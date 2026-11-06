#!/usr/bin/env python3
"""Minimal project PII/path gate, complementary to pinned Gitleaks. Never prints matched values."""
from pathlib import Path
import re,sys,json
rules={
 'private-path':re.compile(rb'/(?:Users|home|workspace)/[A-Za-z0-9_.-]+(?:/[^\s\x00\"\'<>]*)?'),
 'private-key':re.compile(rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'),
 'github-token':re.compile(rb'\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,})'),
 'api-token':re.compile(rb'\bsk-(?:proj-|ant-)?[A-Za-z0-9_-]{25,}'),
 'aws-key':re.compile(rb'\b(?:AKIA|ASIA)[A-Z0-9]{16}\b'),
 'email':re.compile(rb'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b')}
def allowed(kind,value,path):
 if kind=='email' and value.rsplit(b'@',1)[-1] in [b'example.com',b'example.org',b'example.invalid']:return True
 return False
def scan(root):
 root=Path(root);findings=[];count=0
 for p in sorted(root.rglob('*')):
  rel=p.relative_to(root)
  if not p.is_file() or set(rel.parts)&{'.git','.build','.swiftpm','ci-raw','ci-safe','node_modules','__pycache__'}:continue
  count+=1
  if p.name.startswith('.env') and p.name!='.env.example' or p.suffix.lower() in ['.p12','.pfx','.pem','.key']:
   findings.append({'file':rel.as_posix(),'rule':'credential-file'});continue
  data=p.read_bytes()
  for kind,pattern in rules.items():
   if any(not allowed(kind,m.group(),rel) for m in pattern.finditer(data)):findings.append({'file':rel.as_posix(),'rule':kind})
 print(json.dumps({'status':'PASS' if not findings else 'PRIVACY_BLOCKED','filesScanned':count,'findings':findings,'scope':'Supplemental PII/path/signature scan; not a guarantee and not a replacement for Gitleaks'},indent=2))
 return bool(findings)
def redact(source,destination):
 out=Path(destination);out.mkdir(parents=True,exist_ok=True)
 for p in sorted(Path(source).glob('*.log')):
  data=p.read_bytes()
  data=re.sub(rb'(?im)\b(?:authorization|proxy-authorization|cookie|set-cookie)\s*:[^\r\n]+',b'[REDACTED-HEADER]',data)
  data=re.sub(rb'(?i)([?&](?:token|api_key|access_token|refresh_token|password|client_secret)=)[^\s&\"\']+',rb'\1[REDACTED]',data)
  for kind,pattern in rules.items():data=pattern.sub(('[REDACTED-'+kind+']').encode(),data)
  # Compiler/SDK paths are useful only in a local log, not in a public artifact.
  data=re.sub(rb'/(?:Applications|Library|private|var|tmp|opt)/[^\s\x00\"\'<>]+',b'[SYSTEM-PATH]',data)
  (out/p.name).write_bytes(data)
 return 0
if __name__=='__main__':
 if len(sys.argv)==4 and sys.argv[1]=='redact':sys.exit(redact(sys.argv[2],sys.argv[3]))
 if len(sys.argv)==2:sys.exit(scan(sys.argv[1]))
 sys.exit('Usage: privacy-gate.py ROOT | redact RAW_DIR SAFE_DIR')
