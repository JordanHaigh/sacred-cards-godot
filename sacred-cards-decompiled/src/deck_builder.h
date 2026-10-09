#ifndef AY7E_DECK_BUILDER_H
#define AY7E_DECK_BUILDER_H
#include <stdint.h>
/* Native persistent deck:40 card IDs at02020C5A. Menu state at02020C50
 * stores cost:u32, selection:s8, sort:u8, detail:u8, sort_popup:u8, count:u8. */
uint32_t PlayerDeckCost(void);
uint8_t PlayerDeckCount(void);
uint16_t PlayerDeckCardAt(uint8_t visible_row);
uint8_t CountPlayerDeckCard(uint16_t card);
void RecalculatePlayerDeckCost(void);
void RefreshPlayerDeckState(void);
uint8_t DeckAllowsAnotherCopy(uint16_t card);
uint8_t PlayerDeckIsFull(void);
uint8_t PlayerDeckFitsCapacity(void);
void MovePlayerDeckSelection(uint8_t amount,uint8_t down);
void AddSelectedCollectionCardToDeck(void);
void RemoveSelectedCollectionCardFromDeck(void);
void RemoveSelectedDeckCard(void);
void SortPlayerDeck(uint8_t method,uint8_t reset_selection);
void InitializeCollectionList(void);
void SortWagerList(void);
void RunDeckManagement(void);
void ShowPlayerStatus(void);
void RunCollectionEditor(void);
void RunDeckEditor(void);
void DispatchCollectionStateCommand(uint8_t command);
void DispatchDeckStateCommand(uint8_t command);
void DrawCollectionEditorGraphics(uint8_t stage);
void DrawDeckEditorGraphics(uint8_t stage);
void DeckEditorDisplayFrame(uint8_t stage);
#endif
