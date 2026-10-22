from pathlib import Path
import hashlib,json
b=Path(__file__).resolve().parent
before=(b/'source-before/AArch64.lean').read_text()
after=(b/'source-after/AArch64.lean').read_text()
parts={}
for name in ['ALU','ABI']:
 text=(b/f'source-after/{name}.lean').read_text()
 parts[name]=text.split('namespace LeanCompilerBackend.AArch64\n\n',1)[1].removesuffix('end LeanCompilerBackend.AArch64\n')
assert parts['ALU']==before[before.index('inductive ALU where'):before.index('private def register')]
assert parts['ABI']==before[before.index('/-- Apple ARM64 packs'):before.index('/-- Split frame adjustments')]
restored=after.replace('import LeanCompilerBackend.AArch64.ALU\nimport LeanCompilerBackend.AArch64.ABI\n','import LeanCompilerBackend.Semantics\n',1).replace('private def register',parts['ALU']+'private def register',1).replace('/-- Split frame adjustments',parts['ABI']+'/-- Split frame adjustments',1)
assert restored==before
r=json.loads((b/'extraction.json').read_text());sha=lambda s:hashlib.sha256(s.encode()).hexdigest()
assert sha(before)==r['before_sha256'] and sha(after)==r['facade_after_sha256']
assert all(sha(v)==r['moved_bodies'][k] for k,v in parts.items())
print('Moved bodies and inverse facade reconstruction are byte-identical.')
