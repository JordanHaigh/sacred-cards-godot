/* AY7E metadata-1B monster handler bodies (Fairy's Gift is in card_effects.c).
 * Reconstructed from the native control flow and C drafts. Helpers with native
 * names remain dependencies. Semantic C, not linked, execution-compared or
 * compiler-matched. One-card presenters use zero for the unused second
 * argument; their fixed message domains contain no #3 substitution.
 */
#include "card_effects.h"
extern struct MonsterInput gMonsterInput;             /* 02023478 */
extern uint8_t gCardMetadataBytes[0x1E];
extern uint8_t *gDuelSideState[2];
extern uint16_t *gOpponentHandCells[5];
extern uint16_t gDuelLifePoints[2];
extern const uint16_t gGateGuardianMaterialPairs[3][2]; /* 080FB8F4 */
extern void LoadCardMetadata(uint32_t);
extern void SetCardPreviewModifiers(uint8_t,int32_t);
extern void LoadCardWithPreviewStats(uint16_t);
extern uint32_t IsEffectImmune(uint16_t);
extern uint32_t CountEmptyOrImmuneCells(uint16_t *const *);
extern void DrawDuelCard(uint8_t);
extern uint32_t RandomByteInclusive(uint32_t,uint32_t);
extern void RaiseCellStage(uint16_t *);
extern uint32_t LowerCellStageRegisterResult(uint16_t *);
extern uint8_t FindCardInDuelRow(uint16_t *const *,uint16_t);

static uint8_t *Bytes(uint16_t *cell) { return (uint8_t *)cell; }
static uint16_t *Selected(void) { return gEffectBoardCells[gMonsterInput.row][gMonsterInput.column]; }
static uint16_t Read16(const uint8_t *p) { return p[0]|(uint16_t)p[1]<<8; }
static unsigned Count(uint16_t *const row[5],uint16_t card)
{
    unsigned n=0;for (unsigned i=0;i<5;++i) n+=*row[i]==card;return n;
}
static void Lower(uint16_t *c) { (void)LowerCellStageRegisterResult(c); }
static void Clear(uint16_t *c) { *c=0;Bytes(c)[2]=Bytes(c)[3]=0;Bytes(c)[4]&=0xC0; }
/* 080246E8: copy the five meaningful bytes, preserving destination bits 6..7. */
void CopyDuelCell(uint16_t *dst,const uint16_t *src)
{
    const uint8_t *source=(const uint8_t *)src;
    *dst=*src;Bytes(dst)[2]=source[2];Bytes(dst)[3]=source[3];
    Bytes(dst)[4]=(Bytes(dst)[4]&0xC0)|(source[4]&0x3F);
}
static void Ready(uint16_t *c)
{
    Bytes(c)[4]=(Bytes(c)[4]|0x10)&0xD8;Bytes(c)[3]=0;
}
/* Fusion changes preserve byte 3; freshly summoned tokens clear it. */
static void FusionCard(uint16_t *c,uint16_t card)
{
    *c=card;Bytes(c)[4]=(Bytes(c)[4]|0x11)&0xF9;Bytes(c)[2]=0;Bytes(c)[4]&=0xDF;
}
static uint16_t Attack(uint16_t *c)
{
    unsigned stage=Bytes(c)[2];
    SetCardPreviewModifiers(gTerrain,stage<128?(int32_t)stage:(int32_t)stage-256);
    LoadCardWithPreviewStats(*c);return Read16(gCardMetadataBytes+0x12);
}
/* Native 08026AC4 / 08026B28 / 08026B98 / 08026C70 all prefer the last
 * equal-attack candidate; absent target returns zero, not a sentinel. */
static uint8_t Strongest(uint16_t *const row[5],unsigned filter,uint8_t type)
{
    uint16_t best=0;uint8_t slot=0;
    for (uint8_t i=0;i<5;++i) if (*row[i]) {
        if (filter==1 && IsEffectImmune(*row[i])!=0) continue;
        if (filter==2 && (Bytes(row[i])[4]&1)) continue;
        uint16_t attack=Attack(row[i]);
        if (filter==3 && gCardMetadataBytes[0x16]!=type) continue;
        if (attack>=best) { best=attack;slot=i; }
    }
    return slot;
}
static unsigned UnlockedCount(uint16_t *const row[5])
{
    unsigned n=0;for (unsigned i=0;i<5;++i) if (*row[i] && !(Bytes(row[i])[4]&1)) ++n;return n;
}
static void Show(uint16_t card,uint16_t sound)
{
    if (!gSuppressEffectPresentation) { PresentDuelEffect(card,0);PlayGameAudio(sound); }
}
static void ShowPair(uint16_t card,uint16_t target,uint16_t sound)
{
    if (!gSuppressEffectPresentation) { PresentDuelEffect(card,target);PlayGameAudio(sound); }
}
static void DamageOpponent(uint16_t amount)
{
    if (GetActingSide()==0) PrepareDamageSideB(amount);else PrepareDamageSideA(amount);
    ResolveCurrentBattleNumbers();ApplyBattleDefeatFlags();
}
static void HealSelf(uint16_t amount)
{
    if (GetActingSide()==0) PrepareHealSideA(amount);else PrepareHealSideB(amount);
    ResolveCurrentBattleNumbers();
}
static void BoostCard(uint16_t card,unsigned stages)
{
    for (unsigned i=0;i<5;++i) if (*gEffectBoardCells[2][i]==card)
        for (unsigned n=0;n<stages;++n) RaiseCellStage(gEffectBoardCells[2][i]);
}
static void LockRow(unsigned row)
{
    for (unsigned i=0;i<5;++i) if (*gEffectBoardCells[row][i]) Bytes(gEffectBoardCells[row][i])[4]|=1;
}
static void LowerOpponentRow(void)
{
    for (unsigned i=0;i<5;++i) if (*gEffectBoardCells[1][i]) Lower(gEffectBoardCells[1][i]);
}
static void TerrainEffect(uint8_t terrain,uint16_t card,uint8_t pair)
{
    gTerrain=terrain;
    if (!gSuppressEffectPresentation) {
        LoadDuelTerrain(terrain);
        if (pair) PresentDuelEffect(card,card);else PresentDuelEffect(card,0);
        PlayGameAudio(79);
    }
}
/* 08028614 */ void MonsterEffectNone(void) {}
/* 08028618 */
void MonsterReaperOfTheCards(void)
{
    if (Count(gEffectBoardCells[0],0)<5) for (unsigned i=0;i<5;++i) {
        LoadCardMetadata(*gEffectBoardCells[0][i]);
        if (gCardMetadataBytes[0x1C]) { DiscardDuelCell(gEffectBoardCells[0][i],1);break; }
    }
    ShowPair(84,84,89);
}
static void AbsorbOpponent(uint16_t card,unsigned stages)
{
    if (CountEmptyOrImmuneCells(gEffectBoardCells[1])!=5) {
        uint16_t *src=gEffectBoardCells[1][Strongest(gEffectBoardCells[1],1,0)];
        CopyDuelCell(Selected(),src);Ready(Selected());
        for (unsigned n=0;n<stages;++n) RaiseCellStage(Selected());
        Clear(src);
    }
    Show(card,85);
}
/* 080286C0 */ void MonsterRelinquished(void) { AbsorbOpponent(731,0); }
/* 080287C0 */ void MonsterThousandEyesRestrict(void) { AbsorbOpponent(734,2); }
/* 080288E8 */ void MonsterSkelengel(void) { DrawDuelCard(GetActingSide());Show(540,59); }
/* 08028914 */ void MonsterHarpieLady(void) { BoostCard(386,1);ShowPair(62,386,73); }
/* 08028960 */ void MonsterHarpieLadySisters(void) { BoostCard(386,2);ShowPair(63,386,73); }
/* 080289B0 */
void MonsterTimeWizard(void)
{
    for (unsigned i=0;i<5;++i) {
        uint16_t *c=gEffectBoardCells[2][i];
        if (*c==4) *c=69;if (*c==35) *c=888;if (*c==865) *c=888;
    }
    ShowPair(16,16,90);
}
/* 08028A14 */
void MonsterCastleOfDarkIllusions(void)
{
    gTerrain=6;
    for (unsigned i=0;i<5;++i) if (*gEffectBoardCells[2][i]) Bytes(gEffectBoardCells[2][i])[4]&=0xEF;
    for (unsigned i=0;i<5;++i) if (*gEffectBoardCells[2][i]==83) Bytes(gEffectBoardCells[2][i])[4]|=0x10;
    if (!gSuppressEffectPresentation) { LoadDuelTerrain(gTerrain);PresentDuelEffect(83,83);PlayGameAudio(79); }
}
/* 08028A9C */
void MonsterMysticalElf(void)
{
    for (unsigned i=0;i<5;++i) {
        if (*gEffectBoardCells[2][i]==1) RaiseCellStage(gEffectBoardCells[2][i]);
        if (*gEffectBoardCells[2][i]==887) RaiseCellStage(gEffectBoardCells[2][i]);
    }
    ShowPair(2,1,73);
}
/* 08028AF8 */ void MonsterCurseOfDragon(void) { TerrainEffect(2,39,1); }
/* 08028B2C */
void MonsterFlameSwordsman(void)
{
    for (unsigned i=0;i<5;++i) { LoadCardMetadata(*gEffectBoardCells[1][i]);if (gCardMetadataBytes[0x16]==11) DiscardDuelCell(gEffectBoardCells[1][i],1); }
    ShowPair(15,15,76);
}
/* 08028B80 */ void MonsterGiantSoldierOfStone(void) { TerrainEffect(0,74,1); }
/* 08028BB4 */
void MonsterBattleOx(void)
{
    for (unsigned i=0;i<5;++i) { LoadCardMetadata(*gEffectBoardCells[1][i]);if (gCardMetadataBytes[0x17]==5) DiscardDuelCell(gEffectBoardCells[1][i],1); }
    ShowPair(26,26,76);
}
/* 08028C08 */ void MonsterMonsterTamer(void) { BoostCard(375,1);ShowPair(376,375,73); }
/* 08028C58 */
void MonsterPumpking(void)
{
    for (unsigned i=0;i<5;++i) for (uint16_t id=96;id<=98;++id)
        if (*gEffectBoardCells[2][i]==id) RaiseCellStage(gEffectBoardCells[2][i]);
    ShowPair(99,99,73);
}
/* 08028CBC */ void MonsterMammothGraveyard(void) { LowerOpponentRow();ShowPair(59,59,74); }
/* 08028D04 */
void MonsterCatapultTurtle(void)
{
    uint16_t damage=0;
    for (unsigned i=0;i<5;++i) {
        uint16_t *c=gEffectBoardCells[2][i];
        if (i!=gMonsterInput.column && *c && !(Bytes(c)[4]&1)) {
            damage=(uint16_t)(damage+Attack(c));DiscardDuelCell(c,0);
        }
    }
    DamageOpponent(damage);ShowPair(89,89,69);
}
/* 08028DB8 */
void MonsterGoddessOfWhim(void)
{
    DrawDuelCard(GetActingSide());DiscardDuelCell(gEffectBoardCells[2][gMonsterInput.column],0);Show(429,59);
}
/* 08028E00 */ void MonsterSpiritOfTheMountain(void) { TerrainEffect(3,525,0); }
/* 08028E38 */
void MonsterDragonSeeker(void)
{
    for (unsigned i=0;i<5;++i) {
        LoadCardMetadata(*gEffectBoardCells[1][i]);
        if (IsEffectImmune(Read16(gCardMetadataBytes+0x10))==0 && gCardMetadataBytes[0x16]==1) DiscardDuelCell(gEffectBoardCells[1][i],1);
    }
    Show(500,76);
}
/* 08028E98 */
void MonsterTrapMaster(void)
{
    if (Count(gEffectBoardCells[3],0)) {
        uint16_t *c=gEffectBoardCells[3][FindCardInDuelRow(gEffectBoardCells[3],0)];
        *c=685;Bytes(c)[4]&=0xC8;Bytes(c)[3]=Bytes(c)[2]=0;
    }
    ShowPair(224,685,58);
}
/* 08028F28 */
void MonsterFiendsHand(void)
{
    if (CountEmptyOrImmuneCells(gEffectBoardCells[1])!=5) DiscardDuelCell(gEffectBoardCells[1][Strongest(gEffectBoardCells[1],1,0)],1);
    DiscardDuelCell(Selected(),0);ShowPair(135,135,76);
}
/* 08028F90 */ void MonsterIllusionistFacelessMage(void) { LockRow(1);ShowPair(42,42,80); }
/* 08028FD8 */
void MonsterElectricLizard(void)
{
    if (UnlockedCount(gEffectBoardCells[1])) Bytes(gEffectBoardCells[1][Strongest(gEffectBoardCells[1],2,0)])[4]|=1;
    Show(610,80);
}
static void MagicianGirl(uint16_t card)
{
    if (Read16(gDuelSideState[0])==35) RaiseCellStage(Selected());
    if (Read16(gDuelSideState[1])==35) RaiseCellStage(Selected());
    if (Read16(gDuelSideState[0])==865) RaiseCellStage(Selected());
    if (Read16(gDuelSideState[1])==865) RaiseCellStage(Selected());
    ShowPair(card,35,73);
}
/* 08029024 */ void MonsterDarkMagicianGirl(void) { MagicianGirl(760); }
/* 080290DC */
void MonsterWodan(void)
{
    for (unsigned i=0;i<5;++i) { LoadCardMetadata(*gEffectBoardCells[2][i]);if (gCardMetadataBytes[0x16]==20) RaiseCellStage(gEffectBoardCells[2][gMonsterInput.column]); }
    ShowPair(235,235,73);
}
/* 0802913C */ void MonsterMWarrior1(void) { BoostCard(161,1);ShowPair(160,161,73); }
/* 08029184 */ void MonsterMWarrior2(void) { BoostCard(160,1);ShowPair(161,160,73); }
/* 080291CC */
void MonsterRedArcheryGirl(void)
{
    if (UnlockedCount(gEffectBoardCells[1])) {
        uint16_t *c=gEffectBoardCells[1][Strongest(gEffectBoardCells[1],2,0)];Bytes(c)[4]|=1;Lower(c);
    }
    Show(725,74);
}
/* 08029220 */ void MonsterLadyOfFaith(void) { HealSelf(500);Show(612,78); }
/* 08029260 */ void MonsterFireReaper(void) { DamageOpponent(50);ShowPair(154,154,77); }
/* 080292A0 */ void MonsterKairyuShin(void) { TerrainEffect(5,73,1); }
/* 080292D4 */
void MonsterGyakutennoMegami(void)
{
    for (unsigned i=0;i<5;++i) if (*gEffectBoardCells[2][i] && Attack(gEffectBoardCells[2][i])<=500) RaiseCellStage(gEffectBoardCells[2][i]);
    ShowPair(90,90,73);
}
/* 08029350 */
void MonsterMonsterEye(void)
{
    for (unsigned i=0;i<5;++i) if (*gOpponentHandCells[i]) Bytes(gOpponentHandCells[i])[4]|=0x10;
    Show(402,60);
}
static void Duplicate(void)
{
    if (Count(gEffectBoardCells[2],0)) CopyDuelCell(gEffectBoardCells[2][FindCardInDuelRow(gEffectBoardCells[2],0)],Selected());
}
/* 0802939C */ void MonsterDoron(void) { Duplicate();ShowPair(195,195,58); }
/* 080293F8 */ void MonsterSwampBattleguard(void) { BoostCard(554,1);ShowPair(12,554,73); }
/* 08029444 */ void MonsterLavaBattleguard(void) { BoostCard(12,1);ShowPair(554,12,73); }
/* 08029490 */ void MonsterTrent(void) { TerrainEffect(1,637,0); }
/* 080294C8 */
void MonsterLabyrinthTank(void)
{
    for (unsigned i=0;i<5;++i) if (*gEffectBoardCells[2][i]==366) RaiseCellStage(Selected());
    ShowPair(370,366,73);
}
static void SummonToken(uint16_t card)
{
    if (Count(gEffectBoardCells[2],0)) {
        uint8_t slot=FindCardInDuelRow(gEffectBoardCells[2],0);
        uint16_t *c=gEffectBoardCells[gMonsterInput.row][slot];
        *c=card;Ready(c);Bytes(c)[2]=0;
    }
}
/* 08029530 */ void MonsterSpiritOfTheBooks(void) { SummonToken(486);ShowPair(117,486,58); }
/* 08029624 */
void MonsterHourglassOfLife(void)
{
    for (unsigned i=0;i<5;++i) if (*gEffectBoardCells[2][i]) RaiseCellStage(gEffectBoardCells[2][i]);
    if (GetActingSide()==0) PrepareDamageSideA(1000);else PrepareDamageSideB(1000);
    ResolveCurrentBattleNumbers();ApplyBattleDefeatFlags();ShowPair(229,229,73);
}
/* 0802968C */
void MonsterBeastkingOfTheSwamps(void)
{
    for (unsigned row=1;row<=2;++row) for (unsigned i=0;i<5;++i)
        if (IsEffectImmune(*gEffectBoardCells[row][i])!=1) DiscardDuelCell(gEffectBoardCells[row][i],(uint8_t)(2-row));
    Show(258,75);
}
/* 08029704 */ void MonsterNemuriko(void) { LockRow(1);LockRow(2);ShowPair(129,129,80); }
/* 08029774 */ void MonsterToadMaster(void) { SummonToken(549);ShowPair(140,549,58); }
static void AttributeStages(uint8_t lower,uint8_t raise)
{
    for (unsigned i=0;i<5;++i) {
        LoadCardMetadata(*gEffectBoardCells[2][i]);
        if (gCardMetadataBytes[0x17]==lower) Lower(gEffectBoardCells[2][i]);
        if (gCardMetadataBytes[0x17]==raise) RaiseCellStage(gEffectBoardCells[2][i]);
    }
}
/* 08029868 */ void MonsterHoshiningen(void) { AttributeStages(1,2);Show(492,73); }
/* 080298C8 */ void MonsterInvitationToADarkSleep(void) { LockRow(1);Show(740,80); }
/* 08029914 */ void MonsterWitchsApprentice(void) { AttributeStages(2,1);Show(628,73); }
/* 08029974 */ void MonsterMysticLamp(void) { DamageOpponent(Attack(Selected()));Show(387,69); }
/* 08029A0C */ void MonsterLeghul(void) { DamageOpponent(Attack(Selected()));Show(397,69); }
static void BoostForType(unsigned row,uint8_t type)
{
    for (unsigned i=0;i<5;++i) { LoadCardMetadata(*gEffectBoardCells[row][i]);if (gCardMetadataBytes[0x16]==type) RaiseCellStage(Selected()); }
}
/* 08029AA4 */ void MonsterInsectQueen(void) { BoostForType(2,10);BoostForType(1,10);Show(762,73); }
/* 08029B50 */
void MonsterObelisk(void)
{
    for (unsigned i=0;i<5;++i) DiscardDuelCell(gEffectBoardCells[1][i],1);
    DamageOpponent(4000);Show(832,86);
}
/* 08029BB8 */
void MonsterSlifer(void)
{
    for (unsigned i=0;i<5;++i) if (*gEffectBoardCells[4][i]) for (unsigned n=0;n<3;++n) RaiseCellStage(Selected());
    Show(833,87);
}
/* 08029C44 */
void MonsterRa(void)
{
    if (GetActingSide()==0) { PrepareDamageSideB((uint16_t)(gDuelLifePoints[0]-1));ResolveCurrentBattleNumbers();gDuelLifePoints[0]=1; }
    else { PrepareDamageSideA((uint16_t)(gDuelLifePoints[1]-1));ResolveCurrentBattleNumbers();gDuelLifePoints[1]=1; }
    ApplyBattleDefeatFlags();Show(834,88);
}
static void ClearMaterial(uint16_t card)
{
    Clear(gEffectBoardCells[gMonsterInput.row][FindCardInDuelRow(gEffectBoardCells[gMonsterInput.row],card)]);
}
/* 08029CA8: unreferenced metadata slot, retained as native behavior. */
void MonsterUnusedBlueEyesFusion(void)
{
    if (Count(gEffectBoardCells[2],1)>2) {
        Clear(Selected());FusionCard(Selected(),380);ClearMaterial(1);ClearMaterial(1);
    }
    ShowPair(1,380,83);
}
static unsigned GuardianPresent(void)
{
    return Count(gEffectBoardCells[2],371) && Count(gEffectBoardCells[2],372) && Count(gEffectBoardCells[2],373);
}
/* 08029DE8 */
void MonsterUnusedGateGuardianFusion(void)
{
    uint16_t old=*Selected();
    if (GuardianPresent()) {
        unsigned pair=old==371?0:old==372?1:2;
        Clear(Selected());FusionCard(Selected(),374);
        ClearMaterial(gGateGuardianMaterialPairs[pair][0]);ClearMaterial(gGateGuardianMaterialPairs[pair][1]);
    }
    ShowPair(old,374,83);
}
/* 08029FB8: the native unused routine checks Guardian pieces but removes two
 * Blue Eyes cards and presents Blue Eyes Ultimate. Preserve this discrepancy. */
void MonsterUnusedMixedFusion(void)
{
    if (GuardianPresent()) { Clear(Selected());FusionCard(Selected(),374);ClearMaterial(1);ClearMaterial(1); }
    ShowPair(1,380,83);
}
/* 0802A120 */ void MonsterUnusedNoEffect(void) {}
/* 0802A124 */ void MonsterCyberHarpie(void) { BoostCard(386,1);ShowPair(875,386,73); }
/* 0802A174 */ void MonsterToonDarkMagicianGirl(void) { MagicianGirl(872); }
static void MagnetFusion(uint16_t card,uint16_t first,uint16_t second)
{
    if (Count(gEffectBoardCells[2],first) && Count(gEffectBoardCells[2],second)) {
        FusionCard(Selected(),883);ClearMaterial(first);ClearMaterial(second);
    }
    ShowPair(card,883,83);
}
/* 0802A22C */ void MonsterAlphaMagnetWarrior(void) { MagnetFusion(738,757,850); }
/* 0802A374 */ void MonsterBetaMagnetWarrior(void) { MagnetFusion(757,738,850); }
/* 0802A4BC */ void MonsterGammaMagnetWarrior(void) { MagnetFusion(850,738,757); }
/* 0802A604 */
void MonsterValkyrion(void)
{
    if (Count(gEffectBoardCells[2],0)>1) {
        FusionCard(Selected(),738);
        FusionCard(gEffectBoardCells[gMonsterInput.row][FindCardInDuelRow(gEffectBoardCells[gMonsterInput.row],0)],757);
        FusionCard(gEffectBoardCells[gMonsterInput.row][FindCardInDuelRow(gEffectBoardCells[gMonsterInput.row],0)],850);
    }
    Show(883,83);
}
/* 0802A858 */
void MonsterBeastOfGilfer(void)
{
    if (Count(gEffectBoardCells[1],0)<5) LowerOpponentRow();
    DiscardDuelCell(Selected(),0);Show(778,74);
}
/* 0802A8D0: both native count predicates inspect the OPPONENT row. In
 * particular this does not add a missing friendly-empty-slot guard. */
void MonsterDarkNecrofear(void)
{
    if (CountEmptyOrImmuneCells(gEffectBoardCells[1])!=5 && Count(gEffectBoardCells[1],0)!=5) {
        uint16_t *src=gEffectBoardCells[1][Strongest(gEffectBoardCells[1],1,0)];
        uint16_t *dst=gEffectBoardCells[gMonsterInput.row][FindCardInDuelRow(gEffectBoardCells[2],0)];
        CopyDuelCell(dst,src);Ready(dst);Clear(src);
    }
    Show(812,85);
}
/* 0802A9E4 */
void MonsterZombyra(void)
{
    if (CountEmptyOrImmuneCells(gEffectBoardCells[1])!=5) { DiscardDuelCell(gEffectBoardCells[1][Strongest(gEffectBoardCells[1],1,0)],1);Lower(Selected()); }
    Show(858,75);
}
/* 0802AA4C: no draw call occurs in this native handler. */
void MonsterSharedSlot68(void) { (void)GetActingSide();Show(862,59); }
/* 0802AA74 */
void MonsterGilfordTheLightning(void)
{
    for (unsigned i=0;i<5;++i) if (IsEffectImmune(*gEffectBoardCells[1][i])==0) DiscardDuelCell(gEffectBoardCells[1][i],1);
    Show(873,75);
}
/* 0802AAC4 */
void MonsterSerket(void)
{
    if (CountEmptyOrImmuneCells(gEffectBoardCells[1])!=5) { Clear(gEffectBoardCells[1][Strongest(gEffectBoardCells[1],1,0)]);RaiseCellStage(Selected()); }
    Show(874,73);
}
/* 0802AB2C */
void MonsterJinzo(void)
{
    if (Count(gEffectBoardCells[0],0)!=5) for (unsigned i=0;i<5;++i) {
        LoadCardMetadata(*gEffectBoardCells[0][i]);if (gCardMetadataBytes[0x1C]) DiscardDuelCell(gEffectBoardCells[0][i],1);
    }
    Show(752,89);
}
/* 0802AB90 */
void MonsterBusterBlader(void)
{
    if (Count(gEffectBoardCells[1],0)!=5) BoostForType(1,1);Show(811,73);
}
/* 0802AC0C */
void MonsterBarrelDragon(void)
{
    for (unsigned n=0;n<3 && CountEmptyOrImmuneCells(gEffectBoardCells[1])!=5;++n)
        if (RandomByteInclusive(0,1)==1) DiscardDuelCell(gEffectBoardCells[1][Strongest(gEffectBoardCells[1],1,0)],1);
    Show(743,76);
}
/* 0802AC70 */
void MonsterReflectBounder(void)
{
    if (Count(gEffectBoardCells[1],0)!=5) DamageOpponent(Attack(gEffectBoardCells[1][Strongest(gEffectBoardCells[1],0,0)]));
    DiscardDuelCell(Selected(),0);Show(756,69);
}
/* 0802AD1C */
void MonsterParasiteParacide(void)
{
    if (CountEmptyOrImmuneCells(gEffectBoardCells[1])!=5) {
        uint16_t *dst=gEffectBoardCells[1][Strongest(gEffectBoardCells[1],1,0)];
        CopyDuelCell(dst,Selected());Ready(dst);Clear(Selected());
    }
    Show(763,74);
}
/* 0802ADD4 */ void MonsterSkullMarkLadyBug(void) { HealSelf(500);DiscardDuelCell(Selected(),0);Show(764,78); }
/* 0802AE38 */
void MonsterPinchHopper(void)
{
    DiscardDuelCell(Selected(),0);
    unsigned count=0;
    for (unsigned i=0;i<5;++i) if (*gEffectBoardCells[4][i]) {
        LoadCardMetadata(*gEffectBoardCells[4][i]);if (gCardMetadataBytes[0x16]==10) ++count;
    }
    if (count) {
        uint8_t slot=Strongest(gEffectBoardCells[4],3,10);
        if (slot!=5) { CopyDuelCell(Selected(),gEffectBoardCells[4][slot]);Ready(Selected());Clear(gEffectBoardCells[4][slot]); }
    }
    Show(766,58);
}
/* 0802AF54 */
void MonsterRocketWarrior(void)
{
    if (Count(gEffectBoardCells[1],0)<5) Lower(gEffectBoardCells[1][Strongest(gEffectBoardCells[1],0,0)]);Show(838,74);
}
/* 0802AF9C */ void MonsterRevivalJam(void) { Duplicate();Show(810,58); }
/* 0802B000 */ void MonsterMasterOfDragonSoldier(void) { BoostForType(2,1);Show(890,73); }
/* 0802B070 */ void MonsterLegendaryFiend(void) { RaiseCellStage(Selected());Show(878,73); }
/* 0802B0B4 */ void MonsterAncientLamp(void) { SummonToken(379);ShowPair(861,379,58); }
/* 0802B1AC */
void MonsterDesVolstgalph(void)
{
    if (CountEmptyOrImmuneCells(gEffectBoardCells[1])<5) DiscardDuelCell(gEffectBoardCells[1][Strongest(gEffectBoardCells[1],1,0)],1);
    DamageOpponent(500);Show(871,76);
}
/* 0802B218 */ void MonsterExarionUniverse(void) { DamageOpponent(Attack(Selected()));Lower(Selected());Show(877,69); }
