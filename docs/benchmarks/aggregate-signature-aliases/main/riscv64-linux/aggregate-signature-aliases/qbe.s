.text
.balign 16
echo_integer:
	add sp, sp, -64
	sd a0, 0(sp)
	sd a1, 8(sp)
	sd a2, 16(sp)
	sd a3, 24(sp)
	sd a4, 32(sp)
	sd a5, 40(sp)
	sd a6, 48(sp)
	sd a7, 56(sp)
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -48
	add t0, fp, -16
	add t0, t0, 8
	sd a1, 0(t0)
	add t0, fp, -16
	add t0, t0, 0
	sd a0, 0(t0)
	xor t0, a2, 0
	seqz t0, t0
	bnez t0, .L2
	li t0, 1
	subw a2, a2, t0
	li a3, 91
	add t0, fp, -16
	add t0, t0, 8
	ld a1, 0(t0)
	add t0, fp, -16
	add t0, t0, 0
	ld a0, 0(t0)
	call echo_integer
	mv t1, a1
	mv t0, a0
	add t2, fp, -32
	add t2, t2, 8
	sd t1, 0(t2)
	add t1, fp, -32
	add t1, t1, 0
	sd t0, 0(t1)
	add t0, fp, -32
	add t0, t0, 8
	ld a1, 0(t0)
	add t0, fp, -32
	add t0, t0, 0
	ld a0, 0(t0)
	j .L3
.L2:
	add t0, fp, -16
	add t0, t0, 8
	ld a1, 0(t0)
	add t0, fp, -16
	add t0, t0, 0
	ld a0, 0(t0)
.L3:
	add sp, fp, 80
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type echo_integer, @function
.size echo_integer, .-echo_integer
/* end function echo_integer */

.text
.balign 16
.globl probe_integer_direct
probe_integer_direct:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -48
	sd s1, 0(sp)
	li a3, 91
	li a2, 2
	add t0, a0, 8
	mv s1, a1
	ld a1, 0(t0)
	add t0, a0, 0
	ld a0, 0(t0)
	call echo_integer
	mv t1, a1
	mv a1, s1
	mv t0, a0
	add t2, fp, -16
	add t2, t2, 8
	sd t1, 0(t2)
	add t1, fp, -16
	add t1, t1, 0
	sd t0, 0(t1)
	lbu t0, -16(fp)
	sext.w t1, t0
	sb t1, 0(a1)
	add t1, fp, -16
	add t1, t1, 1
	lbu t1, 0(t1)
	add t3, a1, 1
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 2
	lbu t1, 0(t1)
	add t3, a1, 2
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 3
	lbu t1, 0(t1)
	add t3, a1, 3
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 4
	lbu t1, 0(t1)
	add t3, a1, 4
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 5
	lbu t1, 0(t1)
	add t3, a1, 5
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 6
	lbu t1, 0(t1)
	add t3, a1, 6
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 7
	lbu t1, 0(t1)
	add t3, a1, 7
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 8
	lbu t1, 0(t1)
	add t3, a1, 8
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 9
	lbu t1, 0(t1)
	add t3, a1, 9
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 10
	lbu t1, 0(t1)
	add t3, a1, 10
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 11
	lbu t1, 0(t1)
	add t3, a1, 11
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 12
	lbu t1, 0(t1)
	add t3, a1, 12
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 13
	lbu t1, 0(t1)
	add t3, a1, 13
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 14
	lbu t1, 0(t1)
	add t3, a1, 14
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 15
	lbu t1, 0(t1)
	add t3, a1, 15
	sext.w t2, t1
	sb t2, 0(t3)
	add a0, t0, t1
	ld s1, 0(sp)
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type probe_integer_direct, @function
.size probe_integer_direct, .-probe_integer_direct
/* end function probe_integer_direct */

.text
.balign 16
.globl probe_integer_indirect
probe_integer_indirect:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -48
	sd s1, 0(sp)
	li a3, 91
	li a2, 2
	add t0, a0, 8
	mv s1, a1
	ld a1, 0(t0)
	add t0, a0, 0
	ld a0, 0(t0)
	call echo_integer
	mv t1, a1
	mv a1, s1
	mv t0, a0
	add t2, fp, -16
	add t2, t2, 8
	sd t1, 0(t2)
	add t1, fp, -16
	add t1, t1, 0
	sd t0, 0(t1)
	lbu t0, -16(fp)
	sext.w t1, t0
	sb t1, 0(a1)
	add t1, fp, -16
	add t1, t1, 1
	lbu t1, 0(t1)
	add t3, a1, 1
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 2
	lbu t1, 0(t1)
	add t3, a1, 2
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 3
	lbu t1, 0(t1)
	add t3, a1, 3
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 4
	lbu t1, 0(t1)
	add t3, a1, 4
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 5
	lbu t1, 0(t1)
	add t3, a1, 5
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 6
	lbu t1, 0(t1)
	add t3, a1, 6
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 7
	lbu t1, 0(t1)
	add t3, a1, 7
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 8
	lbu t1, 0(t1)
	add t3, a1, 8
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 9
	lbu t1, 0(t1)
	add t3, a1, 9
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 10
	lbu t1, 0(t1)
	add t3, a1, 10
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 11
	lbu t1, 0(t1)
	add t3, a1, 11
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 12
	lbu t1, 0(t1)
	add t3, a1, 12
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 13
	lbu t1, 0(t1)
	add t3, a1, 13
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 14
	lbu t1, 0(t1)
	add t3, a1, 14
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 15
	lbu t1, 0(t1)
	add t3, a1, 15
	sext.w t2, t1
	sb t2, 0(t3)
	add a0, t0, t1
	ld s1, 0(sp)
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type probe_integer_indirect, @function
.size probe_integer_indirect, .-probe_integer_indirect
/* end function probe_integer_indirect */

.text
.balign 16
echo_floating:
	add sp, sp, -64
	sd a0, 0(sp)
	sd a1, 8(sp)
	sd a2, 16(sp)
	sd a3, 24(sp)
	sd a4, 32(sp)
	sd a5, 40(sp)
	sd a6, 48(sp)
	sd a7, 56(sp)
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -48
	add t0, fp, -16
	add t0, t0, 8
	fsd fa1, 0(t0)
	add t0, fp, -16
	add t0, t0, 0
	fsd fa0, 0(t0)
	xor t0, a0, 0
	seqz t0, t0
	bnez t0, .L10
	li t0, 1
	subw a0, a0, t0
	li a1, 91
	add t0, fp, -16
	add t0, t0, 8
	fld fa1, 0(t0)
	add t0, fp, -16
	add t0, t0, 0
	fld fa0, 0(t0)
	call echo_floating
	fmv.d ft1, fa1
	fmv.d ft0, fa0
	add t0, fp, -32
	add t0, t0, 8
	fsd ft1, 0(t0)
	add t0, fp, -32
	add t0, t0, 0
	fsd ft0, 0(t0)
	add t0, fp, -32
	add t0, t0, 8
	fld fa1, 0(t0)
	add t0, fp, -32
	add t0, t0, 0
	fld fa0, 0(t0)
	j .L11
.L10:
	add t0, fp, -16
	add t0, t0, 8
	fld fa1, 0(t0)
	add t0, fp, -16
	add t0, t0, 0
	fld fa0, 0(t0)
.L11:
	add sp, fp, 80
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type echo_floating, @function
.size echo_floating, .-echo_floating
/* end function echo_floating */

.text
.balign 16
.globl probe_floating_direct
probe_floating_direct:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -48
	sd s1, 0(sp)
	mv t0, a0
	mv s1, a1
	li a1, 91
	li a0, 2
	add t1, t0, 8
	fld fa1, 0(t1)
	add t0, t0, 0
	fld fa0, 0(t0)
	call echo_floating
	mv a1, s1
	fmv.d ft1, fa1
	fmv.d ft0, fa0
	add t0, fp, -16
	add t0, t0, 8
	fsd ft1, 0(t0)
	add t0, fp, -16
	add t0, t0, 0
	fsd ft0, 0(t0)
	lbu t0, -16(fp)
	sext.w t1, t0
	sb t1, 0(a1)
	add t1, fp, -16
	add t1, t1, 1
	lbu t1, 0(t1)
	add t3, a1, 1
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 2
	lbu t1, 0(t1)
	add t3, a1, 2
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 3
	lbu t1, 0(t1)
	add t3, a1, 3
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 4
	lbu t1, 0(t1)
	add t3, a1, 4
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 5
	lbu t1, 0(t1)
	add t3, a1, 5
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 6
	lbu t1, 0(t1)
	add t3, a1, 6
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 7
	lbu t1, 0(t1)
	add t3, a1, 7
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 8
	lbu t1, 0(t1)
	add t3, a1, 8
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 9
	lbu t1, 0(t1)
	add t3, a1, 9
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 10
	lbu t1, 0(t1)
	add t3, a1, 10
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 11
	lbu t1, 0(t1)
	add t3, a1, 11
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 12
	lbu t1, 0(t1)
	add t3, a1, 12
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 13
	lbu t1, 0(t1)
	add t3, a1, 13
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 14
	lbu t1, 0(t1)
	add t3, a1, 14
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 15
	lbu t1, 0(t1)
	add t3, a1, 15
	sext.w t2, t1
	sb t2, 0(t3)
	add a0, t0, t1
	ld s1, 0(sp)
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type probe_floating_direct, @function
.size probe_floating_direct, .-probe_floating_direct
/* end function probe_floating_direct */

.text
.balign 16
.globl probe_floating_indirect
probe_floating_indirect:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -48
	sd s1, 0(sp)
	mv t0, a0
	mv s1, a1
	li a1, 91
	li a0, 2
	add t1, t0, 8
	fld fa1, 0(t1)
	add t0, t0, 0
	fld fa0, 0(t0)
	call echo_floating
	mv a1, s1
	fmv.d ft1, fa1
	fmv.d ft0, fa0
	add t0, fp, -16
	add t0, t0, 8
	fsd ft1, 0(t0)
	add t0, fp, -16
	add t0, t0, 0
	fsd ft0, 0(t0)
	lbu t0, -16(fp)
	sext.w t1, t0
	sb t1, 0(a1)
	add t1, fp, -16
	add t1, t1, 1
	lbu t1, 0(t1)
	add t3, a1, 1
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 2
	lbu t1, 0(t1)
	add t3, a1, 2
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 3
	lbu t1, 0(t1)
	add t3, a1, 3
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 4
	lbu t1, 0(t1)
	add t3, a1, 4
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 5
	lbu t1, 0(t1)
	add t3, a1, 5
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 6
	lbu t1, 0(t1)
	add t3, a1, 6
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 7
	lbu t1, 0(t1)
	add t3, a1, 7
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 8
	lbu t1, 0(t1)
	add t3, a1, 8
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 9
	lbu t1, 0(t1)
	add t3, a1, 9
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 10
	lbu t1, 0(t1)
	add t3, a1, 10
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 11
	lbu t1, 0(t1)
	add t3, a1, 11
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 12
	lbu t1, 0(t1)
	add t3, a1, 12
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 13
	lbu t1, 0(t1)
	add t3, a1, 13
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 14
	lbu t1, 0(t1)
	add t3, a1, 14
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 15
	lbu t1, 0(t1)
	add t3, a1, 15
	sext.w t2, t1
	sb t2, 0(t3)
	add a0, t0, t1
	ld s1, 0(sp)
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type probe_floating_indirect, @function
.size probe_floating_indirect, .-probe_floating_indirect
/* end function probe_floating_indirect */

.text
.balign 16
echo_mixed:
	add sp, sp, -64
	sd a0, 0(sp)
	sd a1, 8(sp)
	sd a2, 16(sp)
	sd a3, 24(sp)
	sd a4, 32(sp)
	sd a5, 40(sp)
	sd a6, 48(sp)
	sd a7, 56(sp)
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -48
	add t0, fp, -16
	add t0, t0, 8
	sd a0, 0(t0)
	add t0, fp, -16
	add t0, t0, 0
	fsd fa0, 0(t0)
	xor t0, a1, 0
	seqz t0, t0
	bnez t0, .L18
	li t0, 1
	subw a1, a1, t0
	li a2, 91
	add t0, fp, -16
	add t0, t0, 8
	ld a0, 0(t0)
	add t0, fp, -16
	add t0, t0, 0
	fld fa0, 0(t0)
	call echo_mixed
	mv t0, a0
	fmv.d ft0, fa0
	add t1, fp, -32
	add t1, t1, 8
	sd t0, 0(t1)
	add t0, fp, -32
	add t0, t0, 0
	fsd ft0, 0(t0)
	add t0, fp, -32
	add t0, t0, 8
	ld a0, 0(t0)
	add t0, fp, -32
	add t0, t0, 0
	fld fa0, 0(t0)
	j .L19
.L18:
	add t0, fp, -16
	add t0, t0, 8
	ld a0, 0(t0)
	add t0, fp, -16
	add t0, t0, 0
	fld fa0, 0(t0)
.L19:
	add sp, fp, 80
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type echo_mixed, @function
.size echo_mixed, .-echo_mixed
/* end function echo_mixed */

.text
.balign 16
.globl probe_mixed_direct
probe_mixed_direct:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -48
	sd s1, 0(sp)
	mv t0, a0
	li a2, 91
	mv s1, a1
	li a1, 2
	add t1, t0, 8
	ld a0, 0(t1)
	add t0, t0, 0
	fld fa0, 0(t0)
	call echo_mixed
	mv a1, s1
	mv t0, a0
	fmv.d ft0, fa0
	add t1, fp, -16
	add t1, t1, 8
	sd t0, 0(t1)
	add t0, fp, -16
	add t0, t0, 0
	fsd ft0, 0(t0)
	lbu t0, -16(fp)
	sext.w t1, t0
	sb t1, 0(a1)
	add t1, fp, -16
	add t1, t1, 1
	lbu t1, 0(t1)
	add t3, a1, 1
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 2
	lbu t1, 0(t1)
	add t3, a1, 2
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 3
	lbu t1, 0(t1)
	add t3, a1, 3
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 4
	lbu t1, 0(t1)
	add t3, a1, 4
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 5
	lbu t1, 0(t1)
	add t3, a1, 5
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 6
	lbu t1, 0(t1)
	add t3, a1, 6
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 7
	lbu t1, 0(t1)
	add t3, a1, 7
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 8
	lbu t1, 0(t1)
	add t3, a1, 8
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 9
	lbu t1, 0(t1)
	add t3, a1, 9
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 10
	lbu t1, 0(t1)
	add t3, a1, 10
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 11
	lbu t1, 0(t1)
	add t3, a1, 11
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 12
	lbu t1, 0(t1)
	add t3, a1, 12
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 13
	lbu t1, 0(t1)
	add t3, a1, 13
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 14
	lbu t1, 0(t1)
	add t3, a1, 14
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 15
	lbu t1, 0(t1)
	add t3, a1, 15
	sext.w t2, t1
	sb t2, 0(t3)
	add a0, t0, t1
	ld s1, 0(sp)
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type probe_mixed_direct, @function
.size probe_mixed_direct, .-probe_mixed_direct
/* end function probe_mixed_direct */

.text
.balign 16
.globl probe_mixed_indirect
probe_mixed_indirect:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -48
	sd s1, 0(sp)
	mv t0, a0
	li a2, 91
	mv s1, a1
	li a1, 2
	add t1, t0, 8
	ld a0, 0(t1)
	add t0, t0, 0
	fld fa0, 0(t0)
	call echo_mixed
	mv a1, s1
	mv t0, a0
	fmv.d ft0, fa0
	add t1, fp, -16
	add t1, t1, 8
	sd t0, 0(t1)
	add t0, fp, -16
	add t0, t0, 0
	fsd ft0, 0(t0)
	lbu t0, -16(fp)
	sext.w t1, t0
	sb t1, 0(a1)
	add t1, fp, -16
	add t1, t1, 1
	lbu t1, 0(t1)
	add t3, a1, 1
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 2
	lbu t1, 0(t1)
	add t3, a1, 2
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 3
	lbu t1, 0(t1)
	add t3, a1, 3
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 4
	lbu t1, 0(t1)
	add t3, a1, 4
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 5
	lbu t1, 0(t1)
	add t3, a1, 5
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 6
	lbu t1, 0(t1)
	add t3, a1, 6
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 7
	lbu t1, 0(t1)
	add t3, a1, 7
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 8
	lbu t1, 0(t1)
	add t3, a1, 8
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 9
	lbu t1, 0(t1)
	add t3, a1, 9
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 10
	lbu t1, 0(t1)
	add t3, a1, 10
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 11
	lbu t1, 0(t1)
	add t3, a1, 11
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 12
	lbu t1, 0(t1)
	add t3, a1, 12
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 13
	lbu t1, 0(t1)
	add t3, a1, 13
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 14
	lbu t1, 0(t1)
	add t3, a1, 14
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 15
	lbu t1, 0(t1)
	add t3, a1, 15
	sext.w t2, t1
	sb t2, 0(t3)
	add a0, t0, t1
	ld s1, 0(sp)
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type probe_mixed_indirect, @function
.size probe_mixed_indirect, .-probe_mixed_indirect
/* end function probe_mixed_indirect */

.text
.balign 16
echo_hidden:
	add sp, sp, -64
	sd a0, 0(sp)
	sd a1, 8(sp)
	sd a2, 16(sp)
	sd a3, 24(sp)
	sd a4, 32(sp)
	sd a5, 40(sp)
	sd a6, 48(sp)
	sd a7, 56(sp)
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -96
	sd s1, 0(sp)
	xor t0, a2, 0
	seqz t0, t0
	bnez t0, .L26
	li t0, 1
	subw a2, a2, t0
	add t0, a1, 0
	ld t0, 0(t0)
	add t1, fp, -64
	add t1, t1, 0
	sd t0, 0(t1)
	add t0, a1, 8
	ld t0, 0(t0)
	add t1, fp, -64
	add t1, t1, 8
	sd t0, 0(t1)
	add t0, a1, 16
	ld t0, 0(t0)
	add t1, fp, -64
	add t1, t1, 16
	sd t0, 0(t1)
	add t0, a1, 24
	ld t0, 0(t0)
	add t1, fp, -64
	add t1, t1, 24
	sd t0, 0(t1)
	li a3, 91
	add a1, fp, -64
	mv s1, a0
	add a0, fp, -32
	call echo_hidden
	mv a0, s1
	add t0, fp, -32
	add t0, t0, 0
	ld t0, 0(t0)
	add t1, a0, 0
	sd t0, 0(t1)
	add t0, fp, -32
	add t0, t0, 8
	ld t0, 0(t0)
	add t1, a0, 8
	sd t0, 0(t1)
	add t0, fp, -32
	add t0, t0, 16
	ld t0, 0(t0)
	add t1, a0, 16
	sd t0, 0(t1)
	add t0, fp, -32
	add t0, t0, 24
	ld t0, 0(t0)
	add t1, a0, 24
	sd t0, 0(t1)
	j .L27
.L26:
	add t0, a1, 0
	ld t0, 0(t0)
	add t1, a0, 0
	sd t0, 0(t1)
	add t0, a1, 8
	ld t0, 0(t0)
	add t1, a0, 8
	sd t0, 0(t1)
	add t0, a1, 16
	ld t0, 0(t0)
	add t1, a0, 16
	sd t0, 0(t1)
	add t0, a1, 24
	ld t0, 0(t0)
	add t1, a0, 24
	sd t0, 0(t1)
.L27:
	ld s1, 0(sp)
	add sp, fp, 80
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type echo_hidden, @function
.size echo_hidden, .-echo_hidden
/* end function echo_hidden */

.text
.balign 16
.globl probe_hidden_direct
probe_hidden_direct:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -96
	sd s1, 0(sp)
	add t0, a0, 0
	ld t0, 0(t0)
	add t1, fp, -64
	add t1, t1, 0
	sd t0, 0(t1)
	add t0, a0, 8
	ld t0, 0(t0)
	add t1, fp, -64
	add t1, t1, 8
	sd t0, 0(t1)
	add t0, a0, 16
	ld t0, 0(t0)
	add t1, fp, -64
	add t1, t1, 16
	sd t0, 0(t1)
	add t0, a0, 24
	ld t0, 0(t0)
	add t1, fp, -64
	add t1, t1, 24
	sd t0, 0(t1)
	li a3, 91
	li a2, 2
	mv s1, a1
	add a1, fp, -64
	add a0, fp, -32
	call echo_hidden
	mv a1, s1
	lbu t0, -32(fp)
	sext.w t1, t0
	sb t1, 0(a1)
	add t1, fp, -32
	add t1, t1, 1
	lbu t1, 0(t1)
	add t3, a1, 1
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 2
	lbu t1, 0(t1)
	add t3, a1, 2
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 3
	lbu t1, 0(t1)
	add t3, a1, 3
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 4
	lbu t1, 0(t1)
	add t3, a1, 4
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 5
	lbu t1, 0(t1)
	add t3, a1, 5
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 6
	lbu t1, 0(t1)
	add t3, a1, 6
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 7
	lbu t1, 0(t1)
	add t3, a1, 7
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 8
	lbu t1, 0(t1)
	add t3, a1, 8
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 9
	lbu t1, 0(t1)
	add t3, a1, 9
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 10
	lbu t1, 0(t1)
	add t3, a1, 10
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 11
	lbu t1, 0(t1)
	add t3, a1, 11
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 12
	lbu t1, 0(t1)
	add t3, a1, 12
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 13
	lbu t1, 0(t1)
	add t3, a1, 13
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 14
	lbu t1, 0(t1)
	add t3, a1, 14
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 15
	lbu t1, 0(t1)
	add t3, a1, 15
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 16
	lbu t1, 0(t1)
	add t3, a1, 16
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 17
	lbu t1, 0(t1)
	add t3, a1, 17
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 18
	lbu t1, 0(t1)
	add t3, a1, 18
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 19
	lbu t1, 0(t1)
	add t3, a1, 19
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 20
	lbu t1, 0(t1)
	add t3, a1, 20
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 21
	lbu t1, 0(t1)
	add t3, a1, 21
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 22
	lbu t1, 0(t1)
	add t3, a1, 22
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 23
	lbu t1, 0(t1)
	add t3, a1, 23
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 24
	lbu t1, 0(t1)
	add t3, a1, 24
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 25
	lbu t1, 0(t1)
	add t3, a1, 25
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 26
	lbu t1, 0(t1)
	add t3, a1, 26
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 27
	lbu t1, 0(t1)
	add t3, a1, 27
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 28
	lbu t1, 0(t1)
	add t3, a1, 28
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 29
	lbu t1, 0(t1)
	add t3, a1, 29
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 30
	lbu t1, 0(t1)
	add t3, a1, 30
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 31
	lbu t1, 0(t1)
	add t3, a1, 31
	sext.w t2, t1
	sb t2, 0(t3)
	add a0, t0, t1
	ld s1, 0(sp)
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type probe_hidden_direct, @function
.size probe_hidden_direct, .-probe_hidden_direct
/* end function probe_hidden_direct */

.text
.balign 16
.globl probe_hidden_indirect
probe_hidden_indirect:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -96
	sd s1, 0(sp)
	add t0, a0, 0
	ld t0, 0(t0)
	add t1, fp, -64
	add t1, t1, 0
	sd t0, 0(t1)
	add t0, a0, 8
	ld t0, 0(t0)
	add t1, fp, -64
	add t1, t1, 8
	sd t0, 0(t1)
	add t0, a0, 16
	ld t0, 0(t0)
	add t1, fp, -64
	add t1, t1, 16
	sd t0, 0(t1)
	add t0, a0, 24
	ld t0, 0(t0)
	add t1, fp, -64
	add t1, t1, 24
	sd t0, 0(t1)
	li a3, 91
	li a2, 2
	mv s1, a1
	add a1, fp, -64
	add a0, fp, -32
	call echo_hidden
	mv a1, s1
	lbu t0, -32(fp)
	sext.w t1, t0
	sb t1, 0(a1)
	add t1, fp, -32
	add t1, t1, 1
	lbu t1, 0(t1)
	add t3, a1, 1
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 2
	lbu t1, 0(t1)
	add t3, a1, 2
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 3
	lbu t1, 0(t1)
	add t3, a1, 3
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 4
	lbu t1, 0(t1)
	add t3, a1, 4
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 5
	lbu t1, 0(t1)
	add t3, a1, 5
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 6
	lbu t1, 0(t1)
	add t3, a1, 6
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 7
	lbu t1, 0(t1)
	add t3, a1, 7
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 8
	lbu t1, 0(t1)
	add t3, a1, 8
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 9
	lbu t1, 0(t1)
	add t3, a1, 9
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 10
	lbu t1, 0(t1)
	add t3, a1, 10
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 11
	lbu t1, 0(t1)
	add t3, a1, 11
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 12
	lbu t1, 0(t1)
	add t3, a1, 12
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 13
	lbu t1, 0(t1)
	add t3, a1, 13
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 14
	lbu t1, 0(t1)
	add t3, a1, 14
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 15
	lbu t1, 0(t1)
	add t3, a1, 15
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 16
	lbu t1, 0(t1)
	add t3, a1, 16
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 17
	lbu t1, 0(t1)
	add t3, a1, 17
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 18
	lbu t1, 0(t1)
	add t3, a1, 18
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 19
	lbu t1, 0(t1)
	add t3, a1, 19
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 20
	lbu t1, 0(t1)
	add t3, a1, 20
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 21
	lbu t1, 0(t1)
	add t3, a1, 21
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 22
	lbu t1, 0(t1)
	add t3, a1, 22
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 23
	lbu t1, 0(t1)
	add t3, a1, 23
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 24
	lbu t1, 0(t1)
	add t3, a1, 24
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 25
	lbu t1, 0(t1)
	add t3, a1, 25
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 26
	lbu t1, 0(t1)
	add t3, a1, 26
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 27
	lbu t1, 0(t1)
	add t3, a1, 27
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 28
	lbu t1, 0(t1)
	add t3, a1, 28
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 29
	lbu t1, 0(t1)
	add t3, a1, 29
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 30
	lbu t1, 0(t1)
	add t3, a1, 30
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -32
	add t1, t1, 31
	lbu t1, 0(t1)
	add t3, a1, 31
	sext.w t2, t1
	sb t2, 0(t3)
	add a0, t0, t1
	ld s1, 0(sp)
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type probe_hidden_indirect, @function
.size probe_hidden_indirect, .-probe_hidden_indirect
/* end function probe_hidden_indirect */

.text
.balign 16
echo_union:
	add sp, sp, -64
	sd a0, 0(sp)
	sd a1, 8(sp)
	sd a2, 16(sp)
	sd a3, 24(sp)
	sd a4, 32(sp)
	sd a5, 40(sp)
	sd a6, 48(sp)
	sd a7, 56(sp)
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -48
	add t0, fp, -16
	add t0, t0, 8
	sd a1, 0(t0)
	add t0, fp, -16
	add t0, t0, 0
	sd a0, 0(t0)
	xor t0, a2, 0
	seqz t0, t0
	bnez t0, .L34
	li t0, 1
	subw a2, a2, t0
	li a3, 91
	add t0, fp, -16
	add t0, t0, 8
	ld a1, 0(t0)
	add t0, fp, -16
	add t0, t0, 0
	ld a0, 0(t0)
	call echo_union
	mv t1, a1
	mv t0, a0
	add t2, fp, -32
	add t2, t2, 8
	sd t1, 0(t2)
	add t1, fp, -32
	add t1, t1, 0
	sd t0, 0(t1)
	add t0, fp, -32
	add t0, t0, 8
	ld a1, 0(t0)
	add t0, fp, -32
	add t0, t0, 0
	ld a0, 0(t0)
	j .L35
.L34:
	add t0, fp, -16
	add t0, t0, 8
	ld a1, 0(t0)
	add t0, fp, -16
	add t0, t0, 0
	ld a0, 0(t0)
.L35:
	add sp, fp, 80
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type echo_union, @function
.size echo_union, .-echo_union
/* end function echo_union */

.text
.balign 16
.globl probe_union_direct
probe_union_direct:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -48
	sd s1, 0(sp)
	li a3, 91
	li a2, 2
	add t0, a0, 8
	mv s1, a1
	ld a1, 0(t0)
	add t0, a0, 0
	ld a0, 0(t0)
	call echo_union
	mv t1, a1
	mv a1, s1
	mv t0, a0
	add t2, fp, -16
	add t2, t2, 8
	sd t1, 0(t2)
	add t1, fp, -16
	add t1, t1, 0
	sd t0, 0(t1)
	lbu t0, -16(fp)
	sext.w t1, t0
	sb t1, 0(a1)
	add t1, fp, -16
	add t1, t1, 1
	lbu t1, 0(t1)
	add t3, a1, 1
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 2
	lbu t1, 0(t1)
	add t3, a1, 2
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 3
	lbu t1, 0(t1)
	add t3, a1, 3
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 4
	lbu t1, 0(t1)
	add t3, a1, 4
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 5
	lbu t1, 0(t1)
	add t3, a1, 5
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 6
	lbu t1, 0(t1)
	add t3, a1, 6
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 7
	lbu t1, 0(t1)
	add t3, a1, 7
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 8
	lbu t1, 0(t1)
	add t3, a1, 8
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 9
	lbu t1, 0(t1)
	add t3, a1, 9
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 10
	lbu t1, 0(t1)
	add t3, a1, 10
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 11
	lbu t1, 0(t1)
	add t3, a1, 11
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 12
	lbu t1, 0(t1)
	add t3, a1, 12
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 13
	lbu t1, 0(t1)
	add t3, a1, 13
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 14
	lbu t1, 0(t1)
	add t3, a1, 14
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 15
	lbu t1, 0(t1)
	add t3, a1, 15
	sext.w t2, t1
	sb t2, 0(t3)
	add a0, t0, t1
	ld s1, 0(sp)
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type probe_union_direct, @function
.size probe_union_direct, .-probe_union_direct
/* end function probe_union_direct */

.text
.balign 16
.globl probe_union_indirect
probe_union_indirect:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -48
	sd s1, 0(sp)
	li a3, 91
	li a2, 2
	add t0, a0, 8
	mv s1, a1
	ld a1, 0(t0)
	add t0, a0, 0
	ld a0, 0(t0)
	call echo_union
	mv t1, a1
	mv a1, s1
	mv t0, a0
	add t2, fp, -16
	add t2, t2, 8
	sd t1, 0(t2)
	add t1, fp, -16
	add t1, t1, 0
	sd t0, 0(t1)
	lbu t0, -16(fp)
	sext.w t1, t0
	sb t1, 0(a1)
	add t1, fp, -16
	add t1, t1, 1
	lbu t1, 0(t1)
	add t3, a1, 1
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 2
	lbu t1, 0(t1)
	add t3, a1, 2
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 3
	lbu t1, 0(t1)
	add t3, a1, 3
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 4
	lbu t1, 0(t1)
	add t3, a1, 4
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 5
	lbu t1, 0(t1)
	add t3, a1, 5
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 6
	lbu t1, 0(t1)
	add t3, a1, 6
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 7
	lbu t1, 0(t1)
	add t3, a1, 7
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 8
	lbu t1, 0(t1)
	add t3, a1, 8
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 9
	lbu t1, 0(t1)
	add t3, a1, 9
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 10
	lbu t1, 0(t1)
	add t3, a1, 10
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 11
	lbu t1, 0(t1)
	add t3, a1, 11
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 12
	lbu t1, 0(t1)
	add t3, a1, 12
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 13
	lbu t1, 0(t1)
	add t3, a1, 13
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 14
	lbu t1, 0(t1)
	add t3, a1, 14
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 15
	lbu t1, 0(t1)
	add t3, a1, 15
	sext.w t2, t1
	sb t2, 0(t3)
	add a0, t0, t1
	ld s1, 0(sp)
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type probe_union_indirect, @function
.size probe_union_indirect, .-probe_union_indirect
/* end function probe_union_indirect */

.text
.balign 16
echo_opaque:
	add sp, sp, -64
	sd a0, 0(sp)
	sd a1, 8(sp)
	sd a2, 16(sp)
	sd a3, 24(sp)
	sd a4, 32(sp)
	sd a5, 40(sp)
	sd a6, 48(sp)
	sd a7, 56(sp)
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -80
	sd s1, 0(sp)
	xor t0, a2, 0
	seqz t0, t0
	bnez t0, .L42
	li t0, 1
	subw a2, a2, t0
	add t0, a1, 0
	ld t0, 0(t0)
	add t1, fp, -48
	add t1, t1, 0
	sd t0, 0(t1)
	add t0, a1, 8
	ld t0, 0(t0)
	add t1, fp, -48
	add t1, t1, 8
	sd t0, 0(t1)
	add t0, a1, 16
	ld t0, 0(t0)
	add t1, fp, -48
	add t1, t1, 16
	sd t0, 0(t1)
	li a3, 91
	add a1, fp, -48
	mv s1, a0
	add a0, fp, -24
	call echo_opaque
	mv a0, s1
	add t0, fp, -24
	add t0, t0, 0
	ld t0, 0(t0)
	add t1, a0, 0
	sd t0, 0(t1)
	add t0, fp, -24
	add t0, t0, 8
	ld t0, 0(t0)
	add t1, a0, 8
	sd t0, 0(t1)
	add t0, fp, -24
	add t0, t0, 16
	ld t0, 0(t0)
	add t1, a0, 16
	sd t0, 0(t1)
	j .L43
.L42:
	add t0, a1, 0
	ld t0, 0(t0)
	add t1, a0, 0
	sd t0, 0(t1)
	add t0, a1, 8
	ld t0, 0(t0)
	add t1, a0, 8
	sd t0, 0(t1)
	add t0, a1, 16
	ld t0, 0(t0)
	add t1, a0, 16
	sd t0, 0(t1)
.L43:
	ld s1, 0(sp)
	add sp, fp, 80
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type echo_opaque, @function
.size echo_opaque, .-echo_opaque
/* end function echo_opaque */

.text
.balign 16
.globl probe_opaque_direct
probe_opaque_direct:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -80
	sd s1, 0(sp)
	add t0, a0, 0
	ld t0, 0(t0)
	add t1, fp, -48
	add t1, t1, 0
	sd t0, 0(t1)
	add t0, a0, 8
	ld t0, 0(t0)
	add t1, fp, -48
	add t1, t1, 8
	sd t0, 0(t1)
	add t0, a0, 16
	ld t0, 0(t0)
	add t1, fp, -48
	add t1, t1, 16
	sd t0, 0(t1)
	li a3, 91
	li a2, 2
	mv s1, a1
	add a1, fp, -48
	add a0, fp, -24
	call echo_opaque
	mv a1, s1
	lbu t0, -24(fp)
	sext.w t1, t0
	sb t1, 0(a1)
	add t1, fp, -24
	add t1, t1, 1
	lbu t1, 0(t1)
	add t3, a1, 1
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 2
	lbu t1, 0(t1)
	add t3, a1, 2
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 3
	lbu t1, 0(t1)
	add t3, a1, 3
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 4
	lbu t1, 0(t1)
	add t3, a1, 4
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 5
	lbu t1, 0(t1)
	add t3, a1, 5
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 6
	lbu t1, 0(t1)
	add t3, a1, 6
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 7
	lbu t1, 0(t1)
	add t3, a1, 7
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 8
	lbu t1, 0(t1)
	add t3, a1, 8
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 9
	lbu t1, 0(t1)
	add t3, a1, 9
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 10
	lbu t1, 0(t1)
	add t3, a1, 10
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 11
	lbu t1, 0(t1)
	add t3, a1, 11
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 12
	lbu t1, 0(t1)
	add t3, a1, 12
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 13
	lbu t1, 0(t1)
	add t3, a1, 13
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 14
	lbu t1, 0(t1)
	add t3, a1, 14
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 15
	lbu t1, 0(t1)
	add t3, a1, 15
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 16
	lbu t1, 0(t1)
	add t3, a1, 16
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 17
	lbu t1, 0(t1)
	add t3, a1, 17
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 18
	lbu t1, 0(t1)
	add t3, a1, 18
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 19
	lbu t1, 0(t1)
	add t3, a1, 19
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 20
	lbu t1, 0(t1)
	add t3, a1, 20
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 21
	lbu t1, 0(t1)
	add t3, a1, 21
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 22
	lbu t1, 0(t1)
	add t3, a1, 22
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 23
	lbu t1, 0(t1)
	add t3, a1, 23
	sext.w t2, t1
	sb t2, 0(t3)
	add a0, t0, t1
	ld s1, 0(sp)
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type probe_opaque_direct, @function
.size probe_opaque_direct, .-probe_opaque_direct
/* end function probe_opaque_direct */

.text
.balign 16
.globl probe_opaque_indirect
probe_opaque_indirect:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -80
	sd s1, 0(sp)
	add t0, a0, 0
	ld t0, 0(t0)
	add t1, fp, -48
	add t1, t1, 0
	sd t0, 0(t1)
	add t0, a0, 8
	ld t0, 0(t0)
	add t1, fp, -48
	add t1, t1, 8
	sd t0, 0(t1)
	add t0, a0, 16
	ld t0, 0(t0)
	add t1, fp, -48
	add t1, t1, 16
	sd t0, 0(t1)
	li a3, 91
	li a2, 2
	mv s1, a1
	add a1, fp, -48
	add a0, fp, -24
	call echo_opaque
	mv a1, s1
	lbu t0, -24(fp)
	sext.w t1, t0
	sb t1, 0(a1)
	add t1, fp, -24
	add t1, t1, 1
	lbu t1, 0(t1)
	add t3, a1, 1
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 2
	lbu t1, 0(t1)
	add t3, a1, 2
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 3
	lbu t1, 0(t1)
	add t3, a1, 3
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 4
	lbu t1, 0(t1)
	add t3, a1, 4
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 5
	lbu t1, 0(t1)
	add t3, a1, 5
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 6
	lbu t1, 0(t1)
	add t3, a1, 6
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 7
	lbu t1, 0(t1)
	add t3, a1, 7
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 8
	lbu t1, 0(t1)
	add t3, a1, 8
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 9
	lbu t1, 0(t1)
	add t3, a1, 9
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 10
	lbu t1, 0(t1)
	add t3, a1, 10
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 11
	lbu t1, 0(t1)
	add t3, a1, 11
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 12
	lbu t1, 0(t1)
	add t3, a1, 12
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 13
	lbu t1, 0(t1)
	add t3, a1, 13
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 14
	lbu t1, 0(t1)
	add t3, a1, 14
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 15
	lbu t1, 0(t1)
	add t3, a1, 15
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 16
	lbu t1, 0(t1)
	add t3, a1, 16
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 17
	lbu t1, 0(t1)
	add t3, a1, 17
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 18
	lbu t1, 0(t1)
	add t3, a1, 18
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 19
	lbu t1, 0(t1)
	add t3, a1, 19
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 20
	lbu t1, 0(t1)
	add t3, a1, 20
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 21
	lbu t1, 0(t1)
	add t3, a1, 21
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 22
	lbu t1, 0(t1)
	add t3, a1, 22
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -24
	add t1, t1, 23
	lbu t1, 0(t1)
	add t3, a1, 23
	sext.w t2, t1
	sb t2, 0(t3)
	add a0, t0, t1
	ld s1, 0(sp)
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type probe_opaque_indirect, @function
.size probe_opaque_indirect, .-probe_opaque_indirect
/* end function probe_opaque_indirect */

.text
.balign 16
echo_nested:
	add sp, sp, -64
	sd a0, 0(sp)
	sd a1, 8(sp)
	sd a2, 16(sp)
	sd a3, 24(sp)
	sd a4, 32(sp)
	sd a5, 40(sp)
	sd a6, 48(sp)
	sd a7, 56(sp)
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -48
	add t0, fp, -16
	add t0, t0, 8
	sd a1, 0(t0)
	add t0, fp, -16
	add t0, t0, 0
	sd a0, 0(t0)
	xor t0, a2, 0
	seqz t0, t0
	bnez t0, .L50
	li t0, 1
	subw a2, a2, t0
	li a3, 91
	add t0, fp, -16
	add t0, t0, 8
	ld a1, 0(t0)
	add t0, fp, -16
	add t0, t0, 0
	ld a0, 0(t0)
	call echo_nested
	mv t1, a1
	mv t0, a0
	add t2, fp, -32
	add t2, t2, 8
	sd t1, 0(t2)
	add t1, fp, -32
	add t1, t1, 0
	sd t0, 0(t1)
	add t0, fp, -32
	add t0, t0, 8
	ld a1, 0(t0)
	add t0, fp, -32
	add t0, t0, 0
	ld a0, 0(t0)
	j .L51
.L50:
	add t0, fp, -16
	add t0, t0, 8
	ld a1, 0(t0)
	add t0, fp, -16
	add t0, t0, 0
	ld a0, 0(t0)
.L51:
	add sp, fp, 80
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type echo_nested, @function
.size echo_nested, .-echo_nested
/* end function echo_nested */

.text
.balign 16
.globl probe_nested_direct
probe_nested_direct:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -48
	sd s1, 0(sp)
	li a3, 91
	li a2, 2
	add t0, a0, 8
	mv s1, a1
	ld a1, 0(t0)
	add t0, a0, 0
	ld a0, 0(t0)
	call echo_nested
	mv t1, a1
	mv a1, s1
	mv t0, a0
	add t2, fp, -16
	add t2, t2, 8
	sd t1, 0(t2)
	add t1, fp, -16
	add t1, t1, 0
	sd t0, 0(t1)
	lbu t0, -16(fp)
	sext.w t1, t0
	sb t1, 0(a1)
	add t1, fp, -16
	add t1, t1, 1
	lbu t1, 0(t1)
	add t3, a1, 1
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 2
	lbu t1, 0(t1)
	add t3, a1, 2
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 3
	lbu t1, 0(t1)
	add t3, a1, 3
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 4
	lbu t1, 0(t1)
	add t3, a1, 4
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 5
	lbu t1, 0(t1)
	add t3, a1, 5
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 6
	lbu t1, 0(t1)
	add t3, a1, 6
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 7
	lbu t1, 0(t1)
	add t3, a1, 7
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 8
	lbu t1, 0(t1)
	add t3, a1, 8
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 9
	lbu t1, 0(t1)
	add t3, a1, 9
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 10
	lbu t1, 0(t1)
	add t3, a1, 10
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 11
	lbu t1, 0(t1)
	add t3, a1, 11
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 12
	lbu t1, 0(t1)
	add t3, a1, 12
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 13
	lbu t1, 0(t1)
	add t3, a1, 13
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 14
	lbu t1, 0(t1)
	add t3, a1, 14
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 15
	lbu t1, 0(t1)
	add t3, a1, 15
	sext.w t2, t1
	sb t2, 0(t3)
	add a0, t0, t1
	ld s1, 0(sp)
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type probe_nested_direct, @function
.size probe_nested_direct, .-probe_nested_direct
/* end function probe_nested_direct */

.text
.balign 16
.globl probe_nested_indirect
probe_nested_indirect:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -48
	sd s1, 0(sp)
	li a3, 91
	li a2, 2
	add t0, a0, 8
	mv s1, a1
	ld a1, 0(t0)
	add t0, a0, 0
	ld a0, 0(t0)
	call echo_nested
	mv t1, a1
	mv a1, s1
	mv t0, a0
	add t2, fp, -16
	add t2, t2, 8
	sd t1, 0(t2)
	add t1, fp, -16
	add t1, t1, 0
	sd t0, 0(t1)
	lbu t0, -16(fp)
	sext.w t1, t0
	sb t1, 0(a1)
	add t1, fp, -16
	add t1, t1, 1
	lbu t1, 0(t1)
	add t3, a1, 1
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 2
	lbu t1, 0(t1)
	add t3, a1, 2
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 3
	lbu t1, 0(t1)
	add t3, a1, 3
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 4
	lbu t1, 0(t1)
	add t3, a1, 4
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 5
	lbu t1, 0(t1)
	add t3, a1, 5
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 6
	lbu t1, 0(t1)
	add t3, a1, 6
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 7
	lbu t1, 0(t1)
	add t3, a1, 7
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 8
	lbu t1, 0(t1)
	add t3, a1, 8
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 9
	lbu t1, 0(t1)
	add t3, a1, 9
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 10
	lbu t1, 0(t1)
	add t3, a1, 10
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 11
	lbu t1, 0(t1)
	add t3, a1, 11
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 12
	lbu t1, 0(t1)
	add t3, a1, 12
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 13
	lbu t1, 0(t1)
	add t3, a1, 13
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 14
	lbu t1, 0(t1)
	add t3, a1, 14
	sext.w t2, t1
	sb t2, 0(t3)
	add t0, t0, t1
	add t1, fp, -16
	add t1, t1, 15
	lbu t1, 0(t1)
	add t3, a1, 15
	sext.w t2, t1
	sb t2, 0(t3)
	add a0, t0, t1
	ld s1, 0(sp)
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type probe_nested_indirect, @function
.size probe_nested_indirect, .-probe_nested_indirect
/* end function probe_nested_indirect */

.text
.balign 16
.globl interpreted
interpreted:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -64
	li t0, 72623859790382856
	sd t0, -48(fp)
	add t0, fp, -48
	add t1, t0, 8
	li t0, 72623859790382856
	sd t0, 0(t1)
	add a1, fp, -16
	add a0, fp, -48
	call probe_nested_indirect
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type interpreted, @function
.size interpreted, .-interpreted
/* end function interpreted */

.section .note.GNU-stack,"",@progbits
