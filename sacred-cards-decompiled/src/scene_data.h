#ifndef SACRED_CARDS_SCENE_DATA_H
#define SACRED_CARDS_SCENE_DATA_H
#include <stddef.h>
#include <stdint.h>

/* Recovered from accesses in Thumb 0x0802FD18; script fields hold GBA addresses.
 * Actor names, orientation encoding, and script command semantics remain open.
 */
typedef struct {
    int16_t actor_id;
    uint8_t orientation_raw;
    uint8_t reserved;
    int16_t x;
    int16_t y;
    uint32_t script_a;
    uint32_t script_b;
    uint32_t flags_raw;
} SceneActor;

typedef struct {
    SceneActor actors[16]; /* Active list terminates at actor_id == -1. */
    uint32_t scene_script_a;
    uint32_t scene_script_b;
    SceneActor player_spawns[5];
} SceneConfiguration;

_Static_assert(sizeof(SceneActor) == 20, "actor layout");
_Static_assert(offsetof(SceneConfiguration, scene_script_a) == 0x140, "script layout");
_Static_assert(offsetof(SceneConfiguration, player_spawns) == 0x148, "spawn layout");
_Static_assert(sizeof(SceneConfiguration) == 428, "scene layout");

uint16_t SceneCellAt(const uint16_t *grid, uint8_t x, uint8_t y);
uint32_t SceneCellTestBaseFlag(uint16_t cell);
uint32_t SceneCellTestBit8(uint16_t cell);
uint32_t SceneCellSelectEventClass(uint16_t cell);
#endif
