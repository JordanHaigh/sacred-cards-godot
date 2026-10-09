/* AY7E pre-duel wager selection080074DC..08007878. Shared collection-list
 * rendering, sort keys and popup composition are recovered in companion C. */
#include <stdint.h>
extern uint16_t gKeysPressed,gKeysHeld,gKeysRepeated,gPasswordRepeated,gWageredCard;
extern uint16_t gCollectionSortedCards[900],gPlayerDeck[40]; /*0201FCCC/02020C5A*/
extern uint8_t gCollectionMenu[12],gCollectionTotals[901],gCardCollection[901]; /*0201FCC0/020203E0/02020770*/
extern uint8_t gCardSortState[12];
extern void PollMenuRepeat(void),PlayGameAudio(uint32_t),FadeGameMusic(uint16_t),FadeIntoDuel(void),WaitForFrame(void),UploadOam(void),SetVBlankCallback(void (*)(void));
extern void LoadCardMetadata(uint32_t),ShowCardDescription(void);
extern void RefreshPlayerDeckState(void),SortCardList(void),UploadMenuGraphics(void),UploadCollectionFrame(void),CollectionIdle(void),UploadCollectionList(void),RunWagerSortMenu(void);
extern void DrawPreDuelGraphics(uint8_t),CollectionDisplayFrame(uint8_t);
extern void DrawWagerActionPopup(void),DrawWagerActionCursor(void),WagerPopupDisplayCallback(void),DrawSpecialWagerPopup(void),DrawSpecialWagerCursor(void),DrawNoWagerPopup(void),DrawNoWagerCursor(void);
#define ROM(a) ((const uint8_t *)(uintptr_t)(a))
#define M gCollectionMenu
#define SORT M[2]
#define VIEW M[3]
#define CHOICE M[4]
static uint16_t U16(const uint8_t *p) { return p[0]|(uint16_t)p[1]<<8; }
static void W16(uint8_t *p,uint16_t v) { p[0]=v;p[1]=v>>8; }
static void Frame(void (*callback)(void)) { SetVBlankCallback(callback);WaitForFrame(); }
/*08003D88/03E1C: repeated directions override highest pressed key; held R
 * converts up/down to a50-card jump. The popup reader uses frame repeats.*/
uint16_t ReadCollectionMenuInput(uint8_t popup)
{
    if(!popup)PollMenuRepeat();uint16_t key=0,repeated=popup?gKeysRepeated:gPasswordRepeated;
    for(unsigned bit=1;bit<1024;bit<<=1)if(gKeysPressed&bit)key=bit;
    for(unsigned bit=16;bit<256;bit<<=1)if(repeated&bit)key=bit;
    if((repeated&64) && (gKeysHeld&256))key=0x140;if((repeated&128) && (gKeysHeld&256))key=0x180;return key;
}
/*0800475C*/
uint16_t CollectionCardAt(uint8_t visibleRow)
{
    int16_t index=(int16_t)(visibleRow+U16(M)-2);if(index<0)index+=900;else if(index>=900)index-=900;return gCollectionSortedCards[index];
}
/*080046EC/04694*/
void InitializeCollectionList(void)
{
    W16(M,0);VIEW=1;SORT=0;
    for(unsigned card=0;card<901;++card) {
        unsigned count=0;for(unsigned i=0;i<40;++i)count+=gPlayerDeck[i]==card;gCollectionTotals[card]=gCardCollection[card]+count;
    }
    for(unsigned i=0;i<900;++i)gCollectionSortedCards[i]=i+1;
}
void SortWagerList(void)
{
    uintptr_t p=(uintptr_t)gCollectionSortedCards;for(unsigned i=0;i<4;++i)gCardSortState[i]=p>>(i*8);
    W16(gCardSortState+8,900);gCardSortState[10]=45+SORT;SortCardList();
}
static void MoveWagerList(int offset)
{ int16_t index=(int16_t)(U16(M)+offset);if(index<0)index+=900;else if(index>=900)index-=900;W16(M,index);PlayGameAudio(54); }
/*08018D68/1823C: first element is checked even if it is zero.*/
static int CardInTerminatedList(uint16_t card,uint32_t address)
{ unsigned i=0;do { if(U16(ROM(address)+i*2)==card)return 1;++i; }while(U16(ROM(address)+i*2));return 0; }
extern uint16_t gOamBuffer[128][4];
/*080041B4*/
static void ClearWagerPopupSprites(void) { for(unsigned i=6;i<8;++i)for(unsigned j=0;j<4;++j)gOamBuffer[i][j]=0; }
static void LoadWagerList(void) { DrawPreDuelGraphics(0);DrawPreDuelGraphics(2);CollectionDisplayFrame(1);UploadMenuGraphics(); }
/*080077C0*/
static uint8_t ConfirmSpecialWager(void)
{
    CHOICE=0;DrawSpecialWagerPopup();DrawSpecialWagerCursor();PlayGameAudio(55);Frame(WagerPopupDisplayCallback);
    for(;;) {
        uint16_t key=ReadCollectionMenuInput(1);
        if(key==2) { PlayGameAudio(56);return 1; }
        if(key==1) { if(CHOICE==0) { PlayGameAudio(55);return 1; }if(CHOICE==1) { PlayGameAudio(222);return 0; } }
        else if(key==64 || key==128) {
            CHOICE=ROM(key==64?0x08D3493C:0x08D3493E)[CHOICE];DrawSpecialWagerCursor();PlayGameAudio(54);SetVBlankCallback(UploadOam);
        }
        WaitForFrame();
    }
}
/*08007750*/
static uint8_t AcceptWager(void)
{
    uint8_t result=1;uint16_t card=CollectionCardAt(2);
    if(!gCardCollection[card])PlayGameAudio(57);
    else if(CardInTerminatedList(card,0x080BA280)) {
        if(!ConfirmSpecialWager()) { result=0;gWageredCard=CollectionCardAt(2); }
    }else { result=0;gWageredCard=CollectionCardAt(2);PlayGameAudio(222); }
    WaitForFrame();return result;
}
/*08007638/07704*/
static uint8_t RunWagerActionMenu(void)
{
    uint8_t result=1;CHOICE=0;DrawWagerActionPopup();DrawWagerActionCursor();PlayGameAudio(55);Frame(WagerPopupDisplayCallback);
    for(;;) {
        uint16_t key=ReadCollectionMenuInput(1);
        if(key==2) { PlayGameAudio(56);break; }
        if(key==1) {
            if(!CHOICE) {
                LoadCardMetadata(CollectionCardAt(2));PlayGameAudio(55);ShowCardDescription();LoadWagerList();
                DrawWagerActionPopup();DrawWagerActionCursor();Frame(WagerPopupDisplayCallback);continue;
            }
            if(CHOICE==1) { if(!AcceptWager())result=0;break; }
            if(CHOICE==2) { PlayGameAudio(55);break; }
        }else if(key==64 || key==128) {
            CHOICE=ROM(key==64?0x08D34930:0x08D34933)[CHOICE];DrawWagerActionCursor();PlayGameAudio(54);SetVBlankCallback(UploadOam);
        }
        WaitForFrame();
    }
    ClearWagerPopupSprites();return result;
}
/*08007AB8*/
static uint8_t ConfirmNoWager(void)
{
    uint8_t result=1;CHOICE=0;DrawNoWagerPopup();DrawNoWagerCursor();PlayGameAudio(55);Frame(WagerPopupDisplayCallback);
    for(;;) {
        uint16_t key=ReadCollectionMenuInput(1);
        if(key==2) { PlayGameAudio(56);break; }
        if(key==1) { if(CHOICE==1) { result=0;PlayGameAudio(222); }else PlayGameAudio(55);break; }
        if(key==64 || key==128) { CHOICE=ROM(key==64?0x08D34944:0x08D34946)[CHOICE];PlayGameAudio(54);DrawNoWagerCursor();SetVBlankCallback(UploadOam); }
        WaitForFrame();
    }
    ClearWagerPopupSprites();return result;
}
/*080074DC*/
void RunPreDuelMenu(void)
{
    FadeGameMusic(2);PlayGameAudio(213);FadeIntoDuel();InitializeCollectionList();RefreshPlayerDeckState();SortWagerList();PlayGameAudio(143);
    gWageredCard=0;LoadWagerList();CollectionDisplayFrame(3);
    for(;;) {
        uint16_t key=ReadCollectionMenuInput(0);int done=0;
        switch(key) {
        case 64:case 128:case 0x140:case 0x180:
            MoveWagerList(key==64?-1:key==128?1:key==0x140?-50:50);DrawPreDuelGraphics(3);UploadCollectionFrame();CollectionDisplayFrame(4);break;
        case 512:if(++VIEW>3)VIEW=0;PlayGameAudio(54);DrawPreDuelGraphics(4);UploadCollectionFrame();CollectionDisplayFrame(4);break;
        case 1:
            if(!CardInTerminatedList(CollectionCardAt(2),0x08D36678))done=RunWagerActionMenu()==0;else PlayGameAudio(57);
            CollectionDisplayFrame(7);break;
        case 2:done=ConfirmNoWager()==0;CollectionDisplayFrame(7);break;
        case 4:
            if(++SORT>8)SORT=0;SortWagerList();W16(M,0);PlayGameAudio(54);DrawPreDuelGraphics(7);CollectionDisplayFrame(9);UploadCollectionList();break;
        case 8:RunWagerSortMenu();DrawPreDuelGraphics(8);CollectionDisplayFrame(8);break;
        default:CollectionIdle();CollectionDisplayFrame(5);break;
        }
        if(done) { FadeGameMusic(2);return; }
    }
}

/*08008BD0..08008DB8. Direction helpers preview the shared collection icon;
 * only accepting a non-cancel choice applies the sort and resets selection. */
extern uint8_t gBackgroundBuffer[];
extern void DrawCollectionSortPopup(void),DrawCollectionSortCursor(void),CollectionSortPopupCallback(void),DrawCollectionSortIcon(uint8_t);
#include "gba_bios.h"
void RunWagerSortMenu(void)
{
    CHOICE=SORT;DrawCollectionSortPopup();DrawCollectionSortCursor();BiosCpuSet(gBackgroundBuffer+0x4000,(void *)0x06004000,0x2000);
    PlayGameAudio(55);Frame(CollectionSortPopupCallback);
    for(;;) {
        uint16_t key=ReadCollectionMenuInput(1);
        if(key==1) { PlayGameAudio(55);if(CHOICE<9) { SORT=CHOICE;SortWagerList();W16(M,0); }break; }
        if(key==2 || key==8) { PlayGameAudio(56);break; }
        uint32_t table=key==64?0x08D3494C:key==128?0x08D34956:key==32?0x08D34960:key==16?0x08D3496A:0;
        if(!table) { WaitForFrame();continue; }
        CHOICE=ROM(table)[CHOICE];DrawCollectionSortIcon(CHOICE<9?CHOICE:SORT);DrawCollectionSortCursor();PlayGameAudio(54);Frame(UploadOam);
        BiosCpuSet(gBackgroundBuffer+0x8000,(void *)0x06008000,0x2000);
    }
    DrawPreDuelGraphics(7);UploadMenuGraphics();ClearWagerPopupSprites();
}
