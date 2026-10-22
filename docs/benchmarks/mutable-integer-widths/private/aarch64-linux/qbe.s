.text
.balign 16
.globl long_then_word
long_then_word:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w1, #1
	add	w0, w0, w1
	ldp	x29, x30, [sp], 16
	ret
.type long_then_word, @function
.size long_then_word, .-long_then_word
/* end function long_then_word */

.text
.balign 16
.globl word_then_long
word_then_long:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	x1, #3
	add	x0, x0, x1
	ldp	x29, x30, [sp], 16
	ret
.type word_then_long, @function
.size word_then_long, .-word_then_long
/* end function word_then_long */

.text
.balign 16
.globl parameter_long
parameter_long:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w1, #17
	add	w0, w0, w1
	ldp	x29, x30, [sp], 16
	ret
.type parameter_long, @function
.size parameter_long, .-parameter_long
/* end function parameter_long */

.text
.balign 16
.globl parameter_word
parameter_word:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	x1, #23
	add	x0, x0, x1
	ldp	x29, x30, [sp], 16
	ret
.type parameter_word, @function
.size parameter_word, .-parameter_word
/* end function parameter_word */

.text
.balign 16
.globl branch
branch:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w2, #1
	and	w1, w1, w2
	cmp	w1, #0
	bne	.L10
	mov	w1, #13
	add	w0, w0, w1
	b	.L11
.L10:
	mov	x1, #7
	add	x0, x0, x1
.L11:
	mov	w1, #22136
	movk	w1, #0x1234, lsl #16
	eor	w0, w0, w1
	ldp	x29, x30, [sp], 16
	ret
.type branch, @function
.size branch, .-branch
/* end function branch */

.text
.balign 16
.globl loop
loop:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	cmp	w1, #0
	beq	.L16
	mov	w2, #0
.L15:
	mov	w3, #3
	add	w0, w0, w3
	mov	w0, w0
	mov	x3, #7
	add	x0, x0, x3
	mov	w3, #1
	add	w2, w2, w3
	cmp	w2, w1
	bcc	.L15
.L16:
	ldp	x29, x30, [sp], 16
	ret
.type loop, @function
.size loop, .-loop
/* end function loop */

.text
.balign 16
.globl shift
shift:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	w1, w0, w1
	lsl	x0, x0, x1
	ldp	x29, x30, [sp], 16
	ret
.type shift, @function
.size shift, .-shift
/* end function shift */

.text
.balign 16
called:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w1, #7
	mul	w0, w0, w1
	ldp	x29, x30, [sp], 16
	ret
.type called, @function
.size called, .-called
/* end function called */

.text
.balign 16
.globl call_word
call_word:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	add	w0, w0, w1
	bl	called
	ldp	x29, x30, [sp], 16
	ret
.type call_word, @function
.size call_word, .-call_word
/* end function call_word */

.text
.balign 16
.globl word_roles
word_roles:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	eor	w0, w0, w1
	fmov	s0, w0
	fmov	w0, s0
	ldp	x29, x30, [sp], 16
	ret
.type word_roles, @function
.size word_roles, .-word_roles
/* end function word_roles */

.text
.balign 16
effect:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	str	w0, [x1]
	ldp	x29, x30, [sp], 16
	ret
.type effect, @function
.size effect, .-effect
/* end function effect */

.text
.balign 16
.globl void_call_word
void_call_word:
	hint	#34
	stp	x29, x30, [sp, -32]!
	mov	x29, sp
	add	w0, w0, w1
	add	x2, x29, #24
	mov	w1, #0
	str	w1, [x2]
	add	x1, x29, #24
	bl	effect
	add	x0, x29, #24
	ldr	w0, [x0]
	ldp	x29, x30, [sp], 32
	ret
.type void_call_word, @function
.size void_call_word, .-void_call_word
/* end function void_call_word */

.section .note.GNU-stack,"",@progbits
