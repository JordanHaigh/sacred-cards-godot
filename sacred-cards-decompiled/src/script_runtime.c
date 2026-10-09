/* AY7E script scheduler, node transitions and portrait animation. Reconstructed
 * from 08031AA8/08031D84/0803244C/08032744/080327AC. Command effects and several
 * rendering states are implemented in the companion script modules.
 * Not execution-compared, compiler-matched or linked into the ROM.
 */
#include <stdint.h>

#include "script_runtime.h"
#include "gba_bios.h"

extern const int16_t gBlinkDurations[30]; /* 0817578C */
extern const uint16_t gBlinkFrames[30];  /* 081757C8 */
extern const int16_t gMouthDurations[4]; /* 08D4F10C */
extern const uint16_t gMouthFrames[4];   /* 08D4F114 */
extern void ComposePortraitPart(struct ScriptState *, uint8_t part, uint8_t frame,
                          uint16_t color_mode, uint16_t priority);
extern void ScriptWaitForInput(struct ScriptState *); /* wait-for-input */
extern void ScriptWriteCardName(struct ScriptState *); /* card name */
extern void ScriptChooseAnswer(struct ScriptState *); /* choice */
extern void ScriptWritePlayerName(struct ScriptState *); /* player name */
extern void ShowDialogueWindow(void);                /* dialogue display registers */
extern void WaitForFrame(void);                /* frame/update wait */
extern void UploadDialogueFrame(void);                /* graphics upload */
extern void ExitSceneDialogue(struct ScriptState *); /* dialogue exit */

void LoadScriptNode(struct ScriptState *s, const struct ScriptNode *node)
{
    s->text = node->text;
    s->next_false = node->next_false;
    s->next_true = node->next_true;
}
void ResetScriptGlyphPosition(struct ScriptState *s)
{
    s->glyph_position = s->choice_layout != 1;
}
void UpdatePortraitBlink(struct ScriptState *s)
{
    if (s->portrait == 0) return;
    s->blink_ticks = (int16_t)(s->blink_ticks - 1);
    if (s->blink_ticks != 0) return;
    s->blink_ticks = (int16_t)(gBlinkDurations[s->blink_index] * 4);
    ComposePortraitPart(s, 0, (uint8_t)gBlinkFrames[s->blink_index], 1, 1);
    s->blink_index = (int16_t)(s->blink_index - 1);
    if (s->blink_index == -1) s->blink_index = 29;
}
void UpdatePortraitMouth(struct ScriptState *s)
{
    if (s->portrait == 0) return;
    s->mouth_ticks = (int16_t)(s->mouth_ticks - 1);
    if (s->mouth_ticks != 0) return;
    s->mouth_ticks = (int16_t)(gMouthDurations[s->mouth_index] * (s->speaking ? 1 : 4));
    ComposePortraitPart(s, 1, (uint8_t)gMouthFrames[s->mouth_index], 1, 1);
    s->mouth_index = (int16_t)(s->mouth_index - 1);
    if (s->mouth_index == -1) {
        if (s->speaking) s->mouth_index = 3;
        else { s->mouth_index = 0; s->mouth_ticks = 1; }
    }
}
void RunSceneScript(struct ScriptState *s)
{
    for (;;) {
        if (s->text[s->cursor] == 0) {
            LoadScriptNode(s, s->branch_flags == 0 ? s->next_false : s->next_true);
            s->cursor = 0;
            s->branch_flags = 0;
            ResetScriptGlyphPosition(s);
        }
        if (s->text[0] == 'Z') break;
        UpdatePortraitBlink(s);
        UpdatePortraitMouth(s);
        switch (s->state) {
        case 0: DispatchSceneToken(s); break;
        case 1: ScriptWaitForInput(s); break;
        case 2: ScriptWriteCardName(s); break;
        case 3: ScriptChooseAnswer(s); break;
        case 4: ScriptWritePlayerName(s); break;
        }
        if (s->dirty == 1) ShowDialogueWindow();
        WaitForFrame();
        UploadDialogueFrame();
    }
    ExitSceneDialogue(s);
}

/*08031A48/31B0C. Only fields written by the native initializer are set here;
 *card/portrait_flags and padding are supplied by their script commands. */
extern uint8_t gDialogueTiles[],gDialogueMap[];
extern const uint8_t gDialogueBlankLz[],gDialogueInitialMap[];
extern void UploadDialogueInitialFrame(void);
void InitializeScriptDialogue(void)
{
    BiosLz77UnpackWram(gDialogueBlankLz,gDialogueTiles);BiosCpuSet(gDialogueInitialMap,gDialogueMap,0x280);
    WaitForFrame();UploadDialogueInitialFrame();
}
void RunScriptNode(const void *node)
{
    struct ScriptState s;
    s.portrait=0;s.cursor=0;s.branch_flags=0;s.glyph_position=0;s.state=0;s.choice_layout=1;
    s.wait_counter=0;s.embedded_text_index=0;s.unknown22=0;s.unknown24=0;
    s.blink_index=29;s.blink_ticks=1;s.mouth_index=3;s.mouth_ticks=1;s.speaking=0;s.dirty=0;
    LoadScriptNode(&s,node);InitializeScriptDialogue();RunSceneScript(&s);
    s.portrait=0;s.cursor=0;s.glyph_position=0;
}
