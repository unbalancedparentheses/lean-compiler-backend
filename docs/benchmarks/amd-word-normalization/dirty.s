.text
.globl dirty
dirty:
 movabsq $0xdeadbeef80000001,%rax
 ret
