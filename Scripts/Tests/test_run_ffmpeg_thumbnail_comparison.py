from __future__ import annotations

import importlib.util
import json
import unittest
from pathlib import Path


SCRIPT_PATH = (
    Path(__file__).resolve().parents[1] / "run-ffmpeg-thumbnail-comparison.py"
)
SPECIFICATION = importlib.util.spec_from_file_location(
    "run_ffmpeg_thumbnail_comparison",
    SCRIPT_PATH,
)
if SPECIFICATION is None or SPECIFICATION.loader is None:
    raise RuntimeError(f"Cannot import {SCRIPT_PATH}")
COMPARISON = importlib.util.module_from_spec(SPECIFICATION)
SPECIFICATION.loader.exec_module(COMPARISON)


class FFmpegThumbnailComparisonTests(unittest.TestCase):
    def test_selected_time_uses_showinfo_timestamp(self) -> None:
        log = "frame id #10 (pts_time=1.250000)\npts: 20 pts_time:1.25"

        self.assertEqual(COMPARISON.selected_time(log), 1.25)

    def test_selected_time_rejects_missing_diagnostic(self) -> None:
        with self.assertRaisesRegex(COMPARISON.ComparisonError, "timestamp"):
            COMPARISON.selected_time("no selected frame")

    def test_acceptable_ranges_are_inclusive(self) -> None:
        ranges = [[2.0, 4.0], [8.0, 9.0]]

        self.assertTrue(COMPARISON.is_acceptable(2.0, ranges))
        self.assertTrue(COMPARISON.is_acceptable(9.0, ranges))
        self.assertFalse(COMPARISON.is_acceptable(6.0, ranges))
        self.assertIsNone(COMPARISON.is_acceptable(6.0, []))

    def test_default_selection_uses_five_reviewed_downloads(self) -> None:
        _, fixtures = COMPARISON.load_fixtures(
            COMPARISON.DEFAULT_MANIFEST,
            set(),
        )

        self.assertEqual(len(fixtures), 5)
        self.assertEqual(
            {fixture["id"] for fixture in fixtures},
            {
                "morevna-demo",
                "big-buck-bunny",
                "sintel",
                "tears-of-steel",
                "cosmos-laundromat",
            },
        )

    def test_unknown_fixture_is_rejected(self) -> None:
        with self.assertRaisesRegex(COMPARISON.ComparisonError, "Unknown"):
            COMPARISON.load_fixtures(
                COMPARISON.DEFAULT_MANIFEST,
                {"missing-fixture"},
            )

    def test_checked_report_covers_reviewed_fixture_set(self) -> None:
        report_path = (
            COMPARISON.REPOSITORY_ROOT
            / "Benchmarks"
            / "Reports"
            / "m1-pro-macos-15.7.4-ffmpeg-7.1-quality.json"
        )
        report = json.loads(report_path.read_text(encoding="utf-8"))

        self.assertEqual(report["schemaVersion"], 1)
        self.assertIn("x86_64", report["ffmpegBinary"])
        self.assertEqual(len(report["fixtures"]), 5)
        self.assertEqual(
            sum(result["acceptable"] is True for result in report["fixtures"]),
            3,
        )
        self.assertTrue(
            all(
                result["decodedFrameCount"] == 2880
                for result in report["fixtures"]
            )
        )


if __name__ == "__main__":
    unittest.main()
