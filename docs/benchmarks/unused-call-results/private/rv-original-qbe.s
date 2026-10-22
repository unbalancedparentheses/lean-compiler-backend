.text
.balign 16
local_w:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	ld t0, 0(a0)
	add t0, t0, 1
	sd t0, 0(a0)
	li a0, -1
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type local_w, @function
.size local_w, .-local_w
/* end function local_w */

.text
.balign 16
.globl probe_w
probe_w:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -32
	sd s1, 0(sp)
	sd s2, 8(sp)
	mv s2, a1
	mv s1, a0
	call local_w
	mv a0, s1
	mv s1, a0
	call local_w
	mv a0, s1
	mv s1, a0
	call external_w
	mv a1, s2
	mv a0, s1
	jalr a1
	ld s1, 0(sp)
	ld s2, 8(sp)
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type probe_w, @function
.size probe_w, .-probe_w
/* end function probe_w */

.text
.balign 16
.globl interpret_w
interpret_w:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -32
	li t0, 0
	sd t0, -8(fp)
	add a0, fp, -8
	call local_w
	add a0, fp, -8
	call local_w
	ld a0, -8(fp)
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type interpret_w, @function
.size interpret_w, .-interpret_w
/* end function interpret_w */

.text
.balign 16
local_l:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	ld t0, 0(a0)
	add t0, t0, 2
	sd t0, 0(a0)
	li a0, -1
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type local_l, @function
.size local_l, .-local_l
/* end function local_l */

.text
.balign 16
.globl probe_l
probe_l:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -32
	sd s1, 0(sp)
	sd s2, 8(sp)
	mv s2, a1
	mv s1, a0
	call local_l
	mv a0, s1
	mv s1, a0
	call local_l
	mv a0, s1
	mv s1, a0
	call external_l
	mv a1, s2
	mv a0, s1
	jalr a1
	ld s1, 0(sp)
	ld s2, 8(sp)
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type probe_l, @function
.size probe_l, .-probe_l
/* end function probe_l */

.text
.balign 16
.globl interpret_l
interpret_l:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -32
	li t0, 0
	sd t0, -8(fp)
	add a0, fp, -8
	call local_l
	add a0, fp, -8
	call local_l
	ld a0, -8(fp)
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type interpret_l, @function
.size interpret_l, .-interpret_l
/* end function interpret_l */

.text
.balign 16
local_s:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	ld t0, 0(a0)
	add t0, t0, 3
	sd t0, 0(a0)
	flw fa0, ".Lfp0", t6
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type local_s, @function
.size local_s, .-local_s
/* end function local_s */

.text
.balign 16
.globl probe_s
probe_s:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -32
	sd s1, 0(sp)
	sd s2, 8(sp)
	mv s2, a1
	mv s1, a0
	call local_s
	mv a0, s1
	mv s1, a0
	call local_s
	mv a0, s1
	mv s1, a0
	call external_s
	mv a1, s2
	mv a0, s1
	jalr a1
	ld s1, 0(sp)
	ld s2, 8(sp)
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type probe_s, @function
.size probe_s, .-probe_s
/* end function probe_s */

.text
.balign 16
.globl interpret_s
interpret_s:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -32
	li t0, 0
	sd t0, -8(fp)
	add a0, fp, -8
	call local_s
	add a0, fp, -8
	call local_s
	ld a0, -8(fp)
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type interpret_s, @function
.size interpret_s, .-interpret_s
/* end function interpret_s */

.text
.balign 16
local_d:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	ld t0, 0(a0)
	add t0, t0, 4
	sd t0, 0(a0)
	fld fa0, ".Lfp1", t6
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type local_d, @function
.size local_d, .-local_d
/* end function local_d */

.text
.balign 16
.globl probe_d
probe_d:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -32
	sd s1, 0(sp)
	sd s2, 8(sp)
	mv s2, a1
	mv s1, a0
	call local_d
	mv a0, s1
	mv s1, a0
	call local_d
	mv a0, s1
	mv s1, a0
	call external_d
	mv a1, s2
	mv a0, s1
	jalr a1
	ld s1, 0(sp)
	ld s2, 8(sp)
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type probe_d, @function
.size probe_d, .-probe_d
/* end function probe_d */

.text
.balign 16
.globl interpret_d
interpret_d:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -32
	li t0, 0
	sd t0, -8(fp)
	add a0, fp, -8
	call local_d
	add a0, fp, -8
	call local_d
	ld a0, -8(fp)
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type interpret_d, @function
.size interpret_d, .-interpret_d
/* end function interpret_d */

.text
.balign 16
local_sb:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	ld t0, 0(a0)
	add t0, t0, 5
	sd t0, 0(a0)
	li a0, 255
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type local_sb, @function
.size local_sb, .-local_sb
/* end function local_sb */

.text
.balign 16
.globl probe_sb
probe_sb:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -32
	sd s1, 0(sp)
	sd s2, 8(sp)
	mv s2, a1
	mv s1, a0
	call local_sb
	mv a0, s1
	mv s1, a0
	call local_sb
	mv a0, s1
	mv s1, a0
	call external_sb
	mv a1, s2
	mv a0, s1
	jalr a1
	ld s1, 0(sp)
	ld s2, 8(sp)
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type probe_sb, @function
.size probe_sb, .-probe_sb
/* end function probe_sb */

.text
.balign 16
.globl interpret_sb
interpret_sb:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -32
	li t0, 0
	sd t0, -8(fp)
	add a0, fp, -8
	call local_sb
	add a0, fp, -8
	call local_sb
	ld a0, -8(fp)
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type interpret_sb, @function
.size interpret_sb, .-interpret_sb
/* end function interpret_sb */

.text
.balign 16
local_ub:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	ld t0, 0(a0)
	add t0, t0, 6
	sd t0, 0(a0)
	li a0, 255
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type local_ub, @function
.size local_ub, .-local_ub
/* end function local_ub */

.text
.balign 16
.globl probe_ub
probe_ub:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -32
	sd s1, 0(sp)
	sd s2, 8(sp)
	mv s2, a1
	mv s1, a0
	call local_ub
	mv a0, s1
	mv s1, a0
	call local_ub
	mv a0, s1
	mv s1, a0
	call external_ub
	mv a1, s2
	mv a0, s1
	jalr a1
	ld s1, 0(sp)
	ld s2, 8(sp)
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type probe_ub, @function
.size probe_ub, .-probe_ub
/* end function probe_ub */

.text
.balign 16
.globl interpret_ub
interpret_ub:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -32
	li t0, 0
	sd t0, -8(fp)
	add a0, fp, -8
	call local_ub
	add a0, fp, -8
	call local_ub
	ld a0, -8(fp)
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type interpret_ub, @function
.size interpret_ub, .-interpret_ub
/* end function interpret_ub */

.text
.balign 16
local_sh:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	ld t0, 0(a0)
	add t0, t0, 7
	sd t0, 0(a0)
	li a0, 65535
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type local_sh, @function
.size local_sh, .-local_sh
/* end function local_sh */

.text
.balign 16
.globl probe_sh
probe_sh:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -32
	sd s1, 0(sp)
	sd s2, 8(sp)
	mv s2, a1
	mv s1, a0
	call local_sh
	mv a0, s1
	mv s1, a0
	call local_sh
	mv a0, s1
	mv s1, a0
	call external_sh
	mv a1, s2
	mv a0, s1
	jalr a1
	ld s1, 0(sp)
	ld s2, 8(sp)
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type probe_sh, @function
.size probe_sh, .-probe_sh
/* end function probe_sh */

.text
.balign 16
.globl interpret_sh
interpret_sh:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -32
	li t0, 0
	sd t0, -8(fp)
	add a0, fp, -8
	call local_sh
	add a0, fp, -8
	call local_sh
	ld a0, -8(fp)
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type interpret_sh, @function
.size interpret_sh, .-interpret_sh
/* end function interpret_sh */

.text
.balign 16
local_uh:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	ld t0, 0(a0)
	add t0, t0, 8
	sd t0, 0(a0)
	li a0, 65535
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type local_uh, @function
.size local_uh, .-local_uh
/* end function local_uh */

.text
.balign 16
.globl probe_uh
probe_uh:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -32
	sd s1, 0(sp)
	sd s2, 8(sp)
	mv s2, a1
	mv s1, a0
	call local_uh
	mv a0, s1
	mv s1, a0
	call local_uh
	mv a0, s1
	mv s1, a0
	call external_uh
	mv a1, s2
	mv a0, s1
	jalr a1
	ld s1, 0(sp)
	ld s2, 8(sp)
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type probe_uh, @function
.size probe_uh, .-probe_uh
/* end function probe_uh */

.text
.balign 16
.globl interpret_uh
interpret_uh:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -32
	li t0, 0
	sd t0, -8(fp)
	add a0, fp, -8
	call local_uh
	add a0, fp, -8
	call local_uh
	ld a0, -8(fp)
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type interpret_uh, @function
.size interpret_uh, .-interpret_uh
/* end function interpret_uh */

.text
.balign 16
nothing:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	ld t0, 0(a0)
	add t0, t0, 9
	sd t0, 0(a0)
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type nothing, @function
.size nothing, .-nothing
/* end function nothing */

.text
.balign 16
.globl dead_void
dead_void:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	call nothing
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type dead_void, @function
.size dead_void, .-dead_void
/* end function dead_void */

.text
.balign 16
variadic:
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
	add sp, sp, -16
	ld t0, 0(a0)
	add t0, t0, 10
	sd t0, 0(a0)
	li a0, 99
	add sp, fp, 80
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type variadic, @function
.size variadic, .-variadic
/* end function variadic */

.text
.balign 16
.globl discard_variadic
discard_variadic:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	call variadic
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type discard_variadic, @function
.size discard_variadic, .-discard_variadic
/* end function discard_variadic */

.text
.balign 16
.globl used_w
used_w:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	call local_w
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type used_w, @function
.size used_w, .-used_w
/* end function used_w */

.text
.balign 16
.globl used_l
used_l:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	call local_l
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type used_l, @function
.size used_l, .-used_l
/* end function used_l */

.text
.balign 16
.globl used_s
used_s:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	call local_s
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type used_s, @function
.size used_s, .-used_s
/* end function used_s */

.text
.balign 16
.globl used_d
used_d:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	call local_d
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type used_d, @function
.size used_d, .-used_d
/* end function used_d */

.text
.balign 16
.globl used_sb
used_sb:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	call local_sb
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type used_sb, @function
.size used_sb, .-used_sb
/* end function used_sb */

.text
.balign 16
.globl used_ub
used_ub:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	call local_ub
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type used_ub, @function
.size used_ub, .-used_ub
/* end function used_ub */

.text
.balign 16
.globl used_sh
used_sh:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	call local_sh
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type used_sh, @function
.size used_sh, .-used_sh
/* end function used_sh */

.text
.balign 16
.globl used_uh
used_uh:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	call local_uh
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type used_uh, @function
.size used_uh, .-used_uh
/* end function used_uh */

.text
.balign 16
env_stack:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -32
	sd s1, 0(sp)
	ld t0, 48(fp)
	ld t2, 40(fp)
	ld t3, 32(fp)
	ld t4, 24(fp)
	ld s1, 16(fp)
	mv t6, a4
	mv a4, a2
	mv a2, t6
	mv t6, a5
	mv a5, a1
	mv a1, t6
	mv t1, a0
	mv a0, a6
	mv a6, t5
	mv t5, a7
	ld a6, 0(a6)
	add a5, a5, a6
	add a4, a4, a5
	add a3, a3, a4
	add a2, a2, a3
	add a1, a1, a2
	add a0, a0, a1
	add t5, t5, a0
	add t5, s1, t5
	add t4, t4, t5
	add t3, t3, t4
	add t2, t2, t3
	add t0, t0, t2
	ld t2, 0(t1)
	add t0, t0, t2
	sd t0, 0(t1)
	li a0, 123
	ld s1, 0(sp)
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type env_stack, @function
.size env_stack, .-env_stack
/* end function env_stack */

.text
.balign 16
.globl env_probe
env_probe:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	mv t5, a1
	li t0, 48
	sub sp, sp, t0
	mv t0, sp
	add t2, t0, 32
	li t1, 12
	sd t1, 0(t2)
	add t2, t0, 24
	li t1, 11
	sd t1, 0(t2)
	add t2, t0, 16
	li t1, 10
	sd t1, 0(t2)
	add t2, t0, 8
	li t1, 9
	sd t1, 0(t2)
	add t1, t0, 0
	li t0, 8
	sd t0, 0(t1)
	li a7, 7
	li a6, 6
	li a5, 5
	li a4, 4
	li a3, 3
	li a2, 2
	li a1, 1
	call env_stack
	li t0, -48
	sub sp, sp, t0
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type env_probe, @function
.size env_probe, .-env_probe
/* end function env_probe */

.text
.balign 16
.globl computed_probe
computed_probe:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -16
	add t0, a1, a2
	ld t0, 0(t0)
	jalr t0
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type computed_probe, @function
.size computed_probe, .-computed_probe
/* end function computed_probe */

.text
.balign 16
.globl aggregate_probe
aggregate_probe:
	sd fp, -16(sp)
	sd ra, -8(sp)
	add fp, sp, -16
	add sp, sp, -48
	mv a1, a0
	add a0, fp, -32
	call external_aggregate
	add sp, fp, 16
	ld ra, 8(fp)
	ld fp, 0(fp)
	ret
.type aggregate_probe, @function
.size aggregate_probe, .-aggregate_probe
/* end function aggregate_probe */

/* floating point constants */
.section .rodata
.p2align 3
.Lfp1:
	.quad -4610560118520545280 /* -2.500000 */

.section .rodata
.p2align 2
.Lfp0:
	.int 1069547520 /* 1.500000 */

.section .note.GNU-stack,"",@progbits
