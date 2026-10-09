/* AY7E initialization03958..03B38 and IRQ/VBlank service000FC..00218.
 * The C IRQ dispatcher expresses the native priority, acknowledgement and IE
 *masking. CPU mode/SPSR/stack entry is retained in startup.s as ARM assembly. */
#include <stdint.h>
#define REG16(a) (*(volatile uint16_t *)(uintptr_t)(a))
#define REG32(a) (*(volatile uint32_t *)(uintptr_t)(a))
extern volatile uint16_t gFrameInterruptFlags;
extern void (*volatile gVBlankCallback)(void);
extern void IdleVBlankCallback(void),m4aSoundVSync(void),m4aSoundMain(void);
static void Dma3(const void *source,void *destination,uint32_t control)
{
    REG32(0x040000D4)=(uintptr_t)source;REG32(0x040000D8)=(uintptr_t)destination;REG32(0x040000DC)=control;(void)REG32(0x040000DC);
}
/*08003968: preserve the upper512 bytes of IWRAM containing native stacks.*/
void ClearGameRam(void)
{
    volatile uint32_t zero=0;Dma3((const void *)&zero,(void *)0x02000000,0x85010000);
    zero=0;Dma3((const void *)&zero,(void *)0x03000000,0x85001F80);
}
/*080039B8/03A44*/
void ClearHardwareVram(void) { volatile uint16_t zero=0;Dma3((const void *)&zero,(void *)0x06000000,0x8100C000); }
void ClearHardwarePalette(void) { volatile uint16_t zero=0;Dma3((const void *)&zero,(void *)0x05000000,0x81000200); }
/*080039E0: disabled objects and identity affine matrices.*/
void ClearHardwareOam(void)
{
    volatile uint16_t *o=(volatile uint16_t *)0x07000000;
    for(unsigned group=0;group<32;++group)for(unsigned part=0;part<4;++part,o+=4) { o[0]=0x200;o[1]=o[2]=0;o[3]=(part==0 || part==3)?0x100:0; }
}
/*080039A4/03958*/
void ClearHardwareGraphics(void) { ClearHardwareVram();ClearHardwareOam();ClearHardwarePalette(); }
void ClearGameMemory(void) { ClearGameRam();ClearHardwareGraphics(); }
/*08003B98/03BAC*/
void ClearFrameInterruptFlag(void) { gFrameInterruptFlags&=0xFFFE; }
void SignalFrameInterrupt(void) { REG16(0x04000202)=1;gFrameInterruptFlags|=1; }
/*08003B70: audio precedes the one-shot VBlank callback.*/
void ServiceVBlank(void)
{ m4aSoundVSync();m4aSoundMain();if(gVBlankCallback)gVBlankCallback();SignalFrameInterrupt(); }
/*08003B18: native installation copies0x800 bytes, including the IRQ body
 *and adjacent bytes. A host/native port may install DispatchGameInterrupt.*/
void InstallNativeInterruptHandler(void)
{
    ClearFrameInterruptFlag();gVBlankCallback=IdleVBlankCallback;
    Dma3((const void *)0x080000FC,(void *)0x03000400,0x84000200);REG32(0x03007FFC)=0x03000400;
}
/*080000FC: one source per dispatch, lowest enabled bit first. GamePak IRQ
 *halts in place. The no-pending path still invokes table slot13.*/
void DispatchGameInterrupt(void)
{
    uint16_t saved=REG16(0x04000200),pending=saved&REG16(0x04000202),selected=0;unsigned slot=0;
    while(slot<13 && !(pending&(1u<<slot)))++slot;
    if(slot<13)selected=1u<<slot;else if(pending&0x2000)for(;;) {}
    REG16(0x04000202)=selected;REG16(0x04000200)=saved&0x2000;
    const uint32_t *callbacks=(const uint32_t *)0x0807F420;((void (*)(void))(uintptr_t)callbacks[slot])();REG16(0x04000200)=saved;
}
/*08035AC0: the second graphics clear is present in the original call chain.*/
void InitializeGameHardware(void)
{ REG16(0x04000204)=0x4014;ClearGameMemory();ClearHardwareGraphics();InstallNativeInterruptHandler(); }
/*08003A6C/03A84/03A9C/03AB4/03AF0. Fixed8 multiplication/division truncate
 *toward zero, then retain the native low16/low32 result. Divide-by-zero
 *helpers in this ROM return zero. */
int16_t MultiplyFixed8Short(int16_t a,int16_t b) { return (int16_t)(((int32_t)a*b)/256); }
int16_t DivideFixed8Short(int16_t a,int16_t b) { return b?(int16_t)(((int32_t)a*256)/b):0; }
int16_t ReciprocalFixed8Short(int16_t a) { return a?(int16_t)(65536/a):0; }
int32_t MultiplyFixed8(int32_t a,int32_t b) { return (int32_t)(((int64_t)a*b)/256); }
int32_t DivideFixed8(int32_t a,int32_t b) { return b?(int32_t)(((int64_t)a*256)/b):0; }
