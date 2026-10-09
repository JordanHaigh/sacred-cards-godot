/* AY7E ARM reset/IRQ mode transitions080000C0..08000218. This is the
 *processor-specific assembly boundary of the recovered C game. Not linked
 *to a ROM here; addresses in the native installation remain documented. */
.syntax unified
.cpu arm7tdmi
.arm
.text
.align 2
.global ResetEntry
.type ResetEntry,%function
ResetEntry:
    mov r0,#0x12
    msr cpsr_fc,r0
    ldr sp,=0x03007FA0
    mov r0,#0x1F
    msr cpsr_fc,r0
    ldr sp,=0x03007F00
    ldr r1,=0x03007FFC
    ldr r0,=NativeIrqEntry
    str r0,[r1]
    ldr r1,=RunGame
    mov lr,pc
    bx r1
    b ResetEntry
.size ResetEntry,.-ResetEntry

.global NativeIrqEntry
.type NativeIrqEntry,%function
NativeIrqEntry:
    mov r3,#0x04000000
    add r3,r3,#0x200
    ldr r12,[r3]
    mrs r0,spsr
    push {r0,r3,r12,lr}
    and r1,r12,r12,lsr #16
    mov r2,#0
    ands r0,r1,#1
    bne .Lirq_selected
    add r2,r2,#4
    ands r0,r1,#2
    bne .Lirq_selected
    add r2,r2,#4
    ands r0,r1,#4
    bne .Lirq_selected
    add r2,r2,#4
    ands r0,r1,#8
    bne .Lirq_selected
    add r2,r2,#4
    ands r0,r1,#0x10
    bne .Lirq_selected
    add r2,r2,#4
    ands r0,r1,#0x20
    bne .Lirq_selected
    add r2,r2,#4
    ands r0,r1,#0x40
    bne .Lirq_selected
    add r2,r2,#4
    ands r0,r1,#0x80
    bne .Lirq_selected
    add r2,r2,#4
    ands r0,r1,#0x100
    bne .Lirq_selected
    add r2,r2,#4
    ands r0,r1,#0x200
    bne .Lirq_selected
    add r2,r2,#4
    ands r0,r1,#0x400
    bne .Lirq_selected
    add r2,r2,#4
    ands r0,r1,#0x800
    bne .Lirq_selected
    add r2,r2,#4
    ands r0,r1,#0x1000
    bne .Lirq_selected
    add r2,r2,#4
    ands r0,r1,#0x2000
.Lgamepak_halt:
    bne .Lgamepak_halt
.Lirq_selected:
    strh r0,[r3,#2]
    mov r1,#0x2000
    and r1,r1,r12
    strh r1,[r3]
    mrs r3,cpsr
    bic r3,r3,#0xDF
    orr r3,r3,#0x1F
    msr cpsr_fc,r3
    ldr r1,=.Lirq_callbacks
    add r1,r1,r2
    ldr r0,[r1]
    push {lr}
    add lr,pc,#0
    bx r0
    pop {lr}
    mrs r3,cpsr
    bic r3,r3,#0xDF
    orr r3,r3,#0x92
    msr cpsr_fc,r3
    pop {r0,r3,r12,lr}
    strh r12,[r3]
    msr spsr_fc,r0
    bx lr
.size NativeIrqEntry,.-NativeIrqEntry
.align 2
.Lirq_callbacks:
    .word ServiceVBlank
    .rept 13
    .word IdleVBlankCallback
    .endr
.ltorg
