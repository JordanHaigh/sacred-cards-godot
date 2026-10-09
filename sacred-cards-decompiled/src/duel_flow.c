/* AY7E duel initialization, turn transitions and outcome handling.
 * Player input/action selection is recovered separately. Semantic C is not
 * linked, execution-compared or compiler-matched. */
#include "ai.h"
#include "duel_text.h"
#include "gba_bios.h"
extern uint8_t gDuelStateBytes[252],gAbsoluteDuelHands[2][5][8],gAbsoluteDuelSideState[2][4];
extern uint16_t *gDuelVisibleCells[5][5],*gPlayerHandCells[5],*gOpponentHandCells[5];
extern uint8_t gDuelDeckRecords[2][84],gActingSide,gDuelCursorState[6],gDuelViewMode;
/* cursor02023438; view mode02023384 */
extern uint8_t gOpponentRecord[40],gDuelOutcome,gDuelRewardCount,gProgressionFlags;
/* record02020D5C; outcome02020D59; reward count02020D58; flags02020D5A */
extern const uint8_t *const gOpponentRecords[200];
extern uint16_t gCurrentOpponent,gDuelRewardCards[10],gDuelLifePoints[2],gPlayerDeck[40],gWageredCard;
extern uint64_t gDuelMoneyReward;
extern uint32_t gDuelMusic,gDuelCapacityReward; /*02020D38/3C*/
extern uint8_t gCardCollection[901],gPaletteBuffer[],gBackgroundBuffer[];
extern uint16_t gOamBuffer[128][4];
extern void DrawDuelCard(uint8_t),ResetTributesCommitted(void),RunOpponentTurn(void),CheckExodiaWin(void);
extern void RestoreDuelDisplay(void),LoadDuelTerrain(uint8_t),ComposeDuelMiniatureOam(void),DrawDuelCursorPosition(void);
extern void UploadOam(void),UploadPalettes(void),UploadBackgroundOffsets(void),WaitForFrame(void),SetVBlankCallback(void (*)(void));
extern uint16_t SetDuelViewportOffset(uint8_t);
extern uint32_t RandomByteInclusive(uint32_t,uint32_t);
extern void FadeGameMusic(uint16_t),ShowCardDescription(void),AddNativeDeckCapacity(uint32_t);
extern void AwardDuelCards(void),RestockShopAfterDuel(void),AwardDuelMoney(void);
extern void RunPlayerDuelTurn(void);
#define ROM(a) ((const uint8_t *)(uintptr_t)(a))
#define REG(a) (*(volatile uint16_t *)(uintptr_t)(a))
static uint16_t Read16(const uint8_t *p) { return p[0]|(uint16_t)p[1]<<8; }
static uint32_t Read32(const uint8_t *p) { return Read16(p)|(uint32_t)Read16(p+2)<<16; }
static void Write16(uint8_t *p,uint16_t n) { p[0]=n;p[1]=n>>8; }
static void Write32(uint8_t *p,uint32_t n) { Write16(p,n);Write16(p+2,n>>16); }
/*08027390 /27418 /27480 /273CC. Deck byte80 counts remaining cards.*/
void ClearDuelDecks(void)
{ for(unsigned s=0;s<2;++s) { gDuelDeckRecords[s][80]=0;for(int i=39;i>=0;--i)Write16(gDuelDeckRecords[s]+i*2,0); } }
void LoadDuelDeck(uint8_t side,uint8_t opponent)
{
    const uint8_t *deck=opponent?ROM(Read32(gOpponentRecord+4)):(const uint8_t *)gPlayerDeck;
    for(unsigned i=0;i<40;++i)Write16(gDuelDeckRecords[side]+i*2,Read16(deck+i*2));
}
void CountDuelDecks(void)
{ for(unsigned s=0;s<2;++s) { unsigned n=0;while(n<40 && Read16(gDuelDeckRecords[s]+n*2))++n;gDuelDeckRecords[s][80]=n; } }
void ShuffleDuelDeck(uint8_t side)
{
    uint8_t *deck=gDuelDeckRecords[side];
    for(unsigned i=0;i<200;++i) {
        unsigned a=(uint8_t)RandomByteInclusive(0,39),b=(uint8_t)RandomByteInclusive(0,39);
        uint16_t old=Read16(deck+a*2);Write16(deck+a*2,Read16(deck+b*2));Write16(deck+b*2,old);
    }
}
/*08024000: physical rows are8-byte cells; Ghidra's first two row symbols
 * are inferred as halfword arrays and must not be read as4-byte strides.*/
void OrientDuelBoard(uint8_t side)
{
    static const uint8_t rows[2][4]={{0,1,2,3},{3,2,1,0}};unsigned s=side!=0;
    for(unsigned row=0;row<4;++row)for(unsigned col=0;col<5;++col)
        gEffectBoardCells[row][col]=(uint16_t *)(gDuelStateBytes+(rows[s][row]*5+(row<2?4-col:col))*8);
    for(unsigned col=0;col<5;++col) {
        gEffectBoardCells[4][col]=(uint16_t *)gAbsoluteDuelHands[s][col];
        gPlayerHandCells[col]=(uint16_t *)gAbsoluteDuelHands[s][col];gOpponentHandCells[col]=(uint16_t *)gAbsoluteDuelHands[1-s][col];
    }
    gDuelSideState[0]=gAbsoluteDuelSideState[s];gDuelSideState[1]=gAbsoluteDuelSideState[1-s];
}
/*08023E24 /23CC0*/
void InitializeDuelBoard(void)
{
    for(unsigned row=0;row<4;++row)for(unsigned col=0;col<5;++col)
        gDuelVisibleCells[row][col]=(uint16_t *)(gDuelStateBytes+(row*5+(row<2?4-col:col))*8);
    for(unsigned col=0;col<5;++col)gDuelVisibleCells[4][col]=(uint16_t *)gAbsoluteDuelHands[0][col];
    OrientDuelBoard(0);
    for(unsigned i=0;i<20;++i)ClearDuelCell((uint16_t *)(gDuelStateBytes+i*8));
    for(unsigned i=0;i<20;++i) {
        uint8_t *cell=gDuelStateBytes+i*8;Write16(cell,Read16(ROM(0x08D4BDEC)+i*2));
        cell[4]=(cell[4]&0xED)|((ROM(0x08D4BE1E)[i]&1)<<4)|((ROM(0x08D4BE37)[i]&1)<<1);
    }
    /* Native clears one hand cell, then draws, five times for each side. */
    for(unsigned side=0;side<2;++side)for(unsigned col=0;col<5;++col) { ClearDuelCell((uint16_t *)gAbsoluteDuelHands[side][col]);DrawDuelCard(side); }
    gTerrain=gOpponentRecord[2];
    for(unsigned i=0;i<2;++i)gAbsoluteDuelSideState[i][2]&=0xFC;
    for(unsigned i=0;i<2;++i)gAbsoluteDuelSideState[i][2]&=0xFB;
    for(unsigned i=0;i<2;++i)Write16(gAbsoluteDuelSideState[i],0);
}
/*08017F54*/
void InitializeDuelRewards(void)
{
    gDuelMoneyReward=0;gDuelMusic=0;for(unsigned i=0;i<10;++i)gDuelRewardCards[i]=0;
    gDuelCapacityReward=0;gDuelRewardCount=0;gDuelOutcome=2;gProgressionFlags=(gProgressionFlags&0xFE)|2;
    static const uint32_t defaults[10]={0,0x080E7C70,0x080B7194,0x080C65D4,0x080B80CC,0x1F401F40,0,0,0,32};
    for(unsigned i=0;i<10;++i)Write32(gOpponentRecord+i*4,defaults[i]);
}
/*08024768 /274D4 /248F4*/
void InitializeDuelDisplay(void)
{
    gDuelViewMode=4;REG(0x04000000)=0;gDuelCursorState[4]=0;gDuelCursorState[0]=0;gDuelCursorState[1]=4;gDuelCursorState[2]=0;gDuelCursorState[3]=4;
    WaitForFrame();REG(0x05000000)=0;REG(0x04000000)=0;LoadDuelTerrain(gTerrain);RestoreDuelDisplay();SetVBlankCallback(UploadBackgroundOffsets);
}
/*08017CA8*/
void InitializeDuel(void)
{
    InitializeDuelRewards();const uint8_t *record=gOpponentRecords[gCurrentOpponent];
    for(unsigned i=0;i<10;++i)Write32(gOpponentRecord+i*4,Read32(record+i*4));
    gDuelOutcome=2;gDuelRewardCount=1;gDuelMusic=Read32(record+36);
    ClearDuelDecks();LoadDuelDeck(0,0);LoadDuelDeck(1,(uint8_t)gCurrentOpponent);CountDuelDecks();
    ShuffleDuelDeck(0);ShuffleDuelDeck(1);gActingSide=RandomByteInclusive(0,1)!=0;InitializeDuelBoard();
    gDuelLifePoints[0]=Read16(gOpponentRecord+20);gDuelLifePoints[1]=Read16(gOpponentRecord+22);
    gDuelAuxiliaryFlags[0]=gDuelAuxiliaryFlags[1]=0;gSuppressEffectPresentation=0;InitializeDuelDisplay();PlayGameAudio(gDuelMusic);
}
/*08019CE0 /19C70: ordinary cards return4; replacement keeps cell flags/stages.*/
void TransformGrowingMonsters(void)
{
    for(unsigned col=0;col<5;++col) {
        uint16_t *cell=gEffectBoardCells[2][col];unsigned index=0;
        while(index<4 && *cell!=Read16(ROM(0x08D419CC)+index*2))++index;
        if(index<4) {
            *cell=Read16(ROM(0x08D419D4)+index*2);struct DuelMessage m;InitializeDuelMessage(&m);
            m.card=Read16(ROM(0x08D419CC)+index*2);m.other=*cell;m.index=14;PresentDuelMessage(&m);
        }
    }
}
/*08018E98 /18E60: return to the last empty opposing slot; discard if full.*/
void ReturnBorrowedMonsters(void)
{
    for(unsigned col=0;col<5;++col) {
        uint16_t *source=gEffectBoardCells[2][col];uint8_t *s=(uint8_t *)source;
        if(!*source || !(s[4]&32))continue;
        int slot=4;while(slot>=0 && *gEffectBoardCells[1][slot])--slot;
        if(slot>=0) {
            uint16_t *destination=gEffectBoardCells[1][slot];uint8_t *d=(uint8_t *)destination;
            *destination=*source;d[4]=((d[4]|16)&0xD8)|(s[4]&4);d[3]=2;d[2]=s[2];
        }
        ClearDuelCell(source);
    }
}
static void Message(uint8_t index,uint16_t number)
{ struct DuelMessage m;InitializeDuelMessage(&m);m.index=index;m.number=number;PresentDuelMessage(&m); }
/*08018170*/
void PresentAttackRestriction(void)
{ unsigned turns=gDuelSideState[0][2]&3;if(turns)Message(ROM(0x080BA27C)[turns],0); }
/*08018E60 /242E8 /181CC /36904 /24500 /24260*/
void FinishDuelTurn(void)
{
    ReturnBorrowedMonsters();
    for(unsigned col=0;col<5;++col) { uint16_t *c=gEffectBoardCells[2][col];if(*c && !(((uint8_t *)c)[4]&2))((uint8_t *)c)[4]|=16; }
    for(unsigned side=0;side<2;++side)if(!gDuelAuxiliaryFlags[side])gDuelAuxiliaryFlags[side]=1;
    gActingSide=ROM(0x08D5119C)[gActingSide];gDuelSideState[0][2]&=0xFB;
    uint8_t *flags=&gDuelSideState[0][2];if(*flags&3)*flags=(*flags&0xFC)|((*flags-1)&3);
    for(unsigned row=2;row<=4;row+=2)for(unsigned col=0;col<5;++col) { uint16_t *c=gEffectBoardCells[row][col];if(*c)((uint8_t *)c)[4]&=0xFE; }
}
/*08016670. The last divisor is10^12 despite the localized "billion" wording.*/
void PresentMoneyReward(void)
{
    uint64_t n=gDuelMoneyReward;uint8_t index;
    if(!n)index=12;else if(n<10000)index=8;else if(n<100000000) { index=9;n/=10000; }
    else if(n<UINT64_C(1000000000000)) { index=10;n/=100000000; }else { index=11;n/=UINT64_C(1000000000000); }
    Message(index,(uint16_t)n);
}
/*08016408*/
static unsigned SpecialLossMusic(void)
{ unsigned i=0;do { if(gCurrentOpponent==Read16(ROM(0x080B4B40)+i*2))return 1;++i; }while(Read16(ROM(0x080B4B40)+i*2));return 0; }
/*08016254 /16360*/
void ResolveDuelOutcome(void)
{
    if(gDuelOutcome==1) {
        gDuelCapacityReward=Read32(gOpponentRecords[gCurrentOpponent]+24);AddNativeDeckCapacity(gDuelCapacityReward);
        AwardDuelCards();RestockShopAfterDuel();AwardDuelMoney();
        if(!gDuelLifePoints[1]) { FadeGameMusic(4);Message(19,0); }else if(!gDuelDeckRecords[1][80]) { FadeGameMusic(4);Message(21,0); }
        if(gProgressionFlags&2) {
            PlayGameAudio(43);Message(2,0);Message(6,(uint16_t)gDuelCapacityReward);PresentMoneyReward();
            for(unsigned i=0;i<10 && gDuelRewardCards[i];++i) {
                struct DuelMessage m;InitializeDuelMessage(&m);m.index=5;m.card=gDuelRewardCards[i];PresentDuelMessage(&m);
                LoadCardMetadata(gDuelRewardCards[i]);ShowCardDescription();
            }
        }
    }else {
        if(gWageredCard) { uint8_t *n=&gCardCollection[gWageredCard];if(*n)--*n; }
        if(!gDuelLifePoints[0]) { FadeGameMusic(4);Message(20,0); }else if(!gDuelDeckRecords[0][80]) { FadeGameMusic(4);Message(22,0); }
        if(gProgressionFlags&2) { PlayGameAudio(SpecialLossMusic()?138:44);Message(3,0); }
    }
}
static void DarkenPalette(void)
{
    for(unsigned i=0;i<512;++i) {
        uint16_t old=Read16(gPaletteBuffer+i*2),value=old&0x8000;
        for(unsigned shift=0;shift<15;shift+=5) { unsigned c=(old>>shift)&31;value|=(c?c-1:0)<<shift; }
        Write16(gPaletteBuffer+i*2,value);
    }
}
/*080180E4 /17FCC*/
static void DuelMosaicCallback(void)
{ UploadOam();REG(0x0400004C)=0;for(unsigned i=0;i<4;++i)REG(0x04000008+i*2)|=64; }
void FadeIntoDuel(void)
{
    for(unsigned i=0;i<128;++i)gOamBuffer[i][0]|=0x1000;SetVBlankCallback(DuelMosaicCallback);WaitForFrame();
    for(unsigned i=0;i<32;++i) { DarkenPalette();SetVBlankCallback(UploadPalettes);WaitForFrame();unsigned n=(i>>1)&15;REG(0x0400004C)=(n<<8)|n; }
}
/*08017D6C /17DA8*/
void FinishDuel(void)
{
    gDuelOutcome=gDuelAuxiliaryFlags[1]==2?1:2;ResolveDuelOutcome();FadeGameMusic(2);
    for(unsigned i=0;i<32;++i) { DarkenPalette();SetVBlankCallback(UploadPalettes);WaitForFrame(); }
}
/*08017B84. Drawing the last card and winning checks precede action selection.*/
void RunDuel(void)
{
    FadeIntoDuel();InitializeDuel();
    for(;;) {
        uint8_t side=GetActingSide();RestoreDuelDisplay();SetDuelViewportOffset(side?1:gDuelCursorState[1]);
        ComposeDuelMiniatureOam();DrawDuelCursorPosition();WaitForFrame();UploadOam();UploadBackgroundOffsets();
        BiosCpuSet(gBackgroundBuffer+0x8040,(void *)0x06008040,0x040001D0);BiosCpuSet(gPaletteBuffer+0xA0,(void *)0x050000A0,32);
        if(!side)Message(0,0);
        else {
            /*08017ED4 searches a local two-halfword record, discarded by its
             * caller; it makes no persistent state changes.*/
            PresentDuelText(ROM(Read32(ROM(0x08D3618C)+gCurrentOpponent*4)),0,0,0,0);
        }
        gDuelSideState[0][2]&=0xF7;ResetTributesCommitted();OrientDuelBoard(side);
        unsigned empty=0;for(unsigned i=0;i<5;++i)empty+=*gEffectBoardCells[4][i]==0;
        if(empty) { DrawDuelCard(side);if(DuelHasEnded()==1)break;PlayGameAudio(59); }
        RestoreDuelDisplay();CheckExodiaWin();if(DuelHasEnded()==1)break;
        PresentAttackRestriction();TransformGrowingMonsters();if(!side)RunPlayerDuelTurn();else RunOpponentTurn();
        if(DuelHasEnded()==1)break;FinishDuelTurn();
    }
    FinishDuel();
}

/*080272B8/272C4: dormant fatal-display entry. Native freezes in a frame
 *wait after resetting keys and installing the interrupt handler.*/
extern void ResetGameKeys(void),InstallNativeInterruptHandler(void);
void FreezeDuelDisplay(void)
{ REG(0x04000000)|=0x80;REG(0x04000008)=0x8004;ResetGameKeys();InstallNativeInterruptHandler();for(;;)WaitForFrame(); }
void FreezeDuelDisplayEntry(void) { FreezeDuelDisplay(); }
/*080282B8/282C4: deterministic alternate initialization (no deck shuffle).*/
void InitializeDuelBoardLegacy(void)
{ gActingSide=0;InitializeDuelBoard();gDuelLifePoints[0]=Read16(gOpponentRecord+20);gDuelLifePoints[1]=Read16(gOpponentRecord+22); }
void InitializeDuelBoardLegacyEntry(void) { InitializeDuelBoardLegacy(); }

/*08018148/1812C: the dormant startup hook's predicate is literally zero.*/
uint8_t ShouldRunStartupDuel(void) { return 0; }
extern void RestoreSceneDisplay(void);
void TryStartupDuel(void) { if(ShouldRunStartupDuel()==1) { RunDuel();RestoreSceneDisplay(); } }
