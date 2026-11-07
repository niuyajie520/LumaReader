#!/usr/bin/env python3
"""Synthetic fixtures only: verify binary diagnostics never disclose path values."""
import json
import importlib.util
import io
import subprocess
import tarfile
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('prepare_release', ROOT / 'Scripts/prepare-release.py')
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)

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

    def test_real_git_archives_include_root_and_unicode_paths(self):
        with tempfile.TemporaryDirectory() as directory:
            repo = Path(directory) / 'fixture'
            repo.mkdir()
            files = {'README.md', '.github/workflows/fixture.yml', 'Sources/字体.swift'}
            for name in files:
                p = repo / name
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_text('synthetic fixture\n')
            subprocess.run(['git', 'init', '-q', str(repo)], check=True)
            subprocess.run(['git', '-C', str(repo), 'add', '.'], check=True)
            tree = subprocess.check_output(['git', '-C', str(repo), 'write-tree'], text=True).strip()
            for fmt in ['zip', 'tar.gz']:
                archive = Path(directory) / ('source.' + fmt)
                if fmt == 'tar.gz':
                    import os
                    original = Path.cwd()
                    try:
                        os.chdir(repo)
                        release.create_source_tar_gz(archive, 'LumaReader-fixture/', tree)
                    finally:
                        os.chdir(original)
                else:
                    subprocess.run(['git', '-C', str(repo), 'archive', f'--format={fmt}',
                                    '--prefix=LumaReader-fixture/', f'--output={archive}', tree], check=True)
                release.verify_source_archive(archive, fmt, 'LumaReader-fixture/', files)

    def test_stored_tar_still_exposes_private_data_to_privacy_gate(self):
        import os
        with tempfile.TemporaryDirectory() as directory:
            repo = Path(directory) / 'fixture'
            repo.mkdir()
            (repo / 'data.txt').write_bytes(b'private ' + b'person@' + b'private.invalid')
            subprocess.run(['git', 'init', '-q', str(repo)], check=True)
            subprocess.run(['git', '-C', str(repo), 'add', '.'], check=True)
            tree = subprocess.check_output(['git', '-C', str(repo), 'write-tree'], text=True).strip()
            archive_dir = Path(directory) / 'output'
            archive_dir.mkdir()
            original = Path.cwd()
            try:
                os.chdir(repo)
                release.create_source_tar_gz(archive_dir / 'source.tar.gz', 'fixture/', tree)
            finally:
                os.chdir(original)
            result = subprocess.run(['python3', str(ROOT / 'Scripts/privacy-gate.py'), str(archive_dir)], capture_output=True)
            self.assertEqual(result.returncode, 1)
            self.assertIn(b'email', result.stdout)

    def test_tar_traversal_and_links_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            for link in [False, True]:
                archive = Path(directory) / 'unsafe.tar.gz'
                with tarfile.open(archive, 'w:gz') as t:
                    m = tarfile.TarInfo('fixture/link' if link else 'fixture/../escape')
                    if link:
                        m.type = tarfile.SYMTYPE
                        m.linkname = '../external'
                        t.addfile(m)
                    else:
                        m.size = 1
                        t.addfile(m, io.BytesIO(b'x'))
                with self.assertRaises(AssertionError):
                    release.verify_source_archive(archive, 'tar.gz', 'fixture/', set() if link else {'../escape'})

    def test_zip_links_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / 'unsafe.zip'
            with zipfile.ZipFile(archive, 'w') as z:
                m = zipfile.ZipInfo('fixture/link')
                m.create_system = 3
                m.external_attr = 0o120777 << 16
                z.writestr(m, '../external')
            with self.assertRaises(AssertionError):
                release.verify_source_archive(archive, 'zip', 'fixture/', {'link'})

if __name__ == '__main__':
    unittest.main()
