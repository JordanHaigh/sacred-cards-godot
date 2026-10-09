/* AY7E overworld movement/collision080311D8..08031954, wander/follower
 *08030E58..08031060. Byte coordinates, signed16 actor positions, flag-bit
 *conditions and ordered collision probes are retained. */
#include "overworld.h"
#include "scene_data.h"
extern uint8_t gRuntimeActors[][32],gSceneFlags,gEventFlags[50],gFollowerTrail[80],gWorldMovementState[3];
extern uint16_t gSceneId,gSceneVariant,gOamBuffer[128][4];
extern uint16_t ReadSceneCell(uint8_t,uint8_t);
extern uint8_t TestEventFlag(const uint8_t *,uint32_t);
extern uint32_t RandomByteInclusive(uint32_t,uint32_t);
extern void UpdateActorHeight(uint8_t),SelectRuntimeActorFrame(uint8_t),UpdateSceneActorFrame(void),UploadDialogueFrame(void),PlayGameAudio(uint32_t);
extern void SelectSceneWithFlags(uint16_t,uint16_t,uint16_t);
#define ROM(a) ((const uint8_t *)(uintptr_t)(a))
static uint16_t U16(const uint8_t *p) { return p[0]|(uint16_t)p[1]<<8; }
static uint32_t U32(const uint8_t *p) { return U16(p)|(uint32_t)U16(p+2)<<16; }
static void W16(uint8_t *p,uint16_t n) { p[0]=n;p[1]=n>>8; }
static int16_t Offset(uint32_t table,uint8_t direction) { return (int16_t)U16(ROM(table)+direction*2); }
/*080314B4: no active-ID check; sentinel actors lie outside normal coordinates.
 *Player collision excludes actors with bit5 set; NPC collision does not.*/
int8_t FindBlockingActor(uint8_t x,uint8_t y,uint8_t exclude)
{
    for(unsigned i=0;i<15;++i)if(i!=exclude && (exclude!=0 || !(gRuntimeActors[i][28]&32))) {
        int dy=(int)y-(int16_t)U16(gRuntimeActors[i]+6),dx=(int)x-(int16_t)U16(gRuntimeActors[i]+4);
        if(dy>-5 && dy<5 && dx>-7 && dx<7)return i;
    }return -1;
}
/*08031238/3125C: the first free terrain probe wins; all three blocked =>0.*/
uint8_t ClassifyActorStep(uint8_t x,uint8_t y,uint8_t direction,uint8_t actor)
{
    if(!x || x>119 || !y || y>79 || FindBlockingActor(x,y,actor)!=-1)return 0;
    for(unsigned i=0;i<3;++i) {
        uint8_t px=x+ROM(0x08D4C9B0)[i*8+direction*2],py=y+ROM(0x08D4C9C8)[i*8+direction*2];
        if(SceneCellTestBaseFlag(ReadSceneCell(px,py))!=1)return i+1;
    }return 0;
}
/*08031354: R3 retains the actor index across the omitted fourth draft argument.*/
void ResolveActorStep(uint8_t actor,uint8_t direction,int16_t delta[2])
{
    uint8_t *a=gRuntimeActors[actor];delta[0]=Offset(0x08D4C9A0,direction);delta[1]=Offset(0x08D4C9A8,direction);
    unsigned result=ClassifyActorStep(a[4]+delta[0],a[6]+delta[1],direction,actor);
    if(!result) { a[24]=0;delta[0]=delta[1]=0; }
    else { a[24]=1;if(result>1) { delta[0]+=Offset(result==2?0x08D4C9B8:0x08D4C9C0,direction);delta[1]+=Offset(result==2?0x08D4C9D0:0x08D4C9D8,direction); } }
}
/*08031698/306A8. Native interpolation reads the consecutive low/high BYTES
 *of the new X halfword as x/y, rather than the Y halfword at+2.*/
static void UpdateMovementOam(const uint8_t old[2],const uint8_t *position)
{
    uint16_t *o=gOamBuffer[0];o[2]|=0xC00;if(!(U16(gRuntimeActors[0]+10)&0x100))o[2]=(o[2]&0xF3FF)|0x800;
    int8_t dx=(position[0]-old[0])*2,dy=(position[1]-old[1])*2-(int16_t)U16(gRuntimeActors[0]+8);
    uint8_t x=old[0]*2+dx,y=old[1]*2+dy;o[0]=(o[0]&0xFF00)|(uint8_t)(y-24);o[1]=(o[1]&0xFE00)|((x-16)&0x1FF);
}
/*08031438*/
void MoveOverworldActor(uint8_t actor,uint8_t direction)
{
    uint8_t *a=gRuntimeActors[actor],old[2]={a[4],a[6]};int16_t delta[2];a[2]=direction;ResolveActorStep(actor,direction,delta);
    W16(a+4,U16(a+4)+delta[0]);W16(a+6,U16(a+6)+delta[1]);W16(a+10,ReadSceneCell(a[4],a[6]));UpdateActorHeight(actor);UpdateMovementOam(old,a+4);
}
/*08031A0C*/
static void RecordPlayerMovement(void)
{
    if(gRuntimeActors[0][24]==1 && !SceneCellTestBaseFlag(ReadSceneCell(gRuntimeActors[0][4],gRuntimeActors[0][6]))) {
        gWorldMovementState[0]=gWorldMovementState[1]=0;gWorldMovementState[2]=1;
    }
}
/*080318BC/318E8/318FC*/
void HandlePlayerSceneCell(void)
{
    uint16_t cell=ReadSceneCell(gRuntimeActors[0][4],gRuntimeActors[0][6]);unsigned kind=SceneCellSelectEventClass(cell);
    if(kind==1) { gSceneFlags|=2;SelectSceneWithFlags((uint8_t)cell>>2,0,(uint8_t)cell&3); }
    else if(kind==2) { gSceneFlags|=6;gSceneId=(uint8_t)cell; }
}
/*080311D8/311F4: the run path compares the WHOLE flags byte against2.*/
void WalkOverworldPlayer(uint8_t direction) { MoveOverworldActor(0,direction);RecordPlayerMovement();HandlePlayerSceneCell(); }
void RunOverworldPlayer(uint8_t direction)
{
    MoveOverworldActor(0,direction);HandlePlayerSceneCell();if(gSceneFlags!=2) { MoveOverworldActor(0,direction);HandlePlayerSceneCell(); }
    if(gRuntimeActors[0][24]==1)gRuntimeActors[0][24]=2;
}
/*08031534/31564/3158C/315B4/315E4. Native callers supply directions0..3.*/
static int8_t FindInteractionActor(uint8_t x,uint8_t y,uint8_t direction)
{
    for(unsigned i=1;i<15;++i) {
        int dy=(int)y-(int16_t)U16(gRuntimeActors[i]+6),dx=(int)x-(int16_t)U16(gRuntimeActors[i]+4);unsigned match=0;
        switch(direction) {
        case 0:match=dy>-9 && dy<=0 && dx>-5 && dx<5;break;
        case 1:match=dx>=0 && dx<9 && dy>-5 && dy<5;break;
        case 2:match=dy>=0 && dy<9 && dx>-5 && dx<5;break;
        case 3:match=dx>-9 && dx<=0 && dy>-5 && dy<5;break;
        }
        if(match)return i;
    }return -1;
}
/*08031704/31790: A and R choose the two different actor script pointers.*/
void InteractWithActor(uint8_t alternate)
{
    uint8_t *player=gRuntimeActors[0],direction=player[2];int8_t actor=FindInteractionActor(player[4]+ROM(0x08D4C9A0)[direction*2],player[6]+ROM(0x08D4C9A8)[direction*2],direction);
    if(actor==-1)return;uint8_t *a=gRuntimeActors[(uint8_t)actor];PlayGameAudio(202);
    if(a[28]&2)a[2]=ROM(0x08D4C99C)[direction];a[12]=19;SelectRuntimeActorFrame(actor);UpdateOverworldActors();UploadDialogueFrame();
    RunScriptNode((const void *)(uintptr_t)U32(a+(alternate?20:16)));
}
/*08030E58: NPC wander moves do not update the player's movement-cell state.*/
static void MoveWanderer(uint8_t actor,uint8_t direction)
{
    uint8_t *a=gRuntimeActors[actor];int16_t delta[2];a[2]=direction;ResolveActorStep(actor,direction,delta);
    W16(a+4,U16(a+4)+delta[0]);W16(a+6,U16(a+6)+delta[1]);UpdateActorHeight(actor);UpdateOverworldActorFrame(actor);
}
/*08030EA4*/
void UpdateWanderingActors(void)
{
    for(unsigned i=1;i<15;++i) {
        /*08030EB4/30EBC test bit2 and bit5 independently; bits0/1 may
         *also be set (shadow/interaction flags do not suppress wandering).*/
        uint8_t *a=gRuntimeActors[i];if(!(a[28]&4) || (a[28]&32))continue;
        int16_t timer=(int16_t)U16(a+26);
        if(timer>=2) { if(!(timer&1))MoveWanderer(i,a[2]);W16(a+26,timer-1); }
        else if(timer==1) { a[12]=19;MoveWanderer(i,a[2]);W16(a+26,0); }
        else if(!RandomByteInclusive(0,20)) { a[2]=RandomByteInclusive(0,3);W16(a+26,RandomByteInclusive(5,20)*4); }
    }
}
/*08030F30/30FAC/3102C*/
uint8_t SceneHasFollower(void)
{
    if((gSceneId==25 && gSceneVariant==5)||(gSceneId==26 && gSceneVariant==3)||(gSceneId==36 && gSceneVariant==5)||(gSceneId==30 && gSceneVariant==1)||(gSceneId==10 && !gSceneVariant))return 0;
    return TestEventFlag(gEventFlags,114)!=0;
}
void InitializeFollowerTrail(void)
{ for(unsigned i=0;i<10;++i) { gFollowerTrail[i*8]=gRuntimeActors[0][2];W16(gFollowerTrail+i*8+2,U16(gRuntimeActors[0]+4));W16(gFollowerTrail+i*8+4,U16(gRuntimeActors[0]+6)); } }
void UpdateFollowerTrail(void)
{
    if(!SceneHasFollower())return;uint8_t *a=gRuntimeActors[14];a[2]=gFollowerTrail[0];W16(a+4,U16(gFollowerTrail+2));W16(a+6,U16(gFollowerTrail+4));
    for(unsigned i=0;i<9;++i) { gFollowerTrail[i*8]=gFollowerTrail[(i+1)*8];W16(gFollowerTrail+i*8+2,U16(gFollowerTrail+(i+1)*8+2));W16(gFollowerTrail+i*8+4,U16(gFollowerTrail+(i+1)*8+4)); }
    gFollowerTrail[72]=gRuntimeActors[0][2];W16(gFollowerTrail+74,U16(gRuntimeActors[0]+4));W16(gFollowerTrail+76,U16(gRuntimeActors[0]+6));UpdateActorHeight(14);
}

/*080301F4 is an unused alias of the occupied-player-cell dispatch318FC.*/
void HandlePlayerSceneCellLegacy(void) { HandlePlayerSceneCell(); }
/*08030F8C: alternate follower condition, separate from the active flag114.*/
uint8_t SceneAlternateFollowerEnabled(void)
{ return !TestEventFlag(gEventFlags,94) && TestEventFlag(gEventFlags,93); }
