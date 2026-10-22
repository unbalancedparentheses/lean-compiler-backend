.section ".lcb_tls.init","awT"
.balign 16
.globl custom_init
custom_init:
	.quad 37
/* end data */

.section ".lcb_tls.zero","waT"
.balign 32
.globl custom_zero
custom_zero:
	.fill 8,1,0
/* end data */

.section ".lcb_tls.local","Taw"
.balign 8
custom_local:
	.quad 73
/* end data */

.section .tdata,"awT"
.balign 8
.globl ordinary
ordinary:
	.quad 19
/* end data */

.text
.balign 16
.globl read_custom
read_custom:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	bnez a0, .L2
	lui t6, %tprel_hi(custom_init)
	add t6, t6, tp, %tprel_add(custom_init)
	addi t6, t6, %tprel_lo(custom_init)
	ld a0, 0(t6)
	j .L3
.L2:
	lui t6, %tprel_hi(custom_zero)
	add t6, t6, tp, %tprel_add(custom_zero)
	addi t6, t6, %tprel_lo(custom_zero)
	ld a0, 0(t6)
.L3:
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type read_custom, @function
.size read_custom, .-read_custom
/* end function read_custom */

.text
.balign 16
.globl write_custom
write_custom:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	lui t6, %tprel_hi(custom_init)
	add t6, t6, tp, %tprel_add(custom_init)
	addi t6, t6, %tprel_lo(custom_init)
	sd a0, 0(t6)
	lui t6, %tprel_hi(custom_zero)
	add t6, t6, tp, %tprel_add(custom_zero)
	addi t6, t6, %tprel_lo(custom_zero)
	sd a1, 0(t6)
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type write_custom, @function
.size write_custom, .-write_custom
/* end function write_custom */

.text
.balign 16
.globl read_local
read_local:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	lui t6, %tprel_hi(custom_local)
	add t6, t6, tp, %tprel_add(custom_local)
	addi t6, t6, %tprel_lo(custom_local)
	ld a0, 0(t6)
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type read_local, @function
.size read_local, .-read_local
/* end function read_local */

.text
.balign 16
.globl write_local
write_local:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	lui t6, %tprel_hi(custom_local)
	add t6, t6, tp, %tprel_add(custom_local)
	addi t6, t6, %tprel_lo(custom_local)
	sd a0, 0(t6)
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type write_local, @function
.size write_local, .-write_local
/* end function write_local */

.text
.balign 16
.globl read_ordinary
read_ordinary:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	lui t6, %tprel_hi(ordinary)
	add t6, t6, tp, %tprel_add(ordinary)
	addi t6, t6, %tprel_lo(ordinary)
	ld a0, 0(t6)
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type read_ordinary, @function
.size read_ordinary, .-read_ordinary
/* end function read_ordinary */

.text
.balign 16
.globl write_ordinary
write_ordinary:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	lui t6, %tprel_hi(ordinary)
	add t6, t6, tp, %tprel_add(ordinary)
	addi t6, t6, %tprel_lo(ordinary)
	sd a0, 0(t6)
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type write_ordinary, @function
.size write_ordinary, .-write_ordinary
/* end function write_ordinary */

.section .note.GNU-stack,"",@progbits
