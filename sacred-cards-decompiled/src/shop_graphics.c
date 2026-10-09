/* AY7E shop list graphics, thumbnail composition and cursor sprites.
 * ROM table addresses and tile/palette indices retain their native meaning. */
#include "gba_bios.h"
extern uint8_t gBackgroundBuffer[],gActorGraphicsBuffer[],gPaletteBuffer[],gMiniatureScratch[576];
extern uint8_t gShopMenuState[10],gCardMetadataBytes[0x1E],gDecimalDigits[5],gMoneyDigits[19];
extern uint16_t gBgOffsetsRaw[22],gOamBuffer[128][4],gShopRowCards[5][7];
extern uint64_t gMoney;
extern void LoadCardMetadata(uint32_t),FormatDecimalDigits(uint16_t,uint8_t),FormatMoneyDigits(uint64_t,uint8_t);
extern int32_t CardTributeRequirement(uint16_t);
extern void ComposeMiniCardContiguous(uint8_t *,const uint8_t *,const uint8_t *);
extern void RenderBitmapString(void *,const uint8_t *,uint16_t);
extern uint16_t ReadBackgroundTile(uint8_t,uint8_t,uint16_t);
extern void WriteBackgroundTile(uint8_t,uint8_t,uint16_t,uint16_t);
#define ROM(a) ((const uint8_t *)(uintptr_t)(a))
#define M gShopMenuState
static uint16_t U16(const uint8_t *p) { return p[0]|(uint16_t)p[1]<<8; }
static const uint8_t *Pointer(uint32_t address,unsigned index)
{ const uint8_t *p=ROM(address)+index*4;return ROM(p[0]|(uint32_t)p[1]<<8|(uint32_t)p[2]<<16|(uint32_t)p[3]<<24); }
static void Map(uint32_t address,unsigned offset,unsigned rows)
{ for(unsigned i=0;i<rows;++i)BiosCpuSet(ROM(address)+i*60,gBackgroundBuffer+offset+i*64,30); }
/* 0801C5E4 */
void InitializeShopPopupMaps(void)
{ gBgOffsetsRaw[16]=gBgOffsetsRaw[4]=0;Map(0x080C86E8,0xA000,20);Map(0x080C8B98,0xA800,20);Map(0x080C9048,0xB000,20); }
/* 0801CE4C */
void DrawShopSortIcon(uint8_t sort)
{
    static const unsigned offsets[4]={0xF844,0xF846,0xF884,0xF886};
    for(unsigned i=0;i<4;++i) { uint16_t *p=(uint16_t *)(gBackgroundBuffer+offsets[i]);*p=(*p&0xF000)|(sort*4+0x158+i); }
}
/* 0801CEA4 */
void DrawShopMoney(void)
{
    FormatMoneyDigits(gMoney,0);uint16_t *p=(uint16_t *)(gBackgroundBuffer+0xF86E);unsigned n=0;
    while(n<16 && gMoneyDigits[18-n]!=10) { *p=(*p&0xF000)|(gMoneyDigits[18-n]+0x195);--p;++n; }
    *p&=0xF000;
    for(unsigned i=1;i<=6;++i)p[-(int)i]=(p[-(int)i]&0xF000)|(0x195-i);
    p-=6;n+=7;while(n<20) { --p;*p&=0xF000;++n; }
}
/* 0801CC40 */
void InitializeShopStatusGraphics(void)
{
    gBgOffsetsRaw[10]=3;gBgOffsetsRaw[18]=0;
    for(unsigned i=0;i<3;++i)BiosCpuSet(ROM(0x080845DC+i*32),gBackgroundBuffer+0xF400+i*32,16);
    static const uint32_t strings[]={0x080CBB74,0x080CBB9C,0x080CBC3C,0x080CBCC4,0x080CBD5C,0x080CBD74};
    static const uint16_t offsets[]={0xE780,0xE800,0xEB00,0xF000,0xF2A0,0xF460};
    static const uint16_t modes[]={0x801,0x801,0x901,0x801,0x1801,0x801};
    for(unsigned i=0;i<6;++i)RenderBitmapString(gBackgroundBuffer+offsets[i],ROM(strings[i]),modes[i]);
    Map(0x080C94F8,0xF800,20);uint16_t tile=ReadBackgroundTile(0,0,0xF800);
    for(unsigned i=0;i<6;++i)WriteBackgroundTile(24+i,1,0xF800,(0x1A3+i)|tile);
    for(unsigned group=0;group<2;++group) {
        tile=ReadBackgroundTile(20+group*2,18,0xF800)&0xFC00;
        for(unsigned i=0;i<2;++i)for(unsigned row=0;row<2;++row)
            WriteBackgroundTile(20+group*2+i,18+row,0xF800,(ROM(0x08D30D70)[i]+0x1A9+group*4+row*2)|tile);
    }
    BiosCpuSet(ROM(0x08084F9C),gPaletteBuffer+0x140,16);DrawShopMoney();DrawShopSortIcon(M[7]);
}
/* 080351A4 */
void LoadFramedMiniatureContiguous(uint8_t *destination,uint16_t card)
{
    LoadCardMetadata(card);BiosLz77UnpackWram(Pointer(0x08D536F0,card),gMiniatureScratch);
    ComposeMiniCardContiguous(destination,gMiniatureScratch,Pointer(0x08D536C8,gCardMetadataBytes[0x19]));
}
/* 0801E01C / 0801DFE4 / 0801E048 / 0801E0C0 */
static void DrawShopMiniRequirement(uint8_t *dst,uint16_t card)
{ uint8_t n=CardTributeRequirement(card);if(n)BiosCpuSet(ROM(0x089C56B0+n*64),dst,32); }
static void DrawShopMiniAttribute(uint8_t *dst,uint16_t card)
{ LoadCardMetadata(card);if(gCardMetadataBytes[0x17])BiosCpuSet(Pointer(0x08D5109C,gCardMetadataBytes[0x17]),dst+0xC0,32); }
static void DrawShopMiniStat(uint8_t *dst,uint16_t card,unsigned defense)
{
    LoadCardMetadata(card);if(gCardMetadataBytes[0x1A]!=2)return;
    unsigned n=U16(gCardMetadataBytes+0x12+defense*2)/100;FormatDecimalDigits(n<100?n:99,0);
    BiosCpuSet(ROM((defense?0x089C6330:0x089C5DB0)+gDecimalDigits[3]*64),dst+0x200+defense*0x80,32);
    BiosCpuSet(ROM((defense?0x089C6070:0x089C5AF0)+gDecimalDigits[4]*64),dst+0x240+defense*0x80,32);
}
/* 0801DF54 / 0801DF38 */
void DrawShopMiniRow(uint8_t row)
{
    unsigned physical=ROM(0x080C868C)[M[6]*5+row];uint8_t *dst=gBackgroundBuffer+0x40+physical*0x1C00;
    for(unsigned col=0;col<7;++col,dst+=0x400) {
        uint16_t card=gShopRowCards[physical][col];
        if(!card)BiosCpuSet(ROM(0x080CA218),dst,0x200);
        else { LoadFramedMiniatureContiguous(dst,card);DrawShopMiniRequirement(dst,card);DrawShopMiniAttribute(dst,card);DrawShopMiniStat(dst,card,0);DrawShopMiniStat(dst,card,1); }
    }
}
void DrawShopAllMinis(void) { for(unsigned row=0;row<5;++row)DrawShopMiniRow(row); }
/* 0801E138 / 0801DED0 / 0801E15C */
void UpdateShopOffsets(void) { gBgOffsetsRaw[2]=M[6]<<5;gBgOffsetsRaw[20]=0; }
void InitializeShopMiniatures(void)
{
    UpdateShopOffsets();uint32_t zero=0;BiosCpuSet(&zero,gBackgroundBuffer,0x05000010);DrawShopAllMinis();
    BiosCpuSet(ROM(0x089C54B0),gPaletteBuffer,0xA0);gPaletteBuffer[0]=gPaletteBuffer[1]=0;Map(0x080C99A8,0x9000,36);
}
void InitializeShopBackdrop(void)
{ gBgOffsetsRaw[6]=gBgOffsetsRaw[0]=0;BiosLz77UnpackWram(ROM(0x080CA618),gBackgroundBuffer+0xC000);BiosCpuSet(ROM(0x080CADB4),gPaletteBuffer+0x1A0,0x30);Map(0x080CAE14,0xB800,20); }
/* 0801E2E4 / 0801E3D0 */
void DrawShopSelection(void)
{
    unsigned x=U16(ROM(0x080CBDB0)+M[4]*2),y=U16(ROM(0x080CBDA6)+M[5]*2);
    for(unsigned i=0;i<4;++i) { gOamBuffer[i][0]=(y+(i/2)*30)&255;gOamBuffer[i][1]=((x+(i%2)*30)&511)|0x8000|(i<<12);gOamBuffer[i][2]=0x8800;gOamBuffer[i][3]=0; }
}
void DrawShopShadow(void)
{ gOamBuffer[4][0]=ROM(0x080CBDBE)[M[5]*2]|0x800;gOamBuffer[4][1]=(U16(ROM(0x080CBDC8)+M[4]*2)&511)|0x8000;gOamBuffer[4][2]=0x804;gOamBuffer[4][3]=0; }
/* 0801E434/1E4CC/1E480/1E518. Sort y is the u16 table080CBDF6,
 * which Ghidra displayed as a wide string. Only the low byte is loaded. */
static void PopupSprite(unsigned sort,unsigned cursor)
{
    unsigned index=cursor?5:4,choice=M[8];
    gOamBuffer[index][0]=ROM(sort?0x080CBDF6:0x080CBDD6)[choice*2]|(cursor?0:0x800);
    gOamBuffer[index][1]=(U16(ROM(sort?0x080CBDE2:0x080CBDDC)+choice*2)&511)|0x4000;
    gOamBuffer[index][2]=cursor?0x9408:0x408;gOamBuffer[index][3]=0;
}
void DrawShopActionShadow(void) { PopupSprite(0,0); }
void DrawShopActionCursor(void) { PopupSprite(0,1); }
void DrawShopSortShadow(void) { PopupSprite(1,0); }
void DrawShopSortCursor(void) { PopupSprite(1,1); }
/* 0801E564: signed index and row count, single wrap. */
void DrawShopScrollbar(void)
{
    int row=(int16_t)U16(M)+(int8_t)M[5],count=(int16_t)U16(M+2);if(row<0)row+=count;else if(row>=count)row-=count;
    gOamBuffer[6][0]=((row*127/count+1)&255)|0x8000;gOamBuffer[6][1]=0;gOamBuffer[6][2]=0xAC48;gOamBuffer[6][3]=0;
}
/* 0801E1C4 */
void InitializeShopSprites(void)
{
    for(unsigned i=0;i<128;++i) { gOamBuffer[i][0]=0xA0;gOamBuffer[i][1]=0xF0;gOamBuffer[i][2]=0xC00;gOamBuffer[i][3]=0; }
    for(unsigned row=0;row<4;++row)BiosCpuSet(ROM(0x080CB3C4)+row*128,gActorGraphicsBuffer+row*0x400,64);
    BiosCpuSet(ROM(0x080CB5C4),gPaletteBuffer+0x300,16);DrawShopSelection();
    for(unsigned row=0;row<4;++row)BiosCpuSet(ROM(0x080CB5E4)+row*128,gActorGraphicsBuffer+0x80+row*0x400,64);
    DrawShopShadow();
    for(unsigned row=0;row<2;++row)BiosCpuSet(ROM(0x080CB324)+row*64,gActorGraphicsBuffer+0x100+row*0x400,32);
    BiosCpuSet(ROM(0x080CB3A4),gPaletteBuffer+0x320,16);
    for(unsigned row=0;row<2;++row)BiosCpuSet(ROM(0x080CB2C4)+row*32,gActorGraphicsBuffer+0x900+row*0x400,16);
    BiosCpuSet(ROM(0x080CB304),gPaletteBuffer+0x340,16);DrawShopScrollbar();
}
