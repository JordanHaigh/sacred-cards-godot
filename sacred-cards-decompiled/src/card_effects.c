/* AY7E reviewed semantic reconstructions of 17 handler bodies. External native
 * shared calls use the recovered duel, metadata, battle and presentation modules.
 * Not linked, execution-compared, or compiler-matched. See docs/card_effects.md.
 */
#include <stdint.h>

#include "card_effects.h"

static uint16_t *SelectedSpellCell(void)
{
    return gEffectBoardCells[gSpellInput.row][gSpellInput.column];
}

/* Six native routines share this exact flow, differing only in constants. */
static void FieldSpell(uint8_t terrain, uint16_t card)
{
    gTerrain = terrain;
    DiscardDuelCell(SelectedSpellCell(), 0);
    if (gSuppressEffectPresentation == 0) {
        LoadDuelTerrain(gTerrain);
        PlayGameAudio(65);
        PresentDuelEffect(card,0);
        PlayGameAudio(79);
    }
}
void EffectForest(void)    { FieldSpell(1, 330); } /* 0802B378 */
void EffectWasteland(void) { FieldSpell(2, 331); } /* 0802B3D8 */
void EffectMountain(void)  { FieldSpell(3, 332); } /* 0802B438 */
void EffectSogen(void)     { FieldSpell(4, 333); } /* 0802B498 */
void EffectUmi(void)       { FieldSpell(5, 334); } /* 0802B4F8 */
void EffectYami(void)      { FieldSpell(6, 335); } /* 0802B558 */

/* Healing and direct-damage spells preserve the trap check even when
 * presentation is suppressed. A positive trap result only redirects execution
 * when presentation is enabled; it is not an unconditional early return.
 */
static void LifePointSpell(uint16_t amount, uint16_t card, uint8_t damage)
{
    gTrapInput.row = gSpellInput.row;
    gTrapInput.column = gSpellInput.column;
    gTrapInput.card = *SelectedSpellCell();
    uint8_t trap = FindActivatingTrap();
    if (trap == 1 && gSuppressEffectPresentation == 0) {
        ActivateSelectedTrap(amount);
        return;
    }
    uint8_t side = GetActingSide();
    if (damage) {
        if (side == 0) PrepareDamageSideB(amount);
        else PrepareDamageSideA(amount);
    } else {
        if (side == 0) PrepareHealSideA(amount);
        else PrepareHealSideB(amount);
    }
    ResolveCurrentBattleNumbers();
    ApplyBattleDefeatFlags();
    DiscardDuelCell(SelectedSpellCell(), 0);
    if (gSuppressEffectPresentation == 0) {
        PlayGameAudio(65);
        PresentDuelEffect(card,0);
        PlayGameAudio(damage ? 77 : 78);
    }
}
void EffectMooyanCurry(void)  { LifePointSpell(200, 338, 0); }  /* 0802B5B8 */
void EffectRedMedicine(void)  { LifePointSpell(500, 339, 0); }  /* 0802B66C */
void EffectGoblinsRemedy(void){ LifePointSpell(1000, 340, 0); } /* 0802B72C */
void EffectSoulOfThePure(void){ LifePointSpell(2000, 341, 0); } /* 0802B7E8 */
void EffectDianKeto(void)     { LifePointSpell(5000, 342, 0); } /* 0802B8A8 */
void EffectSparks(void)       { LifePointSpell(50, 343, 1); }   /* 0802B968 */
void EffectHinotama(void)     { LifePointSpell(100, 344, 1); }  /* 0802BA1C */
void EffectFinalFlame(void)   { LifePointSpell(200, 345, 1); }  /* 0802BAD0 */
void EffectOokazi(void)       { LifePointSpell(500, 346, 1); }  /* 0802BB84 */

/* 0802867C: monster effect has neither the spell trap check nor cell removal. */
void EffectFairysGift(void)
{
    if (GetActingSide() == 0) PrepareHealSideA(1000);
    else PrepareHealSideB(1000);
    ResolveCurrentBattleNumbers();
    if (gSuppressEffectPresentation == 0) {
        PresentDuelEffect(363,0);
        PlayGameAudio(78);
    }
}
/* 0802BC40 */
void EffectTremendousFire(void) { LifePointSpell(1000,347,1); }
