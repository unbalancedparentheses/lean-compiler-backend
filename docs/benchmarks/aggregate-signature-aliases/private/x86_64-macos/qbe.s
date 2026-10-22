.text
.balign 16
_echo_integer:
	endbr64
	pushq %rbp
	movq %rsp, %rbp
	subq $208, %rsp
	movq %rdi, -176(%rbp)
	movq %rsi, -168(%rbp)
	movq %rdx, -160(%rbp)
	movq %rcx, -152(%rbp)
	movq %r8, -144(%rbp)
	movq %r9, -136(%rbp)
	movaps %xmm0, -128(%rbp)
	movaps %xmm1, -112(%rbp)
	movaps %xmm2, -96(%rbp)
	movaps %xmm3, -80(%rbp)
	movaps %xmm4, -64(%rbp)
	movaps %xmm5, -48(%rbp)
	movaps %xmm6, -32(%rbp)
	movaps %xmm7, -16(%rbp)
	movq %rdi, -192(%rbp)
	movq %rsi, -184(%rbp)
	cmpl $0, %edx
	jz Lbb2
	subl $1, %edx
	movl $91, %ecx
	movq -192(%rbp), %rdi
	movq -184(%rbp), %rsi
	movl $0, %eax
	callq _echo_integer
	movq %rax, %rcx
	movq %rdx, %rax
	movq %rcx, -208(%rbp)
	movq %rax, -200(%rbp)
	movq -208(%rbp), %rax
	movq -200(%rbp), %rdx
	jmp Lbb3
Lbb2:
	movq -192(%rbp), %rax
	movq -184(%rbp), %rdx
Lbb3:
	leave
	ret
/* end function echo_integer */

.text
.balign 16
.globl _probe_integer_direct
_probe_integer_direct:
	endbr64
	pushq %rbp
	movq %rsp, %rbp
	subq $24, %rsp
	pushq %rbx
	movq %rdi, %rax
	movl $91, %ecx
	movl $2, %edx
	movq (%rax), %rdi
	movq %rsi, %rbx
	movq 8(%rax), %rsi
	movl $0, %eax
	callq _echo_integer
	movq %rbx, %rsi
	movq %rax, %rcx
	movq %rdx, %rax
	movq %rcx, -16(%rbp)
	movq %rax, -8(%rbp)
	movzbq -16(%rbp), %rax
	movb %al, (%rsi)
	movzbq -15(%rbp), %rcx
	movb %cl, 1(%rsi)
	addq %rcx, %rax
	movzbq -14(%rbp), %rcx
	movb %cl, 2(%rsi)
	addq %rcx, %rax
	movzbq -13(%rbp), %rcx
	movb %cl, 3(%rsi)
	addq %rcx, %rax
	movzbq -12(%rbp), %rcx
	movb %cl, 4(%rsi)
	addq %rcx, %rax
	movzbq -11(%rbp), %rcx
	movb %cl, 5(%rsi)
	addq %rcx, %rax
	movzbq -10(%rbp), %rcx
	movb %cl, 6(%rsi)
	addq %rcx, %rax
	movzbq -9(%rbp), %rcx
	movb %cl, 7(%rsi)
	addq %rcx, %rax
	movzbq -8(%rbp), %rcx
	movb %cl, 8(%rsi)
	addq %rcx, %rax
	movzbq -7(%rbp), %rcx
	movb %cl, 9(%rsi)
	addq %rcx, %rax
	movzbq -6(%rbp), %rcx
	movb %cl, 10(%rsi)
	addq %rcx, %rax
	movzbq -5(%rbp), %rcx
	movb %cl, 11(%rsi)
	addq %rcx, %rax
	movzbq -4(%rbp), %rcx
	movb %cl, 12(%rsi)
	addq %rcx, %rax
	movzbq -3(%rbp), %rcx
	movb %cl, 13(%rsi)
	addq %rcx, %rax
	movzbq -2(%rbp), %rcx
	movb %cl, 14(%rsi)
	addq %rcx, %rax
	movzbq -1(%rbp), %rcx
	movb %cl, 15(%rsi)
	addq %rcx, %rax
	popq %rbx
	leave
	ret
/* end function probe_integer_direct */

.text
.balign 16
.globl _probe_integer_indirect
_probe_integer_indirect:
	endbr64
	pushq %rbp
	movq %rsp, %rbp
	subq $24, %rsp
	pushq %rbx
	movq %rdi, %rax
	movl $91, %ecx
	movl $2, %edx
	movq (%rax), %rdi
	movq %rsi, %rbx
	movq 8(%rax), %rsi
	movl $0, %eax
	callq _echo_integer
	movq %rbx, %rsi
	movq %rax, %rcx
	movq %rdx, %rax
	movq %rcx, -16(%rbp)
	movq %rax, -8(%rbp)
	movzbq -16(%rbp), %rax
	movb %al, (%rsi)
	movzbq -15(%rbp), %rcx
	movb %cl, 1(%rsi)
	addq %rcx, %rax
	movzbq -14(%rbp), %rcx
	movb %cl, 2(%rsi)
	addq %rcx, %rax
	movzbq -13(%rbp), %rcx
	movb %cl, 3(%rsi)
	addq %rcx, %rax
	movzbq -12(%rbp), %rcx
	movb %cl, 4(%rsi)
	addq %rcx, %rax
	movzbq -11(%rbp), %rcx
	movb %cl, 5(%rsi)
	addq %rcx, %rax
	movzbq -10(%rbp), %rcx
	movb %cl, 6(%rsi)
	addq %rcx, %rax
	movzbq -9(%rbp), %rcx
	movb %cl, 7(%rsi)
	addq %rcx, %rax
	movzbq -8(%rbp), %rcx
	movb %cl, 8(%rsi)
	addq %rcx, %rax
	movzbq -7(%rbp), %rcx
	movb %cl, 9(%rsi)
	addq %rcx, %rax
	movzbq -6(%rbp), %rcx
	movb %cl, 10(%rsi)
	addq %rcx, %rax
	movzbq -5(%rbp), %rcx
	movb %cl, 11(%rsi)
	addq %rcx, %rax
	movzbq -4(%rbp), %rcx
	movb %cl, 12(%rsi)
	addq %rcx, %rax
	movzbq -3(%rbp), %rcx
	movb %cl, 13(%rsi)
	addq %rcx, %rax
	movzbq -2(%rbp), %rcx
	movb %cl, 14(%rsi)
	addq %rcx, %rax
	movzbq -1(%rbp), %rcx
	movb %cl, 15(%rsi)
	addq %rcx, %rax
	popq %rbx
	leave
	ret
/* end function probe_integer_indirect */

.text
.balign 16
_echo_floating:
	endbr64
	pushq %rbp
	movq %rsp, %rbp
	subq $208, %rsp
	movq %rdi, -176(%rbp)
	movq %rsi, -168(%rbp)
	movq %rdx, -160(%rbp)
	movq %rcx, -152(%rbp)
	movq %r8, -144(%rbp)
	movq %r9, -136(%rbp)
	movaps %xmm0, -128(%rbp)
	movaps %xmm1, -112(%rbp)
	movaps %xmm2, -96(%rbp)
	movaps %xmm3, -80(%rbp)
	movaps %xmm4, -64(%rbp)
	movaps %xmm5, -48(%rbp)
	movaps %xmm6, -32(%rbp)
	movaps %xmm7, -16(%rbp)
	movq %xmm0, -192(%rbp)
	movq %xmm1, -184(%rbp)
	cmpl $0, %edi
	jz Lbb10
	subl $1, %edi
	movl $91, %esi
	movsd -192(%rbp), %xmm0
	movsd -184(%rbp), %xmm1
	movl $2, %eax
	callq _echo_floating
	movsd %xmm0, %xmm15
	movsd %xmm1, %xmm0
	movsd %xmm15, %xmm1
	movq %xmm1, -208(%rbp)
	movq %xmm0, -200(%rbp)
	movq -208(%rbp), %xmm0
	movq -200(%rbp), %xmm1
	jmp Lbb11
Lbb10:
	movq -192(%rbp), %xmm0
	movq -184(%rbp), %xmm1
Lbb11:
	leave
	ret
/* end function echo_floating */

.text
.balign 16
.globl _probe_floating_direct
_probe_floating_direct:
	endbr64
	pushq %rbp
	movq %rsp, %rbp
	subq $24, %rsp
	pushq %rbx
	movq %rdi, %rax
	movq %rsi, %rbx
	movl $91, %esi
	movl $2, %edi
	movsd (%rax), %xmm0
	movsd 8(%rax), %xmm1
	movl $2, %eax
	callq _echo_floating
	movq %rbx, %rsi
	movsd %xmm0, %xmm15
	movsd %xmm1, %xmm0
	movsd %xmm15, %xmm1
	movq %xmm1, -16(%rbp)
	movq %xmm0, -8(%rbp)
	movzbq -16(%rbp), %rax
	movb %al, (%rsi)
	movzbq -15(%rbp), %rcx
	movb %cl, 1(%rsi)
	addq %rcx, %rax
	movzbq -14(%rbp), %rcx
	movb %cl, 2(%rsi)
	addq %rcx, %rax
	movzbq -13(%rbp), %rcx
	movb %cl, 3(%rsi)
	addq %rcx, %rax
	movzbq -12(%rbp), %rcx
	movb %cl, 4(%rsi)
	addq %rcx, %rax
	movzbq -11(%rbp), %rcx
	movb %cl, 5(%rsi)
	addq %rcx, %rax
	movzbq -10(%rbp), %rcx
	movb %cl, 6(%rsi)
	addq %rcx, %rax
	movzbq -9(%rbp), %rcx
	movb %cl, 7(%rsi)
	addq %rcx, %rax
	movzbq -8(%rbp), %rcx
	movb %cl, 8(%rsi)
	addq %rcx, %rax
	movzbq -7(%rbp), %rcx
	movb %cl, 9(%rsi)
	addq %rcx, %rax
	movzbq -6(%rbp), %rcx
	movb %cl, 10(%rsi)
	addq %rcx, %rax
	movzbq -5(%rbp), %rcx
	movb %cl, 11(%rsi)
	addq %rcx, %rax
	movzbq -4(%rbp), %rcx
	movb %cl, 12(%rsi)
	addq %rcx, %rax
	movzbq -3(%rbp), %rcx
	movb %cl, 13(%rsi)
	addq %rcx, %rax
	movzbq -2(%rbp), %rcx
	movb %cl, 14(%rsi)
	addq %rcx, %rax
	movzbq -1(%rbp), %rcx
	movb %cl, 15(%rsi)
	addq %rcx, %rax
	popq %rbx
	leave
	ret
/* end function probe_floating_direct */

.text
.balign 16
.globl _probe_floating_indirect
_probe_floating_indirect:
	endbr64
	pushq %rbp
	movq %rsp, %rbp
	subq $24, %rsp
	pushq %rbx
	movq %rdi, %rax
	movq %rsi, %rbx
	movl $91, %esi
	movl $2, %edi
	movsd (%rax), %xmm0
	movsd 8(%rax), %xmm1
	movl $2, %eax
	callq _echo_floating
	movq %rbx, %rsi
	movsd %xmm0, %xmm15
	movsd %xmm1, %xmm0
	movsd %xmm15, %xmm1
	movq %xmm1, -16(%rbp)
	movq %xmm0, -8(%rbp)
	movzbq -16(%rbp), %rax
	movb %al, (%rsi)
	movzbq -15(%rbp), %rcx
	movb %cl, 1(%rsi)
	addq %rcx, %rax
	movzbq -14(%rbp), %rcx
	movb %cl, 2(%rsi)
	addq %rcx, %rax
	movzbq -13(%rbp), %rcx
	movb %cl, 3(%rsi)
	addq %rcx, %rax
	movzbq -12(%rbp), %rcx
	movb %cl, 4(%rsi)
	addq %rcx, %rax
	movzbq -11(%rbp), %rcx
	movb %cl, 5(%rsi)
	addq %rcx, %rax
	movzbq -10(%rbp), %rcx
	movb %cl, 6(%rsi)
	addq %rcx, %rax
	movzbq -9(%rbp), %rcx
	movb %cl, 7(%rsi)
	addq %rcx, %rax
	movzbq -8(%rbp), %rcx
	movb %cl, 8(%rsi)
	addq %rcx, %rax
	movzbq -7(%rbp), %rcx
	movb %cl, 9(%rsi)
	addq %rcx, %rax
	movzbq -6(%rbp), %rcx
	movb %cl, 10(%rsi)
	addq %rcx, %rax
	movzbq -5(%rbp), %rcx
	movb %cl, 11(%rsi)
	addq %rcx, %rax
	movzbq -4(%rbp), %rcx
	movb %cl, 12(%rsi)
	addq %rcx, %rax
	movzbq -3(%rbp), %rcx
	movb %cl, 13(%rsi)
	addq %rcx, %rax
	movzbq -2(%rbp), %rcx
	movb %cl, 14(%rsi)
	addq %rcx, %rax
	movzbq -1(%rbp), %rcx
	movb %cl, 15(%rsi)
	addq %rcx, %rax
	popq %rbx
	leave
	ret
/* end function probe_floating_indirect */

.text
.balign 16
_echo_mixed:
	endbr64
	pushq %rbp
	movq %rsp, %rbp
	subq $208, %rsp
	movq %rdi, -176(%rbp)
	movq %rsi, -168(%rbp)
	movq %rdx, -160(%rbp)
	movq %rcx, -152(%rbp)
	movq %r8, -144(%rbp)
	movq %r9, -136(%rbp)
	movaps %xmm0, -128(%rbp)
	movaps %xmm1, -112(%rbp)
	movaps %xmm2, -96(%rbp)
	movaps %xmm3, -80(%rbp)
	movaps %xmm4, -64(%rbp)
	movaps %xmm5, -48(%rbp)
	movaps %xmm6, -32(%rbp)
	movaps %xmm7, -16(%rbp)
	movq %xmm0, -192(%rbp)
	movq %rdi, -184(%rbp)
	cmpl $0, %esi
	jz Lbb18
	subl $1, %esi
	movl $91, %edx
	movsd -192(%rbp), %xmm0
	movq -184(%rbp), %rdi
	movl $1, %eax
	callq _echo_mixed
	movq %xmm0, -208(%rbp)
	movq %rax, -200(%rbp)
	movq -208(%rbp), %xmm0
	movq -200(%rbp), %rax
	jmp Lbb19
Lbb18:
	movq -192(%rbp), %xmm0
	movq -184(%rbp), %rax
Lbb19:
	leave
	ret
/* end function echo_mixed */

.text
.balign 16
.globl _probe_mixed_direct
_probe_mixed_direct:
	endbr64
	pushq %rbp
	movq %rsp, %rbp
	subq $24, %rsp
	pushq %rbx
	movl $91, %edx
	movq %rsi, %rbx
	movl $2, %esi
	movsd (%rdi), %xmm0
	movq 8(%rdi), %rdi
	movl $1, %eax
	callq _echo_mixed
	movq %rbx, %rsi
	movq %xmm0, -16(%rbp)
	movq %rax, -8(%rbp)
	movzbq -16(%rbp), %rax
	movb %al, (%rsi)
	movzbq -15(%rbp), %rcx
	movb %cl, 1(%rsi)
	addq %rcx, %rax
	movzbq -14(%rbp), %rcx
	movb %cl, 2(%rsi)
	addq %rcx, %rax
	movzbq -13(%rbp), %rcx
	movb %cl, 3(%rsi)
	addq %rcx, %rax
	movzbq -12(%rbp), %rcx
	movb %cl, 4(%rsi)
	addq %rcx, %rax
	movzbq -11(%rbp), %rcx
	movb %cl, 5(%rsi)
	addq %rcx, %rax
	movzbq -10(%rbp), %rcx
	movb %cl, 6(%rsi)
	addq %rcx, %rax
	movzbq -9(%rbp), %rcx
	movb %cl, 7(%rsi)
	addq %rcx, %rax
	movzbq -8(%rbp), %rcx
	movb %cl, 8(%rsi)
	addq %rcx, %rax
	movzbq -7(%rbp), %rcx
	movb %cl, 9(%rsi)
	addq %rcx, %rax
	movzbq -6(%rbp), %rcx
	movb %cl, 10(%rsi)
	addq %rcx, %rax
	movzbq -5(%rbp), %rcx
	movb %cl, 11(%rsi)
	addq %rcx, %rax
	movzbq -4(%rbp), %rcx
	movb %cl, 12(%rsi)
	addq %rcx, %rax
	movzbq -3(%rbp), %rcx
	movb %cl, 13(%rsi)
	addq %rcx, %rax
	movzbq -2(%rbp), %rcx
	movb %cl, 14(%rsi)
	addq %rcx, %rax
	movzbq -1(%rbp), %rcx
	movb %cl, 15(%rsi)
	addq %rcx, %rax
	popq %rbx
	leave
	ret
/* end function probe_mixed_direct */

.text
.balign 16
.globl _probe_mixed_indirect
_probe_mixed_indirect:
	endbr64
	pushq %rbp
	movq %rsp, %rbp
	subq $24, %rsp
	pushq %rbx
	movl $91, %edx
	movq %rsi, %rbx
	movl $2, %esi
	movsd (%rdi), %xmm0
	movq 8(%rdi), %rdi
	movl $1, %eax
	callq _echo_mixed
	movq %rbx, %rsi
	movq %xmm0, -16(%rbp)
	movq %rax, -8(%rbp)
	movzbq -16(%rbp), %rax
	movb %al, (%rsi)
	movzbq -15(%rbp), %rcx
	movb %cl, 1(%rsi)
	addq %rcx, %rax
	movzbq -14(%rbp), %rcx
	movb %cl, 2(%rsi)
	addq %rcx, %rax
	movzbq -13(%rbp), %rcx
	movb %cl, 3(%rsi)
	addq %rcx, %rax
	movzbq -12(%rbp), %rcx
	movb %cl, 4(%rsi)
	addq %rcx, %rax
	movzbq -11(%rbp), %rcx
	movb %cl, 5(%rsi)
	addq %rcx, %rax
	movzbq -10(%rbp), %rcx
	movb %cl, 6(%rsi)
	addq %rcx, %rax
	movzbq -9(%rbp), %rcx
	movb %cl, 7(%rsi)
	addq %rcx, %rax
	movzbq -8(%rbp), %rcx
	movb %cl, 8(%rsi)
	addq %rcx, %rax
	movzbq -7(%rbp), %rcx
	movb %cl, 9(%rsi)
	addq %rcx, %rax
	movzbq -6(%rbp), %rcx
	movb %cl, 10(%rsi)
	addq %rcx, %rax
	movzbq -5(%rbp), %rcx
	movb %cl, 11(%rsi)
	addq %rcx, %rax
	movzbq -4(%rbp), %rcx
	movb %cl, 12(%rsi)
	addq %rcx, %rax
	movzbq -3(%rbp), %rcx
	movb %cl, 13(%rsi)
	addq %rcx, %rax
	movzbq -2(%rbp), %rcx
	movb %cl, 14(%rsi)
	addq %rcx, %rax
	movzbq -1(%rbp), %rcx
	movb %cl, 15(%rsi)
	addq %rcx, %rax
	popq %rbx
	leave
	ret
/* end function probe_mixed_indirect */

.text
.balign 16
_echo_hidden:
	endbr64
	pushq %rbp
	movq %rsp, %rbp
	subq $216, %rsp
	movq %rdi, -176(%rbp)
	movq %rsi, -168(%rbp)
	movq %rdx, -160(%rbp)
	movq %rcx, -152(%rbp)
	movq %r8, -144(%rbp)
	movq %r9, -136(%rbp)
	movaps %xmm0, -128(%rbp)
	movaps %xmm1, -112(%rbp)
	movaps %xmm2, -96(%rbp)
	movaps %xmm3, -80(%rbp)
	movaps %xmm4, -64(%rbp)
	movaps %xmm5, -48(%rbp)
	movaps %xmm6, -32(%rbp)
	movaps %xmm7, -16(%rbp)
	pushq %rbx
	movq %rdi, %rax
	cmpl $0, %esi
	jz Lbb26
	subl $1, %esi
	subq $32, %rsp
	movq %rsp, %rdx
	movq 16(%rbp), %rcx
	movq %rcx, 0(%rdx)
	movq 24(%rbp), %rcx
	movq %rcx, 8(%rdx)
	movq 32(%rbp), %rcx
	movq %rcx, 16(%rdx)
	movq 40(%rbp), %rcx
	movq %rcx, 24(%rdx)
	movl $91, %edx
	leaq -208(%rbp), %rdi
	movq %rax, %rbx
	movl $0, %eax
	callq _echo_hidden
	movq %rax, %rcx
	movq %rbx, %rax
	subq $-32, %rsp
	movq 0(%rcx), %rdx
	movq %rdx, 0(%rax)
	movq 8(%rcx), %rdx
	movq %rdx, 8(%rax)
	movq 16(%rcx), %rdx
	movq %rdx, 16(%rax)
	movq 24(%rcx), %rcx
	movq %rcx, 24(%rax)
	jmp Lbb27
Lbb26:
	movq 16(%rbp), %rcx
	movq %rcx, 0(%rax)
	movq 24(%rbp), %rcx
	movq %rcx, 8(%rax)
	movq 32(%rbp), %rcx
	movq %rcx, 16(%rax)
	movq 40(%rbp), %rcx
	movq %rcx, 24(%rax)
Lbb27:
	popq %rbx
	leave
	ret
/* end function echo_hidden */

.text
.balign 16
.globl _probe_hidden_direct
_probe_hidden_direct:
	endbr64
	pushq %rbp
	movq %rsp, %rbp
	subq $40, %rsp
	pushq %rbx
	subq $32, %rsp
	movq %rsp, %rcx
	movq 0(%rdi), %rax
	movq %rax, 0(%rcx)
	movq 8(%rdi), %rax
	movq %rax, 8(%rcx)
	movq 16(%rdi), %rax
	movq %rax, 16(%rcx)
	movq 24(%rdi), %rax
	movq %rax, 24(%rcx)
	movl $91, %edx
	movq %rsi, %rbx
	movl $2, %esi
	leaq -32(%rbp), %rdi
	movl $0, %eax
	callq _echo_hidden
	movq %rbx, %rsi
	movq %rax, %rcx
	subq $-32, %rsp
	movzbq (%rcx), %rax
	movb %al, (%rsi)
	movzbq 1(%rcx), %rdx
	movb %dl, 1(%rsi)
	addq %rdx, %rax
	movzbq 2(%rcx), %rdx
	movb %dl, 2(%rsi)
	addq %rdx, %rax
	movzbq 3(%rcx), %rdx
	movb %dl, 3(%rsi)
	addq %rdx, %rax
	movzbq 4(%rcx), %rdx
	movb %dl, 4(%rsi)
	addq %rdx, %rax
	movzbq 5(%rcx), %rdx
	movb %dl, 5(%rsi)
	addq %rdx, %rax
	movzbq 6(%rcx), %rdx
	movb %dl, 6(%rsi)
	addq %rdx, %rax
	movzbq 7(%rcx), %rdx
	movb %dl, 7(%rsi)
	addq %rdx, %rax
	movzbq 8(%rcx), %rdx
	movb %dl, 8(%rsi)
	addq %rdx, %rax
	movzbq 9(%rcx), %rdx
	movb %dl, 9(%rsi)
	addq %rdx, %rax
	movzbq 10(%rcx), %rdx
	movb %dl, 10(%rsi)
	addq %rdx, %rax
	movzbq 11(%rcx), %rdx
	movb %dl, 11(%rsi)
	addq %rdx, %rax
	movzbq 12(%rcx), %rdx
	movb %dl, 12(%rsi)
	addq %rdx, %rax
	movzbq 13(%rcx), %rdx
	movb %dl, 13(%rsi)
	addq %rdx, %rax
	movzbq 14(%rcx), %rdx
	movb %dl, 14(%rsi)
	addq %rdx, %rax
	movzbq 15(%rcx), %rdx
	movb %dl, 15(%rsi)
	addq %rdx, %rax
	movzbq 16(%rcx), %rdx
	movb %dl, 16(%rsi)
	addq %rdx, %rax
	movzbq 17(%rcx), %rdx
	movb %dl, 17(%rsi)
	addq %rdx, %rax
	movzbq 18(%rcx), %rdx
	movb %dl, 18(%rsi)
	addq %rdx, %rax
	movzbq 19(%rcx), %rdx
	movb %dl, 19(%rsi)
	addq %rdx, %rax
	movzbq 20(%rcx), %rdx
	movb %dl, 20(%rsi)
	addq %rdx, %rax
	movzbq 21(%rcx), %rdx
	movb %dl, 21(%rsi)
	addq %rdx, %rax
	movzbq 22(%rcx), %rdx
	movb %dl, 22(%rsi)
	addq %rdx, %rax
	movzbq 23(%rcx), %rdx
	movb %dl, 23(%rsi)
	addq %rdx, %rax
	movzbq 24(%rcx), %rdx
	movb %dl, 24(%rsi)
	addq %rdx, %rax
	movzbq 25(%rcx), %rdx
	movb %dl, 25(%rsi)
	addq %rdx, %rax
	movzbq 26(%rcx), %rdx
	movb %dl, 26(%rsi)
	addq %rdx, %rax
	movzbq 27(%rcx), %rdx
	movb %dl, 27(%rsi)
	addq %rdx, %rax
	movzbq 28(%rcx), %rdx
	movb %dl, 28(%rsi)
	addq %rdx, %rax
	movzbq 29(%rcx), %rdx
	movb %dl, 29(%rsi)
	addq %rdx, %rax
	movzbq 30(%rcx), %rdx
	movb %dl, 30(%rsi)
	addq %rdx, %rax
	movzbq 31(%rcx), %rcx
	movb %cl, 31(%rsi)
	addq %rcx, %rax
	popq %rbx
	leave
	ret
/* end function probe_hidden_direct */

.text
.balign 16
.globl _probe_hidden_indirect
_probe_hidden_indirect:
	endbr64
	pushq %rbp
	movq %rsp, %rbp
	subq $40, %rsp
	pushq %rbx
	subq $32, %rsp
	movq %rsp, %rcx
	movq 0(%rdi), %rax
	movq %rax, 0(%rcx)
	movq 8(%rdi), %rax
	movq %rax, 8(%rcx)
	movq 16(%rdi), %rax
	movq %rax, 16(%rcx)
	movq 24(%rdi), %rax
	movq %rax, 24(%rcx)
	movl $91, %edx
	movq %rsi, %rbx
	movl $2, %esi
	leaq -32(%rbp), %rdi
	movl $0, %eax
	callq _echo_hidden
	movq %rbx, %rsi
	movq %rax, %rcx
	subq $-32, %rsp
	movzbq (%rcx), %rax
	movb %al, (%rsi)
	movzbq 1(%rcx), %rdx
	movb %dl, 1(%rsi)
	addq %rdx, %rax
	movzbq 2(%rcx), %rdx
	movb %dl, 2(%rsi)
	addq %rdx, %rax
	movzbq 3(%rcx), %rdx
	movb %dl, 3(%rsi)
	addq %rdx, %rax
	movzbq 4(%rcx), %rdx
	movb %dl, 4(%rsi)
	addq %rdx, %rax
	movzbq 5(%rcx), %rdx
	movb %dl, 5(%rsi)
	addq %rdx, %rax
	movzbq 6(%rcx), %rdx
	movb %dl, 6(%rsi)
	addq %rdx, %rax
	movzbq 7(%rcx), %rdx
	movb %dl, 7(%rsi)
	addq %rdx, %rax
	movzbq 8(%rcx), %rdx
	movb %dl, 8(%rsi)
	addq %rdx, %rax
	movzbq 9(%rcx), %rdx
	movb %dl, 9(%rsi)
	addq %rdx, %rax
	movzbq 10(%rcx), %rdx
	movb %dl, 10(%rsi)
	addq %rdx, %rax
	movzbq 11(%rcx), %rdx
	movb %dl, 11(%rsi)
	addq %rdx, %rax
	movzbq 12(%rcx), %rdx
	movb %dl, 12(%rsi)
	addq %rdx, %rax
	movzbq 13(%rcx), %rdx
	movb %dl, 13(%rsi)
	addq %rdx, %rax
	movzbq 14(%rcx), %rdx
	movb %dl, 14(%rsi)
	addq %rdx, %rax
	movzbq 15(%rcx), %rdx
	movb %dl, 15(%rsi)
	addq %rdx, %rax
	movzbq 16(%rcx), %rdx
	movb %dl, 16(%rsi)
	addq %rdx, %rax
	movzbq 17(%rcx), %rdx
	movb %dl, 17(%rsi)
	addq %rdx, %rax
	movzbq 18(%rcx), %rdx
	movb %dl, 18(%rsi)
	addq %rdx, %rax
	movzbq 19(%rcx), %rdx
	movb %dl, 19(%rsi)
	addq %rdx, %rax
	movzbq 20(%rcx), %rdx
	movb %dl, 20(%rsi)
	addq %rdx, %rax
	movzbq 21(%rcx), %rdx
	movb %dl, 21(%rsi)
	addq %rdx, %rax
	movzbq 22(%rcx), %rdx
	movb %dl, 22(%rsi)
	addq %rdx, %rax
	movzbq 23(%rcx), %rdx
	movb %dl, 23(%rsi)
	addq %rdx, %rax
	movzbq 24(%rcx), %rdx
	movb %dl, 24(%rsi)
	addq %rdx, %rax
	movzbq 25(%rcx), %rdx
	movb %dl, 25(%rsi)
	addq %rdx, %rax
	movzbq 26(%rcx), %rdx
	movb %dl, 26(%rsi)
	addq %rdx, %rax
	movzbq 27(%rcx), %rdx
	movb %dl, 27(%rsi)
	addq %rdx, %rax
	movzbq 28(%rcx), %rdx
	movb %dl, 28(%rsi)
	addq %rdx, %rax
	movzbq 29(%rcx), %rdx
	movb %dl, 29(%rsi)
	addq %rdx, %rax
	movzbq 30(%rcx), %rdx
	movb %dl, 30(%rsi)
	addq %rdx, %rax
	movzbq 31(%rcx), %rcx
	movb %cl, 31(%rsi)
	addq %rcx, %rax
	popq %rbx
	leave
	ret
/* end function probe_hidden_indirect */

.text
.balign 16
_echo_union:
	endbr64
	pushq %rbp
	movq %rsp, %rbp
	subq $208, %rsp
	movq %rdi, -176(%rbp)
	movq %rsi, -168(%rbp)
	movq %rdx, -160(%rbp)
	movq %rcx, -152(%rbp)
	movq %r8, -144(%rbp)
	movq %r9, -136(%rbp)
	movaps %xmm0, -128(%rbp)
	movaps %xmm1, -112(%rbp)
	movaps %xmm2, -96(%rbp)
	movaps %xmm3, -80(%rbp)
	movaps %xmm4, -64(%rbp)
	movaps %xmm5, -48(%rbp)
	movaps %xmm6, -32(%rbp)
	movaps %xmm7, -16(%rbp)
	movq %rdi, -192(%rbp)
	movq %rsi, -184(%rbp)
	cmpl $0, %edx
	jz Lbb34
	subl $1, %edx
	movl $91, %ecx
	movq -192(%rbp), %rdi
	movq -184(%rbp), %rsi
	movl $0, %eax
	callq _echo_union
	movq %rax, %rcx
	movq %rdx, %rax
	movq %rcx, -208(%rbp)
	movq %rax, -200(%rbp)
	movq -208(%rbp), %rax
	movq -200(%rbp), %rdx
	jmp Lbb35
Lbb34:
	movq -192(%rbp), %rax
	movq -184(%rbp), %rdx
Lbb35:
	leave
	ret
/* end function echo_union */

.text
.balign 16
.globl _probe_union_direct
_probe_union_direct:
	endbr64
	pushq %rbp
	movq %rsp, %rbp
	subq $24, %rsp
	pushq %rbx
	movq %rdi, %rax
	movl $91, %ecx
	movl $2, %edx
	movq (%rax), %rdi
	movq %rsi, %rbx
	movq 8(%rax), %rsi
	movl $0, %eax
	callq _echo_union
	movq %rbx, %rsi
	movq %rax, %rcx
	movq %rdx, %rax
	movq %rcx, -16(%rbp)
	movq %rax, -8(%rbp)
	movzbq -16(%rbp), %rax
	movb %al, (%rsi)
	movzbq -15(%rbp), %rcx
	movb %cl, 1(%rsi)
	addq %rcx, %rax
	movzbq -14(%rbp), %rcx
	movb %cl, 2(%rsi)
	addq %rcx, %rax
	movzbq -13(%rbp), %rcx
	movb %cl, 3(%rsi)
	addq %rcx, %rax
	movzbq -12(%rbp), %rcx
	movb %cl, 4(%rsi)
	addq %rcx, %rax
	movzbq -11(%rbp), %rcx
	movb %cl, 5(%rsi)
	addq %rcx, %rax
	movzbq -10(%rbp), %rcx
	movb %cl, 6(%rsi)
	addq %rcx, %rax
	movzbq -9(%rbp), %rcx
	movb %cl, 7(%rsi)
	addq %rcx, %rax
	movzbq -8(%rbp), %rcx
	movb %cl, 8(%rsi)
	addq %rcx, %rax
	movzbq -7(%rbp), %rcx
	movb %cl, 9(%rsi)
	addq %rcx, %rax
	movzbq -6(%rbp), %rcx
	movb %cl, 10(%rsi)
	addq %rcx, %rax
	movzbq -5(%rbp), %rcx
	movb %cl, 11(%rsi)
	addq %rcx, %rax
	movzbq -4(%rbp), %rcx
	movb %cl, 12(%rsi)
	addq %rcx, %rax
	movzbq -3(%rbp), %rcx
	movb %cl, 13(%rsi)
	addq %rcx, %rax
	movzbq -2(%rbp), %rcx
	movb %cl, 14(%rsi)
	addq %rcx, %rax
	movzbq -1(%rbp), %rcx
	movb %cl, 15(%rsi)
	addq %rcx, %rax
	popq %rbx
	leave
	ret
/* end function probe_union_direct */

.text
.balign 16
.globl _probe_union_indirect
_probe_union_indirect:
	endbr64
	pushq %rbp
	movq %rsp, %rbp
	subq $24, %rsp
	pushq %rbx
	movq %rdi, %rax
	movl $91, %ecx
	movl $2, %edx
	movq (%rax), %rdi
	movq %rsi, %rbx
	movq 8(%rax), %rsi
	movl $0, %eax
	callq _echo_union
	movq %rbx, %rsi
	movq %rax, %rcx
	movq %rdx, %rax
	movq %rcx, -16(%rbp)
	movq %rax, -8(%rbp)
	movzbq -16(%rbp), %rax
	movb %al, (%rsi)
	movzbq -15(%rbp), %rcx
	movb %cl, 1(%rsi)
	addq %rcx, %rax
	movzbq -14(%rbp), %rcx
	movb %cl, 2(%rsi)
	addq %rcx, %rax
	movzbq -13(%rbp), %rcx
	movb %cl, 3(%rsi)
	addq %rcx, %rax
	movzbq -12(%rbp), %rcx
	movb %cl, 4(%rsi)
	addq %rcx, %rax
	movzbq -11(%rbp), %rcx
	movb %cl, 5(%rsi)
	addq %rcx, %rax
	movzbq -10(%rbp), %rcx
	movb %cl, 6(%rsi)
	addq %rcx, %rax
	movzbq -9(%rbp), %rcx
	movb %cl, 7(%rsi)
	addq %rcx, %rax
	movzbq -8(%rbp), %rcx
	movb %cl, 8(%rsi)
	addq %rcx, %rax
	movzbq -7(%rbp), %rcx
	movb %cl, 9(%rsi)
	addq %rcx, %rax
	movzbq -6(%rbp), %rcx
	movb %cl, 10(%rsi)
	addq %rcx, %rax
	movzbq -5(%rbp), %rcx
	movb %cl, 11(%rsi)
	addq %rcx, %rax
	movzbq -4(%rbp), %rcx
	movb %cl, 12(%rsi)
	addq %rcx, %rax
	movzbq -3(%rbp), %rcx
	movb %cl, 13(%rsi)
	addq %rcx, %rax
	movzbq -2(%rbp), %rcx
	movb %cl, 14(%rsi)
	addq %rcx, %rax
	movzbq -1(%rbp), %rcx
	movb %cl, 15(%rsi)
	addq %rcx, %rax
	popq %rbx
	leave
	ret
/* end function probe_union_indirect */

.text
.balign 16
_echo_opaque:
	endbr64
	pushq %rbp
	movq %rsp, %rbp
	subq $216, %rsp
	movq %rdi, -176(%rbp)
	movq %rsi, -168(%rbp)
	movq %rdx, -160(%rbp)
	movq %rcx, -152(%rbp)
	movq %r8, -144(%rbp)
	movq %r9, -136(%rbp)
	movaps %xmm0, -128(%rbp)
	movaps %xmm1, -112(%rbp)
	movaps %xmm2, -96(%rbp)
	movaps %xmm3, -80(%rbp)
	movaps %xmm4, -64(%rbp)
	movaps %xmm5, -48(%rbp)
	movaps %xmm6, -32(%rbp)
	movaps %xmm7, -16(%rbp)
	pushq %rbx
	movq %rdi, %rax
	cmpl $0, %esi
	jz Lbb42
	subl $1, %esi
	subq $32, %rsp
	movq %rsp, %rdx
	movq 16(%rbp), %rcx
	movq %rcx, 0(%rdx)
	movq 24(%rbp), %rcx
	movq %rcx, 8(%rdx)
	movq 32(%rbp), %rcx
	movq %rcx, 16(%rdx)
	movl $91, %edx
	leaq -200(%rbp), %rdi
	movq %rax, %rbx
	movl $0, %eax
	callq _echo_opaque
	movq %rax, %rcx
	movq %rbx, %rax
	subq $-32, %rsp
	movq 0(%rcx), %rdx
	movq %rdx, 0(%rax)
	movq 8(%rcx), %rdx
	movq %rdx, 8(%rax)
	movq 16(%rcx), %rcx
	movq %rcx, 16(%rax)
	jmp Lbb43
Lbb42:
	movq 16(%rbp), %rcx
	movq %rcx, 0(%rax)
	movq 24(%rbp), %rcx
	movq %rcx, 8(%rax)
	movq 32(%rbp), %rcx
	movq %rcx, 16(%rax)
Lbb43:
	popq %rbx
	leave
	ret
/* end function echo_opaque */

.text
.balign 16
.globl _probe_opaque_direct
_probe_opaque_direct:
	endbr64
	pushq %rbp
	movq %rsp, %rbp
	subq $40, %rsp
	pushq %rbx
	subq $32, %rsp
	movq %rsp, %rcx
	movq 0(%rdi), %rax
	movq %rax, 0(%rcx)
	movq 8(%rdi), %rax
	movq %rax, 8(%rcx)
	movq 16(%rdi), %rax
	movq %rax, 16(%rcx)
	movl $91, %edx
	movq %rsi, %rbx
	movl $2, %esi
	leaq -24(%rbp), %rdi
	movl $0, %eax
	callq _echo_opaque
	movq %rbx, %rsi
	movq %rax, %rcx
	subq $-32, %rsp
	movzbq (%rcx), %rax
	movb %al, (%rsi)
	movzbq 1(%rcx), %rdx
	movb %dl, 1(%rsi)
	addq %rdx, %rax
	movzbq 2(%rcx), %rdx
	movb %dl, 2(%rsi)
	addq %rdx, %rax
	movzbq 3(%rcx), %rdx
	movb %dl, 3(%rsi)
	addq %rdx, %rax
	movzbq 4(%rcx), %rdx
	movb %dl, 4(%rsi)
	addq %rdx, %rax
	movzbq 5(%rcx), %rdx
	movb %dl, 5(%rsi)
	addq %rdx, %rax
	movzbq 6(%rcx), %rdx
	movb %dl, 6(%rsi)
	addq %rdx, %rax
	movzbq 7(%rcx), %rdx
	movb %dl, 7(%rsi)
	addq %rdx, %rax
	movzbq 8(%rcx), %rdx
	movb %dl, 8(%rsi)
	addq %rdx, %rax
	movzbq 9(%rcx), %rdx
	movb %dl, 9(%rsi)
	addq %rdx, %rax
	movzbq 10(%rcx), %rdx
	movb %dl, 10(%rsi)
	addq %rdx, %rax
	movzbq 11(%rcx), %rdx
	movb %dl, 11(%rsi)
	addq %rdx, %rax
	movzbq 12(%rcx), %rdx
	movb %dl, 12(%rsi)
	addq %rdx, %rax
	movzbq 13(%rcx), %rdx
	movb %dl, 13(%rsi)
	addq %rdx, %rax
	movzbq 14(%rcx), %rdx
	movb %dl, 14(%rsi)
	addq %rdx, %rax
	movzbq 15(%rcx), %rdx
	movb %dl, 15(%rsi)
	addq %rdx, %rax
	movzbq 16(%rcx), %rdx
	movb %dl, 16(%rsi)
	addq %rdx, %rax
	movzbq 17(%rcx), %rdx
	movb %dl, 17(%rsi)
	addq %rdx, %rax
	movzbq 18(%rcx), %rdx
	movb %dl, 18(%rsi)
	addq %rdx, %rax
	movzbq 19(%rcx), %rdx
	movb %dl, 19(%rsi)
	addq %rdx, %rax
	movzbq 20(%rcx), %rdx
	movb %dl, 20(%rsi)
	addq %rdx, %rax
	movzbq 21(%rcx), %rdx
	movb %dl, 21(%rsi)
	addq %rdx, %rax
	movzbq 22(%rcx), %rdx
	movb %dl, 22(%rsi)
	addq %rdx, %rax
	movzbq 23(%rcx), %rcx
	movb %cl, 23(%rsi)
	addq %rcx, %rax
	popq %rbx
	leave
	ret
/* end function probe_opaque_direct */

.text
.balign 16
.globl _probe_opaque_indirect
_probe_opaque_indirect:
	endbr64
	pushq %rbp
	movq %rsp, %rbp
	subq $40, %rsp
	pushq %rbx
	subq $32, %rsp
	movq %rsp, %rcx
	movq 0(%rdi), %rax
	movq %rax, 0(%rcx)
	movq 8(%rdi), %rax
	movq %rax, 8(%rcx)
	movq 16(%rdi), %rax
	movq %rax, 16(%rcx)
	movl $91, %edx
	movq %rsi, %rbx
	movl $2, %esi
	leaq -24(%rbp), %rdi
	movl $0, %eax
	callq _echo_opaque
	movq %rbx, %rsi
	movq %rax, %rcx
	subq $-32, %rsp
	movzbq (%rcx), %rax
	movb %al, (%rsi)
	movzbq 1(%rcx), %rdx
	movb %dl, 1(%rsi)
	addq %rdx, %rax
	movzbq 2(%rcx), %rdx
	movb %dl, 2(%rsi)
	addq %rdx, %rax
	movzbq 3(%rcx), %rdx
	movb %dl, 3(%rsi)
	addq %rdx, %rax
	movzbq 4(%rcx), %rdx
	movb %dl, 4(%rsi)
	addq %rdx, %rax
	movzbq 5(%rcx), %rdx
	movb %dl, 5(%rsi)
	addq %rdx, %rax
	movzbq 6(%rcx), %rdx
	movb %dl, 6(%rsi)
	addq %rdx, %rax
	movzbq 7(%rcx), %rdx
	movb %dl, 7(%rsi)
	addq %rdx, %rax
	movzbq 8(%rcx), %rdx
	movb %dl, 8(%rsi)
	addq %rdx, %rax
	movzbq 9(%rcx), %rdx
	movb %dl, 9(%rsi)
	addq %rdx, %rax
	movzbq 10(%rcx), %rdx
	movb %dl, 10(%rsi)
	addq %rdx, %rax
	movzbq 11(%rcx), %rdx
	movb %dl, 11(%rsi)
	addq %rdx, %rax
	movzbq 12(%rcx), %rdx
	movb %dl, 12(%rsi)
	addq %rdx, %rax
	movzbq 13(%rcx), %rdx
	movb %dl, 13(%rsi)
	addq %rdx, %rax
	movzbq 14(%rcx), %rdx
	movb %dl, 14(%rsi)
	addq %rdx, %rax
	movzbq 15(%rcx), %rdx
	movb %dl, 15(%rsi)
	addq %rdx, %rax
	movzbq 16(%rcx), %rdx
	movb %dl, 16(%rsi)
	addq %rdx, %rax
	movzbq 17(%rcx), %rdx
	movb %dl, 17(%rsi)
	addq %rdx, %rax
	movzbq 18(%rcx), %rdx
	movb %dl, 18(%rsi)
	addq %rdx, %rax
	movzbq 19(%rcx), %rdx
	movb %dl, 19(%rsi)
	addq %rdx, %rax
	movzbq 20(%rcx), %rdx
	movb %dl, 20(%rsi)
	addq %rdx, %rax
	movzbq 21(%rcx), %rdx
	movb %dl, 21(%rsi)
	addq %rdx, %rax
	movzbq 22(%rcx), %rdx
	movb %dl, 22(%rsi)
	addq %rdx, %rax
	movzbq 23(%rcx), %rcx
	movb %cl, 23(%rsi)
	addq %rcx, %rax
	popq %rbx
	leave
	ret
/* end function probe_opaque_indirect */

.text
.balign 16
_echo_nested:
	endbr64
	pushq %rbp
	movq %rsp, %rbp
	subq $208, %rsp
	movq %rdi, -176(%rbp)
	movq %rsi, -168(%rbp)
	movq %rdx, -160(%rbp)
	movq %rcx, -152(%rbp)
	movq %r8, -144(%rbp)
	movq %r9, -136(%rbp)
	movaps %xmm0, -128(%rbp)
	movaps %xmm1, -112(%rbp)
	movaps %xmm2, -96(%rbp)
	movaps %xmm3, -80(%rbp)
	movaps %xmm4, -64(%rbp)
	movaps %xmm5, -48(%rbp)
	movaps %xmm6, -32(%rbp)
	movaps %xmm7, -16(%rbp)
	movq %rdi, -192(%rbp)
	movq %rsi, -184(%rbp)
	cmpl $0, %edx
	jz Lbb50
	subl $1, %edx
	movl $91, %ecx
	movq -192(%rbp), %rdi
	movq -184(%rbp), %rsi
	movl $0, %eax
	callq _echo_nested
	movq %rax, %rcx
	movq %rdx, %rax
	movq %rcx, -208(%rbp)
	movq %rax, -200(%rbp)
	movq -208(%rbp), %rax
	movq -200(%rbp), %rdx
	jmp Lbb51
Lbb50:
	movq -192(%rbp), %rax
	movq -184(%rbp), %rdx
Lbb51:
	leave
	ret
/* end function echo_nested */

.text
.balign 16
.globl _probe_nested_direct
_probe_nested_direct:
	endbr64
	pushq %rbp
	movq %rsp, %rbp
	subq $24, %rsp
	pushq %rbx
	movq %rdi, %rax
	movl $91, %ecx
	movl $2, %edx
	movq (%rax), %rdi
	movq %rsi, %rbx
	movq 8(%rax), %rsi
	movl $0, %eax
	callq _echo_nested
	movq %rbx, %rsi
	movq %rax, %rcx
	movq %rdx, %rax
	movq %rcx, -16(%rbp)
	movq %rax, -8(%rbp)
	movzbq -16(%rbp), %rax
	movb %al, (%rsi)
	movzbq -15(%rbp), %rcx
	movb %cl, 1(%rsi)
	addq %rcx, %rax
	movzbq -14(%rbp), %rcx
	movb %cl, 2(%rsi)
	addq %rcx, %rax
	movzbq -13(%rbp), %rcx
	movb %cl, 3(%rsi)
	addq %rcx, %rax
	movzbq -12(%rbp), %rcx
	movb %cl, 4(%rsi)
	addq %rcx, %rax
	movzbq -11(%rbp), %rcx
	movb %cl, 5(%rsi)
	addq %rcx, %rax
	movzbq -10(%rbp), %rcx
	movb %cl, 6(%rsi)
	addq %rcx, %rax
	movzbq -9(%rbp), %rcx
	movb %cl, 7(%rsi)
	addq %rcx, %rax
	movzbq -8(%rbp), %rcx
	movb %cl, 8(%rsi)
	addq %rcx, %rax
	movzbq -7(%rbp), %rcx
	movb %cl, 9(%rsi)
	addq %rcx, %rax
	movzbq -6(%rbp), %rcx
	movb %cl, 10(%rsi)
	addq %rcx, %rax
	movzbq -5(%rbp), %rcx
	movb %cl, 11(%rsi)
	addq %rcx, %rax
	movzbq -4(%rbp), %rcx
	movb %cl, 12(%rsi)
	addq %rcx, %rax
	movzbq -3(%rbp), %rcx
	movb %cl, 13(%rsi)
	addq %rcx, %rax
	movzbq -2(%rbp), %rcx
	movb %cl, 14(%rsi)
	addq %rcx, %rax
	movzbq -1(%rbp), %rcx
	movb %cl, 15(%rsi)
	addq %rcx, %rax
	popq %rbx
	leave
	ret
/* end function probe_nested_direct */

.text
.balign 16
.globl _probe_nested_indirect
_probe_nested_indirect:
	endbr64
	pushq %rbp
	movq %rsp, %rbp
	subq $24, %rsp
	pushq %rbx
	movq %rdi, %rax
	movl $91, %ecx
	movl $2, %edx
	movq (%rax), %rdi
	movq %rsi, %rbx
	movq 8(%rax), %rsi
	movl $0, %eax
	callq _echo_nested
	movq %rbx, %rsi
	movq %rax, %rcx
	movq %rdx, %rax
	movq %rcx, -16(%rbp)
	movq %rax, -8(%rbp)
	movzbq -16(%rbp), %rax
	movb %al, (%rsi)
	movzbq -15(%rbp), %rcx
	movb %cl, 1(%rsi)
	addq %rcx, %rax
	movzbq -14(%rbp), %rcx
	movb %cl, 2(%rsi)
	addq %rcx, %rax
	movzbq -13(%rbp), %rcx
	movb %cl, 3(%rsi)
	addq %rcx, %rax
	movzbq -12(%rbp), %rcx
	movb %cl, 4(%rsi)
	addq %rcx, %rax
	movzbq -11(%rbp), %rcx
	movb %cl, 5(%rsi)
	addq %rcx, %rax
	movzbq -10(%rbp), %rcx
	movb %cl, 6(%rsi)
	addq %rcx, %rax
	movzbq -9(%rbp), %rcx
	movb %cl, 7(%rsi)
	addq %rcx, %rax
	movzbq -8(%rbp), %rcx
	movb %cl, 8(%rsi)
	addq %rcx, %rax
	movzbq -7(%rbp), %rcx
	movb %cl, 9(%rsi)
	addq %rcx, %rax
	movzbq -6(%rbp), %rcx
	movb %cl, 10(%rsi)
	addq %rcx, %rax
	movzbq -5(%rbp), %rcx
	movb %cl, 11(%rsi)
	addq %rcx, %rax
	movzbq -4(%rbp), %rcx
	movb %cl, 12(%rsi)
	addq %rcx, %rax
	movzbq -3(%rbp), %rcx
	movb %cl, 13(%rsi)
	addq %rcx, %rax
	movzbq -2(%rbp), %rcx
	movb %cl, 14(%rsi)
	addq %rcx, %rax
	movzbq -1(%rbp), %rcx
	movb %cl, 15(%rsi)
	addq %rcx, %rax
	popq %rbx
	leave
	ret
/* end function probe_nested_indirect */

.text
.balign 16
.globl _interpreted
_interpreted:
	endbr64
	pushq %rbp
	movq %rsp, %rbp
	subq $48, %rsp
	movq $72623859790382856, %rax
	movq %rax, -48(%rbp)
	movq $72623859790382856, %rax
	movq %rax, -40(%rbp)
	leaq -16(%rbp), %rsi
	leaq -48(%rbp), %rdi
	callq _probe_nested_indirect
	leave
	ret
/* end function interpreted */

