/* AY7E scene lifecycle0802FD18..0803032C, overworld input/animation
 *08030720..08030D7C and transition fades08031060..08031144.
 * Native byte truncation, actor flag preservation and input priority retained. */
#include "overworld.h"
#include "scene_data.h"
#include "gba_bios.h"
extern uint8_t gRuntimeActors[][32],gSceneFlags,gEventFlags[50];
extern uint16_t gSceneId,gSceneVariant,gSceneSpawn,gKeysPressed,gKeysHeld,gKeysRepeated;
extern const uint16_t *gSceneGrid;
extern const void *gSceneEntryScript,*gSceneExitScript;
extern uint8_t gCityMapOrigin,gCityMapSelection,gCityUnlockProgress;
extern const uint8_t *const gActorSheets[];
extern const uint16_t gActorFrameTileOffsets[],gActorDestinationTiles[];
extern uint8_t gActorGraphicsBuffer[];
extern void RunNameEntry(void),RunDeckManagement(void),RestoreSceneDisplay(void),RestoreScenePreview(void),RestoreActorsAfterPortrait(void);
extern void SelectSceneWithFlags(uint16_t,uint16_t,uint16_t),SelectScene(uint16_t,uint16_t,uint16_t);
extern uint8_t TestEventFlag(const uint8_t *,uint32_t);
extern void SetEventFlag(uint8_t *,uint32_t),UpdateActorHeight(uint8_t),SelectRuntimeActorFrame(uint8_t),UpdateSceneActorFrame(void);
extern void CopyActorFrame(const uint8_t *,uint16_t,uint8_t *),PlaySceneMusic(uint16_t,uint16_t),PlayGameAudio(uint32_t),FadeGameMusic(uint16_t),WaitForFrame(void),WaitFrames(int32_t);
#define ROM(a) ((const uint8_t *)(uintptr_t)(a))
#define REG(a) (*(volatile uint16_t *)(uintptr_t)(a))
static uint16_t U16(const uint8_t *p) { return p[0]|(uint16_t)p[1]<<8; }
static uint32_t U32(const uint8_t *p) { return U16(p)|(uint32_t)U16(p+2)<<16; }
static void W16(uint8_t *p,uint16_t n) { p[0]=n;p[1]=n>>8; }
static void W32(uint8_t *p,uint32_t n) { W16(p,n);W16(p+2,n>>16); }
/*0802FD18. NPC records terminate withFFFF, rather than a separate count.*/
void LoadSceneConfiguration(void)
{
    gSceneGrid=(const uint16_t *)(uintptr_t)U32(ROM(0x08D51870)+gSceneId*4);
    const SceneConfiguration *c=(const SceneConfiguration *)(uintptr_t)U32(ROM(U32(ROM(0x08D548B8)+gSceneId*4))+gSceneVariant*4);
    gSceneEntryScript=(const void *)(uintptr_t)c->scene_script_a;gSceneExitScript=(const void *)(uintptr_t)c->scene_script_b;
    unsigned actor=1;
    for(unsigned i=0;c->actors[i].actor_id!=-1;++i,++actor) {
        const SceneActor *s=&c->actors[i];uint8_t *a=gRuntimeActors[actor];
        W16(a,s->actor_id);a[2]=s->orientation_raw;W16(a+4,s->x);W16(a+6,s->y);W16(a+8,0);UpdateActorHeight(actor);
        W32(a+16,s->script_a);W32(a+20,s->script_b);a[12]=19;a[28]=(a[28]&0xC0)|(s->flags_raw&31);W16(a+26,0);
    }
    for(;actor<15;++actor) { uint8_t *a=gRuntimeActors[actor];W16(a,0xFFFF);a[2]=0;W16(a+4,192);W16(a+6,192);W16(a+8,0);a[28]&=0xDB; }
    const SceneActor *s=&c->player_spawns[gSceneSpawn];uint8_t *p=gRuntimeActors[0];
    W16(p,s->actor_id);p[2]=s->orientation_raw;W32(p+16,s->script_a);p[12]=19;p[24]=0;p[28]|=7;W16(p+4,s->x);W16(p+6,s->y);UpdateActorHeight(0);
    if(SceneHasFollower()==1) {
        uint8_t *a=gRuntimeActors[14];W16(a,1);a[2]=p[2];W16(a+4,U16(p+4));W16(a+6,U16(p+6));W32(a+16,0x08DE502C);W32(a+20,0x08DE502C);a[28]=(a[28]&0xFB)|0x21;UpdateActorHeight(14);InitializeFollowerTrail();
    }
}
/*080300E0/300F4*/
void InitializeOverworldScene(void) { SelectSceneWithFlags(28,0,4);LoadSceneConfiguration(); }
void TransitionOverworldScene(void)
{
    if(!(gSceneFlags&4))ApplySceneTransitionFade();
    else {
        static const uint16_t milestones[]={249,250,251,252,247,253,254,255,248};gCityUnlockProgress=0;
        for(unsigned i=0;i<9;++i)if(TestEventFlag(gEventFlags,milestones[i]))gCityUnlockProgress=i+1;
        gCityMapOrigin=gSceneId;gSceneFlags&=0xFB;FadeOverworld(4);RunCityMap();
        const uint8_t *p=ROM(0x08D4C6E0)+gCityMapSelection*6;SelectSceneWithFlags(U16(p),U16(p+2),U16(p+4));
    }
    LoadSceneConfiguration();
}
/*0803022C*/
void RunOverworld(void)
{
    if(!TestEventFlag(gEventFlags,43)) { RunNameEntry();SetEventFlag(gEventFlags,43); }
    InitializeOverworldScene();gSceneFlags&=0xFE;
    do {
        TransitionOverworldScene();RestoreSceneDisplay();gSceneFlags&=0xFD;RunScriptNode(gSceneEntryScript);
        if(!(gSceneFlags&2)) { PlaySceneMusic(gSceneId,gSceneVariant);RunOverworldInputLoop();RunScriptNode(gSceneExitScript); }
    }while(!(gSceneFlags&1));
}
/*08030720: A/R interaction wins over movement; B movement wins over walking.*/
uint8_t ReadOverworldInput(void)
{
    if(gKeysPressed&1)return 6;if(gKeysPressed&0x100)return 5;
    if(gKeysHeld&2) { if(gKeysHeld&0x40)return 11;if(gKeysHeld&0x80)return 12;if(gKeysHeld&0x20)return 13;if(gKeysHeld&0x10)return 14; }
    if(gKeysHeld&0x40)return 1;if(gKeysHeld&0x80)return 2;if(gKeysHeld&0x20)return 3;if(gKeysHeld&0x10)return 4;
    if(gKeysRepeated&0x20C)return 7;return 0;
}
/*080307E0: cases8/10 remain from the native dispatch, although the stock
 *input reader cannot select them. They cycle actor and scene previews.*/
void RunOverworldInputLoop(void)
{
    uint8_t preview=0;static const uint8_t direction[]={2,0,1,3};
    while(!(gSceneFlags&3)) {
        gRuntimeActors[0][24]=0;unsigned input=ReadOverworldInput();
        if(input>=1 && input<=4)WalkOverworldPlayer(direction[input-1]);
        else if(input>=11 && input<=14)RunOverworldPlayer(direction[input-11]);
        else switch(input) {
        case 5:InteractWithActor(1);UpdateSceneActorFrame();continue;
        case 6:InteractWithActor(0);UpdateSceneActorFrame();continue;
        case 7:PlayGameAudio(55);RunDeckManagement();RestoreSceneDisplay();PlaySceneMusic(gSceneId,gSceneVariant);continue;
        case 8:W16(gRuntimeActors[0],ROM(0x08D4C78D)[(int16_t)U16(gRuntimeActors[0])]);RestoreActorsAfterPortrait();continue;
        case 10:preview=ROM(0x08D4C751)[preview];SelectScene(preview,0,0);LoadSceneConfiguration();RestoreScenePreview();UpdateSceneActorFrame();continue;
        default:UpdateWanderingActors();UpdateOverworldActors();continue;
        }
        UpdateWanderingActors();UpdateFollowerTrail();UpdateOverworldActors();
    }
}
/*08030914/30940/30960/30974 and08030620. Running uses sheets89/90.*/
void UpdateOverworldActorFrame(uint8_t actor)
{
    uint8_t *a=gRuntimeActors[actor];
    if(a[24]==1) { SelectRuntimeActorFrame(actor);if(!a[12] || a[12]>20)a[12]=20;--a[12]; }
    else if(a[24]==2) {
        unsigned frame=a[2]*3+ROM(0x08D4C737)[a[12]];
        CopyActorFrame(gActorSheets[actor?90:89],gActorFrameTileOffsets[frame],gActorGraphicsBuffer+gActorDestinationTiles[actor]*32u);
        if(!a[12])a[12]=26;--a[12];
    }else { a[12]=19;SelectRuntimeActorFrame(actor); }
}
/*08030D40*/
void UpdateOverworldActors(void)
{
    UpdateOverworldActorFrame(0);if(gRuntimeActors[14][28]&32) { gRuntimeActors[14][24]=gRuntimeActors[0][24];UpdateOverworldActorFrame(14); }UpdateSceneActorFrame();
}
/*08031060*/
void FadeOverworld(uint8_t frames)
{
    REG(0x04000000)=0x1C00;REG(0x04000050)=0xFC;FadeGameMusic(frames);
    for(unsigned level=0;level<16;++level) { REG(0x04000054)=level;for(unsigned i=0;i<frames;++i)WaitForFrame(); }
}
/*080310B8: table terminator is checked after advancing past the first pair.*/
void ApplySceneTransitionFade(void)
{
    const uint8_t *p=ROM(0x08D4C7F4);
    while(gSceneId!=U32(p) || gSceneSpawn!=U32(p+4)) {
        p+=8;if(U32(p)==0xFFFFFFFFu) {
            if(gSceneId==41 && !gSceneSpawn) { FadeOverworld(1);PlayGameAudio(216);WaitFrames(100); }
            else if(gSceneId==23 && gSceneSpawn==1) { FadeOverworld(1);PlayGameAudio(217);WaitFrames(100); }
            return;
        }
    }FadeOverworld(1);
}
