/* Shared effect-state operations recovered from AY7E. Semantic C, not matched
 * or execution-compared. Relative side pointers are established elsewhere. */
#include "card_effects.h"
extern uint8_t *gDuelSideState[2];           /* relative pointers at 02023260 */
extern uint8_t gAbsoluteDuelSideState[2][4]; /* physical records at 02023254 */
extern uint8_t gActingSide;                 /* 020237D8 */
extern const uint16_t gEffectImmuneCards[]; /* 08D36678, zero terminated */
extern int32_t ClassifyDuelCard(uint16_t);
static uint16_t Read16(const uint8_t *p) { return p[0]|(uint16_t)p[1]<<8; }
static void Write16(uint8_t *p,uint16_t v) { p[0]=(uint8_t)v;p[1]=(uint8_t)(v>>8); }
/*08018D68: test the terminator before the first comparison too.*/
uint32_t IsEffectImmune(uint16_t card)
{
    uint8_t i=0;
    while (gEffectImmuneCards[i]) {
        if (gEffectImmuneCards[i]==card) return 1;
        ++i;
    }
    return 0;
}
/* 08023FD4 */
void ClearDuelCell(uint16_t *cell)
{
    uint8_t *bytes=(uint8_t *)cell;*cell=0;bytes[2]=bytes[3]=0;bytes[4]&=0xC0;
}
/* 0802832C: only category-one monsters replace the remembered grave card.
 * Classifying also updates global card metadata, except for card zero. */
void RememberGraveCard(uint8_t *side,uint16_t card)
{
    if (ClassifyDuelCard(card)==1) Write16(side,card);
}
/* 08028308 */
void DiscardDuelCell(uint16_t *cell,uint8_t side)
{
    RememberGraveCard(gDuelSideState[side],*cell);ClearDuelCell(cell);
}
/* 080282E4 uses the absolute record, unlike DiscardDuelCell. */
void DiscardAbsoluteDuelCell(uint16_t *cell,uint8_t side)
{
    RememberGraveCard(gAbsoluteDuelSideState[side],*cell);ClearDuelCell(cell);
}
/* 08028348 and 08028360 intentionally use distinct physical/relative views. */
uint16_t TakeAbsoluteGraveCard(uint8_t side)
{
    uint16_t card=Read16(gAbsoluteDuelSideState[side]);Write16(gAbsoluteDuelSideState[side],0);return card;
}
uint16_t TakeRelativeGraveCard(uint8_t side)
{
    uint16_t card=Read16(gDuelSideState[side]);Write16(gDuelSideState[side],0);return card;
}
/*08026950: immunity substitutes card zero BEFORE comparison with the requested
 * card. The native entry accepts any card ID; it is not just an empty counter.
 * Return is sign-extended from the byte counter (the five-cell result is0..5).*/
int8_t CountDuelCardOrImmuneWindow(uint16_t *const *window,uint16_t wanted)
{
    uint8_t count=0;
    for (unsigned i=0;i<5;++i) {
        uint16_t card=*window[i];if (IsEffectImmune(card)==1) card=0;
        if (card==wanted) ++count;
    }
    return (int8_t)count;
}
/*0802690C: the active empty-or-immune wrapper supplies card zero.*/
uint32_t CountEmptyOrImmuneCells(uint16_t *const row[5])
{ return CountDuelCardOrImmuneWindow(row,0); }
/* 0803691C */ uint8_t GetActingSide(void) { return gActingSide; }

/*080242A0: clear attack lock only for occupied relative cells, all five rows.*/
void ClearOccupiedCellAttackLocks(void)
{ for(unsigned row=0;row<5;++row)for(unsigned col=0;col<5;++col) { uint16_t *p=gEffectBoardCells[row][col];if(*p)((uint8_t *)p)[4]&=0xFE; } }
/*0802432C/2441C/24450 use physical row records, not relative pointers.*/
extern uint8_t gDuelStateBytes[252];
extern const uint16_t gDuelBitMasks[8];
void SetPhysicalDuelCard(uint8_t column,uint8_t row,uint16_t card)
{ Write16(gDuelStateBytes+(row*5+column)*8,card); }
void SetPhysicalDuelCellBit(uint8_t column,uint8_t row,uint8_t bit)
{ gDuelStateBytes[(row*5+column)*8+3]|=gDuelBitMasks[bit]; }
void ClearPhysicalDuelCellBit(uint8_t column,uint8_t row,uint8_t bit)
{ gDuelStateBytes[(row*5+column)*8+3]&=~gDuelBitMasks[bit]; }
/*080243F8: repeat the saturating signed-stage decrement.*/
void LowerDuelCellStageBy(uint16_t *cell,uint8_t count)
{ uint8_t *p=(uint8_t *)cell;while(count--)if((int8_t)p[2]>-128)--p[2]; }
/*08026EA4/27174: additional row occupancy predicates.*/
uint8_t CountFaceDownDuelCells(uint8_t row)
{ uint8_t n=0;for(unsigned col=0;col<5;++col) { uint16_t *p=gEffectBoardCells[row][col];if(*p && !(((uint8_t *)p)[4]&16))++n; }return n; }
uint8_t CountFaceUpLockedDuelCells(uint8_t row)
{ uint8_t n=0;for(unsigned col=0;col<5;++col) { uint16_t *p=gEffectBoardCells[row][col];if(*p && (((uint8_t *)p)[4]&17)==17)++n; }return n; }

/*080268FC/0802691C: these accept a window of five pointers, which need not
 * start at a row boundary (the discard scorer deliberately uses a window).*/
int8_t CountDuelCardInWindow(uint16_t *const *window,uint16_t card)
{ uint8_t n=0;for(unsigned i=0;i<5;++i)n+=*window[i]==card;return (int8_t)n; }
int8_t CountEmptyDuelWindow(uint16_t *const *window)
{ return CountDuelCardInWindow(window,0); }
/*080269A0*/
int8_t CountUnusedDuelWindow(uint16_t *const *window)
{ uint8_t n=0;for(unsigned i=0;i<5;++i)n+=*window[i] && !(((uint8_t *)window[i])[4]&1);return (int8_t)n; }
/*08026A40 receives the LAST pointer, then walks backwards. The no-match
 * result is zero, unlike the last-monster selector's result of four.*/
int8_t FindLastEmptyDuelWindow(uint16_t *const *last)
{ for(int i=4;i>=0;--i,--last)if(!**last)return i;return 0; }
/*08026C04: ties choose the last occupied face-up card, including zero ATK.*/
extern uint8_t gCardMetadataBytes[0x1E];
extern void SetCardPreviewModifiers(uint8_t,int32_t),LoadCardWithPreviewStats(uint16_t);
int8_t FindStrongestFaceUpDuelWindow(uint16_t *const *window)
{
    uint16_t best=0;int8_t result=0;
    for(unsigned i=0;i<5;++i) {
        uint8_t *cell=(uint8_t *)window[i];if(!*window[i] || !(cell[4]&16))continue;
        SetCardPreviewModifiers(gTerrain,(int8_t)cell[2]);LoadCardWithPreviewStats(*window[i]);
        uint16_t attack=Read16(gCardMetadataBytes+0x12);
        if(attack>=best) { best=attack;result=i; }
    }return result;
}
/*080243A0/080243D4, including saturation at signed stage127.*/
void ResetDuelCellStage(uint16_t *cell) { ((uint8_t *)cell)[2]=0; }
void RaiseDuelCellStageBy(uint16_t *cell,uint8_t count)
{ uint8_t *p=(uint8_t *)cell;while(count--)if((int8_t)p[2]<127)++p[2]; }
/*0802457C*/
void ClearDuelSideSummonFlag(uint8_t side) { gDuelSideState[side][2]&=0xF7; }
/*08024744/08024758: preserve the same partial-field copy as CopyDuelCell.*/
extern uint16_t gDuelSelectionCopy[4];
extern void CopyDuelCell(uint16_t *,const uint16_t *);
void SaveDuelSelectionCell(uint16_t *cell) { CopyDuelCell(gDuelSelectionCopy,cell); }
void RestoreDuelSelectionCell(uint16_t *cell) { CopyDuelCell(cell,gDuelSelectionCopy); }
/*080368F8*/
void ResetActingSide(void) { gActingSide=0; }
/* Physical-board counterparts, unused by the active relative-board paths.*/
uint16_t GetPhysicalDuelCard(uint8_t column,uint8_t row)
{ return Read16(gDuelStateBytes+(row*5+column)*8); } /*08024350*/
void TogglePhysicalDuelDefense(uint8_t column,uint8_t row)
{ gDuelStateBytes[(row*5+column)*8+4]^=2; } /*0802436C*/
void ClearPhysicalDuelCellBits(uint8_t column,uint8_t row)
{ gDuelStateBytes[(row*5+column)*8+3]=0; } /*08024484*/
void SetPhysicalDuelAttackRestriction(uint8_t side)
{ gAbsoluteDuelSideState[side][2]|=3; } /*080244A4*/
void StepPhysicalDuelAttackRestriction(uint8_t side)
{ uint8_t *p=&gAbsoluteDuelSideState[side][2];if(*p&3)*p=(*p&0xFC)|((*p-1)&3); } /*080244BC*/
void SetPhysicalDuelSummonFlag(uint8_t side)
{ gAbsoluteDuelSideState[side][2]|=8; } /*08024530*/
void ClearPhysicalDuelSummonFlag(uint8_t side)
{ gAbsoluteDuelSideState[side][2]&=0xF7; } /*08024560*/
