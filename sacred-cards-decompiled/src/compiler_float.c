/* AY7E old GCC software floating-point routines08039D6C..0803B454.
 * Bit-pattern APIs avoid relying on host rounding, NaNs or FPA register order
 * (the original double ABI passes HIGH word first). The common implementation
 * expresses the two original algorithms with their respective bit widths.
 * Zero/inf unpack leaves unused native fields untouched; value APIs zero them.
 * Canonical invalid-operation operands are read from the original RAM views.
 * Original linker integration is deliberately outside these portable APIs. */
#include "compiler_float.h"
#include <limits.h>
/* Native addresses0201FC58/0201FC70, not invented host NaN constants. */
extern const uint32_t gRomDoubleInvalidParts[5],gRomFloatInvalidParts[4];
static RomFpParts Invalid(unsigned single)
{
    const uint32_t *p=single?gRomFloatInvalidParts:gRomDoubleInvalidParts;
    RomFpParts result={p[0],p[1],(int32_t)p[2],p[3]};
    if(!single)result.mantissa|=(uint64_t)p[4]<<32;
    return result;
}
static uint64_t Bit(unsigned n) { return UINT64_C(1)<<n; }
/*08039EB4 /0803ABC0: finite significands retain8/7 rounding bits;
 * NaN significands instead retain their unshifted raw payload. */
static RomFpParts Unpack(uint64_t bits,unsigned single)
{
    unsigned fraction=single?23:52,round=single?7:8,bias=single?127:1023;
    uint32_t maximum=single?255:2047;
    uint64_t payload=bits&(Bit(fraction)-1);
    uint32_t exponent=(uint32_t)(bits>>fraction)&maximum;
    RomFpParts p={0,(uint32_t)(bits>>(single?31:63)),0,0};
    if(exponent==maximum) {
        p.kind=payload?!!(payload&Bit(single?20:51)):4;p.mantissa=payload;
    } else if(exponent || payload) {
        p.kind=3;p.exponent=exponent?(int32_t)exponent-(int32_t)bias:1-(int32_t)bias;
        p.mantissa=payload<<round;
        if(exponent)p.mantissa|=Bit(fraction+round);
        else while(p.mantissa<Bit(fraction+round)) { p.mantissa<<=1;--p.exponent; }
    } else p.kind=2;
    return p;
}
RomFpParts RomUnpackDouble(uint64_t bits) { return Unpack(bits,0); }
RomFpParts RomUnpackFloat(uint32_t bits) { return Unpack(bits,1); }
/*08039D6C /0803AB08: gradual underflow truncates; normal results round to
 * nearest/even. Float quiet-NaN payload bit20 is the native library's choice. */
static uint64_t Pack(RomFpParts p,unsigned single)
{
    unsigned fraction=single?23:52,round=single?7:8;
    int bias=single?127:1023,min=1-bias;
    uint32_t maximum=single?255:2047,exponent=0;
    uint64_t mantissa=p.mantissa;
    if(single)mantissa=(uint32_t)mantissa;
    if(p.kind<2) { exponent=maximum;mantissa|=Bit(single?20:51); }
    else if(p.kind==4) { exponent=maximum;mantissa=0; }
    else if(p.kind==2 || !mantissa)mantissa=0;
    else {
        if(p.exponent<min) {
            int64_t distance=(int64_t)min-p.exponent;
            mantissa=distance<(single?26:57)?mantissa>>(unsigned)distance:0;
        } else if(p.exponent>bias) { exponent=maximum;mantissa=0; }
        else {
            exponent=p.exponent+bias;
            uint64_t half=Bit(round-1),mask=Bit(round)-1;
            if((mantissa&mask)==half) { if(mantissa&Bit(round))mantissa+=half; }
            else mantissa+=half-1;
            if(mantissa>=Bit(fraction+round+1)) { mantissa>>=1;++exponent; }
        }
        mantissa>>=round;
    }
    return ((uint64_t)p.sign<<(single?31:63))|((uint64_t)(exponent&maximum)<<fraction)|(mantissa&(Bit(fraction)-1));
}
uint64_t RomPackDouble(RomFpParts p) { return Pack(p,0); }
uint32_t RomPackFloat(RomFpParts p) { return (uint32_t)Pack(p,1); }
/*08039F8C /0803AC3C. Native helper returns an input/output pointer. The
 * portable API returns the selected value; native aliasing is not exposed. */
static RomFpParts AddParts(RomFpParts a,RomFpParts b,unsigned single)
{
    if(a.kind<2)return a;if(b.kind<2)return b;
    if(a.kind==4)return b.kind==4 && a.sign!=b.sign?Invalid(single):a;
    if(b.kind==4)return b;
    if(b.kind==2) { if(a.kind==2)a.sign&=b.sign;return a; }
    if(a.kind==2)return b;
    int64_t difference=(int64_t)a.exponent-b.exponent;
    if(difference>0) {
        if(difference>=(single?32:64))b.mantissa=0;
        else while(difference--)b.mantissa=(b.mantissa>>1)|(b.mantissa&1);
    } else {
        if(-difference>=(single?32:64))a.mantissa=0;
        else while(difference++)a.mantissa=(a.mantissa>>1)|(a.mantissa&1);
    }
    RomFpParts out={3,0,a.exponent>b.exponent?a.exponent:b.exponent,0};
    if(a.sign==b.sign) { out.sign=a.sign;out.mantissa=a.mantissa+b.mantissa; }
    else {
        uint64_t positive=a.sign?b.mantissa:a.mantissa,negative=a.sign?a.mantissa:b.mantissa;
        out.sign=positive<negative;out.mantissa=out.sign?negative-positive:positive-negative;
        while(out.mantissa && out.mantissa<Bit(single?30:60)) { out.mantissa<<=1;--out.exponent; }
    }
    if(out.mantissa>=Bit(single?31:61)) { out.mantissa=(out.mantissa>>1)|(out.mantissa&1);++out.exponent; }
    return out;
}
RomFpParts RomAddDoubleParts(RomFpParts a,RomFpParts b) { return AddParts(a,b,0); }
RomFpParts RomAddFloatParts(RomFpParts a,RomFpParts b) { return AddParts(a,b,1); }
/* Exact low/high product without requiring a host128-bit type. */
static void Product(uint64_t a,uint64_t b,uint64_t *low,uint64_t *high)
{
    uint64_t p0=(uint64_t)(uint32_t)a*(uint32_t)b,p1=(a>>32)*(uint32_t)b;
    uint64_t p2=(uint64_t)(uint32_t)a*(b>>32),p3=(a>>32)*(b>>32);
    uint64_t middle=(p0>>32)+(uint32_t)p1+(uint32_t)p2;
    *low=(middle<<32)|(uint32_t)p0;*high=p3+(p1>>32)+(p2>>32)+(middle>>32);
}
/*0803A260 /0803AE18: retain the native conditional low-half shift during
 * right normalization, even though an unconditional shift is more usual. */
static RomFpParts Multiply(RomFpParts a,RomFpParts b,unsigned single)
{
    uint32_t sign=!!(a.sign^b.sign);
    if(a.kind<2) { a.sign=sign;return a; }
    if(b.kind<2) { b.sign=sign;return b; }
    if((a.kind==4 && b.kind==2)||(a.kind==2 && b.kind==4))return Invalid(single);
    if(a.kind==4 || a.kind==2) { a.sign=sign;return a; }
    if(b.kind==4 || b.kind==2) { b.sign=sign;return b; }
    uint64_t low,high;
    unsigned width=single?32:64,normal=single?30:60,round=single?7:8;
    if(single) { uint64_t product=a.mantissa*b.mantissa;low=(uint32_t)product;high=product>>32; }
    else Product(a.mantissa,b.mantissa,&low,&high);
    RomFpParts out={3,sign,a.exponent+b.exponent+(single?2:4),0};
    while(high>=Bit(normal+1)) {
        if(high&1)low=(low>>1)|Bit(width-1);
        high>>=1;++out.exponent;
    }
    while(high<Bit(normal)) {
        high=(high<<1)|(low>>(width-1));low<<=1;
        if(single)low=(uint32_t)low;
        --out.exponent;
    }
    if((high&(Bit(round)-1))==Bit(round-1) && ((high&Bit(round)) || low))high+=Bit(round-1);
    out.mantissa=high;return out;
}
/*0803A508 /0803AF7C*/
static RomFpParts Divide(RomFpParts a,RomFpParts b,unsigned single)
{
    if(a.kind<2)return a;if(b.kind<2)return b;
    a.sign^=b.sign;
    if(a.kind==4 || a.kind==2)return a.kind==b.kind?Invalid(single):a;
    if(b.kind==4) { a.mantissa=0;a.exponent=0;return a; }
    if(b.kind==2) { a.kind=4;return a; }
    a.exponent-=b.exponent;
    if(a.mantissa<b.mantissa) { a.mantissa<<=1;--a.exponent; }
    uint64_t quotient=0;
    for(uint64_t bit=Bit(single?30:60);bit;bit>>=1) {
        if(a.mantissa>=b.mantissa) { quotient|=bit;a.mantissa-=b.mantissa; }
        a.mantissa<<=1;
    }
    unsigned round=single?7:8;
    if((quotient&(Bit(round)-1))==Bit(round-1) && ((quotient&Bit(round)) || a.mantissa))quotient+=Bit(round-1);
    a.mantissa=quotient;return a;
}
/*0803A690 /0803B068 and comparison wrappers. Results are -1/0/1, not
 * booleans. 3A854/3A8A0 and3B204/3B24C return-1 on unordered operands. */
static int Compare(RomFpParts a,RomFpParts b)
{
    if(a.kind<2 || b.kind<2)return 1;
    if(a.kind==4 && b.kind==4)return (int)b.sign-(int)a.sign;
    if(a.kind==4)return a.sign?-1:1;if(b.kind==4)return b.sign?1:-1;
    if(a.kind==2 && b.kind==2)return 0;
    if(a.kind==2)return b.sign?1:-1;if(b.kind==2)return a.sign?-1:1;
    if(a.sign!=b.sign)return a.sign?-1:1;
    int comparison=a.exponent>b.exponent?1:a.exponent<b.exponent?-1:a.mantissa>b.mantissa?1:a.mantissa<b.mantissa?-1:0;
    return a.sign?-comparison:comparison;
}
int RomCompareDoubleParts(RomFpParts a,RomFpParts b) { return Compare(a,b); }
int RomCompareFloatParts(RomFpParts a,RomFpParts b) { return Compare(a,b); }
#define OPERATIONS(Name,Type,Single) \
Type RomAdd##Name(Type x,Type y) { return (Type)Pack(AddParts(Unpack(x,Single),Unpack(y,Single),Single),Single); } \
Type RomSubtract##Name(Type x,Type y) { RomFpParts b=Unpack(y,Single);b.sign^=1;return (Type)Pack(AddParts(Unpack(x,Single),b,Single),Single); } \
Type RomMultiply##Name(Type x,Type y) { return (Type)Pack(Multiply(Unpack(x,Single),Unpack(y,Single),Single),Single); } \
Type RomDivide##Name(Type x,Type y) { return (Type)Pack(Divide(Unpack(x,Single),Unpack(y,Single),Single),Single); } \
Type RomNegate##Name(Type x) { RomFpParts p=Unpack(x,Single);p.sign=!p.sign;return (Type)Pack(p,Single); } \
int RomCompare##Name(Type x,Type y) { return Compare(Unpack(x,Single),Unpack(y,Single)); } \
int RomCompare##Name##UnorderedNegative(Type x,Type y) { RomFpParts a=Unpack(x,Single),b=Unpack(y,Single);return a.kind<2 || b.kind<2?-1:Compare(a,b); }
/*0803A1F8/3A228/3A260/3A508/3AA74/3A790/3A7BC/3A808/3A854/3A8A0/3A8EC/3A938*/
OPERATIONS(Double,uint64_t,0)
/*0803ADB8/3ADE4/3AE18/3AF7C/3B3EC/3B14C/3B174/3B1BC/3B204/3B24C/3B294/3B2DC*/
OPERATIONS(Float,uint32_t,1)
/*0803A984 /0803B324*/
static RomFpParts FromSigned(int32_t value,unsigned single)
{
    RomFpParts p={value?3:2,value<0,single?30:60,value<0?0u-(uint32_t)value:(uint32_t)value};
    if(value==INT32_MIN && single) { p.exponent=31;p.mantissa=Bit(30); }
    else if(value)while(p.mantissa<Bit(single?30:60)) { p.mantissa<<=1;--p.exponent; }
    return p;
}
uint64_t RomSignedToDouble(int32_t value) { return Pack(FromSigned(value,0),0); }
uint32_t RomSignedToFloat(int32_t value) { return (uint32_t)Pack(FromSigned(value,1),1); }
/*0803AA00 /0803B384*/
static int32_t ToSigned(RomFpParts p,unsigned single)
{
    if(p.kind<3 || (p.kind!=4 && p.exponent<0))return 0;
    if(p.kind==4 || p.exponent>=31)return p.sign?INT32_MIN:INT32_MAX;
    uint32_t magnitude=(uint32_t)(p.mantissa>>((single?30:60)-p.exponent));
    return (int32_t)(p.sign?0u-magnitude:magnitude);
}
int32_t RomDoubleToSigned(uint64_t bits) { return ToSigned(Unpack(bits,0),0); }
int32_t RomFloatToSigned(uint32_t bits) { return ToSigned(Unpack(bits,1),1); }
/*0803932C*/
uint32_t RomDoubleToUnsigned(uint64_t bits)
{
    if(RomCompareDoubleUnorderedNegative(bits,UINT64_C(0x41E0000000000000))<0)return (uint32_t)RomDoubleToSigned(bits);
    return (uint32_t)RomDoubleToSigned(RomAddDouble(bits,UINT64_C(0xC1E0000000000000)))+0x80000000u;
}
/*0803AAC4 /0803B428: payload shifts also apply to NaNs. */
uint32_t RomDoubleToFloat(uint64_t bits)
{ RomFpParts p=Unpack(bits,0);p.mantissa=(p.mantissa>>30)|!!(p.mantissa&0x3FFFFFFF);return (uint32_t)Pack(p,1); }
uint64_t RomFloatToDouble(uint32_t bits)
{ RomFpParts p=Unpack(bits,1);p.mantissa<<=30;return Pack(p,0); }
/*0803AA9C /0803B410*/
uint64_t RomMakeDouble(uint32_t kind,uint32_t sign,int32_t exponent,uint32_t low,uint32_t high)
{ RomFpParts p={kind,sign,exponent,low|((uint64_t)high<<32)};return Pack(p,0); }
uint32_t RomMakeFloat(uint32_t kind,uint32_t sign,int32_t exponent,uint32_t mantissa)
{ RomFpParts p={kind,sign,exponent,mantissa};return (uint32_t)Pack(p,1); }
