/* Remaining metadata-1A spell-handler bodies. Native addresses are recorded
 * beside each entry. Semantic C retains game-specific behavior, including
 * asymmetrical immunity checks and effects that consume a spell on failure.
 * Helpers/rendering remain dependencies; not matched or execution-compared.
 */
#include "card_effects.h"
extern uint8_t gCardMetadataBytes[0x1E];
extern uint8_t *gDuelSideState[2];                  /* 02023260 */
extern uint16_t *gPlayerHandCells[5],*gOpponentHandCells[5]; /* 02023350/364 */
extern const uint16_t gRitualRecipes[30][4];         /* 08D36328 */
extern void LoadCardMetadata(uint32_t);
extern uint32_t IsEffectImmune(uint16_t);          /* immune card list */
extern void SetCardPreviewModifiers(uint8_t,int32_t);
extern void LoadCardWithPreviewStats(uint16_t);
extern void SetDuelAttackRestriction(uint8_t);
extern void DrawDuelCard(uint8_t);
extern uint32_t CountEmptyOrImmuneCells(uint16_t *const *);
extern uint16_t TakeRelativeGraveCard(uint8_t);
extern uint16_t TakeAbsoluteGraveCard(uint8_t);
extern uint32_t DuelRowContains(uint16_t *const *,uint16_t);
extern uint8_t FindCardInDuelRow(uint16_t *const *,uint16_t);
extern void ReplaceDuelCellCard(uint16_t *,uint16_t);
extern uint32_t LowerCellStageRegisterResult(uint16_t *);
extern void ResetTributesCommitted(void);
static uint8_t *Bytes(uint16_t *c) { return (uint8_t *)c; }
static uint16_t *Target(void) { return gEffectBoardCells[gSpellInput.row][gSpellInput.column]; }
static uint16_t *Source(void) { return gEffectBoardCells[gSpellInput.source_row][gSpellInput.source_column]; }
static uint16_t Meta16(unsigned at) { return gCardMetadataBytes[at]|(uint16_t)gCardMetadataBytes[at+1]<<8; }
static int32_t Stage(uint16_t *c) { unsigned n=Bytes(c)[2];return n<128?(int32_t)n:(int32_t)n-256; }
static void Present(uint16_t card,uint16_t sound)
{
    if (!gSuppressEffectPresentation) { PlayGameAudio(65);PresentDuelEffect(card,0);PlayGameAudio(sound); }
}
static void ConsumeAndPresent(uint16_t card,uint16_t sound)
{
    DiscardDuelCell(Target(),0);Present(card,sound);
}
static void ClearCell(uint16_t *cell) /* 08023FD4 */
{
    *cell=0;Bytes(cell)[2]=0;Bytes(cell)[3]=0;Bytes(cell)[4]&=0xC0;
}
static void ClearUnprotectedRow(unsigned row,unsigned side)
{
    for (unsigned i=0;i<5;++i)
        if (IsEffectImmune(*gEffectBoardCells[row][i])==0)
            DiscardDuelCell(gEffectBoardCells[row][i],(uint8_t)side);
}
/* 0802BD00 */
void EffectDarkHole(void)
{
    ClearUnprotectedRow(1,1);ClearUnprotectedRow(2,0);ConsumeAndPresent(336,75);
}
/* 0802BDA0. The trap arm leaves R0=0 after reading the presentation byte. */
void EffectRaigeki(void)
{
    gTrapInput.row=gSpellInput.row;gTrapInput.column=gSpellInput.column;gTrapInput.card=*Target();
    uint8_t trap=FindActivatingTrap();
    if (trap==1 && !gSuppressEffectPresentation) { ActivateSelectedTrap(0);return; }
    ClearUnprotectedRow(1,1);ConsumeAndPresent(337,75);
}
/* 0802D4B0 */
void EffectStopDefense(void)
{
    gDuelSideState[1][2]|=4;
    for (unsigned i=0;i<5;++i) if (*gEffectBoardCells[1][i]) {
        Bytes(gEffectBoardCells[1][i])[4]&=0xFD;
        Bytes(gEffectBoardCells[1][i])[4]|=0x10;
    }
    ConsumeAndPresent(320,60);
}
/* 0802D54C: metadata load precedes immunity check, unlike Warrior Elimination. */
void EffectDragonCaptureJar(void)
{
    for (unsigned i=0;i<5;++i) {
        LoadCardMetadata(*gEffectBoardCells[1][i]);
        if (IsEffectImmune(Meta16(0x10))==0 && gCardMetadataBytes[0x16]==1)
            DiscardDuelCell(gEffectBoardCells[1][i],1);
    }
    ConsumeAndPresent(329,76);
}
static void RevealRow(uint16_t *const row[5])
{
    for (unsigned i=0;i<5;++i) if (*row[i]) Bytes(row[i])[4]|=0x10;
}
/* 0802D5D4 */
void EffectSwordsOfRevealingLight(void) { SetDuelAttackRestriction(1);RevealRow(gEffectBoardCells[1]);ConsumeAndPresent(348,80); }
/* 0802D648 */
void EffectDarkPiercingLight(void) { RevealRow(gEffectBoardCells[1]);ConsumeAndPresent(350,60); }
/* 0802D6B8 */
void EffectSpellbindingCircle(void)
{
    for (unsigned i=0;i<5;++i) if (*gEffectBoardCells[1][i]) (void)LowerCellStageRegisterResult(gEffectBoardCells[1][i]);
    ConsumeAndPresent(349,74);
}
/* 0802E3A0 */
void EffectShadowSpell(void)
{
    for (unsigned i=0;i<5;++i) if (*gEffectBoardCells[1][i]) {
        (void)LowerCellStageRegisterResult(gEffectBoardCells[1][i]);
        (void)LowerCellStageRegisterResult(gEffectBoardCells[1][i]);
    }
    ConsumeAndPresent(669,74);
}
/* 0802D728: two independent checks, not an else-if. */
void EffectElegantEgotist(void)
{
    const uint16_t materials[2]={62,875};
    for (unsigned i=0;i<2;++i) if (*Target()==materials[i]) {
        *Target()=63;DiscardDuelCell(Source(),0);
        if (!gSuppressEffectPresentation) { PlayGameAudio(65);PresentDuelEffect(318,materials[i]);PlayGameAudio(90); }
    }
}
/* 0802ED3C: each replacement changes only the ID; preserve stages/flags. */
void EffectMetalmorph(void)
{
    const uint16_t materials[3]={391,82,885},results[3]={392,742,884};
    for (unsigned i=0;i<3;++i) if (*Target()==materials[i]) {
        *Target()=results[i];DiscardDuelCell(Source(),0);Present(658,90);
    }
}
/* 0802DF18 */
void EffectHarpiesFeatherDuster(void)
{
    for (unsigned i=0;i<5;++i) DiscardDuelCell(gEffectBoardCells[0][i],1);
    ConsumeAndPresent(672,89);
}
/* 0802E2EC */
void EffectCrushCard(void)
{
    for (unsigned i=0;i<5;++i) {
        uint16_t *c=gEffectBoardCells[1][i];
        if (*c && IsEffectImmune(*c)!=1) {
            SetCardPreviewModifiers(gTerrain,Stage(c));LoadCardWithPreviewStats(*c);
            if (Meta16(0x12)>1499) DiscardDuelCell(c,1);
        }
    }
    ConsumeAndPresent(661,76);
}
/* Type sweep variants deliberately distinguish whether immunity is checked. */
static void EliminateType(uint8_t type,uint16_t spell,uint8_t check_immunity)
{
    for (unsigned i=0;i<5;++i) {
        uint16_t *c=gEffectBoardCells[1][i];
        if (check_immunity && IsEffectImmune(*c)==1) continue;
        LoadCardMetadata(*c);
        if (gCardMetadataBytes[0x16]==type) DiscardDuelCell(c,1);
    }
    ConsumeAndPresent(spell,76);
}
/* 0802EAE0 */ void EffectWarriorElimination(void) { EliminateType(4,653,1); }
/* 0802EBE4 */ void EffectEternalRest(void) { EliminateType(3,656,0); }
/* 0802EF2C */ void EffectStainStorm(void) { EliminateType(15,660,1); }
/* 0802EFB4 */ void EffectEradicatingAerosol(void) { EliminateType(10,662,0); }
/* 0802F034 */ void EffectBreathOfLight(void) { EliminateType(19,663,0); }
/* 0802F0B4 */ void EffectEternalDrought(void) { EliminateType(13,664,0); }
/* 0802F340 */ void EffectLastDayOfWitch(void) { EliminateType(2,787,0); }
/* 0802F3C0 */ void EffectExileOfTheWicked(void) { EliminateType(8,786,0); }
/* 0802EB6C */
void EffectCursebreaker(void)
{
    for (unsigned i=0;i<5;++i) if (*gEffectBoardCells[2][i] && Stage(gEffectBoardCells[2][i])<0)
        Bytes(gEffectBoardCells[2][i])[2]=0;
    ConsumeAndPresent(655,73);
}
/* 0802F130 */ void EffectInexperiencedSpy(void) { RevealRow(gOpponentHandCells);ConsumeAndPresent(790,60); }
/* 0802F264 */
void EffectPotOfGreed(void)
{
    DrawDuelCard(GetActingSide());DrawDuelCard(GetActingSide());ConsumeAndPresent(789,59);
}
static unsigned CountInRow(uint16_t *const row[5],uint16_t card)
{
    unsigned n=0;for (unsigned i=0;i<5;++i) n+=*row[i]==card;return n;
}
/* 0802F2C0 */
void EffectRestructerRevolution(void)
{
    uint16_t damage=(uint16_t)((5-CountInRow(gOpponentHandCells,0))*200);
    if (GetActingSide()==0) PrepareDamageSideB(damage);else PrepareDamageSideA(damage);
    ResolveCurrentBattleNumbers();ApplyBattleDefeatFlags();ConsumeAndPresent(788,77);
}
/* 0802F440 */
void EffectMultiply(void)
{
    if (CountInRow(gEffectBoardCells[2],58)) for (unsigned i=0;i<5;++i) {
        uint16_t *c=gEffectBoardCells[2][i];
        if (*c==0) {
            *c=58;Bytes(c)[4]|=0x11;Bytes(c)[4]&=0xF9;
            Bytes(c)[3]=0;Bytes(c)[2]=0;Bytes(c)[4]&=0xDF;
        } else if (*c==58) { Bytes(c)[4]|=0x11;Bytes(c)[4]&=0xFD; }
    }
    ConsumeAndPresent(785,83);
}
static uint8_t FirstEmpty(uint16_t *const row[5])
{
    for (uint8_t i=0;i<5;++i) if (!*row[i]) return i;return 0;
}
/* 08026B28 chooses the LAST strongest nonimmune monster on ties. */
static uint8_t StrongestVulnerable(uint16_t *const row[5])
{
    uint16_t best=0;uint8_t result=0;
    for (uint8_t i=0;i<5;++i) if (*row[i] && IsEffectImmune(*row[i])==0) {
        SetCardPreviewModifiers(gTerrain,Stage(row[i]));LoadCardWithPreviewStats(*row[i]);
        if (Meta16(0x12)>=best) { best=Meta16(0x12);result=i; }
    }
    return result;
}
static void TakeControl(uint16_t spell,uint8_t temporary)
{
    if (CountInRow(gEffectBoardCells[2],0) && CountEmptyOrImmuneCells(gEffectBoardCells[1])!=5) {
        uint8_t dst=FirstEmpty(gEffectBoardCells[2]),src=StrongestVulnerable(gEffectBoardCells[1]);
        uint16_t *d=gEffectBoardCells[2][dst],*s=gEffectBoardCells[1][src];
        *d=*s;Bytes(d)[4]|=0x10;Bytes(d)[4]&=0xFC;
        Bytes(d)[4]=(Bytes(d)[4]&0xFB)|(Bytes(s)[4]&4);
        Bytes(d)[3]=2;Bytes(d)[2]=Bytes(s)[2];
        if (temporary) Bytes(d)[4]|=0x20;else Bytes(d)[4]&=0xDF;
        ClearCell(s);
    }
    ConsumeAndPresent(spell,85);
}
/* 0802F534 */ void EffectChangeOfHeart(void) { TakeControl(784,0); }
/* 0802F6A8 */ void EffectBrainControl(void) { TakeControl(781,1); }
/* 0802F78C */
void EffectMonsterReborn(void)
{
    if (CountInRow(gEffectBoardCells[2],0)) {
        uint8_t slot=FirstEmpty(gEffectBoardCells[2]);uint16_t card=TakeRelativeGraveCard(1);
        if (card) {
            uint16_t *c=gEffectBoardCells[2][slot];*c=card;
            Bytes(c)[4]|=0x10;Bytes(c)[4]&=0xF8;Bytes(c)[3]=2;Bytes(c)[2]=0;Bytes(c)[4]&=0xDF;
        }
    }
    ConsumeAndPresent(895,84);
}
/* 0802F930 */
void EffectBeckonToDarkness(void)
{
    if (CountEmptyOrImmuneCells(gEffectBoardCells[1])!=5)
        DiscardDuelCell(gEffectBoardCells[1][StrongestVulnerable(gEffectBoardCells[1])],1);
    ConsumeAndPresent(898,76);
}
/* 0802F9A4 */ void EffectGravediggerGhoul(void) { TakeAbsoluteGraveCard(0);TakeAbsoluteGraveCard(1);ConsumeAndPresent(896,76); }
static void ClearBothFields(void)
{
    for (unsigned row=0;row<4;++row) ClearUnprotectedRow(row,row<2?1:0);
}
/* 0802F9F8 */ void EffectHeavyStorm(void) { ClearBothFields();Present(894,75); }
/* 0802FAAC */
void EffectFinalDestiny(void)
{
    ClearBothFields();
    for (unsigned i=0;i<5;++i) {
        if (IsEffectImmune(*gPlayerHandCells[i])==0) DiscardDuelCell(gPlayerHandCells[i],0);
        if (IsEffectImmune(*gOpponentHandCells[i])==0) DiscardDuelCell(gOpponentHandCells[i],1);
    }
    Present(893,75);
}
/* 0802FBA8 */
void EffectMessengerOfPeace(void)
{
    for (unsigned i=0;i<5;++i) {
        uint16_t *c=gEffectBoardCells[1][i];
        if (*c) {
            SetCardPreviewModifiers(gTerrain,Stage(c));LoadCardWithPreviewStats(*c);
            if (Meta16(0x12)>1499) Bytes(c)[4]|=1;
        }
    }
    ConsumeAndPresent(891,80);
}
/* 0802FC54 */
void EffectDarknessApproaches(void)
{
    for (unsigned i=0;i<5;++i) if (*gEffectBoardCells[2][i]) Bytes(gEffectBoardCells[2][i])[4]&=0xEF;
    ConsumeAndPresent(892,60);
}
/* 0802DB10: greedy, distinct-slot search; preserve partial output on failure. */
uint8_t FindThreeMaterials(uint8_t slots[3],const uint16_t recipe[4])
{
    const unsigned columns[3]={0,2,3};
    for (unsigned part=0;part<3;++part) {
        unsigned slot;
        for (slot=0;slot<5;++slot) {
            if ((part>0 && slot==slots[0]) || (part>1 && slot==slots[1])) continue;
            if (*gEffectBoardCells[2][slot]==recipe[columns[part]]) break;
        }
        if (slot==5) return 0;
        slots[part]=(uint8_t)slot;
    }
    return 1;
}
/* 0802DA24 */
void EffectUltimateDragon(void)
{
    const unsigned choices[4]={29,28,27,5};uint8_t slots[3];unsigned choice;
    for (choice=0;choice<4;++choice) if (FindThreeMaterials(slots,gRitualRecipes[choices[choice]])==1) break;
    if (choice==4) return;
    uint16_t result=gRitualRecipes[choices[choice]][1];
    DiscardDuelCell(Target(),0);ReplaceDuelCellCard(gEffectBoardCells[2][slots[0]],result);
    ClearCell(gEffectBoardCells[2][slots[1]]);ClearCell(gEffectBoardCells[2][slots[2]]);ResetTributesCommitted();
    if (!gSuppressEffectPresentation) { PlayGameAudio(65);PresentDuelEffect(675,result);PlayGameAudio(83); }
}
/* 0802EA00 */
void EffectGateGuardianRitual(void)
{
    if (DuelRowContains(gEffectBoardCells[2],371)!=1 || DuelRowContains(gEffectBoardCells[2],372)!=1 || DuelRowContains(gEffectBoardCells[2],373)!=1) return;
    uint8_t slot=FindCardInDuelRow(gEffectBoardCells[2],371);
    DiscardDuelCell(Target(),0);ReplaceDuelCellCard(gEffectBoardCells[2][slot],374);
    ClearCell(gEffectBoardCells[2][FindCardInDuelRow(gEffectBoardCells[2],372)]);
    ClearCell(gEffectBoardCells[2][FindCardInDuelRow(gEffectBoardCells[2],373)]);ResetTributesCommitted();
    if (!gSuppressEffectPresentation) { PlayGameAudio(65);PresentDuelEffect(667,374);PlayGameAudio(83); }
}
/* 0802F1A4 */
void EffectDarkMagicRitual(void)
{
    unsigned recipe;
    if (DuelRowContains(gEffectBoardCells[2],865)==1) recipe=26;
    else if (DuelRowContains(gEffectBoardCells[2],35)==1) recipe=24;
    else return;
    uint8_t slot=FindCardInDuelRow(gEffectBoardCells[2],gRitualRecipes[recipe][0]);
    uint16_t result=gRitualRecipes[recipe][1];
    DiscardDuelCell(Target(),0);ReplaceDuelCellCard(gEffectBoardCells[2][slot],result);ResetTributesCommitted();
    if (!gSuppressEffectPresentation) { PlayGameAudio(65);PresentDuelEffect(722,result);PlayGameAudio(83); }
}
