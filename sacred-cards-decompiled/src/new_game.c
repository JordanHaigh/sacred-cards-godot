/* AY7E native new-game initialization and collection updates. These globals
 * are not yet linked at their native addresses. Semantic C only. */
#include <stdint.h>
extern uint8_t gPlayerName[19]; /* 0201FC90 */
extern uint8_t gCardCollection[901],gShopStock[901]; /* 02020770 / 02020DB0 */
extern const uint8_t gInitialCardCollection[901],gInitialShopStock[901]; /* 0808673C / 080C8304 */
extern uint16_t gPlayerDeck[40]; /* 02020C5A */
extern uint32_t gDeckCapacity,gDuelistLevel; /* 02020C3C/40 */
extern uint16_t gDuelRecordHeader[2],gDuelRecords[25][2]; /* 02020CB0/CB4 */
extern uint8_t gProgressRank; /* 02020DA8 */
extern uint8_t gEventFlags[50],gScenePersistentFlags[2]; /* 02023700 / 020237C4 */
extern void InitializeDeck(uint16_t *);
extern void InitializeMoney(void);
extern void InitializeRandom(void);
extern void ClearAllEventFlags(uint8_t *);
/* 0800431C: signed remaining-space comparison, even for counts above250. */
void AddCollectionCard(uint16_t card,uint8_t count) {
    int32_t space=250-(int32_t)gCardCollection[card];
    if(space<count)gCardCollection[card]=250;else gCardCollection[card]+=count;
}
/*080043D0*/
void InitializeCardCollection(void)
{ for(unsigned i=0;i<901;++i)gCardCollection[i]=gInitialCardCollection[i]; }
/*0800436C uses a signed subtraction: counts already above250 cannot be
 * increased, even by zero. 080043B0 stores the low byte without clamping.*/
uint8_t CanAddCollectionCards(uint16_t card,uint8_t count)
{ return (int32_t)count<=250-(int32_t)gCardCollection[card]; }
uint8_t CanRemoveCollectionCards(uint16_t card,uint8_t count)
{ return count<=gCardCollection[card]; } /*08004390*/
void SetCollectionCardCount(uint16_t card,uint8_t count) { gCardCollection[card]=count; } /*080043B0*/
/* 08006314, in native subsystem order. */
void InitializeNewGame(void) {
    for(unsigned i=0;i<19;++i)gPlayerName[i]=0;                  /* 08001BBC */
    InitializeCardCollection();
    InitializeDeck(gPlayerDeck);gDeckCapacity=1600;gDuelistLevel=72;
    gDuelRecordHeader[0]=gDuelRecordHeader[1]=0;                /* 08016900 */
    for(unsigned i=0;i<25;++i)gDuelRecords[i][0]=gDuelRecords[i][1]=0;
    gProgressRank=1;                                         /* 08019D58 */
    for(unsigned i=0;i<901;++i)gShopStock[i]=gInitialShopStock[i]; /* 0801BFB8 */
    InitializeMoney();InitializeRandom();ClearAllEventFlags(gEventFlags);
    gScenePersistentFlags[0]=gScenePersistentFlags[1]=0;        /* 08034434 */
}
