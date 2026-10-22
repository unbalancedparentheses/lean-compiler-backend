.file 1 "scaled.c"
.text
.balign 4
.globl _ub_w_plain
_ub_w_plain:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function ub_w_plain */

.text
.balign 4
.globl _ub_w_commuted
_ub_w_commuted:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function ub_w_commuted */

.text
.balign 4
.globl _ub_w_zero
_ub_w_zero:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function ub_w_zero */

.text
.balign 4
.globl _ub_w_debug_shift
_ub_w_debug_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	.loc 1 41 2
	add	x0, x0, x1
	ldrb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function ub_w_debug_shift */

.text
.balign 4
.globl _ub_w_debug_add
_ub_w_debug_add:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	.loc 1 42 3
	ldrb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function ub_w_debug_add */

.text
.balign 4
.globl _ub_w_shared_shift
_ub_w_shared_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrb	w0, [x0]
	eor	w0, w1, w0
	ldp	x29, x30, [sp], 16
	ret
/* end function ub_w_shared_shift */

.text
.balign 4
.globl _ub_w_shared_address
_ub_w_shared_address:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrb	w1, [x0]
	eor	w0, w0, w1
	ldp	x29, x30, [sp], 16
	ret
/* end function ub_w_shared_address */

.text
.balign 4
.globl _ub_w_separated
_ub_w_separated:
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
/* end function ub_w_separated */

.text
.balign 4
.globl _ub_w_wrong_scale
_ub_w_wrong_scale:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function ub_w_wrong_scale */

.text
.balign 4
.globl _ub_w_word_shift
_ub_w_word_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w1, w1
	add	x0, x0, x1
	ldrb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function ub_w_word_shift */

.text
.balign 4
.globl _ub_w_barrier_call
_ub_w_barrier_call:
	hint	#34
	stp	x29, x30, [sp, -32]!
	mov	x29, sp
	str	x19, [x29, 24]
	add	x19, x0, x1
	bl	_scaled_barrier
	ldrb	w0, [x19]
	ldr	x19, [x29, 24]
	ldp	x29, x30, [sp], 32
	ret
/* end function ub_w_barrier_call */

.text
.balign 4
.globl _ub_w_live
_ub_w_live:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrb	w0, [x0]
	eor	w0, w1, w0
	ldp	x29, x30, [sp], 16
	ret
/* end function ub_w_live */

.text
.balign 4
.globl _ub_w_pressure
_ub_w_pressure:
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
/* end function ub_w_pressure */

.text
.balign 4
.globl _ub_w_extension
_ub_w_extension:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrb	w0, [x0]
	uxtb	w0, w0
	ldp	x29, x30, [sp], 16
	ret
/* end function ub_w_extension */

.text
.balign 4
.globl _ub_l_plain
_ub_l_plain:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function ub_l_plain */

.text
.balign 4
.globl _ub_l_commuted
_ub_l_commuted:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function ub_l_commuted */

.text
.balign 4
.globl _ub_l_zero
_ub_l_zero:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function ub_l_zero */

.text
.balign 4
.globl _ub_l_debug_shift
_ub_l_debug_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	.loc 1 41 2
	add	x0, x0, x1
	ldrb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function ub_l_debug_shift */

.text
.balign 4
.globl _ub_l_debug_add
_ub_l_debug_add:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	.loc 1 42 3
	ldrb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function ub_l_debug_add */

.text
.balign 4
.globl _ub_l_shared_shift
_ub_l_shared_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrb	w0, [x0]
	eor	x0, x1, x0
	ldp	x29, x30, [sp], 16
	ret
/* end function ub_l_shared_shift */

.text
.balign 4
.globl _ub_l_shared_address
_ub_l_shared_address:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrb	w1, [x0]
	eor	x0, x0, x1
	ldp	x29, x30, [sp], 16
	ret
/* end function ub_l_shared_address */

.text
.balign 4
.globl _ub_l_separated
_ub_l_separated:
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
/* end function ub_l_separated */

.text
.balign 4
.globl _ub_l_wrong_scale
_ub_l_wrong_scale:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function ub_l_wrong_scale */

.text
.balign 4
.globl _ub_l_word_shift
_ub_l_word_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w1, w1
	add	x0, x0, x1
	ldrb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function ub_l_word_shift */

.text
.balign 4
.globl _ub_l_barrier_call
_ub_l_barrier_call:
	hint	#34
	stp	x29, x30, [sp, -32]!
	mov	x29, sp
	str	x19, [x29, 24]
	add	x19, x0, x1
	bl	_scaled_barrier
	ldrb	w0, [x19]
	ldr	x19, [x29, 24]
	ldp	x29, x30, [sp], 32
	ret
/* end function ub_l_barrier_call */

.text
.balign 4
.globl _ub_l_live
_ub_l_live:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrb	w0, [x0]
	eor	x0, x1, x0
	ldp	x29, x30, [sp], 16
	ret
/* end function ub_l_live */

.text
.balign 4
.globl _ub_l_pressure
_ub_l_pressure:
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
/* end function ub_l_pressure */

.text
.balign 4
.globl _ub_l_extension
_ub_l_extension:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function ub_l_extension */

.text
.balign 4
.globl _sb_w_plain
_sb_w_plain:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrsb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function sb_w_plain */

.text
.balign 4
.globl _sb_w_commuted
_sb_w_commuted:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrsb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function sb_w_commuted */

.text
.balign 4
.globl _sb_w_zero
_sb_w_zero:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrsb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function sb_w_zero */

.text
.balign 4
.globl _sb_w_debug_shift
_sb_w_debug_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	.loc 1 41 2
	add	x0, x0, x1
	ldrsb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function sb_w_debug_shift */

.text
.balign 4
.globl _sb_w_debug_add
_sb_w_debug_add:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	.loc 1 42 3
	ldrsb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function sb_w_debug_add */

.text
.balign 4
.globl _sb_w_shared_shift
_sb_w_shared_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrsb	w0, [x0]
	eor	w0, w1, w0
	ldp	x29, x30, [sp], 16
	ret
/* end function sb_w_shared_shift */

.text
.balign 4
.globl _sb_w_shared_address
_sb_w_shared_address:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrsb	w1, [x0]
	eor	w0, w0, w1
	ldp	x29, x30, [sp], 16
	ret
/* end function sb_w_shared_address */

.text
.balign 4
.globl _sb_w_separated
_sb_w_separated:
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
/* end function sb_w_separated */

.text
.balign 4
.globl _sb_w_wrong_scale
_sb_w_wrong_scale:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrsb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function sb_w_wrong_scale */

.text
.balign 4
.globl _sb_w_word_shift
_sb_w_word_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w1, w1
	add	x0, x0, x1
	ldrsb	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function sb_w_word_shift */

.text
.balign 4
.globl _sb_w_barrier_call
_sb_w_barrier_call:
	hint	#34
	stp	x29, x30, [sp, -32]!
	mov	x29, sp
	str	x19, [x29, 24]
	add	x19, x0, x1
	bl	_scaled_barrier
	ldrsb	w0, [x19]
	ldr	x19, [x29, 24]
	ldp	x29, x30, [sp], 32
	ret
/* end function sb_w_barrier_call */

.text
.balign 4
.globl _sb_w_live
_sb_w_live:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrsb	w0, [x0]
	eor	w0, w1, w0
	ldp	x29, x30, [sp], 16
	ret
/* end function sb_w_live */

.text
.balign 4
.globl _sb_w_pressure
_sb_w_pressure:
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
/* end function sb_w_pressure */

.text
.balign 4
.globl _sb_l_plain
_sb_l_plain:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrsb	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function sb_l_plain */

.text
.balign 4
.globl _sb_l_commuted
_sb_l_commuted:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrsb	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function sb_l_commuted */

.text
.balign 4
.globl _sb_l_zero
_sb_l_zero:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrsb	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function sb_l_zero */

.text
.balign 4
.globl _sb_l_debug_shift
_sb_l_debug_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	.loc 1 41 2
	add	x0, x0, x1
	ldrsb	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function sb_l_debug_shift */

.text
.balign 4
.globl _sb_l_debug_add
_sb_l_debug_add:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	.loc 1 42 3
	ldrsb	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function sb_l_debug_add */

.text
.balign 4
.globl _sb_l_shared_shift
_sb_l_shared_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrsb	x0, [x0]
	eor	x0, x1, x0
	ldp	x29, x30, [sp], 16
	ret
/* end function sb_l_shared_shift */

.text
.balign 4
.globl _sb_l_shared_address
_sb_l_shared_address:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrsb	x1, [x0]
	eor	x0, x0, x1
	ldp	x29, x30, [sp], 16
	ret
/* end function sb_l_shared_address */

.text
.balign 4
.globl _sb_l_separated
_sb_l_separated:
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
/* end function sb_l_separated */

.text
.balign 4
.globl _sb_l_wrong_scale
_sb_l_wrong_scale:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrsb	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function sb_l_wrong_scale */

.text
.balign 4
.globl _sb_l_word_shift
_sb_l_word_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w1, w1
	add	x0, x0, x1
	ldrsb	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function sb_l_word_shift */

.text
.balign 4
.globl _sb_l_barrier_call
_sb_l_barrier_call:
	hint	#34
	stp	x29, x30, [sp, -32]!
	mov	x29, sp
	str	x19, [x29, 24]
	add	x19, x0, x1
	bl	_scaled_barrier
	ldrsb	x0, [x19]
	ldr	x19, [x29, 24]
	ldp	x29, x30, [sp], 32
	ret
/* end function sb_l_barrier_call */

.text
.balign 4
.globl _sb_l_live
_sb_l_live:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrsb	x0, [x0]
	eor	x0, x1, x0
	ldp	x29, x30, [sp], 16
	ret
/* end function sb_l_live */

.text
.balign 4
.globl _sb_l_pressure
_sb_l_pressure:
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
/* end function sb_l_pressure */

.text
.balign 4
.globl _uh_w_plain
_uh_w_plain:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrh	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function uh_w_plain */

.text
.balign 4
.globl _uh_w_commuted
_uh_w_commuted:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrh	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function uh_w_commuted */

.text
.balign 4
.globl _uh_w_zero
_uh_w_zero:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrh	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function uh_w_zero */

.text
.balign 4
.globl _uh_w_debug_shift
_uh_w_debug_shift:
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
/* end function uh_w_debug_shift */

.text
.balign 4
.globl _uh_w_debug_add
_uh_w_debug_add:
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
/* end function uh_w_debug_add */

.text
.balign 4
.globl _uh_w_shared_shift
_uh_w_shared_shift:
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
/* end function uh_w_shared_shift */

.text
.balign 4
.globl _uh_w_shared_address
_uh_w_shared_address:
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
/* end function uh_w_shared_address */

.text
.balign 4
.globl _uh_w_separated
_uh_w_separated:
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
/* end function uh_w_separated */

.text
.balign 4
.globl _uh_w_wrong_scale
_uh_w_wrong_scale:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrh	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function uh_w_wrong_scale */

.text
.balign 4
.globl _uh_w_word_shift
_uh_w_word_shift:
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
/* end function uh_w_word_shift */

.text
.balign 4
.globl _uh_w_barrier_call
_uh_w_barrier_call:
	hint	#34
	stp	x29, x30, [sp, -32]!
	mov	x29, sp
	str	x19, [x29, 24]
	mov	w2, #1
	lsl	x1, x1, x2
	add	x19, x0, x1
	bl	_scaled_barrier
	ldrh	w0, [x19]
	ldr	x19, [x29, 24]
	ldp	x29, x30, [sp], 32
	ret
/* end function uh_w_barrier_call */

.text
.balign 4
.globl _uh_w_live
_uh_w_live:
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
/* end function uh_w_live */

.text
.balign 4
.globl _uh_w_pressure
_uh_w_pressure:
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
/* end function uh_w_pressure */

.text
.balign 4
.globl _uh_w_extension
_uh_w_extension:
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
/* end function uh_w_extension */

.text
.balign 4
.globl _uh_l_plain
_uh_l_plain:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrh	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function uh_l_plain */

.text
.balign 4
.globl _uh_l_commuted
_uh_l_commuted:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrh	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function uh_l_commuted */

.text
.balign 4
.globl _uh_l_zero
_uh_l_zero:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrh	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function uh_l_zero */

.text
.balign 4
.globl _uh_l_debug_shift
_uh_l_debug_shift:
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
/* end function uh_l_debug_shift */

.text
.balign 4
.globl _uh_l_debug_add
_uh_l_debug_add:
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
/* end function uh_l_debug_add */

.text
.balign 4
.globl _uh_l_shared_shift
_uh_l_shared_shift:
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
/* end function uh_l_shared_shift */

.text
.balign 4
.globl _uh_l_shared_address
_uh_l_shared_address:
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
/* end function uh_l_shared_address */

.text
.balign 4
.globl _uh_l_separated
_uh_l_separated:
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
/* end function uh_l_separated */

.text
.balign 4
.globl _uh_l_wrong_scale
_uh_l_wrong_scale:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrh	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function uh_l_wrong_scale */

.text
.balign 4
.globl _uh_l_word_shift
_uh_l_word_shift:
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
/* end function uh_l_word_shift */

.text
.balign 4
.globl _uh_l_barrier_call
_uh_l_barrier_call:
	hint	#34
	stp	x29, x30, [sp, -32]!
	mov	x29, sp
	str	x19, [x29, 24]
	mov	w2, #1
	lsl	x1, x1, x2
	add	x19, x0, x1
	bl	_scaled_barrier
	ldrh	w0, [x19]
	ldr	x19, [x29, 24]
	ldp	x29, x30, [sp], 32
	ret
/* end function uh_l_barrier_call */

.text
.balign 4
.globl _uh_l_live
_uh_l_live:
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
/* end function uh_l_live */

.text
.balign 4
.globl _uh_l_pressure
_uh_l_pressure:
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
/* end function uh_l_pressure */

.text
.balign 4
.globl _uh_l_extension
_uh_l_extension:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrh	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function uh_l_extension */

.text
.balign 4
.globl _sh_w_plain
_sh_w_plain:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrsh	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function sh_w_plain */

.text
.balign 4
.globl _sh_w_commuted
_sh_w_commuted:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrsh	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function sh_w_commuted */

.text
.balign 4
.globl _sh_w_zero
_sh_w_zero:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrsh	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function sh_w_zero */

.text
.balign 4
.globl _sh_w_debug_shift
_sh_w_debug_shift:
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
/* end function sh_w_debug_shift */

.text
.balign 4
.globl _sh_w_debug_add
_sh_w_debug_add:
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
/* end function sh_w_debug_add */

.text
.balign 4
.globl _sh_w_shared_shift
_sh_w_shared_shift:
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
/* end function sh_w_shared_shift */

.text
.balign 4
.globl _sh_w_shared_address
_sh_w_shared_address:
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
/* end function sh_w_shared_address */

.text
.balign 4
.globl _sh_w_separated
_sh_w_separated:
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
/* end function sh_w_separated */

.text
.balign 4
.globl _sh_w_wrong_scale
_sh_w_wrong_scale:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrsh	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function sh_w_wrong_scale */

.text
.balign 4
.globl _sh_w_word_shift
_sh_w_word_shift:
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
/* end function sh_w_word_shift */

.text
.balign 4
.globl _sh_w_barrier_call
_sh_w_barrier_call:
	hint	#34
	stp	x29, x30, [sp, -32]!
	mov	x29, sp
	str	x19, [x29, 24]
	mov	w2, #1
	lsl	x1, x1, x2
	add	x19, x0, x1
	bl	_scaled_barrier
	ldrsh	w0, [x19]
	ldr	x19, [x29, 24]
	ldp	x29, x30, [sp], 32
	ret
/* end function sh_w_barrier_call */

.text
.balign 4
.globl _sh_w_live
_sh_w_live:
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
/* end function sh_w_live */

.text
.balign 4
.globl _sh_w_pressure
_sh_w_pressure:
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
/* end function sh_w_pressure */

.text
.balign 4
.globl _sh_l_plain
_sh_l_plain:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrsh	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function sh_l_plain */

.text
.balign 4
.globl _sh_l_commuted
_sh_l_commuted:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrsh	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function sh_l_commuted */

.text
.balign 4
.globl _sh_l_zero
_sh_l_zero:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrsh	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function sh_l_zero */

.text
.balign 4
.globl _sh_l_debug_shift
_sh_l_debug_shift:
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
/* end function sh_l_debug_shift */

.text
.balign 4
.globl _sh_l_debug_add
_sh_l_debug_add:
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
/* end function sh_l_debug_add */

.text
.balign 4
.globl _sh_l_shared_shift
_sh_l_shared_shift:
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
/* end function sh_l_shared_shift */

.text
.balign 4
.globl _sh_l_shared_address
_sh_l_shared_address:
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
/* end function sh_l_shared_address */

.text
.balign 4
.globl _sh_l_separated
_sh_l_separated:
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
/* end function sh_l_separated */

.text
.balign 4
.globl _sh_l_wrong_scale
_sh_l_wrong_scale:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrsh	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function sh_l_wrong_scale */

.text
.balign 4
.globl _sh_l_word_shift
_sh_l_word_shift:
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
/* end function sh_l_word_shift */

.text
.balign 4
.globl _sh_l_barrier_call
_sh_l_barrier_call:
	hint	#34
	stp	x29, x30, [sp, -32]!
	mov	x29, sp
	str	x19, [x29, 24]
	mov	w2, #1
	lsl	x1, x1, x2
	add	x19, x0, x1
	bl	_scaled_barrier
	ldrsh	x0, [x19]
	ldr	x19, [x29, 24]
	ldp	x29, x30, [sp], 32
	ret
/* end function sh_l_barrier_call */

.text
.balign 4
.globl _sh_l_live
_sh_l_live:
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
/* end function sh_l_live */

.text
.balign 4
.globl _sh_l_pressure
_sh_l_pressure:
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
/* end function sh_l_pressure */

.text
.balign 4
.globl _uw_w_plain
_uw_w_plain:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldr	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function uw_w_plain */

.text
.balign 4
.globl _uw_w_commuted
_uw_w_commuted:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldr	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function uw_w_commuted */

.text
.balign 4
.globl _uw_w_zero
_uw_w_zero:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldr	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function uw_w_zero */

.text
.balign 4
.globl _uw_w_debug_shift
_uw_w_debug_shift:
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
/* end function uw_w_debug_shift */

.text
.balign 4
.globl _uw_w_debug_add
_uw_w_debug_add:
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
/* end function uw_w_debug_add */

.text
.balign 4
.globl _uw_w_shared_shift
_uw_w_shared_shift:
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
/* end function uw_w_shared_shift */

.text
.balign 4
.globl _uw_w_shared_address
_uw_w_shared_address:
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
/* end function uw_w_shared_address */

.text
.balign 4
.globl _uw_w_separated
_uw_w_separated:
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
/* end function uw_w_separated */

.text
.balign 4
.globl _uw_w_wrong_scale
_uw_w_wrong_scale:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldr	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function uw_w_wrong_scale */

.text
.balign 4
.globl _uw_w_word_shift
_uw_w_word_shift:
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
/* end function uw_w_word_shift */

.text
.balign 4
.globl _uw_w_barrier_call
_uw_w_barrier_call:
	hint	#34
	stp	x29, x30, [sp, -32]!
	mov	x29, sp
	str	x19, [x29, 24]
	mov	w2, #2
	lsl	x1, x1, x2
	add	x19, x0, x1
	bl	_scaled_barrier
	ldr	w0, [x19]
	ldr	x19, [x29, 24]
	ldp	x29, x30, [sp], 32
	ret
/* end function uw_w_barrier_call */

.text
.balign 4
.globl _uw_w_live
_uw_w_live:
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
/* end function uw_w_live */

.text
.balign 4
.globl _uw_w_pressure
_uw_w_pressure:
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
/* end function uw_w_pressure */

.text
.balign 4
.globl _uw_w_extension
_uw_w_extension:
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
/* end function uw_w_extension */

.text
.balign 4
.globl _uw_l_plain
_uw_l_plain:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldr	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function uw_l_plain */

.text
.balign 4
.globl _uw_l_commuted
_uw_l_commuted:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldr	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function uw_l_commuted */

.text
.balign 4
.globl _uw_l_zero
_uw_l_zero:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldr	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function uw_l_zero */

.text
.balign 4
.globl _uw_l_debug_shift
_uw_l_debug_shift:
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
/* end function uw_l_debug_shift */

.text
.balign 4
.globl _uw_l_debug_add
_uw_l_debug_add:
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
/* end function uw_l_debug_add */

.text
.balign 4
.globl _uw_l_shared_shift
_uw_l_shared_shift:
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
/* end function uw_l_shared_shift */

.text
.balign 4
.globl _uw_l_shared_address
_uw_l_shared_address:
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
/* end function uw_l_shared_address */

.text
.balign 4
.globl _uw_l_separated
_uw_l_separated:
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
/* end function uw_l_separated */

.text
.balign 4
.globl _uw_l_wrong_scale
_uw_l_wrong_scale:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldr	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function uw_l_wrong_scale */

.text
.balign 4
.globl _uw_l_word_shift
_uw_l_word_shift:
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
/* end function uw_l_word_shift */

.text
.balign 4
.globl _uw_l_barrier_call
_uw_l_barrier_call:
	hint	#34
	stp	x29, x30, [sp, -32]!
	mov	x29, sp
	str	x19, [x29, 24]
	mov	w2, #2
	lsl	x1, x1, x2
	add	x19, x0, x1
	bl	_scaled_barrier
	ldr	w0, [x19]
	ldr	x19, [x29, 24]
	ldp	x29, x30, [sp], 32
	ret
/* end function uw_l_barrier_call */

.text
.balign 4
.globl _uw_l_live
_uw_l_live:
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
/* end function uw_l_live */

.text
.balign 4
.globl _uw_l_pressure
_uw_l_pressure:
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
/* end function uw_l_pressure */

.text
.balign 4
.globl _uw_l_extension
_uw_l_extension:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldr	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function uw_l_extension */

.text
.balign 4
.globl _sw_w_plain
_sw_w_plain:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldr	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function sw_w_plain */

.text
.balign 4
.globl _sw_w_commuted
_sw_w_commuted:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldr	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function sw_w_commuted */

.text
.balign 4
.globl _sw_w_zero
_sw_w_zero:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldr	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function sw_w_zero */

.text
.balign 4
.globl _sw_w_debug_shift
_sw_w_debug_shift:
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
/* end function sw_w_debug_shift */

.text
.balign 4
.globl _sw_w_debug_add
_sw_w_debug_add:
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
/* end function sw_w_debug_add */

.text
.balign 4
.globl _sw_w_shared_shift
_sw_w_shared_shift:
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
/* end function sw_w_shared_shift */

.text
.balign 4
.globl _sw_w_shared_address
_sw_w_shared_address:
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
/* end function sw_w_shared_address */

.text
.balign 4
.globl _sw_w_separated
_sw_w_separated:
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
/* end function sw_w_separated */

.text
.balign 4
.globl _sw_w_wrong_scale
_sw_w_wrong_scale:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldr	w0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function sw_w_wrong_scale */

.text
.balign 4
.globl _sw_w_word_shift
_sw_w_word_shift:
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
/* end function sw_w_word_shift */

.text
.balign 4
.globl _sw_w_barrier_call
_sw_w_barrier_call:
	hint	#34
	stp	x29, x30, [sp, -32]!
	mov	x29, sp
	str	x19, [x29, 24]
	mov	w2, #2
	lsl	x1, x1, x2
	add	x19, x0, x1
	bl	_scaled_barrier
	ldr	w0, [x19]
	ldr	x19, [x29, 24]
	ldp	x29, x30, [sp], 32
	ret
/* end function sw_w_barrier_call */

.text
.balign 4
.globl _sw_w_live
_sw_w_live:
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
/* end function sw_w_live */

.text
.balign 4
.globl _sw_w_pressure
_sw_w_pressure:
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
/* end function sw_w_pressure */

.text
.balign 4
.globl _sw_l_plain
_sw_l_plain:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrsw	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function sw_l_plain */

.text
.balign 4
.globl _sw_l_commuted
_sw_l_commuted:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #2
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrsw	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function sw_l_commuted */

.text
.balign 4
.globl _sw_l_zero
_sw_l_zero:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldrsw	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function sw_l_zero */

.text
.balign 4
.globl _sw_l_debug_shift
_sw_l_debug_shift:
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
/* end function sw_l_debug_shift */

.text
.balign 4
.globl _sw_l_debug_add
_sw_l_debug_add:
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
/* end function sw_l_debug_add */

.text
.balign 4
.globl _sw_l_shared_shift
_sw_l_shared_shift:
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
/* end function sw_l_shared_shift */

.text
.balign 4
.globl _sw_l_shared_address
_sw_l_shared_address:
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
/* end function sw_l_shared_address */

.text
.balign 4
.globl _sw_l_separated
_sw_l_separated:
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
/* end function sw_l_separated */

.text
.balign 4
.globl _sw_l_wrong_scale
_sw_l_wrong_scale:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldrsw	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function sw_l_wrong_scale */

.text
.balign 4
.globl _sw_l_word_shift
_sw_l_word_shift:
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
/* end function sw_l_word_shift */

.text
.balign 4
.globl _sw_l_barrier_call
_sw_l_barrier_call:
	hint	#34
	stp	x29, x30, [sp, -32]!
	mov	x29, sp
	str	x19, [x29, 24]
	mov	w2, #2
	lsl	x1, x1, x2
	add	x19, x0, x1
	bl	_scaled_barrier
	ldrsw	x0, [x19]
	ldr	x19, [x29, 24]
	ldp	x29, x30, [sp], 32
	ret
/* end function sw_l_barrier_call */

.text
.balign 4
.globl _sw_l_live
_sw_l_live:
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
/* end function sw_l_live */

.text
.balign 4
.globl _sw_l_pressure
_sw_l_pressure:
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
/* end function sw_l_pressure */

.text
.balign 4
.globl _l_l_plain
_l_l_plain:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #3
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldr	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function l_l_plain */

.text
.balign 4
.globl _l_l_commuted
_l_l_commuted:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #3
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldr	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function l_l_commuted */

.text
.balign 4
.globl _l_l_zero
_l_l_zero:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldr	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function l_l_zero */

.text
.balign 4
.globl _l_l_debug_shift
_l_l_debug_shift:
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
/* end function l_l_debug_shift */

.text
.balign 4
.globl _l_l_debug_add
_l_l_debug_add:
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
/* end function l_l_debug_add */

.text
.balign 4
.globl _l_l_shared_shift
_l_l_shared_shift:
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
/* end function l_l_shared_shift */

.text
.balign 4
.globl _l_l_shared_address
_l_l_shared_address:
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
/* end function l_l_shared_address */

.text
.balign 4
.globl _l_l_separated
_l_l_separated:
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
/* end function l_l_separated */

.text
.balign 4
.globl _l_l_wrong_scale
_l_l_wrong_scale:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	lsl	x1, x1, x2
	add	x0, x0, x1
	ldr	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function l_l_wrong_scale */

.text
.balign 4
.globl _l_l_word_shift
_l_l_word_shift:
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
/* end function l_l_word_shift */

.text
.balign 4
.globl _l_l_barrier_call
_l_l_barrier_call:
	hint	#34
	stp	x29, x30, [sp, -32]!
	mov	x29, sp
	str	x19, [x29, 24]
	mov	w2, #3
	lsl	x1, x1, x2
	add	x19, x0, x1
	bl	_scaled_barrier
	ldr	x0, [x19]
	ldr	x19, [x29, 24]
	ldp	x29, x30, [sp], 32
	ret
/* end function l_l_barrier_call */

.text
.balign 4
.globl _l_l_live
_l_l_live:
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
/* end function l_l_live */

.text
.balign 4
.globl _l_l_pressure
_l_l_pressure:
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
/* end function l_l_pressure */

.text
.balign 4
.globl _s_w_plain
_s_w_plain:
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
/* end function s_w_plain */

.text
.balign 4
.globl _s_w_commuted
_s_w_commuted:
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
/* end function s_w_commuted */

.text
.balign 4
.globl _s_w_zero
_s_w_zero:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldr	s0, [x0]
	fmov	w0, s0
	ldp	x29, x30, [sp], 16
	ret
/* end function s_w_zero */

.text
.balign 4
.globl _s_w_debug_shift
_s_w_debug_shift:
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
/* end function s_w_debug_shift */

.text
.balign 4
.globl _s_w_debug_add
_s_w_debug_add:
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
/* end function s_w_debug_add */

.text
.balign 4
.globl _s_w_shared_shift
_s_w_shared_shift:
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
/* end function s_w_shared_shift */

.text
.balign 4
.globl _s_w_shared_address
_s_w_shared_address:
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
/* end function s_w_shared_address */

.text
.balign 4
.globl _s_w_separated
_s_w_separated:
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
/* end function s_w_separated */

.text
.balign 4
.globl _s_w_wrong_scale
_s_w_wrong_scale:
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
/* end function s_w_wrong_scale */

.text
.balign 4
.globl _s_w_word_shift
_s_w_word_shift:
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
/* end function s_w_word_shift */

.text
.balign 4
.globl _s_w_barrier_call
_s_w_barrier_call:
	hint	#34
	stp	x29, x30, [sp, -32]!
	mov	x29, sp
	str	x19, [x29, 24]
	mov	w2, #2
	lsl	x1, x1, x2
	add	x19, x0, x1
	bl	_scaled_barrier
	ldr	s0, [x19]
	fmov	w0, s0
	ldr	x19, [x29, 24]
	ldp	x29, x30, [sp], 32
	ret
/* end function s_w_barrier_call */

.text
.balign 4
.globl _s_w_live
_s_w_live:
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
/* end function s_w_live */

.text
.balign 4
.globl _s_w_pressure
_s_w_pressure:
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
/* end function s_w_pressure */

.text
.balign 4
.globl _d_l_plain
_d_l_plain:
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
/* end function d_l_plain */

.text
.balign 4
.globl _d_l_commuted
_d_l_commuted:
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
/* end function d_l_commuted */

.text
.balign 4
.globl _d_l_zero
_d_l_zero:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	x0, x0, x1
	ldr	d0, [x0]
	fmov	x0, d0
	ldp	x29, x30, [sp], 16
	ret
/* end function d_l_zero */

.text
.balign 4
.globl _d_l_debug_shift
_d_l_debug_shift:
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
/* end function d_l_debug_shift */

.text
.balign 4
.globl _d_l_debug_add
_d_l_debug_add:
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
/* end function d_l_debug_add */

.text
.balign 4
.globl _d_l_shared_shift
_d_l_shared_shift:
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
/* end function d_l_shared_shift */

.text
.balign 4
.globl _d_l_shared_address
_d_l_shared_address:
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
/* end function d_l_shared_address */

.text
.balign 4
.globl _d_l_separated
_d_l_separated:
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
/* end function d_l_separated */

.text
.balign 4
.globl _d_l_wrong_scale
_d_l_wrong_scale:
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
/* end function d_l_wrong_scale */

.text
.balign 4
.globl _d_l_word_shift
_d_l_word_shift:
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
/* end function d_l_word_shift */

.text
.balign 4
.globl _d_l_barrier_call
_d_l_barrier_call:
	hint	#34
	stp	x29, x30, [sp, -32]!
	mov	x29, sp
	str	x19, [x29, 24]
	mov	w2, #3
	lsl	x1, x1, x2
	add	x19, x0, x1
	bl	_scaled_barrier
	ldr	d0, [x19]
	fmov	x0, d0
	ldr	x19, [x29, 24]
	ldp	x29, x30, [sp], 32
	ret
/* end function d_l_barrier_call */

.text
.balign 4
.globl _d_l_live
_d_l_live:
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
/* end function d_l_live */

.text
.balign 4
.globl _d_l_pressure
_d_l_pressure:
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
/* end function d_l_pressure */

.text
.balign 4
.globl _same_base_index
_same_base_index:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w1, #3
	lsl	x1, x0, x1
	add	x0, x0, x1
	ldr	x0, [x0]
	ldp	x29, x30, [sp], 16
	ret
/* end function same_base_index */

