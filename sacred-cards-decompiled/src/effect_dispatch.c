/* AY7E indirect card-handler dispatch. Semantic C, not linked/matched.
 * All metadata-1A/1B entry bodies have maintained C; native helper dependencies
 * remain. C dispatch tables are generated from semantic_handlers.json.
 */
#include <stdint.h>
extern void LoadCardMetadata(uint32_t card_id); /* 0x08006BE4 */
extern uint8_t gCardMetadataBytes[0x1E];         /* RAM 0x02020B00 */
extern uint16_t gCardHandlerInput;              /* RAM 0x02023478 */
extern void (*const gMetadata1bHandlers[85])(void);  /* ROM 0x080FB79C */
extern void (*const gMetadata1aHandlers[132])(void); /* ROM 0x080FB900 */

/* 0x080285E8; valid metadata indices are a native caller precondition. */
void DispatchMetadata1bHandler(void)
{
    LoadCardMetadata(gCardHandlerInput);
    gMetadata1bHandlers[gCardMetadataBytes[0x1B]]();
}
/* 0x0802B33C reads a different input record at RAM 0x02023480. */
extern uint16_t gMetadata1aHandlerInput;
void DispatchMetadata1aHandler(void)
{
    LoadCardMetadata(gMetadata1aHandlerInput);
    gMetadata1aHandlers[gCardMetadataBytes[0x1A]]();
}
