#ifndef AY7E_COMPILER_RUNTIME_H
#define AY7E_COMPILER_RUNTIME_H
#include <stdint.h>
/* Recovered cartridge library interfaces. These avoid replacing the host
 * standard library or assuming the original compiler calling convention. */
uint32_t RomUnsignedDivide32(uint32_t,uint32_t);
uint32_t RomUnsignedRemainder32(uint32_t,uint32_t);
int32_t RomSignedDivide32(int32_t,int32_t);
int32_t RomSignedRemainder32(int32_t,int32_t);
void RomDivideByZero(void);
uint64_t RomUnsignedDivide64(uint64_t,uint64_t,uint64_t *remainder);
uint64_t RomUnsignedQuotient64(uint64_t,uint64_t);
uint64_t RomUnsignedRemainder64(uint64_t,uint64_t);
int64_t RomSignedDivide64(int64_t,int64_t);
uint64_t RomMultiply64(uint64_t,uint64_t);
uint64_t RomLogicalShiftRight64(uint64_t,uint32_t);
uint64_t RomNegate64(uint64_t);
void RomZeroBytes(void *,uint32_t);
void *RomCopyBytes(void *,const void *,uint32_t);
char *RomCopyString(char *,const char *);
char *RomCopyStringN(char *,const char *,uint32_t);
uint32_t RomStringLength(const char *);
#endif
