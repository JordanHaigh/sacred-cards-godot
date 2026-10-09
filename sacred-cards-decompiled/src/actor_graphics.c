/* Semantic reconstruction of the copy loop at Thumb 0x08030554.
 * Original r0/r1 select sheet and tile offset through ROM tables; this portable
 * interface receives the resolved source sheet and tile offset explicitly.
 * The destination is a 32-tile-wide 4bpp surface. Only four tiles per row change.
 * Not compiler-matched to the original ROM.
 */
#include <stdint.h>

void CopyActorFrame(const uint8_t *sheet, uint16_t tile_offset, uint8_t *destination)
{
    const uint8_t *source = sheet + (unsigned)tile_offset * 32;
    for (unsigned row = 0; row < 4; ++row) {
        for (unsigned column = 0; column < 128; ++column)
            destination[row * 1024 + column] = source[row * 512 + column];
    }
}
