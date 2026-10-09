/* Semantic reconstructions, not compiler-matched replacements. */
#include "scene_data.h"

/* 0x080311B0. The original obtains grid from *(u16 **)0x020236F0. */
uint16_t SceneCellAt(const uint16_t *grid, uint8_t x, uint8_t y)
{
    return grid[(unsigned)y * 120 + x];
}

/* 0x0803181C: high flags suppress the low-bit predicate. */
uint32_t SceneCellTestBaseFlag(uint16_t cell)
{
    return (cell & 0xFE00) == 0 && (cell & 1) != 0;
}

/* 0x0803183C. */
uint32_t SceneCellTestBit8(uint16_t cell)
{
    return (cell & 0x0100) != 0;
}

/* 0x08031854: bit 9 takes precedence over bit 10. */
uint32_t SceneCellSelectEventClass(uint16_t cell)
{
    if (cell & 0x0200)
        return 1;
    return (cell & 0x0400) ? 2 : 0;
}

/* Native global-grid adapter at 080311B0. */
extern const uint16_t *gSceneGrid; /* 020236F0 */
uint16_t ReadSceneCell(uint8_t x,uint8_t y) { return SceneCellAt(gSceneGrid,x,y); }
