/* AY7E semantic reconstruction, not compiler-matched or execution-compared.
 * The parameterized state replaces separate original RAM globals; this struct
 * is not a native memory layout. See docs/game_logic.md for source addresses.
 */
#include <stdint.h>

struct Progression {
    uint32_t capacity;       /* original 0x02020C3C */
    uint32_t duelist_level;  /* original 0x02020C40 */
    uint8_t event_flags;     /* original 0x02020D5A */
};
extern const uint16_t gLevelCapacityThresholds[1000]; /* 0x080B3EC0 */
extern const uint16_t gInitialDeck[40];              /* 0x080EBAF0 */
extern const uint16_t gUntracedDeckPreset[40];        /* 0x080B4690 */

/* 0x0801411C has a side effect even before its caller increments the level. */
uint8_t CanRaiseDuelistLevel(struct Progression *p)
{
    if (p->duelist_level > 998) return 0;
    if (p->capacity < gLevelCapacityThresholds[p->duelist_level + 1]) return 0;
    p->event_flags |= 1;
    return 1;
}

/* 0x080140EC */
void UpdateDuelistLevel(struct Progression *p)
{
    while (CanRaiseDuelistLevel(p)) ++p->duelist_level;
}

/* 0x08014094. Preserve unsigned subtraction/addition of native instructions.
 * Normal game invariant: capacity <= 99999.
 */
void AddDeckCapacity(struct Progression *p, uint32_t amount)
{
    if (amount > 99999u - p->capacity) p->capacity = 99999;
    else p->capacity += amount;
    UpdateDuelistLevel(p);
}

/* 0x080140C0: subtraction does not recompute or lower Duelist Level. */
void SubtractDeckCapacity(struct Progression *p, uint32_t amount)
{
    p->capacity = amount > p->capacity ? 0 : p->capacity - amount;
}

/* 0x080140DC and 0x08014168, combined without changing other state. */
void InitializeProgressionValues(struct Progression *p)
{
    p->capacity = 1600;
    p->duelist_level = 72;
}

/* 0x08014424 writes the starting deck at RAM 0x02020C5A.
 * Called by initialization sequence 0x08006314.
 */
void InitializeDeck(uint16_t deck[40])
{
    for (unsigned i = 0; i < 40; ++i) deck[i] = gInitialDeck[i];
}

/* 0x08014174 writes a different preset at RAM 0x020233E4.
 * No direct caller in current listing; its game context is unresolved.
 */
void CopyUntracedDeckPreset(uint16_t deck[40])
{
    for (unsigned i = 0; i < 40; ++i) deck[i] = gUntracedDeckPreset[i];
}

/* Native-global adapters retain immediate writes to the original separate
 * variables. The parameterized routines above remain useful standalone views. */
extern uint32_t gDeckCapacity,gDuelistLevel;
extern uint8_t gProgressionFlags; /*02020D5A*/
void RefreshNativeDuelistLevel(void)
{
    while(gDuelistLevel<999 && gDeckCapacity>=gLevelCapacityThresholds[gDuelistLevel+1]) {
        gProgressionFlags|=1;++gDuelistLevel;
    }
}
void AddNativeDeckCapacity(uint32_t amount)
{
    if(amount>99999u-gDeckCapacity)gDeckCapacity=99999;else gDeckCapacity+=amount;
    RefreshNativeDuelistLevel();
}
/*08014088*/
uint32_t GetDeckCapacity(void) { return gDeckCapacity; }
