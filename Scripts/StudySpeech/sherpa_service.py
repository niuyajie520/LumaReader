#!/usr/bin/env python3
"""Loopback-only, resident sherpa-onnx VITS worker. No downloads or telemetry.
Usage: python sherpa_service.py --model-dir /path/to/model --model-id lessac --port 8765
Requires a separately installed sherpa-onnx runtime and licensed model files.
"""
import argparse, base64, io, json, os, struct, threading, time, wave
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


def create_engine(directory, threads):
    import sherpa_onnx
    folder=Path(directory).resolve()
    candidates=sorted(folder.glob('*.onnx'))
    if len(candidates)!=1 or not (folder/'tokens.txt').is_file():
        raise ValueError('Expected one ONNX model and tokens.txt')
    config=sherpa_onnx.OfflineTtsConfig(model=sherpa_onnx.OfflineTtsModelConfig(
        vits=sherpa_onnx.OfflineTtsVitsModelConfig(model=str(candidates[0]),tokens=str(folder/'tokens.txt'),data_dir=str(folder/'espeak-ng-data')),
        num_threads=threads,provider='cpu',debug=False),max_num_sentences=1)
    if not config.validate(): raise ValueError('Invalid sherpa model configuration')
    return sherpa_onnx.OfflineTts(config)


def wav_bytes(audio):
    import numpy as np
    pcm=(np.clip(audio.samples,-1,1)*32767).astype('<i2').tobytes()
    buffer=io.BytesIO()
    with wave.open(buffer,'wb') as out:
        out.setnchannels(1);out.setsampwidth(2);out.setframerate(audio.sample_rate);out.writeframes(pcm)
    return buffer.getvalue()


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--model-dir',required=True);parser.add_argument('--model-id',required=True)
    parser.add_argument('--port',type=int,default=8765);parser.add_argument('--threads',type=int,choices=[1,2,4],default=2)
    args=parser.parse_args()
    engine=create_engine(args.model_dir,args.threads) # Exactly once per service lifetime.
    lock=threading.Lock()
    class Handler(BaseHTTPRequestHandler):
        def log_message(self,*unused): pass # Never log words or headers.
        def reply(self,status,body,mime='application/json'):
            self.send_response(status);self.send_header('Content-Type',mime);self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body)
        def do_GET(self):
            if self.path!='/v1/models': self.reply(404,b'{}');return
            self.reply(200,json.dumps({'data':[{'id':args.model_id,'object':'model'}]}).encode())
        def do_POST(self):
            if self.path!='/v1/audio/speech': self.reply(404,b'{}');return
            try:
                length=int(self.headers.get('Content-Length','0'))
                if not 0<length<=16384: self.reply(413,b'{}');return
                request=json.loads(self.rfile.read(length))
                if request.get('model')!=args.model_id: self.reply(404,b'{"error":"model unavailable"}');return
                if str(request.get('voice','default')) not in ('default','0'):
                    self.reply(400,b'{"error":"single speaker model: use default voice"}');return
                text=request['input'];speed=float(request.get('speed',1))
                if not isinstance(text,str) or not 0<len(text)<=2000 or not 0.7<=speed<=1.8: self.reply(400,b'{}');return
                with lock: audio=engine.generate(text,sid=0,speed=speed)
                self.reply(200,wav_bytes(audio),'audio/wav')
            except Exception:
                self.reply(500,b'{"error":"speech generation failed"}')
    server=ThreadingHTTPServer(('127.0.0.1',args.port),Handler)
    print(json.dumps({'ready':True,'port':args.port,'model':args.model_id}),flush=True)
    server.serve_forever()
if __name__=='__main__':main()
