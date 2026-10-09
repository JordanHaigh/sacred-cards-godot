#ifndef AY7E_DUEL_TEXT_H
#define AY7E_DUEL_TEXT_H
#include <stdint.h>
struct DuelTextState {
    uint32_t cursor,glyph_position;
    uint8_t state,padding[3];
    const uint8_t *text;
    uint16_t blink,working,card,other,number,other_number;
    uint8_t index;
};
struct DuelMessage { uint16_t card,other,number,unused;uint8_t index; };
/* R8 is an implicit input in the original no-space card-name wrap path. */
void WriteDuelCardNameWithContext(struct DuelTextState *,uint32_t inherited_r8);
void RunDuelTextWithContext(struct DuelTextState *,uint32_t inherited_r8);
void PresentDuelTextWithContext(const uint8_t *,uint16_t,uint16_t,uint16_t,uint16_t,uint32_t inherited_r8);
void PresentDuelText(const uint8_t *,uint16_t,uint16_t,uint16_t,uint16_t);
void PresentDuelEffect(uint16_t,uint16_t);
void PresentImmuneTrap(uint16_t,uint16_t);
void PresentDuelStatusText(uint8_t);
void UploadDuelText(void);
void InitializeDuelMessage(struct DuelMessage *);
void PresentDuelMessage(const struct DuelMessage *);
#endif
