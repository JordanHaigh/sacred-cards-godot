/* Semantic reconstruction of AY7E 0x0802321C..0x08023512 and
 * 0x08023A04..0x08023C32. Not execution-compared or compiler-matched.
 * This parameterized interface covers the numerical resolution stage only.
 * Board removal, animation, LP write-back and effect dispatch are separate.
 * battle_state.c supplies the native RAM adapter and LP/display write-back.
 */
#include "battle.h"
extern const uint8_t gAttributeBeats[12]; /* ROM 0x08D4BD30 */
extern const uint8_t gAttributeLosesTo[12]; /* ROM 0x08D4BD3C */
extern const uint8_t gOwnerDefeatMask[]; /* ROM 0x08D4BD2C; owner must be valid */

/* 0x08023A04: 0 = A attribute wins; 1 = neutral; 2 = B wins.
 * Divine attribute 11 bypasses the lookup. Native code assumes valid attributes.
 */
uint8_t CompareSummonAttributes(uint32_t a_input, uint32_t b_input)
{
    uint8_t a = (uint8_t)a_input, b = (uint8_t)b_input;
    if (a == 11 || b == 11) return 1;
    if (gAttributeBeats[a] == b) return 0;
    if (gAttributeLosesTo[a] == b) return 2;
    return 1;
}

static void Damage(struct BattleResolution *r, struct BattleSide *s, uint32_t amount)
{
    if (s->life_points <= amount) {
        s->life_points = 0;
        r->flags |= gOwnerDefeatMask[s->owner]; /* 0x08023200 */
    } else s->life_points -= amount;
}
static void Heal(struct BattleSide *s, uint16_t amount)
{
    uint32_t total = s->life_points + amount;
    s->life_points = total > 9999 ? 9999 : (uint16_t)total;
}

/* Includes attribute override paths 0x08023AFC and 0x08023B40. */
static void AttackAgainstAttack(struct BattleResolution *r)
{
    uint8_t relation = CompareSummonAttributes(r->a.attribute, r->b.attribute);
    r->result = 0;
    if (relation == 0) {
        r->flags |= 2; r->result = 16;
        if (r->a.attack > r->b.attack) Damage(r, &r->b, r->a.attack-r->b.attack);
    } else if (relation == 2) {
        r->flags |= 1; r->result = 17;
        if (r->a.attack < r->b.attack) Damage(r, &r->a, r->b.attack-r->a.attack);
    } else if (r->a.attack > r->b.attack) {
        r->flags |= 2; Damage(r, &r->b, r->a.attack-r->b.attack); r->result = 1;
    } else if (r->a.attack == r->b.attack) {
        r->flags |= 3; r->result = 2;
    } else {
        r->flags |= 1; Damage(r, &r->a, r->b.attack-r->a.attack); r->result = 3;
    }
}

/* 0x08023344 with overrides 0x08023B88 / 0x08023B9C. */
static void AttackAgainstDefense(struct BattleResolution *r)
{
    uint8_t relation = CompareSummonAttributes(r->a.attribute, r->b.attribute);
    r->result = 0;
    if (relation == 0) { r->flags |= 2; r->result = 16; }
    else if (relation == 2) {
        r->flags |= 1; r->result = 17;
        if (r->a.attack < r->b.defense) Damage(r, &r->a, r->b.defense-r->a.attack);
    } else if (r->a.attack > r->b.defense) { r->flags |= 2; r->result = 4; }
    else if (r->a.attack == r->b.defense) r->result = 5;
    else { Damage(r, &r->a, r->b.defense-r->a.attack); r->result = 6; }
}

/* 0x080233B4 with overrides 0x08023BDC / 0x08023C20. */
static void DefenseAgainstAttack(struct BattleResolution *r)
{
    uint8_t relation = CompareSummonAttributes(r->a.attribute, r->b.attribute);
    r->result = 0;
    if (relation == 0) {
        r->flags |= 2; r->result = 16;
        if (r->a.defense > r->b.attack) Damage(r, &r->b, r->a.defense-r->b.attack);
    } else if (relation == 2) { r->flags |= 1; r->result = 17; }
    else if (r->a.defense > r->b.attack) {
        Damage(r, &r->b, r->a.defense-r->b.attack); r->result = 7;
    } else if (r->a.defense == r->b.attack) r->result = 8;
    else { r->flags |= 1; r->result = 9; }
}

/* Numerical part of 0x0802321C. Result reset behavior follows each target:
 * no-op and heal/damage cases leave the previous display result untouched.
 */
void ResolveBattleNumbers(struct BattleResolution *r, uint8_t command)
{
    r->flags = 0;
    switch (command) {
    case 1: AttackAgainstAttack(r); break;
    case 2: AttackAgainstDefense(r); break;
    case 3: break; /* 0x080233B0 */
    case 4: r->result = 0; Damage(r, &r->b, r->a.attack); r->result = 10; break;
    case 5: DefenseAgainstAttack(r); break;
    case 6: r->result = 0; Damage(r, &r->a, r->b.attack); r->result = 15; break;
    case 7: Heal(&r->a, r->a.attack); break;
    case 8: Damage(r, &r->a, r->a.attack); break;
    case 9: Damage(r, &r->b, r->b.attack); break;
    case 10: Heal(&r->b, r->b.attack); break;
    default: break;
    }
}
