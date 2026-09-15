#!/usr/bin/env python3
"""Fetch and normalize PosterFrameKit's freely licensed benchmark fixtures."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
import urllib.error
import urllib.request
import zipfile
from pathlib import Path
from typing import Any


REPOSITORY_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_MANIFEST = REPOSITORY_ROOT / "Benchmarks" / "Fixtures" / "manifest.json"


class FixtureError(RuntimeError):
    pass


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--manifest",
        type=Path,
        default=DEFAULT_MANIFEST,
        help="Fixture manifest (default: Benchmarks/Fixtures/manifest.json).",
    )
    parser.add_argument(
        "--fixture",
        action="append",
        default=[],
        help="Fetch only this fixture id; may be repeated.",
    )
    parser.add_argument(
        "--tier",
        choices=("core", "extended", "all"),
        default="core",
        help="Fixture tier to select when --fixture is omitted (default: core).",
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="List manifest entries without downloading them.",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Validate the manifest without downloading files.",
    )
    parser.add_argument(
        "--download-only",
        action="store_true",
        help="Download and verify sources without creating normalized clips.",
    )
    parser.add_argument(
        "--verify-only",
        action="store_true",
        help="Verify downloaded sources and normalized outputs.",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Recreate selected normalized clips even when they already exist.",
    )
    parser.add_argument(
        "--allow-unverified-source",
        action="store_true",
        help="Temporarily permit active sources without a recorded SHA-256.",
    )
    return parser.parse_args()


def load_manifest(
    path: Path, allow_unverified_source: bool = False
) -> dict[str, Any]:
    try:
        with path.open("r", encoding="utf-8") as handle:
            manifest = json.load(handle)
    except (OSError, json.JSONDecodeError) as error:
        raise FixtureError(f"Cannot read {path}: {error}") from error
    validate_manifest(manifest, allow_unverified_source)
    return manifest


def validate_manifest(
    manifest: dict[str, Any], allow_unverified_source: bool
) -> None:
    if manifest.get("schemaVersion") != 2:
        raise FixtureError("schemaVersion must be 2")
    fixtures = manifest.get("fixtures")
    if not isinstance(fixtures, list) or not fixtures:
        raise FixtureError("fixtures must be a non-empty array")

    identifiers: set[str] = set()
    output_names: set[str] = set()
    for fixture in fixtures:
        identifier = required_string(fixture, "id")
        if identifier in identifiers:
            raise FixtureError(f"Duplicate fixture id: {identifier}")
        identifiers.add(identifier)

        if fixture.get("status") not in {"active", "deferred"}:
            raise FixtureError(f"{identifier}: status must be active or deferred")
        if fixture.get("tier") not in {"core", "extended"}:
            raise FixtureError(f"{identifier}: tier must be core or extended")

        kind = fixture.get("kind")
        if kind == "downloaded":
            validate_downloaded_fixture(
                fixture,
                identifier,
                allow_unverified_source,
            )
        elif kind == "generated":
            validate_generated_fixture(fixture, identifier)
        else:
            raise FixtureError(
                f"{identifier}: kind must be downloaded or generated"
            )

        tags = fixture.get("tags")
        if (
            not isinstance(tags, list)
            or not tags
            or not all(isinstance(tag, str) and tag for tag in tags)
            or len(tags) != len(set(tags))
        ):
            raise FixtureError(f"{identifier}: tags must be unique strings")

        expectations = required_dictionary(fixture, "expectations")
        if expectations.get("profile") not in {
            "general",
            "animation",
        }:
            raise FixtureError(f"{identifier}: unsupported expected profile")
        review_status = expectations.get("reviewStatus")
        if review_status not in {
            "initial-human-review",
            "pending-human-review",
            "deferred",
        }:
            raise FixtureError(f"{identifier}: unsupported review status")
        ranges = expectations.get("acceptableTimeRanges")
        if not isinstance(ranges, list):
            raise FixtureError(f"{identifier}: acceptableTimeRanges must be an array")
        for acceptable_range in ranges:
            if (
                not isinstance(acceptable_range, list)
                or len(acceptable_range) != 2
                or not all(
                    isinstance(value, (int, float)) for value in acceptable_range
                )
                or acceptable_range[0] < 0
                or acceptable_range[1] < acceptable_range[0]
            ):
                raise FixtureError(f"{identifier}: invalid acceptable time range")

        if fixture["status"] == "active" and review_status == "deferred":
            raise FixtureError(f"{identifier}: active fixture cannot be deferred")
        if fixture["status"] == "deferred" and review_status != "deferred":
            raise FixtureError(
                f"{identifier}: deferred fixture must use deferred review"
            )
        if review_status == "pending-human-review" and ranges:
            raise FixtureError(
                f"{identifier}: pending fixture cannot declare reviewed ranges"
            )
        if review_status == "initial-human-review" and not ranges:
            raise FixtureError(
                f"{identifier}: reviewed fixture requires acceptable ranges"
            )

        if fixture["status"] == "active":
            output_name = required_string(fixture, "outputFileName")
            if Path(output_name).name != output_name or not output_name.endswith(".mp4"):
                raise FixtureError(f"{identifier}: outputFileName must be a plain MP4 name")
            if output_name in output_names:
                raise FixtureError(f"Duplicate outputFileName: {output_name}")
            output_names.add(output_name)
            if any(
                acceptable_range[1] > fixture_duration(fixture)
                for acceptable_range in ranges
            ):
                raise FixtureError(
                    f"{identifier}: acceptable time range exceeds clip duration"
                )


def validate_downloaded_fixture(
    fixture: dict[str, Any],
    identifier: str,
    allow_unverified_source: bool,
) -> None:
    if fixture.get("generator") is not None:
        raise FixtureError(f"{identifier}: downloaded fixture cannot have generator")
    source = required_dictionary(fixture, "source")
    for key in ("title", "creator", "projectURL", "downloadURL", "fileName"):
        required_string(source, key, identifier)
    if Path(source["fileName"]).name != source["fileName"]:
        raise FixtureError(f"{identifier}: fileName must be a plain file name")
    for key in ("projectURL", "downloadURL"):
        if not source[key].startswith("https://"):
            raise FixtureError(f"{identifier}: {key} must use HTTPS")
    if not isinstance(source.get("expectedBytes"), int) or source["expectedBytes"] <= 0:
        raise FixtureError(f"{identifier}: expectedBytes must be positive")
    checksum = source.get("sha256")
    if checksum is not None and (
        not isinstance(checksum, str)
        or len(checksum) != 64
        or any(character not in "0123456789abcdef" for character in checksum)
    ):
        raise FixtureError(f"{identifier}: sha256 must be lowercase hexadecimal")

    license_data = required_dictionary(source, "license", identifier)
    for key in ("spdx", "url", "attribution", "notes"):
        required_string(license_data, key, identifier)

    if fixture["status"] == "active":
        if checksum is None and not allow_unverified_source:
            raise FixtureError(f"{identifier}: active source requires a SHA-256")
        transform = required_dictionary(fixture, "transform", identifier)
        if transform.get("removeAudio") is not True:
            raise FixtureError(f"{identifier}: normalized fixtures must remove audio")
        for key in ("durationSeconds", "maximumWidth", "maximumHeight"):
            if not isinstance(transform.get(key), (int, float)) or transform[key] <= 0:
                raise FixtureError(f"{identifier}: {key} must be positive")


def validate_generated_fixture(fixture: dict[str, Any], identifier: str) -> None:
    if fixture["status"] != "active":
        raise FixtureError(f"{identifier}: generated fixtures must be active")
    if fixture.get("source") is not None or fixture.get("transform") is not None:
        raise FixtureError(
            f"{identifier}: generated fixture cannot have source or transform"
        )
    generator = required_dictionary(fixture, "generator", identifier)
    if generator.get("name") != "poster-frame-kit-synthetic-video":
        raise FixtureError(f"{identifier}: unsupported generator name")
    if generator.get("variant") not in {
        "standard",
        "subtitles",
        "very-short-single-scene",
        "very-short-multi-scene",
        "coarse-timestamps",
    }:
        raise FixtureError(f"{identifier}: unsupported generator variant")
    required_string(generator, "identifier", identifier)
    for key in (
        "version",
        "width",
        "height",
        "framesPerSecond",
        "durationSeconds",
        "maximumKeyFrameInterval",
    ):
        if not isinstance(generator.get(key), int) or generator[key] <= 0:
            raise FixtureError(f"{identifier}: generator {key} must be positive")


def fixture_duration(fixture: dict[str, Any]) -> float:
    if fixture["kind"] == "generated":
        return float(fixture["generator"]["durationSeconds"])
    return float(fixture["transform"]["durationSeconds"])


def required_string(
    dictionary: dict[str, Any], key: str, context: str | None = None
) -> str:
    value = dictionary.get(key)
    if not isinstance(value, str) or not value:
        prefix = f"{context}: " if context else ""
        raise FixtureError(f"{prefix}{key} must be a non-empty string")
    return value


def required_dictionary(
    dictionary: dict[str, Any], key: str, context: str | None = None
) -> dict[str, Any]:
    value = dictionary.get(key)
    if not isinstance(value, dict):
        prefix = f"{context}: " if context else ""
        raise FixtureError(f"{prefix}{key} must be an object")
    return value


def selected_fixtures(
    manifest: dict[str, Any], arguments: argparse.Namespace
) -> list[dict[str, Any]]:
    fixtures = manifest["fixtures"]
    if arguments.fixture:
        requested = set(arguments.fixture)
        selected = [fixture for fixture in fixtures if fixture["id"] in requested]
        missing = sorted(requested - {fixture["id"] for fixture in selected})
        if missing:
            raise FixtureError(f"Unknown fixture id(s): {', '.join(missing)}")
        return selected
    if arguments.tier == "all":
        return fixtures
    return [fixture for fixture in fixtures if fixture["tier"] == arguments.tier]


def repository_path(relative_path: str) -> Path:
    path = (REPOSITORY_ROOT / relative_path).resolve()
    try:
        path.relative_to(REPOSITORY_ROOT)
    except ValueError as error:
        raise FixtureError(f"Path escapes repository: {relative_path}") from error
    return path


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def verify_source(
    fixture: dict[str, Any], path: Path, allow_unverified_source: bool
) -> None:
    source = fixture["source"]
    actual_bytes = path.stat().st_size
    if actual_bytes != source["expectedBytes"]:
        raise FixtureError(
            f"{fixture['id']}: expected {source['expectedBytes']} source bytes, "
            f"found {actual_bytes}"
        )
    expected_checksum = source.get("sha256")
    if expected_checksum is None:
        if not allow_unverified_source:
            raise FixtureError(
                f"{fixture['id']}: source SHA-256 is not recorded; "
                "use --allow-unverified-source only while establishing the lock"
            )
        print(f"{fixture['id']}: source sha256={sha256(path)}")
        return
    actual_checksum = sha256(path)
    if actual_checksum != expected_checksum:
        raise FixtureError(
            f"{fixture['id']}: SHA-256 mismatch; expected {expected_checksum}, "
            f"found {actual_checksum}"
        )


def download(url: str, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    partial = destination.with_suffix(destination.suffix + ".partial")
    existing_bytes = partial.stat().st_size if partial.exists() else 0
    headers = {"User-Agent": "PosterFrameKit-FixtureFetcher/1"}
    if existing_bytes:
        headers["Range"] = f"bytes={existing_bytes}-"
    request = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            if existing_bytes and response.status != 206:
                existing_bytes = 0
                partial.unlink(missing_ok=True)
            mode = "ab" if existing_bytes else "wb"
            total_header = response.headers.get("Content-Length")
            total = existing_bytes + int(total_header) if total_header else None
            downloaded = existing_bytes
            reported_step = -1
            with partial.open(mode) as handle:
                while True:
                    chunk = response.read(1024 * 1024)
                    if not chunk:
                        break
                    handle.write(chunk)
                    downloaded += len(chunk)
                    if total:
                        percent = downloaded * 100 / total
                        current_step = min(int(percent // 5), 20)
                        if current_step > reported_step:
                            reported_step = current_step
                            print(
                                f"  {downloaded / 1_048_576:.1f} / "
                                f"{total / 1_048_576:.1f} MiB ({percent:.1f}%)",
                                flush=True,
                            )
            if total is None:
                print(f"  downloaded {downloaded / 1_048_576:.1f} MiB")
    except (OSError, urllib.error.URLError) as error:
        raise FixtureError(f"Download failed for {url}: {error}") from error
    partial.replace(destination)


def media_source(fixture: dict[str, Any], downloaded: Path, source_root: Path) -> Path:
    member = fixture["source"].get("archiveMember")
    if member is None:
        return downloaded
    extracted = source_root / fixture["id"] / Path(member).name
    if extracted.exists():
        return extracted
    extracted.parent.mkdir(parents=True, exist_ok=True)
    try:
        with zipfile.ZipFile(downloaded) as archive:
            if member not in archive.namelist():
                raise FixtureError(
                    f"{fixture['id']}: archive does not contain {member}"
                )
            with archive.open(member) as source, extracted.open("wb") as destination:
                shutil.copyfileobj(source, destination)
    except (OSError, zipfile.BadZipFile) as error:
        raise FixtureError(f"{fixture['id']}: cannot extract archive: {error}") from error
    return extracted


def create_normalized_clip(
    fixture: dict[str, Any], source_path: Path, output_path: Path
) -> None:
    transform = fixture["transform"]
    output_path.parent.mkdir(parents=True, exist_ok=True)
    temporary = output_path.with_suffix(".temporary.mp4")
    temporary.unlink(missing_ok=True)
    scale = (
        f"scale={transform['maximumWidth']}:{transform['maximumHeight']}:"
        "force_original_aspect_ratio=decrease:force_divisible_by=2,format=yuv420p"
    )
    command = [
        "ffmpeg",
        "-hide_banner",
        "-loglevel",
        "error",
        "-stats",
        "-ss",
        str(transform["startSeconds"]),
        "-i",
        str(source_path),
        "-t",
        str(transform["durationSeconds"]),
        "-map",
        "0:v:0",
        "-an",
        "-map_metadata",
        "-1",
        "-vf",
        scale,
        "-c:v",
        "libx264",
        "-preset",
        transform["preset"],
        "-crf",
        str(transform["crf"]),
        "-pix_fmt",
        "yuv420p",
        "-movflags",
        "+faststart",
        "-y",
        str(temporary),
    ]
    try:
        subprocess.run(command, check=True)
    except (OSError, subprocess.CalledProcessError) as error:
        temporary.unlink(missing_ok=True)
        raise FixtureError(f"{fixture['id']}: ffmpeg failed: {error}") from error
    temporary.replace(output_path)


def verify_output(fixture: dict[str, Any], output_path: Path) -> None:
    command = [
        "ffprobe",
        "-v",
        "error",
        "-show_entries",
        "stream=codec_type,codec_name,pix_fmt,width,height:format=duration",
        "-of",
        "json",
        str(output_path),
    ]
    try:
        result = subprocess.run(command, check=True, capture_output=True, text=True)
        information = json.loads(result.stdout)
    except (OSError, subprocess.CalledProcessError, json.JSONDecodeError) as error:
        raise FixtureError(f"{fixture['id']}: cannot inspect output: {error}") from error
    streams = information.get("streams", [])
    videos = [stream for stream in streams if stream.get("codec_type") == "video"]
    if len(videos) != 1:
        raise FixtureError(f"{fixture['id']}: output must contain one video stream")
    if any(stream.get("codec_type") == "audio" for stream in streams):
        raise FixtureError(f"{fixture['id']}: output must not contain audio")
    stream = videos[0]
    transform = fixture["transform"]
    if stream.get("codec_name") != "h264" or stream.get("pix_fmt") != "yuv420p":
        raise FixtureError(f"{fixture['id']}: output is not H.264 yuv420p")
    if (
        stream.get("width", 0) > transform["maximumWidth"]
        or stream.get("height", 0) > transform["maximumHeight"]
    ):
        raise FixtureError(f"{fixture['id']}: output exceeds its bounding box")
    duration = float(information["format"]["duration"])
    if abs(duration - transform["durationSeconds"]) > 0.25:
        raise FixtureError(
            f"{fixture['id']}: output duration {duration:.3f}s does not match "
            f"{transform['durationSeconds']}s"
        )


def require_program(name: str) -> None:
    if shutil.which(name) is None:
        raise FixtureError(f"Required program is unavailable: {name}")


def print_fixture(fixture: dict[str, Any]) -> None:
    if fixture["kind"] == "generated":
        generator = fixture["generator"]
        print(
            f"{fixture['id']:<30} {fixture['status']:<8} "
            f"{fixture['tier']:<8} generated  {generator['variant']}"
        )
        return
    source = fixture["source"]
    size_mib = source["expectedBytes"] / 1_048_576
    print(
        f"{fixture['id']:<22} {fixture['status']:<8} {fixture['tier']:<8} "
        f"{size_mib:>9.1f} MiB  {source['title']}"
    )


def main() -> int:
    arguments = parse_arguments()
    manifest = load_manifest(
        arguments.manifest.resolve(),
        allow_unverified_source=arguments.allow_unverified_source,
    )
    fixtures = selected_fixtures(manifest, arguments)

    if arguments.list:
        for fixture in fixtures:
            print_fixture(fixture)
        return 0
    if arguments.check:
        print(f"Validated {len(manifest['fixtures'])} fixture definitions.")
        return 0

    source_root = repository_path(manifest["sourceCacheDirectory"])
    output_root = repository_path(manifest["outputDirectory"])
    has_downloaded_fixture = any(
        fixture["kind"] == "downloaded" and fixture["status"] == "active"
        for fixture in fixtures
    )
    if not arguments.download_only and has_downloaded_fixture:
        require_program("ffmpeg")
        require_program("ffprobe")

    for fixture in fixtures:
        if fixture["status"] != "active":
            print(f"{fixture['id']}: deferred ({fixture['source']['license']['notes']})")
            continue
        if fixture["kind"] == "generated":
            print(f"{fixture['id']}:")
            print("  generated on demand by PosterFrameKitQualityBenchmark")
            continue
        source = fixture["source"]
        downloaded = source_root / source["fileName"]
        output = output_root / fixture["outputFileName"]
        print(f"{fixture['id']}:")
        if not downloaded.exists():
            if arguments.verify_only:
                raise FixtureError(f"{fixture['id']}: source is not downloaded")
            print(f"  downloading {source['downloadURL']}")
            download(source["downloadURL"], downloaded)
        verify_source(fixture, downloaded, arguments.allow_unverified_source)
        print("  source verified")

        if arguments.download_only:
            continue
        if arguments.verify_only:
            if not output.exists():
                raise FixtureError(f"{fixture['id']}: normalized clip is missing")
            verify_output(fixture, output)
            print(f"  output verified: {output.relative_to(REPOSITORY_ROOT)}")
            continue

        source_media = media_source(fixture, downloaded, source_root)
        if arguments.force or not output.exists():
            print(f"  creating {output.relative_to(REPOSITORY_ROOT)}")
            create_normalized_clip(fixture, source_media, output)
        verify_output(fixture, output)
        print(f"  output verified: {output.relative_to(REPOSITORY_ROOT)}")

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except FixtureError as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(1)
