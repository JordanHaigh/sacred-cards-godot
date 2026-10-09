/* AY7E semantic reconstruction. Not compiler-matched or execution-compared.
 * Addresses below are original Thumb entry points. ROM tables are generated
 * by build_runtime_tables.py. Callers supply valid card, type and terrain indices.
 */
#include <stdint.h>
#include "compiler_float.h"

extern const uint8_t gTerrainModifiers[7][24]; /* ROM 0x0808B533 */

/* 0x08006DA0: input truncation precedes signed stage arithmetic. */
uint16_t ApplyStatStage(uint32_t stat_input, uint32_t stage_input)
{
    uint16_t stat = (uint16_t)stat_input;
    int32_t stage = (int32_t)(stage_input & 255);
    if (stage >= 128) stage -= 256;
    int32_t result = stat + stage * 500;
    if (result <= 0) return 0;
    if (result > 65534) return 65534;
    return (uint16_t)result;
}

/* 0x08006DD4: original code uses soft double helpers. Hex constants preserve
 * its binary64 factors. Conversion wraps to u16 BEFORE the upper comparison.
 * This is observable for large inputs; replacing it with saturating math would
 * change behavior. Recovered ROM bit arithmetic supplies multiplication and
 * conversion without depending on host floating-point rounding.
 */
uint16_t ApplyTerrainModifier(uint32_t stat_input, uint32_t modifier_input)
{
    uint16_t stat = (uint16_t)stat_input;
    switch ((uint8_t)modifier_input) {
    case 1:
        return (uint16_t)RomDoubleToUnsigned(RomMultiplyDouble(RomSignedToDouble(stat),UINT64_C(0x3FE6666666666666)));
    case 3: {
        uint16_t result = (uint16_t)RomDoubleToUnsigned(RomMultiplyDouble(RomSignedToDouble(stat),UINT64_C(0x3FF4CCCCCCCCCCCD)));
        return result > 65533 ? 65534 : result;
    }
    default:
        return stat;
    }
}

/* Factored from 0x08006CB4 and 0x08006D2C after LoadCardMetadata.
 * This parameterized interface replaces their RAM globals; it is not their ABI.
 * metadata_1a is the byte at 0x02020B1A. Only value 2 enters this path.
 */
void ApplyCardStatModifiers(uint16_t *attack, uint16_t *defense,
                           uint8_t metadata_1a, uint8_t type,
                           uint8_t terrain, uint8_t stage)
{
    if (metadata_1a != 2) return;
    uint8_t modifier = gTerrainModifiers[terrain][type];
    *attack = ApplyStatStage(ApplyTerrainModifier(*attack, modifier), stage);
    *defense = ApplyStatStage(ApplyTerrainModifier(*defense, modifier), stage);
}
