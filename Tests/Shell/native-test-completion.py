#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('completion', Path(__file__).resolve().parents[2] / 'Scripts/check-native-test-completion.py')
completion = importlib.util.module_from_spec(spec)
spec.loader.exec_module(completion)

class CompletionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.evidence = Path(self.temp.name)
        for name in ['epub-rendered-content-synthetic.png', 'epub-narrow-ai-content-synthetic.png']:
            (self.evidence / name).touch()
        self.log = '\n'.join([
            '✔ Test syntheticEPUBChromeRevealsHidesAndKeepsWebView() passed after 40 seconds.',
            '✔ Test syntheticPDFChromeKeepsViewportAndReadingPosition() passed after 8 seconds.',
            '✔ Test nativeFadeReversalsDoNotApplyStaleHiddenState() passed after 1 second.',
            '✔ Test run with 111 tests in 26 suites passed after 50 seconds.',
        ])
    def test_finished_run(self):
        self.assertEqual(completion.validate(self.log, self.evidence), 111)
    def test_zero_exit_truncated_run_is_rejected(self):
        with self.assertRaises(ValueError):
            completion.validate(self.log.rsplit('\n', 1)[0], self.evidence)
    def test_unfinished_reader_case_is_rejected(self):
        with self.assertRaises(ValueError):
            completion.validate(self.log.replace('syntheticEPUBChromeRevealsHidesAndKeepsWebView() passed', 'syntheticEPUBChromeRevealsHidesAndKeepsWebView() started'), self.evidence)
    def test_missing_rendered_snapshot_is_rejected(self):
        (self.evidence / 'epub-rendered-content-synthetic.png').unlink()
        with self.assertRaises(ValueError):
            completion.validate(self.log, self.evidence)

if __name__ == '__main__':
    unittest.main()
