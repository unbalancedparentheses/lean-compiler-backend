.section ".lcb_tls.init","awT"
.balign 16
.globl custom_init
custom_init:
	.quad 37
/* end data */

.section ".lcb_tls.zero","waT"
.balign 32
.globl custom_zero
custom_zero:
	.fill 8,1,0
/* end data */

.section ".lcb_tls.local","Taw"
.balign 8
custom_local:
	.quad 73
/* end data */

.section .tdata,"awT"
.balign 8
.globl ordinary
ordinary:
	.quad 19
/* end data */

.text
.balign 16
.globl read_custom
read_custom:
	endbr64
	cmpl $0, %edi
	jnz .Lbb2
	movq %fs:custom_init@tpoff, %rax
	jmp .Lbb3
.Lbb2:
	movq %fs:custom_zero@tpoff, %rax
.Lbb3:
	ret
.type read_custom, @function
.size read_custom, .-read_custom
/* end function read_custom */

.text
.balign 16
.globl write_custom
write_custom:
	endbr64
	movq %rdi, %fs:custom_init@tpoff
	movq %rsi, %fs:custom_zero@tpoff
	ret
.type write_custom, @function
.size write_custom, .-write_custom
/* end function write_custom */

.text
.balign 16
.globl read_local
read_local:
	endbr64
	movq %fs:custom_local@tpoff, %rax
	ret
.type read_local, @function
.size read_local, .-read_local
/* end function read_local */

.text
.balign 16
.globl write_local
write_local:
	endbr64
	movq %rdi, %fs:custom_local@tpoff
	ret
.type write_local, @function
.size write_local, .-write_local
/* end function write_local */

.text
.balign 16
.globl read_ordinary
read_ordinary:
	endbr64
	movq %fs:ordinary@tpoff, %rax
	ret
.type read_ordinary, @function
.size read_ordinary, .-read_ordinary
/* end function read_ordinary */

.text
.balign 16
.globl write_ordinary
write_ordinary:
	endbr64
	movq %rdi, %fs:ordinary@tpoff
	ret
.type write_ordinary, @function
.size write_ordinary, .-write_ordinary
/* end function write_ordinary */

.section .note.GNU-stack,"",@progbits
