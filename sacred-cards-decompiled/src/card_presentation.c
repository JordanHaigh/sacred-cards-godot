/* AY7E full-card composition and description viewer. Literal ROM views and
 * shared scratch writes are retained. Not linked or execution-compared. */
#include "gba_bios.h"
extern uint8_t gCardMetadataBytes[0x1E],gLanguage,gDecimalDigits[5];
extern uint8_t gFullCardTiles[0x4000],gFullCardPalette[256]; /*02018800 /0201C800*/
extern uint16_t gFullCardMap[266]; /*0201C900*/
extern uint8_t gCardTileBackground[64],gCardTileForeground[64],gCardTileComposed[64]; /*02020B40/80/C0*/
extern uint8_t gDescriptionPages[],gDescriptionPage,gDescriptionPageCount; /*0201CB58/50/51*/
extern uint8_t gBackgroundBuffer[],gPaletteBuffer[];
extern uint16_t gBgOffsetsRaw[22],gKeysPressed;
extern const uint8_t *const gAsciiGlyphCodes[];
extern const uint8_t *GetLanguageSegmentPointer(const uint8_t *);
extern void CardArtUndoRowDeltas(uint8_t *),RenderBitmapGlyph(void *,uint16_t,uint16_t),RenderBitmapString(void *,const uint8_t *,uint16_t);
extern void FormatDecimalDigits(uint16_t,uint8_t),WaitForFrame(void),SetVBlankCallback(void (*)(void));
extern void UploadBackgroundOffsets(void),UploadPalettes(void),PlayGameAudio(uint32_t);
#define ROM(a) ((const uint8_t *)(uintptr_t)(a))
#define REG(a) (*(volatile uint16_t *)(uintptr_t)(a))
static uint16_t Read16(const uint8_t *p) { return p[0]|(uint16_t)p[1]<<8; }
static const uint8_t *Pointer(const uint8_t *p) { return ROM(p[0]|(uint32_t)p[1]<<8|(uint32_t)p[2]<<16|(uint32_t)p[3]<<24); }
static const uint8_t *TablePointer(uint32_t address,unsigned index) { return Pointer(ROM(address)+index*4); }
/*08008E78*/
void CompositeCardTile(void)
{ for(unsigned i=0;i<64;++i)gCardTileComposed[i]=gCardTileForeground[i]?gCardTileForeground[i]:gCardTileBackground[i]; }
static void Overlay(unsigned offset,const void *tile)
{
    BiosCpuSet(tile,gCardTileForeground,0x04000010);BiosCpuSet(gFullCardTiles+offset,gCardTileBackground,0x04000010);
    CompositeCardTile();BiosCpuSet(gCardTileComposed,gFullCardTiles+offset,0x04000010);
}
/*08009118 /08018F44 /08018FC8*/
void LoadFullCardFrame(void)
{
    BiosCpuSet(ROM(0x089489A8),gFullCardMap,266);
    for(unsigned i=0;i<266;++i)gFullCardMap[i]+=101;
    BiosCpuSet(ROM(0x0894681C),gFullCardTiles+0x1940,0x04000800);
    BiosCpuSet(TablePointer(0x08D53584,gCardMetadataBytes[0x19]),gFullCardPalette+0x80,0x0400000A);
}
void LoadFullCardArt(void)
{
    unsigned card=Read16(gCardMetadataBytes+0x10);BiosHuffmanUnpack(TablePointer(0x08D51958,card),gFullCardTiles+64);
    CardArtUndoRowDeltas(gFullCardTiles+64);uint16_t zero=0;BiosCpuSet(&zero,gFullCardTiles,0x01000020);
    BiosCpuSet(TablePointer(0x08D5276C,card),gFullCardPalette,0x04000020);gFullCardPalette[0]=gFullCardPalette[1]=0;
    for(unsigned row=0;row<10;++row)BiosCpuSet(ROM(0x08946754)+row*20,gFullCardMap+72+row*14,0x04000005);
}
/*08019064 /080190D4*/
void LoadFullCardAttribute(void)
{
    unsigned attribute=gCardMetadataBytes[0x17];if(!attribute)return;
    BiosCpuSet(TablePointer(0x08D53698,attribute),gFullCardPalette+0xAC,7);
    const uint8_t *tiles=TablePointer(0x08D53668,attribute);
    BiosCpuSet(tiles,gFullCardTiles+0x3200,0x04000020);BiosCpuSet(tiles+128,gFullCardTiles+0x3400,0x04000020);
}
void LoadFullCardType(void)
{
    uint8_t type=gCardMetadataBytes[0x16];if(!type)return;
    BiosCpuSet(TablePointer(0x08D53608,type),gFullCardPalette+0xBA,11);
    unsigned width=(uint8_t)(type-21)<3?4:2,control=0x04000000|(width<<4);
    const uint8_t *tiles=TablePointer(0x08D535A8,type);
    BiosCpuSet(tiles,gFullCardTiles+0x3180,control);BiosCpuSet(tiles+width*64,gFullCardTiles+0x3380,control);
}
/*0801916C /080191E0 /080192B8*/
void DrawFullCardLevel(void)
{ unsigned level=gCardMetadataBytes[0x18];if(level>12)level=12;for(;level;--level)Overlay((114-level)*64,ROM(0x08948BBC)); }
static void DrawFullCardStat(unsigned defense)
{
    FormatDecimalDigits(Read16(gCardMetadataBytes+0x12+defense*2),0);
    for(unsigned i=0;i<5;++i) {
        unsigned offset=(114+defense*5+i)*64;
        if(gDecimalDigits[i]!=10)Overlay(offset,ROM(0x08948BFC)+(gDecimalDigits[i]+2)*64);
        else if(!i && gDecimalDigits[4]!=10)Overlay(offset,ROM(defense?0x08948BFC:0x08948C3C));
    }
}
/*08019390: cards364/670 abbreviate the second English title glyph.*/
void DrawFullCardName(void)
{
    unsigned card=Read16(gCardMetadataBytes+0x10),abbreviate=!gLanguage && (card==364 || card==670);
    const uint8_t *p=GetLanguageSegmentPointer(Pointer(gCardMetadataBytes));
    for(unsigned i=0;i<10 && *p && *p!='$';++i) {
        uint16_t code;
        if(abbreviate && i==1) { code=0x4481;p+=4; }
        else if(*p&128) { code=Read16(p);p+=2; }
        else { code=Read16(gAsciiGlyphCodes[*p-32]);++p; }
        uint32_t glyph[16],zero=0;RenderBitmapGlyph(glyph,code,0x44A);
        BiosCpuSet(&zero,gCardTileForeground,0x05000010);BiosCpuSet(glyph,gCardTileForeground+40,0x04000006);
        Overlay((i*2+133)*64,gCardTileForeground);
        BiosCpuSet(&zero,gCardTileForeground,0x05000010);BiosCpuSet((uint8_t *)glyph+24,gCardTileForeground,0x0400000A);
        Overlay((i*2+134)*64,gCardTileForeground);
    }
}
/*08018F1C*/
void ComposeFullCard(void)
{ LoadFullCardFrame();LoadFullCardArt();LoadFullCardAttribute();LoadFullCardType();DrawFullCardLevel();DrawFullCardStat(0);DrawFullCardStat(1);DrawFullCardName(); }
static void CopyNameGlyph(uint8_t *out,uint8_t *index,const uint8_t **source)
{ if(**source&128) { out[(*index)++]=*(*source)++; }out[(*index)++]=*(*source)++; }
/*080070D4: long titles interleave two lines into the small-font tile layout.*/
void DrawCardDetailName(void)
{
    const uint8_t *source=GetLanguageSegmentPointer(Pointer(gCardMetadataBytes)),*suffix=source;
    uint8_t bytes=0,glyphs=0,last_word=0;unsigned in_word=0,passed30=0;
    while(source[bytes] && source[bytes]!='$') {
        if(!in_word) { suffix=source+bytes;last_word=glyphs; }
        if(source[bytes]&128) { bytes+=2;in_word=1; }
        else { in_word=source[bytes]!=' ' || passed30;++bytes; }
        ++glyphs;if(glyphs>30)passed30=1;
    }
    uint8_t suffix_count=0,first_count=glyphs,limit=glyphs;
    if(glyphs>30) { suffix_count=(uint8_t)(glyphs-last_word)|128;first_count=last_word;limit=30; }
    uint8_t out[124],at=0;
    for(unsigned i=0;i<limit;++i) {
        if((i&3)==2 && (suffix_count&128))for(unsigned n=0;n<2;++n) {
            if(suffix_count&127) { CopyNameGlyph(out,&at,&suffix);--suffix_count; }else out[at++]=' ';
        }
        if(i<first_count)CopyNameGlyph(out,&at,&source);else out[at++]=' ';
        if((i&3)==3 && (suffix_count&128))for(unsigned n=0;n<2;++n) {
            if(suffix_count&127) { CopyNameGlyph(out,&at,&suffix);--suffix_count; }else out[at++]=' ';
        }
    }
    out[at]=0;RenderBitmapString(gBackgroundBuffer+0x4020,out,suffix_count&128?0x801:0x901);
}
/*080072F4: five initial blanks followed by the low16 bits of card cost.*/
static void DrawCardDetailCost(void)
{
    FormatDecimalDigits(Read16(gCardMetadataBytes+12),0);uint8_t *out=gBackgroundBuffer+0x5000;
    for(unsigned i=0;i<10;++i) {
        unsigned digit=i<5?10:gDecimalDigits[i-5];uint16_t code=0x4081;
        if(digit!=10) { uint16_t native=0x824F+digit;code=(native<<8)|(native>>8); }
        RenderBitmapGlyph(out,code,0x101);out+=i&1?96:32;
    }
}
/*080073D0 /08006E58*/
void LoadCardDescriptionPage(const uint8_t *page) { BiosCpuFastSet(page,gBackgroundBuffer+0x5280,0x460); }
void LoadCardDetailBackground(const uint8_t *page)
{
    for(unsigned row=0;row<20;++row)BiosCpuSet(ROM(0x0808E2D0)+row*62,gBackgroundBuffer+0xF800+row*64,31);
    BiosLz77UnpackWram(ROM(0x0808BA8C),gBackgroundBuffer+0x8000);BiosCpuSet(ROM(0x0808E1D0),gPaletteBuffer+0x100,0x04000040);
    /* Decompiled DAT is a halfword array: native destination stride is64. */
    for(unsigned row=0;row<20;++row)BiosCpuSet(ROM(0x0808B5DC)+row*60,gBackgroundBuffer+0xF000+row*64,0x0400000F);
    DrawCardDetailName();DrawCardDetailCost();
    RenderBitmapString(gBackgroundBuffer+0x4880,TablePointer(0x08D4BC3C,gCardMetadataBytes[0x16]),0x901);
    RenderBitmapString(gBackgroundBuffer+0x4C00,TablePointer(0x08D419E0,gCardMetadataBytes[0x17]),0x901);
    LoadCardDescriptionPage(page);ComposeFullCard();
    for(unsigned row=0;row<19;++row)BiosCpuSet(gFullCardMap+row*14,gBackgroundBuffer+0xE840+row*64,14);
    BiosCpuSet(gFullCardPalette,gPaletteBuffer,128);BiosCpuSet(gFullCardTiles,gBackgroundBuffer,0x2000);
}
/*08022F04 /08016204*/
static void ClearDescriptionBackground(void)
{ uint16_t zero=0;for(unsigned i=0;i<4;++i)BiosCpuSet(&zero,gBackgroundBuffer+i*0x4000,0x01002000); }
/*08016174 /161CC /16210*/
static void DescriptionBlankCallback(void)
{
    REG(0x05000000)=0;REG(0x04000000)=0;REG(0x0400000A)=0x1D81;REG(0x0400000C)=0x1E06;REG(0x0400000E)=0x1F0B;
    REG(0x04000050)=gBgOffsetsRaw[8];REG(0x04000052)=gBgOffsetsRaw[14];REG(0x04000054)=gBgOffsetsRaw[12];UploadBackgroundOffsets();
}
static void DescriptionShowCallback(void) { UploadPalettes();REG(0x04000000)=0x0E00; }
/*08015DD8. Page-byte and character counters retain native byte wrapping.*/
void ShowCardDescription(void)
{
    uint32_t zero=0;for(unsigned i=0;i<2;++i)BiosCpuFastSet(&zero,gDescriptionPages+i*0x1180,0x01000460);
    const uint8_t *p=GetLanguageSegmentPointer(Pointer(gCardMetadataBytes+8)+2);uint8_t page[144];
    if(*p=='^') {
        gDescriptionPageCount=p[1]>='2' && p[1]<='9'?p[1]-'0':1;p+=2;gDescriptionPage=0;
        while(gDescriptionPage<gDescriptionPageCount) {
            uint8_t at=0,count=0;
            while(*p!='^') {
                CopyNameGlyph(page,&at,&p);++count;
                if(count==12) { page[at++]=' ';if(!gDescriptionPage)page[at++]=' ';else { page[at++]=0x81;page[at++]=0xA2; }count=14; }
            }
            if(gDescriptionPage<gDescriptionPageCount-1) { while(count<69) { page[at++]=' ';++count; }page[at++]=0x81;page[at++]=0xA4; }
            else while(count<70) { page[at++]=' ';++count; }
            ++p;page[at]=0;RenderBitmapString(gDescriptionPages+gDescriptionPage*0x1180,page,0x901);++gDescriptionPage;
        }
    }else {
        uint8_t at=0;while(*p && *p!='$') { page[at++]=*p++;if(at==12) { page[12]=page[13]=' ';at=14; } }
        page[at]=0;RenderBitmapString(gDescriptionPages,page,0x901);gDescriptionPageCount=0;
    }
    gDescriptionPage=0;ClearDescriptionBackground();LoadCardDetailBackground(gDescriptionPages);
    gBgOffsetsRaw[8]=gBgOffsetsRaw[14]=gBgOffsetsRaw[12]=0;gBgOffsetsRaw[10]=0x1FA;gBgOffsetsRaw[18]=0;
    gBgOffsetsRaw[2]=0x1FF;gBgOffsetsRaw[20]=0;gBgOffsetsRaw[6]=0;gBgOffsetsRaw[0]=4;
    SetVBlankCallback(DescriptionBlankCallback);WaitForFrame();
    for(unsigned i=0;i<4;++i)BiosCpuSet(gBackgroundBuffer+i*0x4000,(void *)(uintptr_t)(0x06000000+i*0x4000),0x2000);
    SetVBlankCallback(DescriptionShowCallback);WaitForFrame();
    for(;;) {
        if((gKeysPressed&64) && gDescriptionPageCount>1 && gDescriptionPage) {
            --gDescriptionPage;PlayGameAudio(54);LoadCardDescriptionPage(gDescriptionPages+gDescriptionPage*0x1180);
            BiosCpuSet(gBackgroundBuffer+0x4000,(void *)0x06004000,0x2000);
        }
        if((gKeysPressed&128) && gDescriptionPageCount>1 && gDescriptionPage<gDescriptionPageCount-1) {
            ++gDescriptionPage;PlayGameAudio(54);LoadCardDescriptionPage(gDescriptionPages+gDescriptionPage*0x1180);
            BiosCpuSet(gBackgroundBuffer+0x4000,(void *)0x06004000,0x2000);
        }
        if(gKeysPressed&2)break;WaitForFrame();
    }
    PlayGameAudio(56);ClearDescriptionBackground();
}
