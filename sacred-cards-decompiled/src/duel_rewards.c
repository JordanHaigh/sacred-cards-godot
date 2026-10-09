/* AY7E reward selection and persistent inventory mutation. Presentation and
 * top-level duel-outcome integration remain separate. Semantic C only. */
#include <stdint.h>
struct RewardEntry { uint16_t card,threshold; };
extern const uint16_t gRewardSpecialCards[]; /* 080BA280, zero terminated */
extern const uint8_t *const gOpponentRecords[200]; /* 08D35C28 */
extern const struct RewardEntry *gRewardNormalTable,*gRewardShopTable,*gRewardSpecialTable;
/* 02020D64 / 02020D68 / 02020D6C, copied from opponent fields+08/+0C/+10 */
extern uint16_t gWageredCard,gCurrentOpponent,gDuelRewardCards[10]; /* 02020B34 / 02020D40 / 02020D42 */
extern uint8_t gDuelRewardCount; /* 02020D58 */
extern uint64_t gDuelMoneyReward; /* 02020D30 */
extern uint16_t RandomHalfwordInclusive(uint16_t,uint16_t);
extern void AddCollectionCard(uint16_t,uint8_t),AddPersistentShopStock(uint16_t,uint8_t);
extern void AddMoney(uint64_t);

/* 0801823C: zero is a terminator after the first comparison, not a match. */
uint32_t UsesNormalRewardTable(uint16_t card)
{
    uint16_t i=0;
    do { if(gRewardSpecialCards[i]==card)return 0;++i; }
    while(gRewardSpecialCards[i]!=0);
    return 1;
}
static uint16_t PickReward(const struct RewardEntry *entry,uint16_t roll)
{
    while(entry->card && entry->threshold<=roll)++entry;
    return entry->card;
}
/* 0801649C */
uint16_t PickDuelRewardCard(void)
{
    const struct RewardEntry *table=UsesNormalRewardTable(gWageredCard)==1?gRewardNormalTable:gRewardSpecialTable;
    return PickReward(table,RandomHalfwordInclusive(0,2047));
}
/* 0801644C: a zero result is still stored and passed to AddCollectionCard. */
void AwardDuelCards(void)
{
    if(gWageredCard && gDuelRewardCount)
        for(unsigned i=0;i<gDuelRewardCount && i<10;++i) {
            gDuelRewardCards[i]=PickDuelRewardCard();AddCollectionCard(gDuelRewardCards[i],1);
        }
}
/* 08016768 / 08016748 */
uint16_t PickShopRewardCard(void)
{ return PickReward(gRewardShopTable,RandomHalfwordInclusive(0,29999)); }
void RestockShopAfterDuel(void)
{ for(unsigned i=0;i<50;++i)AddPersistentShopStock(PickShopRewardCard(),1); }
/* 080164EC. Read the ROM record rather than the copied RAM record. Scales
 * outside1..15 select1, and multiplication wraps modulo2^64. */
void AwardDuelMoney(void)
{
    const uint8_t *r=gOpponentRecords[gCurrentOpponent];
    uint64_t scale=1;
    if(r[0x20]>=1 && r[0x20]<=15)
        for(unsigned i=0;i<r[0x20];++i)scale*=10;
    uint16_t lo=(uint16_t)(r[0x1C]|r[0x1D]<<8),hi=(uint16_t)(r[0x1E]|r[0x1F]<<8);
    gDuelMoneyReward=(uint64_t)RandomHalfwordInclusive(lo,hi)*scale;
    AddMoney(gDuelMoneyReward);
}
