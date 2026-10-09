/* AY7E dormant diagnostic label screen080169A8..16CE4. The source map
 * reads32 halfwords per row from a30-halfword stride, retaining the original
 * two-tile overlap. No interactive loop was present at this entry. */
#include "gba_bios.h"
extern uint8_t gBackgroundBuffer[],gActorGraphicsBuffer[],gPaletteBuffer[],gDecimalDigits[5];
extern uint16_t gOamBuffer[128][4],gBgOffsetsRaw[22],gDiagnosticNumber; /*02020D20*/
extern void RenderBitmapString(void *,const uint8_t *,uint16_t),FormatDecimalDigits(uint16_t,uint8_t),UploadOam(void),WaitForFrame(void);
#define ROM(a) ((const uint8_t *)(uintptr_t)(a))
#define REG(a) (*(volatile uint16_t *)(uintptr_t)(a))
static void W16(uint8_t *p,uint16_t v) { p[0]=v;p[1]=v>>8; }
/*08016BCC*/
void DrawDiagnosticTilemap(void)
{
    for(unsigned row=0;row<20;++row)BiosCpuSet(ROM(0x080B6AA0)+row*60,gBackgroundBuffer+0xF000+row*64,32);
    FormatDecimalDigits(gDiagnosticNumber,0);for(unsigned i=0;i<3;++i)W16(gBackgroundBuffer+0xF084+i*2,gDecimalDigits[i+2]|0x30F0);
}
/*08016A38*/
void DrawDiagnosticLabels(void)
{
    static const uint32_t strings[15]={0x080B7008,0x080B6F50,0x080B6F5C,0x080B6F68,0x080B6F70,0x080B6F78,0x080B6F88,0x080B6F94,0x080B6FA8,0x080B6FC0,0x080B6FD0,0x080B6FE0,0x080B6FEC,0x080B6FFC,0x080B7020};
    static const unsigned offsets[14]={0x1E00,0x20,0xC0,0x1A0,0x200,0x260,0x300,0x380,0x4A0,0x5E0,0x6A0,0x780,0x820,0x8E0};
    REG(0x0400000C)=0x5E02;for(unsigned i=0;i<14;++i)RenderBitmapString(gBackgroundBuffer+offsets[i],ROM(strings[i]),1);RenderBitmapString(gActorGraphicsBuffer,ROM(strings[14]),1);
    W16(gPaletteBuffer,0);W16(gPaletteBuffer+0x60,0);W16(gPaletteBuffer+0x62,0x7FFF);W16(gPaletteBuffer+0x200,0);W16(gPaletteBuffer+0x202,0x7FFF);DrawDiagnosticTilemap();
}
/*08016C58/16CB4*/
void UploadDiagnosticScreen(void)
{ BiosCpuSet(gBackgroundBuffer,(void *)0x06000000,0x2000);BiosCpuSet(gActorGraphicsBuffer,(void *)0x06010000,0x200);BiosCpuSet(gBackgroundBuffer+0xF000,(void *)0x0600F000,0x400);BiosCpuSet(gPaletteBuffer,(void *)0x05000000,0x200);UploadOam(); }
void UploadDiagnosticBackground(void)
{ BiosCpuSet(gBackgroundBuffer,(void *)0x06000000,0x2000);BiosCpuSet(gBackgroundBuffer+0xF000,(void *)0x0600F000,0x400); }
/*080169A8*/
void RunDiagnosticScreen(void)
{
    uint16_t zero=0;BiosCpuSet(&zero,gBackgroundBuffer,0x01001000);BiosCpuSet(&zero,gBackgroundBuffer+0xF000,0x01000400);BiosCpuSet(&zero,gOamBuffer,0x01000200);
    gBgOffsetsRaw[8]=gBgOffsetsRaw[14]=gBgOffsetsRaw[12]=0;REG(0x04000050)=REG(0x04000052)=REG(0x04000054)=0;
    REG(0x04000000)=0x1400;REG(0x0400001A)=REG(0x04000018)=0;DrawDiagnosticLabels();UploadDiagnosticScreen();WaitForFrame();
}
