.data
.balign 8
_ctoqbestr:
	.ascii "c->qbe(%d)"
	.byte 0
/* end data */

.data
.balign 8
_emptystr:
	.byte 0
/* end data */

.text
.balign 4
.globl _qfn0
_qfn0:
	hint	#34
	stp	x29, x30, [sp, -32]!
	mov	x29, sp
	str	d8, [x29, 24]
	ldr	s8, [x29, 32]
	mov	x0, #16
	sub	sp, sp, x0
	mov	x0, #0
	add	x1, sp, x0
	mov	w0, #0
	str	w0, [x1]
	adrp	x0, _ctoqbestr@page
	add	x0, x0, _ctoqbestr@pageoff
	bl	_printf
	fmov	s0, s8
	mov	x0, #16
	add	sp, sp, x0
	bl	_ps
	adrp	x0, _emptystr@page
	add	x0, x0, _emptystr@pageoff
	bl	_puts
	ldr	d8, [x29, 24]
	ldp	x29, x30, [sp], 32
	ret
/* end function qfn0 */

.text
.balign 4
.globl _qfn1
_qfn1:
	hint	#34
	stp	x29, x30, [sp, -48]!
	mov	x29, sp
	str	x19, [x29, 40]
	str	d8, [x29, 32]
	fmov	s8, s0
	mov	x3, #0
	add	x2, x29, #24
	add	x2, x2, x3
	str	x1, [x2]
	mov	x1, #16
	sub	sp, sp, x1
	mov	x1, #0
	add	x2, sp, x1
	mov	w1, #1
	str	w1, [x2]
	mov	w19, w0
	adrp	x0, _ctoqbestr@page
	add	x0, x0, _ctoqbestr@pageoff
	bl	_printf
	mov	w0, w19
	mov	x1, #16
	add	sp, sp, x1
	bl	_pw
	fmov	s0, s8
	bl	_ps
	add	x0, x29, #24
	bl	_pfi1
	adrp	x0, _emptystr@page
	add	x0, x0, _emptystr@pageoff
	bl	_puts
	ldr	x19, [x29, 40]
	ldr	d8, [x29, 32]
	ldp	x29, x30, [sp], 48
	ret
/* end function qfn1 */

.text
.balign 4
.globl _qfn2
_qfn2:
	hint	#34
	stp	x29, x30, [sp, -48]!
	mov	x29, sp
	str	x19, [x29, 40]
	str	d8, [x29, 32]
	fmov	s8, s0
	mov	x3, #0
	add	x2, x29, #24
	add	x2, x2, x3
	str	x1, [x2]
	mov	x1, #16
	sub	sp, sp, x1
	mov	x1, #0
	add	x2, sp, x1
	mov	w1, #2
	str	w1, [x2]
	mov	w19, w0
	adrp	x0, _ctoqbestr@page
	add	x0, x0, _ctoqbestr@pageoff
	bl	_printf
	mov	w0, w19
	mov	x1, #16
	add	sp, sp, x1
	bl	_pw
	add	x0, x29, #24
	bl	_pfi2
	fmov	s0, s8
	bl	_ps
	adrp	x0, _emptystr@page
	add	x0, x0, _emptystr@pageoff
	bl	_puts
	ldr	x19, [x29, 40]
	ldr	d8, [x29, 32]
	ldp	x29, x30, [sp], 48
	ret
/* end function qfn2 */

.text
.balign 4
.globl _qfn3
_qfn3:
	hint	#34
	stp	x29, x30, [sp, -48]!
	mov	x29, sp
	str	x19, [x29, 40]
	str	d8, [x29, 32]
	fmov	s8, s0
	mov	x3, #0
	add	x2, x29, #24
	add	x2, x2, x3
	str	x1, [x2]
	mov	x1, #16
	sub	sp, sp, x1
	mov	x1, #0
	add	x2, sp, x1
	mov	w1, #3
	str	w1, [x2]
	mov	w19, w0
	adrp	x0, _ctoqbestr@page
	add	x0, x0, _ctoqbestr@pageoff
	bl	_printf
	mov	w0, w19
	mov	x1, #16
	add	sp, sp, x1
	bl	_pw
	fmov	s0, s8
	bl	_ps
	add	x0, x29, #24
	bl	_pfi3
	adrp	x0, _emptystr@page
	add	x0, x0, _emptystr@pageoff
	bl	_puts
	ldr	x19, [x29, 40]
	ldr	d8, [x29, 32]
	ldp	x29, x30, [sp], 48
	ret
/* end function qfn3 */

.text
.balign 4
.globl _qfn4
_qfn4:
	hint	#34
	stp	x29, x30, [sp, -32]!
	mov	x29, sp
	mov	x1, #4
	add	x0, x29, #24
	add	x0, x0, x1
	str	s1, [x0]
	mov	x1, #0
	add	x0, x29, #24
	add	x0, x0, x1
	str	s0, [x0]
	mov	x0, #16
	sub	sp, sp, x0
	mov	x0, #0
	add	x1, sp, x0
	mov	w0, #4
	str	w0, [x1]
	adrp	x0, _ctoqbestr@page
	add	x0, x0, _ctoqbestr@pageoff
	bl	_printf
	mov	x0, #16
	add	sp, sp, x0
	add	x0, x29, #24
	bl	_pss
	adrp	x0, _emptystr@page
	add	x0, x0, _emptystr@pageoff
	bl	_puts
	ldp	x29, x30, [sp], 32
	ret
/* end function qfn4 */

.text
.balign 4
.globl _qfn5
_qfn5:
	hint	#34
	stp	x29, x30, [sp, -32]!
	mov	x29, sp
	str	x19, [x29, 24]
	str	d8, [x29, 16]
	ldr	s8, [x29, 40]
	mov	x1, #16
	sub	sp, sp, x1
	mov	x1, #0
	add	x2, sp, x1
	mov	w1, #5
	str	w1, [x2]
	mov	x19, x0
	adrp	x0, _ctoqbestr@page
	add	x0, x0, _ctoqbestr@pageoff
	bl	_printf
	mov	x0, x19
	mov	x1, #16
	add	sp, sp, x1
	mov	x19, x0
	add	x0, x29, #32
	bl	_pss
	fmov	s0, s8
	bl	_ps
	mov	x0, x19
	bl	_pl
	adrp	x0, _emptystr@page
	add	x0, x0, _emptystr@pageoff
	bl	_puts
	ldr	x19, [x29, 24]
	ldr	d8, [x29, 16]
	ldp	x29, x30, [sp], 32
	ret
/* end function qfn5 */

.text
.balign 4
.globl _qfn6
_qfn6:
	hint	#34
	stp	x29, x30, [sp, -32]!
	mov	x29, sp
	mov	x3, #8
	add	x2, x29, #16
	add	x2, x2, x3
	str	x1, [x2]
	mov	x2, #0
	add	x1, x29, #16
	add	x1, x1, x2
	str	x0, [x1]
	mov	x0, #16
	sub	sp, sp, x0
	mov	x0, #0
	add	x1, sp, x0
	mov	w0, #6
	str	w0, [x1]
	adrp	x0, _ctoqbestr@page
	add	x0, x0, _ctoqbestr@pageoff
	bl	_printf
	mov	x0, #16
	add	sp, sp, x0
	add	x0, x29, #16
	bl	_plb
	adrp	x0, _emptystr@page
	add	x0, x0, _emptystr@pageoff
	bl	_puts
	ldp	x29, x30, [sp], 32
	ret
/* end function qfn6 */

.text
.balign 4
.globl _qfn7
_qfn7:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	x0, #16
	sub	sp, sp, x0
	mov	x0, #0
	add	x1, sp, x0
	mov	w0, #7
	str	w0, [x1]
	adrp	x0, _ctoqbestr@page
	add	x0, x0, _ctoqbestr@pageoff
	bl	_printf
	mov	x0, #16
	add	sp, sp, x0
	add	x0, x29, #16
	bl	_plb
	adrp	x0, _emptystr@page
	add	x0, x0, _emptystr@pageoff
	bl	_puts
	ldp	x29, x30, [sp], 16
	ret
/* end function qfn7 */

.text
.balign 4
.globl _qfn8
_qfn8:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	x0, #16
	sub	sp, sp, x0
	mov	x0, #0
	add	x1, sp, x0
	mov	w0, #8
	str	w0, [x1]
	adrp	x0, _ctoqbestr@page
	add	x0, x0, _ctoqbestr@pageoff
	bl	_printf
	mov	x0, #16
	add	sp, sp, x0
	add	x0, x29, #16
	bl	_plb
	adrp	x0, _emptystr@page
	add	x0, x0, _emptystr@pageoff
	bl	_puts
	ldp	x29, x30, [sp], 16
	ret
/* end function qfn8 */

.text
.balign 4
.globl _qfn9
_qfn9:
	hint	#34
	stp	x29, x30, [sp, -32]!
	mov	x29, sp
	str	x19, [x29, 24]
	mov	x1, #16
	sub	sp, sp, x1
	mov	x1, #0
	add	x2, sp, x1
	mov	w1, #9
	str	w1, [x2]
	mov	x19, x0
	adrp	x0, _ctoqbestr@page
	add	x0, x0, _ctoqbestr@pageoff
	bl	_printf
	mov	x0, x19
	mov	x1, #16
	add	sp, sp, x1
	bl	_pbig
	adrp	x0, _emptystr@page
	add	x0, x0, _emptystr@pageoff
	bl	_puts
	ldr	x19, [x29, 24]
	ldp	x29, x30, [sp], 32
	ret
/* end function qfn9 */

.text
.balign 4
.globl _qfn10
_qfn10:
	hint	#34
	stp	x29, x30, [sp, -48]!
	mov	x29, sp
	str	x19, [x29, 40]
	str	x20, [x29, 32]
	str	d8, [x29, 24]
	ldr	x19, [x29, 56]
	fmov	s8, s0
	ldr	x20, [x29, 48]
	mov	x0, x20
	mov	x1, #16
	sub	sp, sp, x1
	mov	x1, #0
	add	x2, sp, x1
	mov	w1, #10
	str	w1, [x2]
	mov	x20, x0
	adrp	x0, _ctoqbestr@page
	add	x0, x0, _ctoqbestr@pageoff
	bl	_printf
	mov	x0, x20
	mov	x1, #16
	add	sp, sp, x1
	bl	_pbig
	fmov	s0, s8
	bl	_ps
	mov	x0, x19
	bl	_pl
	adrp	x0, _emptystr@page
	add	x0, x0, _emptystr@pageoff
	bl	_puts
	ldr	x19, [x29, 40]
	ldr	x20, [x29, 32]
	ldr	d8, [x29, 24]
	ldp	x29, x30, [sp], 48
	ret
/* end function qfn10 */

.text
.balign 4
.globl _qfn11
_qfn11:
	hint	#34
	stp	x29, x30, [sp, -48]!
	mov	x29, sp
	mov	x1, #16
	add	x0, x29, #24
	add	x0, x0, x1
	str	d2, [x0]
	mov	x1, #8
	add	x0, x29, #24
	add	x0, x0, x1
	str	d1, [x0]
	mov	x1, #0
	add	x0, x29, #24
	add	x0, x0, x1
	str	d0, [x0]
	mov	x0, #16
	sub	sp, sp, x0
	mov	x0, #0
	add	x1, sp, x0
	mov	w0, #11
	str	w0, [x1]
	adrp	x0, _ctoqbestr@page
	add	x0, x0, _ctoqbestr@pageoff
	bl	_printf
	mov	x0, #16
	add	sp, sp, x0
	add	x0, x29, #24
	bl	_pddd
	adrp	x0, _emptystr@page
	add	x0, x0, _emptystr@pageoff
	bl	_puts
	ldp	x29, x30, [sp], 48
	ret
/* end function qfn11 */

.text
.balign 4
.globl _main
_main:
	hint	#34
	stp	x29, x30, [sp, -64]!
	mov	x29, sp
	mov	x0, #16
	sub	sp, sp, x0
	mov	x0, #0
	add	x0, sp, x0
	adrp	x1, "Lfp2"@page
	add	x1, x1, "Lfp2"@pageoff
	ldr	s0, [x1]
	str	s0, [x0]
	adrp	x0, "Lfp1"@page
	add	x0, x0, "Lfp1"@pageoff
	ldr	s7, [x0]
	adrp	x0, "Lfp1"@page
	add	x0, x0, "Lfp1"@pageoff
	ldr	s6, [x0]
	adrp	x0, "Lfp1"@page
	add	x0, x0, "Lfp1"@pageoff
	ldr	s5, [x0]
	adrp	x0, "Lfp1"@page
	add	x0, x0, "Lfp1"@pageoff
	ldr	s4, [x0]
	adrp	x0, "Lfp1"@page
	add	x0, x0, "Lfp1"@pageoff
	ldr	s3, [x0]
	adrp	x0, "Lfp1"@page
	add	x0, x0, "Lfp1"@pageoff
	ldr	s2, [x0]
	adrp	x0, "Lfp1"@page
	add	x0, x0, "Lfp1"@pageoff
	ldr	s1, [x0]
	adrp	x0, "Lfp1"@page
	add	x0, x0, "Lfp1"@pageoff
	ldr	s0, [x0]
	bl	_cfn0
	mov	x0, #16
	add	sp, sp, x0
	mov	x1, #0
	adrp	x0, _fi1@page
	add	x0, x0, _fi1@pageoff
	add	x0, x0, x1
	ldr	x1, [x0]
	adrp	x0, "Lfp3"@page
	add	x0, x0, "Lfp3"@pageoff
	ldr	s0, [x0]
	mov	w0, #1
	bl	_cfn1
	adrp	x0, "Lfp4"@page
	add	x0, x0, "Lfp4"@pageoff
	ldr	s0, [x0]
	mov	x1, #0
	adrp	x0, _fi2@page
	add	x0, x0, _fi2@pageoff
	add	x0, x0, x1
	ldr	x1, [x0]
	mov	w0, #1
	bl	_cfn2
	mov	x1, #0
	adrp	x0, _fi3@page
	add	x0, x0, _fi3@pageoff
	add	x0, x0, x1
	ldr	x1, [x0]
	adrp	x0, "Lfp3"@page
	add	x0, x0, "Lfp3"@pageoff
	ldr	s0, [x0]
	mov	w0, #1
	bl	_cfn3
	mov	x1, #4
	adrp	x0, _ss@page
	add	x0, x0, _ss@pageoff
	add	x0, x0, x1
	ldr	s1, [x0]
	mov	x1, #0
	adrp	x0, _ss@page
	add	x0, x0, _ss@pageoff
	add	x0, x0, x1
	ldr	s0, [x0]
	bl	_cfn4
	mov	x0, #16
	sub	sp, sp, x0
	mov	x0, #8
	add	x0, sp, x0
	adrp	x1, "Lfp2"@page
	add	x1, x1, "Lfp2"@pageoff
	ldr	s0, [x1]
	str	s0, [x0]
	mov	x0, #0
	add	x1, sp, x0
	mov	x2, #0
	adrp	x0, _ss@page
	add	x0, x0, _ss@pageoff
	add	x0, x0, x2
	ldr	x0, [x0]
	mov	x2, #0
	add	x1, x1, x2
	str	x0, [x1]
	mov	x0, #10
	adrp	x1, "Lfp1"@page
	add	x1, x1, "Lfp1"@pageoff
	ldr	d6, [x1]
	adrp	x1, "Lfp1"@page
	add	x1, x1, "Lfp1"@pageoff
	ldr	d5, [x1]
	adrp	x1, "Lfp1"@page
	add	x1, x1, "Lfp1"@pageoff
	ldr	d4, [x1]
	adrp	x1, "Lfp1"@page
	add	x1, x1, "Lfp1"@pageoff
	ldr	d3, [x1]
	adrp	x1, "Lfp1"@page
	add	x1, x1, "Lfp1"@pageoff
	ldr	d2, [x1]
	adrp	x1, "Lfp1"@page
	add	x1, x1, "Lfp1"@pageoff
	ldr	d1, [x1]
	adrp	x1, "Lfp1"@page
	add	x1, x1, "Lfp1"@pageoff
	ldr	d0, [x1]
	bl	_cfn5
	mov	x0, #16
	add	sp, sp, x0
	mov	x1, #8
	adrp	x0, _lb@page
	add	x0, x0, _lb@pageoff
	add	x0, x0, x1
	ldr	x1, [x0]
	mov	x2, #0
	adrp	x0, _lb@page
	add	x0, x0, _lb@pageoff
	add	x0, x0, x2
	ldr	x0, [x0]
	bl	_cfn6
	mov	x0, #16
	sub	sp, sp, x0
	mov	x0, #0
	add	x1, sp, x0
	mov	x2, #0
	adrp	x0, _lb@page
	add	x0, x0, _lb@pageoff
	add	x0, x0, x2
	ldr	x0, [x0]
	mov	x2, #0
	add	x2, x1, x2
	str	x0, [x2]
	mov	x2, #8
	adrp	x0, _lb@page
	add	x0, x0, _lb@pageoff
	add	x0, x0, x2
	ldr	x0, [x0]
	mov	x2, #8
	add	x1, x1, x2
	str	x0, [x1]
	mov	w6, #0
	mov	w5, #0
	mov	w4, #0
	mov	w3, #0
	mov	w2, #0
	mov	w1, #0
	mov	w0, #0
	bl	_cfn7
	mov	x0, #16
	add	sp, sp, x0
	mov	x0, #16
	sub	sp, sp, x0
	mov	x0, #0
	add	x1, sp, x0
	mov	x2, #0
	adrp	x0, _lb@page
	add	x0, x0, _lb@pageoff
	add	x0, x0, x2
	ldr	x0, [x0]
	mov	x2, #0
	add	x2, x1, x2
	str	x0, [x2]
	mov	x2, #8
	adrp	x0, _lb@page
	add	x0, x0, _lb@pageoff
	add	x0, x0, x2
	ldr	x0, [x0]
	mov	x2, #8
	add	x1, x1, x2
	str	x0, [x1]
	mov	w7, #0
	mov	w6, #0
	mov	w5, #0
	mov	w4, #0
	mov	w3, #0
	mov	w2, #0
	mov	w1, #0
	mov	w0, #0
	bl	_cfn8
	mov	x0, #16
	add	sp, sp, x0
	mov	x1, #0
	adrp	x0, _big@page
	add	x0, x0, _big@pageoff
	add	x0, x0, x1
	ldrb	w0, [x0]
	mov	x2, #0
	add	x1, x29, #44
	add	x1, x1, x2
	strb	w0, [x1]
	mov	x1, #1
	adrp	x0, _big@page
	add	x0, x0, _big@pageoff
	add	x0, x0, x1
	ldr	x0, [x0]
	mov	x2, #1
	add	x1, x29, #44
	add	x1, x1, x2
	str	x0, [x1]
	mov	x1, #9
	adrp	x0, _big@page
	add	x0, x0, _big@pageoff
	add	x0, x0, x1
	ldr	x0, [x0]
	mov	x2, #9
	add	x1, x29, #44
	add	x1, x1, x2
	str	x0, [x1]
	add	x0, x29, #44
	bl	_cfn9
	mov	x1, #0
	adrp	x0, _big@page
	add	x0, x0, _big@pageoff
	add	x0, x0, x1
	ldrb	w0, [x0]
	mov	x2, #0
	add	x1, x29, #24
	add	x1, x1, x2
	strb	w0, [x1]
	mov	x1, #1
	adrp	x0, _big@page
	add	x0, x0, _big@pageoff
	add	x0, x0, x1
	ldr	x0, [x0]
	mov	x2, #1
	add	x1, x29, #24
	add	x1, x1, x2
	str	x0, [x1]
	mov	x1, #9
	adrp	x0, _big@page
	add	x0, x0, _big@pageoff
	add	x0, x0, x1
	ldr	x0, [x0]
	mov	x2, #9
	add	x1, x29, #24
	add	x1, x1, x2
	str	x0, [x1]
	mov	x0, #16
	sub	sp, sp, x0
	mov	x0, #8
	add	x1, sp, x0
	mov	x0, #11
	str	x0, [x1]
	mov	x0, #0
	add	x1, sp, x0
	add	x0, x29, #24
	str	x0, [x1]
	adrp	x0, "Lfp0"@page
	add	x0, x0, "Lfp0"@pageoff
	ldr	s0, [x0]
	mov	w7, #0
	mov	w6, #0
	mov	w5, #0
	mov	w4, #0
	mov	w3, #0
	mov	w2, #0
	mov	w1, #0
	mov	w0, #0
	bl	_cfn10
	mov	x0, #16
	add	sp, sp, x0
	mov	x1, #16
	adrp	x0, _ddd@page
	add	x0, x0, _ddd@pageoff
	add	x0, x0, x1
	ldr	d2, [x0]
	mov	x1, #8
	adrp	x0, _ddd@page
	add	x0, x0, _ddd@pageoff
	add	x0, x0, x1
	ldr	d1, [x0]
	mov	x1, #0
	adrp	x0, _ddd@page
	add	x0, x0, _ddd@pageoff
	add	x0, x0, x1
	ldr	d0, [x0]
	bl	_cfn11
	mov	w0, #0
	ldp	x29, x30, [sp], 64
	ret
/* end function main */

/* floating point constants */
.section __TEXT,__literal8,8byte_literals
.p2align 3
Lfp1:
	.quad 0 /* 0.000000 */

.section __TEXT,__literal4,4byte_literals
.p2align 2
Lfp0:
	.int 1092721050 /* 10.100000 */

.section __TEXT,__literal4,4byte_literals
.p2align 2
Lfp2:
	.int 1092511334 /* 9.900000 */

.section __TEXT,__literal4,4byte_literals
.p2align 2
Lfp3:
	.int 1074580685 /* 2.200000 */

.section __TEXT,__literal4,4byte_literals
.p2align 2
Lfp4:
	.int 1079194419 /* 3.300000 */

