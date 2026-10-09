/* AY7E password lookup080341B8..344A0 and entry UI0801827C..18D64.
 * Card-description presentation remains native. Semantic C, not linked or
 * execution-compared. Menu state aliases the native shared scratch workspace. */
#include "gba_bios.h"
extern uint8_t gPasswordMenu[6]; /*02018800: digit,key,unused,unused,blink,press*/
extern uint8_t gPasswordDigits[8],gPasswordRepeatTimer; /*02020D90 /02020D98*/
extern uint16_t gPasswordRepeated,gKeysPressed,gKeysHeld; /*02020D9C /0201FCAC /0201FCA8*/
extern uint8_t gPasswordResult[11],gUsedBonusPasswords[2]; /*02023740 /020237C4*/
extern const uint8_t gCardPasswords[902][8],gBonusPasswords[4][8],gPasswordEnd[8],gPasswordSkip[8];
extern uint8_t gBackgroundBuffer[],gActorGraphicsBuffer[],gPaletteBuffer[];
extern uint16_t gOamBuffer[128][4],gBgOffsetsRaw[22];
extern void SetVBlankCallback(void (*)(void)),WaitForFrame(void),UploadPalettes(void),UploadOam(void),UploadBackgroundOffsets(void);
extern void PlayGameAudio(uint32_t),LoadCardMetadata(uint32_t),AddPersistentShopStock(uint16_t,uint8_t);
extern void AddMoney(uint64_t),AddNativeDeckCapacity(uint32_t),RefreshNativeDuelistLevel(void);
extern void ShowCardDescription(void);
#define ROM(a) ((const uint8_t *)(uintptr_t)(a))
#define REG(a) (*(volatile uint16_t *)(uintptr_t)(a))
static uint16_t Read16(const uint8_t *p) { return p[0]|(uint16_t)p[1]<<8; }
static const uint8_t *Pointer(const uint8_t *p) { return ROM(p[0]|(uint32_t)p[1]<<8|(uint32_t)p[2]<<16|(uint32_t)p[3]<<24); }
/*08034260 always examines all8 bytes;10 means equal,11 unequal.*/
uint8_t ComparePasswords(const uint8_t *a,const uint8_t *b)
{ uint8_t result=10;for(unsigned i=0;i<8;++i)if(a[i]!=b[i])result=11;return result; }
/*08034218 /08034364*/
static uint8_t PasswordRecordKind(const uint8_t *record)
{ return ComparePasswords(gPasswordEnd,record)==10?0:ComparePasswords(gPasswordSkip,record)==10?1:2; }
/*080341B8 /08034304*/
static void FindPassword(const uint8_t (*table)[8])
{
    uint16_t index=0;gPasswordResult[0]=gPasswordResult[1]=0;
    for(;;) {
        uint8_t kind=PasswordRecordKind(table[index]);
        if(!kind) { gPasswordResult[2]=11;return; }
        if(kind!=1 && ComparePasswords(gPasswordResult+3,table[index])==10) { gPasswordResult[2]=10;return; }
        ++index;gPasswordResult[0]=index;gPasswordResult[1]=index>>8;
    }
}
void FindCardPassword(void) { FindPassword(gCardPasswords); }
void FindBonusPassword(void) { FindPassword(gBonusPasswords); }
/*08034450 /08034478 /080343AC*/
void MarkBonusPasswordUsed(uint16_t id) { gUsedBonusPasswords[id>>3]|=1u<<(id&7); }
uint8_t BonusPasswordUsed(uint16_t id) { return id<10 && (gUsedBonusPasswords[id>>3]&(1u<<(id&7)))!=0; }
void ApplyBonusPassword(uint16_t id)
{
    if(id==1) { AddMoney(50000);PlayGameAudio(201); }
    else if(id==2) { AddNativeDeckCapacity(100);RefreshNativeDuelistLevel();PlayGameAudio(201); }
}
/*08018E08 /0801843C: highest set key wins, repeated navigation overrides presses.*/
uint16_t ReadPasswordKey(void)
{
    gPasswordRepeated=gKeysPressed&1023;
    if(gPasswordRepeated) { gPasswordRepeated=gKeysPressed;gPasswordRepeatTimer=10; }
    else if(!gPasswordRepeatTimer) { gPasswordRepeated=gKeysHeld;gPasswordRepeatTimer=3; }
    else --gPasswordRepeatTimer;
    uint16_t key=0;
    for(unsigned bit=1;bit<1024;bit<<=1)if(gKeysPressed&bit)key=bit;
    for(unsigned bit=16;bit<1024;bit<<=1)if(gPasswordRepeated&bit)key=bit;
    return key;
}
/*080186C0/18750/187E0/18870. Defaults retain out-of-domain menu-key values.*/
void MovePasswordKey(unsigned direction)
{
    static const uint8_t next[4][11]={{1,4,5,6,7,8,9,0,10,10,2},{7,0,10,10,1,2,3,4,5,6,8},
        {10,3,1,2,6,4,5,9,7,8,0},{10,2,3,1,5,6,4,8,9,7,0}};
    if(gPasswordMenu[1]<11)gPasswordMenu[1]=next[direction][gPasswordMenu[1]];
}
/*08018910 /1892C*/
static void MovePasswordDigit(unsigned right)
{ uint8_t n=gPasswordMenu[0];gPasswordMenu[0]=right?(n<7?n+1:0):(n?n-1:7); }
/*0801862C /1868C*/
static unsigned PasswordPressFrame(void)
{ uint8_t n=gPasswordMenu[5];return !n?0:(uint8_t)(n-4)<2?2:1; }
/*08018A88 /18B54: X deliberately masks the source to8 bits, not9.*/
static void DrawPasswordDigit(unsigned slot,unsigned blink)
{
    unsigned index=(uint8_t)(gPasswordDigits[slot]+blink*10);
    const uint8_t *frame=Pointer(ROM(0x08D364BC)+index*4),*oam=Pointer(frame+4);
    uint16_t a=Read16(oam),b=Read16(oam+2),c=Read16(oam+4);
    gOamBuffer[slot][0]=(a&0xFF00)|((a+18)&255);
    gOamBuffer[slot][1]=(b&0xFE00)|(((b&255)+slot*16+56)&511);
    gOamBuffer[slot][2]=(c&0xFFF)|(((c>>12)+3)<<12);gOamBuffer[slot][3]=0;
}
static void DrawPasswordSelectedDigit(void) { DrawPasswordDigit(gPasswordMenu[0],gPasswordMenu[4]>15); }
/*080189A0*/
static void DrawPasswordKey(void)
{
    unsigned press=PasswordPressFrame();
    const uint8_t *frames=Pointer(ROM(press?0x08D36648:0x08D36568)+gPasswordMenu[1]*4);
    const uint8_t *oam=Pointer(frames+(press?(press-1)*8:0)+4);
    uint16_t a=Read16(oam),b=Read16(oam+2);
    gOamBuffer[8][0]=(a&0xFF00)|((a+48)&255);gOamBuffer[8][1]=(b&0xFE00)|((b+72)&511);
    gOamBuffer[8][2]=Read16(oam+4);gOamBuffer[8][3]=0;
}
/*08018524*/
void FadePaletteForPassword(void)
{
    for(unsigned frame=0;frame<16;++frame) {
        for(unsigned i=0;i<512;++i) {
            uint16_t old=Read16(gPaletteBuffer+i*2),value=old&0x8000;
            for(unsigned shift=0;shift<15;shift+=5) { unsigned c=(old>>shift)&31;value|=(c<2?0:c-2)<<shift; }
            gPaletteBuffer[i*2]=value;gPaletteBuffer[i*2+1]=value>>8;
        }
        SetVBlankCallback(UploadPalettes);WaitForFrame();
    }
}
/*08018C0C*/
static void LoadPasswordGraphics(void)
{
    BiosCpuSet(ROM(0x080BA2E4),gBackgroundBuffer,0x04000800);
    BiosCpuSet(ROM(0x080BC2E4),gBackgroundBuffer+0x2000,0x04000800);
    BiosCpuSet(ROM(0x080BE2E4),gPaletteBuffer,0x04000020);
    for(unsigned row=0;row<20;++row)BiosCpuSet(ROM(0x080BE364)+row*60,gBackgroundBuffer+0xF800+row*64,0x0400000F);
    BiosLz77UnpackWram(ROM(0x080BEC5C),gActorGraphicsBuffer);
    BiosCpuSet(ROM(0x080BE994),gPaletteBuffer+0x200,0x04000018);BiosCpuSet(ROM(0x080BE814),gPaletteBuffer+0x260,0x04000010);
}
/*08018D24 /18CE8 /18D10*/
static void PasswordBlankCallback(void)
{
    REG(0x05000000)=0;REG(0x04000000)=0;REG(0x04000050)=0;REG(0x04000052)=0;REG(0x04000054)=0;
    REG(0x0400000E)=0x1F03;gBgOffsetsRaw[6]=gBgOffsetsRaw[0]=0;UploadBackgroundOffsets();
}
static void PasswordShowCallback(void) { UploadPalettes();REG(0x04000000)=0x1800; }
static void PasswordIdleCallback(void) {}
static void PasswordFadeCallback(void) { REG(0x04000050)=gBgOffsetsRaw[8];REG(0x04000052)=gBgOffsetsRaw[14];REG(0x04000054)=gBgOffsetsRaw[12]; }
/*080184AC /18CBC /18960 /18D00*/
static void InitializePasswordMenu(void)
{
    for(unsigned i=0;i<8;++i)gPasswordDigits[i]=0;
    gPasswordMenu[0]=0;gPasswordMenu[1]=1;gPasswordMenu[4]=gPasswordMenu[5]=0;
    for(unsigned i=0;i<128;++i) { gOamBuffer[i][0]=160;gOamBuffer[i][1]=240;gOamBuffer[i][2]=0xC00;gOamBuffer[i][3]=0; }
    LoadPasswordGraphics();for(unsigned i=0;i<8;++i)DrawPasswordDigit(i,0);DrawPasswordKey();
    SetVBlankCallback(PasswordBlankCallback);WaitForFrame();
    for(unsigned i=0;i<4;++i)BiosCpuSet(gBackgroundBuffer+i*0x4000,(void *)(uintptr_t)(0x06000000+i*0x4000),0x2000);
    for(unsigned i=0;i<2;++i)BiosCpuSet(gActorGraphicsBuffer+i*0x4000,(void *)(uintptr_t)(0x06010000+i*0x4000),0x2000);
    UploadOam();SetVBlankCallback(PasswordShowCallback);WaitForFrame();
}
static void PasswordFrame(void) { SetVBlankCallback(PasswordIdleCallback);WaitForFrame();UploadOam(); }
static void TickPasswordTimers(void)
{ gPasswordMenu[4]=gPasswordMenu[4]<30?gPasswordMenu[4]+1:0;if(gPasswordMenu[5])--gPasswordMenu[5]; }
/*0801827C: B moves the input digit; it does not cancel this menu.*/
uint32_t RunPasswordEntry(void)
{
    FadePaletteForPassword();InitializePasswordMenu();unsigned done=0;
    do {
        uint16_t key=ReadPasswordKey();unsigned sound=0;
        if(key==16 || key==32 || key==64 || key==128) {
            gPasswordMenu[5]=0;MovePasswordKey(key==64?0:key==128?1:key==32?2:3);
            DrawPasswordKey();DrawPasswordSelectedDigit();sound=54;
        }else if(key==2 || key==256 || key==512) {
            gPasswordMenu[4]=0;DrawPasswordSelectedDigit();MovePasswordDigit(key==256);gPasswordMenu[4]=15;
            DrawPasswordSelectedDigit();DrawPasswordKey();sound=54;
        }else if(key==4 || key==8) {
            gPasswordMenu[5]=0;gPasswordMenu[1]=10;DrawPasswordSelectedDigit();DrawPasswordKey();sound=54;
        }else if(key==1) {
            if(gPasswordMenu[1]==10) {
                done=1;gPasswordMenu[5]=8;gPasswordMenu[4]=0;DrawPasswordSelectedDigit();DrawPasswordKey();
            }else {
                if(gPasswordMenu[1]<10)gPasswordDigits[gPasswordMenu[0]]=gPasswordMenu[1];
                gPasswordMenu[5]=8;gPasswordMenu[4]=0;DrawPasswordSelectedDigit();DrawPasswordKey();
                if(gPasswordMenu[0]==7) { gPasswordMenu[5]=0;gPasswordMenu[1]=10;DrawPasswordSelectedDigit();DrawPasswordKey(); }
                else { MovePasswordDigit(1);gPasswordMenu[4]=15;DrawPasswordSelectedDigit(); }
            }
            sound=55;
        }else { DrawPasswordSelectedDigit();DrawPasswordKey(); }
        if(sound)PlayGameAudio(sound);PasswordFrame();TickPasswordTimers();
    }while(!done);
    for(;;) { DrawPasswordSelectedDigit();DrawPasswordKey();SetVBlankCallback(PasswordIdleCallback);WaitForFrame();if(!PasswordPressFrame())break;TickPasswordTimers(); }
    return 1;
}
/*080184E8*/
void FadePasswordDisplay(void)
{ gBgOffsetsRaw[8]=255;for(unsigned i=0;i<16;++i) { gBgOffsetsRaw[12]=i&31;SetVBlankCallback(PasswordFadeCallback);WaitForFrame(); } }
/*0803428C*/
void RunPasswordFeature(void)
{
    RunPasswordEntry();for(unsigned i=0;i<8;++i)gPasswordResult[i+3]=gPasswordDigits[i];FindCardPassword();
    if(gPasswordResult[2]==10) { LoadCardMetadata(Read16(gPasswordResult));PlayGameAudio(95);ShowCardDescription();AddPersistentShopStock(Read16(gPasswordResult),1); }
    else { FindBonusPassword();uint16_t id=Read16(gPasswordResult);if(gPasswordResult[2]==10 && !BonusPasswordUsed(id)) { MarkBonusPasswordUsed(id);ApplyBonusPassword(id); } }
    FadePasswordDisplay();
}

/*080343DC/3440C: separate113-byte per-card password-use bank.*/
extern uint8_t gUsedCardPasswords[113]; /*02023750*/
void ClearUsedCardPasswords(void) { for(unsigned i=0;i<113;++i)gUsedCardPasswords[i]=0; }
void MarkCardPasswordUsed(uint16_t id) { gUsedCardPasswords[id>>3]|=1u<<(id&7); }
/*080344A8/344CC/344F0/34504/34518. This unused editor sets a digit to
 * FF then increments it to0, or to10 then decrements it to9. It does not
 * increment/decrement the previous value. Held-key equality is exact. */
extern uint8_t gLegacyPasswordCursor; /*020237C8*/
void LegacyPasswordDigitUp(void) { gPasswordResult[3+gLegacyPasswordCursor]=255;++gPasswordResult[3+gLegacyPasswordCursor]; }
void LegacyPasswordDigitDown(void) { gPasswordResult[3+gLegacyPasswordCursor]=10;--gPasswordResult[3+gLegacyPasswordCursor]; }
void LegacyPasswordLeft(void) { if(gLegacyPasswordCursor)--gLegacyPasswordCursor; }
void LegacyPasswordRight(void) { if(gLegacyPasswordCursor!=7)++gLegacyPasswordCursor; }
uint8_t RunLegacyPasswordEditor(void)
{
    for(;;) { uint8_t done=0,result=0;switch(gKeysHeld) { case 16:LegacyPasswordRight();break;case 32:LegacyPasswordLeft();break;case 64:LegacyPasswordDigitUp();break;case 128:LegacyPasswordDigitDown();break;case 1:done=1;result=1;break;case 2:done=1;break; }WaitForFrame();if(done)return result; }
}
