"""C TLS interoperation for executable and shared-library target output."""
from pathlib import Path
from tls import SOURCE,CALLER


def exercise(compiler,work,run,cc,target):
    case=Path(work)/'tls-interop';case.mkdir(exist_ok=True)
    source,assembly,caller=case/'input.ssa',case/'lean.s',case/'caller.c'
    source.write_text(SOURCE);caller.write_text(CALLER)
    result=run([compiler,source,'--target',target,'-o',assembly]);assert result.returncode==0,result.stderr
    for shared in [False,True]:
        exe=case/('shared' if shared else 'static')
        if shared:
            library=case/'liblcb_tls.so'
            result=run([cc,'-fPIC','-shared',assembly,'-o',library],True);assert result.returncode==0,result.stderr
            command=[cc,'-pthread',caller,library,'-Wl,-rpath,$ORIGIN','-o',exe]
        else:command=[cc,'-pthread',caller,assembly,'-o',exe]
        result=run(command,True);assert result.returncode==0,result.stderr
        result=run([exe],True)
        assert result.returncode==0 and result.stdout=='TLS passed\n',(target,shared,result.returncode,result.stdout,result.stderr)
    print(f'{target}: eight-thread C TLS, live mixed arguments, external TLS and executable/shared-library interoperation passed',flush=True)
