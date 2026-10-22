.text
.balign 16
.globl long_then_word
long_then_word:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	sext.w t0, a0
	addw a0, t0, 1
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type long_then_word, @function
.size long_then_word, .-long_then_word
/* end function long_then_word */

.text
.balign 16
.globl word_then_long
word_then_long:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	add t0, a0, 3
	sext.w a0, t0
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type word_then_long, @function
.size word_then_long, .-word_then_long
/* end function word_then_long */

.text
.balign 16
.globl parameter_long
parameter_long:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	sext.w t0, a0
	addw a0, t0, 17
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type parameter_long, @function
.size parameter_long, .-parameter_long
/* end function parameter_long */

.text
.balign 16
.globl parameter_word
parameter_word:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	add t0, a0, 23
	sext.w a0, t0
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type parameter_word, @function
.size parameter_word, .-parameter_word
/* end function parameter_word */

.text
.balign 16
.globl branch
branch:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	and t0, a1, 1
	bnez t0, .L10
	sext.w t0, a0
	addw t0, t0, 13
	j .L11
.L10:
	add t0, a0, 7
	sext.w t0, t0
.L11:
	li t1, 305419896
	xor a0, t0, t1
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type branch, @function
.size branch, .-branch
/* end function branch */

.text
.balign 16
.globl loop
loop:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	sext.w t2, a0
	sext.w t1, a0
	li t0, 0
	beqz a1, .L18
	mv a0, t1
.L15:
	addw t1, a0, 3
	zext.w t1, t1
	add a0, t1, 7
	addw t0, t0, 1
	sltu t1, t0, a1
	sext.w t3, a0
	sext.w t2, a0
	beqz t1, .L17
	mv a0, t2
	j .L15
.L17:
	mv a0, t3
	j .L19
.L18:
	mv a0, t2
.L19:
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type loop, @function
.size loop, .-loop
/* end function loop */

.text
.balign 16
.globl shift
shift:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	sext.w t0, a0
	addw t0, t0, a1
	sll t0, a0, t0
	sext.w a0, t0
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type shift, @function
.size shift, .-shift
/* end function shift */

.text
.balign 16
called:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	li t0, 7
	mulw a0, a0, t0
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type called, @function
.size called, .-called
/* end function called */

.text
.balign 16
.globl call_word
call_word:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	sext.w t0, a0
	addw a0, t0, a1
	call called
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type call_word, @function
.size call_word, .-call_word
/* end function call_word */

.text
.balign 16
.globl word_roles
word_roles:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	sext.w t0, a0
	xor t0, t0, a1
	fmv.w.x ft0, t0
	fmv.x.w a0, ft0
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type word_roles, @function
.size word_roles, .-word_roles
/* end function word_roles */

.text
.balign 16
effect:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	sw a0, 0(a1)
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type effect, @function
.size effect, .-effect
/* end function effect */

.text
.balign 16
.globl void_call_word
void_call_word:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -32
	sext.w t0, a0
	addw a0, t0, a1
	li t0, 0
	sw t0, -8(fp)
	add a1, fp, -8
	call effect
	lw a0, -8(fp)
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type void_call_word, @function
.size void_call_word, .-void_call_word
/* end function void_call_word */

.section .note.GNU-stack,"",@progbits
