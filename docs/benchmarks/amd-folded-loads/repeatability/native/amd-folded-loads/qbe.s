.file 1 "folded-loads.c"
.data
.balign 8
.globl _saved_address
_saved_address:
	.quad 0
/* end data */

.text
.balign 16
.globl _loadsb_w_fold
_loadsb_w_fold:
	endbr64
	movsbl 17(%rdi), %eax
	movl %eax, %eax
	ret
/* end function loadsb_w_fold */

.text
.balign 16
.globl _loadsb_w_negative
_loadsb_w_negative:
	endbr64
	movsbl -17(%rdi), %eax
	movl %eax, %eax
	ret
/* end function loadsb_w_negative */

.text
.balign 16
.globl _loadsb_w_max
_loadsb_w_max:
	endbr64
	movsbl 2147483647(%rdi), %eax
	movl %eax, %eax
	ret
/* end function loadsb_w_max */

.text
.balign 16
.globl _loadsb_w_min
_loadsb_w_min:
	endbr64
	movsbl -2147483648(%rdi), %eax
	movl %eax, %eax
	ret
/* end function loadsb_w_min */

.text
.balign 16
.globl _loadsb_w_shared
_loadsb_w_shared:
	endbr64
	movq %rdi, %rcx
	addq $17, %rcx
	movsbl 17(%rdi), %eax
	movq %rcx, _saved_address(%rip)
	movl %eax, %eax
	ret
/* end function loadsb_w_shared */

.text
.balign 16
.globl _loadsb_w_debug
_loadsb_w_debug:
	endbr64
	.loc 1 23
	movsbl 17(%rdi), %eax
	movl %eax, %eax
	ret
/* end function loadsb_w_debug */

.text
.balign 16
.globl _loadsb_w_pressure
_loadsb_w_pressure:
	endbr64
	subq $144, %rsp
	pushq %rbx
	pushq %r12
	pushq %r13
	pushq %r14
	pushq %r15
	movq 336(%rsp), %rax
	movq 328(%rsp), %r10
	movq 320(%rsp), %r11
	movq 312(%rsp), %rbx
	movq 304(%rsp), %r12
	movq 296(%rsp), %r13
	movq 288(%rsp), %r14
	movq %r14, 160(%rsp)
	movq 280(%rsp), %r14
	movq %r14, 152(%rsp)
	movq 272(%rsp), %r14
	movq %r14, 144(%rsp)
	movq 264(%rsp), %r14
	movq %r14, 136(%rsp)
	movq 256(%rsp), %r14
	movq %r14, 128(%rsp)
	movq 248(%rsp), %r14
	movq 240(%rsp), %r15
	movq %r15, 168(%rsp)
	movq 232(%rsp), %r15
	movq %r15, 40(%rsp)
	movq 224(%rsp), %r15
	movq %r15, 48(%rsp)
	movq 216(%rsp), %r15
	movq %r15, 56(%rsp)
	movq 208(%rsp), %r15
	movq %r15, 64(%rsp)
	movq 200(%rsp), %r15
	movq %r15, 72(%rsp)
	movq 192(%rsp), %r15
	movq %r15, 80(%rsp)
	movq 168(%rsp), %r15
	movq %r9, 88(%rsp)
	movq %r8, 96(%rsp)
	movq %rcx, 104(%rsp)
	movq %rdx, 112(%rsp)
	movq %rsi, 120(%rsp)
	movq %rdi, %r9
	movq 160(%rsp), %rcx
	movq 152(%rsp), %rdx
	movq 144(%rsp), %rsi
	movq 136(%rsp), %rdi
	movq 128(%rsp), %r8
	movsbl 17(%r9), %r9d
	movl %r9d, %r9d
	addq 120(%rsp), %r9
	addq 112(%rsp), %r9
	addq 104(%rsp), %r9
	addq 96(%rsp), %r9
	addq 88(%rsp), %r9
	addq 80(%rsp), %r9
	addq 72(%rsp), %r9
	addq 64(%rsp), %r9
	addq 56(%rsp), %r9
	addq 48(%rsp), %r9
	addq 40(%rsp), %r9
	addq %r15, %r9
	addq %r14, %r9
	addq %r9, %r8
	addq %r8, %rdi
	addq %rdi, %rsi
	addq %rsi, %rdx
	addq %rdx, %rcx
	addq %r13, %rcx
	addq %r12, %rcx
	addq %rbx, %rcx
	addq %r11, %rcx
	addq %r10, %rcx
	addq %rcx, %rax
	popq %r15
	popq %r14
	popq %r13
	popq %r12
	popq %rbx
	addq $144, %rsp
	ret
/* end function loadsb_w_pressure */

.text
.balign 16
.globl _loadsb_l_fold
_loadsb_l_fold:
	endbr64
	movsbq 17(%rdi), %rax
	ret
/* end function loadsb_l_fold */

.text
.balign 16
.globl _loadsb_l_negative
_loadsb_l_negative:
	endbr64
	movsbq -17(%rdi), %rax
	ret
/* end function loadsb_l_negative */

.text
.balign 16
.globl _loadsb_l_max
_loadsb_l_max:
	endbr64
	movsbq 2147483647(%rdi), %rax
	ret
/* end function loadsb_l_max */

.text
.balign 16
.globl _loadsb_l_min
_loadsb_l_min:
	endbr64
	movsbq -2147483648(%rdi), %rax
	ret
/* end function loadsb_l_min */

.text
.balign 16
.globl _loadsb_l_shared
_loadsb_l_shared:
	endbr64
	movq %rdi, %rcx
	addq $17, %rcx
	movsbq 17(%rdi), %rax
	movq %rcx, _saved_address(%rip)
	ret
/* end function loadsb_l_shared */

.text
.balign 16
.globl _loadsb_l_debug
_loadsb_l_debug:
	endbr64
	.loc 1 23
	movsbq 17(%rdi), %rax
	ret
/* end function loadsb_l_debug */

.text
.balign 16
.globl _loadsb_l_pressure
_loadsb_l_pressure:
	endbr64
	subq $144, %rsp
	pushq %rbx
	pushq %r12
	pushq %r13
	pushq %r14
	pushq %r15
	movq 336(%rsp), %rax
	movq 328(%rsp), %r10
	movq 320(%rsp), %r11
	movq 312(%rsp), %rbx
	movq 304(%rsp), %r12
	movq 296(%rsp), %r13
	movq 288(%rsp), %r14
	movq %r14, 160(%rsp)
	movq 280(%rsp), %r14
	movq %r14, 152(%rsp)
	movq 272(%rsp), %r14
	movq %r14, 144(%rsp)
	movq 264(%rsp), %r14
	movq %r14, 136(%rsp)
	movq 256(%rsp), %r14
	movq %r14, 128(%rsp)
	movq 248(%rsp), %r14
	movq 240(%rsp), %r15
	movq %r15, 168(%rsp)
	movq 232(%rsp), %r15
	movq %r15, 40(%rsp)
	movq 224(%rsp), %r15
	movq %r15, 48(%rsp)
	movq 216(%rsp), %r15
	movq %r15, 56(%rsp)
	movq 208(%rsp), %r15
	movq %r15, 64(%rsp)
	movq 200(%rsp), %r15
	movq %r15, 72(%rsp)
	movq 192(%rsp), %r15
	movq %r15, 80(%rsp)
	movq 168(%rsp), %r15
	movq %r9, 88(%rsp)
	movq %r8, 96(%rsp)
	movq %rcx, 104(%rsp)
	movq %rdx, 112(%rsp)
	movq %rsi, 120(%rsp)
	movq %rdi, %r9
	movq 160(%rsp), %rcx
	movq 152(%rsp), %rdx
	movq 144(%rsp), %rsi
	movq 136(%rsp), %rdi
	movq 128(%rsp), %r8
	movsbq 17(%r9), %r9
	addq 120(%rsp), %r9
	addq 112(%rsp), %r9
	addq 104(%rsp), %r9
	addq 96(%rsp), %r9
	addq 88(%rsp), %r9
	addq 80(%rsp), %r9
	addq 72(%rsp), %r9
	addq 64(%rsp), %r9
	addq 56(%rsp), %r9
	addq 48(%rsp), %r9
	addq 40(%rsp), %r9
	addq %r15, %r9
	addq %r14, %r9
	addq %r9, %r8
	addq %r8, %rdi
	addq %rdi, %rsi
	addq %rsi, %rdx
	addq %rdx, %rcx
	addq %r13, %rcx
	addq %r12, %rcx
	addq %rbx, %rcx
	addq %r11, %rcx
	addq %r10, %rcx
	addq %rcx, %rax
	popq %r15
	popq %r14
	popq %r13
	popq %r12
	popq %rbx
	addq $144, %rsp
	ret
/* end function loadsb_l_pressure */

.text
.balign 16
.globl _loadub_w_fold
_loadub_w_fold:
	endbr64
	movzbl 17(%rdi), %eax
	movl %eax, %eax
	ret
/* end function loadub_w_fold */

.text
.balign 16
.globl _loadub_w_negative
_loadub_w_negative:
	endbr64
	movzbl -17(%rdi), %eax
	movl %eax, %eax
	ret
/* end function loadub_w_negative */

.text
.balign 16
.globl _loadub_w_max
_loadub_w_max:
	endbr64
	movzbl 2147483647(%rdi), %eax
	movl %eax, %eax
	ret
/* end function loadub_w_max */

.text
.balign 16
.globl _loadub_w_min
_loadub_w_min:
	endbr64
	movzbl -2147483648(%rdi), %eax
	movl %eax, %eax
	ret
/* end function loadub_w_min */

.text
.balign 16
.globl _loadub_w_shared
_loadub_w_shared:
	endbr64
	movq %rdi, %rcx
	addq $17, %rcx
	movzbl 17(%rdi), %eax
	movq %rcx, _saved_address(%rip)
	movl %eax, %eax
	ret
/* end function loadub_w_shared */

.text
.balign 16
.globl _loadub_w_debug
_loadub_w_debug:
	endbr64
	.loc 1 23
	movzbl 17(%rdi), %eax
	movl %eax, %eax
	ret
/* end function loadub_w_debug */

.text
.balign 16
.globl _loadub_w_pressure
_loadub_w_pressure:
	endbr64
	subq $144, %rsp
	pushq %rbx
	pushq %r12
	pushq %r13
	pushq %r14
	pushq %r15
	movq 336(%rsp), %rax
	movq 328(%rsp), %r10
	movq 320(%rsp), %r11
	movq 312(%rsp), %rbx
	movq 304(%rsp), %r12
	movq 296(%rsp), %r13
	movq 288(%rsp), %r14
	movq %r14, 160(%rsp)
	movq 280(%rsp), %r14
	movq %r14, 152(%rsp)
	movq 272(%rsp), %r14
	movq %r14, 144(%rsp)
	movq 264(%rsp), %r14
	movq %r14, 136(%rsp)
	movq 256(%rsp), %r14
	movq %r14, 128(%rsp)
	movq 248(%rsp), %r14
	movq 240(%rsp), %r15
	movq %r15, 168(%rsp)
	movq 232(%rsp), %r15
	movq %r15, 40(%rsp)
	movq 224(%rsp), %r15
	movq %r15, 48(%rsp)
	movq 216(%rsp), %r15
	movq %r15, 56(%rsp)
	movq 208(%rsp), %r15
	movq %r15, 64(%rsp)
	movq 200(%rsp), %r15
	movq %r15, 72(%rsp)
	movq 192(%rsp), %r15
	movq %r15, 80(%rsp)
	movq 168(%rsp), %r15
	movq %r9, 88(%rsp)
	movq %r8, 96(%rsp)
	movq %rcx, 104(%rsp)
	movq %rdx, 112(%rsp)
	movq %rsi, 120(%rsp)
	movq %rdi, %r9
	movq 160(%rsp), %rcx
	movq 152(%rsp), %rdx
	movq 144(%rsp), %rsi
	movq 136(%rsp), %rdi
	movq 128(%rsp), %r8
	movzbl 17(%r9), %r9d
	movl %r9d, %r9d
	addq 120(%rsp), %r9
	addq 112(%rsp), %r9
	addq 104(%rsp), %r9
	addq 96(%rsp), %r9
	addq 88(%rsp), %r9
	addq 80(%rsp), %r9
	addq 72(%rsp), %r9
	addq 64(%rsp), %r9
	addq 56(%rsp), %r9
	addq 48(%rsp), %r9
	addq 40(%rsp), %r9
	addq %r15, %r9
	addq %r14, %r9
	addq %r9, %r8
	addq %r8, %rdi
	addq %rdi, %rsi
	addq %rsi, %rdx
	addq %rdx, %rcx
	addq %r13, %rcx
	addq %r12, %rcx
	addq %rbx, %rcx
	addq %r11, %rcx
	addq %r10, %rcx
	addq %rcx, %rax
	popq %r15
	popq %r14
	popq %r13
	popq %r12
	popq %rbx
	addq $144, %rsp
	ret
/* end function loadub_w_pressure */

.text
.balign 16
.globl _loadub_l_fold
_loadub_l_fold:
	endbr64
	movzbq 17(%rdi), %rax
	ret
/* end function loadub_l_fold */

.text
.balign 16
.globl _loadub_l_negative
_loadub_l_negative:
	endbr64
	movzbq -17(%rdi), %rax
	ret
/* end function loadub_l_negative */

.text
.balign 16
.globl _loadub_l_max
_loadub_l_max:
	endbr64
	movzbq 2147483647(%rdi), %rax
	ret
/* end function loadub_l_max */

.text
.balign 16
.globl _loadub_l_min
_loadub_l_min:
	endbr64
	movzbq -2147483648(%rdi), %rax
	ret
/* end function loadub_l_min */

.text
.balign 16
.globl _loadub_l_shared
_loadub_l_shared:
	endbr64
	movq %rdi, %rcx
	addq $17, %rcx
	movzbq 17(%rdi), %rax
	movq %rcx, _saved_address(%rip)
	ret
/* end function loadub_l_shared */

.text
.balign 16
.globl _loadub_l_debug
_loadub_l_debug:
	endbr64
	.loc 1 23
	movzbq 17(%rdi), %rax
	ret
/* end function loadub_l_debug */

.text
.balign 16
.globl _loadub_l_pressure
_loadub_l_pressure:
	endbr64
	subq $144, %rsp
	pushq %rbx
	pushq %r12
	pushq %r13
	pushq %r14
	pushq %r15
	movq 336(%rsp), %rax
	movq 328(%rsp), %r10
	movq 320(%rsp), %r11
	movq 312(%rsp), %rbx
	movq 304(%rsp), %r12
	movq 296(%rsp), %r13
	movq 288(%rsp), %r14
	movq %r14, 160(%rsp)
	movq 280(%rsp), %r14
	movq %r14, 152(%rsp)
	movq 272(%rsp), %r14
	movq %r14, 144(%rsp)
	movq 264(%rsp), %r14
	movq %r14, 136(%rsp)
	movq 256(%rsp), %r14
	movq %r14, 128(%rsp)
	movq 248(%rsp), %r14
	movq 240(%rsp), %r15
	movq %r15, 168(%rsp)
	movq 232(%rsp), %r15
	movq %r15, 40(%rsp)
	movq 224(%rsp), %r15
	movq %r15, 48(%rsp)
	movq 216(%rsp), %r15
	movq %r15, 56(%rsp)
	movq 208(%rsp), %r15
	movq %r15, 64(%rsp)
	movq 200(%rsp), %r15
	movq %r15, 72(%rsp)
	movq 192(%rsp), %r15
	movq %r15, 80(%rsp)
	movq 168(%rsp), %r15
	movq %r9, 88(%rsp)
	movq %r8, 96(%rsp)
	movq %rcx, 104(%rsp)
	movq %rdx, 112(%rsp)
	movq %rsi, 120(%rsp)
	movq %rdi, %r9
	movq 160(%rsp), %rcx
	movq 152(%rsp), %rdx
	movq 144(%rsp), %rsi
	movq 136(%rsp), %rdi
	movq 128(%rsp), %r8
	movzbq 17(%r9), %r9
	addq 120(%rsp), %r9
	addq 112(%rsp), %r9
	addq 104(%rsp), %r9
	addq 96(%rsp), %r9
	addq 88(%rsp), %r9
	addq 80(%rsp), %r9
	addq 72(%rsp), %r9
	addq 64(%rsp), %r9
	addq 56(%rsp), %r9
	addq 48(%rsp), %r9
	addq 40(%rsp), %r9
	addq %r15, %r9
	addq %r14, %r9
	addq %r9, %r8
	addq %r8, %rdi
	addq %rdi, %rsi
	addq %rsi, %rdx
	addq %rdx, %rcx
	addq %r13, %rcx
	addq %r12, %rcx
	addq %rbx, %rcx
	addq %r11, %rcx
	addq %r10, %rcx
	addq %rcx, %rax
	popq %r15
	popq %r14
	popq %r13
	popq %r12
	popq %rbx
	addq $144, %rsp
	ret
/* end function loadub_l_pressure */

.text
.balign 16
.globl _loadsh_w_fold
_loadsh_w_fold:
	endbr64
	movswl 17(%rdi), %eax
	movl %eax, %eax
	ret
/* end function loadsh_w_fold */

.text
.balign 16
.globl _loadsh_w_negative
_loadsh_w_negative:
	endbr64
	movswl -17(%rdi), %eax
	movl %eax, %eax
	ret
/* end function loadsh_w_negative */

.text
.balign 16
.globl _loadsh_w_max
_loadsh_w_max:
	endbr64
	movswl 2147483647(%rdi), %eax
	movl %eax, %eax
	ret
/* end function loadsh_w_max */

.text
.balign 16
.globl _loadsh_w_min
_loadsh_w_min:
	endbr64
	movswl -2147483648(%rdi), %eax
	movl %eax, %eax
	ret
/* end function loadsh_w_min */

.text
.balign 16
.globl _loadsh_w_shared
_loadsh_w_shared:
	endbr64
	movq %rdi, %rcx
	addq $17, %rcx
	movswl 17(%rdi), %eax
	movq %rcx, _saved_address(%rip)
	movl %eax, %eax
	ret
/* end function loadsh_w_shared */

.text
.balign 16
.globl _loadsh_w_debug
_loadsh_w_debug:
	endbr64
	.loc 1 23
	movswl 17(%rdi), %eax
	movl %eax, %eax
	ret
/* end function loadsh_w_debug */

.text
.balign 16
.globl _loadsh_w_pressure
_loadsh_w_pressure:
	endbr64
	subq $144, %rsp
	pushq %rbx
	pushq %r12
	pushq %r13
	pushq %r14
	pushq %r15
	movq 336(%rsp), %rax
	movq 328(%rsp), %r10
	movq 320(%rsp), %r11
	movq 312(%rsp), %rbx
	movq 304(%rsp), %r12
	movq 296(%rsp), %r13
	movq 288(%rsp), %r14
	movq %r14, 160(%rsp)
	movq 280(%rsp), %r14
	movq %r14, 152(%rsp)
	movq 272(%rsp), %r14
	movq %r14, 144(%rsp)
	movq 264(%rsp), %r14
	movq %r14, 136(%rsp)
	movq 256(%rsp), %r14
	movq %r14, 128(%rsp)
	movq 248(%rsp), %r14
	movq 240(%rsp), %r15
	movq %r15, 168(%rsp)
	movq 232(%rsp), %r15
	movq %r15, 40(%rsp)
	movq 224(%rsp), %r15
	movq %r15, 48(%rsp)
	movq 216(%rsp), %r15
	movq %r15, 56(%rsp)
	movq 208(%rsp), %r15
	movq %r15, 64(%rsp)
	movq 200(%rsp), %r15
	movq %r15, 72(%rsp)
	movq 192(%rsp), %r15
	movq %r15, 80(%rsp)
	movq 168(%rsp), %r15
	movq %r9, 88(%rsp)
	movq %r8, 96(%rsp)
	movq %rcx, 104(%rsp)
	movq %rdx, 112(%rsp)
	movq %rsi, 120(%rsp)
	movq %rdi, %r9
	movq 160(%rsp), %rcx
	movq 152(%rsp), %rdx
	movq 144(%rsp), %rsi
	movq 136(%rsp), %rdi
	movq 128(%rsp), %r8
	movswl 17(%r9), %r9d
	movl %r9d, %r9d
	addq 120(%rsp), %r9
	addq 112(%rsp), %r9
	addq 104(%rsp), %r9
	addq 96(%rsp), %r9
	addq 88(%rsp), %r9
	addq 80(%rsp), %r9
	addq 72(%rsp), %r9
	addq 64(%rsp), %r9
	addq 56(%rsp), %r9
	addq 48(%rsp), %r9
	addq 40(%rsp), %r9
	addq %r15, %r9
	addq %r14, %r9
	addq %r9, %r8
	addq %r8, %rdi
	addq %rdi, %rsi
	addq %rsi, %rdx
	addq %rdx, %rcx
	addq %r13, %rcx
	addq %r12, %rcx
	addq %rbx, %rcx
	addq %r11, %rcx
	addq %r10, %rcx
	addq %rcx, %rax
	popq %r15
	popq %r14
	popq %r13
	popq %r12
	popq %rbx
	addq $144, %rsp
	ret
/* end function loadsh_w_pressure */

.text
.balign 16
.globl _loadsh_l_fold
_loadsh_l_fold:
	endbr64
	movswq 17(%rdi), %rax
	ret
/* end function loadsh_l_fold */

.text
.balign 16
.globl _loadsh_l_negative
_loadsh_l_negative:
	endbr64
	movswq -17(%rdi), %rax
	ret
/* end function loadsh_l_negative */

.text
.balign 16
.globl _loadsh_l_max
_loadsh_l_max:
	endbr64
	movswq 2147483647(%rdi), %rax
	ret
/* end function loadsh_l_max */

.text
.balign 16
.globl _loadsh_l_min
_loadsh_l_min:
	endbr64
	movswq -2147483648(%rdi), %rax
	ret
/* end function loadsh_l_min */

.text
.balign 16
.globl _loadsh_l_shared
_loadsh_l_shared:
	endbr64
	movq %rdi, %rcx
	addq $17, %rcx
	movswq 17(%rdi), %rax
	movq %rcx, _saved_address(%rip)
	ret
/* end function loadsh_l_shared */

.text
.balign 16
.globl _loadsh_l_debug
_loadsh_l_debug:
	endbr64
	.loc 1 23
	movswq 17(%rdi), %rax
	ret
/* end function loadsh_l_debug */

.text
.balign 16
.globl _loadsh_l_pressure
_loadsh_l_pressure:
	endbr64
	subq $144, %rsp
	pushq %rbx
	pushq %r12
	pushq %r13
	pushq %r14
	pushq %r15
	movq 336(%rsp), %rax
	movq 328(%rsp), %r10
	movq 320(%rsp), %r11
	movq 312(%rsp), %rbx
	movq 304(%rsp), %r12
	movq 296(%rsp), %r13
	movq 288(%rsp), %r14
	movq %r14, 160(%rsp)
	movq 280(%rsp), %r14
	movq %r14, 152(%rsp)
	movq 272(%rsp), %r14
	movq %r14, 144(%rsp)
	movq 264(%rsp), %r14
	movq %r14, 136(%rsp)
	movq 256(%rsp), %r14
	movq %r14, 128(%rsp)
	movq 248(%rsp), %r14
	movq 240(%rsp), %r15
	movq %r15, 168(%rsp)
	movq 232(%rsp), %r15
	movq %r15, 40(%rsp)
	movq 224(%rsp), %r15
	movq %r15, 48(%rsp)
	movq 216(%rsp), %r15
	movq %r15, 56(%rsp)
	movq 208(%rsp), %r15
	movq %r15, 64(%rsp)
	movq 200(%rsp), %r15
	movq %r15, 72(%rsp)
	movq 192(%rsp), %r15
	movq %r15, 80(%rsp)
	movq 168(%rsp), %r15
	movq %r9, 88(%rsp)
	movq %r8, 96(%rsp)
	movq %rcx, 104(%rsp)
	movq %rdx, 112(%rsp)
	movq %rsi, 120(%rsp)
	movq %rdi, %r9
	movq 160(%rsp), %rcx
	movq 152(%rsp), %rdx
	movq 144(%rsp), %rsi
	movq 136(%rsp), %rdi
	movq 128(%rsp), %r8
	movswq 17(%r9), %r9
	addq 120(%rsp), %r9
	addq 112(%rsp), %r9
	addq 104(%rsp), %r9
	addq 96(%rsp), %r9
	addq 88(%rsp), %r9
	addq 80(%rsp), %r9
	addq 72(%rsp), %r9
	addq 64(%rsp), %r9
	addq 56(%rsp), %r9
	addq 48(%rsp), %r9
	addq 40(%rsp), %r9
	addq %r15, %r9
	addq %r14, %r9
	addq %r9, %r8
	addq %r8, %rdi
	addq %rdi, %rsi
	addq %rsi, %rdx
	addq %rdx, %rcx
	addq %r13, %rcx
	addq %r12, %rcx
	addq %rbx, %rcx
	addq %r11, %rcx
	addq %r10, %rcx
	addq %rcx, %rax
	popq %r15
	popq %r14
	popq %r13
	popq %r12
	popq %rbx
	addq $144, %rsp
	ret
/* end function loadsh_l_pressure */

.text
.balign 16
.globl _loaduh_w_fold
_loaduh_w_fold:
	endbr64
	movzwl 17(%rdi), %eax
	movl %eax, %eax
	ret
/* end function loaduh_w_fold */

.text
.balign 16
.globl _loaduh_w_negative
_loaduh_w_negative:
	endbr64
	movzwl -17(%rdi), %eax
	movl %eax, %eax
	ret
/* end function loaduh_w_negative */

.text
.balign 16
.globl _loaduh_w_max
_loaduh_w_max:
	endbr64
	movzwl 2147483647(%rdi), %eax
	movl %eax, %eax
	ret
/* end function loaduh_w_max */

.text
.balign 16
.globl _loaduh_w_min
_loaduh_w_min:
	endbr64
	movzwl -2147483648(%rdi), %eax
	movl %eax, %eax
	ret
/* end function loaduh_w_min */

.text
.balign 16
.globl _loaduh_w_shared
_loaduh_w_shared:
	endbr64
	movq %rdi, %rcx
	addq $17, %rcx
	movzwl 17(%rdi), %eax
	movq %rcx, _saved_address(%rip)
	movl %eax, %eax
	ret
/* end function loaduh_w_shared */

.text
.balign 16
.globl _loaduh_w_debug
_loaduh_w_debug:
	endbr64
	.loc 1 23
	movzwl 17(%rdi), %eax
	movl %eax, %eax
	ret
/* end function loaduh_w_debug */

.text
.balign 16
.globl _loaduh_w_pressure
_loaduh_w_pressure:
	endbr64
	subq $144, %rsp
	pushq %rbx
	pushq %r12
	pushq %r13
	pushq %r14
	pushq %r15
	movq 336(%rsp), %rax
	movq 328(%rsp), %r10
	movq 320(%rsp), %r11
	movq 312(%rsp), %rbx
	movq 304(%rsp), %r12
	movq 296(%rsp), %r13
	movq 288(%rsp), %r14
	movq %r14, 160(%rsp)
	movq 280(%rsp), %r14
	movq %r14, 152(%rsp)
	movq 272(%rsp), %r14
	movq %r14, 144(%rsp)
	movq 264(%rsp), %r14
	movq %r14, 136(%rsp)
	movq 256(%rsp), %r14
	movq %r14, 128(%rsp)
	movq 248(%rsp), %r14
	movq 240(%rsp), %r15
	movq %r15, 168(%rsp)
	movq 232(%rsp), %r15
	movq %r15, 40(%rsp)
	movq 224(%rsp), %r15
	movq %r15, 48(%rsp)
	movq 216(%rsp), %r15
	movq %r15, 56(%rsp)
	movq 208(%rsp), %r15
	movq %r15, 64(%rsp)
	movq 200(%rsp), %r15
	movq %r15, 72(%rsp)
	movq 192(%rsp), %r15
	movq %r15, 80(%rsp)
	movq 168(%rsp), %r15
	movq %r9, 88(%rsp)
	movq %r8, 96(%rsp)
	movq %rcx, 104(%rsp)
	movq %rdx, 112(%rsp)
	movq %rsi, 120(%rsp)
	movq %rdi, %r9
	movq 160(%rsp), %rcx
	movq 152(%rsp), %rdx
	movq 144(%rsp), %rsi
	movq 136(%rsp), %rdi
	movq 128(%rsp), %r8
	movzwl 17(%r9), %r9d
	movl %r9d, %r9d
	addq 120(%rsp), %r9
	addq 112(%rsp), %r9
	addq 104(%rsp), %r9
	addq 96(%rsp), %r9
	addq 88(%rsp), %r9
	addq 80(%rsp), %r9
	addq 72(%rsp), %r9
	addq 64(%rsp), %r9
	addq 56(%rsp), %r9
	addq 48(%rsp), %r9
	addq 40(%rsp), %r9
	addq %r15, %r9
	addq %r14, %r9
	addq %r9, %r8
	addq %r8, %rdi
	addq %rdi, %rsi
	addq %rsi, %rdx
	addq %rdx, %rcx
	addq %r13, %rcx
	addq %r12, %rcx
	addq %rbx, %rcx
	addq %r11, %rcx
	addq %r10, %rcx
	addq %rcx, %rax
	popq %r15
	popq %r14
	popq %r13
	popq %r12
	popq %rbx
	addq $144, %rsp
	ret
/* end function loaduh_w_pressure */

.text
.balign 16
.globl _loaduh_l_fold
_loaduh_l_fold:
	endbr64
	movzwq 17(%rdi), %rax
	ret
/* end function loaduh_l_fold */

.text
.balign 16
.globl _loaduh_l_negative
_loaduh_l_negative:
	endbr64
	movzwq -17(%rdi), %rax
	ret
/* end function loaduh_l_negative */

.text
.balign 16
.globl _loaduh_l_max
_loaduh_l_max:
	endbr64
	movzwq 2147483647(%rdi), %rax
	ret
/* end function loaduh_l_max */

.text
.balign 16
.globl _loaduh_l_min
_loaduh_l_min:
	endbr64
	movzwq -2147483648(%rdi), %rax
	ret
/* end function loaduh_l_min */

.text
.balign 16
.globl _loaduh_l_shared
_loaduh_l_shared:
	endbr64
	movq %rdi, %rcx
	addq $17, %rcx
	movzwq 17(%rdi), %rax
	movq %rcx, _saved_address(%rip)
	ret
/* end function loaduh_l_shared */

.text
.balign 16
.globl _loaduh_l_debug
_loaduh_l_debug:
	endbr64
	.loc 1 23
	movzwq 17(%rdi), %rax
	ret
/* end function loaduh_l_debug */

.text
.balign 16
.globl _loaduh_l_pressure
_loaduh_l_pressure:
	endbr64
	subq $144, %rsp
	pushq %rbx
	pushq %r12
	pushq %r13
	pushq %r14
	pushq %r15
	movq 336(%rsp), %rax
	movq 328(%rsp), %r10
	movq 320(%rsp), %r11
	movq 312(%rsp), %rbx
	movq 304(%rsp), %r12
	movq 296(%rsp), %r13
	movq 288(%rsp), %r14
	movq %r14, 160(%rsp)
	movq 280(%rsp), %r14
	movq %r14, 152(%rsp)
	movq 272(%rsp), %r14
	movq %r14, 144(%rsp)
	movq 264(%rsp), %r14
	movq %r14, 136(%rsp)
	movq 256(%rsp), %r14
	movq %r14, 128(%rsp)
	movq 248(%rsp), %r14
	movq 240(%rsp), %r15
	movq %r15, 168(%rsp)
	movq 232(%rsp), %r15
	movq %r15, 40(%rsp)
	movq 224(%rsp), %r15
	movq %r15, 48(%rsp)
	movq 216(%rsp), %r15
	movq %r15, 56(%rsp)
	movq 208(%rsp), %r15
	movq %r15, 64(%rsp)
	movq 200(%rsp), %r15
	movq %r15, 72(%rsp)
	movq 192(%rsp), %r15
	movq %r15, 80(%rsp)
	movq 168(%rsp), %r15
	movq %r9, 88(%rsp)
	movq %r8, 96(%rsp)
	movq %rcx, 104(%rsp)
	movq %rdx, 112(%rsp)
	movq %rsi, 120(%rsp)
	movq %rdi, %r9
	movq 160(%rsp), %rcx
	movq 152(%rsp), %rdx
	movq 144(%rsp), %rsi
	movq 136(%rsp), %rdi
	movq 128(%rsp), %r8
	movzwq 17(%r9), %r9
	addq 120(%rsp), %r9
	addq 112(%rsp), %r9
	addq 104(%rsp), %r9
	addq 96(%rsp), %r9
	addq 88(%rsp), %r9
	addq 80(%rsp), %r9
	addq 72(%rsp), %r9
	addq 64(%rsp), %r9
	addq 56(%rsp), %r9
	addq 48(%rsp), %r9
	addq 40(%rsp), %r9
	addq %r15, %r9
	addq %r14, %r9
	addq %r9, %r8
	addq %r8, %rdi
	addq %rdi, %rsi
	addq %rsi, %rdx
	addq %rdx, %rcx
	addq %r13, %rcx
	addq %r12, %rcx
	addq %rbx, %rcx
	addq %r11, %rcx
	addq %r10, %rcx
	addq %rcx, %rax
	popq %r15
	popq %r14
	popq %r13
	popq %r12
	popq %rbx
	addq $144, %rsp
	ret
/* end function loaduh_l_pressure */

.text
.balign 16
.globl _loadsw_w_fold
_loadsw_w_fold:
	endbr64
	movl 17(%rdi), %eax
	movl %eax, %eax
	ret
/* end function loadsw_w_fold */

.text
.balign 16
.globl _loadsw_w_negative
_loadsw_w_negative:
	endbr64
	movl -17(%rdi), %eax
	movl %eax, %eax
	ret
/* end function loadsw_w_negative */

.text
.balign 16
.globl _loadsw_w_max
_loadsw_w_max:
	endbr64
	movl 2147483647(%rdi), %eax
	movl %eax, %eax
	ret
/* end function loadsw_w_max */

.text
.balign 16
.globl _loadsw_w_min
_loadsw_w_min:
	endbr64
	movl -2147483648(%rdi), %eax
	movl %eax, %eax
	ret
/* end function loadsw_w_min */

.text
.balign 16
.globl _loadsw_w_shared
_loadsw_w_shared:
	endbr64
	movq %rdi, %rcx
	addq $17, %rcx
	movl 17(%rdi), %eax
	movq %rcx, _saved_address(%rip)
	movl %eax, %eax
	ret
/* end function loadsw_w_shared */

.text
.balign 16
.globl _loadsw_w_debug
_loadsw_w_debug:
	endbr64
	.loc 1 23
	movl 17(%rdi), %eax
	movl %eax, %eax
	ret
/* end function loadsw_w_debug */

.text
.balign 16
.globl _loadsw_w_pressure
_loadsw_w_pressure:
	endbr64
	subq $144, %rsp
	pushq %rbx
	pushq %r12
	pushq %r13
	pushq %r14
	pushq %r15
	movq 336(%rsp), %rax
	movq 328(%rsp), %r10
	movq 320(%rsp), %r11
	movq 312(%rsp), %rbx
	movq 304(%rsp), %r12
	movq 296(%rsp), %r13
	movq 288(%rsp), %r14
	movq %r14, 160(%rsp)
	movq 280(%rsp), %r14
	movq %r14, 152(%rsp)
	movq 272(%rsp), %r14
	movq %r14, 144(%rsp)
	movq 264(%rsp), %r14
	movq %r14, 136(%rsp)
	movq 256(%rsp), %r14
	movq %r14, 128(%rsp)
	movq 248(%rsp), %r14
	movq 240(%rsp), %r15
	movq %r15, 168(%rsp)
	movq 232(%rsp), %r15
	movq %r15, 40(%rsp)
	movq 224(%rsp), %r15
	movq %r15, 48(%rsp)
	movq 216(%rsp), %r15
	movq %r15, 56(%rsp)
	movq 208(%rsp), %r15
	movq %r15, 64(%rsp)
	movq 200(%rsp), %r15
	movq %r15, 72(%rsp)
	movq 192(%rsp), %r15
	movq %r15, 80(%rsp)
	movq 168(%rsp), %r15
	movq %r9, 88(%rsp)
	movq %r8, 96(%rsp)
	movq %rcx, 104(%rsp)
	movq %rdx, 112(%rsp)
	movq %rsi, 120(%rsp)
	movq %rdi, %r9
	movq 160(%rsp), %rcx
	movq 152(%rsp), %rdx
	movq 144(%rsp), %rsi
	movq 136(%rsp), %rdi
	movq 128(%rsp), %r8
	movl 17(%r9), %r9d
	movl %r9d, %r9d
	addq 120(%rsp), %r9
	addq 112(%rsp), %r9
	addq 104(%rsp), %r9
	addq 96(%rsp), %r9
	addq 88(%rsp), %r9
	addq 80(%rsp), %r9
	addq 72(%rsp), %r9
	addq 64(%rsp), %r9
	addq 56(%rsp), %r9
	addq 48(%rsp), %r9
	addq 40(%rsp), %r9
	addq %r15, %r9
	addq %r14, %r9
	addq %r9, %r8
	addq %r8, %rdi
	addq %rdi, %rsi
	addq %rsi, %rdx
	addq %rdx, %rcx
	addq %r13, %rcx
	addq %r12, %rcx
	addq %rbx, %rcx
	addq %r11, %rcx
	addq %r10, %rcx
	addq %rcx, %rax
	popq %r15
	popq %r14
	popq %r13
	popq %r12
	popq %rbx
	addq $144, %rsp
	ret
/* end function loadsw_w_pressure */

.text
.balign 16
.globl _loadsw_l_fold
_loadsw_l_fold:
	endbr64
	movslq 17(%rdi), %rax
	ret
/* end function loadsw_l_fold */

.text
.balign 16
.globl _loadsw_l_negative
_loadsw_l_negative:
	endbr64
	movslq -17(%rdi), %rax
	ret
/* end function loadsw_l_negative */

.text
.balign 16
.globl _loadsw_l_max
_loadsw_l_max:
	endbr64
	movslq 2147483647(%rdi), %rax
	ret
/* end function loadsw_l_max */

.text
.balign 16
.globl _loadsw_l_min
_loadsw_l_min:
	endbr64
	movslq -2147483648(%rdi), %rax
	ret
/* end function loadsw_l_min */

.text
.balign 16
.globl _loadsw_l_shared
_loadsw_l_shared:
	endbr64
	movq %rdi, %rcx
	addq $17, %rcx
	movslq 17(%rdi), %rax
	movq %rcx, _saved_address(%rip)
	ret
/* end function loadsw_l_shared */

.text
.balign 16
.globl _loadsw_l_debug
_loadsw_l_debug:
	endbr64
	.loc 1 23
	movslq 17(%rdi), %rax
	ret
/* end function loadsw_l_debug */

.text
.balign 16
.globl _loadsw_l_pressure
_loadsw_l_pressure:
	endbr64
	subq $144, %rsp
	pushq %rbx
	pushq %r12
	pushq %r13
	pushq %r14
	pushq %r15
	movq 336(%rsp), %rax
	movq 328(%rsp), %r10
	movq 320(%rsp), %r11
	movq 312(%rsp), %rbx
	movq 304(%rsp), %r12
	movq 296(%rsp), %r13
	movq 288(%rsp), %r14
	movq %r14, 160(%rsp)
	movq 280(%rsp), %r14
	movq %r14, 152(%rsp)
	movq 272(%rsp), %r14
	movq %r14, 144(%rsp)
	movq 264(%rsp), %r14
	movq %r14, 136(%rsp)
	movq 256(%rsp), %r14
	movq %r14, 128(%rsp)
	movq 248(%rsp), %r14
	movq 240(%rsp), %r15
	movq %r15, 168(%rsp)
	movq 232(%rsp), %r15
	movq %r15, 40(%rsp)
	movq 224(%rsp), %r15
	movq %r15, 48(%rsp)
	movq 216(%rsp), %r15
	movq %r15, 56(%rsp)
	movq 208(%rsp), %r15
	movq %r15, 64(%rsp)
	movq 200(%rsp), %r15
	movq %r15, 72(%rsp)
	movq 192(%rsp), %r15
	movq %r15, 80(%rsp)
	movq 168(%rsp), %r15
	movq %r9, 88(%rsp)
	movq %r8, 96(%rsp)
	movq %rcx, 104(%rsp)
	movq %rdx, 112(%rsp)
	movq %rsi, 120(%rsp)
	movq %rdi, %r9
	movq 160(%rsp), %rcx
	movq 152(%rsp), %rdx
	movq 144(%rsp), %rsi
	movq 136(%rsp), %rdi
	movq 128(%rsp), %r8
	movslq 17(%r9), %r9
	addq 120(%rsp), %r9
	addq 112(%rsp), %r9
	addq 104(%rsp), %r9
	addq 96(%rsp), %r9
	addq 88(%rsp), %r9
	addq 80(%rsp), %r9
	addq 72(%rsp), %r9
	addq 64(%rsp), %r9
	addq 56(%rsp), %r9
	addq 48(%rsp), %r9
	addq 40(%rsp), %r9
	addq %r15, %r9
	addq %r14, %r9
	addq %r9, %r8
	addq %r8, %rdi
	addq %rdi, %rsi
	addq %rsi, %rdx
	addq %rdx, %rcx
	addq %r13, %rcx
	addq %r12, %rcx
	addq %rbx, %rcx
	addq %r11, %rcx
	addq %r10, %rcx
	addq %rcx, %rax
	popq %r15
	popq %r14
	popq %r13
	popq %r12
	popq %rbx
	addq $144, %rsp
	ret
/* end function loadsw_l_pressure */

.text
.balign 16
.globl _loaduw_w_fold
_loaduw_w_fold:
	endbr64
	movl 17(%rdi), %eax
	movl %eax, %eax
	ret
/* end function loaduw_w_fold */

.text
.balign 16
.globl _loaduw_w_negative
_loaduw_w_negative:
	endbr64
	movl -17(%rdi), %eax
	movl %eax, %eax
	ret
/* end function loaduw_w_negative */

.text
.balign 16
.globl _loaduw_w_max
_loaduw_w_max:
	endbr64
	movl 2147483647(%rdi), %eax
	movl %eax, %eax
	ret
/* end function loaduw_w_max */

.text
.balign 16
.globl _loaduw_w_min
_loaduw_w_min:
	endbr64
	movl -2147483648(%rdi), %eax
	movl %eax, %eax
	ret
/* end function loaduw_w_min */

.text
.balign 16
.globl _loaduw_w_shared
_loaduw_w_shared:
	endbr64
	movq %rdi, %rcx
	addq $17, %rcx
	movl 17(%rdi), %eax
	movq %rcx, _saved_address(%rip)
	movl %eax, %eax
	ret
/* end function loaduw_w_shared */

.text
.balign 16
.globl _loaduw_w_debug
_loaduw_w_debug:
	endbr64
	.loc 1 23
	movl 17(%rdi), %eax
	movl %eax, %eax
	ret
/* end function loaduw_w_debug */

.text
.balign 16
.globl _loaduw_w_pressure
_loaduw_w_pressure:
	endbr64
	subq $144, %rsp
	pushq %rbx
	pushq %r12
	pushq %r13
	pushq %r14
	pushq %r15
	movq 336(%rsp), %rax
	movq 328(%rsp), %r10
	movq 320(%rsp), %r11
	movq 312(%rsp), %rbx
	movq 304(%rsp), %r12
	movq 296(%rsp), %r13
	movq 288(%rsp), %r14
	movq %r14, 160(%rsp)
	movq 280(%rsp), %r14
	movq %r14, 152(%rsp)
	movq 272(%rsp), %r14
	movq %r14, 144(%rsp)
	movq 264(%rsp), %r14
	movq %r14, 136(%rsp)
	movq 256(%rsp), %r14
	movq %r14, 128(%rsp)
	movq 248(%rsp), %r14
	movq 240(%rsp), %r15
	movq %r15, 168(%rsp)
	movq 232(%rsp), %r15
	movq %r15, 40(%rsp)
	movq 224(%rsp), %r15
	movq %r15, 48(%rsp)
	movq 216(%rsp), %r15
	movq %r15, 56(%rsp)
	movq 208(%rsp), %r15
	movq %r15, 64(%rsp)
	movq 200(%rsp), %r15
	movq %r15, 72(%rsp)
	movq 192(%rsp), %r15
	movq %r15, 80(%rsp)
	movq 168(%rsp), %r15
	movq %r9, 88(%rsp)
	movq %r8, 96(%rsp)
	movq %rcx, 104(%rsp)
	movq %rdx, 112(%rsp)
	movq %rsi, 120(%rsp)
	movq %rdi, %r9
	movq 160(%rsp), %rcx
	movq 152(%rsp), %rdx
	movq 144(%rsp), %rsi
	movq 136(%rsp), %rdi
	movq 128(%rsp), %r8
	movl 17(%r9), %r9d
	movl %r9d, %r9d
	addq 120(%rsp), %r9
	addq 112(%rsp), %r9
	addq 104(%rsp), %r9
	addq 96(%rsp), %r9
	addq 88(%rsp), %r9
	addq 80(%rsp), %r9
	addq 72(%rsp), %r9
	addq 64(%rsp), %r9
	addq 56(%rsp), %r9
	addq 48(%rsp), %r9
	addq 40(%rsp), %r9
	addq %r15, %r9
	addq %r14, %r9
	addq %r9, %r8
	addq %r8, %rdi
	addq %rdi, %rsi
	addq %rsi, %rdx
	addq %rdx, %rcx
	addq %r13, %rcx
	addq %r12, %rcx
	addq %rbx, %rcx
	addq %r11, %rcx
	addq %r10, %rcx
	addq %rcx, %rax
	popq %r15
	popq %r14
	popq %r13
	popq %r12
	popq %rbx
	addq $144, %rsp
	ret
/* end function loaduw_w_pressure */

.text
.balign 16
.globl _loaduw_l_fold
_loaduw_l_fold:
	endbr64
	movl 17(%rdi), %eax
	ret
/* end function loaduw_l_fold */

.text
.balign 16
.globl _loaduw_l_negative
_loaduw_l_negative:
	endbr64
	movl -17(%rdi), %eax
	ret
/* end function loaduw_l_negative */

.text
.balign 16
.globl _loaduw_l_max
_loaduw_l_max:
	endbr64
	movl 2147483647(%rdi), %eax
	ret
/* end function loaduw_l_max */

.text
.balign 16
.globl _loaduw_l_min
_loaduw_l_min:
	endbr64
	movl -2147483648(%rdi), %eax
	ret
/* end function loaduw_l_min */

.text
.balign 16
.globl _loaduw_l_shared
_loaduw_l_shared:
	endbr64
	movq %rdi, %rcx
	addq $17, %rcx
	movl 17(%rdi), %eax
	movq %rcx, _saved_address(%rip)
	ret
/* end function loaduw_l_shared */

.text
.balign 16
.globl _loaduw_l_debug
_loaduw_l_debug:
	endbr64
	.loc 1 23
	movl 17(%rdi), %eax
	ret
/* end function loaduw_l_debug */

.text
.balign 16
.globl _loaduw_l_pressure
_loaduw_l_pressure:
	endbr64
	subq $144, %rsp
	pushq %rbx
	pushq %r12
	pushq %r13
	pushq %r14
	pushq %r15
	movq 336(%rsp), %rax
	movq 328(%rsp), %r10
	movq 320(%rsp), %r11
	movq 312(%rsp), %rbx
	movq 304(%rsp), %r12
	movq 296(%rsp), %r13
	movq 288(%rsp), %r14
	movq %r14, 160(%rsp)
	movq 280(%rsp), %r14
	movq %r14, 152(%rsp)
	movq 272(%rsp), %r14
	movq %r14, 144(%rsp)
	movq 264(%rsp), %r14
	movq %r14, 136(%rsp)
	movq 256(%rsp), %r14
	movq %r14, 128(%rsp)
	movq 248(%rsp), %r14
	movq 240(%rsp), %r15
	movq %r15, 168(%rsp)
	movq 232(%rsp), %r15
	movq %r15, 40(%rsp)
	movq 224(%rsp), %r15
	movq %r15, 48(%rsp)
	movq 216(%rsp), %r15
	movq %r15, 56(%rsp)
	movq 208(%rsp), %r15
	movq %r15, 64(%rsp)
	movq 200(%rsp), %r15
	movq %r15, 72(%rsp)
	movq 192(%rsp), %r15
	movq %r15, 80(%rsp)
	movq 168(%rsp), %r15
	movq %r9, 88(%rsp)
	movq %r8, 96(%rsp)
	movq %rcx, 104(%rsp)
	movq %rdx, 112(%rsp)
	movq %rsi, 120(%rsp)
	movq %rdi, %r9
	movq 160(%rsp), %rcx
	movq 152(%rsp), %rdx
	movq 144(%rsp), %rsi
	movq 136(%rsp), %rdi
	movq 128(%rsp), %r8
	movl 17(%r9), %r9d
	addq 120(%rsp), %r9
	addq 112(%rsp), %r9
	addq 104(%rsp), %r9
	addq 96(%rsp), %r9
	addq 88(%rsp), %r9
	addq 80(%rsp), %r9
	addq 72(%rsp), %r9
	addq 64(%rsp), %r9
	addq 56(%rsp), %r9
	addq 48(%rsp), %r9
	addq 40(%rsp), %r9
	addq %r15, %r9
	addq %r14, %r9
	addq %r9, %r8
	addq %r8, %rdi
	addq %rdi, %rsi
	addq %rsi, %rdx
	addq %rdx, %rcx
	addq %r13, %rcx
	addq %r12, %rcx
	addq %rbx, %rcx
	addq %r11, %rcx
	addq %r10, %rcx
	addq %rcx, %rax
	popq %r15
	popq %r14
	popq %r13
	popq %r12
	popq %rbx
	addq $144, %rsp
	ret
/* end function loaduw_l_pressure */

.text
.balign 16
.globl _loadw_w_fold
_loadw_w_fold:
	endbr64
	movl 17(%rdi), %eax
	movl %eax, %eax
	ret
/* end function loadw_w_fold */

.text
.balign 16
.globl _loadw_w_negative
_loadw_w_negative:
	endbr64
	movl -17(%rdi), %eax
	movl %eax, %eax
	ret
/* end function loadw_w_negative */

.text
.balign 16
.globl _loadw_w_max
_loadw_w_max:
	endbr64
	movl 2147483647(%rdi), %eax
	movl %eax, %eax
	ret
/* end function loadw_w_max */

.text
.balign 16
.globl _loadw_w_min
_loadw_w_min:
	endbr64
	movl -2147483648(%rdi), %eax
	movl %eax, %eax
	ret
/* end function loadw_w_min */

.text
.balign 16
.globl _loadw_w_shared
_loadw_w_shared:
	endbr64
	movq %rdi, %rcx
	addq $17, %rcx
	movl 17(%rdi), %eax
	movq %rcx, _saved_address(%rip)
	movl %eax, %eax
	ret
/* end function loadw_w_shared */

.text
.balign 16
.globl _loadw_w_debug
_loadw_w_debug:
	endbr64
	.loc 1 23
	movl 17(%rdi), %eax
	movl %eax, %eax
	ret
/* end function loadw_w_debug */

.text
.balign 16
.globl _loadw_w_pressure
_loadw_w_pressure:
	endbr64
	subq $144, %rsp
	pushq %rbx
	pushq %r12
	pushq %r13
	pushq %r14
	pushq %r15
	movq 336(%rsp), %rax
	movq 328(%rsp), %r10
	movq 320(%rsp), %r11
	movq 312(%rsp), %rbx
	movq 304(%rsp), %r12
	movq 296(%rsp), %r13
	movq 288(%rsp), %r14
	movq %r14, 160(%rsp)
	movq 280(%rsp), %r14
	movq %r14, 152(%rsp)
	movq 272(%rsp), %r14
	movq %r14, 144(%rsp)
	movq 264(%rsp), %r14
	movq %r14, 136(%rsp)
	movq 256(%rsp), %r14
	movq %r14, 128(%rsp)
	movq 248(%rsp), %r14
	movq 240(%rsp), %r15
	movq %r15, 168(%rsp)
	movq 232(%rsp), %r15
	movq %r15, 40(%rsp)
	movq 224(%rsp), %r15
	movq %r15, 48(%rsp)
	movq 216(%rsp), %r15
	movq %r15, 56(%rsp)
	movq 208(%rsp), %r15
	movq %r15, 64(%rsp)
	movq 200(%rsp), %r15
	movq %r15, 72(%rsp)
	movq 192(%rsp), %r15
	movq %r15, 80(%rsp)
	movq 168(%rsp), %r15
	movq %r9, 88(%rsp)
	movq %r8, 96(%rsp)
	movq %rcx, 104(%rsp)
	movq %rdx, 112(%rsp)
	movq %rsi, 120(%rsp)
	movq %rdi, %r9
	movq 160(%rsp), %rcx
	movq 152(%rsp), %rdx
	movq 144(%rsp), %rsi
	movq 136(%rsp), %rdi
	movq 128(%rsp), %r8
	movl 17(%r9), %r9d
	movl %r9d, %r9d
	addq 120(%rsp), %r9
	addq 112(%rsp), %r9
	addq 104(%rsp), %r9
	addq 96(%rsp), %r9
	addq 88(%rsp), %r9
	addq 80(%rsp), %r9
	addq 72(%rsp), %r9
	addq 64(%rsp), %r9
	addq 56(%rsp), %r9
	addq 48(%rsp), %r9
	addq 40(%rsp), %r9
	addq %r15, %r9
	addq %r14, %r9
	addq %r9, %r8
	addq %r8, %rdi
	addq %rdi, %rsi
	addq %rsi, %rdx
	addq %rdx, %rcx
	addq %r13, %rcx
	addq %r12, %rcx
	addq %rbx, %rcx
	addq %r11, %rcx
	addq %r10, %rcx
	addq %rcx, %rax
	popq %r15
	popq %r14
	popq %r13
	popq %r12
	popq %rbx
	addq $144, %rsp
	ret
/* end function loadw_w_pressure */

.text
.balign 16
.globl _loads_w_fold
_loads_w_fold:
	endbr64
	movss 17(%rdi), %xmm0
	movq %xmm0, %rax
	movl %eax, %eax
	ret
/* end function loads_w_fold */

.text
.balign 16
.globl _loads_w_negative
_loads_w_negative:
	endbr64
	movss -17(%rdi), %xmm0
	movq %xmm0, %rax
	movl %eax, %eax
	ret
/* end function loads_w_negative */

.text
.balign 16
.globl _loads_w_max
_loads_w_max:
	endbr64
	movss 2147483647(%rdi), %xmm0
	movq %xmm0, %rax
	movl %eax, %eax
	ret
/* end function loads_w_max */

.text
.balign 16
.globl _loads_w_min
_loads_w_min:
	endbr64
	movss -2147483648(%rdi), %xmm0
	movq %xmm0, %rax
	movl %eax, %eax
	ret
/* end function loads_w_min */

.text
.balign 16
.globl _loads_w_shared
_loads_w_shared:
	endbr64
	movq %rdi, %rax
	addq $17, %rax
	movss 17(%rdi), %xmm0
	movq %rax, _saved_address(%rip)
	movq %xmm0, %rax
	movl %eax, %eax
	ret
/* end function loads_w_shared */

.text
.balign 16
.globl _loads_w_debug
_loads_w_debug:
	endbr64
	.loc 1 23
	movss 17(%rdi), %xmm0
	movq %xmm0, %rax
	movl %eax, %eax
	ret
/* end function loads_w_debug */

.text
.balign 16
.globl _loads_w_pressure
_loads_w_pressure:
	endbr64
	subq $144, %rsp
	pushq %rbx
	pushq %r12
	pushq %r13
	pushq %r14
	pushq %r15
	movq 336(%rsp), %rax
	movq 328(%rsp), %r10
	movq 320(%rsp), %r11
	movq 312(%rsp), %rbx
	movq 304(%rsp), %r12
	movq 296(%rsp), %r13
	movq 288(%rsp), %r14
	movq %r14, 160(%rsp)
	movq 280(%rsp), %r14
	movq %r14, 152(%rsp)
	movq 272(%rsp), %r14
	movq %r14, 144(%rsp)
	movq 264(%rsp), %r14
	movq %r14, 136(%rsp)
	movq 256(%rsp), %r14
	movq %r14, 128(%rsp)
	movq 248(%rsp), %r14
	movq 240(%rsp), %r15
	movq %r15, 168(%rsp)
	movq 232(%rsp), %r15
	movq %r15, 40(%rsp)
	movq 224(%rsp), %r15
	movq %r15, 48(%rsp)
	movq 216(%rsp), %r15
	movq %r15, 56(%rsp)
	movq 208(%rsp), %r15
	movq %r15, 64(%rsp)
	movq 200(%rsp), %r15
	movq %r15, 72(%rsp)
	movq 192(%rsp), %r15
	movq %r15, 80(%rsp)
	movq 168(%rsp), %r15
	movq %r9, 88(%rsp)
	movq %r8, 96(%rsp)
	movq %rcx, 104(%rsp)
	movq %rdx, 112(%rsp)
	movq %rsi, 120(%rsp)
	movq %rdi, %r9
	movq 160(%rsp), %rcx
	movq 152(%rsp), %rdx
	movq 144(%rsp), %rsi
	movq 136(%rsp), %rdi
	movq 128(%rsp), %r8
	movss 17(%r9), %xmm0
	movq %xmm0, %r9
	movl %r9d, %r9d
	addq 120(%rsp), %r9
	addq 112(%rsp), %r9
	addq 104(%rsp), %r9
	addq 96(%rsp), %r9
	addq 88(%rsp), %r9
	addq 80(%rsp), %r9
	addq 72(%rsp), %r9
	addq 64(%rsp), %r9
	addq 56(%rsp), %r9
	addq 48(%rsp), %r9
	addq 40(%rsp), %r9
	addq %r15, %r9
	addq %r14, %r9
	addq %r9, %r8
	addq %r8, %rdi
	addq %rdi, %rsi
	addq %rsi, %rdx
	addq %rdx, %rcx
	addq %r13, %rcx
	addq %r12, %rcx
	addq %rbx, %rcx
	addq %r11, %rcx
	addq %r10, %rcx
	addq %rcx, %rax
	popq %r15
	popq %r14
	popq %r13
	popq %r12
	popq %rbx
	addq $144, %rsp
	ret
/* end function loads_w_pressure */

.text
.balign 16
.globl _loadl_l_fold
_loadl_l_fold:
	endbr64
	movq 17(%rdi), %rax
	ret
/* end function loadl_l_fold */

.text
.balign 16
.globl _loadl_l_negative
_loadl_l_negative:
	endbr64
	movq -17(%rdi), %rax
	ret
/* end function loadl_l_negative */

.text
.balign 16
.globl _loadl_l_max
_loadl_l_max:
	endbr64
	movq 2147483647(%rdi), %rax
	ret
/* end function loadl_l_max */

.text
.balign 16
.globl _loadl_l_min
_loadl_l_min:
	endbr64
	movq -2147483648(%rdi), %rax
	ret
/* end function loadl_l_min */

.text
.balign 16
.globl _loadl_l_shared
_loadl_l_shared:
	endbr64
	movq %rdi, %rcx
	addq $17, %rcx
	movq 17(%rdi), %rax
	movq %rcx, _saved_address(%rip)
	ret
/* end function loadl_l_shared */

.text
.balign 16
.globl _loadl_l_debug
_loadl_l_debug:
	endbr64
	.loc 1 23
	movq 17(%rdi), %rax
	ret
/* end function loadl_l_debug */

.text
.balign 16
.globl _loadl_l_pressure
_loadl_l_pressure:
	endbr64
	subq $144, %rsp
	pushq %rbx
	pushq %r12
	pushq %r13
	pushq %r14
	pushq %r15
	movq 336(%rsp), %rax
	movq 328(%rsp), %r10
	movq 320(%rsp), %r11
	movq 312(%rsp), %rbx
	movq 304(%rsp), %r12
	movq 296(%rsp), %r13
	movq 288(%rsp), %r14
	movq %r14, 160(%rsp)
	movq 280(%rsp), %r14
	movq %r14, 152(%rsp)
	movq 272(%rsp), %r14
	movq %r14, 144(%rsp)
	movq 264(%rsp), %r14
	movq %r14, 136(%rsp)
	movq 256(%rsp), %r14
	movq %r14, 128(%rsp)
	movq 248(%rsp), %r14
	movq 240(%rsp), %r15
	movq %r15, 168(%rsp)
	movq 232(%rsp), %r15
	movq %r15, 40(%rsp)
	movq 224(%rsp), %r15
	movq %r15, 48(%rsp)
	movq 216(%rsp), %r15
	movq %r15, 56(%rsp)
	movq 208(%rsp), %r15
	movq %r15, 64(%rsp)
	movq 200(%rsp), %r15
	movq %r15, 72(%rsp)
	movq 192(%rsp), %r15
	movq %r15, 80(%rsp)
	movq 168(%rsp), %r15
	movq %r9, 88(%rsp)
	movq %r8, 96(%rsp)
	movq %rcx, 104(%rsp)
	movq %rdx, 112(%rsp)
	movq %rsi, 120(%rsp)
	movq %rdi, %r9
	movq 160(%rsp), %rcx
	movq 152(%rsp), %rdx
	movq 144(%rsp), %rsi
	movq 136(%rsp), %rdi
	movq 128(%rsp), %r8
	movq 17(%r9), %r9
	addq 120(%rsp), %r9
	addq 112(%rsp), %r9
	addq 104(%rsp), %r9
	addq 96(%rsp), %r9
	addq 88(%rsp), %r9
	addq 80(%rsp), %r9
	addq 72(%rsp), %r9
	addq 64(%rsp), %r9
	addq 56(%rsp), %r9
	addq 48(%rsp), %r9
	addq 40(%rsp), %r9
	addq %r15, %r9
	addq %r14, %r9
	addq %r9, %r8
	addq %r8, %rdi
	addq %rdi, %rsi
	addq %rsi, %rdx
	addq %rdx, %rcx
	addq %r13, %rcx
	addq %r12, %rcx
	addq %rbx, %rcx
	addq %r11, %rcx
	addq %r10, %rcx
	addq %rcx, %rax
	popq %r15
	popq %r14
	popq %r13
	popq %r12
	popq %rbx
	addq $144, %rsp
	ret
/* end function loadl_l_pressure */

.text
.balign 16
.globl _loadd_l_fold
_loadd_l_fold:
	endbr64
	movsd 17(%rdi), %xmm0
	movq %xmm0, %rax
	ret
/* end function loadd_l_fold */

.text
.balign 16
.globl _loadd_l_negative
_loadd_l_negative:
	endbr64
	movsd -17(%rdi), %xmm0
	movq %xmm0, %rax
	ret
/* end function loadd_l_negative */

.text
.balign 16
.globl _loadd_l_max
_loadd_l_max:
	endbr64
	movsd 2147483647(%rdi), %xmm0
	movq %xmm0, %rax
	ret
/* end function loadd_l_max */

.text
.balign 16
.globl _loadd_l_min
_loadd_l_min:
	endbr64
	movsd -2147483648(%rdi), %xmm0
	movq %xmm0, %rax
	ret
/* end function loadd_l_min */

.text
.balign 16
.globl _loadd_l_shared
_loadd_l_shared:
	endbr64
	movq %rdi, %rax
	addq $17, %rax
	movsd 17(%rdi), %xmm0
	movq %rax, _saved_address(%rip)
	movq %xmm0, %rax
	ret
/* end function loadd_l_shared */

.text
.balign 16
.globl _loadd_l_debug
_loadd_l_debug:
	endbr64
	.loc 1 23
	movsd 17(%rdi), %xmm0
	movq %xmm0, %rax
	ret
/* end function loadd_l_debug */

.text
.balign 16
.globl _loadd_l_pressure
_loadd_l_pressure:
	endbr64
	subq $144, %rsp
	pushq %rbx
	pushq %r12
	pushq %r13
	pushq %r14
	pushq %r15
	movq 336(%rsp), %rax
	movq 328(%rsp), %r10
	movq 320(%rsp), %r11
	movq 312(%rsp), %rbx
	movq 304(%rsp), %r12
	movq 296(%rsp), %r13
	movq 288(%rsp), %r14
	movq %r14, 160(%rsp)
	movq 280(%rsp), %r14
	movq %r14, 152(%rsp)
	movq 272(%rsp), %r14
	movq %r14, 144(%rsp)
	movq 264(%rsp), %r14
	movq %r14, 136(%rsp)
	movq 256(%rsp), %r14
	movq %r14, 128(%rsp)
	movq 248(%rsp), %r14
	movq 240(%rsp), %r15
	movq %r15, 168(%rsp)
	movq 232(%rsp), %r15
	movq %r15, 40(%rsp)
	movq 224(%rsp), %r15
	movq %r15, 48(%rsp)
	movq 216(%rsp), %r15
	movq %r15, 56(%rsp)
	movq 208(%rsp), %r15
	movq %r15, 64(%rsp)
	movq 200(%rsp), %r15
	movq %r15, 72(%rsp)
	movq 192(%rsp), %r15
	movq %r15, 80(%rsp)
	movq 168(%rsp), %r15
	movq %r9, 88(%rsp)
	movq %r8, 96(%rsp)
	movq %rcx, 104(%rsp)
	movq %rdx, 112(%rsp)
	movq %rsi, 120(%rsp)
	movq %rdi, %r9
	movq 160(%rsp), %rcx
	movq 152(%rsp), %rdx
	movq 144(%rsp), %rsi
	movq 136(%rsp), %rdi
	movq 128(%rsp), %r8
	movsd 17(%r9), %xmm0
	movq %xmm0, %r9
	addq 120(%rsp), %r9
	addq 112(%rsp), %r9
	addq 104(%rsp), %r9
	addq 96(%rsp), %r9
	addq 88(%rsp), %r9
	addq 80(%rsp), %r9
	addq 72(%rsp), %r9
	addq 64(%rsp), %r9
	addq 56(%rsp), %r9
	addq 48(%rsp), %r9
	addq 40(%rsp), %r9
	addq %r15, %r9
	addq %r14, %r9
	addq %r9, %r8
	addq %r8, %rdi
	addq %rdi, %rsi
	addq %rsi, %rdx
	addq %rdx, %rcx
	addq %r13, %rcx
	addq %r12, %rcx
	addq %rbx, %rcx
	addq %r11, %rcx
	addq %r10, %rcx
	addq %rcx, %rax
	popq %r15
	popq %r14
	popq %r13
	popq %r12
	popq %rbx
	addq $144, %rsp
	ret
/* end function loadd_l_pressure */

