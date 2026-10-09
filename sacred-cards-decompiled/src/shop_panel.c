/* AY7E shop status panel0801CF94..0801DDE0. Tile writes preserve the native
 * palette bits and, where specified, the original OR-without-clearing writes. */
#include "gba_bios.h"
extern uint8_t gBackgroundBuffer[],gPaletteBuffer[],gCardMetadataBytes[0x1E],gDecimalDigits[5],gMoneyDigits[19];
extern uint8_t gDecimalDigitLookahead; /* 02020C05: read by0801DDE0 before formatting */
extern uint8_t gShopWorkingStock[901],gShopWorkingCollection[901];
extern uint16_t gPlayerDeck[40];
extern uint64_t gMoney,gShopBuyPrice,gShopSellPrice;
extern void LoadCardMetadata(uint32_t),FormatDecimalDigits(uint16_t,uint8_t),FormatMoneyDigits(uint64_t,uint8_t);
extern uint32_t CanReceiveMoney(uint64_t);
extern uint16_t GetLanguageSegmentOffset(const uint8_t *);
extern void RenderBitmapString(void *,const uint8_t *,uint16_t);
extern void LoadAttributeIcon(uint8_t,uint8_t *),LoadAttributePalette(uint8_t,uint8_t *),LoadTypeIcon(uint8_t,uint8_t *),LoadTypePalette(uint8_t,uint8_t *);
static uint16_t U16(const uint8_t *p) { return p[0]|(uint16_t)p[1]<<8; }
static uint16_t *Tile(unsigned offset) { return (uint16_t *)(gBackgroundBuffer+offset); }
static uint16_t Card(void) { return U16(gCardMetadataBytes+0x10); }
static void Put(uint16_t *p,uint16_t tile) { *p=(*p&0xF000)|tile; }
extern uint8_t CountPlayerDeckCard(uint16_t);
/*0801DB54*/
static void DrawNumber(void)
{
    uint16_t *p=Tile(0xFCC2);if(!Card()) { for(unsigned i=0;i<4;++i)Put(p+i,0x19F);return; }
    FormatDecimalDigits(Card(),1);for(unsigned i=0;i<4;++i)Put(p+i,0x195+gDecimalDigits[i]);
}
/*0801DA98*/
static void DrawName(void)
{
    uint16_t zero=0;BiosCpuSet(&zero,gBackgroundBuffer+0xF620,0x010000F0);
    uint32_t address=gCardMetadataBytes[0]|(uint32_t)gCardMetadataBytes[1]<<8|(uint32_t)gCardMetadataBytes[2]<<16|(uint32_t)gCardMetadataBytes[3]<<24;
    const uint8_t *text=(const uint8_t *)(uintptr_t)address;uint16_t offset=GetLanguageSegmentOffset(text);uint8_t name[32];unsigned n=0,characters=0;
    while(characters<15 && text[offset] && text[offset]!='$') {
        if(text[offset]&128) { name[n++]=text[offset];++offset; }name[n++]=text[offset];++offset;++characters;
    }
    while(characters++<16)name[n++]=0;RenderBitmapString(gBackgroundBuffer+0xF620,name,0x801);
}
/*0801DA58/1D9D8*/
static void DrawIcons(void)
{
    LoadAttributeIcon(gCardMetadataBytes[0x17],gBackgroundBuffer+0xF5A0);LoadAttributePalette(gCardMetadataBytes[0x17],gPaletteBuffer+0x180);
    LoadTypeIcon(gCardMetadataBytes[0x16],gBackgroundBuffer+0xF520);LoadTypePalette(gCardMetadataBytes[0x16],gPaletteBuffer+0x160);
}
static void DrawLevel(void)
{
    uint16_t *p=Tile(0xFC68);if(!gCardMetadataBytes[0x18]) { for(unsigned i=0;i<3;++i)Put(p+i,0);return; }
    FormatDecimalDigits(gCardMetadataBytes[0x18],1);p[0]=0xA1A0;Put(p+1,0x195+gDecimalDigits[0]);Put(p+2,0x195+gDecimalDigits[1]);
}
/*0801D860*/
static void DrawStats(void)
{
    for(unsigned stat=0;stat<2;++stat) {
        uint16_t *p=Tile(0xFCBA+stat*64),value=U16(gCardMetadataBytes+0x12+stat*2);
        if(value==65535) { for(unsigned i=0;i<6;++i)Put(p-i,0);continue; }
        FormatDecimalDigits(value,0);for(unsigned i=0;i<4;++i)p[-(int)i]=0xD000|(0x195+gDecimalDigits[4-i]);
        if(gDecimalDigits[0]==10) { p[-4]=0xA1A1+stat;Put(p-5,0); }
        else { p[-4]=0xD000|(0x195+gDecimalDigits[0]);p[-5]=0xA1A1+stat; }
    }
}
/*0801D794/1DBD0/1DCD8*/
static void DrawCount(unsigned kind)
{
    static const uint16_t offsets[]={0xFC40,0xFC54,0xFC94},labels[]={0x152,0x14C,0x140};
    uint16_t *p=Tile(offsets[kind]);unsigned written=0;
    if(Card()) {
        for(unsigned i=0;i<7;++i) { uint16_t t=i==6?0x182:labels[kind]+i;if(!kind)*p=0xD000|t;else Put(p,t);++p; }
        written=7;unsigned count=kind==0?gShopWorkingStock[Card()]:kind==1?gShopWorkingCollection[Card()]:CountPlayerDeckCard(Card());
        FormatDecimalDigits(count,1);
        for(unsigned i=0;i<3 && gDecimalDigits[i]!=10;++i,++written,++p) { if(!kind)*p=0xD000|(0x195+gDecimalDigits[i]);else Put(p,0x195+gDecimalDigits[i]); }
    }
    while(written++<10)Put(p++,0);
}
/* Native first suffix tile is cleared; the next five are only ORed. */
static void MoneySuffix(uint16_t *p)
{ Put(p,0x1A8);for(unsigned i=1;i<6;++i)p[-(int)i]|=0x1A8-i; }
static unsigned MoneyNumber(uint16_t **pointer,uint64_t value,int palette)
{
    uint16_t *p=*pointer;FormatMoneyDigits(value,0);unsigned n=0;
    while(n<16 && gMoneyDigits[18-n]!=10) {
        uint16_t t=0x195+gMoneyDigits[18-n];if(palette<0)Put(p,t);else *p=palette|t;--p;++n;
    }
    *pointer=p;return n;
}
/*0801D00C/1D174*/
static void DrawPrice(int selling)
{
    uint16_t *p=Tile(0xF8BA);unsigned n=0;
    if(Card()) {
        MoneySuffix(p);p-=6;n=6+MoneyNumber(&p,selling?gShopSellPrice:gShopBuyPrice,-1);Put(p,0);
        for(unsigned i=1;i<=6;++i)Put(p-i,(selling?0x14C:0x18F)-i);p-=7;n+=7;
    }
    while(n++<23)Put(p--,0);
}
/*0801D2DC/1D4A4*/
static void DrawRemainingMoney(int selling)
{
    uint16_t *p=Tile(0xF8FA);unsigned n=0;
    if(Card()) {
        if(selling) {
            uint64_t value=CanReceiveMoney(gShopSellPrice)==1?gMoney+gShopSellPrice:UINT64_C(9999999999999);
            MoneySuffix(p);p-=6;n=6+MoneyNumber(&p,value,-1);Put(p,0);
            for(unsigned i=1;i<=6;++i)Put(p-i,0x189-i);
        }else {
            int shortfall=gMoney<gShopBuyPrice;uint16_t palette=shortfall?0xE000:0xD000;
            for(unsigned i=0;i<6;++i)p[-(int)i]=palette|(0x1A8-i);p-=6;
            n=6+MoneyNumber(&p,shortfall?gShopBuyPrice-gMoney:gMoney-gShopBuyPrice,palette);
            if(shortfall) { *p--=palette|0x181;++n; }Put(p,0);
            for(unsigned i=1;i<=6;++i)p[-(int)i]=palette|(0x189-i);
        }
        p-=7;n+=7;
    }
    while(n++<24)Put(p--,0);
}
/*0801DDE0. The first loop condition reads byte02020C05, outside the five
 * formatted digits, and later conditions read the previous digit. Retained
 * explicitly rather than silently correcting this native boundary quirk. */
static void DrawCost(void)
{
    uint16_t *p=Tile(0xFC7A);unsigned n=0;
    if(!Card()) { for(unsigned i=0;i<7;++i)Put(p--,0);return; }
    uint8_t previous=gDecimalDigitLookahead;
    while(previous!=10 && n<5) {
        FormatDecimalDigits(U16(gCardMetadataBytes+0x0C),0);Put(p--,0x195+gDecimalDigits[4-n]);++n;
        if(n<5)previous=gDecimalDigits[5-n];
    }
    while(n++<4)Put(p--,0);
    Put(p+1,0x13F);Put(p,0x13E);Put(p-1,0x13D);Put(p-2,0x13C);
}
static void DrawPanel(uint16_t card,int selling)
{
    LoadCardMetadata(card);DrawNumber();DrawName();DrawIcons();DrawLevel();DrawStats();DrawCount(0);DrawCount(1);
    DrawPrice(selling);DrawRemainingMoney(selling);DrawCount(2);DrawCost();
}
void DrawShopBuyPanel(uint16_t card) { DrawPanel(card,0); }
void DrawShopSellPanel(uint16_t card) { DrawPanel(card,1); }
