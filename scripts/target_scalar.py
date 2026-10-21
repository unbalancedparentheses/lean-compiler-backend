"""Reuse independent scalar/C matrices for each new Linux machine target."""
from pathlib import Path
import float_abi
import subword
import float_variadic
import floating
import conversions
import re


def qbe_subword_reference(source):
    """Pinned QBE omits narrow ABI extensions on RV64 and some AMD64 calls.

    Keep the Lean input unmodified; make extensions explicit only in the QBE
    reference. C callers still independently enforce the complete narrow ABI.
    """
    def function(match):
        text=match.group(0)
        result=re.match(r"export function (sb|ub|sh|uh) ",text)
        if result:
            text=re.sub(r" ret (%h\d+)",lambda m:f" %abi_result =w ext{result[1]} {m[1]}\n ret %abi_result",text)
        extensions=[]
        def argument(m):
            kind,name=m.groups();new="abi_"+name
            extensions.append(f" %{new} =w ext{kind} %{name}\n")
            return f"{kind} %{new}"
        text=re.sub(r"(sb|ub|sh|uh) %(raw\d+)",argument,text)
        if extensions:text=text.replace(" %r =", "".join(extensions)+" %r =")
        return text
    return re.sub(r"export function [\s\S]*?\n}",function,source)


def exercise(compiler, work, run, cc, qbe, target, qtarget, va_list_bytes):
    seeds=[0,1,(1<<64)-1,1<<63,0x123456789abcdef0]
    fixtures=[('float-abi',float_abi.source(),float_abi.caller(seeds)),
              ('subword',subword.fixture().replace('alloc8 8',f'alloc8 {va_list_bytes}'),subword.caller(seeds)),
              ('variadic',*float_variadic.fixture(va_list_bytes))]
    for name,source_text,caller_text in fixtures:
        case=Path(work)/('matrix-'+name);case.mkdir(exist_ok=True)
        source,assembly,caller=case/'input.ssa',case/'lean.s',case/'caller.c'
        source.write_text(source_text);caller.write_text(caller_text)
        result=run([compiler,source,'--target',target,'-o',assembly]);assert result.returncode==0,result.stderr
        qsource=source
        if name=='subword':
            qsource=case/'qbe-reference.ssa';qsource.write_text(qbe_subword_reference(source_text))
        qasm=case/'qbe.s';result=run([qbe,'-t',qtarget,'-o',qasm,qsource],True);assert result.returncode==0,result.stderr
        for label,asm in [('lean',assembly),('qbe',qasm)]:
            exe=case/label;result=run([cc,'-O2',caller,asm,'-o',exe],True);assert result.returncode==0,result.stderr
            result=run([exe],True);assert result.returncode==0,(name,label,result.returncode,result.stdout,result.stderr)
    for name,module in [('floating',floating),('conversions',conversions)]:
        matrix=module.matrix(20261020) if name=='floating' else module.cases(20261020)
        case=Path(work)/('matrix-'+name);case.mkdir(exist_ok=True)
        source,assembly,caller,ref=case/'input.ssa',case/'lean.s',case/'caller.c',case/'reference.c'
        source.write_text(module.fixture());caller.write_text(module.c_source(matrix,True));ref.write_text(module.c_source(matrix,False))
        result=run([compiler,source,'--target',target,'-o',assembly]);assert result.returncode==0,result.stderr
        qasm=case/'qbe.s';result=run([qbe,'-t',qtarget,'-o',qasm,source],True);assert result.returncode==0,result.stderr
        result=run([cc,'-O0',ref,'-lm','-o',case/'reference'],True);assert result.returncode==0,result.stderr
        result=run([case/'reference'],True);assert result.returncode==0,result.stderr
        expected=[int(x) for x in result.stdout.splitlines()]
        for label,asm in [('lean',assembly),('qbe',qasm)]:
            exe=case/label;result=run([cc,'-O0',caller,asm,'-lm','-o',exe],True);assert result.returncode==0,result.stderr
            result=run([exe],True);assert result.returncode==0,(name,label,result.returncode,result.stderr)
            actual=[int(x) for x in result.stdout.splitlines()];assert len(actual)==len(expected)
            for case_data,a,b in zip(matrix,actual,expected):
                key=case_data if name=='floating' else case_data[0]
                assert module.equivalent(key,a,b),(name,label,case_data,hex(a),hex(b))
    print(f'{target}: QBE subword reference uses explicit narrow extensions; Lean input and independent C ABI checks remain unchanged',flush=True)
    print(f'{target}: generated mixed scalar ABI/subword/variadic matrices and independent C floating/conversion oracles passed against QBE',flush=True)
