.text
.balign 4
.globl _long_then_word
_long_then_word:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w1, #1
	add	w0, w0, w1
	ldp	x29, x30, [sp], 16
	ret
/* end function long_then_word */

.text
.balign 4
.globl _word_then_long
_word_then_long:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	x1, #3
	add	x0, x0, x1
	ldp	x29, x30, [sp], 16
	ret
/* end function word_then_long */

.text
.balign 4
.globl _parameter_long
_parameter_long:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w1, #17
	add	w0, w0, w1
	ldp	x29, x30, [sp], 16
	ret
/* end function parameter_long */

.text
.balign 4
.globl _parameter_word
_parameter_word:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	x1, #23
	add	x0, x0, x1
	ldp	x29, x30, [sp], 16
	ret
/* end function parameter_word */

.text
.balign 4
.globl _branch
_branch:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	and	w1, w1, w2
	cmp	w1, #0
	bne	L10
	mov	w1, #13
	add	w0, w0, w1
	b	L11
L10:
	mov	x1, #7
	add	x0, x0, x1
L11:
	mov	w1, #22136
	movk	w1, #0x1234, lsl #16
	eor	w0, w0, w1
	ldp	x29, x30, [sp], 16
	ret
/* end function branch */

.text
.balign 4
.globl _loop
_loop:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	cmp	w1, #0
	beq	L16
	mov	w2, #0
L15:
	mov	w3, #3
	add	w0, w0, w3
	mov	w0, w0
	mov	x3, #7
	add	x0, x0, x3
	mov	w3, #1
	add	w2, w2, w3
	cmp	w2, w1
	bcc	L15
L16:
	ldp	x29, x30, [sp], 16
	ret
/* end function loop */

.text
.balign 4
.globl _shift
_shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	w1, w0, w1
	lsl	x0, x0, x1
	ldp	x29, x30, [sp], 16
	ret
/* end function shift */

.text
.balign 4
_called:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w1, #7
	mul	w0, w0, w1
	ldp	x29, x30, [sp], 16
	ret
/* end function called */

.text
.balign 4
.globl _call_word
_call_word:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	w0, w0, w1
	bl	_called
	ldp	x29, x30, [sp], 16
	ret
/* end function call_word */

.text
.balign 4
.globl _word_roles
_word_roles:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	eor	w0, w0, w1
	fmov	s0, w0
	fmov	w0, s0
	ldp	x29, x30, [sp], 16
	ret
/* end function word_roles */

.text
.balign 4
_effect:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	str	w0, [x1]
	ldp	x29, x30, [sp], 16
	ret
/* end function effect */

.text
.balign 4
.globl _void_call_word
_void_call_word:
	hint	#34
	stp	x29, x30, [sp, -32]!
	mov	x29, sp
	add	w0, w0, w1
	add	x2, x29, #24
	mov	w1, #0
	str	w1, [x2]
	add	x1, x29, #24
	bl	_effect
	add	x0, x29, #24
	ldr	w0, [x0]
	ldp	x29, x30, [sp], 32
	ret
/* end function void_call_word */

