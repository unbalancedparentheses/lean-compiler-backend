.text
.balign 16
.globl _long_then_word
_long_then_word:
	endbr64
	movl %edi, %eax
	addl $1, %eax
	ret
/* end function long_then_word */

.text
.balign 16
.globl _word_then_long
_word_then_long:
	endbr64
	movq %rdi, %rax
	addq $3, %rax
	ret
/* end function word_then_long */

.text
.balign 16
.globl _parameter_long
_parameter_long:
	endbr64
	movl %edi, %eax
	addl $17, %eax
	ret
/* end function parameter_long */

.text
.balign 16
.globl _parameter_word
_parameter_word:
	endbr64
	movq %rdi, %rax
	addq $23, %rax
	ret
/* end function parameter_word */

.text
.balign 16
.globl _branch
_branch:
	endbr64
	movl %esi, %edx
	andl $1, %edx
	movq %rdi, %rax
	addq $7, %rax
	movl %edi, %ecx
	addl $13, %ecx
	cmpl $0, %edx
	cmovz %ecx, %eax
	xorl $305419896, %eax
	ret
/* end function branch */

.text
.balign 16
.globl _loop
_loop:
	endbr64
	movq %rdi, %rax
	cmpl $0, %esi
	jz Lbb15
	movl %eax, %edi
	movl $0, %eax
.p2align 4
Lbb13:
	movl %edi, %ecx
	addl $3, %ecx
	movl %ecx, %ecx
	movq %rcx, %rdi
	addq $7, %rdi
	addl $1, %eax
	cmpl %esi, %eax
	jb Lbb13
	movl %edi, %eax
Lbb15:
	ret
/* end function loop */

.text
.balign 16
.globl _shift
_shift:
	endbr64
	movl %edi, %ecx
	addl %esi, %ecx
	movq %rdi, %rax
	shlq %cl, %rax
	ret
/* end function shift */

.text
.balign 16
_called:
	endbr64
	imull $7, %edi, %eax
	ret
/* end function called */

.text
.balign 16
.globl _call_word
_call_word:
	endbr64
	pushq %rbp
	movq %rsp, %rbp
	addl %esi, %edi
	callq _called
	leave
	ret
/* end function call_word */

.text
.balign 16
.globl _word_roles
_word_roles:
	endbr64
	movl %edi, %eax
	xorl %esi, %eax
	movq %rax, %xmm0
	movq %xmm0, %rax
	ret
/* end function word_roles */

.text
.balign 16
_effect:
	endbr64
	movl %edi, (%rsi)
	ret
/* end function effect */

.text
.balign 16
.globl _void_call_word
_void_call_word:
	endbr64
	pushq %rbp
	movq %rsp, %rbp
	subq $16, %rsp
	addl %esi, %edi
	movl $0, -8(%rbp)
	leaq -8(%rbp), %rsi
	callq _effect
	movl -8(%rbp), %eax
	leave
	ret
/* end function void_call_word */

