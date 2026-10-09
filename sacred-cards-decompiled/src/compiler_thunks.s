/*08038E24..08038E5C: compiler indirect-call veneers. The caller BL sets LR;
 * each veneer exchanges ARM/Thumb state according to the destination bit0.
 * These entries have register contracts rather than C parameter signatures. */
.syntax unified
.cpu arm7tdmi
.thumb
.text
.macro INDIRECT_CALL number, register
.global RomCallViaR\number
.type RomCallViaR\number,%function
.thumb_func
RomCallViaR\number:
    bx \register
    nop
.size RomCallViaR\number,.-RomCallViaR\number
.endm
INDIRECT_CALL 0,r0
INDIRECT_CALL 1,r1
INDIRECT_CALL 2,r2
INDIRECT_CALL 3,r3
INDIRECT_CALL 4,r4
INDIRECT_CALL 5,r5
INDIRECT_CALL 6,r6
INDIRECT_CALL 7,r7
INDIRECT_CALL 8,r8
INDIRECT_CALL 9,r9
INDIRECT_CALL 10,r10
INDIRECT_CALL 11,r11
INDIRECT_CALL 12,r12
INDIRECT_CALL 13,sp
INDIRECT_CALL 14,lr
