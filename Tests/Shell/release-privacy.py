#!/usr/bin/env python3
"""Synthetic fixtures only: verify binary diagnostics never disclose path values."""
import json
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

class ReleasePrivacyTests(unittest.TestCase):
    def audit(self, data):
        with tempfile.TemporaryDirectory() as directory:
            binary = Path(directory) / 'synthetic-binary'
            binary.write_bytes(data)
            result = subprocess.check_output(['python3', str(ROOT / 'Scripts/binary-path-audit.py'), str(binary)], cwd=ROOT)
            return result, json.loads(result)

    def test_counts_build_paths_without_exporting_values(self):
        value = str(ROOT / 'fixture' / 'private-name.swift').encode()
        raw, report = self.audit(b'\x00' + value + b'\x00')
        self.assertEqual(report['currentBuildWorkspaceMatches'], 1)
        self.assertEqual(report['otherMatches'], 0)
        self.assertNotIn(value, raw)

    def test_other_paths_remain_blocked(self):
        value = b'/' + b'Users' + b'/fictional-person/private-file'
        raw, report = self.audit(b'\x00' + value + b'\x00')
        self.assertEqual(report['otherMatches'], 1)
        self.assertNotIn(value, raw)
        with tempfile.TemporaryDirectory() as directory:
            (Path(directory) / 'synthetic-binary').write_bytes(value)
            result = subprocess.run(['python3', str(ROOT / 'Scripts/privacy-gate.py'), directory], capture_output=True)
            self.assertEqual(result.returncode, 1)
            self.assertNotIn(value, result.stdout)

    def test_clean_binary(self):
        _, report = self.audit(b'\x00safe synthetic payload\x00')
        self.assertEqual(report['privatePathMatches'], 0)

if __name__ == '__main__':
    unittest.main()
