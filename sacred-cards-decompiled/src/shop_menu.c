/* AY7E shop control/transaction/navigation bodies0801A644..0801C5A4,
 * sort menu0801B89C/0801E608. Rendering is in shop_graphics/shop_panel/
 * shop_display; the shared sort engine is in card_sort.c. */
#include <stdint.h>
#include "gba_bios.h"
extern uint8_t gShopWorkingStock[901],gShopWorkingCollection[901],gShopStock[901],gCardCollection[901];
extern uint16_t gShopSortedCards[904],gShopRowCards[5][7],*gShopVisibleCards[5][7]; /*020215A2/0202155C/020214D0*/
extern uint8_t gShopMenuState[10]; /*02021CB2: firstrow u16,rowcount u16,col,row,ring,sort,choice,pad*/
extern uint8_t gCardSortState[12]; /*02023040: card pointer at0,count at8,method at10*/
extern uint16_t gShopPriceCard,gKeysPressed,gKeysRepeated;
extern uint8_t gShopPriceStock,gPaletteBuffer[];
extern void UpdateShopPrices(void),CommitShopInventories(void),LoadCardMetadata(uint32_t),ShowCardDescription(void);
extern uint8_t BuyShopCardCore(uint16_t),SellShopCardCore(uint16_t);
extern void PlayGameAudio(uint32_t),WaitForFrame(void),UploadPalettes(void),SetVBlankCallback(void (*)(void));
/* Recovered graphic, transfer and card-sort bodies. */
extern void SortCardList(void),InitializeShopPopupMaps(void),InitializeShopStatusGraphics(void),InitializeShopMiniatures(void),InitializeShopBackdrop(void),InitializeShopSprites(void),UpdateShopOffsets(void);
extern void DrawShopBuyPanel(uint16_t),DrawShopSellPanel(uint16_t),DrawShopSortIcon(uint8_t),DrawShopMiniRow(uint8_t);
extern void DrawShopSelection(void),DrawShopShadow(void),DrawShopScrollbar(void),DrawShopAllMinis(void),SetShopListBlend(void),SetShopPopupBlend(void);
extern void UploadShopRowThenOffsets(uint8_t),UploadShopOffsetsThenRow(uint8_t),UploadShopAllRows(void),UploadShopTransaction(uint8_t);
extern void DrawShopBuyLabels(void),DrawShopSellLabels(void),DrawShopSortLabels(void),HideShopPopupCursor(void),DrawShopMoney(void);
extern void DrawShopActionCursor(void),DrawShopActionShadow(void),DrawShopSortCursor(void),DrawShopSortShadow(void),UploadShopActionPopup(void),UploadShopSortPopup(void);
extern void UploadShopSortChoice(void),UploadShopSortResults(void),UploadShopSortClosed(void),RestoreShopActionDisplay(void),RestoreShopListDisplay(void);
extern void UploadOam(void),InitializeShopDisplayCallback(void);
extern void ShowShopActionCallback(void),CloseShopPopupCallback(void),ShowShopSortCallback(void);
#define ROM(a) ((const uint8_t *)(uintptr_t)(a))
#define M gShopMenuState
#define COL M[4]
#define ROW M[5]
#define RING M[6]
#define SORT M[7]
#define CHOICE M[8]
static uint16_t U16(const uint8_t *p) { return p[0]|(uint16_t)p[1]<<8; }
static void W16(uint8_t *p,uint16_t v) { p[0]=v;p[1]=v>>8; }
static void Frame(void (*callback)(void)) { SetVBlankCallback(callback);WaitForFrame(); }
static uint16_t Selected(void) { return *gShopVisibleCards[ROW][COL]; }
static uint8_t PhysicalRow(uint8_t row) { return ROM(0x080C868C)[RING*5+row]; }
/*0801A790: independent conditions deliberately allow later keys to override.*/
uint16_t ReadShopInput(void)
{
    uint16_t key=0;if(gKeysRepeated&32)key=32;if(gKeysRepeated&16)key=16;
    if(gKeysRepeated&64)key=(gKeysRepeated&256)?0x140:64;
    if(gKeysRepeated&128)key=(gKeysRepeated&256)?0x180:128;
    if(gKeysPressed&1)key=1;if(gKeysPressed&2)key=2;if(gKeysPressed&4)key=4;if(gKeysPressed&8)key=8;return key;
}
/*0801C13C: single wrap, not arbitrary modulo.*/
static int16_t WrapShopRow(int16_t row)
{ int16_t count=U16(M+2);if(row<0)row+=count;else if(row>=count)row-=count;return row; }
static void OffsetShopRow(int16_t amount) { W16(M,WrapShopRow((int16_t)(U16(M)+amount))); }
/*0801C184*/
static void OrientShopRows(void)
{ for(unsigned row=0;row<5;++row)for(unsigned col=0;col<7;++col)gShopVisibleCards[row][col]=&gShopRowCards[PhysicalRow(row)][col]; }
/*0801B5CC/1C1F0*/
static void FillShopRow(uint8_t row,int selling)
{
    int16_t first=WrapShopRow((int16_t)(U16(M)+row));
    for(unsigned col=0;col<7;++col) {
        uint16_t card=gShopSortedCards[first*7+col+1];
        *gShopVisibleCards[row][col]=!card || (selling?gShopWorkingCollection[card]:gShopWorkingStock[card])?card:0;
    }
}
static void FillShopRows(int selling) { for(unsigned row=0;row<5;++row)FillShopRow(row,selling); }
/*0801B644/1C2B8. Sort method comes from different tables for buy and sell.*/
static void SortShopCards(uint8_t method,int selling)
{
    uintptr_t ptr=(uintptr_t)&gShopSortedCards[1];for(unsigned i=0;i<4;++i)gCardSortState[i]=ptr>>(i*8);
    W16(gCardSortState+8,900);gCardSortState[10]=ROM(selling?0x080C82F8:0x080C86AF)[method];
    SortCardList();RING=4;W16(M,128);
}
/*0801B77C/1C4C4*/
static void InitializeShopMenu(int selling)
{
    for(unsigned i=0;i<904;++i)gShopSortedCards[i]=0;
    for(unsigned i=0;i<901;++i) { gShopWorkingStock[i]=gShopStock[i];gShopWorkingCollection[i]=gCardCollection[i]; }
    CHOICE=0;W16(M,128);W16(M+2,129);RING=4;SORT=0;COL=0;ROW=1;
    for(unsigned i=1;i<901;++i)gShopSortedCards[i]=i;SortShopCards(0,selling);OrientShopRows();FillShopRows(selling);
}
static void Reprice(uint16_t card) { gShopPriceCard=card;gShopPriceStock=gShopWorkingStock[card];UpdateShopPrices(); }
static void DrawPrice(uint16_t card,int selling) { if(selling)DrawShopSellPanel(card);else DrawShopBuyPanel(card); }
/*0801ABCC*/
void FadeShopPalette(void)
{
    for(unsigned frame=0;frame<32;++frame) {
        for(unsigned i=0;i<512;++i) {
            uint8_t *p=gPaletteBuffer+i*2;uint16_t old=U16(p),value=old&0x8000;
            for(unsigned s=0;s<15;s+=5) { unsigned n=(old>>s)&31;value|=(n?n-1:0)<<s; }W16(p,value);
        }
        Frame(UploadPalettes);
    }
}
/*0801B4C8/1B50C/1B550/1B580; buy versions1BFE4/1C028/1C06C/1C09C.*/
static void MoveShopVertical(int down,int selling)
{
    if(down?ROW<3:ROW>=2) { ROW+=down?1:-1;return; }
    OffsetShopRow(down?1:-1);RING=ROM(down?0x080C86AA:0x080C86A5)[RING];OrientShopRows();
    FillShopRow(down?4:0,selling);DrawShopMiniRow(down?4:0);UpdateShopOffsets();
}
static void NavigateShop(uint16_t input,int selling)
{
    unsigned edge=0;
    if(input==64)MoveShopVertical(0,selling);
    else if(input==128) { MoveShopVertical(1,selling);edge=4; }
    else if(input==32) { if(!COL) { MoveShopVertical(0,selling);COL=6; }else --COL; }
    else if(input==16) { if(COL<6)++COL;else { MoveShopVertical(1,selling);COL=0; }edge=4; }
    Reprice(Selected());DrawPrice(gShopPriceCard,selling);DrawShopSelection();DrawShopShadow();DrawShopScrollbar();Frame(UploadOam);
    if(input==128)UploadShopOffsetsThenRow(PhysicalRow(edge));else UploadShopRowThenOffsets(PhysicalRow(edge));
    /* All eight native direction wrappers play54 after their redraws. */
    PlayGameAudio(54);
}
static void PageOrSortShop(uint16_t input,int selling)
{
    if(input==4) { if(++SORT>8)SORT=0;SortShopCards(SORT,selling); }
    else { OffsetShopRow(input==0x140?-10:10);RING=4; }
    OrientShopRows();FillShopRows(selling);Reprice(Selected());if(input==4)DrawShopSortIcon(SORT);
    DrawPrice(gShopPriceCard,selling);DrawShopAllMinis();UpdateShopOffsets();DrawShopScrollbar();
    if(selling)PlayGameAudio(input==4?55:54);Frame(UploadOam);UploadShopAllRows();
    if(!selling)PlayGameAudio(input==4?55:54);
}
static void LoadShopGraphics(int selling)
{
    InitializeShopPopupMaps();InitializeShopStatusGraphics();DrawPrice(gShopPriceCard,selling);InitializeShopMiniatures();InitializeShopBackdrop();InitializeShopSprites();UpdateShopOffsets();
}
static void ActionMenuTiles(int selling) { if(selling)DrawShopSellLabels();else DrawShopBuyLabels(); }
/*0801B41C/1BE28*/
static void InspectShopCard(int selling)
{
    uint16_t card=Selected();LoadCardMetadata(card);PlayGameAudio(55);ShowCardDescription();Reprice(card);SetShopPopupBlend();LoadShopGraphics(selling);
    DrawShopSelection();ActionMenuTiles(selling);DrawShopActionCursor();DrawShopActionShadow();Frame(InitializeShopDisplayCallback);Frame(UploadOam);RestoreShopActionDisplay();
}
/*0801B334/1BD20: redraw/repricing occurs on success AND failure.*/
static void TransactShopCard(int selling)
{
    uint16_t card=Selected();if(selling)SellShopCardCore(card);else BuyShopCardCore(card);
    Reprice(card);FillShopRows(selling);FillShopRow(ROW,selling);DrawShopMiniRow(ROW);DrawShopMoney();DrawPrice(Selected(),selling);
    Frame(ShowShopActionCallback);UploadShopTransaction(PhysicalRow(ROW));
}
/*0801B1B0/1BB9C*/
static void RunShopActionMenu(int selling)
{
    CHOICE=0;SetShopPopupBlend();ActionMenuTiles(selling);DrawShopActionCursor();DrawShopActionShadow();UploadShopActionPopup();Frame(ShowShopActionCallback);PlayGameAudio(55);
    for(;;) {
        uint16_t input=ReadShopInput();
        if(input==2) { PlayGameAudio(56);break; }
        if(input==1) {
            if(!CHOICE)TransactShopCard(selling);else if(CHOICE==1)InspectShopCard(selling);else { PlayGameAudio(55);WaitForFrame(); }
            if(CHOICE==2 || !Selected())break;
        }else if(input==64 || input==128) {
            CHOICE=ROM(input==64?0x080C86B8:0x080C86BB)[CHOICE];DrawShopActionCursor();DrawShopActionShadow();Frame(ShowShopActionCallback);PlayGameAudio(54);
        }else WaitForFrame();
    }
    /* The SELL exit also calls the BUY price presentation body1CF94. */
    SetShopListBlend();DrawShopMoney();DrawShopBuyPanel(Selected());HideShopPopupCursor();DrawShopShadow();Frame(CloseShopPopupCallback);
}
static void CloseShopSortMenu(void)
{ DrawShopSortIcon(SORT);DrawShopShadow();SetShopListBlend();HideShopPopupCursor();Frame(CloseShopPopupCallback);UploadShopSortClosed(); }
/*0801B89C/1E608, with0801C378/398/3B8/3D8 navigation tables.*/
static void RunShopSortMenu(int selling)
{
    CHOICE=SORT;SetShopPopupBlend();DrawShopSortLabels();DrawShopSortCursor();DrawShopSortShadow();UploadShopSortPopup();Frame(ShowShopSortCallback);PlayGameAudio(55);
    for(;;) {
        uint16_t input=ReadShopInput();
        if(input==2 || input==8) { CloseShopSortMenu();PlayGameAudio(56);return; }
        if(input==1) {
            if(CHOICE==9) { CloseShopSortMenu();PlayGameAudio(55);return; }
            SORT=CHOICE;SortShopCards(CHOICE,selling);OrientShopRows();FillShopRows(selling);Reprice(Selected());PlayGameAudio(55);
            SetShopListBlend();DrawShopSortIcon(SORT);DrawPrice(gShopPriceCard,selling);DrawShopAllMinis();UpdateShopOffsets();DrawShopScrollbar();
            DrawShopShadow();HideShopPopupCursor();Frame(CloseShopPopupCallback);UploadShopSortResults();return;
        }
        if(input==64)CHOICE=ROM(0x080C86BE)[CHOICE];else if(input==128)CHOICE=ROM(0x080C86C8)[CHOICE];else if(input==32)CHOICE=ROM(0x080C86D2)[CHOICE];else if(input==16)CHOICE=ROM(0x080C86DC)[CHOICE];
        else { WaitForFrame();continue; }
        DrawShopSortIcon(CHOICE==9?SORT:CHOICE);DrawShopSortCursor();DrawShopSortShadow();Frame(UploadOam);UploadShopSortChoice();PlayGameAudio(54);
    }
}
/*0801AB78/1B15C*/
static int UnavailableShopCard(uint16_t card) { return !card || card==832 || card==833 || card==834; }
/*0801A644/1AC98*/
static void RunShop(int selling)
{
    FadeShopPalette();InitializeShopMenu(selling);Reprice(Selected());LoadShopGraphics(selling);Frame(InitializeShopDisplayCallback);
    SetShopListBlend();Frame(UploadOam);RestoreShopListDisplay();
    for(;;) {
        uint16_t input=ReadShopInput();
        if(input==2) { PlayGameAudio(56);WaitForFrame();break; }
        if(input==16 || input==32 || input==64 || input==128)NavigateShop(input,selling);
        else if(input==4 || input==0x140 || input==0x180)PageOrSortShop(input,selling);
        else if(input==1) { if(UnavailableShopCard(Selected())) { PlayGameAudio(57);WaitForFrame(); }else RunShopActionMenu(selling); }
        else if(input==8)RunShopSortMenu(selling);else WaitForFrame();
    }
    CommitShopInventories();FadeShopPalette();
}
void RunBuyShop(void) { RunShop(0); }
void RunSellShop(void) { RunShop(1); }
