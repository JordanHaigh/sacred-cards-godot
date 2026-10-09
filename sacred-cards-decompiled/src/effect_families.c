/* Reviewed equipment and single-material ritual families. Native entries and
 * constants follow below. The shared control flow was recovered from assembly
 * and drafts; these are semantic functions, not matched or execution-compared.
 */
#include "card_effects.h"
extern const uint8_t gEquipmentCompatibility[33][113]; /* ROM 08175804 */
extern const uint16_t gDuelBitMasks[8];               /* ROM 08D4BCFC */
extern void ResetTributesCommitted(void);

/* 08033DD8, with 33 fixed-mask wrappers at 08033E00..08034180.
 * Valid card ID (0..900) and equipment index (0..32) are preconditions.
 */
uint8_t EquipmentAcceptsCard(uint8_t equipment, uint16_t card)
{
    return (gEquipmentCompatibility[equipment][card >> 3] & gDuelBitMasks[card & 7]) != 0;
}
/* 08026CE4 and 08026D0C. Native Find returns zero even when absent; callers
 * requiring presence perform the separate predicate first.
 */
uint32_t DuelRowContains(uint16_t *const row[5], uint16_t card)
{
    for (unsigned i=0; i<5; ++i) if (*row[i] == card) return 1;
    return 0;
}
uint8_t FindCardInDuelRow(uint16_t *const row[5], uint16_t card)
{
    for (uint8_t i=0; i<5; ++i) if (*row[i] == card) return i;
    return 0;
}
/* 0802FCC8: preserve bits 3,6,7; clear the remaining flags and both stages. */
void ReplaceDuelCellCard(uint16_t *cell, uint16_t card)
{
    uint8_t *bytes=(uint8_t *)cell;
    *cell=card; bytes[3]=0; bytes[2]=0; bytes[4]&=0xC8;
}
/* 080243A8: signed permanent stage saturates at 127. */
void RaiseCellStage(uint16_t *cell)
{
    uint8_t *stage=(uint8_t *)cell+2;
    if (*stage != 127) ++*stage;
}
/* 080243BC: retain its incidental R0 value because the equipment trap branch
 * passes it directly to 08035AFC. At -128 it leaves R0=0xFFFFFF80; otherwise
 * R0 is the zero-extended stage byte minus one, before byte truncation.
 */
uint32_t LowerCellStageRegisterResult(uint16_t *cell)
{
    uint8_t *stage=(uint8_t *)cell+2;
    if (*stage == 128) return (uint32_t)-128;
    uint32_t result=(uint32_t)*stage-1;
    *stage=(uint8_t)result;
    return result;
}
static uint16_t *TargetCell(void)
{
    return gEffectBoardCells[gSpellInput.row][gSpellInput.column];
}
static uint16_t *EquipmentSourceCell(void)
{
    return gEffectBoardCells[gSpellInput.source_row][gSpellInput.source_column];
}
static void EquipmentSpell(uint16_t spell, uint8_t equipment)
{
    if (EquipmentAcceptsCard(equipment,*TargetCell()) != 1) {
        if (!gSuppressEffectPresentation) PlayGameAudio(57);
        return;
    }
    gTrapInput.row=gSpellInput.source_row;
    gTrapInput.column=gSpellInput.source_column;
    gTrapInput.card=*EquipmentSourceCell();
    uint8_t trap=FindActivatingTrap();
    if (trap==1 && !gSuppressEffectPresentation) {
        ActivateSelectedTrap((uint16_t)LowerCellStageRegisterResult(TargetCell()));
        return;
    }
    RaiseCellStage(TargetCell());
    DiscardDuelCell(EquipmentSourceCell(),0);
    if (!gSuppressEffectPresentation) {
        PlayGameAudio(65); PresentDuelEffect(spell,0); PlayGameAudio(73);
    }
}
static void SingleMaterialRitual(uint16_t spell, uint16_t material, uint16_t result)
{
    if (DuelRowContains(gEffectBoardCells[2],material)!=1) return;
    uint8_t slot=FindCardInDuelRow(gEffectBoardCells[2],material);
    DiscardDuelCell(TargetCell(),0);
    ReplaceDuelCellCard(gEffectBoardCells[2][slot],result);
    ResetTributesCommitted();
    if (!gSuppressEffectPresentation) {
        PlayGameAudio(65); PresentDuelEffect(spell,result); PlayGameAudio(83);
    }
}

/* Native per-card entry points: constants select the shared implementation. */
/* 0x0802BE54 */
void Handler_1a_021_Legendary_Sword(void) { EquipmentSpell(301, 0); }
/* 0x0802BF30 */
void Handler_1a_022_Sword_of_Dark_Destruction(void) { EquipmentSpell(302, 1); }
/* 0x0802C00C */
void Handler_1a_023_Dark_Energy(void) { EquipmentSpell(303, 2); }
/* 0x0802C0E8 */
void Handler_1a_024_Axe_of_Despair(void) { EquipmentSpell(304, 3); }
/* 0x0802C1C4 */
void Handler_1a_025_Laser_Cannon_Armor(void) { EquipmentSpell(305, 4); }
/* 0x0802C2A0 */
void Handler_1a_026_Insect_Armor_with_Laser_Cannon(void) { EquipmentSpell(306, 5); }
/* 0x0802C37C */
void Handler_1a_027_Elf_s_Light(void) { EquipmentSpell(307, 6); }
/* 0x0802C458 */
void Handler_1a_028_Beast_Fangs(void) { EquipmentSpell(308, 7); }
/* 0x0802C534 */
void Handler_1a_029_Steel_Shell(void) { EquipmentSpell(309, 8); }
/* 0x0802C610 */
void Handler_1a_030_Vile_Germs(void) { EquipmentSpell(310, 9); }
/* 0x0802C6EC */
void Handler_1a_031_Black_Pendant(void) { EquipmentSpell(311, 10); }
/* 0x0802C7C8 */
void Handler_1a_032_Silver_Bow_and_Arrow(void) { EquipmentSpell(312, 11); }
/* 0x0802C8A4 */
void Handler_1a_033_Horn_of_Light(void) { EquipmentSpell(313, 12); }
/* 0x0802C980 */
void Handler_1a_034_Horn_of_the_Unicorn(void) { EquipmentSpell(314, 13); }
/* 0x0802CA5C */
void Handler_1a_035_Dragon_Treasure(void) { EquipmentSpell(315, 14); }
/* 0x0802CB38 */
void Handler_1a_036_Electro_Whip(void) { EquipmentSpell(316, 15); }
/* 0x0802CC14 */
void Handler_1a_037_Cyber_Shield(void) { EquipmentSpell(317, 16); }
/* 0x0802CCF0 */
void Handler_1a_038_Mystical_Moon(void) { EquipmentSpell(319, 17); }
/* 0x0802CDCC */
void Handler_1a_039_Malevolent_Nuzzler(void) { EquipmentSpell(321, 18); }
/* 0x0802CEA8 */
void Handler_1a_040_Violet_Crystal(void) { EquipmentSpell(322, 19); }
/* 0x0802CF84 */
void Handler_1a_041_Book_of_Secret_Arts(void) { EquipmentSpell(323, 20); }
/* 0x0802D060 */
void Handler_1a_042_Invigoration(void) { EquipmentSpell(324, 21); }
/* 0x0802D13C */
void Handler_1a_043_Machine_Conversion_Factory(void) { EquipmentSpell(325, 22); }
/* 0x0802D218 */
void Handler_1a_044_Raise_Body_Heat(void) { EquipmentSpell(326, 23); }
/* 0x0802D2F4 */
void Handler_1a_045_Follow_Wind(void) { EquipmentSpell(327, 24); }
/* 0x0802D3D0 */
void Handler_1a_046_Power_of_Kaishin(void) { EquipmentSpell(328, 25); }
/* 0x0802D814 */
void Handler_1a_065_Black_Luster_Ritual(void) { SingleMaterialRitual(670, 38, 364); }
/* 0x0802D898 */
void Handler_1a_066_Zera_Ritual(void) { SingleMaterialRitual(671, 377, 360); }
/* 0x0802D91C */
void Handler_1a_067_War_Lion_Ritual(void) { SingleMaterialRitual(673, 403, 356); }
/* 0x0802D9A0 */
void Handler_1a_068_Beastly_Mirror_Ritual(void) { SingleMaterialRitual(674, 595, 365); }
/* 0x0802DBD8 */
void Handler_1a_070_Commencement_Dance(void) { SingleMaterialRitual(676, 249, 701); }
/* 0x0802DC60 */
void Handler_1a_071_Hamburger_Recipe(void) { SingleMaterialRitual(677, 295, 702); }
/* 0x0802DCEC */
void Handler_1a_072_Revival_of_Sennen_Genjin(void) { SingleMaterialRitual(678, 3, 703); }
/* 0x0802DD78 */
void Handler_1a_073_Novox_s_Prayer(void) { SingleMaterialRitual(679, 160, 704); }
/* 0x0802DE04 */
void Handler_1a_074_Curse_of_Tri_Horned_Dragon(void) { SingleMaterialRitual(680, 571, 705); }
/* 0x0802DE8C */
void Handler_1a_075_Revived_Serpent_Night_Dragon(void) { SingleMaterialRitual(691, 168, 706); }
/* 0x0802DF7C */
void Handler_1a_077_Magical_Labyrinth(void) { EquipmentSpell(652, 26); }
/* 0x0802E058 */
void Handler_1a_078_Salamandra(void) { EquipmentSpell(654, 27); }
/* 0x0802E134 */
void Handler_1a_079_Kunai_with_Chain(void) { EquipmentSpell(651, 28); }
/* 0x0802E210 */
void Handler_1a_080_Bright_Castle(void) { EquipmentSpell(668, 29); }
/* 0x0802E418 */
void Handler_1a_083_Turtle_Oath(void) { SingleMaterialRitual(692, 449, 710); }
/* 0x0802E4A0 */
void Handler_1a_084_Contract_of_Mask(void) { SingleMaterialRitual(693, 102, 720); }
/* 0x0802E52C */
void Handler_1a_085_Resurrection_of_Chakra(void) { SingleMaterialRitual(694, 269, 709); }
/* 0x0802E5B8 */
void Handler_1a_086_Puppet_Ritual(void) { SingleMaterialRitual(695, 166, 715); }
/* 0x0802E644 */
void Handler_1a_087_Javelin_Beetle_Pact(void) { SingleMaterialRitual(696, 52, 717); }
/* 0x0802E6CC */
void Handler_1a_088_Garma_Sword_Oath(void) { SingleMaterialRitual(697, 621, 716); }
/* 0x0802E758 */
void Handler_1a_089_Cosmo_Queen_s_Prayer(void) { SingleMaterialRitual(698, 638, 708); }
/* 0x0802E7E4 */
void Handler_1a_090_Revival_of_Dokurorider(void) { SingleMaterialRitual(699, 146, 719); }
/* 0x0802E870 */
void Handler_1a_091_Fortress_Whale_s_Oath(void) { SingleMaterialRitual(700, 441, 718); }
/* 0x0802E8F8 */
void Handler_1a_092_Curse_of_Millennium_Shield(void) { SingleMaterialRitual(665, 296, 362); }
/* 0x0802E97C */
void Handler_1a_093_Yamadron_Ritual(void) { SingleMaterialRitual(666, 29, 357); }
/* 0x0802EC60 */
void Handler_1a_098_Megamorph(void) { EquipmentSpell(657, 30); }
/* 0x0802EE50 */
void Handler_1a_100_Winged_Trumpeter(void) { EquipmentSpell(659, 31); }
/* 0x0802F618 */
void Handler_1a_113_Black_Illusion_Ritual(void) { SingleMaterialRitual(783, 730, 731); }
/* 0x0802F854 */
void Handler_1a_118_7_Completed(void) { EquipmentSpell(900, 32); }
