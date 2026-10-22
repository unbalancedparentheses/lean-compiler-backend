.file 1 "scaled.c"
.text
.balign 16
.globl ub_w_plain
ub_w_plain:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type ub_w_plain, @function
.size ub_w_plain, .-ub_w_plain
/* end function ub_w_plain */

.text
.balign 16
.globl ub_w_commuted
ub_w_commuted:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type ub_w_commuted, @function
.size ub_w_commuted, .-ub_w_commuted
/* end function ub_w_commuted */

.text
.balign 16
.globl ub_w_zero
ub_w_zero:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type ub_w_zero, @function
.size ub_w_zero, .-ub_w_zero
/* end function ub_w_zero */

.text
.balign 16
.globl ub_w_debug_shift
ub_w_debug_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	.loc 1 41 2
	add	x0, x0, x1
	ldrb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type ub_w_debug_shift, @function
.size ub_w_debug_shift, .-ub_w_debug_shift
/* end function ub_w_debug_shift */

.text
.balign 16
.globl ub_w_debug_add
ub_w_debug_add:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	.loc 1 42 3
	ldrb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type ub_w_debug_add, @function
.size ub_w_debug_add, .-ub_w_debug_add
/* end function ub_w_debug_add */

.text
.balign 16
.globl ub_w_shared_shift
ub_w_shared_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrb	w0, [x0]
	eor	w0, w1, w0
	ldp	x29, x30, [sp], 16
	ret
.type ub_w_shared_shift, @function
.size ub_w_shared_shift, .-ub_w_shared_shift
/* end function ub_w_shared_shift */

.text
.balign 16
.globl ub_w_shared_address
ub_w_shared_address:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrb	w1, [x0]
	eor	w0, w0, w1
	ldp	x29, x30, [sp], 16
	ret
.type ub_w_shared_address, @function
.size ub_w_shared_address, .-ub_w_shared_address
/* end function ub_w_shared_address */

.text
.balign 16
.globl ub_w_separated
ub_w_separated:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	x17, x1
	mov	x1, x0
	mov	x0, x17
	add	x1, x1, x0
	mov	x2, #991
	eor	x0, x0, x2
	ldrb	w1, [x1]
	eor	w0, w0, w1
	ldp	x29, x30, [sp], 16
	ret
.type ub_w_separated, @function
.size ub_w_separated, .-ub_w_separated
/* end function ub_w_separated */

.text
.balign 16
.globl ub_w_wrong_scale
ub_w_wrong_scale:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type ub_w_wrong_scale, @function
.size ub_w_wrong_scale, .-ub_w_wrong_scale
/* end function ub_w_wrong_scale */

.text
.balign 16
.globl ub_w_word_shift
ub_w_word_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w1, w1
	add	x0, x0, x1
	ldrb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type ub_w_word_shift, @function
.size ub_w_word_shift, .-ub_w_word_shift
/* end function ub_w_word_shift */

.text
.balign 16
.globl ub_w_barrier_call
ub_w_barrier_call:
	hint	#34
	stp	x29, x30, [sp, -32]!
	mov	x29, sp
	str	x19, [x29, 24]
	add	x19, x0, x1
	bl	scaled_barrier
	ldrb	w0, [x19]
	ldr	x19, [x29, 24]
	ldp	x29, x30, [sp], 32
	ret
.type ub_w_barrier_call, @function
.size ub_w_barrier_call, .-ub_w_barrier_call
/* end function ub_w_barrier_call */

.text
.balign 16
.globl ub_w_live
ub_w_live:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrb	w0, [x0]
	eor	w0, w1, w0
	ldp	x29, x30, [sp], 16
	ret
.type ub_w_live, @function
.size ub_w_live, .-ub_w_live
/* end function ub_w_live */

.text
.balign 16
.globl ub_w_pressure
ub_w_pressure:
	hint	#34
	stp	x29, x30, [sp, -96]!
	mov	x29, sp
	str	x19, [x29, 88]
	str	x20, [x29, 80]
	str	x21, [x29, 72]
	str	x22, [x29, 64]
	str	x23, [x29, 56]
	str	x24, [x29, 48]
	str	x25, [x29, 40]
	str	x26, [x29, 32]
	str	x27, [x29, 24]
	ldr	x8, [x29, 232]
	ldr	x9, [x29, 224]
	ldr	x10, [x29, 216]
	ldr	x11, [x29, 208]
	ldr	x12, [x29, 200]
	ldr	x13, [x29, 192]
	ldr	x14, [x29, 184]
	ldr	x15, [x29, 176]
	ldr	x16, [x29, 168]
	ldr	x19, [x29, 160]
	ldr	x20, [x29, 152]
	ldr	x21, [x29, 144]
	ldr	x22, [x29, 136]
	ldr	x23, [x29, 128]
	ldr	x24, [x29, 120]
	ldr	x25, [x29, 112]
	ldr	x26, [x29, 104]
	ldr	x27, [x29, 96]
	mov	x17, x4
	mov	x4, x3
	mov	x3, x17
	mov	x17, x5
	mov	x5, x2
	mov	x2, x17
	mov	x17, x7
	mov	x7, x0
	mov	x0, x17
	mov	x17, x1
	mov	x1, x7
	mov	x7, x17
	mov	x17, x6
	mov	x6, x1
	mov	x1, x17
	add	x6, x6, x7
	ldrb	w6, [x6]
	add	w5, w5, w6
	add	w4, w4, w5
	add	w3, w3, w4
	add	w2, w2, w3
	add	w1, w1, w2
	add	w0, w0, w1
	add	w0, w27, w0
	add	w0, w26, w0
	add	w0, w25, w0
	add	w0, w24, w0
	add	w0, w23, w0
	add	w0, w22, w0
	add	w0, w21, w0
	add	w0, w20, w0
	add	w0, w19, w0
	add	w0, w16, w0
	add	w0, w15, w0
	add	w0, w14, w0
	add	w0, w13, w0
	add	w0, w12, w0
	add	w0, w11, w0
	add	w0, w10, w0
	add	w0, w9, w0
	add	w0, w8, w0
	ldr	x19, [x29, 88]
	ldr	x20, [x29, 80]
	ldr	x21, [x29, 72]
	ldr	x22, [x29, 64]
	ldr	x23, [x29, 56]
	ldr	x24, [x29, 48]
	ldr	x25, [x29, 40]
	ldr	x26, [x29, 32]
	ldr	x27, [x29, 24]
	ldp	x29, x30, [sp], 96
	ret
.type ub_w_pressure, @function
.size ub_w_pressure, .-ub_w_pressure
/* end function ub_w_pressure */

.text
.balign 16
.globl ub_w_extension
ub_w_extension:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrb	w0, [x0]
	uxtb	w0, w0
	ldp	x29, x30, [sp], 16
	ret
.type ub_w_extension, @function
.size ub_w_extension, .-ub_w_extension
/* end function ub_w_extension */

.text
.balign 16
.globl ub_l_plain
ub_l_plain:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type ub_l_plain, @function
.size ub_l_plain, .-ub_l_plain
/* end function ub_l_plain */

.text
.balign 16
.globl ub_l_commuted
ub_l_commuted:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type ub_l_commuted, @function
.size ub_l_commuted, .-ub_l_commuted
/* end function ub_l_commuted */

.text
.balign 16
.globl ub_l_zero
ub_l_zero:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type ub_l_zero, @function
.size ub_l_zero, .-ub_l_zero
/* end function ub_l_zero */

.text
.balign 16
.globl ub_l_debug_shift
ub_l_debug_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	.loc 1 41 2
	add	x0, x0, x1
	ldrb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type ub_l_debug_shift, @function
.size ub_l_debug_shift, .-ub_l_debug_shift
/* end function ub_l_debug_shift */

.text
.balign 16
.globl ub_l_debug_add
ub_l_debug_add:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	.loc 1 42 3
	ldrb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type ub_l_debug_add, @function
.size ub_l_debug_add, .-ub_l_debug_add
/* end function ub_l_debug_add */

.text
.balign 16
.globl ub_l_shared_shift
ub_l_shared_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrb	w0, [x0]
	eor	x0, x1, x0
	ldp	x29, x30, [sp], 16
	ret
.type ub_l_shared_shift, @function
.size ub_l_shared_shift, .-ub_l_shared_shift
/* end function ub_l_shared_shift */

.text
.balign 16
.globl ub_l_shared_address
ub_l_shared_address:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrb	w1, [x0]
	eor	x0, x0, x1
	ldp	x29, x30, [sp], 16
	ret
.type ub_l_shared_address, @function
.size ub_l_shared_address, .-ub_l_shared_address
/* end function ub_l_shared_address */

.text
.balign 16
.globl ub_l_separated
ub_l_separated:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	x17, x1
	mov	x1, x0
	mov	x0, x17
	add	x1, x1, x0
	mov	x2, #991
	eor	x0, x0, x2
	ldrb	w1, [x1]
	eor	x0, x0, x1
	ldp	x29, x30, [sp], 16
	ret
.type ub_l_separated, @function
.size ub_l_separated, .-ub_l_separated
/* end function ub_l_separated */

.text
.balign 16
.globl ub_l_wrong_scale
ub_l_wrong_scale:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type ub_l_wrong_scale, @function
.size ub_l_wrong_scale, .-ub_l_wrong_scale
/* end function ub_l_wrong_scale */

.text
.balign 16
.globl ub_l_word_shift
ub_l_word_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w1, w1
	add	x0, x0, x1
	ldrb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type ub_l_word_shift, @function
.size ub_l_word_shift, .-ub_l_word_shift
/* end function ub_l_word_shift */

.text
.balign 16
.globl ub_l_barrier_call
ub_l_barrier_call:
	hint	#34
	stp	x29, x30, [sp, -32]!
	mov	x29, sp
	str	x19, [x29, 24]
	add	x19, x0, x1
	bl	scaled_barrier
	ldrb	w0, [x19]
	ldr	x19, [x29, 24]
	ldp	x29, x30, [sp], 32
	ret
.type ub_l_barrier_call, @function
.size ub_l_barrier_call, .-ub_l_barrier_call
/* end function ub_l_barrier_call */

.text
.balign 16
.globl ub_l_live
ub_l_live:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrb	w0, [x0]
	eor	x0, x1, x0
	ldp	x29, x30, [sp], 16
	ret
.type ub_l_live, @function
.size ub_l_live, .-ub_l_live
/* end function ub_l_live */

.text
.balign 16
.globl ub_l_pressure
ub_l_pressure:
	hint	#34
	stp	x29, x30, [sp, -96]!
	mov	x29, sp
	str	x19, [x29, 88]
	str	x20, [x29, 80]
	str	x21, [x29, 72]
	str	x22, [x29, 64]
	str	x23, [x29, 56]
	str	x24, [x29, 48]
	str	x25, [x29, 40]
	str	x26, [x29, 32]
	str	x27, [x29, 24]
	ldr	x8, [x29, 232]
	ldr	x9, [x29, 224]
	ldr	x10, [x29, 216]
	ldr	x11, [x29, 208]
	ldr	x12, [x29, 200]
	ldr	x13, [x29, 192]
	ldr	x14, [x29, 184]
	ldr	x15, [x29, 176]
	ldr	x16, [x29, 168]
	ldr	x19, [x29, 160]
	ldr	x20, [x29, 152]
	ldr	x21, [x29, 144]
	ldr	x22, [x29, 136]
	ldr	x23, [x29, 128]
	ldr	x24, [x29, 120]
	ldr	x25, [x29, 112]
	ldr	x26, [x29, 104]
	ldr	x27, [x29, 96]
	mov	x17, x4
	mov	x4, x3
	mov	x3, x17
	mov	x17, x5
	mov	x5, x2
	mov	x2, x17
	mov	x17, x7
	mov	x7, x0
	mov	x0, x17
	mov	x17, x1
	mov	x1, x7
	mov	x7, x17
	mov	x17, x6
	mov	x6, x1
	mov	x1, x17
	add	x6, x6, x7
	ldrb	w6, [x6]
	add	x5, x5, x6
	add	x4, x4, x5
	add	x3, x3, x4
	add	x2, x2, x3
	add	x1, x1, x2
	add	x0, x0, x1
	add	x0, x27, x0
	add	x0, x26, x0
	add	x0, x25, x0
	add	x0, x24, x0
	add	x0, x23, x0
	add	x0, x22, x0
	add	x0, x21, x0
	add	x0, x20, x0
	add	x0, x19, x0
	add	x0, x16, x0
	add	x0, x15, x0
	add	x0, x14, x0
	add	x0, x13, x0
	add	x0, x12, x0
	add	x0, x11, x0
	add	x0, x10, x0
	add	x0, x9, x0
	add	x0, x8, x0
	ldr	x19, [x29, 88]
	ldr	x20, [x29, 80]
	ldr	x21, [x29, 72]
	ldr	x22, [x29, 64]
	ldr	x23, [x29, 56]
	ldr	x24, [x29, 48]
	ldr	x25, [x29, 40]
	ldr	x26, [x29, 32]
	ldr	x27, [x29, 24]
	ldp	x29, x30, [sp], 96
	ret
.type ub_l_pressure, @function
.size ub_l_pressure, .-ub_l_pressure
/* end function ub_l_pressure */

.text
.balign 16
.globl ub_l_extension
ub_l_extension:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type ub_l_extension, @function
.size ub_l_extension, .-ub_l_extension
/* end function ub_l_extension */

.text
.balign 16
.globl sb_w_plain
sb_w_plain:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrsb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type sb_w_plain, @function
.size sb_w_plain, .-sb_w_plain
/* end function sb_w_plain */

.text
.balign 16
.globl sb_w_commuted
sb_w_commuted:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrsb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type sb_w_commuted, @function
.size sb_w_commuted, .-sb_w_commuted
/* end function sb_w_commuted */

.text
.balign 16
.globl sb_w_zero
sb_w_zero:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrsb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type sb_w_zero, @function
.size sb_w_zero, .-sb_w_zero
/* end function sb_w_zero */

.text
.balign 16
.globl sb_w_debug_shift
sb_w_debug_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	.loc 1 41 2
	add	x0, x0, x1
	ldrsb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type sb_w_debug_shift, @function
.size sb_w_debug_shift, .-sb_w_debug_shift
/* end function sb_w_debug_shift */

.text
.balign 16
.globl sb_w_debug_add
sb_w_debug_add:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	.loc 1 42 3
	ldrsb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type sb_w_debug_add, @function
.size sb_w_debug_add, .-sb_w_debug_add
/* end function sb_w_debug_add */

.text
.balign 16
.globl sb_w_shared_shift
sb_w_shared_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrsb	w0, [x0]
	eor	w0, w1, w0
	ldp	x29, x30, [sp], 16
	ret
.type sb_w_shared_shift, @function
.size sb_w_shared_shift, .-sb_w_shared_shift
/* end function sb_w_shared_shift */

.text
.balign 16
.globl sb_w_shared_address
sb_w_shared_address:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrsb	w1, [x0]
	eor	w0, w0, w1
	ldp	x29, x30, [sp], 16
	ret
.type sb_w_shared_address, @function
.size sb_w_shared_address, .-sb_w_shared_address
/* end function sb_w_shared_address */

.text
.balign 16
.globl sb_w_separated
sb_w_separated:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	x17, x1
	mov	x1, x0
	mov	x0, x17
	add	x1, x1, x0
	mov	x2, #991
	eor	x0, x0, x2
	ldrsb	w1, [x1]
	eor	w0, w0, w1
	ldp	x29, x30, [sp], 16
	ret
.type sb_w_separated, @function
.size sb_w_separated, .-sb_w_separated
/* end function sb_w_separated */

.text
.balign 16
.globl sb_w_wrong_scale
sb_w_wrong_scale:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrsb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type sb_w_wrong_scale, @function
.size sb_w_wrong_scale, .-sb_w_wrong_scale
/* end function sb_w_wrong_scale */

.text
.balign 16
.globl sb_w_word_shift
sb_w_word_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w1, w1
	add	x0, x0, x1
	ldrsb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type sb_w_word_shift, @function
.size sb_w_word_shift, .-sb_w_word_shift
/* end function sb_w_word_shift */

.text
.balign 16
.globl sb_w_barrier_call
sb_w_barrier_call:
	hint	#34
	stp	x29, x30, [sp, -32]!
	mov	x29, sp
	str	x19, [x29, 24]
	add	x19, x0, x1
	bl	scaled_barrier
	ldrsb	w0, [x19]
	ldr	x19, [x29, 24]
	ldp	x29, x30, [sp], 32
	ret
.type sb_w_barrier_call, @function
.size sb_w_barrier_call, .-sb_w_barrier_call
/* end function sb_w_barrier_call */

.text
.balign 16
.globl sb_w_live
sb_w_live:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrsb	w0, [x0]
	eor	w0, w1, w0
	ldp	x29, x30, [sp], 16
	ret
.type sb_w_live, @function
.size sb_w_live, .-sb_w_live
/* end function sb_w_live */

.text
.balign 16
.globl sb_w_pressure
sb_w_pressure:
	hint	#34
	stp	x29, x30, [sp, -96]!
	mov	x29, sp
	str	x19, [x29, 88]
	str	x20, [x29, 80]
	str	x21, [x29, 72]
	str	x22, [x29, 64]
	str	x23, [x29, 56]
	str	x24, [x29, 48]
	str	x25, [x29, 40]
	str	x26, [x29, 32]
	str	x27, [x29, 24]
	ldr	x8, [x29, 232]
	ldr	x9, [x29, 224]
	ldr	x10, [x29, 216]
	ldr	x11, [x29, 208]
	ldr	x12, [x29, 200]
	ldr	x13, [x29, 192]
	ldr	x14, [x29, 184]
	ldr	x15, [x29, 176]
	ldr	x16, [x29, 168]
	ldr	x19, [x29, 160]
	ldr	x20, [x29, 152]
	ldr	x21, [x29, 144]
	ldr	x22, [x29, 136]
	ldr	x23, [x29, 128]
	ldr	x24, [x29, 120]
	ldr	x25, [x29, 112]
	ldr	x26, [x29, 104]
	ldr	x27, [x29, 96]
	mov	x17, x4
	mov	x4, x3
	mov	x3, x17
	mov	x17, x5
	mov	x5, x2
	mov	x2, x17
	mov	x17, x7
	mov	x7, x0
	mov	x0, x17
	mov	x17, x1
	mov	x1, x7
	mov	x7, x17
	mov	x17, x6
	mov	x6, x1
	mov	x1, x17
	add	x6, x6, x7
	ldrsb	w6, [x6]
	add	w5, w5, w6
	add	w4, w4, w5
	add	w3, w3, w4
	add	w2, w2, w3
	add	w1, w1, w2
	add	w0, w0, w1
	add	w0, w27, w0
	add	w0, w26, w0
	add	w0, w25, w0
	add	w0, w24, w0
	add	w0, w23, w0
	add	w0, w22, w0
	add	w0, w21, w0
	add	w0, w20, w0
	add	w0, w19, w0
	add	w0, w16, w0
	add	w0, w15, w0
	add	w0, w14, w0
	add	w0, w13, w0
	add	w0, w12, w0
	add	w0, w11, w0
	add	w0, w10, w0
	add	w0, w9, w0
	add	w0, w8, w0
	ldr	x19, [x29, 88]
	ldr	x20, [x29, 80]
	ldr	x21, [x29, 72]
	ldr	x22, [x29, 64]
	ldr	x23, [x29, 56]
	ldr	x24, [x29, 48]
	ldr	x25, [x29, 40]
	ldr	x26, [x29, 32]
	ldr	x27, [x29, 24]
	ldp	x29, x30, [sp], 96
	ret
.type sb_w_pressure, @function
.size sb_w_pressure, .-sb_w_pressure
/* end function sb_w_pressure */

.text
.balign 16
.globl sb_l_plain
sb_l_plain:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrsb	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type sb_l_plain, @function
.size sb_l_plain, .-sb_l_plain
/* end function sb_l_plain */

.text
.balign 16
.globl sb_l_commuted
sb_l_commuted:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrsb	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type sb_l_commuted, @function
.size sb_l_commuted, .-sb_l_commuted
/* end function sb_l_commuted */

.text
.balign 16
.globl sb_l_zero
sb_l_zero:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrsb	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type sb_l_zero, @function
.size sb_l_zero, .-sb_l_zero
/* end function sb_l_zero */

.text
.balign 16
.globl sb_l_debug_shift
sb_l_debug_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	.loc 1 41 2
	add	x0, x0, x1
	ldrsb	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type sb_l_debug_shift, @function
.size sb_l_debug_shift, .-sb_l_debug_shift
/* end function sb_l_debug_shift */

.text
.balign 16
.globl sb_l_debug_add
sb_l_debug_add:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	.loc 1 42 3
	ldrsb	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type sb_l_debug_add, @function
.size sb_l_debug_add, .-sb_l_debug_add
/* end function sb_l_debug_add */

.text
.balign 16
.globl sb_l_shared_shift
sb_l_shared_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrsb	x0, [x0]
	eor	x0, x1, x0
	ldp	x29, x30, [sp], 16
	ret
.type sb_l_shared_shift, @function
.size sb_l_shared_shift, .-sb_l_shared_shift
/* end function sb_l_shared_shift */

.text
.balign 16
.globl sb_l_shared_address
sb_l_shared_address:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrsb	x1, [x0]
	eor	x0, x0, x1
	ldp	x29, x30, [sp], 16
	ret
.type sb_l_shared_address, @function
.size sb_l_shared_address, .-sb_l_shared_address
/* end function sb_l_shared_address */

.text
.balign 16
.globl sb_l_separated
sb_l_separated:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	x17, x1
	mov	x1, x0
	mov	x0, x17
	add	x1, x1, x0
	mov	x2, #991
	eor	x0, x0, x2
	ldrsb	x1, [x1]
	eor	x0, x0, x1
	ldp	x29, x30, [sp], 16
	ret
.type sb_l_separated, @function
.size sb_l_separated, .-sb_l_separated
/* end function sb_l_separated */

.text
.balign 16
.globl sb_l_wrong_scale
sb_l_wrong_scale:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrsb	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type sb_l_wrong_scale, @function
.size sb_l_wrong_scale, .-sb_l_wrong_scale
/* end function sb_l_wrong_scale */

.text
.balign 16
.globl sb_l_word_shift
sb_l_word_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w1, w1
	add	x0, x0, x1
	ldrsb	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type sb_l_word_shift, @function
.size sb_l_word_shift, .-sb_l_word_shift
/* end function sb_l_word_shift */

.text
.balign 16
.globl sb_l_barrier_call
sb_l_barrier_call:
	hint	#34
	stp	x29, x30, [sp, -32]!
	mov	x29, sp
	str	x19, [x29, 24]
	add	x19, x0, x1
	bl	scaled_barrier
	ldrsb	x0, [x19]
	ldr	x19, [x29, 24]
	ldp	x29, x30, [sp], 32
	ret
.type sb_l_barrier_call, @function
.size sb_l_barrier_call, .-sb_l_barrier_call
/* end function sb_l_barrier_call */

.text
.balign 16
.globl sb_l_live
sb_l_live:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrsb	x0, [x0]
	eor	x0, x1, x0
	ldp	x29, x30, [sp], 16
	ret
.type sb_l_live, @function
.size sb_l_live, .-sb_l_live
/* end function sb_l_live */

.text
.balign 16
.globl sb_l_pressure
sb_l_pressure:
	hint	#34
	stp	x29, x30, [sp, -96]!
	mov	x29, sp
	str	x19, [x29, 88]
	str	x20, [x29, 80]
	str	x21, [x29, 72]
	str	x22, [x29, 64]
	str	x23, [x29, 56]
	str	x24, [x29, 48]
	str	x25, [x29, 40]
	str	x26, [x29, 32]
	str	x27, [x29, 24]
	ldr	x8, [x29, 232]
	ldr	x9, [x29, 224]
	ldr	x10, [x29, 216]
	ldr	x11, [x29, 208]
	ldr	x12, [x29, 200]
	ldr	x13, [x29, 192]
	ldr	x14, [x29, 184]
	ldr	x15, [x29, 176]
	ldr	x16, [x29, 168]
	ldr	x19, [x29, 160]
	ldr	x20, [x29, 152]
	ldr	x21, [x29, 144]
	ldr	x22, [x29, 136]
	ldr	x23, [x29, 128]
	ldr	x24, [x29, 120]
	ldr	x25, [x29, 112]
	ldr	x26, [x29, 104]
	ldr	x27, [x29, 96]
	mov	x17, x4
	mov	x4, x3
	mov	x3, x17
	mov	x17, x5
	mov	x5, x2
	mov	x2, x17
	mov	x17, x7
	mov	x7, x0
	mov	x0, x17
	mov	x17, x1
	mov	x1, x7
	mov	x7, x17
	mov	x17, x6
	mov	x6, x1
	mov	x1, x17
	add	x6, x6, x7
	ldrsb	x6, [x6]
	add	x5, x5, x6
	add	x4, x4, x5
	add	x3, x3, x4
	add	x2, x2, x3
	add	x1, x1, x2
	add	x0, x0, x1
	add	x0, x27, x0
	add	x0, x26, x0
	add	x0, x25, x0
	add	x0, x24, x0
	add	x0, x23, x0
	add	x0, x22, x0
	add	x0, x21, x0
	add	x0, x20, x0
	add	x0, x19, x0
	add	x0, x16, x0
	add	x0, x15, x0
	add	x0, x14, x0
	add	x0, x13, x0
	add	x0, x12, x0
	add	x0, x11, x0
	add	x0, x10, x0
	add	x0, x9, x0
	add	x0, x8, x0
	ldr	x19, [x29, 88]
	ldr	x20, [x29, 80]
	ldr	x21, [x29, 72]
	ldr	x22, [x29, 64]
	ldr	x23, [x29, 56]
	ldr	x24, [x29, 48]
	ldr	x25, [x29, 40]
	ldr	x26, [x29, 32]
	ldr	x27, [x29, 24]
	ldp	x29, x30, [sp], 96
	ret
.type sb_l_pressure, @function
.size sb_l_pressure, .-sb_l_pressure
/* end function sb_l_pressure */

.text
.balign 16
.globl uh_w_plain
uh_w_plain:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrh	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type uh_w_plain, @function
.size uh_w_plain, .-uh_w_plain
/* end function uh_w_plain */

.text
.balign 16
.globl uh_w_commuted
uh_w_commuted:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrh	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type uh_w_commuted, @function
.size uh_w_commuted, .-uh_w_commuted
/* end function uh_w_commuted */

.text
.balign 16
.globl uh_w_zero
uh_w_zero:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrh	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type uh_w_zero, @function
.size uh_w_zero, .-uh_w_zero
/* end function uh_w_zero */

.text
.balign 16
.globl uh_w_debug_shift
uh_w_debug_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	.loc 1 41 2
	add	x0, x0, x1
	ldrh	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type uh_w_debug_shift, @function
.size uh_w_debug_shift, .-uh_w_debug_shift
/* end function uh_w_debug_shift */

.text
.balign 16
.globl uh_w_debug_add
uh_w_debug_add:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	.loc 1 42 3
	ldrh	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type uh_w_debug_add, @function
.size uh_w_debug_add, .-uh_w_debug_add
/* end function uh_w_debug_add */

.text
.balign 16
.globl uh_w_shared_shift
uh_w_shared_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	x17, x1
	mov	x1, x0
	mov	x0, x17
	mov	w2, #1
	lsl	x0, x0, x2
	add	x1, x1, x0
	ldrh	w1, [x1]
	eor	w0, w0, w1
	ldp	x29, x30, [sp], 16
	ret
.type uh_w_shared_shift, @function
.size uh_w_shared_shift, .-uh_w_shared_shift
/* end function uh_w_shared_shift */

.text
.balign 16
.globl uh_w_shared_address
uh_w_shared_address:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrh	w1, [x0]
	eor	w0, w0, w1
	ldp	x29, x30, [sp], 16
	ret
.type uh_w_shared_address, @function
.size uh_w_shared_address, .-uh_w_shared_address
/* end function uh_w_shared_address */

.text
.balign 16
.globl uh_w_separated
uh_w_separated:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	x17, x1
	mov	x1, x0
	mov	x0, x17
	mov	w2, #1
	lsl	x2, x0, x2
	add	x1, x1, x2
	mov	x2, #991
	eor	x0, x0, x2
	ldrh	w1, [x1]
	eor	w0, w0, w1
	ldp	x29, x30, [sp], 16
	ret
.type uh_w_separated, @function
.size uh_w_separated, .-uh_w_separated
/* end function uh_w_separated */

.text
.balign 16
.globl uh_w_wrong_scale
uh_w_wrong_scale:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrh	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type uh_w_wrong_scale, @function
.size uh_w_wrong_scale, .-uh_w_wrong_scale
/* end function uh_w_wrong_scale */

.text
.balign 16
.globl uh_w_word_shift
uh_w_word_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	w1, w1, w2
	mov	w1, w1
	add	x0, x0, x1
	ldrh	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type uh_w_word_shift, @function
.size uh_w_word_shift, .-uh_w_word_shift
/* end function uh_w_word_shift */

.text
.balign 16
.globl uh_w_barrier_call
uh_w_barrier_call:
	hint	#34
	stp	x29, x30, [sp, -32]!
	mov	x29, sp
	str	x19, [x29, 24]
	mov	w2, #1
	lsl	x1, x1, x2
	add	x19, x0, x1
	bl	scaled_barrier
	ldrh	w0, [x19]
	ldr	x19, [x29, 24]
	ldp	x29, x30, [sp], 32
	ret
.type uh_w_barrier_call, @function
.size uh_w_barrier_call, .-uh_w_barrier_call
/* end function uh_w_barrier_call */

.text
.balign 16
.globl uh_w_live
uh_w_live:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x2, x1, x2
	add	x0, x0, x2
	ldrh	w0, [x0]
	eor	w0, w1, w0
	ldp	x29, x30, [sp], 16
	ret
.type uh_w_live, @function
.size uh_w_live, .-uh_w_live
/* end function uh_w_live */

.text
.balign 16
.globl uh_w_pressure
uh_w_pressure:
	hint	#34
	stp	x29, x30, [sp, -96]!
	mov	x29, sp
	str	x19, [x29, 88]
	str	x20, [x29, 80]
	str	x21, [x29, 72]
	str	x22, [x29, 64]
	str	x23, [x29, 56]
	str	x24, [x29, 48]
	str	x25, [x29, 40]
	str	x26, [x29, 32]
	str	x27, [x29, 24]
	str	x28, [x29, 16]
	ldr	x8, [x29, 232]
	ldr	x9, [x29, 224]
	ldr	x10, [x29, 216]
	ldr	x11, [x29, 208]
	ldr	x12, [x29, 200]
	ldr	x13, [x29, 192]
	ldr	x14, [x29, 184]
	ldr	x15, [x29, 176]
	ldr	x16, [x29, 168]
	ldr	x19, [x29, 160]
	ldr	x20, [x29, 152]
	ldr	x21, [x29, 144]
	ldr	x22, [x29, 136]
	ldr	x23, [x29, 128]
	ldr	x24, [x29, 120]
	ldr	x25, [x29, 112]
	ldr	x26, [x29, 104]
	ldr	x27, [x29, 96]
	mov	x17, x4
	mov	x4, x3
	mov	x3, x17
	mov	x17, x5
	mov	x5, x2
	mov	x2, x17
	mov	x17, x7
	mov	x7, x0
	mov	x0, x17
	mov	x17, x1
	mov	x1, x7
	mov	x7, x17
	mov	x17, x6
	mov	x6, x1
	mov	x1, x17
	mov	w28, #1
	lsl	x7, x7, x28
	add	x6, x6, x7
	ldrh	w6, [x6]
	add	w5, w5, w6
	add	w4, w4, w5
	add	w3, w3, w4
	add	w2, w2, w3
	add	w1, w1, w2
	add	w0, w0, w1
	add	w0, w27, w0
	add	w0, w26, w0
	add	w0, w25, w0
	add	w0, w24, w0
	add	w0, w23, w0
	add	w0, w22, w0
	add	w0, w21, w0
	add	w0, w20, w0
	add	w0, w19, w0
	add	w0, w16, w0
	add	w0, w15, w0
	add	w0, w14, w0
	add	w0, w13, w0
	add	w0, w12, w0
	add	w0, w11, w0
	add	w0, w10, w0
	add	w0, w9, w0
	add	w0, w8, w0
	ldr	x19, [x29, 88]
	ldr	x20, [x29, 80]
	ldr	x21, [x29, 72]
	ldr	x22, [x29, 64]
	ldr	x23, [x29, 56]
	ldr	x24, [x29, 48]
	ldr	x25, [x29, 40]
	ldr	x26, [x29, 32]
	ldr	x27, [x29, 24]
	ldr	x28, [x29, 16]
	ldp	x29, x30, [sp], 96
	ret
.type uh_w_pressure, @function
.size uh_w_pressure, .-uh_w_pressure
/* end function uh_w_pressure */

.text
.balign 16
.globl uh_w_extension
uh_w_extension:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrh	w0, [x0]
	uxth	w0, w0
	ldp	x29, x30, [sp], 16
	ret
.type uh_w_extension, @function
.size uh_w_extension, .-uh_w_extension
/* end function uh_w_extension */

.text
.balign 16
.globl uh_l_plain
uh_l_plain:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrh	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type uh_l_plain, @function
.size uh_l_plain, .-uh_l_plain
/* end function uh_l_plain */

.text
.balign 16
.globl uh_l_commuted
uh_l_commuted:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrh	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type uh_l_commuted, @function
.size uh_l_commuted, .-uh_l_commuted
/* end function uh_l_commuted */

.text
.balign 16
.globl uh_l_zero
uh_l_zero:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrh	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type uh_l_zero, @function
.size uh_l_zero, .-uh_l_zero
/* end function uh_l_zero */

.text
.balign 16
.globl uh_l_debug_shift
uh_l_debug_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	.loc 1 41 2
	add	x0, x0, x1
	ldrh	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type uh_l_debug_shift, @function
.size uh_l_debug_shift, .-uh_l_debug_shift
/* end function uh_l_debug_shift */

.text
.balign 16
.globl uh_l_debug_add
uh_l_debug_add:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	.loc 1 42 3
	ldrh	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type uh_l_debug_add, @function
.size uh_l_debug_add, .-uh_l_debug_add
/* end function uh_l_debug_add */

.text
.balign 16
.globl uh_l_shared_shift
uh_l_shared_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	x17, x1
	mov	x1, x0
	mov	x0, x17
	mov	w2, #1
	lsl	x0, x0, x2
	add	x1, x1, x0
	ldrh	w1, [x1]
	eor	x0, x0, x1
	ldp	x29, x30, [sp], 16
	ret
.type uh_l_shared_shift, @function
.size uh_l_shared_shift, .-uh_l_shared_shift
/* end function uh_l_shared_shift */

.text
.balign 16
.globl uh_l_shared_address
uh_l_shared_address:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrh	w1, [x0]
	eor	x0, x0, x1
	ldp	x29, x30, [sp], 16
	ret
.type uh_l_shared_address, @function
.size uh_l_shared_address, .-uh_l_shared_address
/* end function uh_l_shared_address */

.text
.balign 16
.globl uh_l_separated
uh_l_separated:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	x17, x1
	mov	x1, x0
	mov	x0, x17
	mov	w2, #1
	lsl	x2, x0, x2
	add	x1, x1, x2
	mov	x2, #991
	eor	x0, x0, x2
	ldrh	w1, [x1]
	eor	x0, x0, x1
	ldp	x29, x30, [sp], 16
	ret
.type uh_l_separated, @function
.size uh_l_separated, .-uh_l_separated
/* end function uh_l_separated */

.text
.balign 16
.globl uh_l_wrong_scale
uh_l_wrong_scale:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrh	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type uh_l_wrong_scale, @function
.size uh_l_wrong_scale, .-uh_l_wrong_scale
/* end function uh_l_wrong_scale */

.text
.balign 16
.globl uh_l_word_shift
uh_l_word_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	w1, w1, w2
	mov	w1, w1
	add	x0, x0, x1
	ldrh	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type uh_l_word_shift, @function
.size uh_l_word_shift, .-uh_l_word_shift
/* end function uh_l_word_shift */

.text
.balign 16
.globl uh_l_barrier_call
uh_l_barrier_call:
	hint	#34
	stp	x29, x30, [sp, -32]!
	mov	x29, sp
	str	x19, [x29, 24]
	mov	w2, #1
	lsl	x1, x1, x2
	add	x19, x0, x1
	bl	scaled_barrier
	ldrh	w0, [x19]
	ldr	x19, [x29, 24]
	ldp	x29, x30, [sp], 32
	ret
.type uh_l_barrier_call, @function
.size uh_l_barrier_call, .-uh_l_barrier_call
/* end function uh_l_barrier_call */

.text
.balign 16
.globl uh_l_live
uh_l_live:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x2, x1, x2
	add	x0, x0, x2
	ldrh	w0, [x0]
	eor	x0, x1, x0
	ldp	x29, x30, [sp], 16
	ret
.type uh_l_live, @function
.size uh_l_live, .-uh_l_live
/* end function uh_l_live */

.text
.balign 16
.globl uh_l_pressure
uh_l_pressure:
	hint	#34
	stp	x29, x30, [sp, -96]!
	mov	x29, sp
	str	x19, [x29, 88]
	str	x20, [x29, 80]
	str	x21, [x29, 72]
	str	x22, [x29, 64]
	str	x23, [x29, 56]
	str	x24, [x29, 48]
	str	x25, [x29, 40]
	str	x26, [x29, 32]
	str	x27, [x29, 24]
	str	x28, [x29, 16]
	ldr	x8, [x29, 232]
	ldr	x9, [x29, 224]
	ldr	x10, [x29, 216]
	ldr	x11, [x29, 208]
	ldr	x12, [x29, 200]
	ldr	x13, [x29, 192]
	ldr	x14, [x29, 184]
	ldr	x15, [x29, 176]
	ldr	x16, [x29, 168]
	ldr	x19, [x29, 160]
	ldr	x20, [x29, 152]
	ldr	x21, [x29, 144]
	ldr	x22, [x29, 136]
	ldr	x23, [x29, 128]
	ldr	x24, [x29, 120]
	ldr	x25, [x29, 112]
	ldr	x26, [x29, 104]
	ldr	x27, [x29, 96]
	mov	x17, x4
	mov	x4, x3
	mov	x3, x17
	mov	x17, x5
	mov	x5, x2
	mov	x2, x17
	mov	x17, x7
	mov	x7, x0
	mov	x0, x17
	mov	x17, x1
	mov	x1, x7
	mov	x7, x17
	mov	x17, x6
	mov	x6, x1
	mov	x1, x17
	mov	w28, #1
	lsl	x7, x7, x28
	add	x6, x6, x7
	ldrh	w6, [x6]
	add	x5, x5, x6
	add	x4, x4, x5
	add	x3, x3, x4
	add	x2, x2, x3
	add	x1, x1, x2
	add	x0, x0, x1
	add	x0, x27, x0
	add	x0, x26, x0
	add	x0, x25, x0
	add	x0, x24, x0
	add	x0, x23, x0
	add	x0, x22, x0
	add	x0, x21, x0
	add	x0, x20, x0
	add	x0, x19, x0
	add	x0, x16, x0
	add	x0, x15, x0
	add	x0, x14, x0
	add	x0, x13, x0
	add	x0, x12, x0
	add	x0, x11, x0
	add	x0, x10, x0
	add	x0, x9, x0
	add	x0, x8, x0
	ldr	x19, [x29, 88]
	ldr	x20, [x29, 80]
	ldr	x21, [x29, 72]
	ldr	x22, [x29, 64]
	ldr	x23, [x29, 56]
	ldr	x24, [x29, 48]
	ldr	x25, [x29, 40]
	ldr	x26, [x29, 32]
	ldr	x27, [x29, 24]
	ldr	x28, [x29, 16]
	ldp	x29, x30, [sp], 96
	ret
.type uh_l_pressure, @function
.size uh_l_pressure, .-uh_l_pressure
/* end function uh_l_pressure */

.text
.balign 16
.globl uh_l_extension
uh_l_extension:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrh	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type uh_l_extension, @function
.size uh_l_extension, .-uh_l_extension
/* end function uh_l_extension */

.text
.balign 16
.globl sh_w_plain
sh_w_plain:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrsh	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type sh_w_plain, @function
.size sh_w_plain, .-sh_w_plain
/* end function sh_w_plain */

.text
.balign 16
.globl sh_w_commuted
sh_w_commuted:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrsh	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type sh_w_commuted, @function
.size sh_w_commuted, .-sh_w_commuted
/* end function sh_w_commuted */

.text
.balign 16
.globl sh_w_zero
sh_w_zero:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrsh	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type sh_w_zero, @function
.size sh_w_zero, .-sh_w_zero
/* end function sh_w_zero */

.text
.balign 16
.globl sh_w_debug_shift
sh_w_debug_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	.loc 1 41 2
	add	x0, x0, x1
	ldrsh	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type sh_w_debug_shift, @function
.size sh_w_debug_shift, .-sh_w_debug_shift
/* end function sh_w_debug_shift */

.text
.balign 16
.globl sh_w_debug_add
sh_w_debug_add:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	.loc 1 42 3
	ldrsh	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type sh_w_debug_add, @function
.size sh_w_debug_add, .-sh_w_debug_add
/* end function sh_w_debug_add */

.text
.balign 16
.globl sh_w_shared_shift
sh_w_shared_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	x17, x1
	mov	x1, x0
	mov	x0, x17
	mov	w2, #1
	lsl	x0, x0, x2
	add	x1, x1, x0
	ldrsh	w1, [x1]
	eor	w0, w0, w1
	ldp	x29, x30, [sp], 16
	ret
.type sh_w_shared_shift, @function
.size sh_w_shared_shift, .-sh_w_shared_shift
/* end function sh_w_shared_shift */

.text
.balign 16
.globl sh_w_shared_address
sh_w_shared_address:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrsh	w1, [x0]
	eor	w0, w0, w1
	ldp	x29, x30, [sp], 16
	ret
.type sh_w_shared_address, @function
.size sh_w_shared_address, .-sh_w_shared_address
/* end function sh_w_shared_address */

.text
.balign 16
.globl sh_w_separated
sh_w_separated:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	x17, x1
	mov	x1, x0
	mov	x0, x17
	mov	w2, #1
	lsl	x2, x0, x2
	add	x1, x1, x2
	mov	x2, #991
	eor	x0, x0, x2
	ldrsh	w1, [x1]
	eor	w0, w0, w1
	ldp	x29, x30, [sp], 16
	ret
.type sh_w_separated, @function
.size sh_w_separated, .-sh_w_separated
/* end function sh_w_separated */

.text
.balign 16
.globl sh_w_wrong_scale
sh_w_wrong_scale:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrsh	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type sh_w_wrong_scale, @function
.size sh_w_wrong_scale, .-sh_w_wrong_scale
/* end function sh_w_wrong_scale */

.text
.balign 16
.globl sh_w_word_shift
sh_w_word_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	w1, w1, w2
	mov	w1, w1
	add	x0, x0, x1
	ldrsh	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type sh_w_word_shift, @function
.size sh_w_word_shift, .-sh_w_word_shift
/* end function sh_w_word_shift */

.text
.balign 16
.globl sh_w_barrier_call
sh_w_barrier_call:
	hint	#34
	stp	x29, x30, [sp, -32]!
	mov	x29, sp
	str	x19, [x29, 24]
	mov	w2, #1
	lsl	x1, x1, x2
	add	x19, x0, x1
	bl	scaled_barrier
	ldrsh	w0, [x19]
	ldr	x19, [x29, 24]
	ldp	x29, x30, [sp], 32
	ret
.type sh_w_barrier_call, @function
.size sh_w_barrier_call, .-sh_w_barrier_call
/* end function sh_w_barrier_call */

.text
.balign 16
.globl sh_w_live
sh_w_live:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x2, x1, x2
	add	x0, x0, x2
	ldrsh	w0, [x0]
	eor	w0, w1, w0
	ldp	x29, x30, [sp], 16
	ret
.type sh_w_live, @function
.size sh_w_live, .-sh_w_live
/* end function sh_w_live */

.text
.balign 16
.globl sh_w_pressure
sh_w_pressure:
	hint	#34
	stp	x29, x30, [sp, -96]!
	mov	x29, sp
	str	x19, [x29, 88]
	str	x20, [x29, 80]
	str	x21, [x29, 72]
	str	x22, [x29, 64]
	str	x23, [x29, 56]
	str	x24, [x29, 48]
	str	x25, [x29, 40]
	str	x26, [x29, 32]
	str	x27, [x29, 24]
	str	x28, [x29, 16]
	ldr	x8, [x29, 232]
	ldr	x9, [x29, 224]
	ldr	x10, [x29, 216]
	ldr	x11, [x29, 208]
	ldr	x12, [x29, 200]
	ldr	x13, [x29, 192]
	ldr	x14, [x29, 184]
	ldr	x15, [x29, 176]
	ldr	x16, [x29, 168]
	ldr	x19, [x29, 160]
	ldr	x20, [x29, 152]
	ldr	x21, [x29, 144]
	ldr	x22, [x29, 136]
	ldr	x23, [x29, 128]
	ldr	x24, [x29, 120]
	ldr	x25, [x29, 112]
	ldr	x26, [x29, 104]
	ldr	x27, [x29, 96]
	mov	x17, x4
	mov	x4, x3
	mov	x3, x17
	mov	x17, x5
	mov	x5, x2
	mov	x2, x17
	mov	x17, x7
	mov	x7, x0
	mov	x0, x17
	mov	x17, x1
	mov	x1, x7
	mov	x7, x17
	mov	x17, x6
	mov	x6, x1
	mov	x1, x17
	mov	w28, #1
	lsl	x7, x7, x28
	add	x6, x6, x7
	ldrsh	w6, [x6]
	add	w5, w5, w6
	add	w4, w4, w5
	add	w3, w3, w4
	add	w2, w2, w3
	add	w1, w1, w2
	add	w0, w0, w1
	add	w0, w27, w0
	add	w0, w26, w0
	add	w0, w25, w0
	add	w0, w24, w0
	add	w0, w23, w0
	add	w0, w22, w0
	add	w0, w21, w0
	add	w0, w20, w0
	add	w0, w19, w0
	add	w0, w16, w0
	add	w0, w15, w0
	add	w0, w14, w0
	add	w0, w13, w0
	add	w0, w12, w0
	add	w0, w11, w0
	add	w0, w10, w0
	add	w0, w9, w0
	add	w0, w8, w0
	ldr	x19, [x29, 88]
	ldr	x20, [x29, 80]
	ldr	x21, [x29, 72]
	ldr	x22, [x29, 64]
	ldr	x23, [x29, 56]
	ldr	x24, [x29, 48]
	ldr	x25, [x29, 40]
	ldr	x26, [x29, 32]
	ldr	x27, [x29, 24]
	ldr	x28, [x29, 16]
	ldp	x29, x30, [sp], 96
	ret
.type sh_w_pressure, @function
.size sh_w_pressure, .-sh_w_pressure
/* end function sh_w_pressure */

.text
.balign 16
.globl sh_l_plain
sh_l_plain:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrsh	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type sh_l_plain, @function
.size sh_l_plain, .-sh_l_plain
/* end function sh_l_plain */

.text
.balign 16
.globl sh_l_commuted
sh_l_commuted:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrsh	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type sh_l_commuted, @function
.size sh_l_commuted, .-sh_l_commuted
/* end function sh_l_commuted */

.text
.balign 16
.globl sh_l_zero
sh_l_zero:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrsh	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type sh_l_zero, @function
.size sh_l_zero, .-sh_l_zero
/* end function sh_l_zero */

.text
.balign 16
.globl sh_l_debug_shift
sh_l_debug_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	.loc 1 41 2
	add	x0, x0, x1
	ldrsh	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type sh_l_debug_shift, @function
.size sh_l_debug_shift, .-sh_l_debug_shift
/* end function sh_l_debug_shift */

.text
.balign 16
.globl sh_l_debug_add
sh_l_debug_add:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	.loc 1 42 3
	ldrsh	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type sh_l_debug_add, @function
.size sh_l_debug_add, .-sh_l_debug_add
/* end function sh_l_debug_add */

.text
.balign 16
.globl sh_l_shared_shift
sh_l_shared_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	x17, x1
	mov	x1, x0
	mov	x0, x17
	mov	w2, #1
	lsl	x0, x0, x2
	add	x1, x1, x0
	ldrsh	x1, [x1]
	eor	x0, x0, x1
	ldp	x29, x30, [sp], 16
	ret
.type sh_l_shared_shift, @function
.size sh_l_shared_shift, .-sh_l_shared_shift
/* end function sh_l_shared_shift */

.text
.balign 16
.globl sh_l_shared_address
sh_l_shared_address:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrsh	x1, [x0]
	eor	x0, x0, x1
	ldp	x29, x30, [sp], 16
	ret
.type sh_l_shared_address, @function
.size sh_l_shared_address, .-sh_l_shared_address
/* end function sh_l_shared_address */

.text
.balign 16
.globl sh_l_separated
sh_l_separated:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	x17, x1
	mov	x1, x0
	mov	x0, x17
	mov	w2, #1
	lsl	x2, x0, x2
	add	x1, x1, x2
	mov	x2, #991
	eor	x0, x0, x2
	ldrsh	x1, [x1]
	eor	x0, x0, x1
	ldp	x29, x30, [sp], 16
	ret
.type sh_l_separated, @function
.size sh_l_separated, .-sh_l_separated
/* end function sh_l_separated */

.text
.balign 16
.globl sh_l_wrong_scale
sh_l_wrong_scale:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrsh	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type sh_l_wrong_scale, @function
.size sh_l_wrong_scale, .-sh_l_wrong_scale
/* end function sh_l_wrong_scale */

.text
.balign 16
.globl sh_l_word_shift
sh_l_word_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	w1, w1, w2
	mov	w1, w1
	add	x0, x0, x1
	ldrsh	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type sh_l_word_shift, @function
.size sh_l_word_shift, .-sh_l_word_shift
/* end function sh_l_word_shift */

.text
.balign 16
.globl sh_l_barrier_call
sh_l_barrier_call:
	hint	#34
	stp	x29, x30, [sp, -32]!
	mov	x29, sp
	str	x19, [x29, 24]
	mov	w2, #1
	lsl	x1, x1, x2
	add	x19, x0, x1
	bl	scaled_barrier
	ldrsh	x0, [x19]
	ldr	x19, [x29, 24]
	ldp	x29, x30, [sp], 32
	ret
.type sh_l_barrier_call, @function
.size sh_l_barrier_call, .-sh_l_barrier_call
/* end function sh_l_barrier_call */

.text
.balign 16
.globl sh_l_live
sh_l_live:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x2, x1, x2
	add	x0, x0, x2
	ldrsh	x0, [x0]
	eor	x0, x1, x0
	ldp	x29, x30, [sp], 16
	ret
.type sh_l_live, @function
.size sh_l_live, .-sh_l_live
/* end function sh_l_live */

.text
.balign 16
.globl sh_l_pressure
sh_l_pressure:
	hint	#34
	stp	x29, x30, [sp, -96]!
	mov	x29, sp
	str	x19, [x29, 88]
	str	x20, [x29, 80]
	str	x21, [x29, 72]
	str	x22, [x29, 64]
	str	x23, [x29, 56]
	str	x24, [x29, 48]
	str	x25, [x29, 40]
	str	x26, [x29, 32]
	str	x27, [x29, 24]
	str	x28, [x29, 16]
	ldr	x8, [x29, 232]
	ldr	x9, [x29, 224]
	ldr	x10, [x29, 216]
	ldr	x11, [x29, 208]
	ldr	x12, [x29, 200]
	ldr	x13, [x29, 192]
	ldr	x14, [x29, 184]
	ldr	x15, [x29, 176]
	ldr	x16, [x29, 168]
	ldr	x19, [x29, 160]
	ldr	x20, [x29, 152]
	ldr	x21, [x29, 144]
	ldr	x22, [x29, 136]
	ldr	x23, [x29, 128]
	ldr	x24, [x29, 120]
	ldr	x25, [x29, 112]
	ldr	x26, [x29, 104]
	ldr	x27, [x29, 96]
	mov	x17, x4
	mov	x4, x3
	mov	x3, x17
	mov	x17, x5
	mov	x5, x2
	mov	x2, x17
	mov	x17, x7
	mov	x7, x0
	mov	x0, x17
	mov	x17, x1
	mov	x1, x7
	mov	x7, x17
	mov	x17, x6
	mov	x6, x1
	mov	x1, x17
	mov	w28, #1
	lsl	x7, x7, x28
	add	x6, x6, x7
	ldrsh	x6, [x6]
	add	x5, x5, x6
	add	x4, x4, x5
	add	x3, x3, x4
	add	x2, x2, x3
	add	x1, x1, x2
	add	x0, x0, x1
	add	x0, x27, x0
	add	x0, x26, x0
	add	x0, x25, x0
	add	x0, x24, x0
	add	x0, x23, x0
	add	x0, x22, x0
	add	x0, x21, x0
	add	x0, x20, x0
	add	x0, x19, x0
	add	x0, x16, x0
	add	x0, x15, x0
	add	x0, x14, x0
	add	x0, x13, x0
	add	x0, x12, x0
	add	x0, x11, x0
	add	x0, x10, x0
	add	x0, x9, x0
	add	x0, x8, x0
	ldr	x19, [x29, 88]
	ldr	x20, [x29, 80]
	ldr	x21, [x29, 72]
	ldr	x22, [x29, 64]
	ldr	x23, [x29, 56]
	ldr	x24, [x29, 48]
	ldr	x25, [x29, 40]
	ldr	x26, [x29, 32]
	ldr	x27, [x29, 24]
	ldr	x28, [x29, 16]
	ldp	x29, x30, [sp], 96
	ret
.type sh_l_pressure, @function
.size sh_l_pressure, .-sh_l_pressure
/* end function sh_l_pressure */

.text
.balign 16
.globl uw_w_plain
uw_w_plain:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldr	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type uw_w_plain, @function
.size uw_w_plain, .-uw_w_plain
/* end function uw_w_plain */

.text
.balign 16
.globl uw_w_commuted
uw_w_commuted:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldr	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type uw_w_commuted, @function
.size uw_w_commuted, .-uw_w_commuted
/* end function uw_w_commuted */

.text
.balign 16
.globl uw_w_zero
uw_w_zero:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldr	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type uw_w_zero, @function
.size uw_w_zero, .-uw_w_zero
/* end function uw_w_zero */

.text
.balign 16
.globl uw_w_debug_shift
uw_w_debug_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	.loc 1 41 2
	add	x0, x0, x1
	ldr	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type uw_w_debug_shift, @function
.size uw_w_debug_shift, .-uw_w_debug_shift
/* end function uw_w_debug_shift */

.text
.balign 16
.globl uw_w_debug_add
uw_w_debug_add:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	add	x0, x0, x1
	.loc 1 42 3
	ldr	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type uw_w_debug_add, @function
.size uw_w_debug_add, .-uw_w_debug_add
/* end function uw_w_debug_add */

.text
.balign 16
.globl uw_w_shared_shift
uw_w_shared_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	x17, x1
	mov	x1, x0
	mov	x0, x17
	mov	w2, #2
	lsl	x0, x0, x2
	add	x1, x1, x0
	ldr	w1, [x1]
	eor	w0, w0, w1
	ldp	x29, x30, [sp], 16
	ret
.type uw_w_shared_shift, @function
.size uw_w_shared_shift, .-uw_w_shared_shift
/* end function uw_w_shared_shift */

.text
.balign 16
.globl uw_w_shared_address
uw_w_shared_address:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldr	w1, [x0]
	eor	w0, w0, w1
	ldp	x29, x30, [sp], 16
	ret
.type uw_w_shared_address, @function
.size uw_w_shared_address, .-uw_w_shared_address
/* end function uw_w_shared_address */

.text
.balign 16
.globl uw_w_separated
uw_w_separated:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	x17, x1
	mov	x1, x0
	mov	x0, x17
	mov	w2, #2
	lsl	x2, x0, x2
	add	x1, x1, x2
	mov	x2, #991
	eor	x0, x0, x2
	ldr	w1, [x1]
	eor	w0, w0, w1
	ldp	x29, x30, [sp], 16
	ret
.type uw_w_separated, @function
.size uw_w_separated, .-uw_w_separated
/* end function uw_w_separated */

.text
.balign 16
.globl uw_w_wrong_scale
uw_w_wrong_scale:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldr	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type uw_w_wrong_scale, @function
.size uw_w_wrong_scale, .-uw_w_wrong_scale
/* end function uw_w_wrong_scale */

.text
.balign 16
.globl uw_w_word_shift
uw_w_word_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	w1, w1, w2
	mov	w1, w1
	add	x0, x0, x1
	ldr	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type uw_w_word_shift, @function
.size uw_w_word_shift, .-uw_w_word_shift
/* end function uw_w_word_shift */

.text
.balign 16
.globl uw_w_barrier_call
uw_w_barrier_call:
	hint	#34
	stp	x29, x30, [sp, -32]!
	mov	x29, sp
	str	x19, [x29, 24]
	mov	w2, #2
	lsl	x1, x1, x2
	add	x19, x0, x1
	bl	scaled_barrier
	ldr	w0, [x19]
	ldr	x19, [x29, 24]
	ldp	x29, x30, [sp], 32
	ret
.type uw_w_barrier_call, @function
.size uw_w_barrier_call, .-uw_w_barrier_call
/* end function uw_w_barrier_call */

.text
.balign 16
.globl uw_w_live
uw_w_live:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x2, x1, x2
	add	x0, x0, x2
	ldr	w0, [x0]
	eor	w0, w1, w0
	ldp	x29, x30, [sp], 16
	ret
.type uw_w_live, @function
.size uw_w_live, .-uw_w_live
/* end function uw_w_live */

.text
.balign 16
.globl uw_w_pressure
uw_w_pressure:
	hint	#34
	stp	x29, x30, [sp, -96]!
	mov	x29, sp
	str	x19, [x29, 88]
	str	x20, [x29, 80]
	str	x21, [x29, 72]
	str	x22, [x29, 64]
	str	x23, [x29, 56]
	str	x24, [x29, 48]
	str	x25, [x29, 40]
	str	x26, [x29, 32]
	str	x27, [x29, 24]
	str	x28, [x29, 16]
	ldr	x8, [x29, 232]
	ldr	x9, [x29, 224]
	ldr	x10, [x29, 216]
	ldr	x11, [x29, 208]
	ldr	x12, [x29, 200]
	ldr	x13, [x29, 192]
	ldr	x14, [x29, 184]
	ldr	x15, [x29, 176]
	ldr	x16, [x29, 168]
	ldr	x19, [x29, 160]
	ldr	x20, [x29, 152]
	ldr	x21, [x29, 144]
	ldr	x22, [x29, 136]
	ldr	x23, [x29, 128]
	ldr	x24, [x29, 120]
	ldr	x25, [x29, 112]
	ldr	x26, [x29, 104]
	ldr	x27, [x29, 96]
	mov	x17, x4
	mov	x4, x3
	mov	x3, x17
	mov	x17, x5
	mov	x5, x2
	mov	x2, x17
	mov	x17, x7
	mov	x7, x0
	mov	x0, x17
	mov	x17, x1
	mov	x1, x7
	mov	x7, x17
	mov	x17, x6
	mov	x6, x1
	mov	x1, x17
	mov	w28, #2
	lsl	x7, x7, x28
	add	x6, x6, x7
	ldr	w6, [x6]
	add	w5, w5, w6
	add	w4, w4, w5
	add	w3, w3, w4
	add	w2, w2, w3
	add	w1, w1, w2
	add	w0, w0, w1
	add	w0, w27, w0
	add	w0, w26, w0
	add	w0, w25, w0
	add	w0, w24, w0
	add	w0, w23, w0
	add	w0, w22, w0
	add	w0, w21, w0
	add	w0, w20, w0
	add	w0, w19, w0
	add	w0, w16, w0
	add	w0, w15, w0
	add	w0, w14, w0
	add	w0, w13, w0
	add	w0, w12, w0
	add	w0, w11, w0
	add	w0, w10, w0
	add	w0, w9, w0
	add	w0, w8, w0
	ldr	x19, [x29, 88]
	ldr	x20, [x29, 80]
	ldr	x21, [x29, 72]
	ldr	x22, [x29, 64]
	ldr	x23, [x29, 56]
	ldr	x24, [x29, 48]
	ldr	x25, [x29, 40]
	ldr	x26, [x29, 32]
	ldr	x27, [x29, 24]
	ldr	x28, [x29, 16]
	ldp	x29, x30, [sp], 96
	ret
.type uw_w_pressure, @function
.size uw_w_pressure, .-uw_w_pressure
/* end function uw_w_pressure */

.text
.balign 16
.globl uw_w_extension
uw_w_extension:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldr	w0, [x0]
	mov	w0, w0
	ldp	x29, x30, [sp], 16
	ret
.type uw_w_extension, @function
.size uw_w_extension, .-uw_w_extension
/* end function uw_w_extension */

.text
.balign 16
.globl uw_l_plain
uw_l_plain:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldr	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type uw_l_plain, @function
.size uw_l_plain, .-uw_l_plain
/* end function uw_l_plain */

.text
.balign 16
.globl uw_l_commuted
uw_l_commuted:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldr	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type uw_l_commuted, @function
.size uw_l_commuted, .-uw_l_commuted
/* end function uw_l_commuted */

.text
.balign 16
.globl uw_l_zero
uw_l_zero:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldr	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type uw_l_zero, @function
.size uw_l_zero, .-uw_l_zero
/* end function uw_l_zero */

.text
.balign 16
.globl uw_l_debug_shift
uw_l_debug_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	.loc 1 41 2
	add	x0, x0, x1
	ldr	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type uw_l_debug_shift, @function
.size uw_l_debug_shift, .-uw_l_debug_shift
/* end function uw_l_debug_shift */

.text
.balign 16
.globl uw_l_debug_add
uw_l_debug_add:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	add	x0, x0, x1
	.loc 1 42 3
	ldr	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type uw_l_debug_add, @function
.size uw_l_debug_add, .-uw_l_debug_add
/* end function uw_l_debug_add */

.text
.balign 16
.globl uw_l_shared_shift
uw_l_shared_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	x17, x1
	mov	x1, x0
	mov	x0, x17
	mov	w2, #2
	lsl	x0, x0, x2
	add	x1, x1, x0
	ldr	w1, [x1]
	eor	x0, x0, x1
	ldp	x29, x30, [sp], 16
	ret
.type uw_l_shared_shift, @function
.size uw_l_shared_shift, .-uw_l_shared_shift
/* end function uw_l_shared_shift */

.text
.balign 16
.globl uw_l_shared_address
uw_l_shared_address:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldr	w1, [x0]
	eor	x0, x0, x1
	ldp	x29, x30, [sp], 16
	ret
.type uw_l_shared_address, @function
.size uw_l_shared_address, .-uw_l_shared_address
/* end function uw_l_shared_address */

.text
.balign 16
.globl uw_l_separated
uw_l_separated:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	x17, x1
	mov	x1, x0
	mov	x0, x17
	mov	w2, #2
	lsl	x2, x0, x2
	add	x1, x1, x2
	mov	x2, #991
	eor	x0, x0, x2
	ldr	w1, [x1]
	eor	x0, x0, x1
	ldp	x29, x30, [sp], 16
	ret
.type uw_l_separated, @function
.size uw_l_separated, .-uw_l_separated
/* end function uw_l_separated */

.text
.balign 16
.globl uw_l_wrong_scale
uw_l_wrong_scale:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldr	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type uw_l_wrong_scale, @function
.size uw_l_wrong_scale, .-uw_l_wrong_scale
/* end function uw_l_wrong_scale */

.text
.balign 16
.globl uw_l_word_shift
uw_l_word_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	w1, w1, w2
	mov	w1, w1
	add	x0, x0, x1
	ldr	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type uw_l_word_shift, @function
.size uw_l_word_shift, .-uw_l_word_shift
/* end function uw_l_word_shift */

.text
.balign 16
.globl uw_l_barrier_call
uw_l_barrier_call:
	hint	#34
	stp	x29, x30, [sp, -32]!
	mov	x29, sp
	str	x19, [x29, 24]
	mov	w2, #2
	lsl	x1, x1, x2
	add	x19, x0, x1
	bl	scaled_barrier
	ldr	w0, [x19]
	ldr	x19, [x29, 24]
	ldp	x29, x30, [sp], 32
	ret
.type uw_l_barrier_call, @function
.size uw_l_barrier_call, .-uw_l_barrier_call
/* end function uw_l_barrier_call */

.text
.balign 16
.globl uw_l_live
uw_l_live:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x2, x1, x2
	add	x0, x0, x2
	ldr	w0, [x0]
	eor	x0, x1, x0
	ldp	x29, x30, [sp], 16
	ret
.type uw_l_live, @function
.size uw_l_live, .-uw_l_live
/* end function uw_l_live */

.text
.balign 16
.globl uw_l_pressure
uw_l_pressure:
	hint	#34
	stp	x29, x30, [sp, -96]!
	mov	x29, sp
	str	x19, [x29, 88]
	str	x20, [x29, 80]
	str	x21, [x29, 72]
	str	x22, [x29, 64]
	str	x23, [x29, 56]
	str	x24, [x29, 48]
	str	x25, [x29, 40]
	str	x26, [x29, 32]
	str	x27, [x29, 24]
	str	x28, [x29, 16]
	ldr	x8, [x29, 232]
	ldr	x9, [x29, 224]
	ldr	x10, [x29, 216]
	ldr	x11, [x29, 208]
	ldr	x12, [x29, 200]
	ldr	x13, [x29, 192]
	ldr	x14, [x29, 184]
	ldr	x15, [x29, 176]
	ldr	x16, [x29, 168]
	ldr	x19, [x29, 160]
	ldr	x20, [x29, 152]
	ldr	x21, [x29, 144]
	ldr	x22, [x29, 136]
	ldr	x23, [x29, 128]
	ldr	x24, [x29, 120]
	ldr	x25, [x29, 112]
	ldr	x26, [x29, 104]
	ldr	x27, [x29, 96]
	mov	x17, x4
	mov	x4, x3
	mov	x3, x17
	mov	x17, x5
	mov	x5, x2
	mov	x2, x17
	mov	x17, x7
	mov	x7, x0
	mov	x0, x17
	mov	x17, x1
	mov	x1, x7
	mov	x7, x17
	mov	x17, x6
	mov	x6, x1
	mov	x1, x17
	mov	w28, #2
	lsl	x7, x7, x28
	add	x6, x6, x7
	ldr	w6, [x6]
	add	x5, x5, x6
	add	x4, x4, x5
	add	x3, x3, x4
	add	x2, x2, x3
	add	x1, x1, x2
	add	x0, x0, x1
	add	x0, x27, x0
	add	x0, x26, x0
	add	x0, x25, x0
	add	x0, x24, x0
	add	x0, x23, x0
	add	x0, x22, x0
	add	x0, x21, x0
	add	x0, x20, x0
	add	x0, x19, x0
	add	x0, x16, x0
	add	x0, x15, x0
	add	x0, x14, x0
	add	x0, x13, x0
	add	x0, x12, x0
	add	x0, x11, x0
	add	x0, x10, x0
	add	x0, x9, x0
	add	x0, x8, x0
	ldr	x19, [x29, 88]
	ldr	x20, [x29, 80]
	ldr	x21, [x29, 72]
	ldr	x22, [x29, 64]
	ldr	x23, [x29, 56]
	ldr	x24, [x29, 48]
	ldr	x25, [x29, 40]
	ldr	x26, [x29, 32]
	ldr	x27, [x29, 24]
	ldr	x28, [x29, 16]
	ldp	x29, x30, [sp], 96
	ret
.type uw_l_pressure, @function
.size uw_l_pressure, .-uw_l_pressure
/* end function uw_l_pressure */

.text
.balign 16
.globl uw_l_extension
uw_l_extension:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldr	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type uw_l_extension, @function
.size uw_l_extension, .-uw_l_extension
/* end function uw_l_extension */

.text
.balign 16
.globl sw_w_plain
sw_w_plain:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldr	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type sw_w_plain, @function
.size sw_w_plain, .-sw_w_plain
/* end function sw_w_plain */

.text
.balign 16
.globl sw_w_commuted
sw_w_commuted:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldr	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type sw_w_commuted, @function
.size sw_w_commuted, .-sw_w_commuted
/* end function sw_w_commuted */

.text
.balign 16
.globl sw_w_zero
sw_w_zero:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldr	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type sw_w_zero, @function
.size sw_w_zero, .-sw_w_zero
/* end function sw_w_zero */

.text
.balign 16
.globl sw_w_debug_shift
sw_w_debug_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	.loc 1 41 2
	add	x0, x0, x1
	ldr	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type sw_w_debug_shift, @function
.size sw_w_debug_shift, .-sw_w_debug_shift
/* end function sw_w_debug_shift */

.text
.balign 16
.globl sw_w_debug_add
sw_w_debug_add:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	add	x0, x0, x1
	.loc 1 42 3
	ldr	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type sw_w_debug_add, @function
.size sw_w_debug_add, .-sw_w_debug_add
/* end function sw_w_debug_add */

.text
.balign 16
.globl sw_w_shared_shift
sw_w_shared_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	x17, x1
	mov	x1, x0
	mov	x0, x17
	mov	w2, #2
	lsl	x0, x0, x2
	add	x1, x1, x0
	ldr	w1, [x1]
	eor	w0, w0, w1
	ldp	x29, x30, [sp], 16
	ret
.type sw_w_shared_shift, @function
.size sw_w_shared_shift, .-sw_w_shared_shift
/* end function sw_w_shared_shift */

.text
.balign 16
.globl sw_w_shared_address
sw_w_shared_address:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldr	w1, [x0]
	eor	w0, w0, w1
	ldp	x29, x30, [sp], 16
	ret
.type sw_w_shared_address, @function
.size sw_w_shared_address, .-sw_w_shared_address
/* end function sw_w_shared_address */

.text
.balign 16
.globl sw_w_separated
sw_w_separated:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	x17, x1
	mov	x1, x0
	mov	x0, x17
	mov	w2, #2
	lsl	x2, x0, x2
	add	x1, x1, x2
	mov	x2, #991
	eor	x0, x0, x2
	ldr	w1, [x1]
	eor	w0, w0, w1
	ldp	x29, x30, [sp], 16
	ret
.type sw_w_separated, @function
.size sw_w_separated, .-sw_w_separated
/* end function sw_w_separated */

.text
.balign 16
.globl sw_w_wrong_scale
sw_w_wrong_scale:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldr	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type sw_w_wrong_scale, @function
.size sw_w_wrong_scale, .-sw_w_wrong_scale
/* end function sw_w_wrong_scale */

.text
.balign 16
.globl sw_w_word_shift
sw_w_word_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	w1, w1, w2
	mov	w1, w1
	add	x0, x0, x1
	ldr	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type sw_w_word_shift, @function
.size sw_w_word_shift, .-sw_w_word_shift
/* end function sw_w_word_shift */

.text
.balign 16
.globl sw_w_barrier_call
sw_w_barrier_call:
	hint	#34
	stp	x29, x30, [sp, -32]!
	mov	x29, sp
	str	x19, [x29, 24]
	mov	w2, #2
	lsl	x1, x1, x2
	add	x19, x0, x1
	bl	scaled_barrier
	ldr	w0, [x19]
	ldr	x19, [x29, 24]
	ldp	x29, x30, [sp], 32
	ret
.type sw_w_barrier_call, @function
.size sw_w_barrier_call, .-sw_w_barrier_call
/* end function sw_w_barrier_call */

.text
.balign 16
.globl sw_w_live
sw_w_live:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x2, x1, x2
	add	x0, x0, x2
	ldr	w0, [x0]
	eor	w0, w1, w0
	ldp	x29, x30, [sp], 16
	ret
.type sw_w_live, @function
.size sw_w_live, .-sw_w_live
/* end function sw_w_live */

.text
.balign 16
.globl sw_w_pressure
sw_w_pressure:
	hint	#34
	stp	x29, x30, [sp, -96]!
	mov	x29, sp
	str	x19, [x29, 88]
	str	x20, [x29, 80]
	str	x21, [x29, 72]
	str	x22, [x29, 64]
	str	x23, [x29, 56]
	str	x24, [x29, 48]
	str	x25, [x29, 40]
	str	x26, [x29, 32]
	str	x27, [x29, 24]
	str	x28, [x29, 16]
	ldr	x8, [x29, 232]
	ldr	x9, [x29, 224]
	ldr	x10, [x29, 216]
	ldr	x11, [x29, 208]
	ldr	x12, [x29, 200]
	ldr	x13, [x29, 192]
	ldr	x14, [x29, 184]
	ldr	x15, [x29, 176]
	ldr	x16, [x29, 168]
	ldr	x19, [x29, 160]
	ldr	x20, [x29, 152]
	ldr	x21, [x29, 144]
	ldr	x22, [x29, 136]
	ldr	x23, [x29, 128]
	ldr	x24, [x29, 120]
	ldr	x25, [x29, 112]
	ldr	x26, [x29, 104]
	ldr	x27, [x29, 96]
	mov	x17, x4
	mov	x4, x3
	mov	x3, x17
	mov	x17, x5
	mov	x5, x2
	mov	x2, x17
	mov	x17, x7
	mov	x7, x0
	mov	x0, x17
	mov	x17, x1
	mov	x1, x7
	mov	x7, x17
	mov	x17, x6
	mov	x6, x1
	mov	x1, x17
	mov	w28, #2
	lsl	x7, x7, x28
	add	x6, x6, x7
	ldr	w6, [x6]
	add	w5, w5, w6
	add	w4, w4, w5
	add	w3, w3, w4
	add	w2, w2, w3
	add	w1, w1, w2
	add	w0, w0, w1
	add	w0, w27, w0
	add	w0, w26, w0
	add	w0, w25, w0
	add	w0, w24, w0
	add	w0, w23, w0
	add	w0, w22, w0
	add	w0, w21, w0
	add	w0, w20, w0
	add	w0, w19, w0
	add	w0, w16, w0
	add	w0, w15, w0
	add	w0, w14, w0
	add	w0, w13, w0
	add	w0, w12, w0
	add	w0, w11, w0
	add	w0, w10, w0
	add	w0, w9, w0
	add	w0, w8, w0
	ldr	x19, [x29, 88]
	ldr	x20, [x29, 80]
	ldr	x21, [x29, 72]
	ldr	x22, [x29, 64]
	ldr	x23, [x29, 56]
	ldr	x24, [x29, 48]
	ldr	x25, [x29, 40]
	ldr	x26, [x29, 32]
	ldr	x27, [x29, 24]
	ldr	x28, [x29, 16]
	ldp	x29, x30, [sp], 96
	ret
.type sw_w_pressure, @function
.size sw_w_pressure, .-sw_w_pressure
/* end function sw_w_pressure */

.text
.balign 16
.globl sw_l_plain
sw_l_plain:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrsw	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type sw_l_plain, @function
.size sw_l_plain, .-sw_l_plain
/* end function sw_l_plain */

.text
.balign 16
.globl sw_l_commuted
sw_l_commuted:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrsw	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type sw_l_commuted, @function
.size sw_l_commuted, .-sw_l_commuted
/* end function sw_l_commuted */

.text
.balign 16
.globl sw_l_zero
sw_l_zero:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrsw	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type sw_l_zero, @function
.size sw_l_zero, .-sw_l_zero
/* end function sw_l_zero */

.text
.balign 16
.globl sw_l_debug_shift
sw_l_debug_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	.loc 1 41 2
	add	x0, x0, x1
	ldrsw	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type sw_l_debug_shift, @function
.size sw_l_debug_shift, .-sw_l_debug_shift
/* end function sw_l_debug_shift */

.text
.balign 16
.globl sw_l_debug_add
sw_l_debug_add:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	add	x0, x0, x1
	.loc 1 42 3
	ldrsw	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type sw_l_debug_add, @function
.size sw_l_debug_add, .-sw_l_debug_add
/* end function sw_l_debug_add */

.text
.balign 16
.globl sw_l_shared_shift
sw_l_shared_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	x17, x1
	mov	x1, x0
	mov	x0, x17
	mov	w2, #2
	lsl	x0, x0, x2
	add	x1, x1, x0
	ldrsw	x1, [x1]
	eor	x0, x0, x1
	ldp	x29, x30, [sp], 16
	ret
.type sw_l_shared_shift, @function
.size sw_l_shared_shift, .-sw_l_shared_shift
/* end function sw_l_shared_shift */

.text
.balign 16
.globl sw_l_shared_address
sw_l_shared_address:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrsw	x1, [x0]
	eor	x0, x0, x1
	ldp	x29, x30, [sp], 16
	ret
.type sw_l_shared_address, @function
.size sw_l_shared_address, .-sw_l_shared_address
/* end function sw_l_shared_address */

.text
.balign 16
.globl sw_l_separated
sw_l_separated:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	x17, x1
	mov	x1, x0
	mov	x0, x17
	mov	w2, #2
	lsl	x2, x0, x2
	add	x1, x1, x2
	mov	x2, #991
	eor	x0, x0, x2
	ldrsw	x1, [x1]
	eor	x0, x0, x1
	ldp	x29, x30, [sp], 16
	ret
.type sw_l_separated, @function
.size sw_l_separated, .-sw_l_separated
/* end function sw_l_separated */

.text
.balign 16
.globl sw_l_wrong_scale
sw_l_wrong_scale:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrsw	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type sw_l_wrong_scale, @function
.size sw_l_wrong_scale, .-sw_l_wrong_scale
/* end function sw_l_wrong_scale */

.text
.balign 16
.globl sw_l_word_shift
sw_l_word_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	w1, w1, w2
	mov	w1, w1
	add	x0, x0, x1
	ldrsw	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type sw_l_word_shift, @function
.size sw_l_word_shift, .-sw_l_word_shift
/* end function sw_l_word_shift */

.text
.balign 16
.globl sw_l_barrier_call
sw_l_barrier_call:
	hint	#34
	stp	x29, x30, [sp, -32]!
	mov	x29, sp
	str	x19, [x29, 24]
	mov	w2, #2
	lsl	x1, x1, x2
	add	x19, x0, x1
	bl	scaled_barrier
	ldrsw	x0, [x19]
	ldr	x19, [x29, 24]
	ldp	x29, x30, [sp], 32
	ret
.type sw_l_barrier_call, @function
.size sw_l_barrier_call, .-sw_l_barrier_call
/* end function sw_l_barrier_call */

.text
.balign 16
.globl sw_l_live
sw_l_live:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x2, x1, x2
	add	x0, x0, x2
	ldrsw	x0, [x0]
	eor	x0, x1, x0
	ldp	x29, x30, [sp], 16
	ret
.type sw_l_live, @function
.size sw_l_live, .-sw_l_live
/* end function sw_l_live */

.text
.balign 16
.globl sw_l_pressure
sw_l_pressure:
	hint	#34
	stp	x29, x30, [sp, -96]!
	mov	x29, sp
	str	x19, [x29, 88]
	str	x20, [x29, 80]
	str	x21, [x29, 72]
	str	x22, [x29, 64]
	str	x23, [x29, 56]
	str	x24, [x29, 48]
	str	x25, [x29, 40]
	str	x26, [x29, 32]
	str	x27, [x29, 24]
	str	x28, [x29, 16]
	ldr	x8, [x29, 232]
	ldr	x9, [x29, 224]
	ldr	x10, [x29, 216]
	ldr	x11, [x29, 208]
	ldr	x12, [x29, 200]
	ldr	x13, [x29, 192]
	ldr	x14, [x29, 184]
	ldr	x15, [x29, 176]
	ldr	x16, [x29, 168]
	ldr	x19, [x29, 160]
	ldr	x20, [x29, 152]
	ldr	x21, [x29, 144]
	ldr	x22, [x29, 136]
	ldr	x23, [x29, 128]
	ldr	x24, [x29, 120]
	ldr	x25, [x29, 112]
	ldr	x26, [x29, 104]
	ldr	x27, [x29, 96]
	mov	x17, x4
	mov	x4, x3
	mov	x3, x17
	mov	x17, x5
	mov	x5, x2
	mov	x2, x17
	mov	x17, x7
	mov	x7, x0
	mov	x0, x17
	mov	x17, x1
	mov	x1, x7
	mov	x7, x17
	mov	x17, x6
	mov	x6, x1
	mov	x1, x17
	mov	w28, #2
	lsl	x7, x7, x28
	add	x6, x6, x7
	ldrsw	x6, [x6]
	add	x5, x5, x6
	add	x4, x4, x5
	add	x3, x3, x4
	add	x2, x2, x3
	add	x1, x1, x2
	add	x0, x0, x1
	add	x0, x27, x0
	add	x0, x26, x0
	add	x0, x25, x0
	add	x0, x24, x0
	add	x0, x23, x0
	add	x0, x22, x0
	add	x0, x21, x0
	add	x0, x20, x0
	add	x0, x19, x0
	add	x0, x16, x0
	add	x0, x15, x0
	add	x0, x14, x0
	add	x0, x13, x0
	add	x0, x12, x0
	add	x0, x11, x0
	add	x0, x10, x0
	add	x0, x9, x0
	add	x0, x8, x0
	ldr	x19, [x29, 88]
	ldr	x20, [x29, 80]
	ldr	x21, [x29, 72]
	ldr	x22, [x29, 64]
	ldr	x23, [x29, 56]
	ldr	x24, [x29, 48]
	ldr	x25, [x29, 40]
	ldr	x26, [x29, 32]
	ldr	x27, [x29, 24]
	ldr	x28, [x29, 16]
	ldp	x29, x30, [sp], 96
	ret
.type sw_l_pressure, @function
.size sw_l_pressure, .-sw_l_pressure
/* end function sw_l_pressure */

.text
.balign 16
.globl l_l_plain
l_l_plain:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #3
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldr	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type l_l_plain, @function
.size l_l_plain, .-l_l_plain
/* end function l_l_plain */

.text
.balign 16
.globl l_l_commuted
l_l_commuted:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #3
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldr	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type l_l_commuted, @function
.size l_l_commuted, .-l_l_commuted
/* end function l_l_commuted */

.text
.balign 16
.globl l_l_zero
l_l_zero:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldr	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type l_l_zero, @function
.size l_l_zero, .-l_l_zero
/* end function l_l_zero */

.text
.balign 16
.globl l_l_debug_shift
l_l_debug_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #3
	lsl	x1, x1, x2
	.loc 1 41 2
	add	x0, x0, x1
	ldr	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type l_l_debug_shift, @function
.size l_l_debug_shift, .-l_l_debug_shift
/* end function l_l_debug_shift */

.text
.balign 16
.globl l_l_debug_add
l_l_debug_add:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #3
	lsl	x1, x1, x2
	add	x0, x0, x1
	.loc 1 42 3
	ldr	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type l_l_debug_add, @function
.size l_l_debug_add, .-l_l_debug_add
/* end function l_l_debug_add */

.text
.balign 16
.globl l_l_shared_shift
l_l_shared_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	x17, x1
	mov	x1, x0
	mov	x0, x17
	mov	w2, #3
	lsl	x0, x0, x2
	add	x1, x1, x0
	ldr	x1, [x1]
	eor	x0, x0, x1
	ldp	x29, x30, [sp], 16
	ret
.type l_l_shared_shift, @function
.size l_l_shared_shift, .-l_l_shared_shift
/* end function l_l_shared_shift */

.text
.balign 16
.globl l_l_shared_address
l_l_shared_address:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #3
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldr	x1, [x0]
	eor	x0, x0, x1
	ldp	x29, x30, [sp], 16
	ret
.type l_l_shared_address, @function
.size l_l_shared_address, .-l_l_shared_address
/* end function l_l_shared_address */

.text
.balign 16
.globl l_l_separated
l_l_separated:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	x17, x1
	mov	x1, x0
	mov	x0, x17
	mov	w2, #3
	lsl	x2, x0, x2
	add	x1, x1, x2
	mov	x2, #991
	eor	x0, x0, x2
	ldr	x1, [x1]
	eor	x0, x0, x1
	ldp	x29, x30, [sp], 16
	ret
.type l_l_separated, @function
.size l_l_separated, .-l_l_separated
/* end function l_l_separated */

.text
.balign 16
.globl l_l_wrong_scale
l_l_wrong_scale:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldr	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type l_l_wrong_scale, @function
.size l_l_wrong_scale, .-l_l_wrong_scale
/* end function l_l_wrong_scale */

.text
.balign 16
.globl l_l_word_shift
l_l_word_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #3
	lsl	w1, w1, w2
	mov	w1, w1
	add	x0, x0, x1
	ldr	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type l_l_word_shift, @function
.size l_l_word_shift, .-l_l_word_shift
/* end function l_l_word_shift */

.text
.balign 16
.globl l_l_barrier_call
l_l_barrier_call:
	hint	#34
	stp	x29, x30, [sp, -32]!
	mov	x29, sp
	str	x19, [x29, 24]
	mov	w2, #3
	lsl	x1, x1, x2
	add	x19, x0, x1
	bl	scaled_barrier
	ldr	x0, [x19]
	ldr	x19, [x29, 24]
	ldp	x29, x30, [sp], 32
	ret
.type l_l_barrier_call, @function
.size l_l_barrier_call, .-l_l_barrier_call
/* end function l_l_barrier_call */

.text
.balign 16
.globl l_l_live
l_l_live:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #3
	lsl	x2, x1, x2
	add	x0, x0, x2
	ldr	x0, [x0]
	eor	x0, x1, x0
	ldp	x29, x30, [sp], 16
	ret
.type l_l_live, @function
.size l_l_live, .-l_l_live
/* end function l_l_live */

.text
.balign 16
.globl l_l_pressure
l_l_pressure:
	hint	#34
	stp	x29, x30, [sp, -96]!
	mov	x29, sp
	str	x19, [x29, 88]
	str	x20, [x29, 80]
	str	x21, [x29, 72]
	str	x22, [x29, 64]
	str	x23, [x29, 56]
	str	x24, [x29, 48]
	str	x25, [x29, 40]
	str	x26, [x29, 32]
	str	x27, [x29, 24]
	str	x28, [x29, 16]
	ldr	x8, [x29, 232]
	ldr	x9, [x29, 224]
	ldr	x10, [x29, 216]
	ldr	x11, [x29, 208]
	ldr	x12, [x29, 200]
	ldr	x13, [x29, 192]
	ldr	x14, [x29, 184]
	ldr	x15, [x29, 176]
	ldr	x16, [x29, 168]
	ldr	x19, [x29, 160]
	ldr	x20, [x29, 152]
	ldr	x21, [x29, 144]
	ldr	x22, [x29, 136]
	ldr	x23, [x29, 128]
	ldr	x24, [x29, 120]
	ldr	x25, [x29, 112]
	ldr	x26, [x29, 104]
	ldr	x27, [x29, 96]
	mov	x17, x4
	mov	x4, x3
	mov	x3, x17
	mov	x17, x5
	mov	x5, x2
	mov	x2, x17
	mov	x17, x7
	mov	x7, x0
	mov	x0, x17
	mov	x17, x1
	mov	x1, x7
	mov	x7, x17
	mov	x17, x6
	mov	x6, x1
	mov	x1, x17
	mov	w28, #3
	lsl	x7, x7, x28
	add	x6, x6, x7
	ldr	x6, [x6]
	add	x5, x5, x6
	add	x4, x4, x5
	add	x3, x3, x4
	add	x2, x2, x3
	add	x1, x1, x2
	add	x0, x0, x1
	add	x0, x27, x0
	add	x0, x26, x0
	add	x0, x25, x0
	add	x0, x24, x0
	add	x0, x23, x0
	add	x0, x22, x0
	add	x0, x21, x0
	add	x0, x20, x0
	add	x0, x19, x0
	add	x0, x16, x0
	add	x0, x15, x0
	add	x0, x14, x0
	add	x0, x13, x0
	add	x0, x12, x0
	add	x0, x11, x0
	add	x0, x10, x0
	add	x0, x9, x0
	add	x0, x8, x0
	ldr	x19, [x29, 88]
	ldr	x20, [x29, 80]
	ldr	x21, [x29, 72]
	ldr	x22, [x29, 64]
	ldr	x23, [x29, 56]
	ldr	x24, [x29, 48]
	ldr	x25, [x29, 40]
	ldr	x26, [x29, 32]
	ldr	x27, [x29, 24]
	ldr	x28, [x29, 16]
	ldp	x29, x30, [sp], 96
	ret
.type l_l_pressure, @function
.size l_l_pressure, .-l_l_pressure
/* end function l_l_pressure */

.text
.balign 16
.globl s_w_plain
s_w_plain:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldr	s0, [x0]
	fmov	w0, s0
	ldp	x29, x30, [sp], 16
	ret
.type s_w_plain, @function
.size s_w_plain, .-s_w_plain
/* end function s_w_plain */

.text
.balign 16
.globl s_w_commuted
s_w_commuted:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldr	s0, [x0]
	fmov	w0, s0
	ldp	x29, x30, [sp], 16
	ret
.type s_w_commuted, @function
.size s_w_commuted, .-s_w_commuted
/* end function s_w_commuted */

.text
.balign 16
.globl s_w_zero
s_w_zero:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldr	s0, [x0]
	fmov	w0, s0
	ldp	x29, x30, [sp], 16
	ret
.type s_w_zero, @function
.size s_w_zero, .-s_w_zero
/* end function s_w_zero */

.text
.balign 16
.globl s_w_debug_shift
s_w_debug_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	.loc 1 41 2
	add	x0, x0, x1
	ldr	s0, [x0]
	fmov	w0, s0
	ldp	x29, x30, [sp], 16
	ret
.type s_w_debug_shift, @function
.size s_w_debug_shift, .-s_w_debug_shift
/* end function s_w_debug_shift */

.text
.balign 16
.globl s_w_debug_add
s_w_debug_add:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	add	x0, x0, x1
	.loc 1 42 3
	ldr	s0, [x0]
	fmov	w0, s0
	ldp	x29, x30, [sp], 16
	ret
.type s_w_debug_add, @function
.size s_w_debug_add, .-s_w_debug_add
/* end function s_w_debug_add */

.text
.balign 16
.globl s_w_shared_shift
s_w_shared_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	x17, x1
	mov	x1, x0
	mov	x0, x17
	mov	w2, #2
	lsl	x0, x0, x2
	add	x1, x1, x0
	ldr	s0, [x1]
	fmov	w1, s0
	eor	w0, w0, w1
	ldp	x29, x30, [sp], 16
	ret
.type s_w_shared_shift, @function
.size s_w_shared_shift, .-s_w_shared_shift
/* end function s_w_shared_shift */

.text
.balign 16
.globl s_w_shared_address
s_w_shared_address:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldr	s0, [x0]
	fmov	w1, s0
	eor	w0, w0, w1
	ldp	x29, x30, [sp], 16
	ret
.type s_w_shared_address, @function
.size s_w_shared_address, .-s_w_shared_address
/* end function s_w_shared_address */

.text
.balign 16
.globl s_w_separated
s_w_separated:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	x17, x1
	mov	x1, x0
	mov	x0, x17
	mov	w2, #2
	lsl	x2, x0, x2
	add	x1, x1, x2
	mov	x2, #991
	eor	x0, x0, x2
	ldr	s0, [x1]
	fmov	w1, s0
	eor	w0, w0, w1
	ldp	x29, x30, [sp], 16
	ret
.type s_w_separated, @function
.size s_w_separated, .-s_w_separated
/* end function s_w_separated */

.text
.balign 16
.globl s_w_wrong_scale
s_w_wrong_scale:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldr	s0, [x0]
	fmov	w0, s0
	ldp	x29, x30, [sp], 16
	ret
.type s_w_wrong_scale, @function
.size s_w_wrong_scale, .-s_w_wrong_scale
/* end function s_w_wrong_scale */

.text
.balign 16
.globl s_w_word_shift
s_w_word_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	w1, w1, w2
	mov	w1, w1
	add	x0, x0, x1
	ldr	s0, [x0]
	fmov	w0, s0
	ldp	x29, x30, [sp], 16
	ret
.type s_w_word_shift, @function
.size s_w_word_shift, .-s_w_word_shift
/* end function s_w_word_shift */

.text
.balign 16
.globl s_w_barrier_call
s_w_barrier_call:
	hint	#34
	stp	x29, x30, [sp, -32]!
	mov	x29, sp
	str	x19, [x29, 24]
	mov	w2, #2
	lsl	x1, x1, x2
	add	x19, x0, x1
	bl	scaled_barrier
	ldr	s0, [x19]
	fmov	w0, s0
	ldr	x19, [x29, 24]
	ldp	x29, x30, [sp], 32
	ret
.type s_w_barrier_call, @function
.size s_w_barrier_call, .-s_w_barrier_call
/* end function s_w_barrier_call */

.text
.balign 16
.globl s_w_live
s_w_live:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x2, x1, x2
	add	x0, x0, x2
	ldr	s0, [x0]
	fmov	w0, s0
	eor	w0, w1, w0
	ldp	x29, x30, [sp], 16
	ret
.type s_w_live, @function
.size s_w_live, .-s_w_live
/* end function s_w_live */

.text
.balign 16
.globl s_w_pressure
s_w_pressure:
	hint	#34
	stp	x29, x30, [sp, -96]!
	mov	x29, sp
	str	x19, [x29, 88]
	str	x20, [x29, 80]
	str	x21, [x29, 72]
	str	x22, [x29, 64]
	str	x23, [x29, 56]
	str	x24, [x29, 48]
	str	x25, [x29, 40]
	str	x26, [x29, 32]
	str	x27, [x29, 24]
	str	x28, [x29, 16]
	ldr	x8, [x29, 232]
	ldr	x9, [x29, 224]
	ldr	x10, [x29, 216]
	ldr	x11, [x29, 208]
	ldr	x12, [x29, 200]
	ldr	x13, [x29, 192]
	ldr	x14, [x29, 184]
	ldr	x15, [x29, 176]
	ldr	x16, [x29, 168]
	ldr	x19, [x29, 160]
	ldr	x20, [x29, 152]
	ldr	x21, [x29, 144]
	ldr	x22, [x29, 136]
	ldr	x23, [x29, 128]
	ldr	x24, [x29, 120]
	ldr	x25, [x29, 112]
	ldr	x26, [x29, 104]
	ldr	x27, [x29, 96]
	mov	x17, x4
	mov	x4, x3
	mov	x3, x17
	mov	x17, x5
	mov	x5, x2
	mov	x2, x17
	mov	x17, x7
	mov	x7, x0
	mov	x0, x17
	mov	x17, x1
	mov	x1, x7
	mov	x7, x17
	mov	x17, x6
	mov	x6, x1
	mov	x1, x17
	mov	w28, #2
	lsl	x7, x7, x28
	add	x6, x6, x7
	ldr	s0, [x6]
	fmov	w6, s0
	add	w5, w5, w6
	add	w4, w4, w5
	add	w3, w3, w4
	add	w2, w2, w3
	add	w1, w1, w2
	add	w0, w0, w1
	add	w0, w27, w0
	add	w0, w26, w0
	add	w0, w25, w0
	add	w0, w24, w0
	add	w0, w23, w0
	add	w0, w22, w0
	add	w0, w21, w0
	add	w0, w20, w0
	add	w0, w19, w0
	add	w0, w16, w0
	add	w0, w15, w0
	add	w0, w14, w0
	add	w0, w13, w0
	add	w0, w12, w0
	add	w0, w11, w0
	add	w0, w10, w0
	add	w0, w9, w0
	add	w0, w8, w0
	ldr	x19, [x29, 88]
	ldr	x20, [x29, 80]
	ldr	x21, [x29, 72]
	ldr	x22, [x29, 64]
	ldr	x23, [x29, 56]
	ldr	x24, [x29, 48]
	ldr	x25, [x29, 40]
	ldr	x26, [x29, 32]
	ldr	x27, [x29, 24]
	ldr	x28, [x29, 16]
	ldp	x29, x30, [sp], 96
	ret
.type s_w_pressure, @function
.size s_w_pressure, .-s_w_pressure
/* end function s_w_pressure */

.text
.balign 16
.globl d_l_plain
d_l_plain:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #3
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldr	d0, [x0]
	fmov	x0, d0
	ldp	x29, x30, [sp], 16
	ret
.type d_l_plain, @function
.size d_l_plain, .-d_l_plain
/* end function d_l_plain */

.text
.balign 16
.globl d_l_commuted
d_l_commuted:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #3
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldr	d0, [x0]
	fmov	x0, d0
	ldp	x29, x30, [sp], 16
	ret
.type d_l_commuted, @function
.size d_l_commuted, .-d_l_commuted
/* end function d_l_commuted */

.text
.balign 16
.globl d_l_zero
d_l_zero:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldr	d0, [x0]
	fmov	x0, d0
	ldp	x29, x30, [sp], 16
	ret
.type d_l_zero, @function
.size d_l_zero, .-d_l_zero
/* end function d_l_zero */

.text
.balign 16
.globl d_l_debug_shift
d_l_debug_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #3
	lsl	x1, x1, x2
	.loc 1 41 2
	add	x0, x0, x1
	ldr	d0, [x0]
	fmov	x0, d0
	ldp	x29, x30, [sp], 16
	ret
.type d_l_debug_shift, @function
.size d_l_debug_shift, .-d_l_debug_shift
/* end function d_l_debug_shift */

.text
.balign 16
.globl d_l_debug_add
d_l_debug_add:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #3
	lsl	x1, x1, x2
	add	x0, x0, x1
	.loc 1 42 3
	ldr	d0, [x0]
	fmov	x0, d0
	ldp	x29, x30, [sp], 16
	ret
.type d_l_debug_add, @function
.size d_l_debug_add, .-d_l_debug_add
/* end function d_l_debug_add */

.text
.balign 16
.globl d_l_shared_shift
d_l_shared_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	x17, x1
	mov	x1, x0
	mov	x0, x17
	mov	w2, #3
	lsl	x0, x0, x2
	add	x1, x1, x0
	ldr	d0, [x1]
	fmov	x1, d0
	eor	x0, x0, x1
	ldp	x29, x30, [sp], 16
	ret
.type d_l_shared_shift, @function
.size d_l_shared_shift, .-d_l_shared_shift
/* end function d_l_shared_shift */

.text
.balign 16
.globl d_l_shared_address
d_l_shared_address:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #3
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldr	d0, [x0]
	fmov	x1, d0
	eor	x0, x0, x1
	ldp	x29, x30, [sp], 16
	ret
.type d_l_shared_address, @function
.size d_l_shared_address, .-d_l_shared_address
/* end function d_l_shared_address */

.text
.balign 16
.globl d_l_separated
d_l_separated:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	x17, x1
	mov	x1, x0
	mov	x0, x17
	mov	w2, #3
	lsl	x2, x0, x2
	add	x1, x1, x2
	mov	x2, #991
	eor	x0, x0, x2
	ldr	d0, [x1]
	fmov	x1, d0
	eor	x0, x0, x1
	ldp	x29, x30, [sp], 16
	ret
.type d_l_separated, @function
.size d_l_separated, .-d_l_separated
/* end function d_l_separated */

.text
.balign 16
.globl d_l_wrong_scale
d_l_wrong_scale:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldr	d0, [x0]
	fmov	x0, d0
	ldp	x29, x30, [sp], 16
	ret
.type d_l_wrong_scale, @function
.size d_l_wrong_scale, .-d_l_wrong_scale
/* end function d_l_wrong_scale */

.text
.balign 16
.globl d_l_word_shift
d_l_word_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #3
	lsl	w1, w1, w2
	mov	w1, w1
	add	x0, x0, x1
	ldr	d0, [x0]
	fmov	x0, d0
	ldp	x29, x30, [sp], 16
	ret
.type d_l_word_shift, @function
.size d_l_word_shift, .-d_l_word_shift
/* end function d_l_word_shift */

.text
.balign 16
.globl d_l_barrier_call
d_l_barrier_call:
	hint	#34
	stp	x29, x30, [sp, -32]!
	mov	x29, sp
	str	x19, [x29, 24]
	mov	w2, #3
	lsl	x1, x1, x2
	add	x19, x0, x1
	bl	scaled_barrier
	ldr	d0, [x19]
	fmov	x0, d0
	ldr	x19, [x29, 24]
	ldp	x29, x30, [sp], 32
	ret
.type d_l_barrier_call, @function
.size d_l_barrier_call, .-d_l_barrier_call
/* end function d_l_barrier_call */

.text
.balign 16
.globl d_l_live
d_l_live:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #3
	lsl	x2, x1, x2
	add	x0, x0, x2
	ldr	d0, [x0]
	fmov	x0, d0
	eor	x0, x1, x0
	ldp	x29, x30, [sp], 16
	ret
.type d_l_live, @function
.size d_l_live, .-d_l_live
/* end function d_l_live */

.text
.balign 16
.globl d_l_pressure
d_l_pressure:
	hint	#34
	stp	x29, x30, [sp, -96]!
	mov	x29, sp
	str	x19, [x29, 88]
	str	x20, [x29, 80]
	str	x21, [x29, 72]
	str	x22, [x29, 64]
	str	x23, [x29, 56]
	str	x24, [x29, 48]
	str	x25, [x29, 40]
	str	x26, [x29, 32]
	str	x27, [x29, 24]
	str	x28, [x29, 16]
	ldr	x8, [x29, 232]
	ldr	x9, [x29, 224]
	ldr	x10, [x29, 216]
	ldr	x11, [x29, 208]
	ldr	x12, [x29, 200]
	ldr	x13, [x29, 192]
	ldr	x14, [x29, 184]
	ldr	x15, [x29, 176]
	ldr	x16, [x29, 168]
	ldr	x19, [x29, 160]
	ldr	x20, [x29, 152]
	ldr	x21, [x29, 144]
	ldr	x22, [x29, 136]
	ldr	x23, [x29, 128]
	ldr	x24, [x29, 120]
	ldr	x25, [x29, 112]
	ldr	x26, [x29, 104]
	ldr	x27, [x29, 96]
	mov	x17, x4
	mov	x4, x3
	mov	x3, x17
	mov	x17, x5
	mov	x5, x2
	mov	x2, x17
	mov	x17, x7
	mov	x7, x0
	mov	x0, x17
	mov	x17, x1
	mov	x1, x7
	mov	x7, x17
	mov	x17, x6
	mov	x6, x1
	mov	x1, x17
	mov	w28, #3
	lsl	x7, x7, x28
	add	x6, x6, x7
	ldr	d0, [x6]
	fmov	x6, d0
	add	x5, x5, x6
	add	x4, x4, x5
	add	x3, x3, x4
	add	x2, x2, x3
	add	x1, x1, x2
	add	x0, x0, x1
	add	x0, x27, x0
	add	x0, x26, x0
	add	x0, x25, x0
	add	x0, x24, x0
	add	x0, x23, x0
	add	x0, x22, x0
	add	x0, x21, x0
	add	x0, x20, x0
	add	x0, x19, x0
	add	x0, x16, x0
	add	x0, x15, x0
	add	x0, x14, x0
	add	x0, x13, x0
	add	x0, x12, x0
	add	x0, x11, x0
	add	x0, x10, x0
	add	x0, x9, x0
	add	x0, x8, x0
	ldr	x19, [x29, 88]
	ldr	x20, [x29, 80]
	ldr	x21, [x29, 72]
	ldr	x22, [x29, 64]
	ldr	x23, [x29, 56]
	ldr	x24, [x29, 48]
	ldr	x25, [x29, 40]
	ldr	x26, [x29, 32]
	ldr	x27, [x29, 24]
	ldr	x28, [x29, 16]
	ldp	x29, x30, [sp], 96
	ret
.type d_l_pressure, @function
.size d_l_pressure, .-d_l_pressure
/* end function d_l_pressure */

.text
.balign 16
.globl same_base_index
same_base_index:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w1, #3
	lsl	x1, x0, x1
	add	x0, x0, x1
	ldr	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
.type same_base_index, @function
.size same_base_index, .-same_base_index
/* end function same_base_index */

.section .note.GNU-stack,"",@progbits
