/* AY7E deck mutation, constraints and navigation080044A4..08004750,
 *0801421C..0801469C and08015810/15868. Native valid-card/count preconditions
 * are retained; this is faithful source recovery, not a redesigned inventory. */
#include "deck_builder.h"
extern uint16_t gPlayerDeck[40],gCollectionSortedCards[900];
extern uint8_t gPlayerDeckState[10],gCollectionMenu[12],gCardSortState[12],gCardMetadataBytes[0x1E],gCardCollection[901];
extern uint16_t CollectionCardAt(uint8_t);
extern uint32_t GetDeckCapacity(void),GetDuelistLevel(void);
extern void LoadCardMetadata(uint32_t),PlayGameAudio(uint32_t),SortCardList(void);
#define D gPlayerDeckState
static uint16_t U16(const uint8_t *p) { return p[0]|(uint16_t)p[1]<<8; }
static uint32_t U32(const uint8_t *p) { return U16(p)|(uint32_t)U16(p+2)<<16; }
static void W32(uint8_t *p,uint32_t n) { for(unsigned i=0;i<4;++i)p[i]=n>>(i*8); }
/*08014570/1449C/14448/1457C*/
uint32_t PlayerDeckCost(void) { return U32(D); }
uint8_t PlayerDeckCount(void) { return D[8]; }
uint16_t PlayerDeckCardAt(uint8_t row)
{ int index=(int8_t)D[4]+row-2;return index<0 || index>39?0:gPlayerDeck[index]; }
uint8_t CountPlayerDeckCard(uint16_t card)
{ uint8_t n=0;for(unsigned i=0;i<40;++i)if(gPlayerDeck[i]==card)++n;return n; }
/*080144E8/143EC*/
void RecalculatePlayerDeckCost(void)
{ W32(D,0);for(unsigned i=0;i<D[8];++i) { LoadCardMetadata(gPlayerDeck[i]);W32(D,U32(D)+U32(gCardMetadataBytes+12)); } }
void RefreshPlayerDeckState(void)
{
    D[5]=D[4]=D[8]=0;D[6]=1;for(unsigned i=0;i<40;++i)if(gPlayerDeck[i])++D[8];RecalculatePlayerDeckCost();
}
/*080145E8/14610. Fullness scans slots rather than trusting the count.*/
uint8_t PlayerDeckIsFull(void) { for(unsigned i=0;i<40;++i)if(!gPlayerDeck[i])return 0;return 1; }
uint8_t PlayerDeckFitsCapacity(void) { return PlayerDeckCost()<=GetDeckCapacity(); }
/*08015868: unlike some other card lists, a leading zero is never a match.*/
static int Listed(uint16_t card,uint32_t address)
{
    const uint8_t *p=(const uint8_t *)(uintptr_t)address;uint16_t i=0;
    while(U16(p+i*2)) { if(U16(p+i*2)==card)return 1;++i; }return 0;
}
uint8_t DeckAllowsAnotherCopy(uint16_t card)
{
    unsigned count=CountPlayerDeckCard(card);
    if(Listed(card,0x080B4B1C))return count==0;
    if(Listed(card,0x080B4B34))return count<2;
    return count<3;
}
/*0801421C/1425C. Unlike the collection's wrapping selection, deck selection
 * clamps and plays the error sound when already at the requested boundary.*/
void MovePlayerDeckSelection(uint8_t amount,uint8_t down)
{
    if(down) {
        int last=(int)D[8]-1;if((int8_t)D[4]==last) { PlayGameAudio(57);return; }
        D[4]=amount<(int)D[8]-(int8_t)D[4]?D[4]+amount:last;
    }else {
        if(!D[4]) { PlayGameAudio(57);return; }
        D[4]=(int8_t)D[4]<amount?0:D[4]-amount;
    }
    PlayGameAudio(54);
}
/*08014370/144C8: callers guarantee at least one card before removal.*/
static void RemoveSlot(uint8_t slot)
{ while(slot<(int)D[8]-1) { gPlayerDeck[slot]=gPlayerDeck[slot+1];++slot; }gPlayerDeck[D[8]-1]=0;if(D[8])--D[8]; }
static void SubtractCost(uint32_t cost) { W32(D,cost>U32(D)?0:U32(D)-cost); }
static void ClampSelection(void)
{ if(D[8]<=(int8_t)D[4])MovePlayerDeckSelection((uint8_t)(D[4]-D[8]+1),0); }
/*08014318/145B0*/
static uint8_t RemoveCard(uint16_t card)
{
    LoadCardMetadata(card);unsigned slot=0;while(slot<D[8] && gPlayerDeck[slot]!=card)++slot;uint8_t found=slot<D[8];
    if(found) { RemoveSlot(slot);SubtractCost(U32(gCardMetadataBytes+12)); }ClampSelection();return found;
}
/*08004558: the cost comparison is against Duelist Level, not deck capacity.*/
void AddSelectedCollectionCardToDeck(void)
{
    uint16_t card=CollectionCardAt(2);
    if(gCardCollection[card] && D[8]<40 && DeckAllowsAnotherCopy(card)==1) {
        LoadCardMetadata(card);if(U32(gCardMetadataBytes+12)<=GetDuelistLevel()) {
            --gCardCollection[card];gPlayerDeck[D[8]++]=card;RecalculatePlayerDeckCost();PlayGameAudio(55);return;
        }
    }
    PlayGameAudio(57);
}
/*080045E4: collection-view removal increments the byte WITHOUT saturation.*/
void RemoveSelectedCollectionCardFromDeck(void)
{
    uint16_t card=CollectionCardAt(2);
    if(!CountPlayerDeckCard(card) || RemoveCard(card)!=1)PlayGameAudio(57);
    else { ++gCardCollection[card];PlayGameAudio(55); }
}
/*080142B8/045C4: deck-view removal saturates collection count at250.*/
void RemoveSelectedDeckCard(void)
{
    uint16_t card=PlayerDeckCardAt(2);if(!card) { PlayGameAudio(57);return; }
    LoadCardMetadata(card);gCardCollection[card]=gCardCollection[card]<250?gCardCollection[card]+1:250;
    RemoveSlot(D[4]);ClampSelection();SubtractCost(U32(gCardMetadataBytes+12));PlayGameAudio(55);
}
/*08014630/1469C: deck modes36..44; selecting a mode resets selection.*/
void SortPlayerDeck(uint8_t method,uint8_t reset)
{
    W32(gCardSortState,(uint32_t)(uintptr_t)gPlayerDeck);gCardSortState[8]=D[8];gCardSortState[9]=0;gCardSortState[10]=36+method;SortCardList();
    if(reset)D[4]=0;
}
/*08005904/0595C/0597C: coloring has its own count!=40 condition.*/
uint16_t CollectionAddPalette(uint16_t card)
{
    if(gCardCollection[card] && DeckAllowsAnotherCopy(card)==1 && D[8]!=40) {
        LoadCardMetadata(card);if(U32(gCardMetadataBytes+12)<=GetDuelistLevel())return 0x5000;
    }
    return 0x4000;
}
uint16_t DeckCostPalette(void) { return PlayerDeckFitsCapacity()?0x5000:0x4000; }
uint16_t DeckCountPalette(void) { return D[8]<40?0x4000:0x5000; }
/*080141A0: command0 initializes only card IDs; command1 initializes the
 * menu cost/count/selection fields. These are distinct native operations.*/
extern void InitializeDeck(uint16_t *);
void DispatchDeckStateCommand(uint8_t command)
{
    switch(command) {
    case 0:InitializeDeck(gPlayerDeck);break;
    case 1:RefreshPlayerDeckState();break;
    case 2:MovePlayerDeckSelection(1,1);break;
    case 3:MovePlayerDeckSelection(1,0);break;
    case 4:MovePlayerDeckSelection(10,1);break;
    case 5:MovePlayerDeckSelection(10,0);break;
    case 6:if(++D[6]>3)D[6]=0;PlayGameAudio(54);break;
    case 7:RemoveSelectedDeckCard();break;
    }
}
