.section ".lcb.keep_rw","awR"
.balign 8
.globl keep_rw
keep_rw:
	.quad 37
/* end data */

.section ".lcb.keep_ro","aR"
.balign 8
.globl keep_ro
keep_ro:
	.quad 83
/* end data */

.section ".lcb.drop_data","aw"
.balign 8
.globl drop_data
drop_data:
	.quad 99
/* end data */

.section ".lcb.ref_data","aw"
.balign 8
.globl ref_data
ref_data:
	.quad 19
/* end data */

.section ".lcb.keep_code","axR"
.balign 16
.globl keep_code
keep_code:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	li a0, 71
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type keep_code, @function
.size keep_code, .-keep_code
/* end function keep_code */

.section ".lcb.drop_code","ax"
.balign 16
.globl drop_code
drop_code:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	li a0, 101
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type drop_code, @function
.size drop_code, .-drop_code
/* end function drop_code */

.section ".lcb.ref_code","ax"
.balign 16
.globl anchor
anchor:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	li a0, 17
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type anchor, @function
.size anchor, .-anchor
/* end function anchor */

.section .note.GNU-stack,"",@progbits
