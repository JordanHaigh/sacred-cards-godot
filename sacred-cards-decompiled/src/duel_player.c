/* AY7E player duel controls, 0802478C/24810 and 080274EC..08027FBC.
 * The cursor uses the fixed visible grid; spell/trap effects use the relative
 * grid. Preserve that distinction even though both align during player turns.
 * Battle presentation remains an explicit dependency. No execution comparison. */
#include "ai.h"
#include "gba_bios.h"
extern uint8_t gDuelCursorState[6],gDuelViewMode,gPlayerTurnDone;
extern uint16_t gDuelSelectionCopy[4]; /* 02023378, eight-byte cell */
extern uint16_t *gDuelVisibleCells[5][5];
extern uint16_t gKeysPressed,gKeysHeld,gKeysRepeated,gBgOffsetsRaw[22];
extern uint8_t gBackgroundBuffer[],gPaletteBuffer[];
extern const int8_t gSpellTargetClasses[132];
extern void WaitForFrame(void),ResetGameKeys(void),RestoreDuelDisplay(void),LoadSelectedDuelCardDetails(void);
extern void DrawDuelCursorPosition(void),ComposeDuelMiniatureOam(void),UploadOam(void),UploadBackgroundOffsets(void);
extern void ReloadDuelDisplay(void),PresentBattleAnimation(void),CheckExodiaWin(void),CheckDestinyBoardWin(void);
extern void ResetTributesCommitted(void),IncrementTributesCommitted(void),DispatchMetadata1aHandler(void),DispatchMetadata1bHandler(void);
extern uint8_t RemainingCategoryFourRequirement(uint16_t),CanShowDuelCardMetadata(uint8_t,uint8_t);
extern void SetCardPreviewModifiers(uint8_t,int32_t),LoadCardWithPreviewStats(uint16_t),ShowCardDescription(void);
extern void DiscardAbsoluteDuelCell(uint16_t *,uint8_t);
extern uint8_t RunMonsterActionMenu(void);
extern void DrawDuelContextMenu(uint8_t),InitializeDuelContextMenu(uint8_t),ShowDuelStatsWhileHeld(void),ShowOpponentHand(void);
#define ROM(a) ((const uint8_t *)(uintptr_t)(a))
#define COL gDuelCursorState[0]
#define ROW gDuelCursorState[1]
#define SAVED_COL gDuelCursorState[2]
#define SAVED_ROW gDuelCursorState[3]
#define MODE gDuelCursorState[4]
static uint16_t *Selected(void) { return gDuelVisibleCells[ROW][COL]; }
static uint16_t *Saved(void) { return gDuelVisibleCells[SAVED_ROW][SAVED_COL]; }
static uint8_t *Flags(uint16_t *cell) { return (uint8_t *)cell+4; }
static uint16_t U16(const uint8_t *p) { return p[0]|(uint16_t)p[1]<<8; }
static void SaveCursor(void) { SAVED_COL=COL;SAVED_ROW=ROW; } /*08027684*/
static void RestoreCursor(void) { COL=SAVED_COL;ROW=SAVED_ROW; } /*08027694*/
static void InvalidSelection(void) { PlayGameAudio(57);WaitForFrame(); }
/*08024E18*/
void UploadDuelHudUpdate(void)
{
    UploadOam();UploadBackgroundOffsets();
    BiosCpuSet(gBackgroundBuffer+0x8040,(void *)0x06008040,0x040001D0);
    BiosCpuSet(gPaletteBuffer+0xA0,(void *)0x050000A0,0x20);
}
/*08025818/25870/258E8. The native signed targets and unsigned current offset
 * are compared as integers; the 256-unit steps are retained. */
void TransitionDuelViewport(uint8_t previous,uint8_t next)
{
    unsigned kind=ROM(0x08D4C2A8)[previous*5+next];gDuelViewMode=next;
    if(kind==1 || kind==2) {
        int target=(int16_t)U16(ROM(0x08D4C2C6)+next*2);
        while(kind==1?target+256<gBgOffsetsRaw[2]:gBgOffsetsRaw[2]<target-256) {
            gBgOffsetsRaw[2]+=kind==1?-256:256;
            ComposeDuelMiniatureOam();WaitForFrame();UploadDuelHudUpdate();
        }
        gBgOffsetsRaw[2]=(uint16_t)target;ComposeDuelMiniatureOam();
    }else if(kind!=0)return;
    DrawDuelCursorPosition();WaitForFrame();UploadDuelHudUpdate();
}
/*0802478C: directions have priority over A, L, R, B, in that order.*/
uint8_t ReadPlayerDuelInput(void)
{
    if(gKeysRepeated&64)return 1;if(gKeysRepeated&128)return 2;
    if(gKeysRepeated&32)return 3;if(gKeysRepeated&16)return 4;
    if(gKeysPressed&1)return 5;if(gKeysPressed&512)return 6;
    if(gKeysPressed&256)return 7;if(gKeysPressed&2)return 8;return 0;
}
/*08026A20/26A64/26A94: monster search does not filter the used flag.*/
static uint8_t FirstEmpty(uint8_t row)
{ for(unsigned i=0;i<5;++i)if(!*gDuelVisibleCells[row][i])return i;return 0; }
static uint8_t FirstMonster(uint8_t row)
{ for(unsigned i=0;i<5;++i)if(ClassifyDuelCard(*gDuelVisibleCells[row][i])==1)return i;return 0; }
static uint8_t LastMonster(uint8_t row)
{ for(int i=4;i>=0;--i)if(ClassifyDuelCard(*gDuelVisibleCells[row][i])==1)return i;return 4; }
/*080277E0*/
static void BeginPlacement(void)
{
    uint16_t card=*Selected();CopyDuelCell(gDuelSelectionCopy,Selected());MODE=1;SaveCursor();
    int kind=ClassifyDuelCard(card);
    if(kind==1) { COL=FirstEmpty(2);ROW=2; }
    else if(kind>1 && kind<5) { COL=FirstEmpty(3);ROW=3; }
    LoadSelectedDuelCardDetails();TransitionDuelViewport(SAVED_ROW,ROW);
}
/*08027D08: native destination can already be occupied; do not add a guard.*/
static void CommitPlacement(void)
{
    ClearDuelCell(Saved());CopyDuelCell(Selected(),gDuelSelectionCopy);
    MODE=0;SaveCursor();RestoreDuelDisplay();
}
/*08027C80*/
static void ConfirmPlacement(void)
{
    LoadCardMetadata(*Saved());int kind=ClassifyDuelCard(U16(gCardMetadataBytes+0x10));
    if(kind>1 && kind<5) {
        if(ROW==3) { PlayGameAudio(58);CommitPlacement();CheckDestinyBoardWin();return; }
    }else if(ROW==2) {
        PlayGameAudio(58);gDuelSideState[0][2]|=8;LockMonsterRow(4);ResetTributesCommitted();CommitPlacement();return;
    }
    InvalidSelection();
}
/*08027BC8*/
static void BeginSpell(void)
{
    uint16_t card=*Selected();CopyDuelCell(gDuelSelectionCopy,Selected());SaveCursor();
    LoadCardMetadata(card);int kind=gSpellTargetClasses[gCardMetadataBytes[0x1A]];
    if(kind==1) { PlayGameAudio(55);MODE=2;COL=FirstMonster(2);ROW=2; }
    else if(kind==0) {
        MODE=0;gSpellInput.card=card;gSpellInput.row=ROW;gSpellInput.column=COL;DispatchMetadata1aHandler();
        if(gDuelSideState[0][2]&8)LockMonsterRow(4);RestoreDuelDisplay();CheckExodiaWin();
    }else if(kind==2) { PlayGameAudio(57);MODE=0; }
    LoadSelectedDuelCardDetails();TransitionDuelViewport(SAVED_ROW,ROW);
}
/*08027D50*/
static void ConfirmSpellTarget(void)
{
    if(ROW!=2 || !*Selected() || (*Flags(Selected())&1)) { InvalidSelection();return; }
    uint8_t flags=*Flags(Selected());LoadCardMetadata(*Selected());
    if(ClassifyDuelCard(U16(gCardMetadataBytes+0x10))==1) {
        gSpellInput.card=*Saved();gSpellInput.source_row=SAVED_ROW;gSpellInput.source_column=SAVED_COL;
        gSpellInput.row=ROW;gSpellInput.column=COL;DispatchMetadata1aHandler();
    }
    MODE=flags&1;SaveCursor();RestoreDuelDisplay();
}
/*08023684/23734/23854 use visible coordinates, including the saved cursor
 * fields in the direct-attack path. Do not substitute AI setup routines.*/
extern uint8_t gBattleCalculationBytes[0x1C],gBattleDisplayBytes[0x19];
extern uint16_t gDuelLifePoints[2];
static void W16(uint8_t *p,uint16_t v) { p[0]=v;p[1]=v>>8; }
static void LoadPlayerCombatant(unsigned side,uint16_t *cell,uint8_t row,uint8_t col)
{
    unsigned at=side*12;
    SetCardPreviewModifiers(gTerrain,(int8_t)((uint8_t *)cell)[2]);LoadCardWithPreviewStats(*cell);
    W16(gBattleCalculationBytes+at,*cell);W16(gBattleCalculationBytes+at+2,U16(gCardMetadataBytes+0x12));
    W16(gBattleCalculationBytes+at+4,U16(gCardMetadataBytes+0x14));gBattleCalculationBytes[at+8]=gCardMetadataBytes[0x17];
    W16(gBattleCalculationBytes+at+6,gDuelLifePoints[side]);W16(gBattleDisplayBytes+at+2,gDuelLifePoints[side]);
    gBattleCalculationBytes[at+10]=col;gBattleCalculationBytes[at+9]=row;gBattleCalculationBytes[0x1A+side]=side;
}
static void PreparePlayerMonsterAttack(void)
{
    gBattleCalculationBytes[0x18]=(*Flags(Selected())&2)?2:1;
    LoadPlayerCombatant(0,Saved(),SAVED_ROW,SAVED_COL);LoadPlayerCombatant(1,Selected(),ROW,COL);
}
static void PreparePlayerDirectAttack(void)
{
    gBattleCalculationBytes[0x18]=4;W16(gBattleCalculationBytes,*Selected());
    SetCardPreviewModifiers(gTerrain,(int8_t)((uint8_t *)Selected())[2]);LoadCardWithPreviewStats(*Selected());
    W16(gBattleCalculationBytes+2,U16(gCardMetadataBytes+0x12));W16(gBattleCalculationBytes+4,U16(gCardMetadataBytes+0x14));
    for(unsigned side=0;side<2;++side) {
        W16(gBattleCalculationBytes+side*12+6,gDuelLifePoints[side]);W16(gBattleDisplayBytes+side*12+2,gDuelLifePoints[side]);
    }
    gBattleCalculationBytes[10]=SAVED_COL;gBattleCalculationBytes[9]=SAVED_ROW;
    gBattleCalculationBytes[0x1A]=0;gBattleCalculationBytes[0x1B]=1;
}
static void AttackPose(uint16_t *cell) { *Flags(cell)=(*Flags(cell)&0xFD)|0x11; }
/*08027A70*/
static void BeginAttack(void)
{
    if(!gDuelAuxiliaryFlags[GetActingSide()] || (gDuelSideState[0][2]&3)) {
        PlayGameAudio(57);*Flags(Selected())|=1;RestoreDuelDisplay();return;
    }
    gTrapInput.card=*Selected();gTrapInput.row=ROW;gTrapInput.column=COL;
    if(FindActivatingTrap()==1) {
        PlayGameAudio(66);
        /* The attack-trigger validators accept only kinds that ignore amount;
         * the native audio return register is not an amount contract here. */
        ActivateSelectedTrap(0);return;
    }
    PlayGameAudio(55);unsigned empty=0;for(unsigned i=0;i<5;++i)empty+=*gEffectBoardCells[1][i]==0;
    if(empty==5) {
        AttackPose(Selected());PreparePlayerDirectAttack();ResolveCurrentBattleNumbers();ApplyBattleDestruction();MODE=0;
        PresentBattleAnimation();ReloadDuelDisplay();WaitForFrame();
    }else {
        CopyDuelCell(gDuelSelectionCopy,Selected());MODE=4;SaveCursor();COL=LastMonster(1);ROW=1;
        LoadSelectedDuelCardDetails();TransitionDuelViewport(SAVED_ROW,ROW);RestoreDuelDisplay();
    }
}
/*08027DE4*/
static void ConfirmAttackTarget(void)
{
    if(ROW!=1 || !*gEffectBoardCells[1][COL]) { InvalidSelection();return; }
    PlayGameAudio(55);AttackPose(Saved());*Flags(Selected())|=16;
    PreparePlayerMonsterAttack();ResolveCurrentBattleNumbers();ApplyBattleDestruction();MODE=0;RestoreCursor();
    PresentBattleAnimation();ReloadDuelDisplay();WaitForFrame();
}
/*08027854*/
static void ChooseMonsterAction(void)
{
    switch(RunMonsterActionMenu()) {
    case 1:BeginAttack();break;
    case 2:
        if(!(gDuelSideState[0][2]&4)) { PlayGameAudio(55);*Flags(Selected())|=3; }
        else { PlayGameAudio(57);*Flags(Selected())&=0xFD; }
        RestoreDuelDisplay();break;
    case 3:PlayGameAudio(61);IncrementTributesCommitted();DiscardAbsoluteDuelCell(Selected(),0);RestoreDuelDisplay();break;
    case 4:
        if(!(*Flags(Selected())&16) && (LoadCardMetadata(*Selected()),gCardMetadataBytes[0x1B])) {
            PlayGameAudio(64);AttackPose(Selected());gMonsterInput.card=*Selected();gMonsterInput.row=ROW;gMonsterInput.column=COL;
            DispatchMetadata1bHandler();if(gDuelSideState[0][2]&8)LockMonsterRow(4);RestoreDuelDisplay();CheckExodiaWin();
        }else { PlayGameAudio(57);RestoreDuelDisplay(); }break;
    case 5:
        if((*Flags(gEffectBoardCells[ROW][COL])&2) && (gDuelSideState[0][2]&4))*Flags(gEffectBoardCells[ROW][COL])&=0xFD;
        RestoreDuelDisplay();break;
    }
}
/*08027704/276C8*/
void ConfirmDuelSelection(void)
{
    if(MODE==1) { ConfirmPlacement();return; }if(MODE==2) { ConfirmSpellTarget();return; }
    if(MODE==4) { ConfirmAttackTarget();return; }if(MODE!=0)return;
    uint8_t required;
    if(ROW==3 && *Selected()) {
        required=RemainingCategoryFourRequirement(*Selected());if(!required) { BeginSpell();return; }
    }else if(ROW==2 && *Selected() && !(*Flags(Selected())&1)) { PlayGameAudio(55);ChooseMonsterAction();return; }
    else if(ROW==4 && *Selected() && !(*Flags(Selected())&1)) {
        required=RemainingMonsterTributes(*Selected());if(!required) { PlayGameAudio(55);BeginPlacement();return; }
    }else { InvalidSelection();return; }
    PlayGameAudio(57);PresentDuelStatusText(required);
}
/*08025C2C*/
void RunDuelContextMenu(void)
{
    uint8_t choice=0;InitializeDuelContextMenu(choice);
    for(;;) {
        uint32_t navigation=0;
        if(gKeysRepeated&64)navigation=0x08D4C538;else if(gKeysRepeated&128)navigation=0x08D4C53B;
        else if(gKeysRepeated&16)navigation=0x08D4C53E;else if(gKeysRepeated&32)navigation=0x08D4C541;
        if(navigation) { PlayGameAudio(54);choice=ROM(navigation)[choice];DrawDuelContextMenu(choice);WaitForFrame();UploadDuelText();continue; }
        if(gKeysPressed&1) {
            if(choice==1) { PlayGameAudio(55);gPlayerTurnDone=1;RestoreDuelDisplay();return; }
            if(choice==0) {
                if(CanShowDuelCardMetadata(ROW,COL)==1 && ClassifyDuelCard(*Selected())) {
                    PlayGameAudio(55);SetCardPreviewModifiers(gTerrain,(int8_t)((uint8_t *)Selected())[2]);LoadCardWithPreviewStats(*Selected());
                    ShowCardDescription();ReloadDuelDisplay();return;
                }
                PlayGameAudio(57);
            }else if(choice==2) {
                if(ROW>=2 && *Selected()) { PlayGameAudio(62);DiscardAbsoluteDuelCell(Selected(),0); }else PlayGameAudio(57);
            }
            RestoreDuelDisplay();return;
        }
        if(gKeysPressed&2) { PlayGameAudio(56);RestoreDuelDisplay();return; }WaitForFrame();
    }
}
/*08027EB0*/
void CancelDuelSelection(void)
{
    if(!MODE) { PlayGameAudio(55);RunDuelContextMenu(); }
    else if(MODE==1 || MODE==2 || MODE==4) {
        PlayGameAudio(56);uint8_t previous=ROW;MODE=0;RestoreCursor();LoadSelectedDuelCardDetails();TransitionDuelViewport(previous,ROW);
    }
}
/*08024810*/
void RunPlayerDuelTurn(void)
{
    gPlayerTurnDone=0;RestoreDuelDisplay();ResetGameKeys();
    do {
        uint8_t previous=ROW,input=ReadPlayerDuelInput();
        if(input>=1 && input<=4) {
            PlayGameAudio(54);
            if(input==1) { if(!ROW)ROW=1;--ROW; }
            else if(input==2) { uint8_t next=ROW+1;if(next<=4)ROW=next; }
            else if(input==3) { if(!COL)COL=5;--COL; }
            else { ++COL;if(COL==5)COL=0; }
            LoadSelectedDuelCardDetails();TransitionDuelViewport(previous,ROW);
        }else switch(input) {
        case 5:ConfirmDuelSelection();break;
        case 6:ShowDuelStatsWhileHeld();WaitForFrame();UploadDuelText();break;
        case 7:ShowOpponentHand();ReloadDuelDisplay();break;
        case 8:CancelDuelSelection();break;
        case 9:gDuelAuxiliaryFlags[0]=2;break;
        case 10:gDuelAuxiliaryFlags[1]=2;break;
        default:WaitForFrame();break;
        }
    }while(DuelHasEnded()!=1 && gPlayerTurnDone!=1);
}
