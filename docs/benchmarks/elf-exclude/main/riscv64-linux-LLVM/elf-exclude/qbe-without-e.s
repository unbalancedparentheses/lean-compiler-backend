.section ".lcb_exclude_0",""
.balign 8
.globl metadata0
metadata0:
	.quad 73
/* end data */

.section ".lcb_exclude_1","R"
.balign 8
.globl metadata1
metadata1:
	.quad 74
/* end data */

.section ".lcb_exclude_2","x"
.balign 1
.globl metadata2
metadata2:
	.quad 75
/* end data */

.section ".lcb_exclude_3","xR"
.balign 1
.globl metadata3
metadata3:
	.quad 76
/* end data */

.section ".lcb_exclude_4","w"
.balign 8
.globl metadata4
metadata4:
	.quad 77
/* end data */

.section ".lcb_exclude_5","wR"
.balign 8
.globl metadata5
metadata5:
	.quad 78
/* end data */

.section ".lcb_exclude_6","wx"
.balign 1
.globl metadata6
metadata6:
	.quad 79
/* end data */

.section ".lcb_exclude_7","wxR"
.balign 1
.globl metadata7
metadata7:
	.quad 80
/* end data */

.section ".lcb_exclude_8","a"
.balign 8
.globl metadata8
metadata8:
	.quad 81
/* end data */

.section ".lcb_exclude_9","aR"
.balign 8
.globl metadata9
metadata9:
	.quad 82
/* end data */

.section ".lcb_exclude_10","ax"
.balign 1
.globl metadata10
metadata10:
	.quad 83
/* end data */

.section ".lcb_exclude_11","axR"
.balign 1
.globl metadata11
metadata11:
	.quad 84
/* end data */

.section ".lcb_exclude_12","aw"
.balign 8
.globl metadata12
metadata12:
	.quad 85
/* end data */

.section ".lcb_exclude_13","awR"
.balign 8
.globl metadata13
metadata13:
	.quad 86
/* end data */

.section ".lcb_exclude_14","awx"
.balign 1
.globl metadata14
metadata14:
	.quad 87
/* end data */

.section ".lcb_exclude_15","awxR"
.balign 1
.globl metadata15
metadata15:
	.quad 88
/* end data */

.section ".lcb_exclude_16","Rawx"
.balign 1
.globl metadata16
metadata16:
	.quad 89
/* end data */

.section ".lcb_exclude_17",""
.balign 8
.globl metadata17
metadata17:
	.quad 90
/* end data */

.section ".lcb_exclude_function","axR"
.balign 16
.globl excluded_function
excluded_function:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	li a0, 17
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type excluded_function, @function
.size excluded_function, .-excluded_function
/* end function excluded_function */

.data
.balign 8
.globl kept
kept:
	.quad 41
/* end data */

.text
.balign 16
.globl ordinary
ordinary:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	li a0, 42
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type ordinary, @function
.size ordinary, .-ordinary
/* end function ordinary */

.section .note.GNU-stack,"",@progbits
