/* AY7E ^2 event dispatcher08033A14 and all58 event entry bodies08032D38..33A04.
 * Menu/duel subsystems reached by events remain external. Semantic C only. */
#include "script_runtime.h"
#include "script_actors.h"
extern uint8_t gRuntimeActors[][32],gSceneFlags,gProgressRank,gEventFlags[50];
extern uint16_t gSceneId,gSceneVariant,gSceneSpawn;
extern uint32_t GetDuelistLevel(void);
extern void ClearEventFlag(uint8_t *,uint32_t);
extern uint8_t TestEventFlag(const uint8_t *,uint32_t);
extern void HideDialogueWindow(void),ShowDialogueWindow(void),UpdateActorHeight(uint8_t),SelectRuntimeActorFrame(uint8_t),UpdateSceneActorFrame(void);
extern void WaitForFrame(void),PlayGameAudio(uint32_t),FadeGameMusic(uint16_t),StopEffectMusicPlayer(void),SaveCurrentGame(void);
extern void RestoreSceneDisplay(void),RunBuyShop(void),RunCredits(void),RunNameEntry(void),RunSellShop(void),RunPasswordFeature(void);
extern const int32_t gScriptMotionWords[196]; /* 08D4F124..08D4F434 */
struct SceneVariantRule { int16_t scene,variant,flags[8],replacement,padding; };
extern const struct SceneVariantRule gSceneVariantRules[]; /* 080FBB54 */
#define MOTION(address) (gScriptMotionWords+((address)-0x08D4F124u)/4)
static uint16_t Read16(const uint8_t *p) { return p[0]|(uint16_t)p[1]<<8; }
static void Write16(uint8_t *p,uint16_t n) { p[0]=(uint8_t)n;p[1]=(uint8_t)(n>>8); }
/* 08035AE4 */
void WaitForFrames(int32_t count) { while(count>0) { WaitForFrame();--count; } }
/* 08032A08: unlike @1, hides dialogue and selects the actor's current pose. */
void ScriptPositionActor(uint8_t actor,uint16_t x,uint16_t y,struct ScriptState *s) {
    s->dirty=0;HideDialogueWindow();Write16(gRuntimeActors[actor]+4,x);Write16(gRuntimeActors[actor]+6,y);
    UpdateActorHeight(actor);SelectRuntimeActorFrame(actor);UpdateSceneActorFrame();
}
/* 0802FD08 / 08031954. Rules can cascade because variant is replaced in-loop. */
void SelectScene(uint16_t scene,uint16_t variant,uint16_t spawn) { gSceneId=scene;gSceneVariant=variant;gSceneSpawn=spawn; }
void SelectSceneWithFlags(uint16_t scene,uint16_t variant,uint16_t spawn) {
    unsigned i=0;do {
        const struct SceneVariantRule *r=&gSceneVariantRules[i];
        if((uint16_t)r->scene==scene && (uint16_t)r->variant==variant) {
            int missing=0;for(unsigned f=0;f<8;++f)if(r->flags[f]!=-1 && !TestEventFlag(gEventFlags,(uint32_t)(int32_t)r->flags[f]))missing=1;
            if(!missing)variant=(uint16_t)r->replacement;
        }
        ++i;
    }while(gSceneVariantRules[i].scene!=-1);
    SelectScene(scene,variant,spawn);
}
static void ChangeScene(uint16_t scene,uint16_t variant,uint16_t spawn) { gSceneFlags|=2;SelectSceneWithFlags(scene,variant,spawn); }
static void DoorScene(uint16_t scene) { FadeGameMusic(1);WaitForFrames(8);PlayGameAudio(92);WaitForFrames(50);ChangeScene(scene,0,3); }
static void FollowMotion(uint8_t actor,const int32_t *x,const int32_t *y,const int32_t *termination,struct ScriptState *s,int extra_update) {
    unsigned i=0;do {
        ScriptPositionActor(actor,(uint16_t)(Read16(gRuntimeActors[actor]+4)+(uint32_t)x[i]),(uint16_t)(Read16(gRuntimeActors[actor]+6)+(uint32_t)y[i]),s);
        if(extra_update)UpdateSceneActorFrame();else WaitForFrames(1);
        ++i;
    }while(termination[i]!=127);
}
static void VanishActor(uint8_t actor,uint16_t x,uint16_t y,const int32_t *dx,const int32_t *dy,struct ScriptState *s) {
    s->dirty=0;HideDialogueWindow();WaitForFrames(96);ScriptPositionActor(actor,x,y,s);
    PlayGameAudio(209);WaitForFrames(96);PlayGameAudio(91);FollowMotion(actor,dx,dy,dx,s,0);
    WaitForFrames(96);ScriptPositionActor(actor,192,192,s);
}
/* 08019D0C/08019D24 and08033CEC/08033D08/08033D28. */
void DispatchScriptCondition(struct ScriptState *s,uint8_t kind) {
    if(kind==0) { s->branch_flags=0;if(GetDuelistLevel()<80)s->branch_flags=1; }
    else if(kind==1) { unsigned n=0,bits=gProgressRank;for(unsigned i=0;i<6;++i,bits>>=1)n+=bits&1;s->branch_flags=n==6; }
}
void DispatchScriptEvent(uint8_t event,struct ScriptState *s) {
    switch(event) {
    case 0: /* 08032D38 */
        FollowMotion(1,MOTION(0x08D4F124),MOTION(0x08D4F16C),MOTION(0x08D4F124),s,1);
        PlayGameAudio(93);ScriptPositionActor(1,448,192,s);break;
    case 1: /* 08032D9C: termination deliberately reads event0's X table. */
        FollowMotion(0,MOTION(0x08D4F1B4),MOTION(0x08D4F1C8),MOTION(0x08D4F124),s,1);
        PlayGameAudio(93);ScriptPositionActor(0,448,192,s);break;
    case 2:ChangeScene(38,7,0);break; /* 08032E0C */
    case 3:case 4:case 5:case 6:case 7:gProgressRank|=(uint8_t)(1u<<(event-2));break; /* 08032E30..60 */
    case 8:RunBuyShop();RestoreSceneDisplay();ShowDialogueWindow();break; /* 08032E6C */
    case 9:RunCredits();break; /* 08032E80 */
    case 10:RunNameEntry();SaveCurrentGame();RestoreSceneDisplay();break; /* 08032E8C */
    case 11:RunSellShop();RestoreSceneDisplay();ShowDialogueWindow();break; /* 08032EA0 */
    case 12: /* 08032EB4 */
        gRuntimeActors[1][2]=3;PlayGameAudio(94);ScriptPositionActor(1,74,40,s);WaitForFrames(96);PlayGameAudio(214);
        ScriptMoveActor(1,3,16,0,s);StopEffectMusicPlayer();ScriptMoveActor(1,1,0,0,s);WaitForFrames(96);
        gRuntimeActors[0][2]=3;PlayGameAudio(94);ScriptPositionActor(0,74,40,s);WaitForFrames(96);PlayGameAudio(214);
        ScriptMoveActor(0,3,8,0,s);StopEffectMusicPlayer();ScriptMoveActor(0,1,0,0,s);WaitForFrames(96);break;
    case 13:gSceneFlags|=2;SelectScene(1,3,0);break; /* 08032F5C: bypasses flag rules */
    case 14:ChangeScene(28,1,4);break; /* 08032F80 */
    case 15:ChangeScene(gSceneId,0,gSceneSpawn);break; /* 08032FA4 */
    case 16:PlayGameAudio(91);FollowMotion(3,MOTION(0x08D4F1DC),MOTION(0x08D4F204),MOTION(0x08D4F1DC),s,0);break; /* 08032FC8 */
    case 17:ClearEventFlag(gEventFlags,114);break; /* 08033030 */
    case 18:VanishActor(4,50,41,MOTION(0x08D4F22C),MOTION(0x08D4F254),s);break; /* 0803303C */
    case 19:DoorScene(19);break; /* 080330E0 */
    case 20:DoorScene(54);break; /* 0803311C */
    case 21:DoorScene(55);break; /* 08033158 */
    case 22:ChangeScene(30,1,4);break; /* 08033194 */
    case 23: /* 080331B8 */
        for(unsigned i=2;i<8;++i) { Write16(gRuntimeActors[i]+4,0);Write16(gRuntimeActors[i]+6,0);gRuntimeActors[i][28]&=0xDB; }break;
    case 24:RunPasswordFeature();RestoreSceneDisplay();break; /* 080331EC */
    case 25:ChangeScene(42,1,4);break; /* 080331FC */
    case 26:ChangeScene(40,1,4);break; /* 08033220 */
    case 27:VanishActor(3,60,32,MOTION(0x08D4F27C),MOTION(0x08D4F2A0),s);break; /* 08033244 */
    case 28:ChangeScene(42,2,4);break; /* 080332E8 */
    case 29:ChangeScene(53,0,0);break; /* 0803330C */
    case 30:ChangeScene(40,2,4);break; /* 08033330 */
    case 31:ChangeScene(42,3,4);break; /* 08033354 */
    case 32:ChangeScene(51,1,0);break; /* 08033378 */
    case 33:ChangeScene(42,4,4);break; /* 0803339C */
    case 34:ChangeScene(51,2,4);break; /* 080333C0 */
    case 35:ChangeScene(43,0,0);break; /* 080333E4 */
    case 36:break; /* 08033408 */
    case 37:VanishActor(3,60,32,MOTION(0x08D4F2C4),MOTION(0x08D4F2E8),s);break; /* 0803340C */
    case 38:VanishActor(3,60,32,MOTION(0x08D4F30C),MOTION(0x08D4F330),s);break; /* 080334B0 */
    case 39:DoorScene(41);break; /* 08033554 */
    case 40:DoorScene(49);break; /* 08033590 */
    case 41:DoorScene(42);break; /* 080335CC */
    case 42:ChangeScene(53,1,0);break; /* 08033608 */
    case 43:ChangeScene(45,1,0);break; /* 0803362C */
    case 44:ChangeScene(51,4,0);break; /* 08033650 */
    case 45:ChangeScene(23,3,0);break; /* 08033674 */
    case 46:ChangeScene(5,5,0);break; /* 08033698 */
    case 47:ChangeScene(57,0,0);break; /* 080336BC */
    case 48:ChangeScene(53,3,0);break; /* 080336E0 */
    case 49:ChangeScene(53,4,0);break; /* 08033704 */
    case 50:ChangeScene(42,5,0);break; /* 08033728 */
    case 51:ChangeScene(45,3,0);break; /* 0803374C */
    case 52:VanishActor(4,81,42,MOTION(0x08D4F354),MOTION(0x08D4F378),s);break; /* 08033770 */
    case 53:VanishActor(6,32,40,MOTION(0x08D4F39C),MOTION(0x08D4F3BC),s);break; /* 08033814 */
    case 54:ChangeScene(40,0,4);break; /* 080338B8 */
    case 55:ChangeScene(22,0,4);break; /* 080338DC */
    case 56: /* 08033900 */
        s->dirty=0;HideDialogueWindow();WaitForFrames(96);
        ScriptPositionActor(10,72,45,s);PlayGameAudio(209);WaitForFrames(16);
        ScriptPositionActor(11,68,37,s);PlayGameAudio(209);WaitForFrames(16);
        ScriptPositionActor(12,68,53,s);PlayGameAudio(209);WaitForFrames(16);
        ScriptPositionActor(1,48,46,s);PlayGameAudio(209);WaitForFrames(96);PlayGameAudio(91);
        FollowMotion(1,MOTION(0x08D4F3DC),MOTION(0x08D4F408),MOTION(0x08D4F3DC),s,0);
        ScriptPositionActor(10,192,192,s);ScriptPositionActor(11,192,192,s);ScriptPositionActor(12,192,192,s);
        WaitForFrames(96);ScriptPositionActor(1,192,192,s);break;
    case 57:RestoreSceneDisplay();ShowDialogueWindow();break; /* 08033A04 */
    }
}
