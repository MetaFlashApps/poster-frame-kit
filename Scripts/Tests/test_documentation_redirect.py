from __future__ import annotations

import re
import unittest
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urljoin


class RedirectParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.target = ""
        self.link = ""

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attributes = dict(attrs)
        if tag == "meta" and attributes.get("http-equiv") == "refresh":
            self.target = (attributes.get("content") or "").removeprefix("0; url=")
        if tag == "a":
            self.link = attributes.get("href") or ""


class DocumentationRedirectTests(unittest.TestCase):
    def setUp(self) -> None:
        template = Path(__file__).resolve().parents[2] / "docs/assets/docc-index.html"
        self.html = template.read_text(encoding="utf-8")
        self.parser = RedirectParser()
        self.parser.feed(self.html)

    def test_project_site_keeps_repository_prefix(self) -> None:
        self.assertEqual(
            urljoin("https://example.com/poster-frame-kit/", self.parser.target),
            "https://example.com/poster-frame-kit/documentation/posterframekit/",
        )

    def test_root_hosted_site_needs_no_repository_prefix(self) -> None:
        self.assertEqual(
            urljoin("https://docs.example.com/", self.parser.target),
            "https://docs.example.com/documentation/posterframekit/",
        )

    def test_refresh_javascript_and_fallback_link_share_relative_target(self) -> None:
        target = re.search(r'window\.location\.replace\("([^"]+)"', self.html)
        self.assertIsNotNone(target)
        self.assertEqual(self.parser.target, "./documentation/posterframekit/")
        self.assertEqual(self.parser.link, self.parser.target)
        self.assertEqual(target.group(1), self.parser.target)


if __name__ == "__main__":
    unittest.main()
