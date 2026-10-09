/* AY7E attack setup 08006518..08006A70 and board result application.
 * Raw records retain native untouched bytes and the unusual owner assignment
 * in 080066D0. Semantic C, not execution-compared or compiler-matched. */
#include "ai.h"
extern uint8_t gBattleCalculationBytes[0x1C],gBattleDisplayBytes[0x19];
extern uint16_t gDuelLifePoints[2];
extern void SetCardPreviewModifiers(uint8_t,int32_t);
extern void LoadCardWithPreviewStats(uint16_t);
extern void DiscardAbsoluteDuelCell(uint16_t *,uint8_t);
static uint16_t Read16(const uint8_t *p) { return p[0]|(uint16_t)p[1]<<8; }
static void Write16(uint8_t *p,uint16_t v) { p[0]=(uint8_t)v;p[1]=(uint8_t)(v>>8); }
static void LoadCombatant(unsigned side,uint8_t row,uint8_t column,uint8_t with_attribute)
{
    unsigned base=side*12;uint16_t *cell=gEffectBoardCells[row][column];
    Write16(gBattleCalculationBytes+base,*cell);
    unsigned stage=((uint8_t *)cell)[2];
    SetCardPreviewModifiers(gTerrain,stage<128?(int32_t)stage:(int32_t)stage-256);
    LoadCardWithPreviewStats(*cell);
    Write16(gBattleCalculationBytes+base+2,Read16(gCardMetadataBytes+0x12));
    Write16(gBattleCalculationBytes+base+4,Read16(gCardMetadataBytes+0x14));
    if (with_attribute) gBattleCalculationBytes[base+8]=gCardMetadataBytes[0x17];
}
static void InitialLife(unsigned side)
{
    Write16(gBattleCalculationBytes+side*12+6,gDuelLifePoints[side]);
    Write16(gBattleDisplayBytes+side*12+2,gDuelLifePoints[side]);
}
/* 08006518 selecting 08006544 / 080065CC. Direct paths do not set attributes. */
void PrepareDirectAttack(uint8_t column)
{
    uint8_t side=GetActingSide();if (side>1) return;
    gBattleCalculationBytes[0x18]=side?6:4;
    LoadCombatant(side,2,column,0);InitialLife(0);InitialLife(1);
    gBattleCalculationBytes[side*12+10]=column;gBattleCalculationBytes[side*12+9]=2;
    gBattleCalculationBytes[0x1A]=0;gBattleCalculationBytes[0x1B]=1;
}
/* 08006654 dispatches 080066D0 / 080067B8 / 080068A0 / 08006988. */
void PrepareMonsterAttack(uint8_t attacker,uint8_t target)
{
    uint8_t side=GetActingSide();if (side>1) return;
    uint8_t defense=((uint8_t *)gEffectBoardCells[1][target])[4]&2;
    gBattleCalculationBytes[0x18]=defense?(side?5:2):1;
    LoadCombatant(side,2,attacker,1);InitialLife(side);
    gBattleCalculationBytes[side*12+9]=2;
    if (!side && !defense) gBattleCalculationBytes[0x1B]=0;
    else gBattleCalculationBytes[0x1A+side]=side;
    /* Source column is set after the target card ID, before its preview load
     * in the native body; neither metadata loader touches calculation bytes. */
    gBattleCalculationBytes[side*12+10]=attacker;
    LoadCombatant(1-side,1,target,1);InitialLife(1-side);
    gBattleCalculationBytes[(1-side)*12+10]=target;
    gBattleCalculationBytes[(1-side)*12+9]=1;
    if (!side && !defense) gBattleCalculationBytes[0x1A]=1;
    else gBattleCalculationBytes[0x1A+(1-side)]=1-side;
}
/* 0802359C: destruction uses fixed absolute grave owners, not calculation
 * owner fields. This distinction also preserves 080066D0's anomalous indices. */
void ApplyBattleDestruction(void)
{
    if (gBattleCalculationBytes[0x19]&1)
        DiscardAbsoluteDuelCell(gEffectBoardCells[gBattleCalculationBytes[9]][gBattleCalculationBytes[10]],0);
    if (gBattleCalculationBytes[0x19]&2)
        DiscardAbsoluteDuelCell(gEffectBoardCells[gBattleCalculationBytes[0x15]][gBattleCalculationBytes[0x16]],1);
    ApplyBattleDefeatFlags();
}
/* 08023C8C: preserve byte padding at offsets 0B and 17. */
void ClearBattleDisplay(void)
{
    for (unsigned side=0;side<2;++side) for (unsigned i=0;i<11;++i) gBattleDisplayBytes[side*12+i]=0;
    gBattleDisplayBytes[0x18]=0;
}
/* 08018218 */
uint8_t DuelHasEnded(void) { return gDuelAuxiliaryFlags[0]==2 || gDuelAuxiliaryFlags[1]==2; }
