/* AY7E dormant duel-record viewer08019D64..1A640. Page0 shows the player;
 * subsequent pages show four grade-gated opponents. Native tile/palette
 * addressing and the sixteen-byte OAM update are retained. */
#include "gba_bios.h"
extern uint8_t gRecordMenuState[2]; /*02018800, shared menu scratch*/
extern uint8_t gBackgroundBuffer[],gActorGraphicsBuffer[],gPaletteBuffer[],gPlayerName[19],gDecimalDigits[5];
extern uint16_t gOamBuffer[128][4],gBgOffsetsRaw[22],gKeysPressed,gPasswordRepeated;
extern uint16_t gDuelRecordHeader[2],gDuelRecords[25][2];
extern void PollMenuRepeat(void),DuelRecordsNoop(void),ClearMenuGraphics(void),UploadMenuGraphics(void),UploadOam(void),UploadPalettes(void),UploadBackgroundOffsets(void);
extern void RenderBitmapString(void *,const uint8_t *,uint16_t),FormatDecimalDigits(uint16_t,uint8_t),CopyObjectTileRows(uint8_t,const uint8_t *,uint16_t);
extern void SetVBlankCallback(void (*)(void)),WaitForFrame(void),m4aSongNumStart(uint16_t);
extern uint8_t GetDuelRecordGrade(void);
extern uint32_t GetDuelistLevel(void),GetDeckCapacity(void);
#define ROM(a) ((const uint8_t *)(uintptr_t)(a))
#define REG(a) (*(volatile uint16_t *)(uintptr_t)(a))
#define BG(a) (gBackgroundBuffer+((a)-0x02000400))
static uint32_t U32(const uint8_t *p) { return p[0]|(uint32_t)p[1]<<8|(uint32_t)p[2]<<16|(uint32_t)p[3]<<24; }
static void W16(uint8_t *p,uint16_t v) { p[0]=v;p[1]=v>>8; }
static void Frame(void (*fn)(void)) { SetVBlankCallback(fn);WaitForFrame(); }
/*08019EC4/EF0/F1C/F28/F48/F94*/
void NextDuelRecordPage(void)
{ if(gRecordMenuState[0]<gRecordMenuState[1]) { ++gRecordMenuState[0];m4aSongNumStart(54); }else { gRecordMenuState[0]=gRecordMenuState[1];m4aSongNumStart(57); } }
void PreviousDuelRecordPage(void)
{ if(gRecordMenuState[0]) { --gRecordMenuState[0];m4aSongNumStart(54); }else m4aSongNumStart(57); }
uint8_t GetDuelRecordPage(void) { return gRecordMenuState[0]; }
uint8_t GetDuelRecordArrows(void)
{ return (gRecordMenuState[0]!=0)|((gRecordMenuState[0]!=gRecordMenuState[1])?2:0); }
uint8_t GetRecordPageOpponent(uint8_t row)
{ uint8_t index=row+gRecordMenuState[0]*4;if(index<28 && ROM(0x080C089C)[index]<=GetDuelRecordGrade())return ROM(0x080C0880)[index];return 0; }
void InitializeDuelRecordPage(void) { gRecordMenuState[0]=0;gRecordMenuState[1]=ROM(0x080C08B8)[GetDuelRecordGrade()]; }
/*08019E5C. Repeat directions override freshly pressed buttons.*/
uint16_t ReadDuelRecordInput(void)
{ PollMenuRepeat();uint16_t key=0;for(unsigned bit=1;bit<1024;bit<<=1)if(gKeysPressed&bit)key=bit;for(unsigned bit=16;bit<1024;bit<<=1)if(gPasswordRepeated&bit)key=bit;return key; }
/*08019FC0/1A024*/
void DrawRecordNumber(uint16_t *map,uint16_t number,uint8_t palette,uint8_t count)
{ if(count>5)count=5;FormatDecimalDigits(number,0);for(unsigned i=0;i<count;++i) { uint8_t tile=gDecimalDigits[i+5-count]+1;map[i]=tile|((palette&15)<<12);map[i+32]=(uint8_t)(tile+11)|((palette&15)<<12); } }
void DrawRecordTextMap(uint16_t *map,uint16_t tile,uint8_t palette,uint8_t count)
{ for(unsigned i=0;i<count;++i,tile+=4,map+=2) { map[0]=(tile&1023)|((palette&15)<<12);map[1]=((tile+1)&1023)|((palette&15)<<12);map[32]=((tile+2)&1023)|((palette&15)<<12);map[33]=((tile+3)&1023)|((palette&15)<<12); } }
/*0801A090*/
void DrawDuelRecordArrows(void)
{
    uint8_t flags=GetDuelRecordArrows();uint16_t *a=gOamBuffer[0],*b=gOamBuffer[1];
    a[0]=(a[0]&0xFF00)|((flags&1)?0:0xA0);a[1]=(a[1]&0xFE00)|((flags&1)?0x70:0xF0);
    b[0]=(b[0]&0xFF00)|((flags&2)?0x91:0xA0);b[1]=(b[1]&0xFE00)|((flags&2)?0x70:0xF0);
}
/*0801A124/1E0*/
void DrawPlayerDuelRecords(void)
{
    RenderBitmapString(BG(0x020086E0),gPlayerName,0x900);DrawRecordTextMap((uint16_t *)BG(0x0200DDA4),23,15,4);
    DrawRecordNumber((uint16_t *)BG(0x0200DE6E),GetDuelistLevel(),14,3);DrawRecordNumber((uint16_t *)BG(0x0200DF2C),GetDeckCapacity(),14,4);
    uint16_t total=gDuelRecordHeader[0]+gDuelRecordHeader[1];if(total>999)total=999;
    DrawRecordNumber((uint16_t *)BG(0x0200DFDC),total,14,3);DrawRecordNumber((uint16_t *)BG(0x0200DFE4),gDuelRecordHeader[0],14,3);DrawRecordNumber((uint16_t *)BG(0x0200DFEC),gDuelRecordHeader[1],14,3);
}
void DrawOpponentDuelRecords(void)
{
    for(unsigned row=0;row<4;++row) {
        uint8_t id=GetRecordPageOpponent(row);RenderBitmapString(BG(0x02008AE0)+row*0x400,ROM(U32(ROM(0x08D34988)+id*4)),0x900);
        uint16_t total=gDuelRecords[id][0]+gDuelRecords[id][1];if(total>999)total=999;
        uint8_t *map=BG(0x0200D5A2)+row*0xC0;DrawRecordNumber((uint16_t *)map,total,14,3);DrawRecordNumber((uint16_t *)(map+8),gDuelRecords[id][0],14,3);DrawRecordNumber((uint16_t *)(map+16),gDuelRecords[id][1],14,3);
    }
}
/*0801A278*/
void LoadDuelRecordGraphics(void)
{
    BiosLz77UnpackWram(ROM(0x080C08BC),gBackgroundBuffer);BiosCpuSet(ROM(0x080C4B30),gPaletteBuffer,0x04000038);
    static const uint32_t maps[4]={0x080C4C10,0x080C50C0,0x080C5570,0x080C5A20};static const unsigned offsets[4]={0xF800,0xE800,0xF000,0xE000};
    for(unsigned m=0;m<4;++m)for(unsigned row=0;row<20;++row)BiosCpuSet(ROM(maps[m])+row*60,gBackgroundBuffer+offsets[m]+row*64,0x0400000F);
    BiosCpuSet(ROM(0x080C5ED0),BG(0x02008420),0x040000B0);BiosCpuSet(ROM(0x080C6190),gPaletteBuffer+0x1C0,0x04000008);
    W16(gPaletteBuffer+0x1E0,0);W16(gPaletteBuffer+0x1E2,0x7FFF);W16(gPaletteBuffer+0x1E4,0);DrawPlayerDuelRecords();
    for(unsigned i=0;i<4;++i)DrawRecordTextMap((uint16_t *)(BG(0x0200D582)+i*0xC0),0x37+i*0x20,15,8);
    CopyObjectTileRows(0,ROM(0x080C61B0),32);BiosCpuSet(ROM(0x080C65B0),gPaletteBuffer+0x200,0x04000008);
    gOamBuffer[0][1]=0x6000;gOamBuffer[0][2]=0;gOamBuffer[1][1]=0x4000;gOamBuffer[1][2]=0;
}
/*0801A420/470/488/498/4EC/4F8/54C/59C*/
void ClearDuelRecordGraphics(void)
{ uint16_t zero=0;BiosCpuSet(&zero,gBackgroundBuffer+0x8000,0x01002000);BiosCpuSet(&zero,gBackgroundBuffer+0xC000,0x01002000);for(unsigned i=0;i<128;++i) { gOamBuffer[i][0]=0xA0;gOamBuffer[i][1]=0xF0;gOamBuffer[i][2]=0xC00;gOamBuffer[i][3]=0; } }
void ShowDuelRecordScreen(void) { UploadPalettes();REG(0x04000000)=0x1E00; }
void UploadDuelRecordScreen(void) { UploadMenuGraphics();UploadOam(); }
void SelectPlayerRecordMaps(void) { static const unsigned values[3]={0x1B00,0x1E00,0x1F00};for(unsigned i=0;i<3;++i) { REG(0x0400000A+i*2)&=0xE0FF;REG(0x0400000A+i*2)|=values[i]; } }
void UploadDuelRecordArrows(void) { UploadOam(); }
void SelectOpponentRecordMaps(void) { static const unsigned values[3]={0x1A00,0x1C00,0x1D00};for(unsigned i=0;i<3;++i) { REG(0x0400000A+i*2)&=0xE0FF;REG(0x0400000A+i*2)|=values[i]; } }
void UploadOpponentRecords(void)
{ BiosCpuSet(BG(0x0200D400),(void *)0x0600D000,0x04000200);BiosCpuSet(BG(0x02008AE0),(void *)0x060086E0,0x04000400);BiosCpuSet(gOamBuffer,(void *)0x07000000,0x04000004); }
void InitializeDuelRecordDisplay(void)
{
    REG(0x05000000)=0;REG(0x04000000)=0;gBgOffsetsRaw[8]=gBgOffsetsRaw[14]=gBgOffsetsRaw[12]=0;
    REG(0x04000050)=0;REG(0x04000052)=0;REG(0x04000054)=0;
    REG(0x0400000A)=0x1B09;REG(0x0400000C)=0x1E02;REG(0x0400000E)=0x1F03;
    gBgOffsetsRaw[10]=gBgOffsetsRaw[18]=gBgOffsetsRaw[2]=gBgOffsetsRaw[20]=gBgOffsetsRaw[6]=gBgOffsetsRaw[0]=0;UploadBackgroundOffsets();
}
/*08019E20/DB8/DDC/D64*/
void InitializeDuelRecordMenu(void)
{ DuelRecordsNoop();InitializeDuelRecordPage();ClearDuelRecordGraphics();Frame(InitializeDuelRecordDisplay);LoadDuelRecordGraphics();DrawDuelRecordArrows();UploadDuelRecordScreen();Frame(ShowDuelRecordScreen); }
void DuelRecordPageDown(void)
{ NextDuelRecordPage();DrawOpponentDuelRecords();DrawDuelRecordArrows();UploadOpponentRecords();Frame(SelectOpponentRecordMaps); }
void DuelRecordPageUp(void)
{ PreviousDuelRecordPage();DrawDuelRecordArrows();if(!GetDuelRecordPage()) { UploadDuelRecordArrows();Frame(SelectPlayerRecordMaps); }else { DrawOpponentDuelRecords();UploadOpponentRecords();Frame(SelectOpponentRecordMaps); } }
void RunDuelRecordMenu(void)
{ InitializeDuelRecordMenu();m4aSongNumStart(43);for(;;) { uint16_t key=ReadDuelRecordInput();if(key==64)DuelRecordPageUp();else if(key==128)DuelRecordPageDown();else if(key==2) { ClearMenuGraphics();Frame(ShowDuelRecordScreen);return; }else WaitForFrame(); } }
/*0801A624: unused pointer accessor, distinct from opponent name lookup.*/
const uint8_t *GetDuelRecordText(uint8_t index) { return ROM(U32(ROM(0x08D419E0)+index*4)); }
