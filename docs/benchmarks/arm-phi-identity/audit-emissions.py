"""Check phi-copy deletions and newly exposed existing empty-branch rewrites."""
import argparse,json,re
from pathlib import Path

def copy(line):
    return bool(re.fullmatch(r'\tmov w(\d+), w\1',line) or re.fullmatch(r'\t(?:ldr|str) [wx]9, \[(?:sp|x29)(?:, #\d+)?\]',line))

def audit(old,new):
    a=old.splitlines();b=new.splitlines();i=j=removed=branches=0
    while i<len(a):
        if j<len(b) and a[i]==b[j]:i+=1;j+=1;continue
        if copy(a[i]):removed+=1;i+=1;continue
        m=re.fullmatch(r'(\tb\.[a-z]+ |\tcbz w[0-9]+, )(L_lcb_edge_.+)',a[i])
        assert m,('unexpected edit',i,j,a[i],b[j] if j<len(b) else None)
        k=i+1;copies=0
        while k<len(a) and copy(a[k]):k+=1;copies+=1
        assert a[k].startswith('\tb ')
        yes=a[k][3:];assert a[k+1]==m[2]+':'
        k+=2
        while k<len(a) and copy(a[k]):k+=1;copies+=1
        assert a[k].startswith('\tb ')
        no=a[k][3:];assert a[k+1]==yes+':'
        assert b[j]==m[1]+no and b[j+1]==yes+':'
        removed+=copies;branches+=2;i=k+1;j+=1
    assert j==len(b)
    return removed,branches

def main():
    p=argparse.ArgumentParser();p.add_argument('raw',type=Path);p.add_argument('output',type=Path);args=p.parse_args();d=json.loads(args.raw.read_text());work=Path(d['work']);inputs=sorted({r['input'] for r in d['cases']});changed=[]
    for r in d['cases']:
        if r['status']=='identical_refusal':continue
        assert r['before']['exit']==r['after']['exit']==0
        stem=f'{inputs.index(r["input"])}-{r["target"]}-{r["mode"]}'
        old=(work/(stem+'-before.s')).read_text();new=(work/(stem+'-after.s')).read_text()
        if r['target'].startswith('aarch64') and r['mode']!='baseline':copies,branches=audit(old,new)
        else:assert old==new;copies=branches=0
        if old!=new:changed.append({'input':r['input'],'target':r['target'],'mode':r['mode'],'copy_instructions_removed':copies,'branch_instructions_removed':branches})
    result={'status':'passed','compilers':d['compilers'],'unchanged_assemblies':d['identical_assemblies'],'matching_refusals':d['identical_refusals'],'changed_assemblies':len(changed),'copy_instructions_removed':sum(x['copy_instructions_removed'] for x in changed),'branch_instructions_removed':sum(x['branch_instructions_removed'] for x in changed),'cases':changed,'scope':'Only word self-moves/frame scratch9 copies deleted, plus the exact existing empty-conditional-trampoline rewrite when those deletions expose it. Not a semantic proof.'}
    args.output.write_text(json.dumps(result,indent=2)+'\n');print(result['changed_assemblies'],result['copy_instructions_removed'],result['branch_instructions_removed'])
if __name__=='__main__':main()
