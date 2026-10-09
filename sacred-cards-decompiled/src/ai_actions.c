/* All 25 distinct native action callbacks shared by the simulation/execution
 * tables at 08D349EC/08D34A50. Address-specific wrappers retain the table map.
 * Semantic reconstruction, not linked, execution-compared or matched. */
#include "ai.h"
extern void DispatchMetadata1aHandler(void);
extern void DispatchMetadata1bHandler(void);
static void AttackPose(void) { AiBytes(0)[4]=(AiBytes(0)[4]&0xFD)|0x11; }
static void SetTrapTrigger(void)
{
    gTrapInput.row=AiRow(0);gTrapInput.column=AiColumn(0);gTrapInput.card=*AiCell(0);
}
static void MoveCard(void)
{
    uint8_t source=gAiAction.cells[0],dest=gAiAction.cells[1];
    CopyDuelCell(gEffectBoardCells[dest>>4][dest&15],gEffectBoardCells[source>>4][source&15]);
    ClearDuelCell(gEffectBoardCells[source>>4][source&15]);
}
/* 0802421C: classify each nonempty card before locking it. */
void LockMonsterRow(uint8_t row)
{
    for (unsigned i=0;i<5;++i) if (*gEffectBoardCells[row][i] && ClassifyDuelCard(*gEffectBoardCells[row][i])==1)
        ((uint8_t *)gEffectBoardCells[row][i])[4]|=1;
}
static void Summon(unsigned tributes)
{
    /* Native 2/3-tribute paths discard in reverse operand order. */
    for (unsigned i=tributes;i>0;--i) DiscardDuelCell(AiCell(i),0);
    MoveCard();gDuelSideState[0][2]|=8; /* 08024548 */
    LockMonsterRow(4);
}
/* 08009248 */ void AiActionNone(void) {}
/* 08009250 */ void AiActionDiscard(void) { DiscardDuelCell(AiCell(0),0); }
/* 0800927C */ void AiActionSummonZero(void) { Summon(0); }
/* 080092D0 */ void AiActionSummonOne(void) { Summon(1); }
/* 08009338 */ void AiActionSummonTwo(void) { Summon(2); }
/* 080093C8 */ void AiActionSummonThree(void) { Summon(3); }
/* 08009474 */ void AiActionDefense(void) { AiBytes(0)[4]|=3; }
/* 080094A8 */ void AiActionAttackPosition(void) { AttackPose(); }
/* 080094E8: R0 retains the first operand's COLUMN at the setup call. */
void AiActionDirectAttack(void)
{
    uint8_t column=AiColumn(0);AttackPose();PrepareDirectAttack(column);
    ResolveCurrentBattleNumbers();ApplyBattleDestruction();
}
/* 0800953C: R0/R1 retain attacker/target columns despite omitted draft args. */
void AiActionMonsterAttack(void)
{
    uint8_t attacker=AiColumn(0),target=AiColumn(1);
    AttackPose();AiBytes(1)[4]|=0x10;
    PrepareMonsterAttack(attacker,target);ResolveCurrentBattleNumbers();ApplyBattleDestruction();
}
/* 080095B4 */ void AiActionHiddenMonsterAttack(void) { AiActionMonsterAttack(); }
/* 080095C0 / 08009620: FindActivatingTrap's return remains in R0 and is
 * passed to activation as its amount. Do not invent a zero argument. */
static void TrappedAttack(void)
{
    AttackPose();SetTrapTrigger();uint8_t found=FindActivatingTrap();ActivateSelectedTrap(found);
}
/* 080095C0 */ void AiActionTrappedDirectAttack(void) { TrappedAttack(); }
/* 08009620 */ void AiActionTrappedMonsterAttack(void) { TrappedAttack(); }
/* 08009680 */ void AiActionTrappedHiddenAttack(void) { AiActionTrappedMonsterAttack(); }
/* 0800968C */
void AiActionMonsterEffect(void)
{
    AttackPose();gMonsterInput.row=AiRow(0);gMonsterInput.card=*AiCell(0);gMonsterInput.column=AiColumn(0);
    DispatchMetadata1bHandler();if (gDuelSideState[0][2]&8) LockMonsterRow(4);
}
/* 08009700 */ void AiActionSetTrap(void) { MoveCard(); }
/* 08009748 */ void AiActionSetSpecialPiece(void) { MoveCard(); }
/* 08009790 */ void AiActionSetEquipment(void) { MoveCard(); }
static void TargetedSpell(void)
{
    uint8_t source=gAiAction.cells[0];
    gSpellInput.source_row=source>>4;gSpellInput.source_column=source&15;
    gSpellInput.row=AiRow(1);gSpellInput.column=AiColumn(1);
    gSpellInput.card=*gEffectBoardCells[source>>4][source&15];
    DispatchMetadata1aHandler();ClearDuelCell(gEffectBoardCells[source>>4][source&15]);
}
/* 080097D8 */ void AiActionTargetedSpell(void) { TargetedSpell(); }
/* 08009824 */ void AiActionTrappedTargetedSpell(void) { TargetedSpell(); }
/* 08009870 */ void AiActionSetSpell(void) { MoveCard(); }
static void UntargetedSpell(uint8_t lock_hand)
{
    uint8_t source=gAiAction.cells[0];
    gSpellInput.row=source>>4;gSpellInput.column=source&15;
    gSpellInput.card=*gEffectBoardCells[source>>4][source&15];
    DispatchMetadata1aHandler();
    if (lock_hand && (gDuelSideState[0][2]&8)) LockMonsterRow(4);
    ClearDuelCell(gEffectBoardCells[source>>4][source&15]);
}
/* 080098B8 */ void AiActionSpell(void) { UntargetedSpell(1); }
/* 08009910 */ void AiActionTrappedSpell(void) { UntargetedSpell(0); }
/* 08009950 */ void AiActionSetRitual(void) { MoveCard(); }
/* 08009998: only requirement==2 consumes operands 2 and 3 here. */
void AiActionRitual(void)
{
    uint8_t source=gAiAction.cells[0];
    if (CardCategoryRequirement(*AiCell(0))==2) { DiscardDuelCell(AiCell(2),0);DiscardDuelCell(AiCell(3),0); }
    gSpellInput.card=*gEffectBoardCells[source>>4][source&15];
    gSpellInput.row=source>>4;gSpellInput.column=source&15;
    DispatchMetadata1aHandler();ClearDuelCell(gEffectBoardCells[source>>4][source&15]);
}
void (*const gAiSimulate[25])(void)={
    AiActionNone,AiActionDiscard,AiActionSummonZero,AiActionSummonOne,AiActionSummonTwo,
    AiActionDefense,AiActionAttackPosition,AiActionDirectAttack,AiActionMonsterAttack,
    AiActionDirectAttack,AiActionMonsterAttack,AiActionSummonThree,AiActionHiddenMonsterAttack,
    AiActionHiddenMonsterAttack,AiActionSetTrap,AiActionSetEquipment,AiActionTargetedSpell,
    AiActionTargetedSpell,AiActionSetSpell,AiActionSpell,AiActionSpell,AiActionSetRitual,
    AiActionRitual,AiActionMonsterEffect,AiActionSetSpecialPiece
};
void (*const gAiExecute[25])(void)={
    AiActionNone,AiActionDiscard,AiActionSummonZero,AiActionSummonOne,AiActionSummonTwo,
    AiActionDefense,AiActionAttackPosition,AiActionDirectAttack,AiActionMonsterAttack,
    AiActionTrappedDirectAttack,AiActionTrappedMonsterAttack,AiActionSummonThree,AiActionHiddenMonsterAttack,
    AiActionTrappedHiddenAttack,AiActionSetTrap,AiActionSetEquipment,AiActionTargetedSpell,
    AiActionTrappedTargetedSpell,AiActionSetSpell,AiActionSpell,AiActionTrappedSpell,AiActionSetRitual,
    AiActionRitual,AiActionMonsterEffect,AiActionSetSpecialPiece
};
