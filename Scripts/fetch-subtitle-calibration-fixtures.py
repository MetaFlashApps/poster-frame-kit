#!/usr/bin/env python3
"""Fetch and verify real-material subtitle calibration inputs."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


REPOSITORY_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_MANIFEST = (
    REPOSITORY_ROOT / "Benchmarks" / "Fixtures" / "subtitle-calibration.json"
)
QUALITY_MANIFEST = REPOSITORY_ROOT / "Benchmarks" / "Fixtures" / "manifest.json"
QUALITY_FETCHER = REPOSITORY_ROOT / "Scripts" / "fetch-benchmark-fixtures.py"


class FixtureError(RuntimeError):
    pass


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--manifest",
        type=Path,
        default=DEFAULT_MANIFEST,
        help="Calibration manifest (default: Benchmarks/Fixtures/subtitle-calibration.json).",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Validate manifests without downloading files.",
    )
    parser.add_argument(
        "--verify-only",
        action="store_true",
        help="Verify the existing video and subtitle cache without downloading.",
    )
    return parser.parse_args()


def load_json(path: Path) -> dict[str, Any]:
    try:
        with path.open("r", encoding="utf-8") as handle:
            value = json.load(handle)
    except (OSError, json.JSONDecodeError) as error:
        raise FixtureError(f"Cannot read {path}: {error}") from error
    if not isinstance(value, dict):
        raise FixtureError(f"{path} must contain a JSON object")
    return value


def load_manifest(path: Path = DEFAULT_MANIFEST) -> dict[str, Any]:
    manifest = load_json(path)
    validate_manifest(manifest)
    return manifest


def validate_manifest(manifest: dict[str, Any]) -> None:
    if manifest.get("schemaVersion") != 1:
        raise FixtureError("schemaVersion must be 1")
    for key in (
        "identifier",
        "sourceFixtureID",
        "sourceVideoPath",
        "subtitleDirectory",
        "resultDirectory",
    ):
        required_string(manifest, key)
    repository_path(manifest["sourceVideoPath"])
    repository_path(manifest["subtitleDirectory"])
    repository_path(manifest["resultDirectory"])

    sources = manifest.get("subtitleSources")
    if not isinstance(sources, list) or not sources:
        raise FixtureError("subtitleSources must be a non-empty array")
    source_ids: set[str] = set()
    file_names: set[str] = set()
    for source in sources:
        identifier = required_string(source, "id")
        if identifier in source_ids:
            raise FixtureError(f"Duplicate subtitle source id: {identifier}")
        source_ids.add(identifier)
        for key in ("language", "downloadURL", "fileName", "sha256"):
            required_string(source, key, identifier)
        if not source["downloadURL"].startswith("https://"):
            raise FixtureError(f"{identifier}: downloadURL must use HTTPS")
        file_name = source["fileName"]
        if Path(file_name).name != file_name or not file_name.endswith(".srt"):
            raise FixtureError(f"{identifier}: fileName must be a plain SRT name")
        if file_name in file_names:
            raise FixtureError(f"Duplicate subtitle fileName: {file_name}")
        file_names.add(file_name)
        if not isinstance(source.get("expectedBytes"), int) or source["expectedBytes"] <= 0:
            raise FixtureError(f"{identifier}: expectedBytes must be positive")
        checksum = source["sha256"]
        if len(checksum) != 64 or any(
            character not in "0123456789abcdef" for character in checksum
        ):
            raise FixtureError(f"{identifier}: sha256 must be lowercase hexadecimal")

    variants = manifest.get("variants")
    if not isinstance(variants, list) or not variants:
        raise FixtureError("variants must be a non-empty array")
    variant_ids: set[str] = set()
    supported_styles = {"clean", "outline", "boxed"}
    for variant in variants:
        identifier = required_string(variant, "id")
        if identifier in variant_ids:
            raise FixtureError(f"Duplicate variant id: {identifier}")
        variant_ids.add(identifier)
        style = required_string(variant, "style", identifier)
        if style not in supported_styles:
            raise FixtureError(f"{identifier}: unsupported style {style}")
        source_id = variant.get("subtitleSourceID")
        if style == "clean":
            if source_id is not None:
                raise FixtureError(f"{identifier}: clean style cannot use subtitles")
        elif source_id not in source_ids:
            raise FixtureError(f"{identifier}: unknown subtitleSourceID")
    if sum(variant["style"] == "clean" for variant in variants) != 1:
        raise FixtureError("variants must contain exactly one clean style")

    samples = manifest.get("samples")
    if not isinstance(samples, list) or not samples:
        raise FixtureError("samples must be a non-empty array")
    sample_ids: set[str] = set()
    for sample in samples:
        identifier = required_string(sample, "id")
        if identifier in sample_ids:
            raise FixtureError(f"Duplicate sample id: {identifier}")
        sample_ids.add(identifier)
        timestamp = sample.get("sourceTimeSeconds")
        if not isinstance(timestamp, (int, float)) or timestamp < 0:
            raise FixtureError(f"{identifier}: sourceTimeSeconds must be non-negative")
        if not isinstance(sample.get("expectsSubtitleCue"), bool):
            raise FixtureError(f"{identifier}: expectsSubtitleCue must be boolean")
        if sample.get("sourceExpectation") not in {
            "clean",
            "unwanted-lower-third",
            "ambiguous",
        }:
            raise FixtureError(f"{identifier}: unsupported sourceExpectation")
        tags = sample.get("tags")
        if (
            not isinstance(tags, list)
            or not tags
            or not all(isinstance(tag, str) and tag for tag in tags)
            or len(tags) != len(set(tags))
        ):
            raise FixtureError(f"{identifier}: tags must be unique strings")


def required_string(
    dictionary: dict[str, Any], key: str, context: str | None = None
) -> str:
    value = dictionary.get(key)
    if not isinstance(value, str) or not value:
        prefix = f"{context}: " if context else ""
        raise FixtureError(f"{prefix}{key} must be a non-empty string")
    return value


def repository_path(relative_path: str) -> Path:
    path = (REPOSITORY_ROOT / relative_path).resolve()
    try:
        path.relative_to(REPOSITORY_ROOT)
    except ValueError as error:
        raise FixtureError(f"Path escapes repository: {relative_path}") from error
    return path


def quality_source(manifest: dict[str, Any]) -> dict[str, Any]:
    quality_manifest = load_json(QUALITY_MANIFEST)
    fixtures = quality_manifest.get("fixtures", [])
    fixture = next(
        (
            candidate
            for candidate in fixtures
            if candidate.get("id") == manifest["sourceFixtureID"]
        ),
        None,
    )
    if not isinstance(fixture, dict) or fixture.get("kind") != "downloaded":
        raise FixtureError("sourceFixtureID must reference a downloaded quality fixture")
    expected_path = repository_path(
        f"{quality_manifest['sourceCacheDirectory']}/{fixture['source']['fileName']}"
    )
    declared_path = repository_path(manifest["sourceVideoPath"])
    if expected_path != declared_path:
        raise FixtureError("sourceVideoPath does not match the quality fixture")
    return fixture


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def verify_file(path: Path, expected_bytes: int, expected_checksum: str) -> None:
    if not path.exists():
        raise FixtureError(f"Missing fixture input: {path.relative_to(REPOSITORY_ROOT)}")
    actual_bytes = path.stat().st_size
    if actual_bytes != expected_bytes:
        raise FixtureError(
            f"{path.name}: expected {expected_bytes} bytes, found {actual_bytes}"
        )
    actual_checksum = sha256(path)
    if actual_checksum != expected_checksum:
        raise FixtureError(
            f"{path.name}: SHA-256 mismatch; expected {expected_checksum}, "
            f"found {actual_checksum}"
        )


def download(url: str, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    partial = destination.with_suffix(destination.suffix + ".partial")
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "PosterFrameKit-SubtitleFixtureFetcher/1"},
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            with partial.open("wb") as handle:
                while chunk := response.read(64 * 1024):
                    handle.write(chunk)
    except (OSError, urllib.error.URLError) as error:
        raise FixtureError(f"Download failed for {url}: {error}") from error
    partial.replace(destination)


def fetch_video_source(manifest: dict[str, Any]) -> None:
    command = [
        sys.executable,
        str(QUALITY_FETCHER),
        "--fixture",
        manifest["sourceFixtureID"],
        "--download-only",
    ]
    try:
        subprocess.run(command, cwd=REPOSITORY_ROOT, check=True)
    except (OSError, subprocess.CalledProcessError) as error:
        raise FixtureError(f"Cannot prepare source video: {error}") from error


def verify_video_source(manifest: dict[str, Any], fixture: dict[str, Any]) -> None:
    source = fixture["source"]
    verify_file(
        repository_path(manifest["sourceVideoPath"]),
        source["expectedBytes"],
        source["sha256"],
    )


def main() -> int:
    arguments = parse_arguments()
    manifest = load_manifest(arguments.manifest.resolve())
    fixture = quality_source(manifest)
    if arguments.check:
        print(
            f"Validated {len(manifest['subtitleSources'])} subtitle sources, "
            f"{len(manifest['variants'])} variants, and "
            f"{len(manifest['samples'])} sample timestamps."
        )
        return 0

    if not arguments.verify_only:
        fetch_video_source(manifest)
    verify_video_source(manifest, fixture)
    print("source video verified")

    subtitle_directory = repository_path(manifest["subtitleDirectory"])
    for source in manifest["subtitleSources"]:
        destination = subtitle_directory / source["fileName"]
        if not destination.exists():
            if arguments.verify_only:
                raise FixtureError(
                    f"Missing fixture input: {destination.relative_to(REPOSITORY_ROOT)}"
                )
            print(f"downloading {source['downloadURL']}")
            download(source["downloadURL"], destination)
        verify_file(destination, source["expectedBytes"], source["sha256"])
        print(f"{source['id']} subtitles verified")

    print(
        "ready: arch -arm64 swift run -c release "
        "PosterFrameKitSubtitleBenchmark"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except FixtureError as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(1)
