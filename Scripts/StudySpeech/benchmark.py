#!/usr/bin/env python3
"""Actual model inference measurements, not a perceptual speech-quality rating."""
import argparse, json, resource, statistics, sys, time
from pathlib import Path
from sherpa_service import create_engine, wav_bytes

p=argparse.ArgumentParser();p.add_argument('--model-dir',required=True);p.add_argument('--output',required=True);args=p.parse_args()
started=time.perf_counter();engine=create_engine(args.model_dir,2);load_ms=(time.perf_counter()-started)*1000
runs=[]
for word in ['accommodation','infrastructure','fluctuate','sustainable','accommodation']:
    start=time.perf_counter();audio=engine.generate(word,sid=0,speed=1);elapsed=(time.perf_counter()-start)*1000
    samples=audio.samples
    assert len(samples)>0 and any(abs(float(x))>0.0001 for x in samples),'Empty/silent synthesis'
    runs.append({'generationMS':round(elapsed,3),'durationSeconds':round(len(samples)/audio.sample_rate,3),'wavBytes':len(wav_bytes(audio))})
start=time.perf_counter();fast=engine.generate('accommodation',sid=0,speed=1.8);fast_ms=(time.perf_counter()-start)*1000
assert len(fast.samples)>0
rss=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
report={'method':'real sherpa-onnx VITS CPU inference, 2 threads; synthetic word list','platform':sys.platform,'modelLoadMS':round(load_ms,3),'firstGenerationMS':runs[0]['generationMS'],'warmMedianMS':statistics.median(r['generationMS'] for r in runs[1:]),'speed1_8GenerationMS':round(fast_ms,3),'peakRSSBytes':rss if sys.platform=='darwin' else rss*1024,'modelBytes':sum(f.stat().st_size for f in Path(args.model_dir).rglob('*') if f.is_file()),'runs':runs,'physicalAudibility':'NOT MEASURED','gpu':'CPU only; no GPU allocation requested'}
Path(args.output).write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))
