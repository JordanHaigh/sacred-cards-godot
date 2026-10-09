/* AY7E language selection and bitmap glyph rendering. Semantic C only.
 * ROM text streams and destinations satisfy the native size preconditions. */
#include <stdint.h>
extern uint8_t gLanguage; /* 02020D18 */
extern const uint8_t gSmallFontBitmap[]; /* 08D2AAEA: ten bytes per glyph */
extern const uint8_t gLargeFontBitmap[]; /* 08D2CA66: eighteen bytes per glyph */
/* 08016DB4 / 08016F40. Offset wraps independently of the scan pointer. */
static const uint8_t *SelectLanguage(const uint8_t *p,uint16_t *offset)
{
    *offset=0;if(*p!='$')return p;
    for(;;) {
        ++p;++*offset;uint8_t tag=*p;
        if(tag>='0' && tag<='5') {
            if(gLanguage==tag-'0') { ++*offset;return p+1; }
            while(*p!='$') { unsigned n=(*p&128)?2:1;p+=n;*offset=(uint16_t)(*offset+n); }
        }else if(tag=='6') { ++*offset;return p+1; }
        /* Unrecognized tags advance one byte, as the native switch default. */
    }
}
uint16_t GetLanguageSegmentOffset(const uint8_t *p) { uint16_t n;SelectLanguage(p,&n);return n; }
const uint8_t *GetLanguageSegmentPointer(const uint8_t *p) { uint16_t n;return SelectLanguage(p,&n); }
/* 080178B0 */
uint16_t GetBitmapGlyphIndex(uint16_t code)
{
    if(code<0x8140)code=0x8140;
    uint16_t original=code-0x8140,value=original;
    if(original>0x400)value-=0x200;
    if(original>0x700)value-=0x100;
    if(original>0x5F00)value-=0x4000;
    uint16_t index=value-(value>>8)*68;
    if((value&255)>0x3F)--index;
    return index;
}
/* 08017934 / 08017A28: bit 7 is ignored, seven bitmap pixels followed by zero. */
static uint32_t GlyphRow4(uint8_t bits)
{
    uint32_t n=0;for(unsigned x=0;x<7;++x)n|=(uint32_t)((bits>>(6-x))&1)<<(x*4);return n;
}
static void Glyph4(const uint8_t *src,uint32_t *dst,unsigned blocks)
{
    for(unsigned b=0;b<blocks;++b)for(unsigned y=0;y<8;++y)dst[b*16+y]=GlyphRow4(src[b*8+y]);
}
/* 0801798C */
static void Glyph8(const uint8_t *src,uint8_t *dst,uint8_t ink)
{
    for(unsigned y=0;y<8;++y) { for(unsigned x=0;x<7;++x)dst[y*8+x]=((src[y]>>(6-x))&1)?ink:0;dst[y*8+7]=0; }
}
/* 08017AF8 / 08017B20: use the previous unmodified row, including across tiles. */
static void ShadowGlyph(uint32_t *dst,unsigned blocks)
{
    uint32_t previous=dst[0];
    for(unsigned b=0;b<blocks;++b)for(unsigned y=b?0:1;y<8;++y) {
        unsigned index=b*16+y;uint32_t current=dst[index];
        dst[index]=((previous<<4)&~current)<<1|current;previous=current;
    }
}
/* 08017088 plus 080177D0/17808/17840/17878 dispatch. Input glyph is byte swapped.
 * Native mode 0500 writes zeroes despite its font lookup; confirmed at 08017A98.
 * Native bold mode 1800 widens only the first seven rows before shadowing. */
void RenderBitmapGlyph(void *destination,uint16_t encoded,uint16_t mode)
{
    uint16_t code=(encoded<<8)|(encoded>>8);uint32_t *dst=destination;
    switch(mode&0x1F00) {
    case 0x000:Glyph4(gSmallFontBitmap+GetBitmapGlyphIndex(code)*10,dst,1);break;
    case 0x100:Glyph4(gLargeFontBitmap+GetBitmapGlyphIndex(code)*18,dst,2);break;
    case 0x400:Glyph8(gSmallFontBitmap+GetBitmapGlyphIndex(code)*10,destination,(uint8_t)mode);break;
    case 0x500:
        for(unsigned b=0;b<2;++b)for(unsigned i=0;i<16;++i)dst[b*32+i]=0;
        break;
    case 0x800:Glyph4(gSmallFontBitmap+GetBitmapGlyphIndex(code)*10,dst,1);ShadowGlyph(dst,1);break;
    case 0x900:Glyph4(gLargeFontBitmap+GetBitmapGlyphIndex(code)*18,dst,2);ShadowGlyph(dst,2);break;
    case 0x1800:
        Glyph4(gSmallFontBitmap+GetBitmapGlyphIndex(code)*10,dst,1);
        for(unsigned y=0;y<7;++y)dst[y]|=dst[y]<<4;
        ShadowGlyph(dst,1);break;
    }
}

extern const uint8_t *const gAsciiGlyphCodes[]; /* literal ASCII20..7F view08D35FB8 */
/* 0801715C. Two-tile glyphs interleave successive characters with strides
 *32/96 or64/192 bytes. This path also supports bold-only mode1000, which the
 *single-glyph dispatcher08017088 does not handle. */
void RenderBitmapString(void *destination,const uint8_t *text,uint16_t mode)
{
    const uint8_t *p=GetLanguageSegmentPointer(text);uint8_t *dst=destination;unsigned odd=0;
    unsigned format=mode&0x1F00;
    if(format!=0 && format!=0x100 && format!=0x400 && format!=0x500 &&
       format!=0x800 && format!=0x900 && format!=0x1000 && format!=0x1800)return;
    while(*p && *p!='$') {
        uint16_t encoded;
        if(*p&128) { encoded=p[0]|(uint16_t)p[1]<<8;p+=2; }
        else { const uint8_t *code=gAsciiGlyphCodes[*p-32];encoded=code[0]|(uint16_t)code[1]<<8;++p; }
        if(format==0x1000) {
            RenderBitmapGlyph(dst,encoded,0);uint32_t *rows=(uint32_t *)dst;
            for(unsigned y=0;y<7;++y)rows[y]|=rows[y]<<4;
        } else RenderBitmapGlyph(dst,encoded,mode);
        if(format==0x100 || format==0x900) { dst+=odd?96:32;odd^=1; }
        else if(format==0x500) { dst+=odd?192:64;odd^=1; }
        else dst+=format==0x400?64:32;
    }
}

extern uint8_t gDecimalDigits[5]; /* 02020C00 */
/* 08008ECC. Unsigned16-bit input; FFFF renders blank unless flag2 fills zeroes.
 * Flag1 packs significant digits at the left; digit10 is the blank marker. */
void FormatDecimalDigits(uint16_t number,uint8_t flags)
{
    for(unsigned i=0;i<5;++i)gDecimalDigits[i]=10;
    if(number!=65535) {
        unsigned compact=flags&1,pos=0,divisor=10000;if(compact)gDecimalDigits[0]=0;
        for(unsigned i=0;i<5;++i) {
            unsigned digit=number/divisor;
            if(digit || (pos && gDecimalDigits[pos-1]!=10))gDecimalDigits[pos]=digit;
            else if(pos==4)gDecimalDigits[4]=0;
            if(digit)++pos;
            else if(!pos) { if(!compact)pos=1; }
            else if(gDecimalDigits[pos-1]!=10 || !compact)++pos;
            number=(uint16_t)(number-divisor*digit);divisor/=10;
        }
    }
    if(flags&2)for(unsigned i=0;i<5;++i)if(gDecimalDigits[i]==10)gDecimalDigits[i]=0;
}

extern uint8_t gMoneyDigits[19]; /* 02020C10 */
/* 08008FD8: the native formatter reserves nineteen positions. The callers
 * constrain money below 10^19; a general uint64_t can give a first digit >9. */
void FormatMoneyDigits(uint64_t number,uint8_t flags)
{
    for(unsigned i=0;i<19;++i)gMoneyDigits[i]=10;
    unsigned compact=flags&1,pos=0;if(compact)gMoneyDigits[0]=0;
    uint64_t divisor=UINT64_C(1000000000000000000);
    for(unsigned i=0;i<19;++i) {
        uint64_t digit=number/divisor;
        if(digit || (pos && gMoneyDigits[pos-1]!=10))gMoneyDigits[pos]=(uint8_t)digit;
        else if(pos==18)gMoneyDigits[18]=0;
        if(digit)++pos;
        else if(!pos) { if(!compact)pos=1; }
        else if(gMoneyDigits[pos-1]!=10 || !compact)++pos;
        number-=divisor*digit;divisor/=10;
    }
    if(flags&2)for(unsigned i=0;i<19;++i)if(gMoneyDigits[i]==10)gMoneyDigits[i]=0;
}
