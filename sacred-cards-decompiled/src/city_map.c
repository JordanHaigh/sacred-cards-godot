/* AY7E city selection08000934..08001298. The ten location values are ordered
 *by a ROM table, with story progress selecting an unlock mask. Shared scratch
 *repeat state is deliberately not reset on entry, matching the native screen. */
#include "gba_bios.h"
extern uint8_t gCityMapOrigin,gCityMapSelection,gCityUnlockProgress,gMenuScratch[];
extern uint8_t gBackgroundBuffer[],gActorGraphicsBuffer[],gPaletteBuffer[];
extern uint16_t gKeysPressed,gKeysHeld,gOamBuffer[128][4],gBgOffsetsRaw[22];
extern void ClearMenuGraphics(void),UploadMenuGraphics(void),UploadOam(void),UploadPalettes(void),UploadBackgroundOffsets(void),WaitForFrame(void),SetVBlankCallback(void (*)(void)),PlayGameAudio(uint32_t),FadeGameMusic(uint16_t),RenderBitmapString(void *,const uint8_t *,uint16_t);
#define ROM(a) ((const uint8_t *)(uintptr_t)(a))
#define REG(a) (*(volatile uint16_t *)(uintptr_t)(a))
static uint16_t U16(const uint8_t *p) { return p[0]|(uint16_t)p[1]<<8; }
static uint32_t U32(const uint8_t *p) { return U16(p)|(uint32_t)U16(p+2)<<16; }
static void Blend(void) { REG(0x04000050)=gBgOffsetsRaw[8];REG(0x04000052)=gBgOffsetsRaw[14];REG(0x04000054)=gBgOffsetsRaw[12]; }
static void Blank(void) { REG(0x05000000)=0;REG(0x04000000)=0; }
/*08000CAC: return the original value if it is absent from the permutation.*/
uint8_t FindCityMapIndex(uint8_t location)
{ for(unsigned i=0;i<10;++i)if(ROM(0x08D30670)[i]==location)return i;return location; }
/*08000CD8*/
void DrawCityMapLabel(void)
{
    gOamBuffer[0][0]=0x2070;gOamBuffer[0][1]=0xC000;gOamBuffer[0][2]=gOamBuffer[0][3]=0;
    gOamBuffer[1][0]=0x2070;gOamBuffer[1][1]=0xC040;gOamBuffer[1][2]=0x10;gOamBuffer[1][3]=0;
}
/*08000CF8*/
void DrawCitySelectionMarker(uint8_t location)
{
    const uint8_t *p=ROM(U32(ROM(U32(ROM(0x08D305B4)+location*4))+4));uint16_t x=U16(p+2)&0x1FF;
    for(unsigned i=0;i<2;++i) { gOamBuffer[2+i][0]=p[0]|(i?0x800:0);gOamBuffer[2+i][1]=x|0x4000;gOamBuffer[2+i][2]=0x8200;gOamBuffer[2+i][3]=0; }
}
/*08000D4C: affine/padding halfwords of these objects remain untouched.*/
void DrawUnlockedCityMarkers(uint8_t progress)
{
    unsigned slot=4,mask=U16(ROM(0x08D3065C)+progress*2);
    for(unsigned location=0;location<10;++location) {
        const uint8_t *d=ROM(U32(ROM(0x08D30630)+location*4)),*o=ROM(U32(d+4));
        for(unsigned i=0;i<d[1];++i,++slot) {
            if(mask&(1u<<location)) { gOamBuffer[slot][0]=U16(o+i*8);gOamBuffer[slot][1]=U16(o+i*8+2);gOamBuffer[slot][2]=U16(o+i*8+4)|0x9610; }
            else { gOamBuffer[slot][0]=0xA0;gOamBuffer[slot][1]=0xF0;gOamBuffer[slot][2]=0xC00; }
        }
    }
}
/*08000E58: map/palette selection and immediate tile transfer.*/
void ReloadCityMapSelection(uint8_t location)
{
    if(location<10) {
        for(unsigned row=0;row<6;++row)BiosCpuSet(ROM(0x0806046C)+location*0xF00+row*0x280,gActorGraphicsBuffer+row*0x400,0x140);
        BiosCpuSet(ROM(0x08069A6C)+location*0x100,gPaletteBuffer+0x200,0x80);
    }
    for(unsigned row=0;row<2;++row)BiosCpuSet(ROM(0x0806A46C)+(row+location*2)*60,gBackgroundBuffer+0xA014+row*64,30);
    BiosCpuSet(gBackgroundBuffer+0xA000,(void *)0x0600A000,0x40);BiosCpuSet(gActorGraphicsBuffer,(void *)0x06010000,0xC00);
}
/*08001124*/
void PollCityMapRepeat(void)
{
    uint16_t keys=gKeysPressed&0x3FF;
    if(!keys) { if(!gMenuScratch[2]) { keys=gKeysHeld;gMenuScratch[2]=5; }else --gMenuScratch[2]; }
    else gMenuScratch[2]=10;
    gMenuScratch[0]=keys;gMenuScratch[1]=keys>>8;
}
/*0800116C*/
void FadeCityMap(void)
{
    unsigned delay=1;gBgOffsetsRaw[8]=0xFC;gBgOffsetsRaw[12]=0;
    for(unsigned i=0;i<15;++i)WaitForFrame();FadeGameMusic(4);
    while(gBgOffsetsRaw[12]<16) { if(!delay) { ++gBgOffsetsRaw[12];Blend();delay=1; }else --delay;WaitForFrame(); }
    for(unsigned i=0;i<15;++i)WaitForFrame();
}
/*080011E0 VBlank callback*/
void CityMapInitializeCallback(void)
{
    for(unsigned i=0;i<128;++i) { gOamBuffer[i][0]=160;gOamBuffer[i][1]=240;gOamBuffer[i][2]=0xC00;gOamBuffer[i][3]=0; }
    REG(0x0400000E)=0x1383;REG(0x0400000C)=0x140E;REG(0x04000200)=1;REG(0x04000208)=1;REG(0x04000004)=8;REG(0x04000000)=0x1C00;
    gBgOffsetsRaw[8]=0;Blend();gBgOffsetsRaw[0]=gBgOffsetsRaw[6]=gBgOffsetsRaw[20]=0;gBgOffsetsRaw[2]=0xFF70;UploadBackgroundOffsets();
}
/*08000A64*/
void LoadCityMapLayers(uint8_t index,uint8_t progress)
{
    static const uint32_t labels[]={0x0806B308,0x0806B37C,0x0806B3C0,0x0806B3E8,0x0806B418,0x0806B454,0x0806B47C,0x0806B4A0,0x0806B500,0x0806B53C};
    ClearMenuGraphics();UploadOam();UploadPalettes();UploadMenuGraphics();Blank();BiosLz77UnpackWram(ROM(0x08056D28),gBackgroundBuffer);
    for(unsigned row=0;row<20;++row)BiosCpuSet(ROM(0x0805FFBC)+row*60,gBackgroundBuffer+0x9800+row*64,30);
    for(unsigned row=0;row<2;++row)BiosCpuSet(ROM(0x0806A46C)+row*60,gBackgroundBuffer+0xA014+row*64,30);
    for(unsigned row=0;row<6;++row)BiosCpuSet(ROM(0x0806046C)+row*0x280,gActorGraphicsBuffer+row*0x400,0x140);
    BiosLz77UnpackWram(ROM(0x0806AABC),gActorGraphicsBuffer+0x4000);
    for(unsigned i=0;i<10;++i)RenderBitmapString(gBackgroundBuffer+0xC020+i*0x500,ROM(labels[i]),0x901);
    BiosCpuSet(ROM(0x0805FE3C),gPaletteBuffer,0xC0);BiosCpuSet(ROM(0x0806A91C),gPaletteBuffer+0x1E0,0x10);BiosCpuSet(ROM(0x08069A6C),gPaletteBuffer+0x200,0x80);
    BiosCpuSet(ROM(0x0806A93C),gPaletteBuffer+0x300,0x10);BiosCpuSet(ROM(0x0806A9FC),gPaletteBuffer+0x320,0x10);
    SetVBlankCallback(CityMapInitializeCallback);ReloadCityMapSelection(ROM(0x08D30670)[index]);DrawCityMapLabel();DrawCitySelectionMarker(ROM(0x08D30670)[index]);DrawUnlockedCityMarkers(progress);UploadOam();UploadMenuGraphics();UploadPalettes();WaitForFrame();
}
/*08000934*/
void RunCityMap(void)
{
    uint8_t index=FindCityMapIndex(gCityMapOrigin),progress=gCityUnlockProgress&15;LoadCityMapLayers(index,progress);PlayGameAudio(3);
    while(!(gKeysPressed&3)) {
        if(gKeysHeld&0xF0) {
            uint16_t repeated=U16(gMenuScratch),mask=U16(ROM(0x08D3065C)+progress*2);
            if(repeated&0x60)do { index=index?index-1:9;PlayGameAudio(54); }while(!(mask&(1u<<ROM(0x08D30670)[index])));
            else if(repeated&0x90)do { index=index==9?0:index+1;PlayGameAudio(54); }while(!(mask&(1u<<ROM(0x08D30670)[index])));
            ReloadCityMapSelection(ROM(0x08D30670)[index]);
        }
        DrawCityMapLabel();DrawCitySelectionMarker(ROM(0x08D30670)[index]);DrawUnlockedCityMarkers(progress);UploadOam();UploadPalettes();WaitForFrame();PollCityMapRepeat();
    }
    PlayGameAudio(55);FadeCityMap();ClearMenuGraphics();UploadOam();UploadPalettes();UploadMenuGraphics();Blank();gCityMapSelection=ROM(0x08D30670)[index];
}
