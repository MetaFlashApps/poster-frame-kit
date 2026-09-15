from __future__ import annotations

import copy
import importlib.util
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).resolve().parents[1] / "fetch-benchmark-fixtures.py"
SPECIFICATION = importlib.util.spec_from_file_location(
    "fetch_benchmark_fixtures",
    SCRIPT_PATH,
)
if SPECIFICATION is None or SPECIFICATION.loader is None:
    raise RuntimeError(f"Cannot import {SCRIPT_PATH}")
FIXTURES = importlib.util.module_from_spec(SPECIFICATION)
SPECIFICATION.loader.exec_module(FIXTURES)


class FixtureManifestValidationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.manifest = FIXTURES.load_manifest(FIXTURES.DEFAULT_MANIFEST)

    def test_checked_in_manifest_contains_both_fixture_kinds(self) -> None:
        self.assertEqual(self.manifest["schemaVersion"], 2)
        self.assertEqual(
            {fixture["kind"] for fixture in self.manifest["fixtures"]},
            {"downloaded", "generated"},
        )

    def test_generated_fixture_rejects_download_source(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        generated = next(
            fixture for fixture in manifest["fixtures"]
            if fixture["kind"] == "generated"
        )
        downloaded = next(
            fixture for fixture in manifest["fixtures"]
            if fixture["kind"] == "downloaded"
        )
        generated["source"] = copy.deepcopy(downloaded["source"])

        with self.assertRaisesRegex(
            FIXTURES.FixtureError,
            "cannot have source or transform",
        ):
            FIXTURES.validate_manifest(manifest, False)

    def test_generated_fixture_rejects_unknown_variant(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        generated = next(
            fixture for fixture in manifest["fixtures"]
            if fixture["kind"] == "generated"
        )
        generated["generator"]["variant"] = "unversioned-experiment"

        with self.assertRaisesRegex(
            FIXTURES.FixtureError,
            "unsupported generator variant",
        ):
            FIXTURES.validate_manifest(manifest, False)

    def test_active_download_requires_checksum(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        downloaded = next(
            fixture for fixture in manifest["fixtures"]
            if fixture["kind"] == "downloaded" and fixture["status"] == "active"
        )
        downloaded["source"]["sha256"] = None

        with self.assertRaisesRegex(
            FIXTURES.FixtureError,
            "active source requires a SHA-256",
        ):
            FIXTURES.validate_manifest(manifest, False)

    def test_retired_profile_name_is_rejected(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        manifest["fixtures"][0]["expectations"]["profile"] = "liveAction"

        with self.assertRaisesRegex(
            FIXTURES.FixtureError,
            "unsupported expected profile",
        ):
            FIXTURES.validate_manifest(manifest, False)

    def test_pending_fixture_rejects_reviewed_ranges(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        generated = next(
            fixture for fixture in manifest["fixtures"]
            if fixture["kind"] == "generated"
        )
        generated["expectations"]["acceptableTimeRanges"] = [[0, 1]]

        with self.assertRaisesRegex(
            FIXTURES.FixtureError,
            "pending fixture cannot declare reviewed ranges",
        ):
            FIXTURES.validate_manifest(manifest, False)

    def test_output_names_must_be_unique(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        active = [
            fixture for fixture in manifest["fixtures"]
            if fixture["status"] == "active"
        ]
        active[1]["outputFileName"] = active[0]["outputFileName"]

        with self.assertRaisesRegex(
            FIXTURES.FixtureError,
            "Duplicate outputFileName",
        ):
            FIXTURES.validate_manifest(manifest, False)


if __name__ == "__main__":
    unittest.main()
