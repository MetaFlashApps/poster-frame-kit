#!/usr/bin/env python3
"""Run FFmpeg's full-sequence thumbnail filter on reviewed quality fixtures."""

from __future__ import annotations

import argparse
import datetime
import json
import platform
import re
import shutil
import subprocess
import time
from pathlib import Path
from typing import Any


REPOSITORY_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_MANIFEST = REPOSITORY_ROOT / "Benchmarks" / "Fixtures" / "manifest.json"
DEFAULT_OUTPUT = REPOSITORY_ROOT / "Benchmarks" / ".quality-results" / "ffmpeg"
SELECTED_TIME_PATTERN = re.compile(r"pts_time[=:](?P<seconds>[0-9]+(?:\.[0-9]+)?)")


class ComparisonError(RuntimeError):
    pass


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--output-directory", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--fixture", action="append", default=[])
    return parser.parse_args()


def selected_time(log: str) -> float:
    matches = list(SELECTED_TIME_PATTERN.finditer(log))
    if not matches:
        raise ComparisonError("FFmpeg did not report a selected frame timestamp")
    return float(matches[-1].group("seconds"))


def is_acceptable(seconds: float, ranges: list[list[float]]) -> bool | None:
    if not ranges:
        return None
    return any(start <= seconds <= end for start, end in ranges)


def load_fixtures(
    path: Path,
    requested: set[str],
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    try:
        manifest = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ComparisonError(f"Cannot read {path}: {error}") from error

    fixtures = [
        fixture
        for fixture in manifest.get("fixtures", [])
        if fixture.get("kind") == "downloaded"
        and fixture.get("status") == "active"
        and fixture.get("tier") == "core"
        and fixture.get("expectations", {}).get("reviewStatus")
        == "initial-human-review"
    ]
    known = {fixture["id"] for fixture in fixtures}
    unknown = requested - known
    if unknown:
        raise ComparisonError(
            "Unknown reviewed downloaded fixture: " + ", ".join(sorted(unknown))
        )
    if requested:
        fixtures = [fixture for fixture in fixtures if fixture["id"] in requested]
    if not fixtures:
        raise ComparisonError("No reviewed downloaded fixtures were selected")
    return manifest, fixtures


def probe(ffprobe: str, video: Path) -> dict[str, Any]:
    process = subprocess.run(
        [
            ffprobe,
            "-v",
            "error",
            "-select_streams",
            "v:0",
            "-show_entries",
            "stream=codec_name,width,height,avg_frame_rate,duration,nb_frames",
            "-of",
            "json",
            str(video),
        ],
        check=False,
        capture_output=True,
        text=True,
    )
    if process.returncode != 0:
        raise ComparisonError(process.stderr.strip() or f"ffprobe failed for {video}")
    streams = json.loads(process.stdout).get("streams", [])
    if not streams or not str(streams[0].get("nb_frames", "")).isdigit():
        raise ComparisonError(f"ffprobe did not report a frame count for {video}")
    return streams[0]


def run_fixture(
    ffmpeg: str,
    ffprobe: str,
    fixture: dict[str, Any],
    clips_directory: Path,
    output_directory: Path,
) -> dict[str, Any]:
    video = clips_directory / fixture["outputFileName"]
    if not video.is_file():
        raise ComparisonError(
            f"Missing normalized fixture: {video}. Run the fixture fetcher first."
        )
    metadata = probe(ffprobe, video)
    frame_count = int(metadata["nb_frames"])
    image = output_directory / f"{fixture['id']}.png"
    start = time.perf_counter()
    process = subprocess.run(
        [
            ffmpeg,
            "-nostdin",
            "-hide_banner",
            "-loglevel",
            "info",
            "-i",
            str(video),
            "-map",
            "0:v:0",
            "-vf",
            f"thumbnail=n={frame_count},showinfo",
            "-frames:v",
            "1",
            "-update",
            "1",
            "-y",
            str(image),
        ],
        check=False,
        capture_output=True,
        text=True,
    )
    wall_milliseconds = (time.perf_counter() - start) * 1_000
    if process.returncode != 0:
        raise ComparisonError(process.stderr.strip() or f"ffmpeg failed for {video}")
    seconds = selected_time(process.stderr)
    return {
        "id": fixture["id"],
        "codec": metadata["codec_name"],
        "width": metadata["width"],
        "height": metadata["height"],
        "averageFrameRate": metadata["avg_frame_rate"],
        "durationSeconds": float(metadata["duration"]),
        "decodedFrameCount": frame_count,
        "selectedTimeSeconds": seconds,
        "acceptable": is_acceptable(
            seconds,
            fixture["expectations"]["acceptableTimeRanges"],
        ),
        "wallMilliseconds": wall_milliseconds,
        "imagePath": image.name,
    }


def processor_name() -> str:
    if platform.system() == "Darwin":
        process = subprocess.run(
            ["sysctl", "-n", "machdep.cpu.brand_string"],
            check=False,
            capture_output=True,
            text=True,
        )
        if process.returncode == 0 and process.stdout.strip():
            return process.stdout.strip()
    return platform.processor() or "unknown"


def portable_path(path: Path) -> str:
    try:
        return str(path.resolve().relative_to(REPOSITORY_ROOT))
    except ValueError:
        return path.name


def binary_description(path: str) -> str:
    file_tool = shutil.which("file")
    if file_tool is None:
        return "unavailable"
    process = subprocess.run(
        [file_tool, "-b", path],
        check=False,
        capture_output=True,
        text=True,
    )
    return process.stdout.strip() if process.returncode == 0 else "unavailable"


def main() -> None:
    arguments = parse_arguments()
    ffmpeg = shutil.which("ffmpeg")
    ffprobe = shutil.which("ffprobe")
    if ffmpeg is None or ffprobe is None:
        raise ComparisonError("ffmpeg and ffprobe must both be available on PATH")

    manifest, fixtures = load_fixtures(
        arguments.manifest,
        set(arguments.fixture),
    )
    manifest_root = arguments.manifest.resolve().parent.parent.parent
    clips_directory = manifest_root / manifest["outputDirectory"]
    arguments.output_directory.mkdir(parents=True, exist_ok=True)
    version = subprocess.run(
        [ffmpeg, "-hide_banner", "-version"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.splitlines()[0]
    results = [
        run_fixture(
            ffmpeg,
            ffprobe,
            fixture,
            clips_directory,
            arguments.output_directory,
        )
        for fixture in fixtures
    ]
    report = {
        "schemaVersion": 1,
        "generatedAt": datetime.datetime.now(datetime.UTC).isoformat(),
        "system": {
            "platform": platform.platform(),
            "architecture": platform.machine(),
            "processor": processor_name(),
        },
        "ffmpegVersion": version,
        "ffmpegBinary": binary_description(ffmpeg),
        "imageDirectory": portable_path(arguments.output_directory),
        "policy": (
            "FFmpeg thumbnail filter over every normalized video frame as one batch; "
            "wall time includes complete software decode, histogram selection, and PNG output"
        ),
        "fixtures": results,
    }
    report_path = arguments.report or arguments.output_directory / "report.json"
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    for result in results:
        print(
            f"{result['id']}: {result['selectedTimeSeconds']:.3f}s, "
            f"{result['wallMilliseconds']:.2f}ms"
        )
    print(f"Wrote FFmpeg comparison to {report_path}")


if __name__ == "__main__":
    try:
        main()
    except ComparisonError as error:
        raise SystemExit(f"FFmpeg comparison failed: {error}") from error
