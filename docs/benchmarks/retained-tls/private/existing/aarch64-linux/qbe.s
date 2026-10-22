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
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	cmp	w0, #0
	bne	.L2
	mrs	x0, tpidr_el0
	add	x0, x0, #:tprel_hi12:custom_init, lsl #12
	add	x0, x0, #:tprel_lo12_nc:custom_init
	ldr	x0, [x0]
	b	.L3
.L2:
	mrs	x0, tpidr_el0
	add	x0, x0, #:tprel_hi12:custom_zero, lsl #12
	add	x0, x0, #:tprel_lo12_nc:custom_zero
	ldr	x0, [x0]
.L3:
	ldp	x29, x30, [sp], 16
	ret
.type read_custom, @function
.size read_custom, .-read_custom
/* end function read_custom */

.text
.balign 16
.globl write_custom
write_custom:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mrs	x2, tpidr_el0
	add	x2, x2, #:tprel_hi12:custom_init, lsl #12
	add	x2, x2, #:tprel_lo12_nc:custom_init
	str	x0, [x2]
	mrs	x0, tpidr_el0
	add	x0, x0, #:tprel_hi12:custom_zero, lsl #12
	add	x0, x0, #:tprel_lo12_nc:custom_zero
	str	x1, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type write_custom, @function
.size write_custom, .-write_custom
/* end function write_custom */

.text
.balign 16
.globl read_local
read_local:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mrs	x0, tpidr_el0
	add	x0, x0, #:tprel_hi12:custom_local, lsl #12
	add	x0, x0, #:tprel_lo12_nc:custom_local
	ldr	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type read_local, @function
.size read_local, .-read_local
/* end function read_local */

.text
.balign 16
.globl write_local
write_local:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mrs	x1, tpidr_el0
	add	x1, x1, #:tprel_hi12:custom_local, lsl #12
	add	x1, x1, #:tprel_lo12_nc:custom_local
	str	x0, [x1]
	ldp	x29, x30, [sp], 16
	ret
.type write_local, @function
.size write_local, .-write_local
/* end function write_local */

.text
.balign 16
.globl read_ordinary
read_ordinary:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mrs	x0, tpidr_el0
	add	x0, x0, #:tprel_hi12:ordinary, lsl #12
	add	x0, x0, #:tprel_lo12_nc:ordinary
	ldr	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type read_ordinary, @function
.size read_ordinary, .-read_ordinary
/* end function read_ordinary */

.text
.balign 16
.globl write_ordinary
write_ordinary:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mrs	x1, tpidr_el0
	add	x1, x1, #:tprel_hi12:ordinary, lsl #12
	add	x1, x1, #:tprel_lo12_nc:ordinary
	str	x0, [x1]
	ldp	x29, x30, [sp], 16
	ret
.type write_ordinary, @function
.size write_ordinary, .-write_ordinary
/* end function write_ordinary */

.section .note.GNU-stack,"",@progbits
