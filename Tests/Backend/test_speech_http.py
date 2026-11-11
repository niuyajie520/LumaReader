"""Real local HTTP/queue/cache integration; inference is a deterministic fake, no model downloads."""
import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import threading
import unittest
import urllib.error
import urllib.request

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'Scripts'))

class SpeechHTTPTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp=tempfile.TemporaryDirectory()
        previous=os.environ.get('LUMA_KOKORO_DIR')
        os.environ['LUMA_KOKORO_DIR']=cls.temp.name
        try:
            spec=importlib.util.spec_from_file_location('luma_test_daemon',ROOT/'Scripts/kokoro_neural_daemon.py')
            cls.daemon=importlib.util.module_from_spec(spec);spec.loader.exec_module(cls.daemon)
        finally:
            if previous is None:os.environ.pop('LUMA_KOKORO_DIR',None)
            else:os.environ['LUMA_KOKORO_DIR']=previous
        import numpy as np
        class Model:
            calls=0
            def create(self,**kwargs):
                self.calls+=1
                return np.zeros(2400,dtype=np.float32),24000
        cls.model=Model()
        cls.daemon.MODEL_CONTROL.loader=lambda name: cls.model
        cls.daemon.MODEL_CONTROL.ensure_loaded()
        cls.server=cls.daemon.ReusableThreadingHTTPServer(('127.0.0.1',0),cls.daemon.Handler)
        cls.thread=threading.Thread(target=cls.server.serve_forever,daemon=True);cls.thread.start()
        cls.base='http://127.0.0.1:'+str(cls.server.server_address[1])
    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown();cls.server.server_close();cls.thread.join(2);cls.temp.cleanup()
    def post(self,path,data):
        request=urllib.request.Request(self.base+path,data=data,headers={'Content-Type':'application/json'})
        try:
            with urllib.request.urlopen(request,timeout=3) as response:return response.status,json.load(response)
        except urllib.error.HTTPError as error:return error.code,json.load(error)
    def test_invalid_json_and_size_are_rejected(self):
        self.assertEqual(self.post('/synthesize',b'[]')[0],400)
        self.assertEqual(self.post('/synthesize',b'x'*(256*1024+1))[0],413)
    def test_same_word_uses_disk_audio_without_second_inference(self):
        body=json.dumps(dict(text='regression-word',voice='Bella',engine='kitten-micro',speed=1)).encode()
        first=self.post('/synthesize',body);second=self.post('/synthesize',body)
        self.assertEqual(first[0],200);self.assertEqual(second[0],200)
        self.assertEqual(first[1]['wav_path'],second[1]['wav_path'])
        self.assertTrue(Path(first[1]['wav_path']).is_file())
        self.assertEqual(self.model.calls,1)
    def test_failed_model_reports_unavailable_instead_of_apple_as_neural(self):
        control = self.daemon.MODEL_CONTROL
        original_loader = control.loader
        def unavailable(_):
            raise RuntimeError("missing model fixture")
        control.loader = unavailable
        try:
            status, result = self.post('/engine', b'{"model":"kitten-micro"}')
            self.assertEqual(status, 503)
            self.assertFalse(result['neural_loaded'])
            self.assertFalse(result['ready'])
            status, result = self.post('/synthesize', b'{"text":"missing-model-fixture","voice":"Bella","engine":"kitten-micro"}')
            self.assertEqual(status, 503)
            self.assertIn('missing model fixture', result['error'])
        finally:
            control.loader = original_loader
            control.switch('kitten-micro')

    def test_suspend_endpoint_is_available(self):
        self.assertEqual(self.post('/suspend',b'{}'),(200,{'status':'paused'}))

if __name__=='__main__':unittest.main()
