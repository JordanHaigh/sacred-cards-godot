/* AY7E current-deck screen08014B28..080157B8. Its eighteen-glyph base
 * layout and twenty-two-glyph name buffer differ from the collection screen. */
#include "deck_builder.h"
#include "gba_bios.h"
extern uint8_t gBackgroundBuffer[],gActorGraphicsBuffer[],gPaletteBuffer[],gPlayerDeckState[10],gCardMetadataBytes[0x1E],gDecimalDigits[5];
extern uint16_t gOamBuffer[128][4],gCollectionScrollPosition,gCollectionScrollLimit;
extern uint32_t GetDeckCapacity(void);
extern uint16_t DeckCostPalette(void),DeckCountPalette(void);
extern void InitializeCollectionSprites(unsigned),DrawCollectionSortIcon(uint8_t),LoadCardMetadata(uint32_t),FormatDecimalDigits(uint16_t,uint8_t);
extern void LoadFramedMiniature(uint8_t *,uint16_t),RenderBitmapString(void *,const uint8_t *,uint16_t),LoadAttributePalette(uint8_t,uint8_t *),LoadTypePalette(uint8_t,uint8_t *);
extern const uint8_t *GetLanguageSegmentPointer(const uint8_t *);
#define ROM(a) ((const uint8_t *)(uintptr_t)(a))
static uint16_t U16(const uint8_t *p) { return p[0]|(uint16_t)p[1]<<8; }
static uint32_t U32(const uint8_t *p) { return U16(p)|(uint32_t)U16(p+2)<<16; }
static uint16_t *Tiles(unsigned offset) { return (uint16_t *)(gBackgroundBuffer+offset); }
static unsigned Row(unsigned row) { return row*3+(row<2?0:row==2?1:2)+2; }
static void Map(uint32_t address,unsigned offset)
{ for(unsigned row=0;row<20;++row)BiosCpuSet(ROM(address)+row*60,gBackgroundBuffer+offset+row*64,0x0400000F); }
static void InitializeGraphics(void)
{
    BiosLz77UnpackWram(ROM(0x0807F458),gBackgroundBuffer);BiosCpuSet(ROM(0x0808248C),gPaletteBuffer,0x04000020);Map(0x08081FDC,0x3800);
    uint16_t zero=0;BiosCpuSet(&zero,gBackgroundBuffer+0x8000,0x01000010);BiosCpuSet(&zero,gBackgroundBuffer+0xB800,0x01000400);
    RenderBitmapString(gBackgroundBuffer+0x8020,ROM(0x080B4A58),0x801);RenderBitmapString(gBackgroundBuffer+0x8040,ROM(0x080B4A5C),0x901);
    *Tiles(0xB85E)=0x5001;FormatDecimalDigits(GetDeckCapacity(),0);for(unsigned i=0;i<5;++i)Tiles(0xB860)[i]=gDecimalDigits[i]+0x5209;
    *Tiles(0xB870)=0x5001;*Tiles(0xB872)=0x520D;*Tiles(0xB874)=0x5209;
    for(unsigned i=0;i<3;++i)BiosCpuSet(ROM(0x080845DC+i*32),gBackgroundBuffer+0xC020+i*32,0x04000008);
    RenderBitmapString(gBackgroundBuffer+0xC080,ROM(0x080B4AD8),0x801);RenderBitmapString(gBackgroundBuffer+0xC120,ROM(0x080B4B04),0x1801);
    for(unsigned i=0;i<12;++i)BiosCpuSet(ROM(U32(ROM(0x08D30E8C)+i*4)),gBackgroundBuffer+0xC000+(i*4+0x13)*32,0x04000020);
    unsigned offset=0;for(unsigned i=0;i<24;++i) {
        unsigned wide=(uint8_t)(i-21)<3;BiosCpuSet(ROM(U32(ROM(0x08D30DFC)+i*4)),gBackgroundBuffer+0xC000+(offset+0x43)*32,wide?0x04000040:0x04000020);offset+=wide?8:4;
    }
    BiosCpuSet(ROM(0x08084F9C),gPaletteBuffer+0xA0,0x04000008);BiosCpuSet(ROM(0x08084FBC),gPaletteBuffer+0x80,0x04000008);Map(0x08084AEC,0xF800);
    for(unsigned row=0;row<5;++row)for(unsigned x=0;x<9;++x)for(unsigned y=0;y<2;++y)for(unsigned half=0;half<2;++half)
        Tiles(0xF800)[(Row(row)+1+y)*32+2+x*2+half]=0x50D0+row*48+x*4+y*2+half;
    BiosCpuSet(ROM(0x089C54B0),gPaletteBuffer+0x200,0xA0);
}
/*08015038: byte counters and language-segment stop rules retained. The local
 * buffer is sized for all22 double-byte glyphs; native ROM names fit its stack.*/
static void DrawName(uint8_t *destination)
{
    const uint8_t *text=GetLanguageSegmentPointer(ROM(U32(gCardMetadataBytes)));uint8_t name[45],offset=0,count=0,written=0;
    while(text[offset] && text[offset]!='$') {
        unsigned width=text[offset]&128?2:1;if(count<22)for(unsigned i=0;i<width;++i)name[written++]=text[offset+i];offset+=width;++count;
    }
    name[written]=0;RenderBitmapString(destination,name,0x901);
}
/*08015114, including the visible empty sprite after clearing its tile region.*/
static void Miniature(uint16_t card,unsigned row)
{
    if(card)LoadFramedMiniature(gActorGraphicsBuffer+0x400+(row&3)*256+(row>>2)*0x1000,card);
    gOamBuffer[row][0]=(gOamBuffer[row][0]&0x3300)|0x2000|(row==2?0x400:0)|(uint8_t)(row*32+12);
    gOamBuffer[row][1]=(gOamBuffer[row][1]&0x3E00)|0x8000|210;
    gOamBuffer[row][2]=(gOamBuffer[row][2]&0xF000)|0x800|((row&3)*8+32+(row>>2)*128);
}
/*08014E74/14FDC/150D0, and shared scrollbar08005A78.*/
static void Cards(void)
{
    uint32_t zero=0;BiosCpuSet(&zero,gBackgroundBuffer+0xDA00,0x05000780);BiosCpuSet(&zero,gActorGraphicsBuffer+0x400,0x05000800);
    for(unsigned row=0;row<5;++row) {
        LoadCardMetadata(PlayerDeckCardAt(row));uint16_t card=U16(gCardMetadataBytes+16),*p=Tiles(0xF800)+Row(row)*32;
        for(unsigned i=0;i<4;++i) { if(card) { FormatDecimalDigits(card,1);p[1+i]=0x5009+gDecimalDigits[i]; }else p[1+i]=0x5013; }
        DrawName(gBackgroundBuffer+0xDA00+row*0x600);
        for(unsigned i=0;i<12;++i)p[16-(int)i]=0x5000;
        for(unsigned i=0;i<gCardMetadataBytes[0x18];++i)p[16-(int)i]=0x5001;
        Miniature(card,row);
    }
    FormatDecimalDigits(PlayerDeckCost(),0);uint16_t pal=DeckCostPalette();for(unsigned i=0;i<5;++i)Tiles(0xB854)[i]=pal+0x209+gDecimalDigits[i];
    FormatDecimalDigits(PlayerDeckCount(),0);pal=DeckCountPalette();for(unsigned i=0;i<2;++i)Tiles(0xB86C)[i]=pal+0x209+gDecimalDigits[3+i];
    gCollectionScrollPosition=(int8_t)gPlayerDeckState[4];gCollectionScrollLimit=(uint16_t)(PlayerDeckCount()-1);
    unsigned n=0;if(gCollectionScrollLimit && gCollectionScrollPosition<=gCollectionScrollLimit)n=gCollectionScrollPosition*124/gCollectionScrollLimit;
    gOamBuffer[5][0]=0x2400|(uint8_t)(n+25);gOamBuffer[5][1]=0x1FF;gOamBuffer[5][2]=0x62A;
}
static void Details(void)
{
    unsigned mode=gPlayerDeckState[6];uint16_t *map=Tiles(0xF800);
    for(unsigned row=0;row<5;++row) {
        unsigned y=Row(row)+1;uint16_t *top=map+y*32+20,*bottom=top+32;
        if(!mode || mode>3) {
            for(unsigned i=0;i<6;++i) { top[i]=0x50F4+row*48+(i/2)*4+i%2;bottom[i]=top[i]+2; }continue;
        }
        LoadCardMetadata(PlayerDeckCardAt(row));
        if((mode==1 || mode==3) && !U16(gCardMetadataBytes+16)) { for(unsigned i=0;i<6;++i)top[i]=bottom[i]=0x5000;continue; }
        if(mode==1) {
            top[0]=0x5002;FormatDecimalDigits(U16(gCardMetadataBytes+0x12),0);for(unsigned i=0;i<5;++i)top[i+1]=0x2009+gDecimalDigits[i];
            bottom[0]=0x5003;FormatDecimalDigits(U16(gCardMetadataBytes+0x14),0);for(unsigned i=0;i<5;++i)bottom[i+1]=0x1009+gDecimalDigits[i];
        }else if(mode==2) {
            top[0]=top[5]=bottom[0]=bottom[5]=0x5000;unsigned attr=gCardMetadataBytes[0x17],type=gCardMetadataBytes[0x16];
            LoadAttributePalette(attr,gPaletteBuffer+(row+11)*32);for(unsigned i=0;i<4;++i)map[(y+i/2)*32+23+i%2]=((row+11)<<12)|(attr*4+0x13+i);
            LoadTypePalette(type,gPaletteBuffer+(row+6)*32);unsigned wide=(uint8_t)(type-21)<3,width=wide?4:2;
            for(unsigned i=0;i<width*2;++i)map[(y+i/width)*32+21+i%width]=((row+6)<<12)|(wide?type*8-0x11+i:type*4+0x43+i);
        }else {
            top[0]=bottom[0]=0x5000;for(unsigned i=0;i<5;++i)top[i+1]=0x5004+i;
            FormatDecimalDigits(U16(gCardMetadataBytes+12),0);for(unsigned i=0;i<5;++i)bottom[i+1]=0x5009+gDecimalDigits[i];
        }
    }
}
/*080146D0. Stage3 falls through to4 then5; stage6/7 share one full refresh.*/
void DrawDeckEditorGraphics(uint8_t stage)
{
    switch(stage) {
    case 0:InitializeCollectionSprites(0);break;
    case 2:InitializeGraphics();Cards();Details();DrawCollectionSortIcon(gPlayerDeckState[5]);InitializeCollectionSprites(1);break;
    case 3:Cards();/*fall through*/
    case 4:Details();/*fall through*/
    case 5:InitializeCollectionSprites(3);break;
    case 6:case 7:Cards();Details();DrawCollectionSortIcon(gPlayerDeckState[5]);InitializeCollectionSprites(3);break;
    }
}
