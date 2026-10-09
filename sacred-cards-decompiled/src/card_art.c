/* Semantic reconstruction of AY7E Thumb 0x0800917C for 10x10 tile card art.
 * Original callers 0x08009118 and 0x08009148 pass (10, 10).
 * This is portable recovered C, not yet a compiler-matched ROM replacement.
 */
#include <stdint.h>

void CardArtUndoRowDeltas(uint8_t tiles[6400])
{
    for (unsigned y = 0; y < 80; ++y) {
        uint8_t previous = 0;
        for (unsigned x = 0; x < 80; ++x) {
            unsigned offset = ((y / 8) * 10 + x / 8) * 64
                            + (y % 8) * 8 + x % 8;
            previous = (uint8_t)(previous + tiles[offset]);
            tiles[offset] = previous;
        }
    }
}

/* Semantic reconstruction of Thumb 0x08034B40. The destination surface is
 * 16 tiles wide; the four-by-four tile card occupies its upper-left corner.
 */
void ComposeMiniCard(uint8_t *destination, const uint8_t art[576],
                     const uint8_t frame[1024])
{
    for (unsigned y = 0; y < 32; ++y) {
        for (unsigned x = 0; x < 32; ++x) {
            unsigned source = ((y / 8) * 4 + x / 8) * 64
                            + (y % 8) * 8 + x % 8;
            uint8_t color = frame[source];
            if (x >= 4 && x < 28 && y >= 2 && y < 26) {
                unsigned ax = x - 4, ay = y - 2;
                source = ((ay / 8) * 3 + ax / 8) * 64
                       + (ay % 8) * 8 + ax % 8;
                color = art[source];
            }
            unsigned target = ((y / 8) * 16 + x / 8) * 64
                            + (y % 8) * 8 + x % 8;
            destination[target] = color;
        }
    }
}

/* 080351EC: the same frame and inset art as 08034B40, with four tiles per
 * destination row. The source frame advances even under the inserted art. */
void ComposeMiniCardContiguous(uint8_t destination[1024],const uint8_t art[576],const uint8_t frame[1024])
{
    for(unsigned y=0;y<32;++y)for(unsigned x=0;x<32;++x) {
        unsigned target=((y/8)*4+x/8)*64+(y%8)*8+x%8;
        uint8_t color=frame[target];
        if(x>=4 && x<28 && y>=2 && y<26) {
            unsigned ax=x-4,ay=y-2;color=art[((ay/8)*3+ax/8)*64+(ay%8)*8+ax%8];
        }
        destination[target]=color;
    }
}

/*08009160/0917C generalized delta decoders, including unused LZ77 routes.
 * Byte counts and tile dimensions are supplied by the native caller. */
void UndoByteDeltas(uint8_t *bytes,uint32_t count)
{ uint8_t previous=0;for(uint32_t i=0;i<count;++i) { previous+=bytes[i];bytes[i]=previous; } }
void UndoTiledRowDeltas(uint8_t *tiles,uint8_t rows,uint8_t columns)
{
    /* Native strides describe a ten-tile surface, independently of arguments. */
    for(unsigned y=0;y<(unsigned)rows*8;++y) { uint8_t previous=0;
        for(unsigned x=0;x<(unsigned)columns*8;++x) { previous+=*tiles;*tiles=previous;tiles+=(x&7)==7?57:1; }
        tiles-=(y&7)==7?56:632;
    }
}
