/* AY7E RAM adapter for numerical battle operations and effect LP changes.
 * Native calculation/display structures retain untouched bytes. Calls the
 * parameterized numerical C; no execution or compiler equivalence is claimed. */
#include "battle.h"
extern uint8_t gBattleCalculationBytes[0x1C]; /* 02023120 */
extern uint8_t gBattleDisplayBytes[0x19];     /* 02023140 */
extern uint16_t gDuelLifePoints[2];          /* 0202347C */
extern uint8_t gDuelAuxiliaryFlags[2];       /* 02020D88 */
static uint16_t Read16(const uint8_t *p) { return p[0]|(uint16_t)p[1]<<8; }
static void Write16(uint8_t *p,uint16_t v) { p[0]=(uint8_t)v;p[1]=(uint8_t)(v>>8); }
static void PrepareLifeOperation(uint8_t command,unsigned amount_at,uint16_t amount)
{
    gBattleCalculationBytes[0x18]=command;
    gBattleCalculationBytes[0x1A]=0;gBattleCalculationBytes[0x1B]=1;
    Write16(gBattleCalculationBytes+amount_at,amount);
    Write16(gBattleCalculationBytes+6,gDuelLifePoints[0]);
    Write16(gBattleCalculationBytes+0x12,gDuelLifePoints[1]);
}
/* 08023974 / 08023998 / 080239BC / 080239E0. */
void PrepareHealSideA(uint16_t amount) { PrepareLifeOperation(7,2,amount); }
void PrepareDamageSideA(uint16_t amount) { PrepareLifeOperation(8,2,amount); }
void PrepareHealSideB(uint16_t amount) { PrepareLifeOperation(10,0x0E,amount); }
void PrepareDamageSideB(uint16_t amount) { PrepareLifeOperation(9,0x0E,amount); }
static struct BattleSide ReadSide(unsigned at,uint8_t owner)
{
    const uint8_t *p=gBattleCalculationBytes+at;
    struct BattleSide side={Read16(p+2),Read16(p+4),Read16(p+6),p[8],owner};return side;
}
/* 08023514: use the calculation owner indices, not an assumed A=0/B=1. */
static void CommitLifePoints(void)
{
    uint16_t a=Read16(gBattleCalculationBytes+6),b=Read16(gBattleCalculationBytes+0x12);
    gDuelLifePoints[gBattleCalculationBytes[0x1A]]=a;Write16(gBattleDisplayBytes+4,a);
    gDuelLifePoints[gBattleCalculationBytes[0x1B]]=b;Write16(gBattleDisplayBytes+0x10,b);
}
/* 0802356C: attribute writes are bytes; other listed fields are halfwords. */
static void CommitDisplayFields(void)
{
    Write16(gBattleDisplayBytes,Read16(gBattleCalculationBytes));
    gBattleDisplayBytes[0x0A]=gBattleCalculationBytes[8];
    Write16(gBattleDisplayBytes+6,Read16(gBattleCalculationBytes+2));
    Write16(gBattleDisplayBytes+8,Read16(gBattleCalculationBytes+4));
    Write16(gBattleDisplayBytes+0x0C,Read16(gBattleCalculationBytes+0x0C));
    gBattleDisplayBytes[0x16]=gBattleCalculationBytes[0x14];
    Write16(gBattleDisplayBytes+0x12,Read16(gBattleCalculationBytes+0x0E));
    Write16(gBattleDisplayBytes+0x14,Read16(gBattleCalculationBytes+0x10));
}
/* 0802321C including both post-calculation write-back helpers. */
void ResolveCurrentBattleNumbers(void)
{
    struct BattleResolution result={ReadSide(0,gBattleCalculationBytes[0x1A]),
        ReadSide(0x0C,gBattleCalculationBytes[0x1B]),0,gBattleDisplayBytes[0x18]};
    ResolveBattleNumbers(&result,gBattleCalculationBytes[0x18]);
    Write16(gBattleCalculationBytes+6,result.a.life_points);
    Write16(gBattleCalculationBytes+0x12,result.b.life_points);
    gBattleCalculationBytes[0x19]=result.flags;gBattleDisplayBytes[0x18]=result.result;
    CommitLifePoints();CommitDisplayFields();
}
/* 08023614 and 080181F4: only defeat bits 2/4 set side flags to two. */
void ApplyBattleDefeatFlags(void)
{
    if (gBattleCalculationBytes[0x19]&4) gDuelAuxiliaryFlags[0]=2;
    if (gBattleCalculationBytes[0x19]&0x10) gDuelAuxiliaryFlags[1]=2;
}
