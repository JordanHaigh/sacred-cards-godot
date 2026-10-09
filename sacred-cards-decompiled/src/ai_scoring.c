/* AY7E top-level before/after scoring callbacks. Unsigned arithmetic and exact
 * priority constants are preserved. Card-specific scorer tables remain separate
 * dependencies. Semantic C, not linked, execution-compared or matched. */
#include "ai.h"
extern uint8_t *gAiScratch;
extern uint16_t *gEffectBoardPointerWindow[]; /* raw pointer view at 02023270 */
extern uint8_t gAiSpellScoreIndex,gAiTrappedSpellScoreIndex,gAiMonsterScoreIndex; /* 0201CB34/38/3C */
extern void (*const gAiSpellBefore[])(void);    /* 08D34B80 */
extern void (*const gAiSpellAfter[])(void);     /* 08D34D88 */
extern void (*const gAiMonsterBefore[])(void);  /* 08D353A0 */
extern void (*const gAiMonsterAfter[])(void);   /* 08D35530 */
extern void SetCardPreviewModifiers(uint8_t,int32_t);
extern void LoadCardWithPreviewStats(uint16_t);
#define LOW_PRIORITY 0x7EE0ACE9u
static uint32_t Score(void)
{
    const uint8_t *p=gAiScratch+0x14F0;return p[0]|(uint32_t)p[1]<<8|(uint32_t)p[2]<<16|(uint32_t)p[3]<<24;
}
static void SetScore(uint32_t n)
{
    for (unsigned i=0;i<4;++i) gAiScratch[0x14F0+i]=(uint8_t)(n>>(i*8));
}
static uint16_t Meta16(unsigned at) { return gCardMetadataBytes[at]|(uint16_t)gCardMetadataBytes[at+1]<<8; }
static uint8_t Flags(uint16_t *c) { return ((uint8_t *)c)[4]; }
static void Preview(uint16_t *c)
{
    unsigned stage=((uint8_t *)c)[2];SetCardPreviewModifiers(gTerrain,stage<128?(int32_t)stage:(int32_t)stage-256);LoadCardWithPreviewStats(*c);
}
static uint16_t Attack(uint16_t *c) { Preview(c);return Meta16(0x12); }
static unsigned Count(uint16_t *const *row,uint16_t card)
{
    unsigned n=0;for (unsigned i=0;i<5;++i) n+=*row[i]==card;return n;
}
static unsigned Occupied(uint8_t row) { return 5-Count(gEffectBoardCells[row],0); }
static uint8_t Monster(uint16_t *c) { return *c && ClassifyDuelCard(*c)==1 && !(Flags(c)&1); }
/* 08016D30 (Exodia), 08023114 (Destiny Board/message sequence). */
static uint32_t ExodiaMask(uint16_t card) { return card>=17 && card<=21?1u<<(card-17):0; }
static uint32_t DestinyMask(uint16_t card) { return card>=583 && card<=587?1u<<(card-583):0; }
/* 080271C4 */
static uint32_t MonsterStatSum(uint8_t row)
{
    uint32_t sum=0;
    for (unsigned i=0;i<5;++i) if (ClassifyDuelCard(*gEffectBoardCells[row][i])==1) {
        Preview(gEffectBoardCells[row][i]);sum+=Meta16(0x12)+Meta16(0x14);
    }
    return sum;
}
/* 08009CA4 / 08009CC0 */
void AiScoreNoneBefore(void) { SetScore(0x7EE0ACEA); }
void AiScoreNoneAfter(void) {}
/* 08009CC4. Native duplicate count starts at the selected pointer, not row
 * start, and reads FIVE pointers from there. Preserve the raw alias explicitly. */
void AiScoreDiscardBefore(void)
{
    uint16_t card=*AiCell(0);LoadCardMetadata(card);
    if (gCardMetadataBytes[0x1A]!=2) { SetScore(0x7EE4F2AF);return; }
    switch (RemainingMonsterTributes(card)) {
    case 0:
        if (!ExodiaMask(card) || Count(gEffectBoardPointerWindow+AiRow(0)*5+AiColumn(0),card)>1) SetScore(0x7EE2CFCF);
        else SetScore(0x7EE0ACEE);
        break;
    case 1:SetScore(0x7EE4F2B4);break;
    case 2:SetScore(0x7EE71594);break;
    case 3:SetScore((uint16_t)(card-832)<3?0x7EE0ACEF:0x7EE93874);break;
    default:SetScore(LOW_PRIORITY);return;
    }
    Preview(AiCell(0));SetScore(Score()-Meta16(0x12)+0x1FFFCu-Meta16(0x14));
}
/* 08009E94 */ void AiScoreDiscardAfter(void) {}
/* 0800A050 and the replacement branches of 08009E98. */
static void ScoreSummonDestination(uint32_t empty_score,uint32_t upgrade_score)
{
    uint16_t *dst=AiCell(1);
    if (!*dst) SetScore(empty_score);
    else if (!(Flags(dst)&1)) {
        if (ClassifyDuelCard(*dst)==1) {
            uint16_t attack=Attack(AiCell(0));SetScore(Attack(dst)<attack?upgrade_score:LOW_PRIORITY);
        } else SetScore(empty_score);
    } else SetScore(LOW_PRIORITY);
}
/* 08009E98 */
void AiScoreSummonZeroBefore(void)
{
    if (!Monster(AiCell(0)) || RemainingMonsterTributes(*AiCell(0))!=0) { SetScore(LOW_PRIORITY);return; }
    uint16_t card=*AiCell(0);
    if (!ExodiaMask(card) || Count(gEffectBoardCells[AiRow(0)],card)>1) ScoreSummonDestination(0x7F3D9A26,0x7F32EBC6);
    else ScoreSummonDestination(0x7F1D8F06,0x7F12E0A6);
}
static void SummonAfter(void) { if (Score()!=LOW_PRIORITY) SetScore(Score()+MonsterStatSum(2)); }
/* 0800A178 */ void AiScoreSummonZeroAfter(void) { SummonAfter(); }
static void SummonBefore(unsigned tributes,uint32_t priority)
{
    if (!Monster(AiCell(0)) || RemainingMonsterTributes(*AiCell(0))!=tributes) { SetScore(LOW_PRIORITY);return; }
    /* Native three-tribute scorer omits the third material's Monster predicate. */
    for (unsigned i=1;i<=tributes && i<=2;++i) if (!Monster(AiCell(i))) { SetScore(LOW_PRIORITY);return; }
    uint16_t attack=Attack(AiCell(0));
    for (unsigned i=1;i<=tributes;++i) if (Attack(AiCell(i))>=attack) { SetScore(LOW_PRIORITY);return; }
    SetScore(priority);
}
/* 0800A1B0 */ void AiScoreSummonOneBefore(void) { SummonBefore(1,0x7F5DA546); }
/* 0800A2E0 */ void AiScoreSummonOneAfter(void) { SummonAfter(); }
/* 0800A318 */ void AiScoreSummonTwoBefore(void) { SummonBefore(2,0x7F7DB066); }
/* 0800A4C0 */ void AiScoreSummonTwoAfter(void) { SummonAfter(); }
/* 0800A4F8 */ void AiScoreSummonThreeBefore(void) { SummonBefore(3,0x7F7DB066); }
/* 0800A70C */ void AiScoreSummonThreeAfter(void) { SummonAfter(); }
/* 0800A744 */ void AiScoreDefenseBefore(void) { SetScore(0x7EE0ACEC); }
/* 0800A760 */ void AiScoreDefenseAfter(void) {}
/* 0800A764 */
void AiScorePositionBefore(void)
{
    Preview(AiCell(0));uint16_t attack=Meta16(0x12),defense=Meta16(0x14);
    if (!attack) { SetScore(0x7EE0ACEB);return; }
    if (!Occupied(1)) {
        if (attack<=defense) { SetScore(0x7EE0ACEB);return; }
    } else for (unsigned i=0;i<5;++i) if (*gEffectBoardCells[1][i]) {
        uint16_t *c=gEffectBoardCells[1][i];
        if (!(Flags(c)&0x10)) { SetScore(0x7EE0ACEB);return; }
        uint16_t opposing=Attack(c);
        if (attack<=opposing || opposing<=defense) { SetScore(0x7EE0ACEB);return; }
    }
    SetScore(0x7EE0ACED);
}
/* 0800A8D0 */ void AiScorePositionAfter(void) {}
/* 0800A8D4 */ void AiScoreDirectBefore(void) { uint16_t a=Attack(AiCell(0));SetScore(a?a+0x7EF1C400u:LOW_PRIORITY); }
/* 0800A95C */
void AiScoreDirectAfter(void)
{
    if (Score()!=LOW_PRIORITY && DuelHasEnded()==1) SetScore(gDuelAuxiliaryFlags[GetActingSide()]==2?0:0x7FFFFFFF);
}
/* 0800A9B8 */ void AiScoreAttackBefore(void) { Preview(AiCell(1));SetScore((uint32_t)Meta16(0x12)+Meta16(0x14)); }
/* 0800AA1C */
void AiScoreAttackAfter(void)
{
    if (DuelHasEnded()==1) { SetScore(gDuelAuxiliaryFlags[GetActingSide()]==2?0:0x7FFFFFFF);return; }
    if (!*AiCell(1)) {
        if (*AiCell(0)) { uint16_t attack=Attack(AiCell(0));SetScore(Score()-attack+0x7EF0A11Eu);return; }
        unsigned own=Occupied(AiRow(0)),opponent=Occupied(AiRow(1));
        if (own>opponent) { SetScore(Score()+0x7EEE8FB0u);return; }
    }
    SetScore(LOW_PRIORITY);
}
/* 0800AB54 */ void AiScoreHiddenBefore(void) { uint16_t a=Attack(AiCell(0));SetScore(a?a+0x7EED7E40u:LOW_PRIORITY); }
/* 0800ABDC */ void AiScoreHiddenAfter(void) {}
/* 0800ABE0 */ void AiScoreTrappedDirectBefore(void) { AiScoreDirectBefore(); }
/* 0800ABEC */ void AiScoreTrappedDirectAfter(void) { AiScoreDirectAfter(); }
/* 0800ABF8 */ void AiScoreTrappedAttackBefore(void) { AiScoreAttackBefore(); }
/* 0800AC04 */ void AiScoreTrappedAttackAfter(void) { AiScoreAttackAfter(); }
/* 0800AC10 */ void AiScoreTrappedHiddenBefore(void) { AiScoreHiddenBefore(); }
/* 0800AC1C */ void AiScoreTrappedHiddenAfter(void) { AiScoreHiddenAfter(); }
/* 0800AC28 */ void AiScoreSetTrapBefore(void) { SetScore(!*AiCell(1)?0x7EEB5B54:LOW_PRIORITY); }
/* 0800AC84 */ void AiScoreSetTrapAfter(void) {}
/* 0800AC88 */
void AiScoreSetPieceBefore(void)
{
    if (Count(gEffectBoardCells[3],*AiCell(0))) SetScore(LOW_PRIORITY);
    else if (!*AiCell(1)) SetScore(0x7EEB5B56);
    else SetScore(DestinyMask(*AiCell(1))?LOW_PRIORITY:0x7EEB5B55);
}
/* 0800AD4C, incorporating 080230E4. */
void AiScoreSetPieceAfter(void)
{
    uint32_t pieces=0;for (unsigned i=0;i<5;++i) pieces|=DestinyMask(*gEffectBoardCells[3][i]);
    if (pieces==31) SetScore(0x7FFFFFFF);
}
/* 0800AD74 */ void AiScoreSetEquipmentBefore(void) { SetScore(!*AiCell(1)?0x7FFFFFFC:LOW_PRIORITY); }
/* 0800ADD0 */ void AiScoreSetEquipmentAfter(void) {}
/* 0800ADD4 */ void AiScoreSetSpellBefore(void) { SetScore(!*AiCell(1)?0x7FFFFFFB:LOW_PRIORITY); }
/* 0800AE30 */ void AiScoreSetSpellAfter(void) {}
/* 0800AE34 */ void AiScoreSetRitualBefore(void) { SetScore(!*AiCell(1)?0x7FFFFFFA:LOW_PRIORITY); }
/* 0800AE90 */ void AiScoreSetRitualAfter(void) {}
/* 0800D078 / 0800D0C8 */
void AiScoreSpellBefore(void)
{
    LoadCardMetadata(*AiCell(0));gAiSpellScoreIndex=gCardMetadataBytes[0x1A];gAiSpellBefore[gAiSpellScoreIndex]();
}
void AiScoreSpellAfter(void) { gAiSpellAfter[gAiSpellScoreIndex](); }
/* 0800ED58 / 0800ED98. Keep both metadata loads and the otherwise-unused index. */
void AiScoreTrappedSpellBefore(void)
{
    LoadCardMetadata(*AiCell(0));gAiTrappedSpellScoreIndex=gCardMetadataBytes[0x1A];AiScoreSpellBefore();
}
void AiScoreTrappedSpellAfter(void) { AiScoreSpellAfter(); }
/* 080113EC / 0801143C */
void AiScoreMonsterBefore(void)
{
    LoadCardMetadata(*AiCell(0));gAiMonsterScoreIndex=gCardMetadataBytes[0x1B];gAiMonsterBefore[gAiMonsterScoreIndex]();
}
void AiScoreMonsterAfter(void) { gAiMonsterAfter[gAiMonsterScoreIndex](); }
void (*const gAiScoreBefore[25])(void)={
    AiScoreNoneBefore,AiScoreDiscardBefore,AiScoreSummonZeroBefore,AiScoreSummonOneBefore,AiScoreSummonTwoBefore,
    AiScoreDefenseBefore,AiScorePositionBefore,AiScoreDirectBefore,AiScoreAttackBefore,
    AiScoreTrappedDirectBefore,AiScoreTrappedAttackBefore,AiScoreSummonThreeBefore,AiScoreHiddenBefore,
    AiScoreTrappedHiddenBefore,AiScoreSetTrapBefore,AiScoreSetEquipmentBefore,AiScoreSpellBefore,
    AiScoreTrappedSpellBefore,AiScoreSetSpellBefore,AiScoreSpellBefore,AiScoreTrappedSpellBefore,
    AiScoreSetRitualBefore,AiScoreSpellBefore,AiScoreMonsterBefore,AiScoreSetPieceBefore
};
void (*const gAiScoreAfter[25])(void)={
    AiScoreNoneAfter,AiScoreDiscardAfter,AiScoreSummonZeroAfter,AiScoreSummonOneAfter,AiScoreSummonTwoAfter,
    AiScoreDefenseAfter,AiScorePositionAfter,AiScoreDirectAfter,AiScoreAttackAfter,
    AiScoreTrappedDirectAfter,AiScoreTrappedAttackAfter,AiScoreSummonThreeAfter,AiScoreHiddenAfter,
    AiScoreTrappedHiddenAfter,AiScoreSetTrapAfter,AiScoreSetEquipmentAfter,AiScoreSpellAfter,
    AiScoreTrappedSpellAfter,AiScoreSetSpellAfter,AiScoreSpellAfter,AiScoreTrappedSpellAfter,
    AiScoreSetRitualAfter,AiScoreSpellAfter,AiScoreMonsterAfter,AiScoreSetPieceAfter
};
