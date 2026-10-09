#ifndef AY7E_AI_H
#define AY7E_AI_H
#include "card_effects.h"
struct AiAction { uint16_t kind;uint8_t cells[6]; };
extern struct AiAction gAiAction;
extern uint8_t *gDuelSideState[2];
extern uint8_t gDuelAuxiliaryFlags[2];
extern uint8_t gCardMetadataBytes[0x1E];
extern void LoadCardMetadata(uint32_t);
extern int32_t ClassifyDuelCard(uint16_t);
extern uint8_t RemainingMonsterTributes(uint16_t);
extern uint8_t CardCategoryRequirement(uint16_t);
extern uint8_t FindCardInDuelRow(uint16_t *const *,uint16_t);
extern uint32_t DuelRowContains(uint16_t *const *,uint16_t);
extern uint8_t FindThreeMaterials(uint8_t [3],const uint16_t [4]);
extern const uint16_t gRitualRecipes[30][4];
extern void CopyDuelCell(uint16_t *,const uint16_t *);
extern void ClearDuelCell(uint16_t *);
static inline uint8_t AiRow(unsigned operand) { return gAiAction.cells[operand]>>4; }
static inline uint8_t AiColumn(unsigned operand) { return gAiAction.cells[operand]&15; }
static inline uint16_t *AiCell(unsigned operand) { return gEffectBoardCells[AiRow(operand)][AiColumn(operand)]; }
static inline uint8_t *AiBytes(unsigned operand) { return (uint8_t *)AiCell(operand); }
void LockMonsterRow(uint8_t);
void ClearBattleDisplay(void);
uint8_t DuelHasEnded(void);
void PrepareDirectAttack(uint8_t);
void PrepareMonsterAttack(uint8_t,uint8_t);
void ApplyBattleDestruction(void);
#endif
