/* AY7E compiler integer/string support. Names identify ROM semantics without
 * overriding the host C library or assuming the original compiler ABI.
 * Native division-by-zero handler39328 returns; 32-bit divide/mod return0.
 * Signed results use unsigned magnitudes to retain INT_MIN wrap. */
#include "compiler_runtime.h"
#include <stddef.h>
/*08039888/39CAC/39294/39370*/
uint32_t RomUnsignedDivide32(uint32_t numerator,uint32_t denominator)
{
    if(!denominator)return 0;uint32_t quotient=0,remainder=0;
    for(unsigned bits=32;bits;--bits) { uint32_t overflow=remainder>>31;remainder=(remainder<<1)|((numerator>>(bits-1))&1);if(overflow || remainder>=denominator) { remainder-=denominator;quotient|=1u<<(bits-1); } }return quotient;
}
uint32_t RomUnsignedRemainder32(uint32_t a,uint32_t b) { return b?a-RomUnsignedDivide32(a,b)*b:0; }
int32_t RomSignedDivide32(int32_t a,int32_t b)
{ uint32_t x=a<0?0u-(uint32_t)a:(uint32_t)a,y=b<0?0u-(uint32_t)b:(uint32_t)b,q=RomUnsignedDivide32(x,y);return (int32_t)((a<0)!=(b<0)?0u-q:q); }
int32_t RomSignedRemainder32(int32_t a,int32_t b)
{ uint32_t x=a<0?0u-(uint32_t)a:(uint32_t)a,y=b<0?0u-(uint32_t)b:(uint32_t)b,r=RomUnsignedRemainder32(x,y);return (int32_t)(a<0?0u-r:r); }
void RomDivideByZero(void) {} /*08039328*/
/* Shared restoring divide with optional remainder output. Original uses
 * normalized16-bit quotient estimation; the same quotient/remainder contract
 * is expressed with shifts/subtraction here. 394B0 and38E60 contain quotient
 * algorithms;39900 contains the unsigned remainder algorithm.*/
uint64_t RomUnsignedDivide64(uint64_t numerator,uint64_t denominator,uint64_t *remainder)
{
    uint64_t quotient=0,r=0;if(!denominator) { if(remainder)*remainder=0;return 0; }
    for(unsigned bits=64;bits;--bits) { uint64_t overflow=r>>63;r=(r<<1)|((numerator>>(bits-1))&1);if(overflow || r>=denominator) { r-=denominator;quotient|=UINT64_C(1)<<(bits-1); } }
    if(remainder)*remainder=r;return quotient;
}
/*08039900 returns the remainder, not the quotient. Its local output pointer
 * is a stack slot; Ghidra incorrectly presents it as an optional input. */
uint64_t RomUnsignedRemainder64(uint64_t a,uint64_t b)
{ uint64_t remainder;RomUnsignedDivide64(a,b,&remainder);return remainder; }
uint64_t RomUnsignedQuotient64(uint64_t a,uint64_t b) { return RomUnsignedDivide64(a,b,0); } /*080394B0*/
int64_t RomSignedDivide64(int64_t a,int64_t b)
{ uint64_t x=a<0?0-(uint64_t)a:(uint64_t)a,y=b<0?0-(uint64_t)b:(uint64_t)b,q=RomUnsignedDivide64(x,y,0);return (int64_t)((a<0)!=(b<0)?0-q:q); } /*08038E60*/
/*08039440: only the low64 product bits are returned.*/
uint64_t RomMultiply64(uint64_t a,uint64_t b)
{
    uint64_t product=0;for(unsigned i=0;i<64;++i) { if(b&1)product+=a;a<<=1;b>>=1; }return product;
}
/*0803B454/3B488. ARM variable shifts use the low8 shift bits and produce
 *zero at32 or above, instead of C's undefined out-of-range shift.*/
static uint32_t ArmLsr(uint32_t x,uint32_t n) { n&=255;return n>=32?0:x>>n; }
static uint32_t ArmLsl(uint32_t x,uint32_t n) { n&=255;return n>=32?0:x<<n; }
uint64_t RomLogicalShiftRight64(uint64_t value,uint32_t count)
{
    uint32_t low=value,high=value>>32;if(count) {
        int32_t left=(int32_t)(32u-count);
        if(left<1) { low=ArmLsr(high,0u-(uint32_t)left);high=0; }
        else { low=ArmLsr(low,count)|ArmLsl(high,left);high=ArmLsr(high,count); }
    }return low|((uint64_t)high<<32);
}
uint64_t RomNegate64(uint64_t value) { return 0-value; }
/*0803B4A0/3B4BC/3B51C/3B568/3B5AC. Native aligned word fast paths
 * are replaced by byte loops; forward-copy and NUL-padding semantics remain.*/
void RomZeroBytes(void *destination,uint32_t count)
{ uint8_t *p=destination;while(count--)*p++=0; }
void *RomCopyBytes(void *destination,const void *source,uint32_t count)
{ uint8_t *out=destination;const uint8_t *in=source;while(count--)*out++=*in++;return destination; }
char *RomCopyString(char *destination,const char *source)
{ char *out=destination;do { *out++=*source; }while(*source++);return destination; }
uint32_t RomStringLength(const char *source)
{ const char *p=source;while(*p)++p;return (uint32_t)(p-source); }
char *RomCopyStringN(char *destination,const char *source,uint32_t count)
{ char *out=destination;while(count && *source) { *out++=*source++;--count; }while(count--)*out++=0;return destination; }
