#ifndef AY7E_CARD_EFFECTS_H
#define AY7E_CARD_EFFECTS_H
#include <stdint.h>

struct EffectInput { uint16_t card; uint8_t row, column, source_row, source_column; };
struct TrapInput { uint16_t card; uint8_t row, column, slot, kind; };
struct MonsterInput { uint16_t card;uint8_t row,column; };
extern struct MonsterInput gMonsterInput; /* 02023478 */
extern struct EffectInput gSpellInput;       /* 02023480 */
extern struct TrapInput gTrapInput;          /* 020237D0 */
extern uint8_t gSuppressEffectPresentation;  /* 02020C38 */
extern uint8_t gTerrain;                     /* 02023250 */
extern uint16_t *gEffectBoardCells[5][5];     /* 02023270, pointer grid */
extern void DiscardDuelCell(uint16_t *cell, uint8_t side);
extern void LoadDuelTerrain(uint8_t terrain);
#include "duel_text.h"
extern void PlayGameAudio(uint32_t id);
extern uint8_t FindActivatingTrap(void);
extern void ActivateSelectedTrap(uint16_t amount);
extern uint8_t GetActingSide(void);         /* byte at 020237D8 */
extern void PrepareHealSideA(uint16_t amount); /* numerical battle operation 7 */
extern void PrepareHealSideB(uint16_t amount); /* numerical battle operation 10 */
extern void PrepareDamageSideA(uint16_t amount); /* numerical battle operation 8 */
extern void PrepareDamageSideB(uint16_t amount); /* numerical battle operation 9 */
extern void ResolveCurrentBattleNumbers(void);
extern void ApplyBattleDefeatFlags(void);


#endif
