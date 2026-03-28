/* Test for bn.ld and bn.sd variants:
 * - bn.ld wdr, 0(gpr)
 * - bn.ld wdr, offset(gpr)
 * - bn.ld wdr, 0(gpr++)
 * - bn.sd wdr, 0(gpr)
 * - bn.sd wdr, offset(gpr)
 * - bn.sd wdr, 0(gpr++)
 */

.section .text.start

li x3, 0
li x4, 0
li x5, 0
li x6, 0
li x7, 0
li x8, 0
li x9, 0
li x10, 0
li x11, 0
li x12, 0
li x13, 0
li x14, 0
li x15, 0
li x16, 0
li x17, 0
li x18, 0
li x19, 0
li x20, 0
li x21, 0
li x22, 0
li x23, 0
li x24, 0
li x25, 0
li x26, 0
li x27, 0
li x28, 0
li x29, 0
li x30, 0
li x31, 0


la    x2, op /* x2 = 0 */
bn.ld w0, 0(x2++) /* x2 = 0, w0 = A */
bn.ld w1, 0(x2) /* x2 = 32, w1 = B */
bn.ld w2, 32(x2) /* x2 = 32, w2 = C */

la    x2, r /* x2 = 96 */
bn.sd w0, 0(x2++) /* x2 = 96, w0 = A */
bn.sd w1, 32(x2++) /* x2 = 128, w1 = B */
bn.sd w2, 32(x2++) /* x2 = 160, w2 = C */

la    x2, r /* x2 = 96 */
bn.ld w3, 0(x2++) /* x2 = 96 */
bn.ld w4, 32(x2++) /* x2 = 128 */
bn.ld w5, 32(x2++) /* x2 = 160 */

bn.xor w6, w6, w6
bn.xor w7, w7, w7
bn.xor w8, w8, w8
bn.xor w9, w9, w9
bn.xor w10, w10, w10
bn.xor w11, w11, w11
bn.xor w12, w12, w12
bn.xor w13, w13, w13
bn.xor w14, w14, w14
bn.xor w15, w15, w15
bn.xor w16, w16, w16
bn.xor w17, w17, w17
bn.xor w18, w18, w18
bn.xor w19, w19, w19
bn.xor w20, w20, w20
bn.xor w21, w21, w21
bn.xor w22, w22, w22
bn.xor w23, w23, w23
bn.xor w24, w24, w24
bn.xor w25, w25, w25
bn.xor w26, w26, w26
bn.xor w27, w27, w27
bn.xor w28, w28, w28
bn.xor w29, w29, w29
bn.xor w30, w30, w30
bn.xor w31, w31, w31

ecall

.data
.balign 32
op:
    .quad 0xAAAAAAAAAAAAAAAA
    .quad 0xAAAAAAAAAAAAAAAA
    .quad 0xAAAAAAAAAAAAAAAA
    .quad 0xAAAAAAAAAAAAAAAA
    .quad 0xBBBBBBBBBBBBBBBB
    .quad 0xBBBBBBBBBBBBBBBB
    .quad 0xBBBBBBBBBBBBBBBB
    .quad 0xBBBBBBBBBBBBBBBB
    .quad 0xCCCCCCCCCCCCCCCC
    .quad 0xCCCCCCCCCCCCCCCC
    .quad 0xCCCCCCCCCCCCCCCC
    .quad 0xCCCCCCCCCCCCCCCC

r:
    .zero 128