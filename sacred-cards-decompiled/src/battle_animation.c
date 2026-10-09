/* AY7E battle presentation, 08012358..08013B6C. Full-card staging, hit,
 * destruction, attribute-hit and life-point animations. Shared scratch is
 * intentionally reused after cards have been transferred to BG buffers.
 * Readable C recovery; hardware timing/execution equivalence is unestablished. */
#include <stdint.h>
#include "gba_bios.h"
extern uint8_t gBattleDisplayBytes[0x19],gCardMetadataBytes[0x1E];
extern uint8_t gBattleAnimationFlags[8]; /*0201CB40, only bytes0 and4*/
extern uint8_t gBattleAnimationScratch[0x4314]; /*02018800*/
extern uint8_t gBackgroundBuffer[],gActorGraphicsBuffer[],gPaletteBuffer[],gDecimalDigits[5];
extern uint8_t gFullCardTiles[0x4000];
extern uint8_t gFullCardPalette[256]; /*0201C800:128 RGB555 entries, then map at0201C900*/
extern uint16_t gFullCardMap[266],gBgOffsetsRaw[22],gOamBuffer[128][4];
extern uint32_t gRandomState;
extern uint32_t RandomByteInclusive(uint32_t,uint32_t);
extern uint8_t NextRandomByte(void);
extern void ComposeFullCard(void),LoadCardMetadata(uint32_t),FormatDecimalDigits(uint16_t,uint8_t),PlayGameAudio(uint32_t);
extern void WaitForFrame(void),SetVBlankCallback(void (*)(void)),UploadPalettes(void),UploadOam(void),UploadBackgroundOffsets(void);
#define ROM(a) ((const uint8_t *)(uintptr_t)(a))
#define REG(a) (*(volatile uint16_t *)(uintptr_t)(a))
#define S gBattleAnimationScratch
static uint16_t U16(const uint8_t *p) { return p[0]|(uint16_t)p[1]<<8; }
static uint32_t U32(const uint8_t *p) { return U16(p)|(uint32_t)U16(p+2)<<16; }
static void W16(uint8_t *p,uint16_t v) { p[0]=v;p[1]=v>>8; }
static void Wait(unsigned n) { for(unsigned i=0;i<n;++i)WaitForFrame(); }
static void CallbackFrame(void (*fn)(void)) { SetVBlankCallback(fn);WaitForFrame(); }
static void ClearOamEntry(unsigned i)
{ gOamBuffer[i][0]=0xA0;gOamBuffer[i][1]=0xF0;gOamBuffer[i][2]=0xC00;gOamBuffer[i][3]=0; }
static void ResetOam(void) { for(unsigned i=0;i<128;++i)ClearOamEntry(i); }
static void UploadBlend(void) { REG(0x04000050)=gBgOffsetsRaw[8];REG(0x04000052)=gBgOffsetsRaw[14];REG(0x04000054)=gBgOffsetsRaw[12]; }
static void UploadObjects(void)
{ for(unsigned i=0;i<2;++i)BiosCpuSet(gActorGraphicsBuffer+i*0x4000,(void *)(uintptr_t)(0x06010000+i*0x4000),0x2000); }
/*08023064: 16 tiles per copied row, 32 tiles per destination row.*/
void CopyObjectTileRows(uint8_t bank,const uint8_t *tiles,uint16_t count)
{
    static const unsigned offsets[4]={0,0x4000,0x200,0x4200};uint8_t *out=gActorGraphicsBuffer+offsets[bank<4?bank:0];
    for(unsigned i=0;i<(count>>4);++i)BiosCpuSet(tiles+i*512,out+i*1024,0x100);
}
static void HideObjects(void) { REG(0x04000000)&=0xEFFF; }
static void ShowObjects(void) { UploadOam();UploadPalettes();UploadBlend();REG(0x04000000)|=0x1000; }
static void ShowLifeObjects(void) { UploadOam();UploadPalettes();REG(0x04000000)|=0x1000; }
static void UploadOamBlend(void) { UploadOam();UploadBlend(); }
static void UploadOamOffsets(void) { UploadOam();UploadBackgroundOffsets(); }
static void ResetBattleOffsets(void)
{ gBgOffsetsRaw[2]=4;gBgOffsetsRaw[20]=0x1FC;gBgOffsetsRaw[6]=4;gBgOffsetsRaw[0]=4;UploadBackgroundOffsets(); }
static void EndHit(void) { HideObjects();ResetBattleOffsets(); }
static void BlankBattle(void) { REG(0x05000000)=0;REG(0x04000000)=0; }
static void ShowBattle(void) { UploadPalettes();REG(0x0400000C)=0x1E81;REG(0x0400000E)=0x1F86;REG(0x04000000)=0xC00; }
/*080124F4/12528. Flags are ORed; callers clear just the two active bytes.*/
void SelectBattleAnimationFlags(void)
{
    static const uint8_t flags[18][2]={
        {0,0},{9,0x4F},{0x4F,0x4F},{0x4F,9},{9,0x57},{9,0x11},
        {0x4B,0x11},{0x11,0x4B},{0x11,9},{0x57,9},{9,0xC2},
        {9,0},{0xCF,0},{0,0xCF},{0,9},{0xC2,9},{0x21,0x67},{0x67,0x21}
    };
    unsigned kind=gBattleDisplayBytes[0x18];
    if(kind<18) { gBattleAnimationFlags[0]|=flags[kind][0];gBattleAnimationFlags[4]|=flags[kind][1]; }
}
/*080127D8*/
static void LoadBattleCardMetadata(unsigned side)
{
    uint8_t *p=gBattleDisplayBytes+side*12,flags=gBattleAnimationFlags[side*4];LoadCardMetadata(U16(p));
    W16(gCardMetadataBytes+0x12,(flags&8)?U16(p+6):0xFFFF);W16(gCardMetadataBytes+0x14,(flags&16)?U16(p+8):0xFFFF);
    gCardMetadataBytes[0x16]=0;if(!(flags&32))gCardMetadataBytes[0x17]=0;
}
/*08006A78/06AA0/06B08: side0 of the battle record is drawn on the left.*/
static void StageBattleCard(unsigned side)
{
    ComposeFullCard();
    unsigned mapOffset=side?0xF862:0xF040;
    for(unsigned row=0;row<19;++row)BiosCpuSet(gFullCardMap+row*14,gBackgroundBuffer+mapOffset+row*64,0x04000007);
    if(side)for(unsigned i=64;i<0x4000;++i)gFullCardTiles[i]|=128;
    BiosCpuSet(gFullCardPalette,gPaletteBuffer+side*256,0x80);BiosCpuSet(gFullCardTiles,gBackgroundBuffer+side*0x4000,0x2000);
}
/*08013330/130F0/132D0/1331C/13090. Four descriptors are drawn twice;
 * their duration byte is ignored. 080131EC jitter is not called here.*/
void AnimateBattleHit(uint8_t side)
{
    BiosCpuSet(ROM(0x080AFDE0),gPaletteBuffer+0x200,0x10);
    CopyObjectTileRows(0,ROM(0x080AD3E0),0x100);CopyObjectTileRows(1,ROM(0x080AF3E0),0x50);ResetOam();
    gBgOffsetsRaw[8]=0x2C10;gBgOffsetsRaw[14]=0x80E;gBgOffsetsRaw[12]=0;S[0]=S[1]=0;
    CallbackFrame(ShowObjects);UploadObjects();PlayGameAudio(68);
    do {
        const uint8_t *frame=ROM(0x080AC2A0)+S[1]*8,*parts=ROM(U32(frame+4));
        for(unsigned i=0;i<21;++i) {
            if(i<frame[1]) {
                uint16_t *o=gOamBuffer[i];o[0]=U16(parts+i*8);o[1]=U16(parts+i*8+2);o[2]=U16(parts+i*8+4);
                o[0]=(o[0]&0xF300)|(uint8_t)(o[0]+4)|0x400;o[1]=(o[1]&0xFE00)|((o[1]+(side?124:4))&511);
            }else ClearOamEntry(i);
        }
        CallbackFrame(UploadOamOffsets);
        if(++S[0]>1) {
            S[0]=0;++S[1];
            if(U32(ROM(0x080AC2A4)+(S[1]-1)*8)==U32(ROM(0x080AC2A4)+S[1]*8))S[1]=0;
        }
    }while(U16(S));
    CallbackFrame(EndHit);
}
/*08013658/1353C/1351C/13464. LP falls by72 per frame, capped at target;
 * initial15 frames and final30 frames are part of the original sequence.*/
static void DrawLifePoints(uint8_t side)
{
    uint8_t x=side?124:4;FormatDecimalDigits(U16(S),0);
    for(unsigned i=0;i<7;++i,x+=16) {
        unsigned digit=i<2?10+i:gDecimalDigits[i-2];
        if(i>=2 && digit==10) { ClearOamEntry(i);continue; }
        const uint8_t *record=ROM(U32(ROM(0x08D359B0)+digit*4)),*o=ROM(U32(record+4));
        gOamBuffer[i][0]=U16(o)|0x3C;gOamBuffer[i][1]=U16(o+2)|x;gOamBuffer[i][2]=U16(o+4);
    }
}
void AnimateBattleLifePoints(uint8_t side)
{
    BiosCpuSet(ROM(0x080B3EA0),gPaletteBuffer+0x200,0x04000008);CopyObjectTileRows(0,ROM(0x080B1EA0),0x100);ResetOam();
    unsigned at=side==1?12:0;W16(S+2,U16(gBattleDisplayBytes+at+2));W16(S+4,U16(gBattleDisplayBytes+at+4));
    gBgOffsetsRaw[8]=gBgOffsetsRaw[14]=gBgOffsetsRaw[12]=0;W16(S,U16(S+2));
    CallbackFrame(ShowLifeObjects);UploadObjects();UploadBlend();DrawLifePoints(side);SetVBlankCallback(UploadOam);Wait(15);
    if(U16(S+4)<U16(S+2)) {
        unsigned frames=0; /* Native guard compares incremented counter to0x270F. */
        while(U16(S+4)<U16(S) && frames<10000) {
            int difference=(int)U16(S)-U16(S+4);W16(S,difference<73?U16(S+4):U16(S)-72);DrawLifePoints(side);CallbackFrame(UploadOam);
            if(!(frames&1))PlayGameAudio(71);++frames;
        }
        Wait(30);
    }
    CallbackFrame(HideObjects);
}
/*0801384C/13978/137C4/13828/1376C. Five descriptors are drawn twice;
 * the repeated-pointer fifth descriptor is drawable, unlike the hit table.
 * Zero duration terminates this sequence. Affine padding survives OAM hiding.*/
void AnimateBattleAttributeHit(uint8_t side)
{
    W16(S,side?124:0);W16(S+2,side?116:508);S[4]=4;S[5]=12;S[6]=S[7]=S[8]=0;
    BiosCpuSet(ROM(0x080AFDE0),gPaletteBuffer+0x200,0x10);BiosCpuSet(ROM(0x080B1E00),gPaletteBuffer+0x220,0x10);
    CopyObjectTileRows(0,ROM(0x080AD3E0),0x100);CopyObjectTileRows(1,ROM(0x080AF3E0),0x50);CopyObjectTileRows(2,ROM(0x080AFE00),0x100);
    ResetOam();for(unsigned i=0;i<4;++i)gOamBuffer[i][3]=U16(ROM(0x080B1E20)+i*2);
    gBgOffsetsRaw[8]=0x2C10;gBgOffsetsRaw[14]=0x80E;gBgOffsetsRaw[12]=0;
    CallbackFrame(ShowObjects);UploadObjects();PlayGameAudio(69);
    do {
        const uint8_t *frame=ROM(0x080AC390)+S[7]*8,*parts=ROM(U32(frame+4));
        for(unsigned i=0;i<128;++i) {
            uint16_t *o=gOamBuffer[i];
            if(i<frame[1]) {
                o[0]=(U16(parts+i*8)&0xF300)|(uint8_t)(parts[i*8]+S[4])|0x400;
                o[1]=(U16(parts+i*8+2)&0xFE00)|((U16(parts+i*8+2)+U16(S))&511);
                o[2]=(U16(parts+i*8+4)&0xF3FF)|0x400;
            }else if(i==frame[1]) {
                o[0]=0x700|S[5];o[1]=(o[1]&0xC1FF&0xFE00)|(U16(S+2)&511)|0xC000;
                o[2]=(o[2]&0xFC00)|16;
                o[2]=(o[2]&0xF3FF)|((o[2]&0xC00)?0:0x400);o[2]=(o[2]&0xFFF)|0x1000;
            }else { o[0]=0xA0;o[1]=0xF0;o[2]=0xC00; }
        }
        CallbackFrame(UploadOam);if(S[6])++S[7];S[6]=S[6]==0;++S[8];
        for(unsigned i=0;i<4;++i)gOamBuffer[i][3]=U16(ROM(0x080B1E20)+(S[8]*4+i)*2);
    }while(ROM(0x080AC390)[S[7]*8]);
    CallbackFrame(HideObjects);
}
/*08012DDC: animation chooses a seed after one global random draw, then
 * restores that post-draw state, so particles do not consume gameplay RNG.
 * Particle stride32: x/y+0/+2; five signed x/y offsets at+4+j*4/+5+j*4;
 * descriptor+24,timer+25,delay+26,initial_hold+27,remaining+28,plane+29,
 * horizontal_flip+30. The caller clears the entire shared scratch first.*/
static void InitializeDestruction(uint8_t side)
{
    unsigned choice=(uint8_t)RandomByteInclusive(0,3);uint32_t saved=gRandomState;gRandomState=U32(ROM(0x08D35750)+choice*4);
    gBgOffsetsRaw[8]=0x2C10;ResetOam();BiosCpuSet(ROM(0x080AD3C0),gPaletteBuffer+0x200,0x10);CopyObjectTileRows(0,ROM(0x080AC3C0),0x80);
    for(unsigned col=0;col<3;++col)for(unsigned row=0;row<4;++row) {
        uint8_t *p=S+(col*4+row)*32;W16(p,(side?122:4)+col*40);int y=94-(int)(row*112/3);W16(p+2,y<0?y+256:y);
        p[24]=p[25]=0;p[27]=4;
        if(!row)p[26]+=NextRandomByte()%4;else p[26]+=NextRandomByte()%2+p[-6]+1;
        p[28]=3;p[29]=0;p[30]=NextRandomByte()%2;
    }
    for(unsigned i=0;i<12;++i)for(unsigned j=0;j<5;++j) { S[i*32+j*4+4]=16-NextRandomByte()%32;S[i*32+j*4+5]=20-NextRandomByte()%40; }
    gRandomState=saved;
}
/*08012B70*/
static void StepDestruction(unsigned step)
{
    for(unsigned i=0;i<12;++i) {
        uint8_t *p=S+i*32;
        if(p[26])--p[26];else if(p[28]) {
            if(p[27])--p[27];else if(step%3==0 || p[29]==1) { if(p[29]==1)--p[28];else p[29]=1; }
        }
    }
    for(unsigned i=0;i<12;++i) {
        uint8_t *p=S+i*32;if(!p[28] || p[26])continue;
        if(++p[25]>=ROM(0x080AC26C)[p[24]*8]) {
            p[25]=0;unsigned next=p[24]+1;
            unsigned oldTile=U16(ROM(U32(ROM(0x080AC270)+p[24]*8))+4)&1023;
            unsigned newTile=U16(ROM(U32(ROM(0x080AC270)+next*8))+4)&1023;
            p[24]=oldTile==newTile?0:next;
        }
    }
}
/*08012C74: second particle plane starts at OAM60. Each plane has60 slots.*/
static void DrawDestruction(void)
{
    uint16_t zero=0;BiosCpuSet(&zero,gOamBuffer,0x01000200);
    for(unsigned i=0;i<12;++i)for(unsigned j=0;j<5;++j) {
        uint8_t *p=S+i*32;unsigned index=i*5+j;
        if(!p[28] || p[26]) { ClearOamEntry(index);continue; }
        uint16_t *o=gOamBuffer[index+(p[29]?60:0)];
        o[0]=((U16(p+2)+(int8_t)p[j*4+5])&255)|(p[29]?0x8400:0x8000);
        o[1]=((U16(p)+(int8_t)p[j*4+4])&511)|0xC000|((p[30]&1)<<12);
        o[2]=U16(ROM(U32(ROM(0x080AC270)+p[24]*8))+4);o[3]=0;
    }
}
/*08012A74*/
static void DarkenCardPalette(uint8_t side)
{
    for(unsigned i=0;i<128;++i) {
        uint8_t *p=gPaletteBuffer+(i+(side==1?128:0))*2;uint16_t old=U16(p),value=old&0x8000;
        for(unsigned s=0;s<15;s+=5) { unsigned n=(old>>s)&31;value|=(n<3?0:n-2)<<s; }W16(p,value);
    }
}
/*08012928/12964/129EC*/
void AnimateBattleDestruction(uint8_t side)
{
    uint16_t zero=0;BiosCpuSet(&zero,S,0x0100218A);if(side>1)return;
    InitializeDestruction(side);CallbackFrame(ShowObjects);UploadObjects();PlayGameAudio(70);
    unsigned step=1,phase=0;
    do {
        if(!phase) {
            StepDestruction(step);DarkenCardPalette(side);DrawDestruction();
            unsigned alpha=ROM(0x080AC29C)[step%3];gBgOffsetsRaw[14]=((16-alpha)&31)|((alpha&31)<<8);
        }
        CallbackFrame(UploadOamBlend);UploadPalettes();if(++phase>2) { phase=0;++step; }
    }while(step<18);
    CallbackFrame(HideObjects);
}
/*08012358: opponent presentation precedes player presentation.*/
void PresentBattleAnimation(void)
{
    unsigned kind=gBattleDisplayBytes[0x18];if(!kind)return;
    uint16_t zero=0;BiosCpuSet(&zero,gBackgroundBuffer,0x01002000);BiosCpuSet(&zero,gBackgroundBuffer+0x4000,0x01002000);BiosCpuSet(&zero,gBackgroundBuffer+0xC000,0x01002000);
    gBattleAnimationFlags[0]=gBattleAnimationFlags[4]=0;SelectBattleAnimationFlags();
    LoadBattleCardMetadata(0);if(gBattleAnimationFlags[0]&1)StageBattleCard(0);
    LoadBattleCardMetadata(1);if(gBattleAnimationFlags[4]&1)StageBattleCard(1);
    CallbackFrame(BlankBattle);
    BiosCpuSet(gBackgroundBuffer,(void *)0x06000000,0x2000);BiosCpuSet(gBackgroundBuffer+0x4000,(void *)0x06004000,0x2000);BiosCpuSet(gBackgroundBuffer+0xC000,(void *)0x0600C000,0x2000);
    ResetOam();UploadOam();ResetBattleOffsets();gBgOffsetsRaw[8]=gBgOffsetsRaw[14]=gBgOffsetsRaw[12]=0;UploadBlend();
    CallbackFrame(ShowBattle);Wait(15);
    for(int side=1;side>=0;--side) {
        uint8_t flags=gBattleAnimationFlags[side*4];if(!(flags&6))continue;
        if(flags&2) { if(flags&128)AnimateBattleAttributeHit(side);else AnimateBattleHit(side);Wait(6); }
        if(flags&4)AnimateBattleDestruction(side);if(flags&64)AnimateBattleLifePoints(side);
        if(side==1 && (gBattleAnimationFlags[0]&6))Wait(30);
    }
    if(gBattleDisplayBytes[0x18]==5 || gBattleDisplayBytes[0x18]==8)Wait(30);
}
