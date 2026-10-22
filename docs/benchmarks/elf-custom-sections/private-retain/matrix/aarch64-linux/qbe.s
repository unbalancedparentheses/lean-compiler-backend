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
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	x0, #71
	ldp	x29, x30, [sp], 16
	ret
.type keep_code, @function
.size keep_code, .-keep_code
/* end function keep_code */

.section ".lcb.drop_code","ax"
.balign 16
.globl drop_code
drop_code:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	x0, #101
	ldp	x29, x30, [sp], 16
	ret
.type drop_code, @function
.size drop_code, .-drop_code
/* end function drop_code */

.section ".lcb.ref_code","ax"
.balign 16
.globl anchor
anchor:
	hint	#34
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	x0, #17
	ldp	x29, x30, [sp], 16
	ret
.type anchor, @function
.size anchor, .-anchor
/* end function anchor */

.section .note.GNU-stack,"",@progbits
