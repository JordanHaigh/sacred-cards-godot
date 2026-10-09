/* AY7E deck-management hub08001298..0800181C and player status0800315C..
 *0800391A. Hardware callbacks retain byte writes and their original ordering.
 * This is source recovery; display buffers and hardware are supplied by host. */
#include "deck_builder.h"
#include "gba_bios.h"
extern uint8_t gBackgroundBuffer[],gActorGraphicsBuffer[],gPaletteBuffer[],gPlayerName[19],gProgressRank;
extern uint16_t gBgOffsetsRaw[22],gOamBuffer[128][4],gKeysPressed;
extern uint32_t gDuelistLevel,gDeckCapacity;
extern uint64_t gMoney;
extern void ClearMenuGraphics(void),UploadMenuGraphics(void),UploadOam(void),UploadPalettes(void),UploadBackgroundOffsets(void);
extern void FadeGameMusic(uint16_t),PlayGameAudio(uint32_t),WaitForFrame(void),SetVBlankCallback(void (*)(void));
extern void RenderBitmapString(void *,const uint8_t *,uint16_t);
extern uint16_t ReadBackgroundTile(uint8_t,uint8_t,uint16_t);
extern void WriteBackgroundTile(uint8_t,uint8_t,uint16_t,uint16_t);
#define ROM(a) ((const uint8_t *)(uintptr_t)(a))
#define REG(a) (*(volatile uint16_t *)(uintptr_t)(a))
#define BYTE(a) (*(volatile uint8_t *)(uintptr_t)(a))
static uint16_t U16(const uint8_t *p) { return p[0]|(uint16_t)p[1]<<8; }
static void Blend(void) { REG(0x04000050)=gBgOffsetsRaw[8];REG(0x04000052)=gBgOffsetsRaw[14];REG(0x04000054)=gBgOffsetsRaw[12]; }
static void Blank(void) { REG(0x05000000)=0;REG(0x04000000)=0; }
static void UploadObjects(void) { BiosCpuSet(gActorGraphicsBuffer,(void *)0x06010000,0x2000); }
static void UploadStatus(void) { BiosCpuSet(gBackgroundBuffer+0xC000,(void *)0x0600C000,0x2000); }
static void Map(uint32_t source,unsigned destination)
{ for(unsigned y=0;y<20;++y)BiosCpuSet(ROM(source)+y*60,gBackgroundBuffer+destination+y*64,30); }
/*08001550*/
static void DrawHub(void)
{
    BiosLz77UnpackWram(ROM(0x0806ECA4),gActorGraphicsBuffer);
    Map(0x0806F990,0xF800);Map(0x0806FD50,0xE800);Map(0x08070200,0xE000);
    BiosCpuSet(ROM(0x0806F480),gPaletteBuffer,16);BiosCpuSet(ROM(0x0806F4A0),gPaletteBuffer+0x200,16);
    static const uint32_t texts[]={0x080706B0,0x0807082C,0x080709A8,0x080709F4,0x08070A3C};
    static const unsigned offsets[]={0x8020,0x9020,0xD020,0xD2A0,0xD520};
    for(unsigned i=0;i<5;++i)RenderBitmapString(gBackgroundBuffer+offsets[i],ROM(texts[i]),0x901);
}
/*080016D8*/
static void HubDisplay(void)
{
    for(unsigned i=0;i<128;++i) { gOamBuffer[i][0]=160;gOamBuffer[i][1]=240;gOamBuffer[i][2]=0xC00;gOamBuffer[i][3]=0; }
    REG(0x04000008)=0x1C09;REG(0x0400000A)=0x1D09;REG(0x0400000C)=0x1F0E;REG(0x0400000E)=0x1E03;
    REG(0x04000208)=1;REG(0x04000200)=1;REG(0x04000004)=8;REG(0x04000000)=0x3C00;
    gBgOffsetsRaw[20]=0xFFB0;gBgOffsetsRaw[2]=0xFFC8;
    gBgOffsetsRaw[0]=gBgOffsetsRaw[6]=gBgOffsetsRaw[4]=gBgOffsetsRaw[16]=gBgOffsetsRaw[18]=gBgOffsetsRaw[10]=0;UploadBackgroundOffsets();
    REG(0x04000040)=0x38B8;REG(0x04000044)=0x2878;gBgOffsetsRaw[8]=0xE8;gBgOffsetsRaw[12]=8;Blend();
}
/*080016B0/016CC*/
static void ShowHub(void) { BYTE(0x04000048)=0x3C;BYTE(0x0400004A)=8;HubDisplay(); }
static void HideHubWindow(void) { HubDisplay(); }
/*08001460/014F8*/
static void LoadHub(void)
{
    ClearMenuGraphics();UploadOam();UploadPalettes();UploadMenuGraphics();Blank();
    BiosLz77UnpackWram(ROM(0x0806B5B0),gBackgroundBuffer);DrawHub();Map(0x0806F4E0,0xF000);
    BiosCpuSet(ROM(0x0806F4C0),gPaletteBuffer+0x1E0,16);SetVBlankCallback(ShowHub);
    for(unsigned i=0;i<4;++i)BiosCpuSet(gBackgroundBuffer+i*0x4000,(void *)(uintptr_t)(0x06000000+i*0x4000),0x2000);
    UploadObjects();UploadPalettes();WaitForFrame();
}
static void RestoreHub(void)
{
    BiosCpuSet(ROM(0x0806F480),gPaletteBuffer,16);BiosCpuSet(ROM(0x0806F4A0),gPaletteBuffer+0x200,16);DrawHub();
    SetVBlankCallback(HideHubWindow);UploadObjects();UploadStatus();UploadPalettes();SetVBlankCallback(ShowHub);WaitForFrame();
}
/*080013D8/013F4/01410*/
static void InvalidDeck(uint16_t display)
{
    REG(0x04000000)=display;UploadBackgroundOffsets();gBgOffsetsRaw[8]=0xFC;gBgOffsetsRaw[12]=8;Blend();
    WaitForFrame();while(!(gKeysPressed&0x3FF))WaitForFrame();WaitForFrame();
}
/*080037D0/03894 differ only in the two WININ byte values.*/
static void StatusDisplay(unsigned visible)
{
    REG(0x0400000C)=0x1F0E;REG(0x0400000E)=0x1E03;REG(0x04000208)=1;REG(0x04000200)=1;REG(0x04000004)=8;REG(0x04000000)=0x6C00;
    gBgOffsetsRaw[20]=gBgOffsetsRaw[2]=gBgOffsetsRaw[0]=gBgOffsetsRaw[6]=0;UploadBackgroundOffsets();
    REG(0x04000040)=0x08C7;REG(0x04000044)=0x084F;REG(0x04000042)=0x08EF;REG(0x04000046)=0x7F97;
    BYTE(0x04000048)=visible?0x2C:8;BYTE(0x04000049)=visible?0x2C:8;BYTE(0x0400004A)=8;
    gBgOffsetsRaw[8]=0xE8;gBgOffsetsRaw[12]=6;Blend();
}
static void ShowStatus(void) { StatusDisplay(1); }
static void HideStatus(void) { StatusDisplay(0); }
static void Tile(unsigned x,unsigned y,uint16_t tile) { WriteBackgroundTile(x,y,0xF800,tile); }
/*0800358C deliberately ORs the glyph into the existing tile.*/
static void Digit(unsigned x,unsigned y,uint16_t digit)
{
    unsigned tile=ROM(0x08D30D70)[digit];Tile(x,y,ReadBackgroundTile(x,y,0xF800)|(tile+1));Tile(x,y+1,ReadBackgroundTile(x,y+1,0xF800)|(tile+3));
}
static void StatusNumber(uint16_t value,uint32_t divisors,unsigned n,unsigned x,unsigned y)
{
    unsigned seen=0;for(unsigned i=0;i<n;++i) { unsigned digit=(value/U16(ROM(divisors)+i*2))%10;
        if(digit)seen=1;Digit(x+i,y,digit?digit:seen?0:10); }
}
/*0800315C +0800360C/03690/03718/0373C. The native status view truncates
 * capacity and level to16 bits before division, including capacities>65535.*/
void ShowPlayerStatus(void)
{
    Map(0x0807E9E0,0xF800);uint16_t blank=ReadBackgroundTile(1,1,0xF800),palette=ReadBackgroundTile(2,2,0xF800)&0xFF00;
    for(unsigned i=0;i<7;++i)Tile(i+2,1,(i+0x19)|palette);
    for(unsigned i=0;i<3;++i)Tile(i+2,2,blank);
    for(unsigned i=0;i<8;++i) { unsigned tile=ROM(0x08D30D70)[i];Tile(i+3,3,(tile+0x5D)|palette);Tile(i+3,4,(tile+0x5F)|palette); }
    for(unsigned i=0;i<20;++i)Tile(i%10+2,i/10+6,(i+0x20)|palette);
    for(unsigned i=0;i<20;++i)Tile(i%10+13,i/10+1,(i+0x34)|palette);
    for(unsigned i=0;i<20;++i)Tile(i%10+13,i/10+6,(i+0x48)|palette);
    Tile(18,7,blank);Tile(18,8,palette|0x16);Tile(18,9,palette|0x18);Tile(22,8,blank);Tile(23,8,blank);
    for(unsigned i=0;i<10;++i)Tile(i+1,16,(i+0x6D)|palette);
    for(unsigned i=0;i<8;++i)Tile(i+22,18,(i+0x77)|palette);
    BiosCpuSet(ROM(0x0807E4F0),gPaletteBuffer,16);
    static const unsigned offsets[]={0xC020,0xC040,0xC0A0,0xC0C0,0xC120,0xC140,0xC1A0,0xC1C0,0xC220,0xC240,0xCEE0,0xC2C0};
    for(unsigned i=0;i<12;++i)RenderBitmapString(gBackgroundBuffer+offsets[i],ROM(0x0807EE90+i*4),0x901);
    static const uint32_t texts[]={0x0807EEC0,0x0807EEF8,0x0807EF7C,0x0807F000,0x0807F080};
    static const unsigned labels[]={0xC320,0xC400,0xC680,0xC900,0xCB80};
    for(unsigned i=0;i<5;++i)RenderBitmapString(gBackgroundBuffer+labels[i],ROM(texts[i]),0x801);
    RenderBitmapString(gBackgroundBuffer+0xCBA0,gPlayerName,0x901);RenderBitmapString(gBackgroundBuffer+0xCDA0,ROM(0x0807F098),0x801);RenderBitmapString(gBackgroundBuffer+0xCEE0,ROM(0x0807F0E0),0x801);
    SetVBlankCallback(HideStatus);StatusNumber(gDuelistLevel,0x0807F126,4,3,8);StatusNumber(gDeckCapacity,0x0807F12E,5,14,3);
    unsigned rank=0;for(unsigned i=0;i<6;++i)rank+=(gProgressRank>>i)&1;Digit(16,8,rank);Digit(20,8,6);
    unsigned seen=0;for(unsigned i=0;i<13;++i) { uint64_t divisor=0;for(unsigned b=0;b<8;++b)divisor|=(uint64_t)ROM(0x0807F138)[i*8+b]<<(b*8);
        unsigned digit=gMoney/divisor%10;if(digit)seen=1;Digit(i+8,17,digit?digit:seen||i==12?0:10); }
    UploadStatus();UploadPalettes();SetVBlankCallback(ShowStatus);WaitForFrame();while(!(gKeysPressed&2))WaitForFrame();PlayGameAudio(56);
}
void RunDeckManagement(void)
{
    uint8_t choice=0;FadeGameMusic(1);LoadHub();InitializeCollectionList();RefreshPlayerDeckState();PlayGameAudio(47);
    for(;;) {
        if(gKeysPressed&2) {
            if(!PlayerDeckIsFull()) { PlayGameAudio(57);InvalidDeck(0x1E00);RestoreHub(); }
            else if(!PlayerDeckFitsCapacity()) { PlayGameAudio(57);InvalidDeck(0x1D00);RestoreHub(); }
            else if(PlayerDeckIsFull()==1 && PlayerDeckFitsCapacity()==1) { PlayGameAudio(56);Blank();return; }
        }
        if((gKeysPressed&64) && choice) { PlayGameAudio(54);--choice; }
        if((gKeysPressed&128) && choice<2) { PlayGameAudio(54);++choice; }
        if(gKeysPressed&1) {
            if(choice==0) { PlayGameAudio(55);ShowPlayerStatus();RestoreHub(); }
            else if(choice==1) { PlayGameAudio(55);RunCollectionEditor();LoadHub(); }
            else if(PlayerDeckCount()) { PlayGameAudio(55);RunDeckEditor();LoadHub(); }
            else PlayGameAudio(57);
        }
        gOamBuffer[0][0]=choice*16+56;gOamBuffer[0][1]=0x4040;gOamBuffer[0][2]=0x800;gOamBuffer[0][3]=0;UploadOam();WaitForFrame();
    }
}
