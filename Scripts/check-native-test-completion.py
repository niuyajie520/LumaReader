#!/usr/bin/env python3
"""Reject a zero-exit test process that never finishes the native acceptance suite."""
from pathlib import Path
import re
import sys

def validate(log, evidence):
    summary = re.search(r'Test run with ([1-9][0-9]*) tests(?: in [0-9]+ suites)? passed', log)
    if not summary:
        raise ValueError('Missing successful final Swift Testing summary')
    required = [
        'syntheticEPUBChromeRevealsHidesAndKeepsWebView',
        'syntheticPDFChromeKeepsViewportAndReadingPosition',
        'nativeFadeReversalsDoNotApplyStaleHiddenState',
    ]
    for name in required:
        if not re.search(r'Test ' + re.escape(name) + r'\(\) passed', log):
            raise ValueError('Native reader acceptance test did not finish: ' + name)
    for name in ['epub-rendered-content-synthetic.png', 'epub-narrow-ai-content-synthetic.png']:
        if not (evidence / name).is_file():
            raise ValueError('Missing rendered reader evidence: ' + name)
    return int(summary.group(1))

if __name__ == '__main__':
    if len(sys.argv) < 3:
        sys.exit('Usage: check-native-test-completion.py <test-log-path> <evidence-dir>')
    try:
        count = validate(Path(sys.argv[1]).read_text(encoding='utf-8', errors='replace'), Path(sys.argv[2]))
    except (ValueError, OSError) as error:
        sys.exit('Native test completion: FAIL: ' + str(error))
    print(f'Native test completion: PASS ({count} tests, reader cases and rendered evidence complete)')
