#ifndef AY7E_OVERWORLD_H
#define AY7E_OVERWORLD_H
#include <stdint.h>
void LoadSceneConfiguration(void);
void RunOverworld(void);
void RunOverworldInputLoop(void);
void RunCityMap(void);
void RunScriptNode(const void *node);
uint8_t ReadOverworldInput(void);
int8_t FindBlockingActor(uint8_t x,uint8_t y,uint8_t exclude);
uint8_t ClassifyActorStep(uint8_t x,uint8_t y,uint8_t direction,uint8_t actor);
void ResolveActorStep(uint8_t actor,uint8_t direction,int16_t delta[2]);
void MoveOverworldActor(uint8_t actor,uint8_t direction);
void WalkOverworldPlayer(uint8_t direction);
void RunOverworldPlayer(uint8_t direction);
void UpdateOverworldActors(void);
void InteractWithActor(uint8_t alternate);
void HandlePlayerSceneCell(void);
void UpdateWanderingActors(void);
void UpdateFollowerTrail(void);
void InitializeFollowerTrail(void);
uint8_t SceneHasFollower(void);
void FadeOverworld(uint8_t frames);
void ApplySceneTransitionFade(void);
void UpdateOverworldActorFrame(uint8_t actor);
#endif
