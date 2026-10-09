/* AY7E title/new-game/continue screens08022184..08022984.
 * The credits entry08000224 is a separate screen. */
#include <stdint.h>
#include "gba_bios.h"
#include "save_storage.h"
extern uint8_t gBackgroundBuffer[],gPaletteBuffer[],gTitleScratch[4]; /*02018800*/
extern uint16_t gOamBuffer[128][4],gBgOffsetsRaw[22],gKeysPressed,gKeysHeld,gPasswordRepeated;
extern uint8_t gPasswordRepeatTimer;
extern void RenderBitmapString(void *,const uint8_t *,uint16_t),CopyObjectTileRows(uint8_t,const uint8_t *,uint16_t);
extern void UploadMenuGraphics(void),ClearMenuGraphics(void),UploadOam(void),UploadPalettes(void),UploadBackgroundOffsets(void);
extern void WaitForFrame(void),SetVBlankCallback(void (*)(void)),PlayGameAudio(uint32_t),FadeGameMusic(uint16_t);
extern uint8_t NextRandomByte(void);
#define ROM(a) ((const uint8_t *)(uintptr_t)(a))
#define REG(a) (*(volatile uint16_t *)(uintptr_t)(a))
static uint16_t U16(const uint8_t *p) { return p[0]|(uint16_t)p[1]<<8; }
static uint32_t U32(const uint8_t *p) { return U16(p)|(uint32_t)U16(p+2)<<16; }
static void W16(uint8_t *p,uint16_t v) { p[0]=v;p[1]=v>>8; }
static void UploadBlend(void) { REG(0x04000050)=gBgOffsetsRaw[8];REG(0x04000052)=gBgOffsetsRaw[14];REG(0x04000054)=gBgOffsetsRaw[12]; }
static void Frame(void (*callback)(void)) { SetVBlankCallback(callback);WaitForFrame(); }
/*08018DA8: menu repeat reaches zero and repeats every subsequent frame.*/
void PollMenuRepeat(void)
{
    gPasswordRepeated=gKeysPressed&1023;
    if(gPasswordRepeated) { gPasswordRepeated=gKeysPressed;gPasswordRepeatTimer=10; }
    else if(!gPasswordRepeatTimer)gPasswordRepeated=gKeysHeld;else --gPasswordRepeatTimer;
}
/*080223AC*/
static uint16_t ReadTitleInput(void)
{ PollMenuRepeat();uint16_t key=0;for(unsigned bit=1;bit<1024;bit<<=1)if(gKeysPressed&bit)key=bit;return key; }
/*080225C4*/
static void CopyTitleSprites(unsigned at,unsigned count,uint32_t descriptor)
{
    const uint8_t *parts=ROM(U32(ROM(descriptor)+4));
    for(unsigned i=0;i<count;++i) { uint16_t *o=gOamBuffer[at+i];o[0]=U16(parts+i*8);o[1]=U16(parts+i*8+2);o[2]=U16(parts+i*8+4)|0x400;o[3]=0; }
}
/*080224B8/22500/22564*/
static void DrawTitleChoice(unsigned choice,int hasSave)
{
    if(!hasSave) { CopyTitleSprites(0,2,0x080D3560);CopyTitleSprites(2,1,0x080D35A0);gOamBuffer[2][0]|=0x400; }
    else {
        CopyTitleSprites(0,2,choice?0x080D3580:0x080D3560);CopyTitleSprites(2,2,choice?0x080D3570:0x080D3590);
        CopyTitleSprites(4,1,choice?0x080D35B0:0x080D35A0);gOamBuffer[4][0]|=0x400;
    }
}
/*08022600/22744/22774*/
static void LoadTitleGraphics(void)
{
    BiosCpuSet(ROM(0x08D41B48),gBackgroundBuffer,0x04001000);BiosCpuSet(ROM(0x08D45B48),gBackgroundBuffer+0x4000,0x04001000);
    BiosCpuSet(ROM(0x08D49B48),gBackgroundBuffer+0x8000,0x04000590);RenderBitmapString(gBackgroundBuffer+0xC000,ROM(0x080D35C0),0x4FF);
    for(unsigned row=0;row<20;++row) {
        BiosCpuSet(ROM(0x08D4B388)+row*64,gBackgroundBuffer+0xF800+row*64,0x04000010);
        uint32_t zero=0;BiosCpuSet(&zero,gBackgroundBuffer+0xF000+row*64,0x0500000F);
    }
    for(unsigned i=0;i<4;++i) { W16(gBackgroundBuffer+0xF2DC+i*2,i+2);W16(gBackgroundBuffer+0xF31C+i*2,i+6); }
    for(unsigned i=0;i<13;++i)for(unsigned row=0;row<5;++row)W16(gBackgroundBuffer+(0x78A9+row*32+i)*2,10+row*13+i);
    BiosCpuSet(ROM(0x08D4B188),gPaletteBuffer,0x04000080);CopyObjectTileRows(0,ROM(0x080D1500),0x100);
    BiosCpuSet(ROM(0x080D3500),gPaletteBuffer+0x200,0x04000018);
    for(unsigned i=0;i<128;++i) { gOamBuffer[i][0]=0xA0;gOamBuffer[i][1]=0xF0;gOamBuffer[i][2]=0xC00;gOamBuffer[i][3]=0; }
    W16(gTitleScratch,0);W16(gTitleScratch+2,0);
}
/*080228A4*/
static void InitializeTitleDisplay(void)
{
    REG(0x05000000)=0;REG(0x04000000)=0;gBgOffsetsRaw[8]=0x8D8;gBgOffsetsRaw[14]=0x1000;gBgOffsetsRaw[12]=0;UploadBlend();
    REG(0x04000040)=0x40B8;REG(0x04000044)=0x2070;REG(0x04000048)=0x3F;REG(0x0400004A)=0x1F;
    REG(0x04000008)=0x1E8C;REG(0x0400000E)=0x1F83;
    gBgOffsetsRaw[16]=gBgOffsetsRaw[4]=gBgOffsetsRaw[6]=gBgOffsetsRaw[0]=0;UploadBackgroundOffsets();
}
static void ShowTitle(void) { UploadPalettes();REG(0x04000000)=0x1800; }
/*080227B8 retains native zero timer assignment (the else path is normally unused).*/
static void StepTitlePulse(void)
{
    if(!U16(gTitleScratch+2)) {
        unsigned phase=U16(gTitleScratch);if(phase>29)phase=0;
        gBgOffsetsRaw[14]=(U16(ROM(0x08D4BC00)+phase*2)&15)|0x1000;W16(gTitleScratch+2,0);W16(gTitleScratch,phase+1);
    }else W16(gTitleScratch+2,U16(gTitleScratch+2)+1);
}
static void ShowOverwriteWarning(void) { REG(0x04000000)|=0x2100;gBgOffsetsRaw[12]=10;UploadBlend(); }
static void HideOverwriteWarning(void) { REG(0x04000000)&=0xDEFF;gBgOffsetsRaw[12]=0;UploadBlend(); }
static void DrawOverwriteChoice(unsigned cancel)
{ W16(gBackgroundBuffer+0xF2DA,cancel?1:0);W16(gBackgroundBuffer+0xF31A,cancel?0:1); }
static void UploadTitleMap(void) { BiosCpuSet(gBackgroundBuffer+0xC000,(void *)0x0600C000,0x2000); }
/*080222EC: cancel is the initial selection.*/
static uint8_t ConfirmNewGame(void)
{
    uint8_t cancel=1;PlayGameAudio(201);Frame(ShowOverwriteWarning);DrawOverwriteChoice(1);UploadTitleMap();
    for(;;) {
        uint16_t input=ReadTitleInput();if(input==2) { cancel=1;break; }if(input==1)break;
        if(input==64 || input==128) { cancel=input==64;DrawOverwriteChoice(cancel);PlayGameAudio(54); }
        WaitForFrame();UploadTitleMap();
    }
    if(cancel)PlayGameAudio(56);Frame(HideOverwriteWarning);return cancel;
}
/*08022424: 16 brightness updates spaced four frames apart, exit immediately
 * after the frame containing the sixteenth update (61 frames total).*/
static void FadeTitle(void)
{
    unsigned a=gBgOffsetsRaw[14]&31,b=(gBgOffsetsRaw[14]>>8)&31,brightness=0,phase=0;
    do {
        if(!phase) { if(a)--a;if(b)--b;gBgOffsetsRaw[14]=(b<<8)|a;gBgOffsetsRaw[12]=brightness++&31; }
        phase=phase<3?phase+1:0;Frame(UploadBlend);
    }while(brightness<16);
}
/*080221C0/2222C. SELECT toggles new/continue; B returns to continue.*/
uint8_t RunTitleMenu(uint8_t hasSave)
{
    uint8_t choice=hasSave?1:0;LoadTitleGraphics();Frame(InitializeTitleDisplay);DrawTitleChoice(choice,hasSave);
    UploadMenuGraphics();UploadOam();SetVBlankCallback(ShowTitle);PlayGameAudio(1);WaitForFrame();
    for(;;) {
        NextRandomByte();uint16_t input=ReadTitleInput();
        if(input==1) { if(hasSave && !choice && ConfirmNewGame())continue;FadeGameMusic(1);break; }
        if(hasSave && (input==2 || input==4)) {
            PlayGameAudio(54);choice=input==2?1:choice!=1;DrawTitleChoice(choice,1);UploadOam();Frame(UploadBlend);
        }else { StepTitlePulse();Frame(UploadBlend); }
    }
    StepTitlePulse();Frame(UploadBlend);PlayGameAudio(210);FadeTitle();return choice;
}
/*08022184. Save payload and title animation workspace intentionally alias.*/
void RunTitleScreen(void)
{
    struct SaveStorage storage={(volatile uint8_t *)0x0E000000,(uint8_t *)0x02018800,(volatile uint16_t *)0x04000204};
    uint8_t choice=RunTitleMenu((uint8_t)DetectSaveState(&storage)!=0);
    if(!choice)InitializeSaveStorage(&storage);
    else { uint8_t state=DetectSaveState(&storage);PrepareSaveState(&storage,state);LoadPrimarySave(&storage); }
    ClearMenuGraphics();Frame(UploadPalettes);
}
