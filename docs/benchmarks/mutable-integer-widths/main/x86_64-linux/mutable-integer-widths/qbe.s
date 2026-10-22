.text
.balign 16
.globl long_then_word
long_then_word:
	endbr64
	movl %edi, %eax
	addl $1, %eax
	ret
.type long_then_word, @function
.size long_then_word, .-long_then_word
/* end function long_then_word */

.text
.balign 16
.globl word_then_long
word_then_long:
	endbr64
	movq %rdi, %rax
	addq $3, %rax
	ret
.type word_then_long, @function
.size word_then_long, .-word_then_long
/* end function word_then_long */

.text
.balign 16
.globl parameter_long
parameter_long:
	endbr64
	movl %edi, %eax
	addl $17, %eax
	ret
.type parameter_long, @function
.size parameter_long, .-parameter_long
/* end function parameter_long */

.text
.balign 16
.globl parameter_word
parameter_word:
	endbr64
	movq %rdi, %rax
	addq $23, %rax
	ret
.type parameter_word, @function
.size parameter_word, .-parameter_word
/* end function parameter_word */

.text
.balign 16
.globl branch
branch:
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
.type branch, @function
.size branch, .-branch
/* end function branch */

.text
.balign 16
.globl loop
loop:
	endbr64
	movq %rdi, %rax
	cmpl $0, %esi
	jz .Lbb15
	movl %eax, %edi
	movl $0, %eax
.p2align 4
.Lbb13:
	movl %edi, %ecx
	addl $3, %ecx
	movl %ecx, %ecx
	movq %rcx, %rdi
	addq $7, %rdi
	addl $1, %eax
	cmpl %esi, %eax
	jb .Lbb13
	movl %edi, %eax
.Lbb15:
	ret
.type loop, @function
.size loop, .-loop
/* end function loop */

.text
.balign 16
.globl shift
shift:
	endbr64
	movl %edi, %ecx
	addl %esi, %ecx
	movq %rdi, %rax
	shlq %cl, %rax
	ret
.type shift, @function
.size shift, .-shift
/* end function shift */

.text
.balign 16
called:
	endbr64
	imull $7, %edi, %eax
	ret
.type called, @function
.size called, .-called
/* end function called */

.text
.balign 16
.globl call_word
call_word:
	endbr64
	pushq %rbp
	movq %rsp, %rbp
	addl %esi, %edi
	callq called
	leave
	ret
.type call_word, @function
.size call_word, .-call_word
/* end function call_word */

.text
.balign 16
.globl word_roles
word_roles:
	endbr64
	movl %edi, %eax
	xorl %esi, %eax
	movq %rax, %xmm0
	movq %xmm0, %rax
	ret
.type word_roles, @function
.size word_roles, .-word_roles
/* end function word_roles */

.text
.balign 16
effect:
	endbr64
	movl %edi, (%rsi)
	ret
.type effect, @function
.size effect, .-effect
/* end function effect */

.text
.balign 16
.globl void_call_word
void_call_word:
	endbr64
	pushq %rbp
	movq %rsp, %rbp
	subq $16, %rsp
	addl %esi, %edi
	movl $0, -8(%rbp)
	leaq -8(%rbp), %rsi
	callq effect
	movl -8(%rbp), %eax
	leave
	ret
.type void_call_word, @function
.size void_call_word, .-void_call_word
/* end function void_call_word */

.section .note.GNU-stack,"",@progbits
