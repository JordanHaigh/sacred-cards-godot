/* All 25 AI validators, 08011774..08012358, and cell predicates. Native
 * action operands are prevalidated row/column nibbles. Preserve call order:
 * classification and trap search overwrite shared metadata/trigger state.
 * Semantic C, not linked, execution-compared or matched. */
#include "ai.h"
extern const int8_t gSpellTargetClasses[132]; /* 08D4BD60 */
static uint8_t Flags(uint16_t *c) { return ((uint8_t *)c)[4]; }
/* 08026D38 */
static uint8_t UnlockedMonster(uint16_t *c)
{
    return *c && ClassifyDuelCard(*c)==1 && !(Flags(c)&1);
}
/* 08026D60 */
static uint8_t HiddenMonsterEffect(uint16_t *c)
{
    if (!*c) return 0;LoadCardMetadata(*c);
    return gCardMetadataBytes[0x1B]!=0 && !(Flags(c)&1) && !(Flags(c)&0x10);
}
/* 08026D98 and 08026E00 */
static uint8_t CardClass(uint16_t *c,int32_t category) { return *c && ClassifyDuelCard(*c)==category; }
/* 08023C64 with 08026DB8/08026DDC. Empty cards are still classified. */
static uint8_t SpellClass(uint16_t *c,int32_t target_class)
{
    if (ClassifyDuelCard(*c)!=2) return 0;
    LoadCardMetadata(*c);return gSpellTargetClasses[gCardMetadataBytes[0x1A]]==target_class;
}
/* 08026E20 */
static uint8_t Occupied(uint8_t row)
{
    uint8_t count=0;for (unsigned i=0;i<5;++i) if (*gEffectBoardCells[row][i]) ++count;return count;
}
/* 08023114 */
static uint32_t SpecialPieceMask(uint16_t card) { return card>=583 && card<=587?1u<<(card-583):0; }
static uint8_t FindTrap(void)
{
    gTrapInput.row=AiRow(0);gTrapInput.column=AiColumn(0);gTrapInput.card=*AiCell(0);
    return FindActivatingTrap();
}
/* 08011774 */ uint8_t AiValidNone(void) { return 1; }
/* 08011778 */ uint8_t AiValidDiscard(void) { return Occupied(AiRow(0))>4 && *AiCell(0) && !(AiBytes(0)[4]&1); }
/* 080117C4 */
uint8_t AiValidSummonZero(void)
{
    if (!UnlockedMonster(AiCell(0)) || RemainingMonsterTributes(*AiCell(0))!=0) return 0;
    return !*AiCell(1) || !(AiBytes(1)[4]&1);
}
static uint8_t SummonTributes(uint8_t count)
{
    if (!UnlockedMonster(AiCell(0)) || RemainingMonsterTributes(*AiCell(0))!=count) return 0;
    for (unsigned i=1;i<=count;++i) if (!UnlockedMonster(AiCell(i))) return 0;
    return 1;
}
/* 0801184C */ uint8_t AiValidSummonOne(void) { return SummonTributes(1); }
/* 080118C0 */ uint8_t AiValidSummonTwo(void) { return SummonTributes(2); }
/* 08011964 */ uint8_t AiValidSummonThree(void) { return SummonTributes(3); }
/* 08011A34 */ uint8_t AiValidDefense(void) { return !(gDuelSideState[0][2]&4) && UnlockedMonster(AiCell(0)); }
/* 08011A88 */ uint8_t AiValidAttackPosition(void) { return UnlockedMonster(AiCell(0)); }
static uint8_t AttackValid(uint8_t trapped,uint8_t target_kind)
{
    /* 08018208 returns the raw side byte; any nonzero value passes. */
    if (!gDuelAuxiliaryFlags[GetActingSide()] || (gDuelSideState[0][2]&3)) return 0;
    uint8_t found=FindTrap();
    if ((found==1)!=trapped || !UnlockedMonster(AiCell(0))) return 0;
    if (target_kind==0) return Occupied(1)==0;
    if (!*AiCell(1) || ClassifyDuelCard(*AiCell(1))!=1) return 0;
    return ((AiBytes(1)[4]&0x10)!=0)==(target_kind==1);
}
/* 08011AC4 */ uint8_t AiValidDirectAttack(void) { return AttackValid(0,0); }
/* 08011B48 */ uint8_t AiValidMonsterAttack(void) { return AttackValid(0,1); }
/* 08011BFC */ uint8_t AiValidHiddenAttack(void) { return AttackValid(0,2); }
/* 08011CB0 */ uint8_t AiValidTrappedDirectAttack(void) { return AttackValid(1,0); }
/* 08011D34 */ uint8_t AiValidTrappedMonsterAttack(void) { return AttackValid(1,1); }
/* 08011DE8 */ uint8_t AiValidTrappedHiddenAttack(void) { return AttackValid(1,2); }
/* 08011E9C */ uint8_t AiValidMonsterEffect(void) { return HiddenMonsterEffect(AiCell(0)); }
/* 08011ED8 */ uint8_t AiValidSetTrap(void) { return CardClass(AiCell(0),3) && SpecialPieceMask(*AiCell(0))==0; }
/* 08011F20 */ uint8_t AiValidSetSpecialPiece(void) { return CardClass(AiCell(0),3) && SpecialPieceMask(*AiCell(0))>0; }
/* 08011F68 */ uint8_t AiValidSetEquipment(void) { return SpellClass(AiCell(0),1); }
static uint8_t TargetedSpellValid(uint8_t trapped)
{
    if (!SpellClass(AiCell(0),1) || !UnlockedMonster(AiCell(1))) return 0;
    return (FindTrap()==1)==trapped;
}
/* 08011FA4 */ uint8_t AiValidTargetedSpell(void) { return TargetedSpellValid(0); }
/* 08012030 */ uint8_t AiValidTrappedTargetedSpell(void) { return TargetedSpellValid(1); }
/* 080120BC */ uint8_t AiValidSetSpell(void) { return SpellClass(AiCell(0),0); }
static uint8_t SpellValid(uint8_t trapped)
{
    if (!SpellClass(AiCell(0),0)) return 0;return (FindTrap()==1)==trapped;
}
/* 080120F8 */ uint8_t AiValidSpell(void) { return SpellValid(0); }
/* 0801214C */ uint8_t AiValidTrappedSpell(void) { return SpellValid(1); }
/* 080121A0 */ uint8_t AiValidSetRitual(void) { return CardClass(AiCell(0),4); }
/* 08012324: require the first occurrence of material to equal operand-1 column. */
static uint8_t MaterialAtColumn(uint8_t column,const uint16_t recipe[4])
{
    return DuelRowContains(gEffectBoardCells[2],recipe[0])==1 && FindCardInDuelRow(gEffectBoardCells[2],recipe[0])==column;
}
/* 080121DC. Operand rows 1..3 are checked, but recipe matching uses row 2. */
uint8_t AiValidRitual(void)
{
    if (!CardClass(AiCell(0),4)) return 0;
    for (unsigned i=1;i<=3;++i) if (!UnlockedMonster(AiCell(i))) return 0;
    LoadCardMetadata(*AiCell(0));uint8_t recipe=gCardMetadataBytes[0x1D];
    if (recipe==5) {
        const uint8_t choices[4]={29,28,27,5};uint8_t slots[3];
        for (unsigned i=0;i<4;++i) if (FindThreeMaterials(slots,gRitualRecipes[choices[i]])==1) return 1;
        return 0;
    }
    if (recipe==24) return MaterialAtColumn(AiColumn(1),gRitualRecipes[26]) || MaterialAtColumn(AiColumn(1),gRitualRecipes[24]);
    return MaterialAtColumn(AiColumn(1),gRitualRecipes[recipe]);
}
uint8_t (*const gAiValidate[25])(void)={
    AiValidNone,AiValidDiscard,AiValidSummonZero,AiValidSummonOne,AiValidSummonTwo,
    AiValidDefense,AiValidAttackPosition,AiValidDirectAttack,AiValidMonsterAttack,
    AiValidTrappedDirectAttack,AiValidTrappedMonsterAttack,AiValidSummonThree,AiValidHiddenAttack,
    AiValidTrappedHiddenAttack,AiValidSetTrap,AiValidSetEquipment,AiValidTargetedSpell,
    AiValidTrappedTargetedSpell,AiValidSetSpell,AiValidSpell,AiValidTrappedSpell,AiValidSetRitual,
    AiValidRitual,AiValidMonsterEffect,AiValidSetSpecialPiece
};
