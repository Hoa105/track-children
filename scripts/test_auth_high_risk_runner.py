"""Check report accounting cannot hide loader failures or incomplete runs."""
import json
from pathlib import Path
import tempfile
import unittest

from scripts.test_auth_high_risk import backend_counts, flutter_counts


class ReportTests(unittest.TestCase):
    def test_flutter_excludes_successful_loaders_but_preserves_failures_and_skips(self):
        events = [
            {'type': 'testDone', 'testID': 1, 'result': 'success', 'hidden': True},
            {'type': 'testDone', 'testID': 2, 'result': 'error', 'hidden': True},
            {'type': 'testDone', 'testID': 3, 'result': 'success', 'skipped': True},
            {'type': 'testDone', 'testID': 4, 'result': 'success'},
        ]
        with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as directory:
            path = Path(directory) / 'events.jsonl'
            path.write_text('\n'.join(json.dumps(e) for e in events), encoding='utf-8')
            result = flutter_counts(path)
        self.assertEqual(result, {'total': 3, 'failed': 1, 'skipped': 1, 'complete': False})

    def test_backend_counts_setup_errors_as_failures(self):
        with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as directory:
            path = Path(directory) / 'junit.xml'
            path.write_text('<testsuites><testsuite><testcase/><testcase><error/></testcase>'
                            '<testcase><failure/></testcase><testcase><skipped/></testcase>'
                            '</testsuite></testsuites>', encoding='utf-8')
            self.assertEqual(backend_counts(path), {'total': 4, 'failed': 2, 'skipped': 1})


if __name__ == '__main__':
    unittest.main()
