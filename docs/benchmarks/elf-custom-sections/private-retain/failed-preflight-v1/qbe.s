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

