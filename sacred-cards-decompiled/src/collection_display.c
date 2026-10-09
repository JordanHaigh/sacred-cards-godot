/* AY7E shared collection-menu transfers and callbacks08005DCC..08006054. */
#include "gba_bios.h"
extern uint8_t gBackgroundBuffer[],gActorGraphicsBuffer[];
extern uint16_t gBgOffsetsRaw[22];
extern void UploadOam(void),UploadPalettes(void),UploadBackgroundOffsets(void),WaitForFrame(void),SetVBlankCallback(void (*)(void));
#define REG(a) (*(volatile uint16_t *)(uintptr_t)(a))
/*08005EF0*/
static void Windows(void)
{
    REG(0x04000040)=240;REG(0x04000044)=24;REG(0x04000042)=980;REG(0x04000046)=0x486F;
    REG(0x04000048)=0x1E0E;REG(0x0400004A)=0x103F;REG(0x04000050)=0x28D2;REG(0x04000052)=16;REG(0x04000054)=4;
}
static void Initialize(void)
{
    REG(0x05000000)=0;REG(0x04000000)=0;Windows();
    REG(0x04000008)=0xF04;REG(0x0400000A)=0x1F0D;REG(0x0400000C)=0x170A;REG(0x0400000E)=0x703;
    gBgOffsetsRaw[16]=gBgOffsetsRaw[4]=gBgOffsetsRaw[18]=gBgOffsetsRaw[6]=gBgOffsetsRaw[0]=0;
    gBgOffsetsRaw[10]=248;gBgOffsetsRaw[2]=253;gBgOffsetsRaw[20]=4;UploadBackgroundOffsets();
}
static void Noop(void) {}
static void Show(void) { UploadOam();UploadPalettes();REG(0x04000000)=0x7E00; }
static void Restore(void) { UploadOam();Windows();REG(0x04000000)|=0x4000;REG(0x04000000)&=0xFEFF; }
static void RestorePalettes(void) { UploadOam();UploadPalettes();Windows();REG(0x04000000)|=0x4000;REG(0x04000000)&=0xFEFF; }
static void SpritesAndPalettes(void) { UploadOam();UploadPalettes(); }
void CollectionDisplayFrame(uint8_t stage)
{
    static void (*const callbacks[])(void)={0,Initialize,Noop,Show,Noop,Noop,Noop,Restore,RestorePalettes,SpritesAndPalettes};
    if(stage && stage<10)SetVBlankCallback(callbacks[stage]);WaitForFrame();
}
/*08006054;08005EDC and0800600C use the same three transfers.*/
void UploadCollectionList(void)
{
    BiosCpuSet(gBackgroundBuffer+0x8000,(void *)0x06008000,0x2000);BiosCpuSet(gBackgroundBuffer+0xC000,(void *)0x0600C000,0x2000);
    BiosCpuSet(gActorGraphicsBuffer,(void *)0x06010000,0x2000);
}
void UploadCollectionFrame(void) { UploadPalettes();UploadCollectionList();UploadOam(); }
/*08006040*/
void CollectionIdle(void) {}

/*08015BEC differs from08005E80 by uploading OAM after the window writes.*/
static void RestoreDeck(void) { Windows();REG(0x04000000)|=0x4000;REG(0x04000000)&=0xFEFF;UploadOam(); }
/*08015B38; initialization and window values are identical to collection.*/
void DeckEditorDisplayFrame(uint8_t stage)
{
    static void (*const callbacks[])(void)={0,Initialize,Noop,Show,Noop,Noop,Noop,RestoreDeck,SpritesAndPalettes,RestorePalettes};
    if(stage && stage<10)SetVBlankCallback(callbacks[stage]);WaitForFrame();
}
/*0800602C*/
void UploadCollectionText(void)
{ BiosCpuSet(gBackgroundBuffer+0x8000,(void *)0x06008000,0x2000);BiosCpuSet(gBackgroundBuffer+0xC000,(void *)0x0600C000,0x2000); }
/*08015D9C/15DB8 preserve different transfer order.*/
void UploadDeckEditorFrame(void)
{
    BiosCpuSet(gBackgroundBuffer+0xC000,(void *)0x0600C000,0x2000);BiosCpuSet(gActorGraphicsBuffer,(void *)0x06010000,0x2000);UploadPalettes();UploadOam();
}
void UploadDeckRemoval(void)
{
    BiosCpuSet(gBackgroundBuffer+0xC000,(void *)0x0600C000,0x2000);BiosCpuSet(gActorGraphicsBuffer,(void *)0x06010000,0x2000);UploadPalettes();
    BiosCpuSet(gBackgroundBuffer+0x8000,(void *)0x06008000,0x2000);
}

/*08005EDC: unused selection of just these three background banks.*/
extern uint8_t gActorGraphicsBuffer[];
void UploadCollectionLegacyBanks(void)
{ BiosCpuSet(gBackgroundBuffer+0x8000,(void *)0x06008000,0x2000);BiosCpuSet(gBackgroundBuffer+0xC000,(void *)0x0600C000,0x2000);BiosCpuSet(gActorGraphicsBuffer,(void *)0x06010000,0x2000); }
