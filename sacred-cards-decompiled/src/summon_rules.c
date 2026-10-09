/* AY7E tribute requirement queries. Semantic C reviewed against the instruction
 * listing; not execution-compared or compiler-matched. Does not implement the
 * whole summon action, board selection, ritual effects, or opponent AI.
 */
#include <stdint.h>
extern void LoadCardMetadata(uint32_t card);
extern uint8_t gCardMetadataBytes[0x1E];    /* 02020B00 */
extern const int8_t gCardTypeClasses[24];   /* 08D4BD48 */
extern const int8_t gTributesByLevel[13];   /* 08D4C6D0: levels 0..12 */
extern const uint8_t gCategoryRequirements[]; /* 080BA25C, metadata byte 1D */
extern uint8_t gTributesCommitted;          /* 02023448 */

/* 08023C34: signed classification, with card ID zero handled before loading. */
int32_t ClassifyDuelCard(uint16_t card)
{
    if (card == 0) return 0;
    LoadCardMetadata(card);
    return gCardTypeClasses[gCardMetadataBytes[0x16]];
}
void ResetTributesCommitted(void) { gTributesCommitted = 0; } /* 08028378 */
void IncrementTributesCommitted(void) { ++gTributesCommitted; } /* 08028384 */

/* 08028394: category 1 only. The loader is called again after classification,
 * preserving the native call order and metadata global side effects.
 */
uint8_t RemainingMonsterTributes(uint16_t card)
{
    if (ClassifyDuelCard(card) != 1) return 0;
    LoadCardMetadata(card);
    int32_t remaining = gTributesByLevel[gCardMetadataBytes[0x18]] - gTributesCommitted;
    return (uint8_t)(remaining < 0 ? 0 : remaining);
}

/* 08018150 and 080283DC: category 4 uses a separate metadata-indexed table. */
uint8_t CardCategoryRequirement(uint16_t card)
{
    LoadCardMetadata(card);
    return gCategoryRequirements[gCardMetadataBytes[0x1D]];
}
uint8_t RemainingCategoryFourRequirement(uint16_t card)
{
    if (ClassifyDuelCard(card) != 4) return 0;
    int32_t remaining = CardCategoryRequirement(card) - gTributesCommitted;
    return (uint8_t)(remaining < 0 ? 0 : remaining);
}

/* 08028414: unlike the remaining-count query, this does not classify the card. */
int32_t CardTributeRequirement(uint16_t card)
{
    LoadCardMetadata(card);
    return gTributesByLevel[gCardMetadataBytes[0x18]];
}
