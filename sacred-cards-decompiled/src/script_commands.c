/* AY7E 08031E40 command dispatch. All 27 #/@/^ forms are represented here;
 * actor/duel/rendering helpers are maintained in their respective modules. The glyph
 * path calls ScriptWriteGlyph in script_dialogue.c. Valid ROM streams are a precondition;
 * native code has no length bounds. Not execution-compared or compiler-matched.
 */
#include "script_runtime.h"
#include "script_actors.h"
extern uint8_t gEventFlags[50];
extern void SetEventFlag(uint8_t *, uint32_t);
extern uint8_t TestEventFlag(const uint8_t *, uint32_t);
extern uint16_t GetLanguageSegmentOffset(const uint8_t *);
extern const uint8_t gChoiceLinePositions[]; /* 08D4EF48 */
extern uint16_t gScriptOpponent;            /* 02020D40 */
extern uint8_t gDuelOutcome;                /* 02020D59 */
extern uint16_t gPlayerCellX, gPlayerCellY;   /* 0202349C, 0202349E */
extern uint16_t ReadSceneCell(uint8_t x, uint8_t y);
extern void PlayGameAudio(uint32_t);
extern void ScriptWriteGlyph(struct ScriptState *);
extern void LoadDialoguePortrait(struct ScriptState *);
extern void RunPreDuelMenu(void);
extern void RunDuel(void);
extern void RestoreSceneDisplay(void);
extern void ShowDialogueWindow(void);
extern void AddCollectionCard(uint16_t card, uint8_t count);
extern void SaveCurrentGame(void);
extern void FadeGameMusic(uint16_t);
extern void WaitForFrame(void);
extern void DispatchScriptCondition(struct ScriptState *, uint8_t);
extern void StopEffectMusicPlayer(void);
extern void DispatchScriptEvent(uint8_t, struct ScriptState *);
extern void HideDialogueWindow(void);

static uint16_t ReadOperand16(const uint8_t *p)
{
    return (uint16_t)(p[0] | (uint16_t)p[1] << 8);
}
void DispatchSceneToken(struct ScriptState *s)
{
    uint8_t prefix = s->text[s->cursor];
    if (prefix == '$') {
        s->cursor += GetLanguageSegmentOffset(s->text + s->cursor);
        return;
    }
    if (prefix != '#' && prefix != '@' && prefix != '^') {
        ScriptWriteGlyph(s); /* recovered glyph path; invalid ASCII retains native fallback */
        return;
    }
    ++s->cursor; /* Native dispatch leaves cursor pointing to the subcommand. */
    uint8_t command = s->text[s->cursor];
    const uint8_t *p = s->text + s->cursor + 1;
    if (prefix == '#') {
        switch (command) {
        case '0':
            ++s->cursor;
            if (s->choice_layout == 1) {
                s->glyph_position = gChoiceLinePositions[s->glyph_position / 28];
            } else if (s->branch_flags & 0x80) {
                s->glyph_position = s->glyph_position == 0 ? 1 : 29;
            } else if (s->glyph_position <= 28) s->glyph_position = 29;
            else if (s->glyph_position <= 41) s->glyph_position = 42;
            else s->glyph_position = 1;
            return;
        case '1':
            s->speaking = 0;
            s->state = 1; /* subcommand consumed by the input handler later */
            return;
        case '2': {
            s->choice_layout = 0;
            s->branch_flags = 0;
            ++s->cursor;
            s->glyph_position = 0;
            uint32_t scan = 2;
            while (s->text[s->cursor + scan] != '#') {
                scan += (s->text[s->cursor + scan] & 0x80) ? 2 : 1;
                ++s->glyph_position;
            }
            if (s->glyph_position > 11) s->branch_flags |= 0x80;
            s->glyph_position = 0;
            return;
        }
        case '3':
            s->speaking = 0; s->choice_layout = 1; s->state = 3;
            ++s->cursor; return;
        case '4':
            s->dirty = 1; s->portrait = p[0]; s->portrait_flags = p[1];
            LoadDialoguePortrait(s); s->cursor += 3; return;
        case '5':
            s->embedded_text_index = 0; s->state = 4; ++s->cursor; return;
        case '6': SetEventFlag(gEventFlags, p[0]); s->cursor += 2; return;
        case '7': s->branch_flags = TestEventFlag(gEventFlags, p[0]); s->cursor += 2; return;
        case '8':
            RunPreDuelMenu();
            gScriptOpponent = s->text[s->cursor + 1];
            RunDuel();
            if (gDuelOutcome == 1) {
                s->branch_flags = 0; RestoreSceneDisplay(); ShowDialogueWindow();
            } else s->branch_flags = 1;
            s->cursor += 2; s->portrait = 0; return;
        case '9': AddCollectionCard(ReadOperand16(p), 1); s->cursor += 3; return;
        default: return;
        }
    }
    if (prefix == '@') {
        switch (command) {
        case '0': ScriptMoveActor(p[0],p[1],p[2],p[3],s); s->cursor += 5; return;
        case '1': ScriptPlaceActor(p[0],p[1],p[2],p[3],s); s->cursor += 5; return;
        case '2': SaveCurrentGame(); ++s->cursor; return;
        case '3': FadeGameMusic(ReadOperand16(p)); s->cursor += 3; return;
        case '4': ScriptMoveActorToX(p[0],p[1],s); s->cursor += 3; return;
        case '5': ScriptMoveActorToY(p[0],p[1],s); s->cursor += 3; return;
        case '6': ScriptActorPoseFour(p[0],s); s->cursor += 2; return;
        case '7':
            for (uint32_t frames=p[0]; frames; --frames) WaitForFrame();
            s->cursor += 2; return;
        case '8':
            if (p[0] != 111 && p[0] != 122 && p[0] != 123) PlayGameAudio(p[0]);
            s->cursor += 2; return;
        case '9':
            s->branch_flags = (uint8_t)ReadSceneCell((uint8_t)gPlayerCellX,(uint8_t)gPlayerCellY)
                              != s->text[s->cursor + 1];
            s->cursor += 2; return;
        default: return;
        }
    }
    switch (command) {
    case '0': DispatchScriptCondition(s,p[0]); s->cursor += 2; return;
    case '1': StopEffectMusicPlayer(); ++s->cursor; return;
    case '2': DispatchScriptEvent(p[0],s); s->cursor += 2; return;
    case '3': ScriptFadeToDark(p[0]); s->cursor += 2; return;
    case '4': s->dirty=0; HideDialogueWindow(); ++s->cursor; return;
    case '5': ScriptChangeActorSprite(p[0],p[1],s); s->cursor += 3; return;
    case '6': s->cursor += 2; return;
    default: return;
    }
}
