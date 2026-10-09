#ifndef AY7E_BATTLE_H
#define AY7E_BATTLE_H
#include <stdint.h>
struct BattleSide {
    uint16_t attack,defense,life_points;
    uint8_t attribute,owner;
};
struct BattleResolution {
    struct BattleSide a,b;
    uint8_t flags,result;
};
void ResolveBattleNumbers(struct BattleResolution *,uint8_t);
#endif
