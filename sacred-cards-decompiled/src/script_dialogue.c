/* AY7E dialogue text/input states. Semantic C, not linked or matched.
 * Unsupported ASCII uses the caller's low16-bit script-state address as the
 * glyph, as native RunSceneScript keeps its state pointer in R4. */
#include "script_runtime.h"
#include <stddef.h>
#include "gba_bios.h"
extern uint16_t gKeysPressed; /* 0201FCAC */
extern uint8_t gPlayerName[]; /* 0201FC90 */
extern uint8_t gDialogueTiles[]; /* 0200DC00 */
extern const uint8_t gDialogueBlankLz[]; /* 082B26AC */
extern const uint8_t *const gAsciiGlyphCodes[]; /* 08D35FB8: starts at ASCII20 */
extern const uint32_t gChoiceGlyphNext[56],gDialogueGlyphNext[56]; /* 08D4EF4C / 08D4F02C */
extern uint8_t gCardMetadataBytes[0x1E];
extern void LoadCardMetadata(uint32_t);
extern uint16_t GetLanguageSegmentOffset(const uint8_t *);
extern void RenderBitmapGlyph(void *,uint16_t,uint16_t);
extern void PlayGameAudio(uint32_t);
extern void ResetScriptGlyphPosition(struct ScriptState *);

_Static_assert(offsetof(struct ScriptState,dirty)==0x33,"native script layout");
static uint16_t Read16(const uint8_t *p) { return p[0]|(uint16_t)p[1]<<8; }
static const uint8_t *CardName(void) {
    uint8_t *p=gCardMetadataBytes;uint32_t address=p[0]|(uint32_t)p[1]<<8|(uint32_t)p[2]<<16|(uint32_t)p[3]<<24;
    return (const uint8_t *)(uintptr_t)address;
}
/* Native BIOS wrapper08036934. Requires ARM Thumb target and GBA BIOS. */
static void ClearDialogueText(void) {
    BiosLz77UnpackWram(gDialogueBlankLz,gDialogueTiles);
}
static void DrawAt(uint32_t position,uint16_t glyph) {
    RenderBitmapGlyph(gDialogueTiles+((position&1)?0x40:0x20)+(position>>1)*0x80,glyph,0x101);
}
/* 08032428 */
void AdvanceScriptGlyph(struct ScriptState *s) {
    s->glyph_position=(s->choice_layout==1?gChoiceGlyphNext:gDialogueGlyphNext)[s->glyph_position];
}
static void FinishInput(struct ScriptState *s,unsigned bytes) {
    s->cursor+=bytes;ResetScriptGlyphPosition(s);s->wait_counter=0;s->state=0;ClearDialogueText();
}
/* 08032460: pre-increment timer is tested; held counters wrap as u16. */
void ScriptWaitForInput(struct ScriptState *s) {
    if(gKeysPressed&0x103) { PlayGameAudio(202);FinishInput(s,1);return; }
    uint16_t old=s->wait_counter++;
    if(old==0)DrawAt(s->glyph_position,0xA081);
    else if(old==15)DrawAt(s->glyph_position,0x4081);
    else if(old==29)s->wait_counter=0;
}
/* 08032534: two independent direction tests preserve simultaneous-key behavior. */
void ScriptChooseAnswer(struct ScriptState *s) {
    if(gKeysPressed&0x103) { s->branch_flags&=0x7F;PlayGameAudio(55);FinishInput(s,2);return; }
    if((gKeysPressed&0x60) && (s->branch_flags&0x7F)==1) { PlayGameAudio(54);s->branch_flags&=0x80; }
    if((gKeysPressed&0x90) && (s->branch_flags&0x7F)==0) { PlayGameAudio(54);s->branch_flags|=1; }
    unsigned first,second;switch(s->branch_flags) {
    case 0:first=0x720;second=0xA40;break;
    case 1:first=0x720;second=0xA40;break;
    case 0x80:first=0x20;second=0x720;break;
    case 0x81:first=0x20;second=0x720;break;
    default:return;
    }
    RenderBitmapGlyph(gDialogueTiles+first,(s->branch_flags&1)?0x4081:0x7281,0x101);
    RenderBitmapGlyph(gDialogueTiles+second,(s->branch_flags&1)?0x7281:0x4081,0x101);
}
static uint16_t DecodeNameGlyph(const uint8_t *p,uint8_t *index) {
    uint16_t code;if(*p&128) { code=Read16(p);*index+=2; }
    else { code=Read16(gAsciiGlyphCodes[*p-0x20]);++*index; }return code;
}
/* 08032690: player names do not go through the ordinary ASCII whitelist. */
void ScriptWritePlayerName(struct ScriptState *s) {
    s->dirty=1;uint16_t code=DecodeNameGlyph(gPlayerName+s->embedded_text_index,&s->embedded_text_index);
    DrawAt(s->glyph_position,code);AdvanceScriptGlyph(s);
    if(!gPlayerName[s->embedded_text_index])s->state=0;
}
/* 08032874: reload metadata only at index zero, then retain the global name pointer. */
void ScriptWriteCardName(struct ScriptState *s) {
    s->dirty=1;if(!s->embedded_text_index)LoadCardMetadata(s->card);
    s->embedded_text_index+=(uint8_t)GetLanguageSegmentOffset(CardName()+s->embedded_text_index);
    uint16_t code=DecodeNameGlyph(CardName()+s->embedded_text_index,&s->embedded_text_index);
    DrawAt(s->glyph_position,code);AdvanceScriptGlyph(s);
    uint8_t next=CardName()[s->embedded_text_index];if(!next || next=='$')s->state=0;
}
/* Glyph arm of08031E40, including unsupported inherited-register behavior. */
void ScriptWriteGlyph(struct ScriptState *s) {
    const uint8_t *p=s->text+s->cursor;uint16_t code;
    s->speaking=1;
    if(*p&128) { code=Read16(p);s->cursor+=2; }
    else {
        uint8_t c=*p;int supported=(c>='A' && c<='Z') || (c>='a' && c<='z');
        switch(c) { case ' ':case '!':case '"':case '%':case '\'':case ',':case '-':case '.':case ':':case ';':case '?':supported=1; }
        if(!supported) {
            /* Only direct caller08031DF6 inherits R4=script state. Unsupported
             * ASCII neither advances the cursor nor sets dirty. */
            DrawAt(s->glyph_position,(uint16_t)(uintptr_t)s);AdvanceScriptGlyph(s);return;
        }
        code=Read16(gAsciiGlyphCodes[c-0x20]);++s->cursor;
    }
    s->speaking=1;s->dirty=1;DrawAt(s->glyph_position,code);AdvanceScriptGlyph(s);
}
