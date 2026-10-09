/* AY7E 0x08033D48, 0x08033D64, 0x08033D90, 0x08033DB0.
 * Parameterized semantic C; original bank is RAM 0x02023700, 50 bytes.
 * Original bit-mask table at ROM 0x08D4F434. Not execution-compared or matched.
 */
#include <stdint.h>
extern const uint8_t gEventBitMasks[8];
void ClearAllEventFlags(uint8_t flags[50])
{
    for (unsigned i = 0; i < 50; ++i) flags[i] = 0;
}
void SetEventFlag(uint8_t flags[50], uint32_t id)
{
    if (id > 399) return;
    flags[id >> 3] |= gEventBitMasks[id & 7];
}
/* Clear/test do not perform the setter's range check in the native code.
 * Callers must provide IDs in the bank; retain this precondition explicitly.
 */
void ClearEventFlag(uint8_t flags[50], uint32_t id)
{
    flags[id >> 3] &= (uint8_t)~gEventBitMasks[id & 7];
}
uint8_t TestEventFlag(const uint8_t flags[50], uint32_t id)
{
    return (flags[id >> 3] & gEventBitMasks[id & 7]) != 0;
}
