/* AY7E shop inventories and price arithmetic. Semantic C, not linked or
 * execution-compared. Transaction cores below exclude their native UI tails. */
#include <stdint.h>
extern uint8_t gCardCollection[901],gShopStock[901]; /* 02020770 / 02020DB0 */
extern uint8_t gShopWorkingStock[901],gShopWorkingCollection[901]; /* 02021140 / 02021CC0 */
extern const uint64_t gCardBasePrices[901]; /* 08D32D08 */
extern uint64_t gShopBuyPrice,gShopSellPrice; /* 02020B20 / 02020B28 */
extern uint16_t gShopPriceCard; /* 02020B30 */
extern uint8_t gShopPriceStock; /* 02020B32 */
extern void AddMoney(uint64_t),SubtractMoney(uint64_t);
extern uint32_t CanAfford(uint64_t);
extern void PlayGameAudio(uint32_t);

/* 08007414. Counts 1..250 have a price; all other byte values produce zero. */
void UpdateShopBuyPrice(void)
{
    gShopBuyPrice=0;
    if((uint8_t)(gShopPriceStock-1)<250) {
        gShopBuyPrice=(gCardBasePrices[gShopPriceCard]*(251u-gShopPriceStock))/250;
        if(!gShopBuyPrice)gShopBuyPrice=1;
    }
}
/* 08007470. At stock >=250 the base price is divided directly, not zeroed. */
void UpdateShopSellPrice(void)
{
    uint64_t price=gCardBasePrices[gShopPriceCard];
    if(gShopPriceStock<250)price*=250u-gShopPriceStock;
    gShopSellPrice=price/500;
    if(!gShopSellPrice)gShopSellPrice=1;
}
/* 08007404 */
void UpdateShopPrices(void) { UpdateShopBuyPrice();UpdateShopSellPrice(); }

/* 0801B730 / 0801B758. Signed remaining-space comparison is deliberate. */
uint8_t ShopCollectionHasSpace(uint16_t card,uint8_t n)
{ return n<=250-(int32_t)gShopWorkingCollection[card]; }
uint8_t ShopCollectionHasCards(uint16_t card,uint8_t n)
{ return n<=gShopWorkingCollection[card]; }
/* 0801B6B0 / 0801B6F0 skip card zero. */
void AddShopCollectionCard(uint16_t card,uint8_t n)
{ if(card)gShopWorkingCollection[card]=ShopCollectionHasSpace(card,n)?gShopWorkingCollection[card]+n:250; }
void RemoveShopCollectionCard(uint16_t card,uint8_t n)
{ if(card)gShopWorkingCollection[card]=ShopCollectionHasCards(card,n)?gShopWorkingCollection[card]-n:0; }
/* 0801C478 / 0801C4A0 / 0801C3F8 / 0801C438 */
uint8_t ShopStockHasSpace(uint16_t card,uint8_t n)
{ return n<=250-(int32_t)gShopWorkingStock[card]; }
uint8_t ShopStockHasCards(uint16_t card,uint8_t n)
{ return n<=gShopWorkingStock[card]; }
void AddShopWorkingStock(uint16_t card,uint8_t n)
{ if(card)gShopWorkingStock[card]=ShopStockHasSpace(card,n)?gShopWorkingStock[card]+n:250; }
void RemoveShopWorkingStock(uint16_t card,uint8_t n)
{ if(card)gShopWorkingStock[card]=ShopStockHasCards(card,n)?gShopWorkingStock[card]-n:0; }
/* 0801BF74 / 0801BED4: persistent stock addition accepts only IDs1..900. */
uint8_t PersistentShopStockHasSpace(uint16_t card,uint8_t n)
{ return n<=250-(int32_t)gShopStock[card]; }
void AddPersistentShopStock(uint16_t card,uint8_t n)
{
    if(card>=1 && card<=900)
        gShopStock[card]=PersistentShopStockHasSpace(card,n)?gShopStock[card]+n:250;
}
/* 0801B85C */
void CommitShopInventories(void)
{
    for(unsigned i=0;i<901;++i) {
        gShopStock[i]=gShopWorkingStock[i];gCardCollection[i]=gShopWorkingCollection[i];
    }
}
/* Mutation/audio prefixes of 0801B334 and0801BD20. The menu supplies the
 * selected card and current prices. Return values are recovery-adapter status,
 * not native ABI. UI redraw/repricing lives in the shop display/menu modules. */
uint8_t SellShopCardCore(uint16_t card)
{
    uint8_t success=ShopCollectionHasCards(card,1)==1;
    if(success) {
        RemoveShopCollectionCard(card,1);AddMoney(gShopSellPrice);
        AddShopWorkingStock(card,1);
    }
    PlayGameAudio(success?55:57);return success;
}
uint8_t BuyShopCardCore(uint16_t card)
{
    uint8_t success=0;
    if(ShopStockHasCards(card,1)==1 && ShopCollectionHasSpace(card,1)==1 && CanAfford(gShopBuyPrice)==1) {
        RemoveShopWorkingStock(card,1);SubtractMoney(gShopBuyPrice);
        AddShopCollectionCard(card,1);success=1;
    }
    PlayGameAudio(success?55:57);return success;
}

/*0801BF98/1BF24: unused persistent-stock subtraction also rejects card0.*/
uint8_t PersistentShopStockHasCards(uint16_t card,uint8_t n) { return n<=gShopStock[card]; }
void RemovePersistentShopStock(uint16_t card,uint8_t n)
{ if(card>=1 && card<=900)gShopStock[card]=PersistentShopStockHasCards(card,n)?gShopStock[card]-n:0; }
