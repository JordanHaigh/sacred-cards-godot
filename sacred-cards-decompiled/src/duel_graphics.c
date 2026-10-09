/* AY7E duel terrain layer08024980/08025800. Semantic C only. The native copy
 * overlaps each 31-halfword source row by one halfword and reads forty rows. */
#include "gba_bios.h"
extern uint8_t gBackgroundBuffer[],gPaletteBuffer[],gDialogueTiles[];
extern uint16_t gBgOffsetsRaw[22];
extern uint8_t gDuelViewport; /* 02023439 */
extern const uint8_t *const gDuelTerrainTiles[7],*const gDuelTerrainMaps[7],*const gDuelTerrainPalettes[7];
/* Native tables08D4BE58 / 08D4BE74 / 08D4BE90 */
extern const uint8_t gDuelViewportOffsets[256]; /* byte-indexed view08D4C2C1 */
/* Native leaves the loaded byte in R0 as well as storing it. */
uint16_t SetDuelViewportOffset(uint8_t view) { uint16_t value=gDuelViewportOffsets[view];gBgOffsetsRaw[2]=value;return value; }
void LoadDuelTerrain(uint8_t terrain) {
    *(volatile uint16_t *)0x0400000C=0x9B02;
    BiosHuffmanUnpack(gDuelTerrainTiles[terrain],gBackgroundBuffer);
    BiosCpuSet(gDuelTerrainPalettes[terrain],gPaletteBuffer,0x30);
    for(unsigned row=0;row<40;++row)BiosCpuSet(gDuelTerrainMaps[terrain]+row*62,gDialogueTiles+row*64,0x20);
    gBgOffsetsRaw[20]=4;gBgOffsetsRaw[2]=SetDuelViewportOffset(gDuelViewport);
}
