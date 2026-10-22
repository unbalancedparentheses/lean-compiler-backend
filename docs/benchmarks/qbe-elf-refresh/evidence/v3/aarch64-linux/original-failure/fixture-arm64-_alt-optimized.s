.text
.balign 16
test:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w0, #100
	mov	w2, #0
.L2:
	mov	w1, #1
	sub	w2, w1, w2
	cmp	w2, #0
	bne	.L5
	mov	w1, #10
.L4:
	mov	w3, w1
	mov	w1, #1
	sub	w1, w3, w1
	cmp	w3, #0
	beq	.L2
	b	.L4
.L5:
	mov	w1, #10
	sub	w0, w0, w1
	cmp	w0, #0
	bne	.L2
	ldp	x29, x30, [sp], 16
	ret
.type test, @function
.size test, .-test
/* end function test */

.section .note.GNU-stack,"",@progbits
