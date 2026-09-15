from __future__ import annotations

import copy
import importlib.util
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = (
    Path(__file__).resolve().parents[1]
    / "fetch-subtitle-calibration-fixtures.py"
)
SPECIFICATION = importlib.util.spec_from_file_location(
    "fetch_subtitle_calibration_fixtures",
    SCRIPT_PATH,
)
if SPECIFICATION is None or SPECIFICATION.loader is None:
    raise RuntimeError(f"Cannot import {SCRIPT_PATH}")
FIXTURES = importlib.util.module_from_spec(SPECIFICATION)
SPECIFICATION.loader.exec_module(FIXTURES)


class SubtitleFixtureTests(unittest.TestCase):
    def setUp(self) -> None:
        self.manifest = FIXTURES.load_manifest()

    def test_checked_in_manifest_is_paired_and_checksum_locked(self) -> None:
        self.assertEqual(self.manifest["schemaVersion"], 1)
        self.assertEqual(len(self.manifest["subtitleSources"]), 2)
        self.assertEqual(
            [variant["style"] for variant in self.manifest["variants"]].count(
                "clean"
            ),
            1,
        )
        self.assertTrue(
            all(source["sha256"] for source in self.manifest["subtitleSources"])
        )

    def test_unknown_subtitle_source_is_rejected(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        manifest["variants"][1]["subtitleSourceID"] = "missing"

        with self.assertRaisesRegex(FIXTURES.FixtureError, "unknown subtitleSourceID"):
            FIXTURES.validate_manifest(manifest)

    def test_path_escape_is_rejected(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        manifest["sourceVideoPath"] = "../outside.mov"

        with self.assertRaisesRegex(FIXTURES.FixtureError, "Path escapes repository"):
            FIXTURES.validate_manifest(manifest)

    def test_verify_file_checks_byte_count_and_hash(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "fixture.srt"
            path.write_bytes(b"subtitle")
            checksum = FIXTURES.hashlib.sha256(b"subtitle").hexdigest()
            FIXTURES.verify_file(path, 8, checksum)
            with self.assertRaisesRegex(FIXTURES.FixtureError, "expected 9 bytes"):
                FIXTURES.verify_file(path, 9, checksum)


if __name__ == "__main__":
    unittest.main()
