/* AY7E collection editor08003C8C..080041B4 and deck editor08013B70..08014074,
 * with their sorting popups08005B24..08005D9C /08015898..08015B08. */
#include "deck_builder.h"
#include "gba_bios.h"
extern uint8_t gCollectionMenu[12],gPlayerDeckState[10],gDeckActionChoice; /*0201CB48*/
extern uint8_t gBackgroundBuffer[];
extern uint16_t gOamBuffer[128][4];
extern void PlayGameAudio(uint32_t),WaitForFrame(void),SetVBlankCallback(void (*)(void)),UploadOam(void),UploadPalettes(void),PollMenuRepeat(void);
extern uint16_t ReadCollectionMenuInput(uint8_t),CollectionCardAt(uint8_t);
extern void LoadCardMetadata(uint32_t),ShowCardDescription(void),UploadMenuGraphics(void),UploadCollectionText(void),UploadCollectionFrame(void),UploadCollectionList(void);
extern void UploadDeckEditorFrame(void),UploadDeckRemoval(void),CollectionDisplayFrame(uint8_t),DrawCollectionSortIcon(uint8_t);
extern void DrawCardListActionPopup(uint32_t,uint32_t),DrawCardListSortPopup(uint32_t,uint32_t),CollectionSortPopupCallback(void);
#define ROM(a) ((const uint8_t *)(uintptr_t)(a))
#define REG(a) (*(volatile uint16_t *)(uintptr_t)(a))
#define M gCollectionMenu
#define D gPlayerDeckState
static uint16_t U16(const uint8_t *p) { return p[0]|(uint16_t)p[1]<<8; }
static void W16(uint8_t *p,uint16_t n) { p[0]=n;p[1]=n>>8; }
static void Frame(void (*callback)(void)) { SetVBlankCallback(callback);WaitForFrame(); }
static void UploadPopup(void) { BiosCpuSet(gBackgroundBuffer+0x4000,(void *)0x06004000,0x2000); }
static void ClearPopupSprites(void) { for(unsigned i=6;i<8;++i)for(unsigned j=0;j<4;++j)gOamBuffer[i][j]=0; }
/*08004180/14040: palette and OAM upload, without the wager callback's BG copy.*/
void DeckBuilderPopupCallback(void)
{ UploadPalettes();UploadOam();REG(0x04000000)=0xBF00;REG(0x04000052)=6;REG(0x04000054)=10;REG(0x04000050)|=8; }
static void Cursor(unsigned choice,uint32_t ytable,uint32_t xtable)
{
    for(unsigned i=6;i<8;++i) { gOamBuffer[i][0]=ROM(ytable)[choice]|(i==7?0x800:0);gOamBuffer[i][1]=ROM(xtable)[choice]|0x4000;gOamBuffer[i][2]=i==6?0xC120:0x120;gOamBuffer[i][3]=0; }
}
static void CollectionCursor(void) { Cursor(M[4],0x08D30D96,0x08D30D99); }
static void DeckCursor(void) { Cursor(gDeckActionChoice,0x08D35BD8,0x08D35BDB); }
/*08013C84/08013D18 poll menu repeat state but read frame repeats.*/
static uint16_t DeckInput(void) { PollMenuRepeat();return ReadCollectionMenuInput(1); }
/*08003F70/13E5C. Only the former sorts before entering.*/
static void LoadCollection(void)
{ DrawCollectionEditorGraphics(0);DrawCollectionEditorGraphics(2);CollectionDisplayFrame(1);UploadMenuGraphics(); }
static void LoadDeck(void)
{ DrawDeckEditorGraphics(0);DrawDeckEditorGraphics(2);DeckEditorDisplayFrame(1);UploadMenuGraphics(); }
static void CollectionTransfer(unsigned add)
{
    if(add)AddSelectedCollectionCardToDeck();else RemoveSelectedCollectionCardFromDeck();
    DrawCollectionEditorGraphics(3);UploadCollectionText();CollectionDisplayFrame(6);
}
static void CollectionAction(void)
{
    M[4]=0;DrawCardListActionPopup(0x0808250C,0x08086AC4);CollectionCursor();UploadPopup();Frame(DeckBuilderPopupCallback);PlayGameAudio(55);
    for(;;) {
        uint16_t key=ReadCollectionMenuInput(1);
        if(key==2) { PlayGameAudio(56);ClearPopupSprites();return; }
        if(key==1) {
            if(!M[4]) {
                LoadCardMetadata(CollectionCardAt(2));PlayGameAudio(55);ShowCardDescription();LoadCollection();
                DrawCardListActionPopup(0x0808250C,0x08086AC4);CollectionCursor();Frame(DeckBuilderPopupCallback);UploadPopup();
            }else if(M[4]==1)CollectionTransfer(1);else if(M[4]==2)CollectionTransfer(0);
        }else if(key==64 || key==128) {
            M[4]=ROM(key==64?0x08D30D90:0x08D30D93)[M[4]];CollectionCursor();PlayGameAudio(54);Frame(UploadOam);
        }else WaitForFrame();
    }
}
static void DeckAction(void)
{
    gDeckActionChoice=0;PlayGameAudio(55);DrawCardListActionPopup(0x08083C7C,0x080B46E0);DeckCursor();UploadPopup();Frame(DeckBuilderPopupCallback);
    for(;;) {
        uint16_t key=DeckInput();
        if(key==2) { PlayGameAudio(56);break; }
        if(key==1) {
            if(!gDeckActionChoice) {
                LoadCardMetadata(PlayerDeckCardAt(2));PlayGameAudio(55);ShowCardDescription();LoadDeck();
                DrawCardListActionPopup(0x08083C7C,0x080B46E0);DeckCursor();Frame(DeckBuilderPopupCallback);UploadPopup();
            }else if(gDeckActionChoice==1) { RemoveSelectedDeckCard();DrawDeckEditorGraphics(3);UploadDeckRemoval();DeckEditorDisplayFrame(6);break; }
        }else if(key==64 || key==128) {
            gDeckActionChoice=ROM(key==64?0x08D35BD4:0x08D35BD6)[gDeckActionChoice];DeckCursor();PlayGameAudio(54);Frame(UploadOam);
        }else WaitForFrame();
    }
    ClearPopupSprites();
}
/* The two sort menus share logic, with distinct state and ROM navigation/OAM
 * tables. The deck caller performs its own post-popup redraw. */
static void SortPopup(unsigned deck)
{
    uint8_t *choice=deck?D+7:M+4,*sort=deck?D+5:M+2;*choice=*sort;
    DrawCardListSortPopup(deck?0x0808412C:0x080829BC,deck?0x080B4820:0x08086C00);
    Cursor(*choice,deck?0x08D35C14:0x08D30F2C,deck?0x08D35C1E:0x08D30F36);UploadPopup();PlayGameAudio(55);Frame(CollectionSortPopupCallback);
    for(;;) {
        uint16_t key=deck?DeckInput():ReadCollectionMenuInput(1);
        if(key==2 || key==8) { PlayGameAudio(56);break; }
        if(key==1) {
            PlayGameAudio(55);if(*choice<9) { *sort=*choice;if(deck)SortPlayerDeck(*choice,1);else { SortWagerList();W16(M,0); } }break;
        }
        unsigned index=key==64?0:key==128?1:key==32?2:key==16?3:4;
        if(index==4) { WaitForFrame();continue; }
        *choice=ROM((deck?0x08D35BEC:0x08D30F04)+index*10)[*choice];DrawCollectionSortIcon(*choice<9?*choice:*sort);
        Cursor(*choice,deck?0x08D35C14:0x08D30F2C,deck?0x08D35C1E:0x08D30F36);PlayGameAudio(54);Frame(UploadOam);
        BiosCpuSet(gBackgroundBuffer+0x8000,(void *)0x06008000,0x2000);
    }
    if(!deck) { DrawCollectionEditorGraphics(7);UploadMenuGraphics(); }ClearPopupSprites();
}
static void MoveCollection(int amount)
{ int16_t index=(int16_t)(U16(M)+amount);if(index<0)index+=900;else if(index>=900)index-=900;W16(M,index);PlayGameAudio(54); }
/*0800441C: the original state dispatcher is also callable independently of
 * the editor loop; command10 changes mode without sorting or redrawing.*/
extern void InitializeCardCollection(void);
void DispatchCollectionStateCommand(uint8_t command)
{
    switch(command) {
    case 0:InitializeCardCollection();break;
    case 1:InitializeCollectionList();break;
    case 2:MoveCollection(1);break;
    case 3:MoveCollection(-1);break;
    case 4:MoveCollection(50);break;
    case 5:MoveCollection(-50);break;
    case 6:if(++M[3]>3)M[3]=0;PlayGameAudio(54);break;
    case 7:AddSelectedCollectionCardToDeck();break;
    case 8:RemoveSelectedCollectionCardFromDeck();break;
    case 10:if(++M[2]>8)M[2]=0;PlayGameAudio(54);break;
    }
}
void RunCollectionEditor(void)
{
    SortWagerList();LoadCollection();CollectionDisplayFrame(3);
    for(;;) {
        uint16_t key=ReadCollectionMenuInput(0);
        switch(key) {
        case 2:DrawCollectionEditorGraphics(1);PlayGameAudio(56);CollectionDisplayFrame(2);return;
        case 1:CollectionAction();CollectionDisplayFrame(7);break;
        case 16:CollectionTransfer(1);break;
        case 32:CollectionTransfer(0);break;
        case 64:case 128:case 0x140:case 0x180:
            MoveCollection(key==64?-1:key==128?1:key==0x140?-50:50);DrawCollectionEditorGraphics(3);UploadCollectionFrame();CollectionDisplayFrame(4);break;
        case 512:
            if(++M[3]>3)M[3]=0;PlayGameAudio(54);DrawCollectionEditorGraphics(4);UploadCollectionFrame();CollectionDisplayFrame(4);break;
        case 4:
            if(++M[2]>8)M[2]=0;SortWagerList();W16(M,0);PlayGameAudio(54);DrawCollectionEditorGraphics(7);CollectionDisplayFrame(9);UploadCollectionList();break;
        case 8:SortPopup(0);DrawCollectionEditorGraphics(8);CollectionDisplayFrame(8);break;
        default:DrawCollectionEditorGraphics(5);CollectionDisplayFrame(5);break;
        }
    }
}
void RunDeckEditor(void)
{
    if(!PlayerDeckCount())return;SortPlayerDeck(D[5],0);LoadDeck();DeckEditorDisplayFrame(3);unsigned done=0;
    do {
        uint16_t key=DeckInput();
        switch(key) {
        case 2:done=1;PlayGameAudio(56);break;
        case 1:DeckAction();DeckEditorDisplayFrame(7);break;
        case 8:SortPopup(1);DrawDeckEditorGraphics(7);DeckEditorDisplayFrame(9);UploadCollectionList();break;
        case 4:
            if(++D[5]>8)D[5]=0;SortPlayerDeck(D[5],1);DrawDeckEditorGraphics(6);DrawDeckEditorGraphics(6);PlayGameAudio(55);DeckEditorDisplayFrame(8);UploadCollectionList();break;
        case 64:case 128:case 0x140:case 0x180:
            MovePlayerDeckSelection(key>=0x140?10:1,key==128 || key==0x180);DrawDeckEditorGraphics(3);UploadDeckEditorFrame();DeckEditorDisplayFrame(4);break;
        case 512:
            if(++D[6]>3)D[6]=0;PlayGameAudio(54);DrawDeckEditorGraphics(4);UploadDeckEditorFrame();DeckEditorDisplayFrame(4);break;
        default:DrawDeckEditorGraphics(5);DeckEditorDisplayFrame(5);break;
        }
        if(!PlayerDeckCount())done=1;
    }while(!done);
    DrawDeckEditorGraphics(1);DeckEditorDisplayFrame(2);
}

/*08013DD4: unused removal path without the normal transfer/popup tail.*/
void RemoveDeckCardLegacy(void) { RemoveSelectedDeckCard();DrawDeckEditorGraphics(3); }
