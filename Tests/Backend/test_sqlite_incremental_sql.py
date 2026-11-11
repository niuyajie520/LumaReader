"""Execute the exact UPSERT statements embedded in the Swift archive against SQLite."""
from pathlib import Path
import re
import sqlite3
import unittest

SOURCE=(Path(__file__).resolve().parents[2]/'Deferred/StudyCenter/StudyPersistence.swift').read_text()
class SQLitePolicyTests(unittest.TestCase):
    def test_upserts_preserve_unchanged_rows_and_update_payload(self):
        for table,variable,time_field in [('writing_drafts','draftSQL','updated_at'),('writing_submissions','submissionSQL','submitted_at')]:
            with self.subTest(table=table):
                db=sqlite3.connect(':memory:')
                db.execute(f'CREATE TABLE {table}(id TEXT PRIMARY KEY,payload BLOB NOT NULL,{time_field} REAL NOT NULL)')
                sql=re.search(r'let '+variable+r' = "([^"]+)"',SOURCE).group(1)
                db.execute(sql,('one',b'first',1));db.execute(sql,('keep',b'keep',1))
                original=db.execute(f'SELECT rowid FROM {table} WHERE id="one"').fetchone()[0]
                count=db.total_changes
                db.execute(sql,('one',b'first',1));self.assertEqual(db.total_changes,count)
                db.execute(sql,('one',b'changed',2))
                self.assertEqual(db.total_changes,count+1)
                self.assertEqual(db.execute(f'SELECT rowid,payload FROM {table} WHERE id="one"').fetchone(),(original,b'changed'))
                db.execute(f'DELETE FROM {table} WHERE id=?',('one',))
                self.assertEqual(db.execute(f'SELECT id,payload FROM {table}').fetchall(),[('keep',b'keep')])
                db.close()
if __name__=='__main__':unittest.main()
