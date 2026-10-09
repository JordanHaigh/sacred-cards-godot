/* AY7E save payload reconstruction. Byte-copy behavior reviewed against native
 * instructions; not execution-compared or compiler-matched. This module covers
 * payload packing/checksum, not SRAM slot selection, headers, or write retries.
 */
#include <stdint.h>
#include <stddef.h>

#define SAVE_PAYLOAD_BYTES 0x80Au
struct SaveRegion { uint8_t *ram; uint32_t size; };
/* ROM 0x080D1490, 13 regions followed by {NULL,0}; native buffer pointer is
 * ROM 0x08D41B28 -> RAM 0x02018800. See build/assets/save/layout.json.
 */
extern const struct SaveRegion gSaveRegions[];

/* 0x08021F28: sum exactly 2058 bytes, reduced modulo 65536. */
uint16_t SavePayloadChecksum(const uint8_t payload[SAVE_PAYLOAD_BYTES])
{
    uint32_t sum = 0;
    for (uint32_t i = 0; i < SAVE_PAYLOAD_BYTES; ++i) sum += payload[i];
    return (uint16_t)sum;
}

/* 0x08021F54. Parameter replaces the native fixed buffer. The descriptors
 * define capacity; there is no native bounds check or padding between regions.
 */
void PackSavePayload(uint8_t *payload)
{
    uint32_t offset = 0;
    for (const struct SaveRegion *r = gSaveRegions; r->ram != NULL; ++r)
        for (uint32_t i = 0; i < r->size; ++i) payload[offset++] = r->ram[i];
}

/* 0x08021FB8. The same descriptor order is used in the reverse direction. */
void UnpackSavePayload(const uint8_t *payload)
{
    uint32_t offset = 0;
    for (const struct SaveRegion *r = gSaveRegions; r->ram != NULL; ++r)
        for (uint32_t i = 0; i < r->size; ++i) r->ram[i] = payload[offset++];
}
