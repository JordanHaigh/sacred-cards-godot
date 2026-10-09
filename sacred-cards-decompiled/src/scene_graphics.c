/* AY7E scene/portrait composition and graphics transfer routines. Semantic C;
 * native timing, compiler matching and runtime equivalence remain unestablished. */
#include "script_runtime.h"
#include "gba_bios.h"
extern uint8_t gRuntimeActors[][32];             /* 02023498 */
extern uint16_t gActorDrawOrder[15];             /* 020236D0 */
extern uint8_t gPlayerDrawOrder,gSceneFlags;      /* 020236EE / 020236F4 */
extern uint16_t gSceneId,gSceneVariant;           /* 02023490 / 02023492 */
extern uint16_t gOamBuffer[128][4];               /* 02018400 */
extern uint8_t gActorGraphicsBuffer[];           /* 02010400 */
extern uint8_t gPaletteBuffer[],gObjectPaletteBuffer[]; /* 02000000 / 02000200 */
extern uint8_t gDialogueTiles[],gDialogueMap[];   /* 0200DC00 / 0200EC00 */
extern const uint16_t gActorDestinationTiles[];
extern const uint8_t *const gActorPalettes[];
extern const uint8_t gActorShadowTiles[],gActorShadowPalette[]; /* 082B16EC / 082B268C */
extern const uint8_t *const gPortraitCompressedTiles[]; /* 08D4EDBC */
extern const uint8_t *const gPortraitPalettes[];   /* 08D4EE40 */
struct PortraitFrame { uint8_t unknown,count;uint16_t reserved;const uint16_t (*oam)[4]; };
extern const struct PortraitFrame *const *const gPortraitParts[]; /* 08D4EEC4 */
extern void WaitForFrame(void);
extern void SelectRuntimeActorFrame(uint8_t);
extern uint16_t ReadSceneCell(uint8_t,uint8_t);
extern void PlaySceneMusic(uint16_t,uint16_t);
#define REG16(address) (*(volatile uint16_t *)(uintptr_t)(address))
#define REG8(address) (*(volatile uint8_t *)(uintptr_t)(address))
static uint16_t Read16(const uint8_t *p) { return p[0]|(uint16_t)p[1]<<8; }
static int32_t Signed16(const uint8_t *p) { unsigned n=Read16(p);return n<32768?(int32_t)n:(int32_t)n-65536; }
static void Write16(uint8_t *p,uint16_t n) { p[0]=(uint8_t)n;p[1]=(uint8_t)(n>>8); }
/* 08031878 / 08031238: actor argument to bounds predicate is unused. */
void UpdateActorHeight(uint8_t actor) {
    uint8_t *a=gRuntimeActors[actor];uint8_t x=a[4],y=a[6];
    if(x && x<=119 && y && y<=79) { uint16_t cell=ReadSceneCell(x,y);if(!(cell&0xFE00))Write16(a+8,(cell&255)>>1); }
}
/* 08024DB8 / 080306FC: preserve OAM padding and unrelated attribute bits. */
void ClearSceneOam(void) {
    for(unsigned i=0;i<128;++i) { uint8_t *p=(uint8_t *)gOamBuffer[i];
        p[0]=0xC0;Write16(p+2,(Read16(p+2)&0xFE00)|0x1C0);p[1]&=0x3F;
        Write16(p+4,Read16(p+4)&0xFC00);p[5]|=12;p[3]&=15;
    }
}
/* 080309C0: descending Y insertion; equal coordinates retain actor order.
 * Native valid actor positions must exceed sentinel -32767. */
void SortSceneActors(void) {
    int16_t sorted[15];for(unsigned i=0;i<15;++i)sorted[i]=-32767;
    for(unsigned actor=0;actor<15;++actor) {
        int16_t y=(int16_t)Signed16(gRuntimeActors[actor]+6);unsigned at=0;
        while(y<=sorted[at])++at;
        uint16_t id=actor;
        for(;at<15;++at) { int16_t old_y=sorted[at];uint16_t old_id=gActorDrawOrder[at];sorted[at]=y;gActorDrawOrder[at]=id;y=old_y;id=old_id; }
    }
    gPlayerDrawOrder=0;for(unsigned i=0;i<15;++i)if(gActorDrawOrder[i]==0)gPlayerDrawOrder=i;
}
/* 080306D0 */
static void SetActorPriority(uint8_t *oam,uint16_t cell) { oam[5]|=12;if(!(cell&0x100))oam[5]=(oam[5]&0xF3)|8; }
static void OamDefaults(uint8_t *p,uint8_t actor) {
    p[3]=(p[3]&0x3F)|0x80;p[1]&=3;p[5]=(p[5]&15)|(uint8_t)(actor<<4);
    p[0]=0xC0;Write16(p+2,(Read16(p+2)&0xFE00)|0x1C0);
}
/* 08030A90 */
void ComposeActorOam(uint8_t *p,uint8_t actor) {
    uint8_t *a=gRuntimeActors[actor];OamDefaults(p,actor);if(Read16(a)==0xFFFF)return;
    Write16(p+4,(Read16(p+4)&0xFC00)|(gActorDestinationTiles[actor]&0x3FF));
    uint16_t cell=ReadSceneCell(a[4],a[6]);Write16(a+10,cell);SetActorPriority(p,cell);
    int32_t y=Signed16(a+6),x=Signed16(a+4);
    if(y>-32 && y<104)p[0]=(uint8_t)(y*2-a[8]-24);
    if(x>-16 && x<136)Write16(p+2,(Read16(p+2)&0xFE00)|((x*2-16)&0x1FF));
}
/* 08030B7C */
void ComposeActorShadowOam(uint8_t *p,uint8_t actor) {
    uint8_t *a=gRuntimeActors[actor];OamDefaults(p,actor);
    if(Read16(a)==0xFFFF || !(a[28]&1))return;
    p[3]&=0x3F;p[1]=(p[1]&3)|0x40;p[5]|=0xF0;
    p[0]=0xC0;Write16(p+2,(Read16(p+2)&0xFE00)|0x1C0);
    int32_t y=Signed16(a+6),x=Signed16(a+4);
    if(y>-32 && y<104)p[0]=(uint8_t)(y*2-a[8]);
    if(x>-16 && x<136)Write16(p+2,(Read16(p+2)&0xFE00)|((x*2-8)&0x1FF));
    Write16(p+4,(Read16(p+4)&0xFC00)|0x9C);SetActorPriority(p,Read16(a+10));
}
/* 08030CC8: both loops advance EIGHT bytes, as the instruction listing shows. */
void ComposeSceneActors(void) {
    for(unsigned i=0;i<15;++i)ComposeActorOam((uint8_t *)gOamBuffer[i],(uint8_t)gActorDrawOrder[i]);
    for(unsigned i=0;i<15;++i)ComposeActorShadowOam((uint8_t *)gOamBuffer[15+i],(uint8_t)gActorDrawOrder[i]);
}
/* 08030464 */
void LoadActorGraphicsAndPalette(uint8_t actor,uint8_t sprite) {
    SelectRuntimeActorFrame(actor);
    BiosCpuSet(gActorPalettes[sprite]+((gRuntimeActors[actor][28]&31)>>3)*32,gObjectPaletteBuffer+actor*32,0x10);
}
/* 080304B0 / 08030510 */
void LoadSceneActorGraphics(void) {
    ClearSceneOam();SortSceneActors();
    for(unsigned i=0;i<15;++i) { uint16_t actor=gActorDrawOrder[i];LoadActorGraphicsAndPalette((uint8_t)actor,gRuntimeActors[actor][0]); }
    for(unsigned b=0;b<2;++b)for(unsigned i=0;i<128;++i)gActorGraphicsBuffer[0x1380+b*0x400+i]=gActorShadowTiles[b*0x200+i];
    BiosCpuSet(gActorShadowPalette,gObjectPaletteBuffer+0x1E0,0x10);ComposeSceneActors();
}
/* 080284CC / 080284E4 */
void UploadOam(void) { BiosCpuSet(gOamBuffer,(void *)0x07000000,0x200); }
void UploadPalettes(void) { BiosCpuSet(gPaletteBuffer,(void *)0x05000000,0x200); }
/* 08030D14 / 08030D7C */
void UpdateSceneActorFrame(void) {
    SortSceneActors();ComposeSceneActors();WaitForFrame();BiosCpuFastSet(gActorGraphicsBuffer,(void *)0x06010000,0x800);UploadOam();
}
void UploadActorPaletteFrame(void) {
    WaitForFrame();BiosCpuFastSet(gActorGraphicsBuffer,(void *)0x06010000,0x800);UploadPalettes();
}
/* 08030DB8 / 08030E14 / 080285B8 */
void UploadDialogueFrame(void) { BiosCpuSet(gDialogueTiles,(void *)0x0600D800,0x04000388);UploadOam(); }
void UploadSceneGraphics(void) {
    BiosCpuSet(gDialogueTiles,(void *)0x0600D800,0x04000388);BiosCpuSet(gDialogueMap,(void *)0x0600E800,0x04000040);
    UploadOam();BiosCpuSet(gActorGraphicsBuffer,(void *)0x06010000,0x2000);
    BiosCpuSet(gActorGraphicsBuffer+0x4000,(void *)0x06014000,0x2000);UploadPalettes();
}
/* 08031AB8 / 08031AF8. WININ's high byte is written independently. */
void ShowDialogueWindow(void) {
    REG16(0x04000042)=0x03ED;REG16(0x04000046)=0x739D;REG8(0x04000049)=0x3D;
    REG16(0x0400004A)=0x1C;REG16(0x04000000)=0x5D00;REG16(0x04000050)=0xDC;REG16(0x04000054)=7;
}
void HideDialogueWindow(void) { REG16(0x04000000)=0x1D00;REG16(0x04000050)=0; }
/* 08031C58: offset each part by the FIRST frame's object count. Copy three
 * attributes per object, preserving the fourth halfword (affine/padding). */
void ComposePortraitPart(struct ScriptState *s,uint8_t part,uint8_t frame,uint16_t color_mode,uint16_t priority) {
    const struct PortraitFrame *const *parts=gPortraitParts[s->portrait];unsigned offset=0;
    for(unsigned i=0;i<part;++i)offset+=parts[i][0].count;
    const struct PortraitFrame *f=&parts[part][frame];
    for(unsigned i=0;i<f->count;++i) {
        gOamBuffer[offset+i][0]=f->oam[i][0]|(uint16_t)(color_mode<<13);
        gOamBuffer[offset+i][1]=f->oam[i][1];
        gOamBuffer[offset+i][2]=f->oam[i][2]|(uint16_t)(priority<<10);
    }
}
/* 08031D58 */
void RestoreActorsAfterPortrait(void) {
    ShowDialogueWindow();REG16(0x04000000)=0x4D00;LoadSceneActorGraphics();WaitForFrame();UploadSceneGraphics();REG16(0x04000000)=0x5D00;
}
/* 08031B88 / 08031BA4, including Huffman + cumulative-byte decode08009100/09160. */
void LoadDialoguePortrait(struct ScriptState *s) {
    if(!s->portrait) { RestoreActorsAfterPortrait();return; }
    ShowDialogueWindow();REG16(0x04000000)=0x4D00;ClearSceneOam();
    BiosHuffmanUnpack(gPortraitCompressedTiles[s->portrait],gActorGraphicsBuffer);
    uint8_t previous=0;for(unsigned i=0;i<0x8000;++i) { previous+=gActorGraphicsBuffer[i];gActorGraphicsBuffer[i]=previous; }
    BiosCpuSet(gPortraitPalettes[s->portrait],gObjectPaletteBuffer,0x100);
    for(unsigned part=0;part<3;++part)ComposePortraitPart(s,part,0,1,1);
    if(s->portrait_flags&1)ComposePortraitPart(s,3,0,1,1);
    WaitForFrame();UploadSceneGraphics();REG16(0x04000000)=0x5D00;
}
/* 08031B44 */
void ExitSceneDialogue(struct ScriptState *s) {
    if(gSceneFlags&2)return;
    PlaySceneMusic(gSceneId,gSceneVariant);if(s->portrait)RestoreActorsAfterPortrait();HideDialogueWindow();
}

extern uint8_t gBackgroundBuffer[]; /* 02000400..02010400 */
extern uint16_t gBgOffsetsRaw[22]; /* 0202344C..02023478: interleaved native offsets/state */
extern const uint8_t *const gSceneBackgroundTiles[],*const gSceneBackgroundMaps[],*const gSceneForegroundMaps[],*const gSceneBackgroundPalettes[];
/* ROM tables 08D514D0 / 08D515B8 / 08D516A0 / 08D51788 */
extern const uint8_t gDialogueBlankLz[],gDialogueInitialMap[],gDialoguePalette[]; /* 082B26AC / 082B2868 / 082B3068 */
/* 08028438: register order differs from the RAM order. */
void UploadBackgroundOffsets(void) {
    static const uint8_t offsets[8]={4,16,18,10,20,2,0,6};
    for(unsigned i=0;i<8;++i)REG16(0x04000010+i*2)=gBgOffsetsRaw[offsets[i]];
}
/* 080302E8 / 0803032C / 080303B0 / 080303FC / 08030DA0. */
static void RestoreScene(uint8_t dialogue) {
    REG16(0x04000000)=0;REG16(0x04000050)=0;
    REG16(0x0400000E)=0x1F83;gBgOffsetsRaw[0]=8;gBgOffsetsRaw[6]=0;
    BiosLz77UnpackWram(gSceneBackgroundTiles[gSceneId],gBackgroundBuffer);
    BiosCpuSet(gSceneBackgroundPalettes[gSceneId],gPaletteBuffer+0x20,0xF0);
    BiosCpuSet(gSceneBackgroundMaps[gSceneId],gBackgroundBuffer+0xF800,0x400);
    REG16(0x0400000C)=0x1E82;gBgOffsetsRaw[20]=8;gBgOffsetsRaw[2]=0;
    BiosCpuSet(gSceneForegroundMaps[gSceneId],gBackgroundBuffer+0xF000,0x400);
    if(dialogue) {
        REG16(0x04000008)=0x1D0C;gBgOffsetsRaw[4]=8;gBgOffsetsRaw[16]=0;
        BiosLz77UnpackWram(gDialogueBlankLz,gDialogueTiles);BiosCpuSet(gDialoguePalette,gPaletteBuffer,0x10);
        BiosCpuSet(gDialogueInitialMap,gDialogueMap,0x280);
    }
    LoadSceneActorGraphics();REG16(0x04000054)=7;
    WaitForFrame();UploadBackgroundOffsets();UploadOam();
    for(unsigned block=0;block<4;++block)BiosCpuSet(gBackgroundBuffer+block*0x4000,(void *)(uintptr_t)(0x06000000+block*0x4000),0x2000);
    BiosCpuSet(gActorGraphicsBuffer,(void *)0x06010000,0x2000);BiosCpuSet(gActorGraphicsBuffer+0x4000,(void *)0x06014000,0x2000);
    UploadPalettes();REG16(0x04000000)=0x1D00;
}

/*080302A8 /080302E8*/
void RestoreScenePreview(void) { RestoreScene(0); }
void RestoreSceneDisplay(void) { RestoreScene(1); }

/*08030DD8, unlike UploadDialogueFrame also transfers the dialogue map.*/
void UploadDialogueInitialFrame(void) { UploadDialogueFrame();BiosCpuSet(gDialogueMap,(void *)0x0600E800,0x04000040); }
