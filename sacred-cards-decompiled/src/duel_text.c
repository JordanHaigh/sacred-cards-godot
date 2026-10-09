/* AY7E duel text VM08024F2C..080257C4. Semantic reconstruction, not linked
 * or execution-compared. Requires valid native strings, card IDs and numeric
 * substitutions below65535. The inherited-R8 name-wrap edge is an explicit
 * input exposed by the WithContext API; no fabricated zero/default is used. */
#include "duel_text.h"
#include "gba_bios.h"
#include <stddef.h>
extern uint8_t gBackgroundBuffer[],gPlayerName[],gCardMetadataBytes[0x1E],gDecimalDigits[5];
extern uint8_t gDuelRawCardName[112],gDuelWrappedCardName[112]; /*0201EE78/0201EEE8*/
extern uint16_t gKeysPressed;
extern const uint8_t *const gAsciiGlyphCodes[];
extern void RenderBitmapString(void *,const uint8_t *,uint16_t),RenderBitmapGlyph(void *,uint16_t,uint16_t);
extern void LoadCardMetadata(uint32_t),FormatDecimalDigits(uint16_t,uint8_t);
extern uint16_t GetLanguageSegmentOffset(const uint8_t *);
extern void WaitForFrame(void),RestoreDuelDisplay(void),PlayGameAudio(uint32_t);
/* Legacy convenience entry points use this integration-owned context.
 * WithContext entry points expose the native implicit register input directly.
 * German names325/771 can consume it; normal names overwrite it with a space. */
extern uint32_t gDuelTextInheritedR8;
#define ROM(a) ((const uint8_t *)(uintptr_t)(a))
#define REG16(a) (*(volatile uint16_t *)(uintptr_t)(a))
_Static_assert(offsetof(struct DuelTextState,index)==0x1C,"native duel text layout");
static uint16_t Read16(const uint8_t *p) { return p[0]|(uint16_t)p[1]<<8; }
static const uint8_t *ReadPointer(const uint8_t *p)
{ return ROM(p[0]|(uint32_t)p[1]<<8|(uint32_t)p[2]<<16|(uint32_t)p[3]<<24); }
static void CopyString(uint8_t *out,const uint8_t *in) { do { *out++=*in; }while(*in++); }
static uint8_t *GlyphDestination(uint32_t position)
{ return gBackgroundBuffer+0x88A0+(position>>1)*128+(position&1)*32; }
static void DrawNext(struct DuelTextState *s,uint16_t code)
{ RenderBitmapGlyph(GlyphDestination(s->glyph_position),code,0x101);++s->glyph_position; }
static void ClearText(void) { RenderBitmapString(gBackgroundBuffer+0x88A0,ROM(0x08D4BEBD),0x101); }
/*08024E50*/
void UploadDuelText(void)
{
    BiosCpuSet(gBackgroundBuffer+0x87A0,(void *)0x060087A0,0x04000740);
    BiosCpuSet(gBackgroundBuffer+0xE800,(void *)0x0600E800,0x04000120);
}
/*08024FE8: each native row copies64 bytes from a60-byte source stride.*/
void InitializeDuelTextDisplay(void)
{
    for(unsigned row=0;row<18;++row)BiosCpuSet(ROM(0x080E7720)+row*60,gBackgroundBuffer+0xE800+row*64,0x04000010);
    RenderBitmapString(gBackgroundBuffer+0x87A0,ROM(0x08D4BEAC),0x801);ClearText();
    WaitForFrame();UploadDuelText();REG16(0x0400004A)=0x1E;REG16(0x04000042)=0x03ED;REG16(0x04000046)=0x438D;
    WaitForFrame();*(volatile uint8_t *)0x04000049=0x36;REG16(0x04000054)=7;REG16(0x04000000)=0x7600;
}
/*0802510C: unsupported ASCII draws glyph zero without advancing the cursor.*/
void StepDuelText(struct DuelTextState *s)
{
    const uint8_t *p=s->text+s->cursor;uint8_t c=*p;
    if(c=='$') { s->cursor+=GetLanguageSegmentOffset(p);return; }
    if(c=='#') {
        ++s->cursor;
        switch(s->text[s->cursor]) {
        case '0':++s->cursor;s->glyph_position=(s->glyph_position/28+1)*28;if(s->glyph_position>84)s->glyph_position=84;break;
        case '1':s->state=1;break;
        case '2':case '3':s->state=2;s->working=s->text[s->cursor]=='2'?s->card:s->other;s->index=0;++s->cursor;break;
        case '5':s->state=4;s->index=0;++s->cursor;break;
        case '6':case '7':s->state=5;s->working=s->text[s->cursor]=='6'?s->number:s->other_number;s->index=0;++s->cursor;break;
        }
        return;
    }
    uint16_t code=0;
    if(c&128) { code=Read16(p);s->cursor+=2; }
    else {
        unsigned supported=(c>='A' && c<='Z') || (c>='a' && c<='z');
        switch(c) { case ' ':case '!':case '"':case '%':case '\'':case ',':case '-':case '.':case ':':case ';':case '?':supported=1; }
        if(supported) { code=Read16(gAsciiGlyphCodes[c-32]);++s->cursor; }
    }
    DrawNext(s,code);
}
/*080253F4*/
void WaitDuelTextInput(struct DuelTextState *s)
{
    if(gKeysPressed&0x103) { PlayGameAudio(202);++s->cursor;s->glyph_position=0;s->blink=0;s->state=0;ClearText();return; }
    uint16_t old=s->blink++;
    if(old==0 || old==15)RenderBitmapGlyph(GlyphDestination(s->glyph_position),old?0x4081:0xA081,0x101);
    else if(old==29)s->blink=0;
}
static void NameGlyph(struct DuelTextState *s,const uint8_t *name)
{
    const uint8_t *p=name+s->index;uint16_t code;
    if(*p&128) { code=Read16(p);s->index+=2; }
    else { code=Read16(gAsciiGlyphCodes[*p-32]);++s->index; }
    DrawNext(s,code);if(!name[s->index])s->state=0;
}
/*080254CC. The native wrap threshold is26, while line width is28.*/
void WriteDuelCardNameWithContext(struct DuelTextState *s,uint32_t inherited_r8)
{
    if(!s->index) {
        LoadCardMetadata(s->working);
        for(unsigned i=0;i<112;++i)gDuelRawCardName[i]=gDuelWrappedCardName[i]=0;
        const uint8_t *name=ReadPointer(gCardMetadataBytes);uint16_t at=GetLanguageSegmentOffset(name);
        uint16_t bytes=0,glyphs=0,space_byte=0;uint32_t space_glyph=0;unsigned found_space=0;
        while(name[at] && name[at]!='$') {
            uint8_t c=name[at];
            if(c&128) { gDuelRawCardName[bytes++]=c;++at; }
            else if(c==' ' && glyphs<28) { space_byte=bytes;space_glyph=glyphs;found_space=1; }
            gDuelRawCardName[bytes++]=name[at++];++glyphs;
        }
        if(glyphs<26)CopyString(gDuelWrappedCardName,gDuelRawCardName);
        else {
            if(!found_space)space_glyph=inherited_r8;
            gDuelRawCardName[space_byte]=0;CopyString(gDuelWrappedCardName,gDuelRawCardName);
            uint16_t suffix=space_byte+1;
            for(;space_glyph<28;space_glyph=(uint16_t)(space_glyph+1))gDuelWrappedCardName[space_byte++]=' ';
            CopyString(gDuelWrappedCardName+space_byte,gDuelRawCardName+suffix);
        }
    }
    NameGlyph(s,gDuelWrappedCardName);
}
/*0802568C /0802572C*/
void WriteDuelPlayerName(struct DuelTextState *s) { NameGlyph(s,gPlayerName); }
void WriteDuelNumber(struct DuelTextState *s)
{
    if(!s->index) { FormatDecimalDigits(s->working,0);while(gDecimalDigits[s->index]==10)++s->index; }
    DrawNext(s,Read16(ROM(0x08D4BF30)+gDecimalDigits[s->index]*2));if(++s->index==5)s->state=0;
}
/*08025098 /08024F2C*/
void RunDuelTextWithContext(struct DuelTextState *s,uint32_t inherited_r8)
{
    while(s->text[s->cursor]) {
        switch(s->state) {
        case 0:StepDuelText(s);break;case 1:WaitDuelTextInput(s);break;
        case 2:WriteDuelCardNameWithContext(s,inherited_r8);break;case 4:WriteDuelPlayerName(s);break;case 5:WriteDuelNumber(s);break;
        }
        WaitForFrame();UploadDuelText();
    }
}
void PresentDuelTextWithContext(const uint8_t *text,uint16_t card,uint16_t other,uint16_t number,uint16_t other_number,uint32_t inherited_r8)
{
    struct DuelTextState s;s.cursor=0;s.glyph_position=0;s.state=0;s.text=text;s.blink=0;
    s.card=card;s.other=other;s.number=number;s.other_number=other_number;s.index=0;
    InitializeDuelTextDisplay();RunDuelTextWithContext(&s,inherited_r8);RestoreDuelDisplay();
}
/*08024F64 /08024F94 /08024FC0*/
void PresentDuelEffect(uint16_t card,uint16_t other) { PresentDuelText(ReadPointer(ROM(0x08DFC054)+card*4),card,other,0,0); }
void PresentImmuneTrap(uint16_t card,uint16_t other) { PresentDuelText(ROM(0x08D4C178),card,other,0,0); }
void PresentDuelStatusText(uint8_t index) { PresentDuelText(ReadPointer(ROM(0x08D4C168)+index*4),0,0,0,0); }
/*08017F44 /08017E74*/
void InitializeDuelMessage(struct DuelMessage *m) { m->card=m->other=m->number=m->unused=0;m->index=255; }
void PresentDuelMessage(const struct DuelMessage *m)
{ if(m->index!=255)PresentDuelText(ReadPointer(ROM(0x08D36130)+m->index*4),m->card,m->other,m->number,0); }

/* Portable adapters for callers which bind the inherited register context. */
void WriteDuelCardName(struct DuelTextState *s) { WriteDuelCardNameWithContext(s,gDuelTextInheritedR8); }
void RunDuelText(struct DuelTextState *s) { RunDuelTextWithContext(s,gDuelTextInheritedR8); }
void PresentDuelText(const uint8_t *text,uint16_t card,uint16_t other,uint16_t number,uint16_t other_number)
{ PresentDuelTextWithContext(text,card,other,number,other_number,gDuelTextInheritedR8); }
