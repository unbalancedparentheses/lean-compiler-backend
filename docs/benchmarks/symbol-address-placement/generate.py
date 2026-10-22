from pathlib import Path
p=Path(__file__).parent
for n in [8,16,64,512]:
 ir=[f'export data $g{i} = align 8 {{ l 0, l 0, l 0 }}' for i in range(n)]+['export function l $pressure(l %seed) {','@s']
 acc='%seed'
 for i in range(n):
  ir += [f' %a{i} =l loadl $g{i}',f' %bp{i} =l add $g{i},8',f' %b{i} =l loadl %bp{i}',f' %cp{i} =l add $g{i},16',f' %c{i} =l loadl %cp{i}',f' %x{i} =l xor %a{i},%b{i}',f' %y{i} =l add %x{i},%c{i}',f' %m{i} =l mul {acc},33',f' %acc{i} =l add %m{i},%y{i}'];acc=f'%acc{i}'
 ir += [f' ret {acc}','}'];(p/f'globals-{n}.ssa').write_text('\n'.join(ir)+'\n')
