/* AY7E duel HUD, miniatures, OAM and display restoration. ROM addresses below
 * remain literal source views; semantic C is not linked or execution-compared. */
#include "card_effects.h"
#include "gba_bios.h"
extern uint8_t gBackgroundBuffer[],gPaletteBuffer[],gObjectPaletteBuffer[],gActorGraphicsBuffer[];
extern uint8_t gMiniatureScratch[576]; /* 02018800, shared with other workspaces */
extern uint16_t gOamBuffer[128][4],gBgOffsetsRaw[22];
extern uint8_t gDuelViewport,gDuelCursorColumn; /* 02023439 / 02023438 */
extern uint8_t gCardMetadataBytes[0x1E],gDecimalDigits[5];
extern uint16_t *gDuelVisibleCells[5][5]; /* 020232E0; distinct from the effect grid02023270 */
extern void LoadCardMetadata(uint32_t),LoadCardWithPreviewStats(uint16_t);
extern uint8_t *gAttributeIconDestination,*gAttributePaletteDestination; /* 0201CB28/2C */
extern void RenderBitmapString(void *,const uint8_t *,uint16_t),RenderBitmapGlyph(void *,uint16_t,uint16_t);
extern void FormatDecimalDigits(uint16_t,uint8_t),SetCardPreviewModifiers(uint8_t,int32_t);
extern void ComposeMiniCard(uint8_t *,const uint8_t *,const uint8_t *);
extern void ClearSceneOam(void),UploadOam(void),UploadPalettes(void),UploadBackgroundOffsets(void),WaitForFrame(void);
extern void LoadDuelTerrain(uint8_t);
extern uint16_t SetDuelViewportOffset(uint8_t);
#define ROM(a) ((const uint8_t *)(uintptr_t)(a))
#define UIREG(a) (*(volatile uint16_t *)(uintptr_t)(a))
static uint16_t U16(const uint8_t *p) { return p[0]|(uint16_t)p[1]<<8; }
static uint32_t U32(const uint8_t *p) { return p[0]|(uint32_t)p[1]<<8|(uint32_t)p[2]<<16|(uint32_t)p[3]<<24; }
static const uint8_t *RomPointer(uint32_t table,unsigned index) { return ROM(U32(ROM(table)+index*4)); }
/* 08003118 /08003138 */
uint16_t ReadBackgroundTile(uint8_t x,uint8_t y,uint16_t offset)
{ return U16(gBackgroundBuffer+(offset&0xFFFE)+y*64+x*2); }
void WriteBackgroundTile(uint8_t x,uint8_t y,uint16_t offset,uint16_t tile)
{ uint8_t *p=gBackgroundBuffer+(offset&0xFFFE)+y*64+x*2;p[0]=tile;p[1]=tile>>8; }
/* 08004284/042A8 establish destinations which special card types overwrite. */
void LoadAttributeIcon(uint8_t attribute,uint8_t *destination)
{ gAttributeIconDestination=destination;BiosCpuSet(RomPointer(0x08D30E8C,attribute),destination,0x40); }
void LoadAttributePalette(uint8_t attribute,uint8_t *destination)
{ gAttributePaletteDestination=destination;BiosCpuSet(RomPointer(0x08D30E5C,attribute),destination,0x10); }
/* 080041C8 /0800423C */
void LoadTypeIcon(uint8_t type,uint8_t *destination)
{
    const uint8_t *p=RomPointer(0x08D30DFC,type);
    if((uint8_t)(type-21)<3) {
        BiosCpuSet(p,destination,0x20);BiosCpuSet(p+0x80,destination+0x40,0x20);
        BiosCpuSet(p+0x40,gAttributeIconDestination,0x20);BiosCpuSet(p+0xC0,gAttributeIconDestination+0x40,0x20);
    }else BiosCpuSet(p,destination,0x40);
}
void LoadTypePalette(uint8_t type,uint8_t *destination)
{
    const uint8_t *p=RomPointer(0x08D30D9C,type);
    if((uint8_t)(type-21)<3)BiosCpuSet(p,gAttributePaletteDestination,0x10);
    BiosCpuSet(p,destination,0x10);
}
/* 080275DC /0802761C: recovered valid duel rows0..4. */
uint8_t CanShowDuelCardMetadata(uint8_t row,uint8_t column)
{ return row<2?(((uint8_t *)gDuelVisibleCells[row][column])[4]>>4)&1:row<5?1:row; }
uint8_t IsDuelCardPublic(uint8_t row,uint8_t column)
{
    uint16_t *cell=gDuelVisibleCells[row][column];if(!*cell || row==0 || row==1 || row==4)return 1;
    if(row==2 || row==3)return (((uint8_t *)cell)[4]>>4)&1;return row;
}
/* 080259D4 /08025A40 /08025AC4 /08025BA0 /08025BE0 */
void DrawDuelCardDetails(void)
{
    uint8_t *tiles=gBackgroundBuffer+0x8000;
    for(unsigned i=0;i<15;++i)BiosCpuSet(tiles,tiles+0x1E0+i*32,0x10);
    uint8_t name[32];const uint8_t *source=ROM(U32(gCardMetadataBytes));
    for(unsigned i=0;i<30;++i)name[i]=source[i];name[30]=0;
    RenderBitmapString(tiles+0x1E0,name,0x801);
    uint8_t level=gCardMetadataBytes[0x18];
    if(!level)for(unsigned i=0;i<3;++i)BiosCpuSet(tiles,tiles+0x40+i*32,0x10);
    else {
        BiosCpuSet(ROM(0x080845DC),tiles+0x40,0x10);FormatDecimalDigits(level,1);
        for(unsigned i=0;i<2;++i)RenderBitmapGlyph(tiles+0x60+i*32,U16(ROM(0x08D4C2D0)+gDecimalDigits[i]*2),0x801);
    }
    for(unsigned stat=0;stat<2;++stat) {
        uint16_t value=U16(gCardMetadataBytes+0x12+stat*2);FormatDecimalDigits(value,0);unsigned first=0;
        uint8_t *out=tiles+0x3C0+stat*0xA0;
        if(value!=65535 && gDecimalDigits[0]==10) { first=1;BiosCpuSet(ROM(0x080845FC+stat*32),out,0x10); }
        for(unsigned i=first;i<5;++i)RenderBitmapGlyph(out+i*32,U16(ROM(0x08D4C2D0)+gDecimalDigits[i]*2),0x801);
    }
    LoadAttributeIcon(gCardMetadataBytes[0x17],tiles+0x580);LoadAttributePalette(gCardMetadataBytes[0x17],gPaletteBuffer+0xC0);
    LoadTypeIcon(gCardMetadataBytes[0x16],tiles+0x500);LoadTypePalette(gCardMetadataBytes[0x16],gPaletteBuffer+0xA0);
    RenderBitmapString(tiles+0x600,ROM(IsDuelCardPublic(gDuelViewport,gDuelCursorColumn)?0x08D4C337:0x08D4C2E7),0x801);
}
/* 0802595C */
void LoadSelectedDuelCardDetails(void)
{
    if(CanShowDuelCardMetadata(gDuelViewport,gDuelCursorColumn)==1) {
        uint16_t *cell=gDuelVisibleCells[gDuelViewport][gDuelCursorColumn];
        SetCardPreviewModifiers(gTerrain,(int8_t)((uint8_t *)cell)[2]);LoadCardWithPreviewStats(*cell);
    }else LoadCardMetadata(0);
    DrawDuelCardDetails();
}
/* 08024A14 */
void LoadDuelHud(void)
{
    UIREG(0x0400000A)=0x5D09;gBgOffsetsRaw[18]=0;gBgOffsetsRaw[10]=0;
    BiosCpuSet(ROM(0x080E54C0),gBackgroundBuffer+0x8000,0x20);
    BiosCpuSet(ROM(0x080E59F0),gPaletteBuffer+0x60,0x10);BiosCpuSet(ROM(0x08084F9C),gPaletteBuffer+0x80,0x10);
    BiosCpuSet(ROM(0x080E7C50),gPaletteBuffer+0xE0,0x10);
    for(unsigned row=0;row<20;++row)BiosCpuSet(ROM(0x080E5540)+row*60,gBackgroundBuffer+0xE800+row*64,0x20);
    uint16_t a=ReadBackgroundTile(17,19,0xE800),b=ReadBackgroundTile(18,19,0xE800);
    for(unsigned i=0;i<2;++i)WriteBackgroundTile(18+i,19,0xE800,a);
    for(unsigned i=0;i<12;++i)WriteBackgroundTile(8+i,18,0xE800,(uint16_t)((b&0xFF00)|(48+i)));
    UIREG(0x04000040)=0xF0;UIREG(0x04000044)=0x8EA0;UIREG(0x04000048)=0x36;UIREG(0x0400004A)=0x1F;
}
/* 08024B34: fixed inputs to08003A9C/03A6C fold to these matrix values;
 * native explicit overwrites retain FEFF rather than FF00 in two positions. */
void InitializeDuelOam(void)
{
    ClearSceneOam();static const uint16_t matrices[20]={256,0,0,256,256,0,0,256,0,256,0xFEFF,0,0xFF00,0,0,0xFEFF,0,0xFF00,256,0};
    for(unsigned i=0;i<20;++i)gOamBuffer[i][3]=matrices[i];
}
/* 08034A28 /08034A5C */
static int16_t CardX(uint8_t column,uint8_t row) { return (int16_t)U16(ROM(0x08D510FE)+row*10+column*2); }
static int16_t CardY(uint8_t row) { return (int16_t)(U16(ROM(0x08D51130)+row*2)-gBgOffsetsRaw[2]); }
/* 08024598 /080245D0 /0802460C /0802757C /080275AC */
void DrawDuelCursorPosition(void)
{
    for(unsigned i=0;i<4;++i) {
        uint16_t x=(uint16_t)(CardX(gDuelCursorColumn,gDuelViewport)+(int8_t)ROM(0x08D4C670)[i]);
        uint8_t y=(uint8_t)(CardY(gDuelViewport)+ROM(0x08D4C674)[i]);
        gOamBuffer[i*2][0]=y;gOamBuffer[i*2][1]=(x&511)|0x8000|(i<<12);gOamBuffer[i*2][2]=0xA980;
    }
}
void DrawDuelCursor(void)
{
    for(unsigned row=0;row<4;++row)for(unsigned i=0;i<128;++i)gActorGraphicsBuffer[0x3000+row*0x400+i]=ROM(0x080D4694)[row*128+i];
    BiosCpuSet(ROM(0x080D4894),gPaletteBuffer+0x340,0x10);
    DrawDuelCursorPosition();
}
/* 08034AF8 /0803466C */
void LoadFramedMiniature(uint8_t *destination,uint16_t card)
{
    LoadCardMetadata(card);BiosLz77UnpackWram(RomPointer(0x08D536F0,card),gMiniatureScratch);
    ComposeMiniCard(destination,gMiniatureScratch,RomPointer(0x08D536C8,gCardMetadataBytes[0x19]));
}
/*08034658: the original accepts a destination; the duel caller supplies OBJ
 * palette RAM's staging buffer. Keep that independent entry available. */
void CopyMiniaturePalette(void *destination) { BiosCpuSet(ROM(0x089C54B0),destination,0xA0); }
void LoadMiniatureObjectPalette(void) { CopyMiniaturePalette(gObjectPaletteBuffer); }
/* 08035840 /08035874 /080358E4 */
static void DrawMiniBack(uint8_t *out)
{ for(unsigned row=0;row<4;++row)for(unsigned i=0;i<256;++i)out[row*0x400+i]=ROM(0x0894B8B4)[row*256+i]; }
static void DrawMiniUsed(uint8_t *out) { BiosCpuSet(ROM(0x089C5470),out+0xCC0,0x20); }
static void DrawMiniHidden(uint8_t *out) { BiosCpuSet(ROM(0x089C57B0),out+0xC80,0x20); }
/* 08035890; native signed -128 draws the minus but no magnitude digit. */
static void DrawMiniStage(uint8_t *out,int8_t stage)
{
    unsigned at=0xC00;int n=stage;if(n<0) { BiosCpuSet(ROM(0x089C68B0),out+at,0x20);at=0xC40;n=-n; }
    if((int8_t)n>0) { if(n>9)n=10;BiosCpuSet(ROM(0x089C65F0)+n*64,out+at,0x20); }
}
/* 08035900 /08035938 /08035964 */
static void DrawMiniAttribute(uint8_t *out,uint16_t card)
{ LoadCardMetadata(card);if(gCardMetadataBytes[0x17])BiosCpuSet(RomPointer(0x08D5109C,gCardMetadataBytes[0x17]),out+0xC0,0x20); }
static void DrawMiniRequirement(uint8_t *out,uint16_t card,unsigned spell)
{
    LoadCardMetadata(card);int n=spell?ROM(0x080BA25C)[gCardMetadataBytes[0x1D]]:(int8_t)ROM(0x08D4C6D0)[gCardMetadataBytes[0x18]];
    if(n>0)BiosCpuSet(ROM(0x089C56B0)+n*64,out,0x20);
}
/* 08035990 /08035A18 */
static void DrawMiniStat(uint8_t *out,uint16_t *cell,unsigned defense)
{
    SetCardPreviewModifiers(gTerrain,(int8_t)((uint8_t *)cell)[2]);LoadCardWithPreviewStats(*cell);
    if(gCardMetadataBytes[0x1A]!=2)return;
    unsigned n=U16(gCardMetadataBytes+0x12+defense*2)/100;FormatDecimalDigits(n<100?n:99,0);
    BiosCpuSet(ROM(defense?0x089C6330:0x089C5DB0)+gDecimalDigits[3]*64,out+0x800+defense*128,0x20);
    BiosCpuSet(ROM(defense?0x089C6070:0x089C5AF0)+gDecimalDigits[4]*64,out+0x840+defense*128,0x20);
}
/* 08034684. Row-specific overlay order matters because metadata is global. */
void LoadDuelMiniatures(void)
{
    for(unsigned row=0;row<5;++row)for(unsigned col=0;col<5;++col) {
        uint16_t *cell=gDuelVisibleCells[row][col];uint8_t flags=((uint8_t *)cell)[4];
        uint8_t *out=gActorGraphicsBuffer+U16(ROM(0x08D510CC)+(row*5+col)*2)*32;
        if(row<2 && !(flags&16))DrawMiniBack(out);
        else {
            LoadFramedMiniature(out,*cell);
            if(row==1) { DrawMiniRequirement(out,*cell,0);DrawMiniAttribute(out,*cell); }
            if(row==4) { DrawMiniAttribute(out,*cell);DrawMiniRequirement(out,*cell,0); }
            if(row==2) {
                if(flags&1)DrawMiniUsed(out);DrawMiniAttribute(out,*cell);DrawMiniRequirement(out,*cell,0);
            }
            if(row==1 || row==2)DrawMiniStage(out,(int8_t)((uint8_t *)cell)[2]);
            if(row==1 || row==2 || row==4) { DrawMiniStat(out,cell,0);DrawMiniStat(out,cell,1); }
            if(row==3)DrawMiniRequirement(out,*cell,1);
        }
        if((row==1 || row==4) && (flags&1))DrawMiniUsed(out);
        if(row>=2 && !(flags&16))DrawMiniHidden(out);
    }
}
/* 08034938 /08034984 /08034A7C */
void ComposeDuelCardOam(uint8_t col,uint8_t row)
{
        uint16_t *cell=gDuelVisibleCells[row][col];unsigned index=row*5+col;
        uint16_t *oam=gOamBuffer[102+index];oam[0]=(CardY(row)&255)|0x2100;
        oam[1]=(CardX(col,row)&511)|0x8000;oam[2]=(U16(ROM(0x08D510CC)+index*2)&1023)|0x800;
        unsigned orientation=row==0?0x600:row==1?(((uint8_t *)cell)[4]&2?0x800:0x600):row==2 && (((uint8_t *)cell)[4]&2)?0x400:0x200;
        oam[1]|=orientation;
}
void ComposeDuelMiniatureOam(void)
{ for(unsigned row=0;row<5;++row)for(unsigned col=0;col<5;++col)if(*gDuelVisibleCells[row][col])ComposeDuelCardOam(col,row); }
/* 08028090 reuses these overlays in this specific order. */
void DrawOpponentHandMiniature(uint8_t *out,uint16_t *cell)
{
    if(!*cell)return;
    if(!(((uint8_t *)cell)[4]&16))DrawMiniBack(out);
    else { LoadFramedMiniature(out,*cell);DrawMiniAttribute(out,*cell);DrawMiniRequirement(out,*cell,0);DrawMiniStat(out,cell,0);DrawMiniStat(out,cell,1); }
}
/* 08035AA0 /08024E00 /08024944 /08024ECC */
void RestoreDuelDisplay(void)
{
    LoadDuelHud();LoadSelectedDuelCardDetails();InitializeDuelOam();
    LoadDuelMiniatures();LoadMiniatureObjectPalette();ComposeDuelMiniatureOam();DrawDuelCursor();WaitForFrame();
    for(unsigned block=0;block<4;++block)BiosCpuSet(gBackgroundBuffer+block*0x4000,(void *)(uintptr_t)(0x06000000+block*0x4000),0x2000);
    for(unsigned block=0;block<2;++block)BiosCpuSet(gActorGraphicsBuffer+block*0x4000,(void *)(uintptr_t)(0x06010000+block*0x4000),0x2000);
    UploadBackgroundOffsets();UploadOam();UploadPalettes();UIREG(0x04000000)=0x3600;UIREG(0x04000050)=0xD4;UIREG(0x04000054)=10;
}
void RestoreDuelAfterBattle(void)
{ WaitForFrame();UIREG(0x05000000)=0;UIREG(0x04000000)=0;LoadDuelTerrain(gTerrain);gBgOffsetsRaw[2]=SetDuelViewportOffset(1);RestoreDuelDisplay(); }

/*080248F4: reload terrain without resetting cursor, mode or callback.*/
void ReloadDuelDisplay(void)
{ WaitForFrame();UIREG(0x05000000)=0;UIREG(0x04000000)=0;LoadDuelTerrain(gTerrain);RestoreDuelDisplay(); }
