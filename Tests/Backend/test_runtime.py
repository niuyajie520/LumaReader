import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import threading
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'Scripts'))
from audio_priority_queue import AudioPriorityQueue
from exclusive_tts import MODEL_IDS
spec = importlib.util.spec_from_file_location('cleanup', ROOT / 'Scripts/remove-legacy-kokoro.py')
cleanup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cleanup)

class BackendTests(unittest.TestCase):
    def test_priority_dedup_and_background_cancellation(self):
        entered, release = threading.Event(), threading.Event()
        calls = []
        def generate(name):
            calls.append(name)
            if name == 'running':
                entered.set()
                self.assertTrue(release.wait(2))
            return name
        queue = AudioPriorityQueue(generate)
        queue.preload([('running', ('running',))])
        self.assertTrue(entered.wait(2))
        queue.preload([('drop', ('drop',)), ('promote', ('promote',))])
        with queue.condition:
            first = queue._submit('promote', ('promote',), True)
            second = queue._submit('promote', ('promote',), True)
        self.assertIs(first, second)
        queue.preload([])
        release.set()
        self.assertEqual(first.result(2), 'promote')
        self.assertEqual(calls, ['running', 'promote'])

    def test_bounded_requests(self):
        entered, release = threading.Event(), threading.Event()
        def generate(*_):
            entered.set(); release.wait(2)
        queue = AudioPriorityQueue(generate, max_pending=1)
        queue.preload([('one', ())])
        self.assertTrue(entered.wait(2))
        try:
            with self.assertRaises(RuntimeError): queue.request('two', ())
        finally: release.set()

    def test_request_deadline(self):
        release = threading.Event()
        queue = AudioPriorityQueue(lambda: release.wait(2), request_timeout=.02)
        try:
            with self.assertRaises(TimeoutError): queue.request('one', ())
        finally: release.set()

    def test_suspend_cancels_queued_foreground(self):
        entered, release = threading.Event(), threading.Event()
        def generate():
            entered.set(); release.wait(2)
        queue = AudioPriorityQueue(generate)
        queue.preload([('running', ())])
        self.assertTrue(entered.wait(2))
        with queue.condition:
            future = queue._submit('queued', (), True)
        queue.cancel_pending()
        self.assertTrue(future.cancelled())
        self.assertNotIn('queued', queue.jobs)
        release.set()

    def test_retired_selection_migrates(self):
        from types import SimpleNamespace
        from exclusive_tts import ExclusiveModels
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary); (base / 'config').mkdir()
            (base / 'config/exclusive-engine.json').write_text(json.dumps({'model': 'kokoro', 'voices': {'kokoro': {}}}))
            engine = SimpleNamespace(active_slots={}, synthesize_with_wsola_and_padding=lambda *args: None,
                                     get_categorized_voices=lambda: {}, save_slots=lambda *args: None,
                                     model_error=None)
            control = ExclusiveModels(engine, base)
            self.assertEqual(control.selected, 'kitten-micro')
            self.assertNotIn('kokoro', control.voice_sets)
            with self.assertRaises(ValueError): control.switch('kokoro')

    def test_only_supported_models(self):
        self.assertEqual(set(MODEL_IDS), {'kitten-nano', 'kitten-micro'})

    def test_cleanup_preserves_kitten_and_documents(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for directory in ('KokoroEngine', 'KokoroTTS'):
                base = root / directory
                (base / 'models').mkdir(parents=True)
                for folder in (base, base / 'models'):
                    for name in ('kokoro-v1.0.onnx', 'voices-v1.0.bin'): (folder / name).write_bytes(b'old')
                keep = base / 'kitten-cache/weights.onnx'
                keep.parent.mkdir(); keep.write_bytes(b'keep')
                (base / 'venv').mkdir()
                config = base / 'config/exclusive-engine.json'
                config.parent.mkdir()
                config.write_text(json.dumps({'model': 'kokoro', 'voices': {'kokoro': {}, 'kitten-micro': {'US_Female':'Bella'}}}))
            (root / 'writing.sqlite').write_bytes(b'essays')
            cleanup.cleanup(root); cleanup.cleanup(root)
            self.assertEqual((root / 'writing.sqlite').read_bytes(), b'essays')
            self.assertFalse(list(root.rglob('kokoro-v1.0.onnx')))
            for base in (root / 'KokoroEngine', root / 'KokoroTTS'):
                self.assertEqual((base / 'kitten-cache/weights.onnx').read_bytes(), b'keep')
                self.assertTrue((base / 'venv').exists())
                data = json.loads((base / 'config/exclusive-engine.json').read_text())
                self.assertEqual(data['model'], 'kitten-micro')
                self.assertNotIn('kokoro', data['voices'])

    def test_cleanup_unlinks_weight_symlink_only(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); base = root / 'KokoroEngine'; base.mkdir()
            external = root / 'personal.onnx'; external.write_bytes(b'keep')
            (base / 'kokoro-v1.0.onnx').symlink_to(external)
            cleanup.cleanup(root)
            self.assertTrue(external.exists())
            self.assertFalse((base / 'kokoro-v1.0.onnx').is_symlink())

if __name__ == '__main__': unittest.main()
