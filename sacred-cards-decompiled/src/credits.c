/* AY7E credits08000224..08000934. This screen intentionally never returns.
 * Scene maps read31 halfwords from a30-halfword source stride on initial load.
 * Shared02018800 state and palette/offset arithmetic retain native wrapping. */
#include "gba_bios.h"
extern uint8_t gCreditsScratch[0x4314],gLanguage,gBackgroundBuffer[],gPaletteBuffer[];
extern uint16_t gCreditsTextRow,gBgOffsetsRaw[22]; /* Text row at0201CB20 is native halfword. */
extern void ClearMenuGraphics(void),UploadMenuGraphics(void),UploadOam(void),UploadPalettes(void),UploadBackgroundOffsets(void),ResetGameKeys(void);
extern void RenderBitmapString(void *,const uint8_t *,uint16_t),WaitForFrame(void),SetVBlankCallback(void (*)(void)),PlayGameAudio(uint32_t);
#define ROM(a) ((const uint8_t *)(uintptr_t)(a))
#define REG(a) (*(volatile uint16_t *)(uintptr_t)(a))
#define BYTE(a) (*(volatile uint8_t *)(uintptr_t)(a))
#define S gCreditsScratch
static uint16_t U16(const uint8_t *p) { return p[0]|(uint16_t)p[1]<<8; }
static uint32_t U32(const uint8_t *p) { return U16(p)|(uint32_t)U16(p+2)<<16; }
static void W16(unsigned at,uint16_t v) { S[at]=v;S[at+1]=v>>8; }
static void Blend(void) { REG(0x04000050)=gBgOffsetsRaw[8];REG(0x04000052)=gBgOffsetsRaw[14];REG(0x04000054)=gBgOffsetsRaw[12]; }
static void UploadBackground(unsigned block) { BiosCpuSet(gBackgroundBuffer+block*0x4000,(void *)(uintptr_t)(0x06000000+block*0x4000),0x2000); }
static void SceneMap(uint32_t address,unsigned offset,unsigned count)
{ for(unsigned y=0;y<32;++y)BiosCpuSet(ROM(address)+y*60,gBackgroundBuffer+offset+y*64,count); }
static void SecondMapBank(void) { uint16_t *p=(uint16_t *)(gBackgroundBuffer+0xF000);for(unsigned i=0;i<1024;++i)p[i]|=0x200; }
/*08000358*/
void InitializeCredits(void)
{ for(unsigned i=0;i<0x4314;++i)S[i]=0;W16(8,0xFFB0);W16(10,0xFFDC);S[1]=48;S[2]=36; }
/*0800038C; chapter19 stays on screen, language5 skips chapters17/18.*/
void StepCreditsText(void)
{
    unsigned page=S[4],tick=U16(S+6),layout=ROM(0x08D30544)[page];
    if(layout<3) { static const uint16_t x[]={0xFFF8,0xFFB0,0xFF58},y[]={0xFFDC,0xFFDC,0xFF98};static const uint8_t wx[]={8,48,71},wy[]={36,36,151};W16(8,x[layout]);W16(10,y[layout]);S[1]=wx[layout];S[2]=wy[layout]; }
    if(!tick) {
        RenderBitmapString(gBackgroundBuffer+0x8020,ROM(U32(ROM(0x08D30310)+page*8)),0x801);
        RenderBitmapString(gBackgroundBuffer+0xA000,ROM(U32(ROM(0x08D30314)+page*8)),0x801);gCreditsTextRow=0;
    }else if(tick<6) {
        if(gCreditsTextRow<5)RenderBitmapString(gBackgroundBuffer+0x8420+gCreditsTextRow*0x580,ROM(U32(ROM(0x08D303B0)+(page*5+gCreditsTextRow)*4)),0x901);
        ++gCreditsTextRow;
    }else if(tick==6)BiosCpuSet(gBackgroundBuffer+0x8000,(void *)0x06008000,0x04000980);
    else if(tick<200) { if(S[3]<19)++S[3]; }
    else if(tick<300 && page!=19 && S[3])--S[3];
    if(tick==U16(ROM(0x08D30558)+gLanguage*2)) {
        W16(6,0);if(page<19) { if(gLanguage==5 && page==16) { S[4]=19;return; }if(gLanguage==5 && page>15)return;++S[4]; }
    }else W16(6,tick+1);
}
/*0800053C: load alternating backgrounds, then upload at native frame phases.*/
void StepCreditsBackdrop(void)
{
    static const uint32_t tiles[]={0x0803F128,0x08041D44,0x08044B54,0x080477A0,0x0804A26C,0x0804CFEC};
    static const uint32_t maps[]={0x08051648,0x08051DC8,0x08052548,0x08052CC8,0x08053448,0x08053BC8};
    unsigned phase=U16(S+12),frame=U16(S+14);
    if(phase>=2 && phase<=0x502 && (phase-2)%256==0) {
        unsigned index=(phase-2)/256,second=index&1;BiosLz77UnpackWram(ROM(tiles[index]),gBackgroundBuffer+second*0x4000);
        SceneMap(maps[index],second?0xF000:0xE800,30);if(second)SecondMapBank();
    }
    if(frame%0x600==0x300)UploadBackground(0);
    if(frame%0x600==0x303)UploadBackground(3);
    if(frame%0x600==0)UploadBackground(1);
    if(frame%0x600==3)UploadBackground(3);
    if(phase!=0x760 && frame%3==0)W16(12,phase+1);
}
/*080007FC*/
void CreditsFrameCallback(void)
{
    gBgOffsetsRaw[20]=0;gBgOffsetsRaw[2]=U16(S+12);gBgOffsetsRaw[0]=U16(S+8);gBgOffsetsRaw[6]=U16(S+10);UploadBackgroundOffsets();
    REG(0x04000040)=((unsigned)S[1]<<8)|(S[1]+184);REG(0x04000044)=((unsigned)S[2]<<8)|(S[2]+104);
    gBgOffsetsRaw[8]=0x448;gBgOffsetsRaw[14]=((16u-S[3])<<8)|S[3];Blend();
}
/*0800087C*/
void CreditsShowCallback(void)
{
    REG(0x0400000C)=0x9D02;REG(0x0400000E)=0x1F09;REG(0x04000208)=1;REG(0x04000200)=1;REG(0x04000004)=8;REG(0x04000000)=0x2C00;
    gBgOffsetsRaw[20]=0;gBgOffsetsRaw[0]=0xFFB0;gBgOffsetsRaw[6]=0xFFDC;UploadBackgroundOffsets();
    REG(0x04000040)=0x30E8;REG(0x04000044)=0x248C;BYTE(0x04000048)=44;BYTE(0x0400004A)=4;
    gBgOffsetsRaw[8]=0x3F48;gBgOffsetsRaw[14]=0x1000;Blend();
}
void RunCredits(void)
{
    ClearMenuGraphics();UploadOam();UploadPalettes();UploadMenuGraphics();REG(0x05000000)=0;REG(0x04000000)=0;ResetGameKeys();PlayGameAudio(49);
    BiosCpuSet(ROM(0x08054548),gBackgroundBuffer+0xF800,0x1E0);BiosCpuSet(ROM(0x08054348),gPaletteBuffer,0x100);
    BiosLz77UnpackWram(ROM(0x0803B61C),gBackgroundBuffer);BiosLz77UnpackWram(ROM(0x0803C44C),gBackgroundBuffer+0x4000);
    SceneMap(0x08050748,0xE800,31);SceneMap(0x08050EC8,0xF000,31);SecondMapBank();InitializeCredits();
    SetVBlankCallback(CreditsFrameCallback);WaitForFrame();StepCreditsText();for(unsigned i=0;i<4;++i)UploadBackground(i);UploadPalettes();
    SetVBlankCallback(CreditsShowCallback);WaitForFrame();
    for(;;) { StepCreditsText();StepCreditsBackdrop();W16(14,U16(S+14)+1);SetVBlankCallback(CreditsFrameCallback);WaitForFrame(); }
}
