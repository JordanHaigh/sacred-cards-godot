/* AY7E trap engine, 08035AFC..080368F0. All 20 validator and activation
 * cases, including seven empty cases, are represented. Metadata-1C must be
 * 0..19, as in the ROM's 901 card records. Native invalid-category behavior
 * returns caller register residue and is outside this semantic API's domain.
 * Not linked, execution-compared, or compiler-matched.
 */
#include "card_effects.h"
extern uint8_t gCardMetadataBytes[0x1E];
extern void LoadCardMetadata(uint32_t);
extern int32_t ClassifyDuelCard(uint16_t);
extern void SetCardPreviewModifiers(uint8_t,int32_t);
extern void LoadCardWithPreviewStats(uint16_t);
extern uint32_t IsEffectImmune(uint16_t);
extern void PresentImmuneTrap(uint16_t,uint16_t);
extern uint32_t LowerCellStageRegisterResult(uint16_t *);
extern const uint16_t gTrapDamageSpellIndices[];   /* 08D5113C, FFFF terminated */
extern const uint16_t gTrapHealingSpellIndices[];  /* 08D51148 */
extern const uint16_t gTrapEquipmentSpellIndices[];/* 08D51154 */
extern const uint16_t gTrapRaigekiSpellIndices[];  /* 08D51198 */
static uint8_t *Bytes(uint16_t *c) { return (uint8_t *)c; }
static uint16_t *Trigger(void) { return gEffectBoardCells[gTrapInput.row][gTrapInput.column]; }
static uint16_t *Trap(void) { return gEffectBoardCells[0][gTrapInput.slot]; }
static uint8_t Accept(uint8_t kind) { gTrapInput.kind=kind;return 1; }
/* 08035D2C, 08036100, 08036124, 08036148. */
static uint8_t TriggerIsMonster(uint8_t kind)
{
    return ClassifyDuelCard(gTrapInput.card)==1?Accept(kind):0;
}
/* 08035D50 / DC4 / E38 / EAC / F20: thresholds inclusive. */
static uint8_t TriggerAttackAtMost(uint8_t kind,uint16_t maximum)
{
    if (ClassifyDuelCard(gTrapInput.card)!=1) return 0;
    unsigned stage=Bytes(Trigger())[2];
    SetCardPreviewModifiers(gTerrain,stage<128?(int32_t)stage:(int32_t)stage-256);
    LoadCardWithPreviewStats(*Trigger());
    uint16_t attack=gCardMetadataBytes[0x12]|(uint16_t)gCardMetadataBytes[0x13]<<8;
    return attack<=maximum?Accept(kind):0;
}
/* 08035F94 / FF0 / 0803604C / A4: compare metadata-1A, not card IDs. */
static uint8_t TriggerSpellInList(uint8_t kind,const uint16_t *list,uint8_t classify)
{
    if (classify && ClassifyDuelCard(gTrapInput.card)!=2) return 0;
    LoadCardMetadata(gTrapInput.card);
    do {
        if (*list==gCardMetadataBytes[0x1A]) return Accept(kind);
    } while (*++list!=0xFFFF);
    return 0;
}
/* 08035C30. The dispatcher saves the trap's kind before helpers load the
 * trigger card and overwrite global metadata. */
uint8_t CanActivateTrap(uint16_t card)
{
    LoadCardMetadata(card);
    switch (gCardMetadataBytes[0x1C]) {
    case 1:return TriggerIsMonster(1);
    case 2:return TriggerAttackAtMost(2,500);
    case 3:return TriggerAttackAtMost(3,1000);
    case 4:return TriggerAttackAtMost(4,1500);
    case 5:return TriggerAttackAtMost(5,2000);
    case 6:return TriggerAttackAtMost(6,3000);
    case 7:return TriggerSpellInList(7,gTrapDamageSpellIndices,1);
    case 8:return TriggerSpellInList(8,gTrapHealingSpellIndices,1);
    case 9:return TriggerSpellInList(9,gTrapEquipmentSpellIndices,0);
    case 11:return TriggerSpellInList(11,gTrapRaigekiSpellIndices,1);
    case 12:return TriggerIsMonster(12);
    case 13:return TriggerIsMonster(13);
    case 14:return TriggerIsMonster(14);
    /* Native 08035D28, 080360A0, 0803616C/170/174/178/17C return zero. */
    default:return 0;
    }
}
/* 08035BEC: priority is the first matching slot, left to right. On failure
 * kind remains zero, slot remains four, and metadata retains the last load. */
uint8_t FindActivatingTrap(void)
{
    gTrapInput.kind=0;
    for (uint8_t i=0;i<5;++i) {
        gTrapInput.slot=i;
        if (CanActivateTrap(*gEffectBoardCells[0][i])==1) return 1;
    }
    return 0;
}
static void PresentPair(uint16_t card,uint16_t other,uint16_t sound)
{
    if (!gSuppressEffectPresentation) { PlayGameAudio(66);PresentDuelEffect(card,other);PlayGameAudio(sound); }
}
static void Present(uint16_t card,uint16_t sound)
{
    if (!gSuppressEffectPresentation) { PlayGameAudio(66);PresentDuelEffect(card,0);PlayGameAudio(sound); }
}
/* 08036188, 08036238, 080362E8, 08036398, 08036448, 080364F4. The trap
 * is consumed even against immune monsters; immunity then reveals the target. */
static void DestroyTrigger(uint16_t card)
{
    DiscardDuelCell(Trap(),1);
    if (IsEffectImmune(*Trigger())==0) {
        DiscardDuelCell(Trigger(),0);PresentPair(card,gTrapInput.card,76);
    } else {
        Bytes(Trigger())[4]|=0x10;
        if (!gSuppressEffectPresentation) { PlayGameAudio(66);PresentImmuneTrap(card,gTrapInput.card); }
    }
}
/* 080365A4, 08036624. Both reflected damage and inverted healing select
 * damage to the currently acting side, then consume trap and trigger. */
static void ReflectLifePoints(uint16_t card,uint16_t amount)
{
    if (GetActingSide()==0) PrepareDamageSideA(amount);else PrepareDamageSideB(amount);
    ResolveCurrentBattleNumbers();ApplyBattleDefeatFlags();
    DiscardDuelCell(Trap(),1);DiscardDuelCell(Trigger(),0);
    PresentPair(card,gTrapInput.card,77);
}
static void DestroyActingMonsters(void)
{
    for (unsigned i=0;i<5;++i) if (IsEffectImmune(*gEffectBoardCells[2][i])==0) DiscardDuelCell(gEffectBoardCells[2][i],0);
}
/* 08035AFC, including all activation routines through 080368F0. */
void ActivateSelectedTrap(uint16_t amount)
{
    switch (gTrapInput.kind) {
    case 1:DestroyTrigger(686);break;
    case 2:DestroyTrigger(681);break;
    case 3:DestroyTrigger(682);break;
    case 4:DestroyTrigger(683);break;
    case 5:DestroyTrigger(684);break;
    case 6:DestroyTrigger(685);break;
    case 7:ReflectLifePoints(687,amount);break;
    case 8:ReflectLifePoints(688,amount);break;
    case 9: /* 080366A0 Reverse Trap */
        DiscardDuelCell(Trap(),1);DiscardDuelCell(Trigger(),0);
        PresentPair(689,gTrapInput.card,74);break;
    case 11: /* 08036700 Anti Raigeki */
        DestroyActingMonsters();DiscardDuelCell(Trap(),1);DiscardDuelCell(Trigger(),0);
        Present(782,75);break;
    case 12: /* 08036784 Infinite Dismissal: fixed row 2, irrespective of input.row. */
        Bytes(gEffectBoardCells[2][gTrapInput.column])[4]|=0x11;
        DiscardDuelCell(Trap(),1);PresentPair(899,*gEffectBoardCells[2][gTrapInput.column],80);break;
    case 13: /* 080367F8 Torrential Tribute */
        DestroyActingMonsters();DiscardDuelCell(Trap(),1);Present(897,75);break;
    case 14: /* 08036868 Amazon Archers */
        (void)LowerCellStageRegisterResult(gEffectBoardCells[2][gTrapInput.column]);
        Bytes(gEffectBoardCells[2][gTrapInput.column])[4]|=0x11;
        DiscardDuelCell(Trap(),1);PresentPair(870,gTrapInput.card,74);break;
    /* 08036184, 080366FC, 080368E0/E4/E8/EC/F0 are immediate returns. */
    default:break;
    }
}
