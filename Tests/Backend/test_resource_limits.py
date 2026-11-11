from pathlib import Path
import os
import sys
import tempfile
import threading
import time
import types
import unittest

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'Scripts'))
from audio_cache_budget import AudioCacheBudget
from bounded_onnx import bounded_sessions
from audio_priority_queue import AudioPriorityQueue

class ResourceTests(unittest.TestCase):
    def test_budget_evicts_oldest_and_preserves_personal_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); now=time.time()
            for n in range(3):
                path=root/(str(n)*32+'.wav');path.write_bytes(b'x'*100)
                os.utime(path,(now-1000+n,now-1000+n))
            personal=root/'my-recording.wav';personal.write_bytes(b'keep')
            result=AudioCacheBudget([root],max_bytes=150).prune(now)
            self.assertEqual(result,dict(remaining_bytes=100,removed_files=2))
            self.assertTrue((root/('2'*32+'.wav')).exists())
            self.assertEqual(personal.read_bytes(),b'keep')

    def test_recent_active_audio_and_symlink_are_protected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); path=root/('a'*32+'.wav');path.write_bytes(b'keep')
            (root/('b'*32+'.wav')).symlink_to(path)
            result=AudioCacheBudget([root],max_bytes=0,grace=300).prune()
            self.assertEqual(result['removed_files'],0)
            self.assertTrue(path.exists())

    def test_expired_audio_and_touch_throttling(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); path=root/('a'*32+'.wav');path.write_bytes(b'cache')
            now=time.time(); old=now-31*86400; os.utime(path,(old,old))
            AudioCacheBudget.touch(path,now)
            AudioCacheBudget.touch(path,now+10)
            self.assertAlmostEqual(path.stat().st_mtime,now,places=3)
            os.utime(path,(old,old))
            self.assertEqual(AudioCacheBudget([root]).prune(now)['removed_files'],1)

    def test_symlinked_cache_folder_is_never_cleaned(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); outside=root/'outside';outside.mkdir()
            file=outside/('a'*32+'.wav');file.write_bytes(b'keep');os.utime(file,(1,1))
            link=root/'cache';link.symlink_to(outside,target_is_directory=True)
            self.assertEqual(AudioCacheBudget([link],max_bytes=0).prune()['removed_files'],0)
            self.assertTrue(file.exists())

    def test_scoped_onnx_options_and_restore_after_failure(self):
        calls=[]
        class Options:
            def __init__(self):self.entries={}
            def add_session_config_entry(self,key,value):self.entries[key]=value
        def session(*args,**kwargs):calls.append(kwargs);return object()
        runtime=types.SimpleNamespace(SessionOptions=Options,ExecutionMode=types.SimpleNamespace(ORT_SEQUENTIAL='sequential'),InferenceSession=session)
        legacy=types.SimpleNamespace(ort=runtime)
        with self.assertRaisesRegex(RuntimeError,'load failed'):
            with bounded_sessions(legacy):
                legacy.ort.InferenceSession('model',providers=['GPU'])
                raise RuntimeError('load failed')
        self.assertIs(legacy.ort,runtime)
        self.assertIs(runtime.InferenceSession,session)
        options=calls[0]['sess_options']
        self.assertEqual((options.intra_op_num_threads,options.inter_op_num_threads),(2,1))
        self.assertEqual(options.entries,{'session.intra_op.allow_spinning':'0','session.inter_op.allow_spinning':'0'})
        self.assertFalse(options.enable_cpu_mem_arena)
        self.assertEqual(calls[0]['providers'],['CPUExecutionProvider'])

    def test_queue_is_not_idle_during_inference(self):
        entered,release=threading.Event(),threading.Event()
        def render():entered.set();release.wait(2)
        queue=AudioPriorityQueue(render)
        queue.preload([('one',())]);self.assertTrue(entered.wait(2))
        self.assertEqual(queue.idle_seconds(),0)
        release.set()
        deadline=time.monotonic()+2
        while queue.jobs and time.monotonic()<deadline:time.sleep(.005)
        self.assertFalse(queue.jobs)
        self.assertLess(queue.idle_seconds(),1)

if __name__=='__main__':unittest.main()
