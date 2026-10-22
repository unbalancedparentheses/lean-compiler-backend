.text
.balign 16
echo_integer:
	hint	#34
	str	q7, [sp, -16]!
	str	q6, [sp, -16]!
	str	q5, [sp, -16]!
	str	q4, [sp, -16]!
	str	q3, [sp, -16]!
	str	q2, [sp, -16]!
	str	q1, [sp, -16]!
	str	q0, [sp, -16]!
	stp	x6, x7, [sp, -16]!
	stp	x4, x5, [sp, -16]!
	stp	x2, x3, [sp, -16]!
	stp	x0, x1, [sp, -16]!
	stp	x29, x30, [sp, -48]!
	mov	x29, sp
	mov	x4, #8
	add	x3, x29, #32
	add	x3, x3, x4
	str	x1, [x3]
	mov	x3, #0
	add	x1, x29, #32
	add	x1, x1, x3
	str	x0, [x1]
	cmp	w2, #0
	beq	.L2
	mov	w0, #1
	sub	w2, w2, w0
	mov	x3, #91
	mov	x1, #8
	add	x0, x29, #32
	add	x0, x0, x1
	ldr	x1, [x0]
	mov	x4, #0
	add	x0, x29, #32
	add	x0, x0, x4
	ldr	x0, [x0]
	bl	echo_integer
	mov	x3, #8
	add	x2, x29, #16
	add	x2, x2, x3
	str	x1, [x2]
	mov	x2, #0
	add	x1, x29, #16
	add	x1, x1, x2
	str	x0, [x1]
	mov	x1, #8
	add	x0, x29, #16
	add	x0, x0, x1
	ldr	x1, [x0]
	mov	x2, #0
	add	x0, x29, #16
	add	x0, x0, x2
	ldr	x0, [x0]
	b	.L3
.L2:
	mov	x1, #8
	add	x0, x29, #32
	add	x0, x0, x1
	ldr	x1, [x0]
	mov	x2, #0
	add	x0, x29, #32
	add	x0, x0, x2
	ldr	x0, [x0]
.L3:
	ldp	x29, x30, [sp], 240
	ret
.type echo_integer, @function
.size echo_integer, .-echo_integer
/* end function echo_integer */

.text
.balign 16
.globl probe_integer_direct
probe_integer_direct:
	hint	#34
	stp	x29, x30, [sp, -48]!
	mov	x29, sp
	str	x19, [x29, 40]
	mov	x19, x1
	mov	x3, #91
	mov	w2, #2
	mov	x1, #8
	add	x1, x0, x1
	ldr	x1, [x1]
	mov	x4, #0
	add	x0, x0, x4
	ldr	x0, [x0]
	bl	echo_integer
	mov	x3, #8
	add	x2, x29, #16
	add	x2, x2, x3
	str	x1, [x2]
	mov	x2, #0
	add	x1, x29, #16
	add	x1, x1, x2
	str	x0, [x1]
	add	x0, x29, #16
	ldrb	w0, [x0]
	strb	w0, [x19]
	mov	x2, #1
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #1
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #2
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #2
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #3
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #3
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #4
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #4
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #5
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #5
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #6
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #6
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #7
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #7
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #8
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #8
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #9
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #9
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #10
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #10
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #11
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #11
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #12
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #12
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #13
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #13
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #14
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #14
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #15
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #15
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	ldr	x19, [x29, 40]
	ldp	x29, x30, [sp], 48
	ret
.type probe_integer_direct, @function
.size probe_integer_direct, .-probe_integer_direct
/* end function probe_integer_direct */

.text
.balign 16
.globl probe_integer_indirect
probe_integer_indirect:
	hint	#34
	stp	x29, x30, [sp, -48]!
	mov	x29, sp
	str	x19, [x29, 40]
	mov	x19, x1
	mov	x3, #91
	mov	w2, #2
	mov	x1, #8
	add	x1, x0, x1
	ldr	x1, [x1]
	mov	x4, #0
	add	x0, x0, x4
	ldr	x0, [x0]
	bl	echo_integer
	mov	x3, #8
	add	x2, x29, #16
	add	x2, x2, x3
	str	x1, [x2]
	mov	x2, #0
	add	x1, x29, #16
	add	x1, x1, x2
	str	x0, [x1]
	add	x0, x29, #16
	ldrb	w0, [x0]
	strb	w0, [x19]
	mov	x2, #1
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #1
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #2
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #2
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #3
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #3
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #4
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #4
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #5
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #5
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #6
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #6
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #7
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #7
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #8
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #8
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #9
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #9
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #10
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #10
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #11
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #11
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #12
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #12
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #13
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #13
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #14
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #14
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #15
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #15
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	ldr	x19, [x29, 40]
	ldp	x29, x30, [sp], 48
	ret
.type probe_integer_indirect, @function
.size probe_integer_indirect, .-probe_integer_indirect
/* end function probe_integer_indirect */

.text
.balign 16
echo_floating:
	hint	#34
	str	q7, [sp, -16]!
	str	q6, [sp, -16]!
	str	q5, [sp, -16]!
	str	q4, [sp, -16]!
	str	q3, [sp, -16]!
	str	q2, [sp, -16]!
	str	q1, [sp, -16]!
	str	q0, [sp, -16]!
	stp	x6, x7, [sp, -16]!
	stp	x4, x5, [sp, -16]!
	stp	x2, x3, [sp, -16]!
	stp	x0, x1, [sp, -16]!
	stp	x29, x30, [sp, -48]!
	mov	x29, sp
	mov	x2, #8
	add	x1, x29, #32
	add	x1, x1, x2
	str	d1, [x1]
	mov	x2, #0
	add	x1, x29, #32
	add	x1, x1, x2
	str	d0, [x1]
	cmp	w0, #0
	beq	.L10
	mov	w1, #1
	sub	w0, w0, w1
	mov	x1, #91
	mov	x3, #8
	add	x2, x29, #32
	add	x2, x2, x3
	ldr	d1, [x2]
	mov	x3, #0
	add	x2, x29, #32
	add	x2, x2, x3
	ldr	d0, [x2]
	bl	echo_floating
	mov	x1, #8
	add	x0, x29, #16
	add	x0, x0, x1
	str	d1, [x0]
	mov	x1, #0
	add	x0, x29, #16
	add	x0, x0, x1
	str	d0, [x0]
	mov	x1, #8
	add	x0, x29, #16
	add	x0, x0, x1
	ldr	d1, [x0]
	mov	x1, #0
	add	x0, x29, #16
	add	x0, x0, x1
	ldr	d0, [x0]
	b	.L11
.L10:
	mov	x1, #8
	add	x0, x29, #32
	add	x0, x0, x1
	ldr	d1, [x0]
	mov	x1, #0
	add	x0, x29, #32
	add	x0, x0, x1
	ldr	d0, [x0]
.L11:
	ldp	x29, x30, [sp], 240
	ret
.type echo_floating, @function
.size echo_floating, .-echo_floating
/* end function echo_floating */

.text
.balign 16
.globl probe_floating_direct
probe_floating_direct:
	hint	#34
	stp	x29, x30, [sp, -48]!
	mov	x29, sp
	str	x19, [x29, 40]
	mov	x19, x1
	mov	x2, x0
	mov	x1, #91
	mov	w0, #2
	mov	x3, #8
	add	x3, x2, x3
	ldr	d1, [x3]
	mov	x3, #0
	add	x2, x2, x3
	ldr	d0, [x2]
	bl	echo_floating
	mov	x1, #8
	add	x0, x29, #16
	add	x0, x0, x1
	str	d1, [x0]
	mov	x1, #0
	add	x0, x29, #16
	add	x0, x0, x1
	str	d0, [x0]
	add	x0, x29, #16
	ldrb	w0, [x0]
	strb	w0, [x19]
	mov	x2, #1
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #1
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #2
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #2
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #3
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #3
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #4
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #4
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #5
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #5
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #6
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #6
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #7
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #7
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #8
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #8
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #9
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #9
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #10
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #10
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #11
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #11
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #12
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #12
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #13
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #13
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #14
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #14
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #15
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #15
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	ldr	x19, [x29, 40]
	ldp	x29, x30, [sp], 48
	ret
.type probe_floating_direct, @function
.size probe_floating_direct, .-probe_floating_direct
/* end function probe_floating_direct */

.text
.balign 16
.globl probe_floating_indirect
probe_floating_indirect:
	hint	#34
	stp	x29, x30, [sp, -48]!
	mov	x29, sp
	str	x19, [x29, 40]
	mov	x19, x1
	mov	x2, x0
	mov	x1, #91
	mov	w0, #2
	mov	x3, #8
	add	x3, x2, x3
	ldr	d1, [x3]
	mov	x3, #0
	add	x2, x2, x3
	ldr	d0, [x2]
	bl	echo_floating
	mov	x1, #8
	add	x0, x29, #16
	add	x0, x0, x1
	str	d1, [x0]
	mov	x1, #0
	add	x0, x29, #16
	add	x0, x0, x1
	str	d0, [x0]
	add	x0, x29, #16
	ldrb	w0, [x0]
	strb	w0, [x19]
	mov	x2, #1
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #1
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #2
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #2
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #3
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #3
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #4
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #4
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #5
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #5
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #6
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #6
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #7
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #7
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #8
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #8
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #9
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #9
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #10
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #10
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #11
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #11
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #12
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #12
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #13
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #13
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #14
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #14
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #15
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #15
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	ldr	x19, [x29, 40]
	ldp	x29, x30, [sp], 48
	ret
.type probe_floating_indirect, @function
.size probe_floating_indirect, .-probe_floating_indirect
/* end function probe_floating_indirect */

.text
.balign 16
echo_mixed:
	hint	#34
	str	q7, [sp, -16]!
	str	q6, [sp, -16]!
	str	q5, [sp, -16]!
	str	q4, [sp, -16]!
	str	q3, [sp, -16]!
	str	q2, [sp, -16]!
	str	q1, [sp, -16]!
	str	q0, [sp, -16]!
	stp	x6, x7, [sp, -16]!
	stp	x4, x5, [sp, -16]!
	stp	x2, x3, [sp, -16]!
	stp	x0, x1, [sp, -16]!
	stp	x29, x30, [sp, -48]!
	mov	x29, sp
	mov	x4, #8
	add	x3, x29, #32
	add	x3, x3, x4
	str	x1, [x3]
	mov	x3, #0
	add	x1, x29, #32
	add	x1, x1, x3
	str	x0, [x1]
	cmp	w2, #0
	beq	.L18
	mov	w0, #1
	sub	w2, w2, w0
	mov	x3, #91
	mov	x1, #8
	add	x0, x29, #32
	add	x0, x0, x1
	ldr	x1, [x0]
	mov	x4, #0
	add	x0, x29, #32
	add	x0, x0, x4
	ldr	x0, [x0]
	bl	echo_mixed
	mov	x3, #8
	add	x2, x29, #16
	add	x2, x2, x3
	str	x1, [x2]
	mov	x2, #0
	add	x1, x29, #16
	add	x1, x1, x2
	str	x0, [x1]
	mov	x1, #8
	add	x0, x29, #16
	add	x0, x0, x1
	ldr	x1, [x0]
	mov	x2, #0
	add	x0, x29, #16
	add	x0, x0, x2
	ldr	x0, [x0]
	b	.L19
.L18:
	mov	x1, #8
	add	x0, x29, #32
	add	x0, x0, x1
	ldr	x1, [x0]
	mov	x2, #0
	add	x0, x29, #32
	add	x0, x0, x2
	ldr	x0, [x0]
.L19:
	ldp	x29, x30, [sp], 240
	ret
.type echo_mixed, @function
.size echo_mixed, .-echo_mixed
/* end function echo_mixed */

.text
.balign 16
.globl probe_mixed_direct
probe_mixed_direct:
	hint	#34
	stp	x29, x30, [sp, -48]!
	mov	x29, sp
	str	x19, [x29, 40]
	mov	x19, x1
	mov	x3, #91
	mov	w2, #2
	mov	x1, #8
	add	x1, x0, x1
	ldr	x1, [x1]
	mov	x4, #0
	add	x0, x0, x4
	ldr	x0, [x0]
	bl	echo_mixed
	mov	x3, #8
	add	x2, x29, #16
	add	x2, x2, x3
	str	x1, [x2]
	mov	x2, #0
	add	x1, x29, #16
	add	x1, x1, x2
	str	x0, [x1]
	add	x0, x29, #16
	ldrb	w0, [x0]
	strb	w0, [x19]
	mov	x2, #1
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #1
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #2
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #2
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #3
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #3
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #4
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #4
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #5
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #5
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #6
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #6
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #7
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #7
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #8
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #8
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #9
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #9
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #10
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #10
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #11
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #11
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #12
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #12
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #13
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #13
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #14
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #14
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #15
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #15
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	ldr	x19, [x29, 40]
	ldp	x29, x30, [sp], 48
	ret
.type probe_mixed_direct, @function
.size probe_mixed_direct, .-probe_mixed_direct
/* end function probe_mixed_direct */

.text
.balign 16
.globl probe_mixed_indirect
probe_mixed_indirect:
	hint	#34
	stp	x29, x30, [sp, -48]!
	mov	x29, sp
	str	x19, [x29, 40]
	mov	x19, x1
	mov	x3, #91
	mov	w2, #2
	mov	x1, #8
	add	x1, x0, x1
	ldr	x1, [x1]
	mov	x4, #0
	add	x0, x0, x4
	ldr	x0, [x0]
	bl	echo_mixed
	mov	x3, #8
	add	x2, x29, #16
	add	x2, x2, x3
	str	x1, [x2]
	mov	x2, #0
	add	x1, x29, #16
	add	x1, x1, x2
	str	x0, [x1]
	add	x0, x29, #16
	ldrb	w0, [x0]
	strb	w0, [x19]
	mov	x2, #1
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #1
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #2
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #2
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #3
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #3
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #4
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #4
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #5
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #5
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #6
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #6
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #7
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #7
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #8
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #8
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #9
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #9
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #10
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #10
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #11
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #11
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #12
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #12
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #13
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #13
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #14
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #14
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #15
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #15
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	ldr	x19, [x29, 40]
	ldp	x29, x30, [sp], 48
	ret
.type probe_mixed_indirect, @function
.size probe_mixed_indirect, .-probe_mixed_indirect
/* end function probe_mixed_indirect */

.text
.balign 16
echo_hidden:
	hint	#34
	str	q7, [sp, -16]!
	str	q6, [sp, -16]!
	str	q5, [sp, -16]!
	str	q4, [sp, -16]!
	str	q3, [sp, -16]!
	str	q2, [sp, -16]!
	str	q1, [sp, -16]!
	str	q0, [sp, -16]!
	stp	x6, x7, [sp, -16]!
	stp	x4, x5, [sp, -16]!
	stp	x2, x3, [sp, -16]!
	stp	x0, x1, [sp, -16]!
	stp	x29, x30, [sp, -96]!
	mov	x29, sp
	str	x19, [x29, 88]
	cmp	w1, #0
	beq	.L26
	mov	w2, #1
	sub	w1, w1, w2
	mov	x2, #0
	add	x2, x0, x2
	ldr	x2, [x2]
	mov	x4, #0
	add	x3, x29, #16
	add	x3, x3, x4
	str	x2, [x3]
	mov	x2, #8
	add	x2, x0, x2
	ldr	x2, [x2]
	mov	x4, #8
	add	x3, x29, #16
	add	x3, x3, x4
	str	x2, [x3]
	mov	x2, #16
	add	x2, x0, x2
	ldr	x2, [x2]
	mov	x4, #16
	add	x3, x29, #16
	add	x3, x3, x4
	str	x2, [x3]
	mov	x2, #24
	add	x0, x0, x2
	ldr	x0, [x0]
	mov	x3, #24
	add	x2, x29, #16
	add	x2, x2, x3
	str	x0, [x2]
	mov	x2, #91
	add	x0, x29, #16
	mov	x19, x8
	add	x8, x29, #48
	bl	echo_hidden
	mov	x8, x19
	mov	x1, #0
	add	x0, x29, #48
	add	x0, x0, x1
	ldr	x0, [x0]
	mov	x1, #0
	add	x1, x8, x1
	str	x0, [x1]
	mov	x1, #8
	add	x0, x29, #48
	add	x0, x0, x1
	ldr	x0, [x0]
	mov	x1, #8
	add	x1, x8, x1
	str	x0, [x1]
	mov	x1, #16
	add	x0, x29, #48
	add	x0, x0, x1
	ldr	x0, [x0]
	mov	x1, #16
	add	x1, x8, x1
	str	x0, [x1]
	mov	x1, #24
	add	x0, x29, #48
	add	x0, x0, x1
	ldr	x0, [x0]
	mov	x1, #24
	add	x1, x8, x1
	str	x0, [x1]
	b	.L27
.L26:
	mov	x1, #0
	add	x1, x0, x1
	ldr	x1, [x1]
	mov	x2, #0
	add	x2, x8, x2
	str	x1, [x2]
	mov	x1, #8
	add	x1, x0, x1
	ldr	x1, [x1]
	mov	x2, #8
	add	x2, x8, x2
	str	x1, [x2]
	mov	x1, #16
	add	x1, x0, x1
	ldr	x1, [x1]
	mov	x2, #16
	add	x2, x8, x2
	str	x1, [x2]
	mov	x1, #24
	add	x0, x0, x1
	ldr	x0, [x0]
	mov	x1, #24
	add	x1, x8, x1
	str	x0, [x1]
.L27:
	ldr	x19, [x29, 88]
	ldp	x29, x30, [sp], 288
	ret
.type echo_hidden, @function
.size echo_hidden, .-echo_hidden
/* end function echo_hidden */

.text
.balign 16
.globl probe_hidden_direct
probe_hidden_direct:
	hint	#34
	stp	x29, x30, [sp, -96]!
	mov	x29, sp
	str	x19, [x29, 88]
	mov	x19, x1
	mov	x1, #0
	add	x1, x0, x1
	ldr	x1, [x1]
	mov	x3, #0
	add	x2, x29, #16
	add	x2, x2, x3
	str	x1, [x2]
	mov	x1, #8
	add	x1, x0, x1
	ldr	x1, [x1]
	mov	x3, #8
	add	x2, x29, #16
	add	x2, x2, x3
	str	x1, [x2]
	mov	x1, #16
	add	x1, x0, x1
	ldr	x1, [x1]
	mov	x3, #16
	add	x2, x29, #16
	add	x2, x2, x3
	str	x1, [x2]
	mov	x1, #24
	add	x0, x0, x1
	ldr	x0, [x0]
	mov	x2, #24
	add	x1, x29, #16
	add	x1, x1, x2
	str	x0, [x1]
	mov	x2, #91
	mov	w1, #2
	add	x0, x29, #16
	add	x8, x29, #48
	bl	echo_hidden
	add	x0, x29, #48
	ldrb	w0, [x0]
	strb	w0, [x19]
	mov	x2, #1
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #1
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #2
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #2
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #3
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #3
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #4
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #4
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #5
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #5
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #6
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #6
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #7
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #7
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #8
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #8
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #9
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #9
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #10
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #10
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #11
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #11
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #12
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #12
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #13
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #13
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #14
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #14
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #15
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #15
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #16
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #16
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #17
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #17
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #18
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #18
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #19
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #19
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #20
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #20
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #21
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #21
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #22
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #22
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #23
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #23
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #24
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #24
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #25
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #25
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #26
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #26
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #27
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #27
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #28
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #28
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #29
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #29
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #30
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #30
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #31
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #31
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	ldr	x19, [x29, 88]
	ldp	x29, x30, [sp], 96
	ret
.type probe_hidden_direct, @function
.size probe_hidden_direct, .-probe_hidden_direct
/* end function probe_hidden_direct */

.text
.balign 16
.globl probe_hidden_indirect
probe_hidden_indirect:
	hint	#34
	stp	x29, x30, [sp, -96]!
	mov	x29, sp
	str	x19, [x29, 88]
	mov	x19, x1
	mov	x1, #0
	add	x1, x0, x1
	ldr	x1, [x1]
	mov	x3, #0
	add	x2, x29, #16
	add	x2, x2, x3
	str	x1, [x2]
	mov	x1, #8
	add	x1, x0, x1
	ldr	x1, [x1]
	mov	x3, #8
	add	x2, x29, #16
	add	x2, x2, x3
	str	x1, [x2]
	mov	x1, #16
	add	x1, x0, x1
	ldr	x1, [x1]
	mov	x3, #16
	add	x2, x29, #16
	add	x2, x2, x3
	str	x1, [x2]
	mov	x1, #24
	add	x0, x0, x1
	ldr	x0, [x0]
	mov	x2, #24
	add	x1, x29, #16
	add	x1, x1, x2
	str	x0, [x1]
	mov	x2, #91
	mov	w1, #2
	add	x0, x29, #16
	add	x8, x29, #48
	bl	echo_hidden
	add	x0, x29, #48
	ldrb	w0, [x0]
	strb	w0, [x19]
	mov	x2, #1
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #1
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #2
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #2
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #3
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #3
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #4
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #4
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #5
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #5
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #6
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #6
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #7
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #7
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #8
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #8
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #9
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #9
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #10
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #10
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #11
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #11
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #12
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #12
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #13
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #13
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #14
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #14
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #15
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #15
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #16
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #16
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #17
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #17
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #18
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #18
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #19
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #19
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #20
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #20
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #21
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #21
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #22
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #22
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #23
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #23
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #24
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #24
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #25
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #25
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #26
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #26
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #27
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #27
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #28
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #28
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #29
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #29
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #30
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #30
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #31
	add	x1, x29, #48
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #31
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	ldr	x19, [x29, 88]
	ldp	x29, x30, [sp], 96
	ret
.type probe_hidden_indirect, @function
.size probe_hidden_indirect, .-probe_hidden_indirect
/* end function probe_hidden_indirect */

.text
.balign 16
echo_union:
	hint	#34
	str	q7, [sp, -16]!
	str	q6, [sp, -16]!
	str	q5, [sp, -16]!
	str	q4, [sp, -16]!
	str	q3, [sp, -16]!
	str	q2, [sp, -16]!
	str	q1, [sp, -16]!
	str	q0, [sp, -16]!
	stp	x6, x7, [sp, -16]!
	stp	x4, x5, [sp, -16]!
	stp	x2, x3, [sp, -16]!
	stp	x0, x1, [sp, -16]!
	stp	x29, x30, [sp, -48]!
	mov	x29, sp
	mov	x4, #8
	add	x3, x29, #32
	add	x3, x3, x4
	str	x1, [x3]
	mov	x3, #0
	add	x1, x29, #32
	add	x1, x1, x3
	str	x0, [x1]
	cmp	w2, #0
	beq	.L34
	mov	w0, #1
	sub	w2, w2, w0
	mov	x3, #91
	mov	x1, #8
	add	x0, x29, #32
	add	x0, x0, x1
	ldr	x1, [x0]
	mov	x4, #0
	add	x0, x29, #32
	add	x0, x0, x4
	ldr	x0, [x0]
	bl	echo_union
	mov	x3, #8
	add	x2, x29, #16
	add	x2, x2, x3
	str	x1, [x2]
	mov	x2, #0
	add	x1, x29, #16
	add	x1, x1, x2
	str	x0, [x1]
	mov	x1, #8
	add	x0, x29, #16
	add	x0, x0, x1
	ldr	x1, [x0]
	mov	x2, #0
	add	x0, x29, #16
	add	x0, x0, x2
	ldr	x0, [x0]
	b	.L35
.L34:
	mov	x1, #8
	add	x0, x29, #32
	add	x0, x0, x1
	ldr	x1, [x0]
	mov	x2, #0
	add	x0, x29, #32
	add	x0, x0, x2
	ldr	x0, [x0]
.L35:
	ldp	x29, x30, [sp], 240
	ret
.type echo_union, @function
.size echo_union, .-echo_union
/* end function echo_union */

.text
.balign 16
.globl probe_union_direct
probe_union_direct:
	hint	#34
	stp	x29, x30, [sp, -48]!
	mov	x29, sp
	str	x19, [x29, 40]
	mov	x19, x1
	mov	x3, #91
	mov	w2, #2
	mov	x1, #8
	add	x1, x0, x1
	ldr	x1, [x1]
	mov	x4, #0
	add	x0, x0, x4
	ldr	x0, [x0]
	bl	echo_union
	mov	x3, #8
	add	x2, x29, #16
	add	x2, x2, x3
	str	x1, [x2]
	mov	x2, #0
	add	x1, x29, #16
	add	x1, x1, x2
	str	x0, [x1]
	add	x0, x29, #16
	ldrb	w0, [x0]
	strb	w0, [x19]
	mov	x2, #1
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #1
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #2
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #2
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #3
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #3
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #4
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #4
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #5
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #5
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #6
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #6
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #7
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #7
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #8
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #8
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #9
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #9
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #10
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #10
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #11
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #11
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #12
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #12
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #13
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #13
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #14
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #14
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #15
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #15
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	ldr	x19, [x29, 40]
	ldp	x29, x30, [sp], 48
	ret
.type probe_union_direct, @function
.size probe_union_direct, .-probe_union_direct
/* end function probe_union_direct */

.text
.balign 16
.globl probe_union_indirect
probe_union_indirect:
	hint	#34
	stp	x29, x30, [sp, -48]!
	mov	x29, sp
	str	x19, [x29, 40]
	mov	x19, x1
	mov	x3, #91
	mov	w2, #2
	mov	x1, #8
	add	x1, x0, x1
	ldr	x1, [x1]
	mov	x4, #0
	add	x0, x0, x4
	ldr	x0, [x0]
	bl	echo_union
	mov	x3, #8
	add	x2, x29, #16
	add	x2, x2, x3
	str	x1, [x2]
	mov	x2, #0
	add	x1, x29, #16
	add	x1, x1, x2
	str	x0, [x1]
	add	x0, x29, #16
	ldrb	w0, [x0]
	strb	w0, [x19]
	mov	x2, #1
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #1
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #2
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #2
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #3
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #3
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #4
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #4
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #5
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #5
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #6
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #6
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #7
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #7
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #8
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #8
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #9
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #9
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #10
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #10
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #11
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #11
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #12
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #12
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #13
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #13
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #14
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #14
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #15
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #15
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	ldr	x19, [x29, 40]
	ldp	x29, x30, [sp], 48
	ret
.type probe_union_indirect, @function
.size probe_union_indirect, .-probe_union_indirect
/* end function probe_union_indirect */

.text
.balign 16
echo_opaque:
	hint	#34
	str	q7, [sp, -16]!
	str	q6, [sp, -16]!
	str	q5, [sp, -16]!
	str	q4, [sp, -16]!
	str	q3, [sp, -16]!
	str	q2, [sp, -16]!
	str	q1, [sp, -16]!
	str	q0, [sp, -16]!
	stp	x6, x7, [sp, -16]!
	stp	x4, x5, [sp, -16]!
	stp	x2, x3, [sp, -16]!
	stp	x0, x1, [sp, -16]!
	stp	x29, x30, [sp, -80]!
	mov	x29, sp
	str	x19, [x29, 72]
	cmp	w1, #0
	beq	.L42
	mov	w2, #1
	sub	w1, w1, w2
	mov	x2, #0
	add	x2, x0, x2
	ldr	x2, [x2]
	mov	x4, #0
	add	x3, x29, #16
	add	x3, x3, x4
	str	x2, [x3]
	mov	x2, #8
	add	x2, x0, x2
	ldr	x2, [x2]
	mov	x4, #8
	add	x3, x29, #16
	add	x3, x3, x4
	str	x2, [x3]
	mov	x2, #16
	add	x0, x0, x2
	ldr	x0, [x0]
	mov	x3, #16
	add	x2, x29, #16
	add	x2, x2, x3
	str	x0, [x2]
	mov	x2, #91
	add	x0, x29, #16
	mov	x19, x8
	add	x8, x29, #40
	bl	echo_opaque
	mov	x8, x19
	mov	x1, #0
	add	x0, x29, #40
	add	x0, x0, x1
	ldr	x0, [x0]
	mov	x1, #0
	add	x1, x8, x1
	str	x0, [x1]
	mov	x1, #8
	add	x0, x29, #40
	add	x0, x0, x1
	ldr	x0, [x0]
	mov	x1, #8
	add	x1, x8, x1
	str	x0, [x1]
	mov	x1, #16
	add	x0, x29, #40
	add	x0, x0, x1
	ldr	x0, [x0]
	mov	x1, #16
	add	x1, x8, x1
	str	x0, [x1]
	b	.L43
.L42:
	mov	x1, #0
	add	x1, x0, x1
	ldr	x1, [x1]
	mov	x2, #0
	add	x2, x8, x2
	str	x1, [x2]
	mov	x1, #8
	add	x1, x0, x1
	ldr	x1, [x1]
	mov	x2, #8
	add	x2, x8, x2
	str	x1, [x2]
	mov	x1, #16
	add	x0, x0, x1
	ldr	x0, [x0]
	mov	x1, #16
	add	x1, x8, x1
	str	x0, [x1]
.L43:
	ldr	x19, [x29, 72]
	ldp	x29, x30, [sp], 272
	ret
.type echo_opaque, @function
.size echo_opaque, .-echo_opaque
/* end function echo_opaque */

.text
.balign 16
.globl probe_opaque_direct
probe_opaque_direct:
	hint	#34
	stp	x29, x30, [sp, -80]!
	mov	x29, sp
	str	x19, [x29, 72]
	mov	x19, x1
	mov	x1, #0
	add	x1, x0, x1
	ldr	x1, [x1]
	mov	x3, #0
	add	x2, x29, #16
	add	x2, x2, x3
	str	x1, [x2]
	mov	x1, #8
	add	x1, x0, x1
	ldr	x1, [x1]
	mov	x3, #8
	add	x2, x29, #16
	add	x2, x2, x3
	str	x1, [x2]
	mov	x1, #16
	add	x0, x0, x1
	ldr	x0, [x0]
	mov	x2, #16
	add	x1, x29, #16
	add	x1, x1, x2
	str	x0, [x1]
	mov	x2, #91
	mov	w1, #2
	add	x0, x29, #16
	add	x8, x29, #40
	bl	echo_opaque
	add	x0, x29, #40
	ldrb	w0, [x0]
	strb	w0, [x19]
	mov	x2, #1
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #1
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #2
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #2
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #3
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #3
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #4
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #4
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #5
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #5
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #6
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #6
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #7
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #7
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #8
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #8
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #9
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #9
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #10
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #10
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #11
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #11
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #12
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #12
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #13
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #13
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #14
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #14
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #15
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #15
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #16
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #16
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #17
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #17
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #18
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #18
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #19
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #19
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #20
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #20
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #21
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #21
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #22
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #22
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #23
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #23
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	ldr	x19, [x29, 72]
	ldp	x29, x30, [sp], 80
	ret
.type probe_opaque_direct, @function
.size probe_opaque_direct, .-probe_opaque_direct
/* end function probe_opaque_direct */

.text
.balign 16
.globl probe_opaque_indirect
probe_opaque_indirect:
	hint	#34
	stp	x29, x30, [sp, -80]!
	mov	x29, sp
	str	x19, [x29, 72]
	mov	x19, x1
	mov	x1, #0
	add	x1, x0, x1
	ldr	x1, [x1]
	mov	x3, #0
	add	x2, x29, #16
	add	x2, x2, x3
	str	x1, [x2]
	mov	x1, #8
	add	x1, x0, x1
	ldr	x1, [x1]
	mov	x3, #8
	add	x2, x29, #16
	add	x2, x2, x3
	str	x1, [x2]
	mov	x1, #16
	add	x0, x0, x1
	ldr	x0, [x0]
	mov	x2, #16
	add	x1, x29, #16
	add	x1, x1, x2
	str	x0, [x1]
	mov	x2, #91
	mov	w1, #2
	add	x0, x29, #16
	add	x8, x29, #40
	bl	echo_opaque
	add	x0, x29, #40
	ldrb	w0, [x0]
	strb	w0, [x19]
	mov	x2, #1
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #1
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #2
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #2
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #3
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #3
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #4
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #4
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #5
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #5
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #6
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #6
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #7
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #7
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #8
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #8
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #9
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #9
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #10
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #10
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #11
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #11
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #12
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #12
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #13
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #13
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #14
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #14
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #15
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #15
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #16
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #16
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #17
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #17
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #18
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #18
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #19
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #19
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #20
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #20
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #21
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #21
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #22
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #22
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #23
	add	x1, x29, #40
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #23
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	ldr	x19, [x29, 72]
	ldp	x29, x30, [sp], 80
	ret
.type probe_opaque_indirect, @function
.size probe_opaque_indirect, .-probe_opaque_indirect
/* end function probe_opaque_indirect */

.text
.balign 16
echo_nested:
	hint	#34
	str	q7, [sp, -16]!
	str	q6, [sp, -16]!
	str	q5, [sp, -16]!
	str	q4, [sp, -16]!
	str	q3, [sp, -16]!
	str	q2, [sp, -16]!
	str	q1, [sp, -16]!
	str	q0, [sp, -16]!
	stp	x6, x7, [sp, -16]!
	stp	x4, x5, [sp, -16]!
	stp	x2, x3, [sp, -16]!
	stp	x0, x1, [sp, -16]!
	stp	x29, x30, [sp, -48]!
	mov	x29, sp
	mov	x4, #8
	add	x3, x29, #32
	add	x3, x3, x4
	str	x1, [x3]
	mov	x3, #0
	add	x1, x29, #32
	add	x1, x1, x3
	str	x0, [x1]
	cmp	w2, #0
	beq	.L50
	mov	w0, #1
	sub	w2, w2, w0
	mov	x3, #91
	mov	x1, #8
	add	x0, x29, #32
	add	x0, x0, x1
	ldr	x1, [x0]
	mov	x4, #0
	add	x0, x29, #32
	add	x0, x0, x4
	ldr	x0, [x0]
	bl	echo_nested
	mov	x3, #8
	add	x2, x29, #16
	add	x2, x2, x3
	str	x1, [x2]
	mov	x2, #0
	add	x1, x29, #16
	add	x1, x1, x2
	str	x0, [x1]
	mov	x1, #8
	add	x0, x29, #16
	add	x0, x0, x1
	ldr	x1, [x0]
	mov	x2, #0
	add	x0, x29, #16
	add	x0, x0, x2
	ldr	x0, [x0]
	b	.L51
.L50:
	mov	x1, #8
	add	x0, x29, #32
	add	x0, x0, x1
	ldr	x1, [x0]
	mov	x2, #0
	add	x0, x29, #32
	add	x0, x0, x2
	ldr	x0, [x0]
.L51:
	ldp	x29, x30, [sp], 240
	ret
.type echo_nested, @function
.size echo_nested, .-echo_nested
/* end function echo_nested */

.text
.balign 16
.globl probe_nested_direct
probe_nested_direct:
	hint	#34
	stp	x29, x30, [sp, -48]!
	mov	x29, sp
	str	x19, [x29, 40]
	mov	x19, x1
	mov	x3, #91
	mov	w2, #2
	mov	x1, #8
	add	x1, x0, x1
	ldr	x1, [x1]
	mov	x4, #0
	add	x0, x0, x4
	ldr	x0, [x0]
	bl	echo_nested
	mov	x3, #8
	add	x2, x29, #16
	add	x2, x2, x3
	str	x1, [x2]
	mov	x2, #0
	add	x1, x29, #16
	add	x1, x1, x2
	str	x0, [x1]
	add	x0, x29, #16
	ldrb	w0, [x0]
	strb	w0, [x19]
	mov	x2, #1
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #1
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #2
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #2
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #3
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #3
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #4
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #4
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #5
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #5
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #6
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #6
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #7
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #7
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #8
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #8
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #9
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #9
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #10
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #10
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #11
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #11
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #12
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #12
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #13
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #13
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #14
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #14
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #15
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #15
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	ldr	x19, [x29, 40]
	ldp	x29, x30, [sp], 48
	ret
.type probe_nested_direct, @function
.size probe_nested_direct, .-probe_nested_direct
/* end function probe_nested_direct */

.text
.balign 16
.globl probe_nested_indirect
probe_nested_indirect:
	hint	#34
	stp	x29, x30, [sp, -48]!
	mov	x29, sp
	str	x19, [x29, 40]
	mov	x19, x1
	mov	x3, #91
	mov	w2, #2
	mov	x1, #8
	add	x1, x0, x1
	ldr	x1, [x1]
	mov	x4, #0
	add	x0, x0, x4
	ldr	x0, [x0]
	bl	echo_nested
	mov	x3, #8
	add	x2, x29, #16
	add	x2, x2, x3
	str	x1, [x2]
	mov	x2, #0
	add	x1, x29, #16
	add	x1, x1, x2
	str	x0, [x1]
	add	x0, x29, #16
	ldrb	w0, [x0]
	strb	w0, [x19]
	mov	x2, #1
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #1
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #2
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #2
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #3
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #3
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #4
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #4
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #5
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #5
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #6
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #6
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #7
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #7
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #8
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #8
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #9
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #9
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #10
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #10
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #11
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #11
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #12
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #12
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #13
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #13
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #14
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #14
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	mov	x2, #15
	add	x1, x29, #16
	add	x1, x1, x2
	ldrb	w1, [x1]
	mov	x2, #15
	add	x2, x19, x2
	strb	w1, [x2]
	add	x0, x0, x1
	ldr	x19, [x29, 40]
	ldp	x29, x30, [sp], 48
	ret
.type probe_nested_indirect, @function
.size probe_nested_indirect, .-probe_nested_indirect
/* end function probe_nested_indirect */

.text
.balign 16
.globl interpreted
interpreted:
	hint	#34
	stp	x29, x30, [sp, -64]!
	mov	x29, sp
	add	x1, x29, #16
	mov	x0, #1800
	movk	x0, #0x506, lsl #16
	movk	x0, #0x304, lsl #32
	movk	x0, #0x102, lsl #48
	str	x0, [x1]
	mov	x1, #8
	add	x0, x29, #16
	add	x1, x0, x1
	mov	x0, #1800
	movk	x0, #0x506, lsl #16
	movk	x0, #0x304, lsl #32
	movk	x0, #0x102, lsl #48
	str	x0, [x1]
	add	x1, x29, #48
	add	x0, x29, #16
	bl	probe_nested_indirect
	ldp	x29, x30, [sp], 64
	ret
.type interpreted, @function
.size interpreted, .-interpreted
/* end function interpreted */

.section .note.GNU-stack,"",@progbits
