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
            darwin=target.endswith('-macos')
            library=case/('liblcb_tls.dylib' if darwin else 'liblcb_tls.so')
            flags=['-dynamiclib','-Wl,-undefined,dynamic_lookup'] if darwin else ['-fPIC','-shared']
            dependencies=[];shared_caller=caller
            if darwin:
                # Mach-O needs a typed TLS definition at dylib link time;
                # dynamic_lookup alone treats the symbol as ordinary data.
                provider=case/'external.c';provider.write_text('#include <stdint.h>\n_Thread_local uint64_t external_tls=123;\n')
                dependency=case/'libexternal_tls.dylib'
                result=run([cc,'-dynamiclib',provider,'-o',dependency],True);assert result.returncode==0,result.stderr
                dependencies=[dependency]
                shared_caller=case/'shared-caller.c'
                shared_caller.write_text(CALLER.replace('_Thread_local uint64_t external_tls=123;', 'extern _Thread_local uint64_t external_tls;'))
            result=run([cc,*flags,assembly,*dependencies,'-o',library],True);assert result.returncode==0,result.stderr
            command=[cc,'-pthread',shared_caller,library,*dependencies,*([] if darwin else ['-Wl,-rpath,$ORIGIN']),'-o',exe]
        else:command=[cc,'-pthread',caller,assembly,'-o',exe]
        result=run(command,True);assert result.returncode==0,result.stderr
        result=run([exe],True)
        assert result.returncode==0 and result.stdout=='TLS passed\n',(target,shared,result.returncode,result.stdout,result.stderr)
    print(f'{target}: eight-thread C TLS, live mixed arguments, external TLS and executable/shared-library interoperation passed',flush=True)
