/* AY7E wager-list graphics08007D94..08008B74 and shared sprite helpers.
 * The list has five visible rows; the center row occupies an extra line. */
#include "gba_bios.h"
extern uint8_t gBackgroundBuffer[],gActorGraphicsBuffer[],gPaletteBuffer[],gCardMetadataBytes[0x1E],gDecimalDigits[5];
extern uint8_t gCollectionMenu[12],gCardCollection[901],gPlayerDeckState[10]; /*02020C50*/
extern uint16_t gPlayerDeck[40],gOamBuffer[128][4],gCollectionScrollPosition,gCollectionScrollLimit; /*02020AF8/20AFA*/
extern uint16_t CollectionCardAt(uint8_t);
extern uint32_t GetDeckCapacity(void);
extern uint8_t CountPlayerDeckCard(uint16_t);
extern void LoadCardMetadata(uint32_t),FormatDecimalDigits(uint16_t,uint8_t),RenderBitmapString(void *,const uint8_t *,uint16_t);
extern void LoadFramedMiniature(uint8_t *,uint16_t),LoadAttributePalette(uint8_t,uint8_t *),LoadTypePalette(uint8_t,uint8_t *);
#define ROM(a) ((const uint8_t *)(uintptr_t)(a))
static uint16_t U16(const uint8_t *p) { return p[0]|(uint16_t)p[1]<<8; }
static uint32_t U32(const uint8_t *p) { return U16(p)|(uint32_t)U16(p+2)<<16; }
static const uint8_t *Pointer(uint32_t a,unsigned i) { return ROM(U32(ROM(a)+i*4)); }
static uint16_t *Tiles(unsigned offset) { return (uint16_t *)(gBackgroundBuffer+offset); }
static unsigned Row(unsigned i) { return i*3+(i<2?0:i==2?1:2)+2; }
static void Map(uint32_t source,unsigned offset)
{ for(unsigned i=0;i<20;++i)BiosCpuSet(ROM(source)+i*60,gBackgroundBuffer+offset+i*64,0x0400000F); }
/*080059DC/05A00/05A70/05A74*/
void InitializeCollectionSprites(unsigned stage)
{
    uint16_t zero=0;if(!stage)BiosCpuSet(&zero,gOamBuffer,0x01000200);
    if(stage==1) {
        BiosCpuSet(ROM(0x08087EFC),gPaletteBuffer+0x362,16);BiosCpuSet(ROM(0x08086EFC),gActorGraphicsBuffer+0x4400,0x04000400);
        BiosCpuSet(ROM(0x08087FBC),gPaletteBuffer+0x380,16);BiosCpuSet(ROM(0x08087F3C),gActorGraphicsBuffer+0x2400,32);
        BiosCpuSet(ROM(0x08087F7C),gActorGraphicsBuffer+0x2800,32);
    }
}
/*08005A78*/
static void Scrollbar(void)
{
    unsigned n=0;if(gCollectionScrollLimit && gCollectionScrollPosition<=gCollectionScrollLimit)n=gCollectionScrollPosition*124/gCollectionScrollLimit;
    gOamBuffer[5][0]=0x2400|(uint8_t)(n+25);gOamBuffer[5][1]=0x1FF;gOamBuffer[5][2]=0x62A;
}
/*080058AC/08B1C*/
void DrawCollectionSortIcon(uint8_t sort)
{
    uint16_t *p=Tiles(0xB838);p[0]=sort*4+0x5002;p[1]=sort*4+0x5003;p[32]=sort*4+0x5004;p[33]=sort*4+0x5005;
}
static void Backdrop(void)
{ BiosLz77UnpackWram(ROM(0x0807F458),gBackgroundBuffer);Map(0x08081B2C,0x3800);BiosCpuSet(ROM(0x0808248C),gPaletteBuffer,0x04000020); }
/*08007F68*/
static void Header(unsigned editor)
{
    uint16_t zero=0;BiosCpuSet(&zero,gBackgroundBuffer+0x8000,0x01000010);BiosCpuSet(&zero,gBackgroundBuffer+0xB800,0x01000400);
    RenderBitmapString(gBackgroundBuffer+0x8020,ROM(editor?0x08086E38:0x080AAC00),0x801);RenderBitmapString(gBackgroundBuffer+0x8040,ROM(editor?0x08086E3C:0x080AAC04),0x901);
    *Tiles(0xB85E)=0x5001;FormatDecimalDigits(GetDeckCapacity(),0);for(unsigned i=0;i<5;++i)Tiles(0xB860)[i]=0x5209+gDecimalDigits[i];
    *Tiles(0xB870)=0x5001;*Tiles(0xB872)=0x520D;*Tiles(0xB874)=0x5209;
}
/*08008044*/
static void ListTiles(unsigned editor)
{
    BiosCpuSet(ROM(0x08084F9C),gPaletteBuffer+0xA0,0x04000008);BiosCpuSet(ROM(0x08084FBC),gPaletteBuffer+0x80,0x04000008);
    for(unsigned i=0;i<3;++i)BiosCpuSet(ROM(0x080845DC+i*32),gBackgroundBuffer+0xC020+i*32,0x04000008);
    RenderBitmapString(gBackgroundBuffer+0xC080,ROM(editor?0x08086EB8:0x080AAC80),0x801);RenderBitmapString(gBackgroundBuffer+0xC120,ROM(editor?0x08086EE4:0x080AACAC),0x1801);
    for(unsigned i=0;i<12;++i)BiosCpuSet(Pointer(0x08D30E8C,i),gBackgroundBuffer+0xC000+(i*4+0x13)*32,0x04000020);
    unsigned offset=0;for(unsigned i=0;i<24;++i) {
        unsigned wide=(uint8_t)(i-21)<3;BiosCpuSet(Pointer(0x08D30DFC,i),gBackgroundBuffer+0xC000+(offset+0x43)*32,wide?0x04000040:0x04000020);offset+=wide?8:4;
    }
    Map(0x08084AEC,0xF800);
    for(unsigned row=0;row<5;++row)for(unsigned x=0;x<7;++x)for(unsigned y=0;y<2;++y)for(unsigned half=0;half<2;++half)
        Tiles(0xF800)[(Row(row)+1+y)*32+2+x*2+half]=0x50F8+row*40+x*4+y*2+half;
    BiosCpuSet(ROM(0x089C54B0),gPaletteBuffer+0x200,0xA0);
}
/*08008254*/
extern uint16_t CollectionAddPalette(uint16_t),DeckCostPalette(void),DeckCountPalette(void);
extern const uint8_t *GetLanguageSegmentPointer(const uint8_t *);
/*08004F88 collection names use the selected language and eighteen glyphs.
 *08008254 wager names instead take a twenty-byte prefix of the raw string.*/
static void CollectionName(uint8_t *destination,const uint8_t *source)
{
    const uint8_t *text=GetLanguageSegmentPointer(source);uint8_t name[37],offset=0,count=0,written=0;
    while(text[offset] && text[offset]!='$') {
        unsigned width=text[offset]&128?2:1;
        if(count<18)for(unsigned i=0;i<width;++i)name[written++]=text[offset+i];
        offset+=width;++count;
    }
    name[written]=0;RenderBitmapString(destination,name,0x901);
}
static void ListCards(unsigned editor)
{
    uint32_t zero=0;BiosCpuSet(&zero,gBackgroundBuffer+0xDF00,0x05000640);
    for(unsigned row=0;row<5;++row) {
        uint16_t card=CollectionCardAt(row),palette=gCardCollection[card]?0x5000:0x4000;LoadCardMetadata(card);
        unsigned y=Row(row);uint16_t *map=Tiles(0xF800);FormatDecimalDigits(U16(gCardMetadataBytes+0x10),1);
        for(unsigned i=0;i<4;++i)map[y*32+1+i]=(gDecimalDigits[i]+9)|0x5000;
        /* Native strlen result is truncated to a byte before the comparison;
         * long strings take a20-byte prefix, not20 decoded glyphs. */
        const uint8_t *source=ROM(U32(gCardMetadataBytes));
        uint8_t name[21];if(editor)CollectionName(gBackgroundBuffer+0xDF00+row*0x500,source);
        else { unsigned length=0;while(source[length])++length;
        if((uint8_t)length<21) { for(unsigned i=0;i<=length;++i)name[i]=source[i]; }
        else { for(unsigned i=0;i<20;++i)name[i]=source[i];name[20]=0; }
        RenderBitmapString(gBackgroundBuffer+0xDF00+row*0x500,name,0x901); }
        for(unsigned i=0;i<12;++i)map[y*32+16-i]=i<gCardMetadataBytes[0x18]?0x5001:0x5000;
        if(editor)palette=CollectionAddPalette(CollectionCardAt(row));
        FormatDecimalDigits(gCardCollection[U16(gCardMetadataBytes+0x10)],1);
        for(unsigned i=0;i<3;++i)map[(y+1)*32+23+i]=(gDecimalDigits[i]+9)|palette;
        FormatDecimalDigits(CountPlayerDeckCard(U16(gCardMetadataBytes+0x10)),0);
        for(unsigned i=0;i<3;++i)map[(y+2)*32+23+i]=(gDecimalDigits[2+i]+9)|0x5000;
        LoadFramedMiniature(gActorGraphicsBuffer+0x400+(row&3)*256+(row>>2)*0x1000,U16(gCardMetadataBytes+0x10));
        gOamBuffer[row][0]=(gOamBuffer[row][0]&0x3300)|0x2000|(row==2?0x400:0)|(uint8_t)(row*32+12);
        gOamBuffer[row][1]=(gOamBuffer[row][1]&0x3E00)|0x8000|210;
        gOamBuffer[row][2]=(gOamBuffer[row][2]&0xF000)|0x800|((row&3)*8+32+(row>>2)*128);
    }
    uint16_t palette=editor?DeckCostPalette():0x5000;
    FormatDecimalDigits((uint16_t)U32(gPlayerDeckState),0);for(unsigned i=0;i<5;++i)Tiles(0xB854)[i]=palette+0x209+gDecimalDigits[i];
    palette=editor?DeckCountPalette():0x5000;
    FormatDecimalDigits(gPlayerDeckState[8],0);for(unsigned i=0;i<2;++i)Tiles(0xB86C)[i]=palette+0x209+gDecimalDigits[3+i];
    gCollectionScrollPosition=U16(gCollectionMenu);gCollectionScrollLimit=899;Scrollbar();
}
/*080085D8/086F4/087F0/089FC, dispatched by080085A0*/
static void DetailRows(void)
{
    uint16_t *map=Tiles(0xF800);unsigned mode=gCollectionMenu[3];
    if(mode==0 || mode>3) {
        for(unsigned row=0;row<5;++row)for(unsigned y=0;y<2;++y)for(unsigned x=0;x<6;++x)map[(Row(row)+1+y)*32+16+x]=0x5000;
        for(unsigned row=0;row<5;++row)for(unsigned y=0;y<2;++y)for(unsigned x=0;x<6;++x)
            map[(Row(row)+1+y)*32+16+x]=0x5114+row*40+(x/2)*4+y*2+x%2;
        return;
    }
    for(unsigned row=0;row<5;++row) {
        unsigned y=Row(row)+1;uint16_t *top=map+y*32+16,*bottom=top+32;
        if(mode==1) {
            LoadCardMetadata(CollectionCardAt(row));top[0]=0x5002;FormatDecimalDigits(U16(gCardMetadataBytes+0x12),0);
            for(unsigned i=0;i<5;++i)top[i+1]=gDecimalDigits[i]+0x2009;
            bottom[0]=0x5003;FormatDecimalDigits(U16(gCardMetadataBytes+0x14),0);for(unsigned i=0;i<5;++i)bottom[i+1]=gDecimalDigits[i]+0x1009;
        }else if(mode==2) {
            LoadCardMetadata(CollectionCardAt(row));top[0]=top[5]=bottom[0]=bottom[5]=0x5000;
            unsigned attr=gCardMetadataBytes[0x17],type=gCardMetadataBytes[0x16];LoadAttributePalette(attr,gPaletteBuffer+(row+11)*32);
            for(unsigned i=0;i<4;++i)map[(y+i/2)*32+19+i%2]=((row+11)<<12)|(attr*4+0x13+i);
            LoadTypePalette(type,gPaletteBuffer+(row+6)*32);unsigned wide=(uint8_t)(type-21)<3,width=wide?4:2;
            for(unsigned i=0;i<width*2;++i)map[(y+i/width)*32+17+i%width]=((row+6)<<12)|(wide?type*8-0x11+i:type*4+0x43+i);
        }else {
            top[0]=bottom[0]=0x5000;for(unsigned i=0;i<5;++i)top[i+1]=0x5004+i;
            LoadCardMetadata(CollectionCardAt(row));FormatDecimalDigits(U16(gCardMetadataBytes+0xC),0);
            for(unsigned i=0;i<5;++i)bottom[i+1]=gDecimalDigits[i]+0x5009;
        }
    }
}
static void DrawListGraphics(uint8_t stage,unsigned editor)
{
    switch(stage) {
    case 0:InitializeCollectionSprites(0);break;
    case 2:Backdrop();Header(editor);ListTiles(editor);ListCards(editor);DetailRows();DrawCollectionSortIcon(gCollectionMenu[2]);InitializeCollectionSprites(1);break;
    case 3:ListCards(editor);/*fall through*/
    case 4:DetailRows();InitializeCollectionSprites(3);break;
    case 5:InitializeCollectionSprites(3);break;
    case 7:ListCards(editor);DetailRows();DrawCollectionSortIcon(gCollectionMenu[2]);InitializeCollectionSprites(3);DetailRows();InitializeCollectionSprites(3);break;
    }
}

/*08007D94/047D8 differ in strings, name slicing and eligibility colors.*/
void DrawPreDuelGraphics(uint8_t stage) { DrawListGraphics(stage,0); }
void DrawCollectionEditorGraphics(uint8_t stage) { DrawListGraphics(stage,1); }
