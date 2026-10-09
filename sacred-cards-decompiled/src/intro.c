/* AY7E copyright/company-logo sequence0801950C..08019B7C.
 * 120-frame holds, four-frame fade steps, and ignored input polling retained. */
#include "gba_bios.h"
extern uint8_t gBackgroundBuffer[],gPaletteBuffer[],gIntroFade[2]; /*0201EE58*/
extern uint16_t gBgOffsetsRaw[22],gKeysPressed;
extern void UploadMenuGraphics(void),UploadPalettes(void),UploadBackgroundOffsets(void),WaitForFrame(void),SetVBlankCallback(void (*)(void)),PollMenuRepeat(void);
#define ROM(a) ((const void *)(uintptr_t)(a))
#define REG(a) (*(volatile uint16_t *)(uintptr_t)(a))
/*0801950C/19584/19534/19598*/
void InitializeIntroFadeFromBlack(void) { REG(0x04000050)=0x3FFF;gIntroFade[1]=16;gIntroFade[0]=0; }
void InitializeIntroFadeToBlack(void) { gIntroFade[0]=gIntroFade[1]=0; }
void FadeIntroFromBlack(void)
{ while(gIntroFade[1]) { if(++gIntroFade[0]>3) { --gIntroFade[1];gIntroFade[0]=0; }REG(0x04000054)=gIntroFade[1];WaitForFrame(); } }
void FadeIntroToBlack(void)
{ while(gIntroFade[1]<16) { if(++gIntroFade[0]>3) { ++gIntroFade[1];gIntroFade[0]=0; }REG(0x04000054)=gIntroFade[1];WaitForFrame(); } }
/*08019694: the caller discards this input; the screens cannot be skipped.*/
uint16_t ReadIntroInput(void)
{ PollMenuRepeat();uint16_t key=0;for(unsigned bit=1;bit<1024;bit<<=1)if(gKeysPressed&bit)key=bit;return key; }
/*08019B60*/
void IntroBlankCallback(void) { REG(0x04000000)=0x80;REG(0x04000050)=REG(0x04000052)=REG(0x04000054)=0; }
/*08019998/199EC/19A3C/19A90: sequential volatile register writes retained.*/
static void ShowIntroLayer(uint16_t map,uint16_t tiles)
{
    UploadPalettes();gBgOffsetsRaw[6]=gBgOffsetsRaw[0]=0;UploadBackgroundOffsets();
    REG(0x0400000E)&=0xE0F3;REG(0x0400000E)|=map;REG(0x0400000E)|=tiles;REG(0x04000000)=0x800;
}
void IntroCopyrightCallback(void) { ShowIntroLayer(0x1C00,12); }
void IntroFirstLogoCallback(void) { ShowIntroLayer(0x1F00,0); }
void IntroSecondLogoCallback(void) { ShowIntroLayer(0x1E00,4); }
void IntroAlternateLogoCallback(void) { ShowIntroLayer(0x1D00,8); }
/*08019AE4, unused by the stock three-screen sequence.*/
void IntroCombinedLogoCallback(void)
{
    UploadPalettes();gBgOffsetsRaw[2]=gBgOffsetsRaw[20]=gBgOffsetsRaw[6]=gBgOffsetsRaw[0]=0;UploadBackgroundOffsets();
    REG(0x0400000C)&=0xE0F3;REG(0x0400000C)|=0x1F00;REG(0x0400000C)|=0;
    REG(0x0400000E)&=0xE0F3;REG(0x0400000E)|=0x1E00;REG(0x0400000E)|=0;REG(0x04000000)=0xC00;
}
/*080196D4/19704/19744/1975C/197B8, with the two native no-op calls.*/
void LoadIntroGraphics(void)
{
    SetVBlankCallback(IntroBlankCallback);WaitForFrame();
    BiosCpuSet(ROM(0x08D366AC),gBackgroundBuffer+0xC000,0x1E0);
    for(unsigned row=0;row<20;++row)BiosCpuSet(ROM(0x08D36A6C+row*64),gBackgroundBuffer+0xE000+row*64,0x20);
    BiosCpuSet(ROM(0x08D3716C),gBackgroundBuffer,0x1000);
    for(unsigned row=0;row<20;++row)BiosCpuSet(ROM(0x08D3792C+row*64),gBackgroundBuffer+0xF800+row*64,0x20);
    BiosCpuSet(ROM(0x08D3816C),gBackgroundBuffer+0x4000,0x7E0);
    for(unsigned row=0;row<20;++row)BiosCpuSet(ROM(0x08D3912C+row*64),gBackgroundBuffer+0xF000+row*64,0x20);
    UploadMenuGraphics();BiosCpuSet(ROM(0x08D3668C),gPaletteBuffer,0x10);
}
/*080195E8*/
void RunIntro(void)
{
    LoadIntroGraphics();SetVBlankCallback(IntroCopyrightCallback);WaitForFrame();for(unsigned i=0;i<120;++i)WaitForFrame();
    BiosCpuSet(ROM(0x08D36F6C),gPaletteBuffer,0x100);SetVBlankCallback(IntroFirstLogoCallback);InitializeIntroFadeFromBlack();WaitForFrame();FadeIntroFromBlack();
    for(unsigned i=0;i<120;++i) { (void)ReadIntroInput();WaitForFrame(); }InitializeIntroFadeToBlack();FadeIntroToBlack();
    BiosCpuSet(ROM(0x08D3812C),gPaletteBuffer,0x20);SetVBlankCallback(IntroSecondLogoCallback);InitializeIntroFadeFromBlack();WaitForFrame();FadeIntroFromBlack();
    for(unsigned i=0;i<120;++i) { (void)ReadIntroInput();WaitForFrame(); }InitializeIntroFadeToBlack();FadeIntroToBlack();InitializeIntroFadeFromBlack();REG(0x04000054)=gIntroFade[1];
}

/*08019818/198F8: unused alternate logo/map family retained in the ROM.*/
void SelectIntroAlternateMap(uint8_t selection)
{
    uint8_t index=selection-1;unsigned at=index>=1 && index<=4?0x08D400CC+index*0x500:0x08D400CC;
    for(unsigned row=0;row<20;++row)BiosCpuSet(ROM(at+row*64),gBackgroundBuffer+0xF800+row*64,0x20);
}
void LoadIntroAlternateGraphics(void)
{
    BiosCpuSet(ROM(0x08D39B2C),gBackgroundBuffer,0x1000);BiosCpuSet(ROM(0x08D3BB2C),gBackgroundBuffer+0x2000,0x1000);
    BiosCpuSet(ROM(0x08D3DB2C),gBackgroundBuffer+0x4000,0x1000);BiosCpuSet(ROM(0x08D3FB2C),gBackgroundBuffer+0x6000,0x50);
    for(unsigned row=0;row<20;++row)BiosCpuSet(ROM(0x08D3FBCC+row*64),gBackgroundBuffer+0xF000+row*64,0x20);
    SelectIntroAlternateMap(1);
}

/*0801979C/197F8: palette callbacks split out by the original logo loader.*/
void LoadIntroFirstLogoPalette(void) { BiosCpuSet(ROM(0x08D36F6C),gPaletteBuffer,0x100); }
void LoadIntroSecondLogoPalette(void) { BiosCpuSet(ROM(0x08D3812C),gPaletteBuffer,0x20); }
/*08019810/19814/19994: retained empty intro hooks.*/
void IntroUnusedNoop(void) {}
