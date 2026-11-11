#!/usr/bin/env python3
"""SQLite workload comparison, NOT an app CPU/RSS or macOS benchmark."""
import json
from pathlib import Path
import re
import sqlite3
import statistics
import tempfile
import time

ROOT=Path(__file__).resolve().parents[1]
source=(ROOT/'Deferred/StudyCenter/StudyPersistence.swift').read_text()
new_sql=re.search(r'let draftSQL = "([^"]+)"',source).group(1)

def workload(mode):
    with tempfile.TemporaryDirectory() as tmp:
        db=sqlite3.connect(str(Path(tmp)/'test.sqlite'),isolation_level=None)
        db.execute('PRAGMA journal_mode=WAL')
        db.execute('CREATE TABLE writing_drafts(id TEXT PRIMARY KEY,payload BLOB NOT NULL,updated_at REAL NOT NULL)')
        records={str(n):(str(n)+'x'*4096).encode() for n in range(1200)}
        db.executemany('INSERT INTO writing_drafts VALUES(?,?,?)',[(key,data,1) for key,data in records.items()])
        db.execute('PRAGMA wal_checkpoint(TRUNCATE)')
        previous=records.copy(); count=db.total_changes; times=[]
        for iteration in range(12):
            records['0']=('changed'+str(iteration)+'x'*4096).encode()
            started=time.perf_counter()
            db.execute('BEGIN IMMEDIATE')
            if mode=='old':
                db.execute('DELETE FROM writing_drafts')
                db.executemany('INSERT OR REPLACE INTO writing_drafts VALUES(?,?,?)',[(key,data,2) for key,data in records.items()])
            else:
                changed=[(key,data,2) for key,data in records.items() if previous.get(key)!=data]
                db.executemany(new_sql,changed)
            db.execute('COMMIT')
            times.append((time.perf_counter()-started)*1000)
            previous=records.copy()
        result=dict(rows=1200,saves=12,row_mutations=db.total_changes-count,median_ms=round(statistics.median(times),3))
        assert db.execute('SELECT COUNT(*) FROM writing_drafts').fetchone()[0]==1200
        db.close()
        return result

if __name__=='__main__':
    print(json.dumps(dict(scope='Synthetic SQLite workload on this Linux host; not native App performance.',before=workload('old'),after=workload('new')),indent=2))
