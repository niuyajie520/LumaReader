#!/usr/bin/env python3
"""Dependency-free packaging guard against malformed or missing AI UI resources."""
from pathlib import Path
import json,re,sys
root=Path(sys.argv[1]) if len(sys.argv)>1 else Path(__file__).resolve().parents[1];r=root/'Sources/LumaReader/Resources'
css=(r/'AIChat.css').read_text();script=(r/'AIChat.js').read_text();html=(r/'AIChat.html').read_text()
assert 'import SwiftUI' not in css and 'struct CustomizationPanel' not in css, 'Swift source found in AI stylesheet'
for selector in ['.symbols{display:none}','svg{width:20px','header{display:flex','#messages','#draft']:
 assert selector in css, 'Missing AI style: '+selector
assert css.count('{')==css.count('}'), 'Unbalanced CSS braces'
assert 'window.LumaAI=' in script and "post('ready')" in script, 'Missing AI bridge/bootstrap'
for name in re.findall(r'(?:src|href)="([^"#]+\.(?:css|js))"',html):assert (r/name).is_file(), 'Missing '+name
catalog=json.loads((r/'AppStrings.json').read_text());assert all(isinstance(v,str) for v in catalog.values())
assert 'Resources/AppStrings.' in (root/'Scripts/build-macos.sh').read_text(), 'Installer omits AppStrings.js'
assert (r/'AIHealth.js').is_file() and 'Resources/AIHealth.js' in (root/'Scripts/build-macos.sh').read_text()
print('AI UI resources: PASS (stylesheet, bridge, resource paths, installer asset list)')
