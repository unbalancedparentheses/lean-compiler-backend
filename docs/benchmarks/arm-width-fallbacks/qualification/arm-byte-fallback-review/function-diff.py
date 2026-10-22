from pathlib import Path
import re,json,hashlib
root=Path('/Users/unbalancedparen/projects/lean-compiler-backend/.build/linux-arm64/arm-byte-fallback-zlib-review');report={}
def functions(p):
 text=p.read_text();matches=list(re.finditer(r'(?:;|//) function ([^;\n]+);',text));return {m[1]:text[m.start():(matches[i+1].start() if i+1<len(matches) else len(text))] for i,m in enumerate(matches)}
def stats(s):return {'instructions':sum(bool(re.match(r'\t[a-z]',l)) for l in s.splitlines()),'narrow_indexed':len(re.findall(r'\tldr(?:b|h|sb|sh) [wx]\d+, \[x\d+, x\d+\]',s)),'wide_indexed':len(re.findall(r'\tldr(?:sw)? [wx]\d+, \[x\d+, x\d+\]',s))}
for target in ['aarch64-linux','aarch64-macos']:
 report[target]={}
 for mode in ['baseline','allocated','optimized']:
  rows={}
  for before in sorted((root/target/mode/'before').glob('*.s')):
   after=root/target/mode/'after'/before.name;left=functions(before);right=functions(after);assert left.keys()==right.keys()
   changes={n:{'before':stats(s),'after':stats(right[n])} for n,s in left.items() if s!=right[n]}
   # Mixed narrow widths intentionally remain indexed in this diagnostic.
   if changes:rows[before.stem]=changes
  report[target][mode]=rows
(root/'function-differences.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report['aarch64-linux']['optimized'],indent=2))
