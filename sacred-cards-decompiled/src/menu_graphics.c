/* Shared menu buffer clearing and transfers, 08022EE0..08023040. */
#include "gba_bios.h"
extern uint8_t gBackgroundBuffer[],gActorGraphicsBuffer[],gPaletteBuffer[];
extern uint16_t gOamBuffer[128][4];
void ClearMenuGraphics(void)
{
    uint16_t zero=0;
    for(unsigned i=0;i<4;++i)BiosCpuSet(&zero,gBackgroundBuffer+i*0x4000,0x01002000);
    for(unsigned i=0;i<2;++i)BiosCpuSet(&zero,gActorGraphicsBuffer+i*0x4000,0x01002000);
    BiosCpuSet(&zero,gPaletteBuffer,0x01000100);BiosCpuSet(&zero,gPaletteBuffer+0x200,0x01000100);
    BiosCpuSet(&zero,gOamBuffer,0x01000200);
}
void UploadMenuBackgroundGraphics(void) /*08028568, also wrapper08016228*/
{
    for(unsigned i=0;i<4;++i)BiosCpuSet(gBackgroundBuffer+i*0x4000,(void *)(uintptr_t)(0x06000000+i*0x4000),0x2000);
}
void UploadMenuGraphics(void) /*080285C8*/
{
    UploadMenuBackgroundGraphics();
    for(unsigned i=0;i<2;++i)BiosCpuSet(gActorGraphicsBuffer+i*0x4000,(void *)(uintptr_t)(0x06010000+i*0x4000),0x2000);
}
