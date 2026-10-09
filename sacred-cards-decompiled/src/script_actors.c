/* Script actor commands 08032944..08032D22, plus animation selection helpers.
 * Native runtime actor records have stride32 at 02023498. Raw accessors retain
 * unknown fields. Valid actor/direction/frame indices are caller preconditions.
 * Semantic C; not execution-compared or matched. Frame upload and terrain-height
 * helpers remain external dependencies.
 */
#include "script_actors.h"
extern uint8_t gRuntimeActors[][32];                 /* 02023498 */
extern const int8_t gDirectionDX[4],gDirectionDY[4]; /* D4F11C / D4F120 */
extern const uint8_t gActorWalkPhases[20];           /* D4C71C */
extern const uint8_t gActorSpecialFrames[];          /* D4C730 */
extern const uint8_t *const gActorSheets[];          /* D511A0 */
extern const uint8_t *const gActorPalettes[];        /* D51338 */
extern const uint16_t gActorFrameTileOffsets[];      /* FBB10 */
extern const uint16_t gActorDestinationTiles[];      /* FBB34 */
extern uint8_t gActorGraphicsBuffer[];              /* 02010400 */
extern uint8_t gObjectPaletteBuffer[];              /* 02000200 */
extern volatile uint16_t gDisplayControl,gBlendControl,gBlendY;
extern void CopyActorFrame(const uint8_t *,uint16_t,uint8_t *);
extern void HideDialogueWindow(void);
extern void UpdateActorHeight(uint8_t);
extern void UpdateSceneActorFrame(void);
extern void UploadActorPaletteFrame(void);
extern void WaitForFrame(void);

static uint16_t Read16(const uint8_t *p) { return p[0]|(uint16_t)p[1]<<8; }
static int32_t Signed16(const uint8_t *p) { uint16_t v=Read16(p); return v<32768?v:(int32_t)v-65536; }
static void Write16(uint8_t *p,uint16_t v) { p[0]=(uint8_t)v;p[1]=(uint8_t)(v>>8); }
static void DrawActorFrame(uint8_t actor,uint16_t frame)
{
    uint16_t sprite=Read16(gRuntimeActors[actor]);
    CopyActorFrame(gActorSheets[sprite],gActorFrameTileOffsets[frame],
                   gActorGraphicsBuffer+gActorDestinationTiles[actor]*32u);
}
/* 080305A4 */
void SelectRuntimeActorFrame(uint8_t actor)
{
    uint8_t *a=gRuntimeActors[actor];
    uint8_t frame=a[2]<4 ? (uint8_t)(a[2]*3+gActorWalkPhases[a[12]]) : gActorSpecialFrames[a[2]];
    DrawActorFrame(actor,frame);
}
/* 08030914: animation phase decrements, wrapping zero/out-of-range to 19. */
static void AdvanceWalkingPhase(uint8_t actor)
{
    uint8_t *phase=&gRuntimeActors[actor][12];
    if (*phase>20 || *phase==0) *phase=20;
    --*phase;
}
static void BeginActorCommand(struct ScriptState *s)
{
    s->dirty=0;HideDialogueWindow();
}
static void WalkStep(uint8_t actor)
{
    uint8_t *a=gRuntimeActors[actor];
    Write16(a+4,(uint16_t)(Read16(a+4)+gDirectionDX[a[2]]));
    Write16(a+6,(uint16_t)(Read16(a+6)+gDirectionDY[a[2]]));
    UpdateActorHeight(actor);
    AdvanceWalkingPhase(actor);
    SelectRuntimeActorFrame(actor);
    UpdateSceneActorFrame();UpdateSceneActorFrame();
}
static void FinishWalk(uint8_t actor,uint8_t keep_flag)
{
    uint8_t *a=gRuntimeActors[actor];
    a[28]&=0xFB;
    if (keep_flag==1) a[28]|=4;
    a[12]=19; /* 08030960 */
    SelectRuntimeActorFrame(actor);UpdateSceneActorFrame();
}
/* 08032944, @0. Two frame/upload cycles per coordinate increment. */
void ScriptMoveActor(uint8_t actor,uint8_t direction,uint8_t count,uint8_t keep_flag,struct ScriptState *s)
{
    BeginActorCommand(s);gRuntimeActors[actor][2]=direction;
    for (uint32_t i=0;i<count;++i) WalkStep(actor);
    FinishWalk(actor,keep_flag);
}
/* 08032A50, @1. Unlike movement commands this neither hides the text nor clears
 * its dirty bit. The script-state argument is unused in native code.
 */
void ScriptPlaceActor(uint8_t actor,uint16_t x,uint16_t y,uint16_t frame,struct ScriptState *s)
{
    (void)s;uint8_t *a=gRuntimeActors[actor];
    Write16(a+4,x);Write16(a+6,y);a[28]&=0xFB;
    UpdateActorHeight(actor);
    DrawActorFrame(actor,(uint16_t)(a[2]*3u+frame));
    UpdateSceneActorFrame();
}
/* 08032AB0, @6 */
void ScriptActorPoseFour(uint8_t actor,struct ScriptState *s)
{
    BeginActorCommand(s);uint8_t *a=gRuntimeActors[actor];
    a[28]&=0xF8;a[2]=4;a[12]=0;
    SelectRuntimeActorFrame(actor);UpdateSceneActorFrame();
}
/* 08032AFC, ^5. Native palette selection here uses bits3..4, not bit5. */
void ScriptChangeActorSprite(uint8_t actor,uint8_t sprite,struct ScriptState *s)
{
    BeginActorCommand(s);uint8_t *a=gRuntimeActors[actor];
    Write16(a,sprite);SelectRuntimeActorFrame(actor);
    const uint8_t *palette=gActorPalettes[sprite]+((a[28]&0x1F)>>3)*32u;
    for (unsigned i=0;i<32;++i) gObjectPaletteBuffer[actor*32u+i]=palette[i];
    UploadActorPaletteFrame();
}
/* 08032B64, @4 */
void ScriptMoveActorToX(uint8_t actor,uint8_t x,struct ScriptState *s)
{
    BeginActorCommand(s);uint8_t *a=gRuntimeActors[actor];
    int32_t distance=(int32_t)x-Signed16(a+4);
    a[2]=3;if (distance<0) { a[2]=1;distance=-distance; }
    while (distance-->0) WalkStep(actor);
    FinishWalk(actor,0);
}
/* 08032C24, @5 */
void ScriptMoveActorToY(uint8_t actor,uint8_t y,struct ScriptState *s)
{
    BeginActorCommand(s);uint8_t *a=gRuntimeActors[actor];
    int32_t distance=(int32_t)y-Signed16(a+6);
    a[2]=0;if (distance<0) { a[2]=2;distance=-distance; }
    while (distance-->0) WalkStep(actor);
    FinishWalk(actor,0);
}
/* 08032CE4, ^3. Ends at brightness15; delay zero still writes all16 values. */
void ScriptFadeToDark(uint8_t delay)
{
    gDisplayControl=0x1D00;gBlendControl=0xDC;
    for (unsigned level=0;level<16;++level) {
        gBlendY=(uint16_t)level;
        for (unsigned frame=0;frame<delay;++frame) WaitForFrame();
    }
}
