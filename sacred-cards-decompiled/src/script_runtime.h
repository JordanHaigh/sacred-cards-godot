#ifndef AY7E_SCRIPT_RUNTIME_H
#define AY7E_SCRIPT_RUNTIME_H
#include <stdint.h>

/* Native offsets assume a 32-bit ARM build. */
struct ScriptNode;
struct ScriptState {
    uint16_t portrait, unknown02;
    uint32_t cursor, glyph_position;
    uint8_t state, choice_layout, unknown0e[2];
    const uint8_t *text;
    const struct ScriptNode *next_false, *next_true;
    uint16_t wait_counter;
    uint8_t branch_flags, unknown1f;
    uint16_t card, unknown22, unknown24;
    uint8_t embedded_text_index, unknown27;
    int16_t blink_index, blink_ticks, mouth_index, mouth_ticks;
    uint16_t speaking;
    uint8_t portrait_flags, dirty;
};
struct ScriptNode {
    const uint8_t *text;
    const struct ScriptNode *next_false, *next_true;
};

void DispatchSceneToken(struct ScriptState *);
#endif
