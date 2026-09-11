#!/usr/bin/env python3
"""Keep Bubble user-facing system documentation synchronized with the FE catalog."""

from __future__ import annotations

import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class SupportedSystemsDocumentationTest(unittest.TestCase):
    def test_generated_documentation_is_current(self) -> None:
        result = subprocess.run(
            [
                "python3",
                str(ROOT / "scripts/generate-bubble-supported-systems-doc.py"),
                "--check",
            ],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
