/* AY7E unused shop money rows0801C6EC..1CB04 and0801D65C/1D6F8.
 * These older views have a different suffix arrangement from the live panel. */
#include <stdint.h>
extern uint8_t gBackgroundBuffer[],gCardMetadataBytes[0x1E],gMoneyDigits[19];
extern uint64_t gMoney,gShopBuyPrice,gShopSellPrice;
extern void FormatMoneyDigits(uint64_t,uint8_t);
extern uint32_t CanReceiveMoney(uint64_t);
static void Put(uint16_t *p,uint16_t tile) { *p=(*p&0xF000)|tile; }
static void DrawLegacyMoney(unsigned offset,uint64_t value,uint16_t label,unsigned width,uint8_t negative)
{
    uint16_t *p=(uint16_t *)(gBackgroundBuffer+offset);unsigned n=0;FormatMoneyDigits(value,0);
    while(n<16 && gMoneyDigits[18-n]!=10) { Put(p--,gMoneyDigits[18-n]+0x195);++n; }
    if(negative) { Put(p--,0x181);++n; }
    Put(p,0);for(unsigned i=1;i<=6;++i)Put(p-i,label+6-i);p-=6;n+=7;
    while(n<=width) { --p;Put(p,0);++n; }
}
/*0801C6EC/1C7DC/1C8CC/1C9BC/1CB04*/
void DrawLegacyShopMoney(void) { DrawLegacyMoney(0xA336,gMoney,0x18F,19,0); }
void DrawLegacyShopBuyPrice(void) { DrawLegacyMoney(0xA0B6,gShopBuyPrice,0x189,19,0); }
void DrawLegacyShopSellPrice(void) { DrawLegacyMoney(0xA0B6,gShopSellPrice,0x189,19,0); }
void DrawLegacyShopAfterPurchase(void)
{ uint8_t negative=gMoney<gShopBuyPrice;DrawLegacyMoney(0xA136,negative?gShopBuyPrice-gMoney:gMoney-gShopBuyPrice,0x183,20,negative); }
void DrawLegacyShopAfterSale(void)
{ DrawLegacyMoney(0xA136,CanReceiveMoney(gShopSellPrice)==1?gMoney+gShopSellPrice:UINT64_C(9999999999999),0x183,20,0); }
/*0801D65C/1D6F8: compact decimal digits followed by a two-tile label.*/
static void DrawLegacyPanelPrice(uint64_t value)
{
    uint16_t *p=(uint16_t *)(gBackgroundBuffer+0xFCC2);unsigned n=0;
    if(gCardMetadataBytes[0x10] || gCardMetadataBytes[0x11]) {
        FormatMoneyDigits(value,1);while(n<16 && gMoneyDigits[n]!=10) { *p++=0xD000|(gMoneyDigits[n]+0x195);++n; }
        *p++=0xD183;*p++=0xD184;n+=2;
    }while(n++<18)Put(p++,0);
}
void DrawLegacyPanelBuyPrice(void) { DrawLegacyPanelPrice(gShopBuyPrice); }
void DrawLegacyPanelSellPrice(void) { DrawLegacyPanelPrice(gShopSellPrice); }
