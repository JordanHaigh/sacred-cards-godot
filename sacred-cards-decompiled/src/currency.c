/* AY7E currency arithmetic, RAM 02020DA0..02020DA7. Native ARM code uses
 * low/high word arithmetic; uint64_t expresses the same unsigned operations.
 * Semantic reconstruction, not execution-compared or compiler-matched.
 */
#include <stdint.h>
#define MONEY_LIMIT UINT64_C(9999999999999)
extern uint64_t gMoney;

/* 08019B7C. Normal invariant: money <= MONEY_LIMIT. Preserve native unsigned
 * subtraction even for values outside that invariant.
 */
void AddMoney(uint64_t amount)
{
    if (amount > MONEY_LIMIT - gMoney) gMoney = MONEY_LIMIT;
    else gMoney += amount;
}
/* 08019BC4 */
void SubtractMoney(uint64_t amount)
{
    gMoney = amount > gMoney ? 0 : gMoney - amount;
}
/* 08019BFC */
uint32_t CanReceiveMoney(uint64_t amount)
{
    return amount <= MONEY_LIMIT - gMoney;
}
/* 08019C34 */
uint32_t CanAfford(uint64_t amount) { return amount <= gMoney; }
/* 08019C58 */
void InitializeMoney(void) { gMoney = 500; }
