/* AY7E Exodia and Destiny Board conditions and presentation. */
#include "card_effects.h"
#include "duel_text.h"
extern uint8_t gDuelAuxiliaryFlags[2];
extern void FadeGameMusic(uint16_t);
/*08016D30 /08023114*/
uint8_t ExodiaPieceMask(uint16_t card) { return card>=17 && card<=21?1u<<(card-17):0; }
uint8_t DestinyBoardPieceMask(uint16_t card) { return card>=583 && card<=587?1u<<(card-583):0; }
/*08016D00 /080230E4*/
uint8_t ExodiaHandMask(void) { uint8_t mask=0;for(unsigned i=0;i<5;++i)mask|=ExodiaPieceMask(*gEffectBoardCells[4][i]);return mask; }
uint8_t DestinyBoardMask(void) { uint8_t mask=0;for(unsigned i=0;i<5;++i)mask|=DestinyBoardPieceMask(*gEffectBoardCells[3][i]);return mask; }
/*08016D78 /08023160*/
static void SpecialWin(uint8_t message)
{
    gDuelAuxiliaryFlags[GetActingSide()==0]=2;FadeGameMusic(4);
    struct DuelMessage m;InitializeDuelMessage(&m);m.index=message;PlayGameAudio(82);PresentDuelMessage(&m);
}
/*08016CE8 /080230CC*/
void CheckExodiaWin(void) { if((ExodiaHandMask()&31)==31)SpecialWin(17); }
void CheckDestinyBoardWin(void) { if((DestinyBoardMask()&31)==31)SpecialWin(18); }
