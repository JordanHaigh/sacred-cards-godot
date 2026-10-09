#ifndef AY7E_SCRIPT_ACTORS_H
#define AY7E_SCRIPT_ACTORS_H
#include "script_runtime.h"
void ScriptMoveActor(uint8_t,uint8_t,uint8_t,uint8_t,struct ScriptState *);
void ScriptPlaceActor(uint8_t,uint16_t,uint16_t,uint16_t,struct ScriptState *);
void ScriptActorPoseFour(uint8_t,struct ScriptState *);
void ScriptChangeActorSprite(uint8_t,uint8_t,struct ScriptState *);
void ScriptMoveActorToX(uint8_t,uint8_t,struct ScriptState *);
void ScriptMoveActorToY(uint8_t,uint8_t,struct ScriptState *);
void ScriptFadeToDark(uint8_t);
void SelectRuntimeActorFrame(uint8_t);
#endif
