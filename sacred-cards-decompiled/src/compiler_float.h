#ifndef COMPILER_FLOAT_H
#define COMPILER_FLOAT_H
#include <stdint.h>
/* Portable value representation, not the original register/stack ABI. Native
 * double parts use five words: kind,sign,exponent,mantissa low,mantissa high;
 * float parts use four. Mantissa here accommodates both formats. */
typedef struct { uint32_t kind,sign; int32_t exponent; uint64_t mantissa; } RomFpParts;
RomFpParts RomUnpackDouble(uint64_t bits),RomUnpackFloat(uint32_t bits);
uint64_t RomPackDouble(RomFpParts p);
uint32_t RomPackFloat(RomFpParts p);
RomFpParts RomAddDoubleParts(RomFpParts a,RomFpParts b),RomAddFloatParts(RomFpParts a,RomFpParts b);
int RomCompareDoubleParts(RomFpParts a,RomFpParts b),RomCompareFloatParts(RomFpParts a,RomFpParts b);
uint64_t RomAddDouble(uint64_t a,uint64_t b),RomSubtractDouble(uint64_t a,uint64_t b),RomMultiplyDouble(uint64_t a,uint64_t b),RomDivideDouble(uint64_t a,uint64_t b),RomNegateDouble(uint64_t a);
uint32_t RomAddFloat(uint32_t a,uint32_t b),RomSubtractFloat(uint32_t a,uint32_t b),RomMultiplyFloat(uint32_t a,uint32_t b),RomDivideFloat(uint32_t a,uint32_t b),RomNegateFloat(uint32_t a);
int RomCompareDouble(uint64_t a,uint64_t b),RomCompareDoubleUnorderedNegative(uint64_t a,uint64_t b);
int RomCompareFloat(uint32_t a,uint32_t b),RomCompareFloatUnorderedNegative(uint32_t a,uint32_t b);
uint64_t RomSignedToDouble(int32_t value),RomFloatToDouble(uint32_t bits);
uint32_t RomSignedToFloat(int32_t value),RomDoubleToFloat(uint64_t bits),RomDoubleToUnsigned(uint64_t bits);
int32_t RomDoubleToSigned(uint64_t bits),RomFloatToSigned(uint32_t bits);
uint64_t RomMakeDouble(uint32_t kind,uint32_t sign,int32_t exponent,uint32_t low,uint32_t high);
uint32_t RomMakeFloat(uint32_t kind,uint32_t sign,int32_t exponent,uint32_t mantissa);
#endif
