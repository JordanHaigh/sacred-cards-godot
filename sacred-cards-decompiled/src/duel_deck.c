/* AY7E deck draw and turn restriction helpers. Native physical hand/deck
 * records are kept distinct from relative board pointers. Semantic C only. */
#include "ai.h"
extern uint8_t gAbsoluteDuelHands[2][5][8]; /* 02023200 */
extern uint8_t gDuelDeckRecords[2][84];    /* 02023390 */
/* 08027300: only writes the card ID, retaining the cell's other bytes. */
void PopDuelDeckCard(uint16_t *cell,uint8_t side)
{
    uint8_t *deck=gDuelDeckRecords[side];uint8_t index=--deck[80];
    *cell=deck[index*2]|(uint16_t)deck[index*2+1]<<8;
}
/* 08027330: a full hand does not consume a card or trigger deck-out. */
void DrawDuelCard(uint8_t side)
{
    for(unsigned i=0;i<5;++i) {
        uint8_t *cell=gAbsoluteDuelHands[side][i];
        if(!(cell[0]|cell[1])) {
            if(gDuelDeckRecords[side][80])PopDuelDeckCard((uint16_t *)cell,side);
            else gDuelAuxiliaryFlags[side]=2;
            return;
        }
    }
}
/* 080244E8 */
void SetDuelAttackRestriction(uint8_t side) { gDuelSideState[side][2]|=3; }
