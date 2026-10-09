#ifndef AY7E_GBA_BIOS_H
#define AY7E_GBA_BIOS_H
#include <stdint.h>
/* AY7E Thumb BIOS wrappers. These require a GBA BIOS when executed. */
#define AY7E_BIOS_COPY(name,number) \
static inline void name(const void *source,void *destination,uint32_t control) { \
    register const void *r0 __asm__("r0")=source; \
    register void *r1 __asm__("r1")=destination; \
    register uint32_t r2 __asm__("r2")=control; \
    __asm__ volatile("swi " #number : "+r"(r0),"+r"(r1),"+r"(r2) : : "r3","memory","cc"); \
}
AY7E_BIOS_COPY(BiosCpuSet,0x0B)
AY7E_BIOS_COPY(BiosCpuFastSet,0x0C)
#undef AY7E_BIOS_COPY
#define AY7E_BIOS_UNPACK(name,number) \
static inline void name(const void *source,void *destination) { \
    register const void *r0 __asm__("r0")=source; \
    register void *r1 __asm__("r1")=destination; \
    __asm__ volatile("swi " #number : "+r"(r0),"+r"(r1) : : "r2","r3","memory","cc"); \
}
AY7E_BIOS_UNPACK(BiosLz77UnpackWram,0x11)
AY7E_BIOS_UNPACK(BiosHuffmanUnpack,0x13)
#undef AY7E_BIOS_UNPACK
/*08037D04: the BIOS itself belongs to the console, outside the cartridge.*/
static inline void BiosSoundBias(uint32_t bias)
{ register uint32_t r0 __asm__("r0")=bias;__asm__ volatile("swi 0x2A" : "+r"(r0) : : "r1","r2","r3","memory","cc"); }
#endif
