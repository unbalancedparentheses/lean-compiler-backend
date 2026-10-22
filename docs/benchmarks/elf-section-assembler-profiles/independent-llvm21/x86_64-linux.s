.section "d","aw"
.balign 8
.globl value0
value0:
	.quad 37
/* end data */

.section "f","ax"
.balign 16
.globl get0
get0:
	endbr64
	movq value0(%rip), %rax
	ret
.type get0, @function
.size get0, .-get0
/* end function get0 */

.section "dplain","aw"
.balign 8
.globl value1
value1:
	.quad 38
/* end data */

.section "fplain","ax"
.balign 16
.globl get1
get1:
	endbr64
	movq value1(%rip), %rax
	ret
.type get1, @function
.size get1, .-get1
/* end function get1 */

.section "dspace name","aw"
.balign 8
.globl value2
value2:
	.quad 39
/* end data */

.section "fspace name","ax"
.balign 16
.globl get2
get2:
	endbr64
	movq value2(%rip), %rax
	ret
.type get2, @function
.size get2, .-get2
/* end function get2 */

.section "dcolon:name","aw"
.balign 8
.globl value3
value3:
	.quad 40
/* end data */

.section "fcolon:name","ax"
.balign 16
.globl get3
get3:
	endbr64
	movq value3(%rip), %rax
	ret
.type get3, @function
.size get3, .-get3
/* end function get3 */

.section "dslash/name","aw"
.balign 8
.globl value4
value4:
	.quad 41
/* end data */

.section "fslash/name","ax"
.balign 16
.globl get4
get4:
	endbr64
	movq value4(%rip), %rax
	ret
.type get4, @function
.size get4, .-get4
/* end function get4 */

.section "dplus+name","aw"
.balign 8
.globl value5
value5:
	.quad 42
/* end data */

.section "fplus+name","ax"
.balign 16
.globl get5
get5:
	endbr64
	movq value5(%rip), %rax
	ret
.type get5, @function
.size get5, .-get5
/* end function get5 */

.section "dat@name","aw"
.balign 8
.globl value6
value6:
	.quad 43
/* end data */

.section "fat@name","ax"
.balign 16
.globl get6
get6:
	endbr64
	movq value6(%rip), %rax
	ret
.type get6, @function
.size get6, .-get6
/* end function get6 */

.section "dquote\"name","aw"
.balign 8
.globl value7
value7:
	.quad 44
/* end data */

.section "fquote\"name","ax"
.balign 16
.globl get7
get7:
	endbr64
	movq value7(%rip), %rax
	ret
.type get7, @function
.size get7, .-get7
/* end function get7 */

.section "dback\\name","aw"
.balign 8
.globl value8
value8:
	.quad 45
/* end data */

.section "fback\\name","ax"
.balign 16
.globl get8
get8:
	endbr64
	movq value8(%rip), %rax
	ret
.type get8, @function
.size get8, .-get8
/* end function get8 */

.section "dliteral\\n","aw"
.balign 8
.globl value9
value9:
	.quad 46
/* end data */

.section "fliteral\\n","ax"
.balign 16
.globl get9
get9:
	endbr64
	movq value9(%rip), %rax
	ret
.type get9, @function
.size get9, .-get9
/* end function get9 */

.section "dx\"; .globl injected; #","aw"
.balign 8
.globl value10
value10:
	.quad 47
/* end data */

.section "fx\"; .globl injected; #","ax"
.balign 16
.globl get10
get10:
	endbr64
	movq value10(%rip), %rax
	ret
.type get10, @function
.size get10, .-get10
/* end function get10 */

.section "dx\\\"; .section injected; #","aw"
.balign 8
.globl value11
value11:
	.quad 48
/* end data */

.section "fx\\\"; .section injected; #","ax"
.balign 16
.globl get11
get11:
	endbr64
	movq value11(%rip), %rax
	ret
.type get11, @function
.size get11, .-get11
/* end function get11 */

.section "d !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~","aw"
.balign 8
.globl value12
value12:
	.quad 49
/* end data */

.section "f !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~","ax"
.balign 16
.globl get12
get12:
	endbr64
	movq value12(%rip), %rax
	ret
.type get12, @function
.size get12, .-get12
/* end function get12 */

.section "dxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx","aw"
.balign 8
.globl value13
value13:
	.quad 50
/* end data */

.section "fxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx","ax"
.balign 16
.globl get13
get13:
	endbr64
	movq value13(%rip), %rax
	ret
.type get13, @function
.size get13, .-get13
/* end function get13 */

.section "d space","aw"
.balign 8
.globl equiv0
equiv0:
	.quad 91
/* end data */

.section "d\040space","aw"
.balign 8
.globl equiv1
equiv1:
	.quad 92
/* end data */

.section "d\x20space","aw"
.balign 8
.globl equiv2
equiv2:
	.quad 93
/* end data */

.section .note.GNU-stack,"",@progbits
