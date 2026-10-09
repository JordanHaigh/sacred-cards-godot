/* AY7E duel action/context menus and inspection overlays, 08025DE0..28230.
 * Addresses retain original tile, palette and layout provenance. */
#include "ai.h"
#include "gba_bios.h"
extern uint8_t gBackgroundBuffer[],gPaletteBuffer[],gActorGraphicsBuffer[],gDecimalDigits[5];
extern uint8_t gDuelCursorState[6];
extern uint16_t gBgOffsetsRaw[22],gOamBuffer[128][4],gKeysRepeated,gKeysPressed,gKeysHeld;
extern uint16_t *gDuelVisibleCells[5][5],*gOpponentHandCells[5];
extern uint16_t gDuelLifePoints[2];
extern uint8_t gDuelDeckRecords[2][84];
extern uint8_t CanShowDuelCardMetadata(uint8_t,uint8_t);
extern void SetCardPreviewModifiers(uint8_t,int32_t),LoadCardWithPreviewStats(uint16_t),FormatDecimalDigits(uint16_t,uint8_t);
extern void WaitForFrame(void),UploadOam(void),UploadPalettes(void),UploadBackgroundOffsets(void),SetVBlankCallback(void (*)(void));
extern void ComposeDuelCardOam(uint8_t,uint8_t),DrawOpponentHandMiniature(uint8_t *,uint16_t *),LoadMiniatureObjectPalette(void);
extern uint16_t ReadBackgroundTile(uint8_t,uint8_t,uint16_t);
extern void WriteBackgroundTile(uint8_t,uint8_t,uint16_t,uint16_t),RenderBitmapString(void *,const uint8_t *,uint16_t);
#define ROM(a) ((const uint8_t *)(uintptr_t)(a))
#define REG(a) (*(volatile uint16_t *)(uintptr_t)(a))
#define REG8(a) (*(volatile uint8_t *)(uintptr_t)(a))
static uint16_t U16(const uint8_t *p) { return p[0]|(uint16_t)p[1]<<8; }
static uint32_t U32(const uint8_t *p) { return U16(p)|(uint32_t)U16(p+2)<<16; }
static void W16(uint8_t *p,uint16_t v) { p[0]=v;p[1]=v>>8; }
static void Tile(unsigned x,unsigned y,uint16_t value) { WriteBackgroundTile(x,y,0xE800,value); }
static void MenuMap(uint32_t source)
{ for(unsigned row=0;row<18;++row)BiosCpuSet(ROM(source)+row*60,gBackgroundBuffer+0xE800+row*64,0x20);BiosCpuSet(ROM(0x080E7BD0),gBackgroundBuffer+0x87A0,0x40); }
static void MenuWindow(uint16_t h,uint16_t v,uint8_t brightness)
{ REG(0x04000000)=0x7600;REG(0x04000042)=h;REG(0x04000046)=v;REG8(0x04000049)=0x36;REG(0x04000054)=brightness;REG(0x0400004A)=0x1F; }
/*080262A8/26614: context pointer is shifted one tile right, action is not.*/
static void MenuCursor(uint32_t table,unsigned count,unsigned shift,uint8_t selected)
{
    for(unsigned i=0;i<count;++i) {
        unsigned at=(U16(ROM(table)+i*2)&0xFFFE)+shift*2;
        static const unsigned offsets[4]={0,2,64,66};
        for(unsigned j=0;j<4;++j)W16(gBackgroundBuffer+at+offsets[j],i==selected?0x703D+j:0x7000);
    }
}
void DrawDuelContextMenu(uint8_t selection) { MenuCursor(0x08D4C532,3,1,selection); }
static void DrawMonsterActionMenu(uint8_t selection) { MenuCursor(0x08D4C636,4,0,selection); }
/*08026494*/
static void InitializeMonsterActionMenu(uint8_t selection)
{
    MenuMap(0x080E6370);uint16_t palette=ReadBackgroundTile(4,3,0xE800)&0xFF00;
    for(unsigned i=0;i<8;++i) {
        unsigned n=ROM(0x08D30D70)[i];Tile(i+4,3,(n+0x41)|palette);Tile(i+4,4,(n+0x43)|palette);
        Tile(i+4,5,(n+0x51)|palette);Tile(i+4,6,(n+0x53)|palette);
    }
    for(unsigned i=0;i<12;++i) {
        unsigned n=ROM(0x08D30D70)[i];Tile(i+14,3,(n+0x61)|palette);Tile(i+14,4,(n+0x63)|palette);
        Tile(i+14,5,(n+0x79)|palette);Tile(i+14,6,(n+0x7B)|palette);
    }
    RenderBitmapString(gBackgroundBuffer+0x8820,ROM(0x08D4C544),0x901);
    DrawMonsterActionMenu(selection);WaitForFrame();UploadDuelText();MenuWindow(0x0CD4,0x143C,10);
}
/*0802635C: highlighting attack/defense changes the live pose even before A.
 * A returns before preview updates; cancel does not restore the old pose.*/
uint8_t RunMonsterActionMenu(void)
{
    uint8_t choice=0;InitializeMonsterActionMenu(choice);
    for(;;) {
        uint32_t nav=0;
        if(gKeysRepeated&64)nav=0x08D4C63E;else if(gKeysRepeated&128)nav=0x08D4C642;
        else if(gKeysRepeated&32)nav=0x08D4C64A;else if(gKeysRepeated&16)nav=0x08D4C646;
        if(nav) { PlayGameAudio(54);choice=ROM(nav)[choice];DrawMonsterActionMenu(choice);WaitForFrame();UploadDuelText();continue; }
        if((gKeysPressed&1) && choice<4)return choice+1;
        if(gKeysPressed&2) { PlayGameAudio(56);return 5; }
        if(choice<2) {
            uint8_t row=gDuelCursorState[1],col=gDuelCursorState[0];uint8_t *flags=(uint8_t *)gEffectBoardCells[row][col]+4;
            *flags=choice?*flags|2:*flags&0xFD;ComposeDuelCardOam(col,row);SetVBlankCallback(UploadOam);
        }
        WaitForFrame();
    }
}
static void GraveName(uint16_t card,unsigned destination)
{
    LoadCardMetadata(card);const uint8_t *source=ROM(U32(gCardMetadataBytes));uint8_t name[24];unsigned i=0;
    while(i<20 && source[i]) { name[i]=source[i];name[i+1]=source[i+1];i+=2; }
    while(i<20) { name[i++]=0x81;name[i++]=0x40; }name[i]=0;
    RenderBitmapString(gBackgroundBuffer+destination,name,0x901);
}
static void MenuNumber(uint16_t number,unsigned tile,unsigned digits)
{ FormatDecimalDigits(number,0);for(unsigned i=0;i<digits;++i)W16(gBackgroundBuffer+(tile-i)*2,(gDecimalDigits[4-i]+0x41)|0x3000); }
/*08025DE0*/
void InitializeDuelContextMenu(uint8_t selection)
{
    MenuMap(0x080E5EC0);RenderBitmapString(gBackgroundBuffer+0x8820,ROM(0x08D4C388),0x801);
    RenderBitmapString(gBackgroundBuffer+0x8B00,ROM(0x08D4C473),0x901);
    uint16_t blank=ReadBackgroundTile(0,0,0xE800),pal=ReadBackgroundTile(20,1,0xE800)&0xFF00;
    for(unsigned i=0;i<4;++i) { Tile(i+4,6,(i+0x4E)|pal);Tile(i+4,12,(i+0x4E)|pal); }
    Tile(8,6,blank);Tile(8,12,blank);
    for(unsigned i=0;i<6;++i) { Tile(i+11,6,(i+0x52)|pal);Tile(i+11,12,(i+0x52)|pal); }
    for(unsigned i=0;i<10;++i) {
        unsigned n=ROM(0x08D30D70)[i];Tile(i+5,1,(n+0x58)|pal);Tile(i+5,2,(n+0x5A)|pal);
        Tile(i+5,3,(n+0x6C)|pal);Tile(i+5,4,(n+0x6E)|pal);
        Tile(i+17,1,(n+0x80)|pal);Tile(i+17,2,(n+0x82)|pal);
    }
    for(unsigned i=0;i<2;++i) { Tile(i+15,3,blank);Tile(i+15,4,blank); }
    for(unsigned i=0;i<20;++i) {
        unsigned n=ROM(0x08D30D70)[i];Tile(i+5,9,(n+0x94)|pal);Tile(i+5,10,(n+0x96)|pal);
        Tile(i+5,15,(n+0xBC)|pal);Tile(i+5,16,(n+0xBE)|pal);
    }
    /*02023254/58 are the grave-card halfwords at absolute side record starts.*/
    extern uint8_t gAbsoluteDuelSideState[2][4];
    GraveName(U16(gAbsoluteDuelSideState[0]),0x9780);GraveName(U16(gAbsoluteDuelSideState[1]),0x9280);
    MenuNumber(gDuelLifePoints[0],0x75AC,4);MenuNumber(gDuelLifePoints[1],0x74EC,4);
    MenuNumber(gDuelDeckRecords[0][80],0x758A,2);MenuNumber(gDuelDeckRecords[1][80],0x74CA,2);
    DrawDuelContextMenu(selection);WaitForFrame();UploadDuelText();MenuWindow(0xF0,0x98,7);
}
/*08026788/26704/266C4*/
void ShowDuelStatsWhileHeld(void)
{
    for(unsigned row=0;row<64;++row)BiosCpuSet(ROM(0x080E6820)+row*60,gBackgroundBuffer+0xF000+row*64,0x04000010);
    for(unsigned row=0;row<5;++row)for(unsigned col=0;col<5;++col) {
        int y=(int16_t)U16(ROM(0x08D51130)+row*2),x=(int16_t)U16(ROM(0x08D510FE)+(row*5+col)*2);
        int at=((((y+24)*8)&0xFC0)+x/4+0xF000)/2*2;
        if(CanShowDuelCardMetadata(row,col)==1) {
            uint16_t *cell=gDuelVisibleCells[row][col];SetCardPreviewModifiers(gTerrain,(int8_t)((uint8_t *)cell)[2]);LoadCardWithPreviewStats(*cell);
        }else LoadCardMetadata(0);
        for(unsigned stat=0;stat<2;++stat) {
            FormatDecimalDigits(U16(gCardMetadataBytes+0x12+stat*2),0);
            for(unsigned i=0;i<5;++i)W16(gBackgroundBuffer+at+stat*64+i*2,gDecimalDigits[i]+0x303D);
        }
    }
    RenderBitmapString(gBackgroundBuffer+0x87A0,ROM(0x08D4C650),0x801);REG(0x04000008)=0x9E08;
    gBgOffsetsRaw[4]=gBgOffsetsRaw[20];gBgOffsetsRaw[16]=gBgOffsetsRaw[2];WaitForFrame();UploadBackgroundOffsets();
    BiosCpuSet(gBackgroundBuffer+0x87A0,(void *)0x060087A0,0x04000058);BiosCpuSet(gBackgroundBuffer+0xF000,(void *)0x0600F000,0x04000400);
    REG(0x04000000)=0x7700;REG(0x04000042)=0xF0;REG(0x04000046)=0x98;REG8(0x04000049)=0x35;REG(0x04000054)=7;REG(0x0400004A)=0x1E;
    while(gKeysHeld&512)WaitForFrame();REG(0x04000000)=0x3600;WaitForFrame();
}
static void BlankHandDisplay(void) { REG(0x05000000)=0;REG(0x04000000)=0; }
/*08028230, decoded directly because the callback was not an exported root.*/
static void HandDisplayCallback(void)
{
    UploadOam();static const uint8_t zeroOffsets[]={4,16,18,10,20,2,6,8,14,12};
    for(unsigned i=0;i<sizeof(zeroOffsets);++i)gBgOffsetsRaw[zeroOffsets[i]]=0;gBgOffsetsRaw[0]=4;
    UploadBackgroundOffsets();REG(0x04000050)=gBgOffsetsRaw[8];REG(0x04000052)=gBgOffsetsRaw[14];REG(0x04000054)=gBgOffsetsRaw[12];
    REG(0x0400000E)=0x1F03;REG(0x04000000)=0x1800;
}
/*08027FE4/28018/28090/28214/27F80*/
void ShowOpponentHand(void)
{
    PlayGameAudio(55);uint16_t zero=0;BiosCpuSet(&zero,gActorGraphicsBuffer,0x01002000);BiosCpuSet(&zero,gActorGraphicsBuffer+0x4000,0x01002000);
    BiosHuffmanUnpack(ROM(U32(ROM(0x08D4C67C)+gTerrain*4)),gBackgroundBuffer);
    const uint8_t *map=ROM(U32(ROM(0x08D4C698)+gTerrain*4));
    for(unsigned row=0;row<20;++row)BiosCpuSet(map+row*62,gBackgroundBuffer+0xF800+row*64,0x1F);
    BiosCpuSet(ROM(U32(ROM(0x08D4C6B4)+gTerrain*4)),gPaletteBuffer,0x30);
    for(unsigned i=0;i<5;++i)DrawOpponentHandMiniature(gActorGraphicsBuffer+((i&3)*256+(i>>2)*0x1000),gOpponentHandCells[i]);
    LoadMiniatureObjectPalette();
    for(unsigned i=0;i<128;++i) { gOamBuffer[i][0]=0xA0;gOamBuffer[i][1]=0xF0;gOamBuffer[i][2]=0xC00;gOamBuffer[i][3]=0; }
    for(unsigned i=0;i<5;++i) {
        gOamBuffer[i][0]=0x2118;gOamBuffer[i][1]=0x8000|ROM(0x080FB794)[i];gOamBuffer[i][2]=0xC00+(i&3)*8+(i>>2)*128;
    }
    gOamBuffer[0][3]=0xFF00;gOamBuffer[3][3]=0xFEFF;
    SetVBlankCallback(BlankHandDisplay);WaitForFrame();
    BiosCpuSet(gBackgroundBuffer,(void *)0x06000000,0x2000);BiosCpuSet(gBackgroundBuffer+0xC000,(void *)0x0600C000,0x2000);
    BiosCpuSet(gActorGraphicsBuffer,(void *)0x06010000,0x2000);BiosCpuSet(gActorGraphicsBuffer+0x4000,(void *)0x06014000,0x2000);UploadPalettes();
    SetVBlankCallback(HandDisplayCallback);WaitForFrame();
    for(;;) { uint16_t key=(gKeysPressed&256)?256:(gKeysPressed&2)?2:0;WaitForFrame();if(key==2 || key==256)break; }
    PlayGameAudio(56);
}
