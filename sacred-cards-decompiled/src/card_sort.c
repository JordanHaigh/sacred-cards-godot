/* AY7E card sorting0801FB74..08021E18. All54 key-builder slots from
 * ROM08D41A50 are represented below. Keys compare as unsigned64-bit values,
 * descending; the native partition and push order determine ties. */
#include "gba_bios.h"
extern uint8_t gCardSortState[12],gCardSortScratch[0x4314]; /*02023040 /02018800*/
extern uint8_t gLanguage,gCardCollection[901],gCollectionTotals[901],gShopWorkingStock[901],gShopWorkingCollection[901];
extern uint16_t gShopPriceCard;
extern uint8_t gShopPriceStock;
extern uint64_t gShopBuyPrice,gShopSellPrice;
extern void UpdateShopBuyPrice(void),UpdateShopSellPrice(void);
extern uint8_t CountPlayerDeckCard(uint16_t);
#define ROM(a) ((const uint8_t *)(uintptr_t)(a))
static uint16_t U16(const uint8_t *p) { return p[0]|(uint16_t)p[1]<<8; }
static uint32_t U32(const uint8_t *p) { return U16(p)|(uint32_t)U16(p+2)<<16; }
static void W16(uint8_t *p,uint16_t value) { p[0]=value;p[1]=value>>8; }
static void W32(uint8_t *p,uint32_t value) { for(unsigned i=0;i<4;++i)p[i]=value>>(i*8); }
static uint64_t Key(unsigned i)
{ const uint8_t *p=gCardSortScratch+i*12;return U32(p+4)|(uint64_t)U32(p+8)<<32; }
/* Record bytes2..3 are cleared initially and travel with the card and key. */
static void Swap(unsigned a,unsigned b)
{ for(unsigned i=0;i<12;++i) { uint8_t t=gCardSortScratch[a*12+i];gCardSortScratch[a*12+i]=gCardSortScratch[b*12+i];gCardSortScratch[b*12+i]=t; } }
/*0801FD18/1FCF4/1FD4C. The native32-entry range stack follows900 records.*/
static void Push(uint16_t low,uint16_t high)
{
    uint32_t n=U32(gCardSortScratch+0x2AB0);if(n>=32)for(;;) {}
    W32(gCardSortScratch+0x2A30+n*4,low|(uint32_t)high<<16);W32(gCardSortScratch+0x2AB0,n+1);
}
static uint32_t Pop(void)
{ uint32_t n=U32(gCardSortScratch+0x2AB0)-1;W32(gCardSortScratch+0x2AB0,n);return U32(gCardSortScratch+0x2A30+n*4); }
static void SortRecords(unsigned count)
{
    if(count<2)return;W32(gCardSortScratch+0x2AB0,0);Push(0,count-1);
    while(U32(gCardSortScratch+0x2AB0)) {
        uint32_t range=Pop();unsigned first=range&65535,last=range>>16,left=first,right=last;uint64_t pivot=Key((left+right)/2);
        for(;;) {
            while(Key(left)>pivot)left=(uint16_t)(left+1);
            while(Key(right)<pivot)right=(uint16_t)(right-1);
            if(right<=left)break;Swap(left,right);left=(uint16_t)(left+1);right=(uint16_t)(right-1);
        }
        if(right+1<last)Push(right+1,last);if((int)first<(int)left-1)Push(first,left-1);
    }
}
enum SortKey { COPY,NUMBER,NAME,ATTACK,DEFENSE,TYPE,ATTRIBUTE,QUANTITY,COST,LEVEL,BUY_PRICE,SELL_PRICE,DECK_QUANTITY };
enum Inventory { NONE,COLLECTION,BUY_STOCK,SELL_COLLECTION,TOTAL };
typedef struct { uint8_t key,inventory; } SortMethod;
/* Each row corresponds directly to one entry in08D41A50. Methods1,3..6
 * have separate ROM-output-list behavior; their keys are handled below. */
static const SortMethod methods[54]={
    {COPY,NONE},{NUMBER,NONE},{NAME,NONE},{ATTACK,NONE},{DEFENSE,NONE},{TYPE,NONE},{ATTRIBUTE,NONE},{COST,NONE},
    {QUANTITY,COLLECTION},{BUY_PRICE,BUY_STOCK},{SELL_PRICE,SELL_COLLECTION},{LEVEL,NONE},
    {NUMBER,COLLECTION},{NAME,COLLECTION},{ATTACK,COLLECTION},{DEFENSE,COLLECTION},{TYPE,COLLECTION},{ATTRIBUTE,COLLECTION},{COST,COLLECTION},{LEVEL,COLLECTION},
    {NUMBER,BUY_STOCK},{NAME,BUY_STOCK},{ATTACK,BUY_STOCK},{DEFENSE,BUY_STOCK},{TYPE,BUY_STOCK},{ATTRIBUTE,BUY_STOCK},{COST,BUY_STOCK},{LEVEL,BUY_STOCK},
    {NUMBER,SELL_COLLECTION},{NAME,SELL_COLLECTION},{ATTACK,SELL_COLLECTION},{DEFENSE,SELL_COLLECTION},{TYPE,SELL_COLLECTION},{ATTRIBUTE,SELL_COLLECTION},{COST,SELL_COLLECTION},{LEVEL,SELL_COLLECTION},
    {NUMBER,NONE},{NAME,NONE},{ATTACK,NONE},{DEFENSE,NONE},{TYPE,NONE},{ATTRIBUTE,NONE},{DECK_QUANTITY,NONE},{COST,NONE},{LEVEL,NONE},
    {NUMBER,TOTAL},{NAME,TOTAL},{ATTACK,TOTAL},{DEFENSE,TOTAL},{TYPE,TOTAL},{ATTRIBUTE,TOTAL},{QUANTITY,TOTAL},{COST,TOTAL},{LEVEL,TOTAL}
};
static const uint8_t *InventoryFor(unsigned inventory)
{
    switch(inventory) { case COLLECTION:return gCardCollection;case BUY_STOCK:return gShopWorkingStock;case SELL_COLLECTION:return gShopWorkingCollection;case TOTAL:return gCollectionTotals;default:return 0; }
}
static uint64_t BuildKey(unsigned method,uint16_t card)
{
    SortMethod m=methods[method];const uint8_t *inventory=InventoryFor(m.inventory);
    /* The sign extension of900-card precedes the OR, even for invalid IDs. */
    uint64_t base=(uint64_t)(int64_t)(900-(int32_t)card),key=base;unsigned count=inventory?inventory[card]:0;
    switch(m.key) {
    case COPY:return 0;
    case NUMBER:
        if(m.inventory==COLLECTION || m.inventory==TOTAL)return base+(count?900:0);
        break;
    case NAME:
        key=(uint64_t)(int64_t)(900-(int32_t)U16(ROM(0x080CE83C)+gLanguage*0x70A+card*2));
        return key+(count?900:0);
    /* Stat+1 is shifted in32 bits, so FFFF rolls over to zero. */
    case ATTACK:key|=(uint32_t)(U16(ROM(0x080886E6)+card*2)+1)<<16;break;
    case DEFENSE:key|=(uint32_t)(U16(ROM(0x08087FDC)+card*2)+1)<<16;break;
    case TYPE:key|=(uint64_t)(255-ROM(0x0808A30E)[card])<<16;break;
    case ATTRIBUTE:key|=(uint64_t)(uint8_t)(256-ROM(0x08089C04)[card])<<16;break;
    case QUANTITY:return key|(uint64_t)count<<16;
    case COST:key|=(uint64_t)U32(ROM(0x08088DF0)+card*4)<<16;break;
    case LEVEL:key|=(uint64_t)ROM(0x08089F89)[card]<<16;break;
    case DECK_QUANTITY:return key|(uint64_t)CountPlayerDeckCard(card)<<16;
    case BUY_PRICE:
        gShopPriceCard=card;gShopPriceStock=gShopWorkingStock[card];UpdateShopBuyPrice();return key|(gShopBuyPrice<<16);
    case SELL_PRICE:
        gShopPriceCard=card;gShopPriceStock=gShopWorkingStock[card];UpdateShopSellPrice();key|=gShopSellPrice<<16;break;
    }
    if(count)key|=UINT64_C(1)<<60;return key;
}
/*0801FD5C entry,08021E18 scratch reset. No callback dispatch remains opaque.*/
void SortCardList(void)
{
    unsigned method=gCardSortState[10],count=U16(gCardSortState+8);if(method>=54)return;
    uint16_t zero=0;BiosCpuSet(&zero,gCardSortScratch,0x0100218A);
    uint16_t *cards=(uint16_t *)(uintptr_t)U32(gCardSortState);
    static const uint32_t fixedLists[4]={0x080CCC1C,0x080CD324,0x080CDA2C,0x080CE134};
    for(unsigned i=0;i<count;++i) {
        uint16_t card=cards[i],output=card;uint64_t key;
        if(method>=3 && method<=6) { output=U16(ROM(fixedLists[method-3])+i*2);key=0; }
        else { if(method==1)output=U16(ROM(0x080CBE0C)+i*2);key=BuildKey(method,card); }
        uint8_t *record=gCardSortScratch+i*12;W16(record,output);W32(record+4,(uint32_t)key);W32(record+8,key>>32);
    }
    SortRecords(count);for(unsigned i=0;i<count;++i)cards[i]=U16(gCardSortScratch+i*12);
}

/*08021D74: unused descending bubble-sort alternative to the partition
 * routine. Equal keys are never swapped. The pass is narrowed AFTER its
 * comparisons, so an incoming65535 pass compares using65536 before wrapping.*/
void BubbleSortCardRecords(void)
{
    uint32_t pass=0;uint16_t count=U16(gCardSortState+8);uint8_t changed;
    do {
        changed=0;++pass;
        for(uint16_t i=0;(int)i<(int)count-(int)pass;++i)
            if(Key(i)<Key(i+1)) { Swap(i,i+1);changed=1; }
        pass=(uint16_t)pass;
    }while(changed);
}
