/* AY7E name-entry screen0800181C..08003118. Byte offsets describe the original
 * shared02018800 workspace, including 8 name glyphs and 154 keyboard glyphs.
 * The ninth editing slot supports combining marks; it is not a ninth saved
 * character. Original repeat/pressed priority and live OAM ordering retained. */
#include <stdint.h>
#include "gba_bios.h"
extern uint8_t gNameEntryScratch[0x4314]; /*02018800*/
extern uint8_t gPlayerName[19],gBackgroundBuffer[],gActorGraphicsBuffer[],gPaletteBuffer[];
extern uint16_t gOamBuffer[128][4],gBgOffsetsRaw[22],gKeysPressed,gKeysRepeated;
extern const uint8_t *const gAsciiGlyphCodes[];
extern void ClearMenuGraphics(void),UploadMenuGraphics(void),UploadOam(void),UploadPalettes(void),UploadBackgroundOffsets(void);
extern void PlayGameAudio(uint32_t),FadeGameMusic(uint16_t),WaitForFrame(void),SetVBlankCallback(void (*)(void));
extern void RenderBitmapGlyph(void *,uint16_t,uint16_t);
#define S gNameEntryScratch
#define X S[0]
#define Y S[1]
#define POSITION S[2]
#define FOCUS S[3]
#define PAGE S[0x32]
#define ROM(a) ((const uint8_t *)(uintptr_t)(a))
#define REG(a) (*(volatile uint16_t *)(uintptr_t)(a))
static uint16_t U16(const uint8_t *p) { return p[0]|(uint16_t)p[1]<<8; }
static uint32_t U32(const uint8_t *p) { return U16(p)|(uint32_t)U16(p+2)<<16; }
static void W16(uint8_t *p,uint16_t v) { p[0]=v;p[1]=v>>8; }
static const uint8_t *PageText(void) { return ROM(U32(ROM(0x08D30C84)+PAGE*4)); }
static unsigned Length(const uint8_t *p) { unsigned n=0;while(p[n])++n;return n; }
/*0803B5AC is strncpy, not a raw buffer copy.*/
static void CopyText(uint8_t *out,const uint8_t *in,unsigned n)
{ unsigned i=0;while(i<n && in[i]) { out[i]=in[i];++i; }while(i<n)out[i++]=0; }
static void UploadNameTiles(void) { BiosCpuSet(gBackgroundBuffer+0x8000,(void *)0x06008000,0x2000); }
/*080174D8, mode0901: literal string, with no language/$ processing.*/
static void RenderNameText(uint8_t *out,const uint8_t *p)
{
    unsigned odd=0;while(*p) {
        uint16_t glyph;if(*p&128) { glyph=U16(p);p+=2; }else { glyph=U16(gAsciiGlyphCodes[*p-32]);++p; }
        RenderBitmapGlyph(out,glyph,0x901);out+=odd?96:32;odd^=1;
    }
}
static void DrawNameGlyph(unsigned i)
{ RenderBitmapGlyph(gBackgroundBuffer+0x8000+((i>>1)*4+(i&1)+1)*32,U16(S+14+i*2),0x901); }
/*080023C4*/
void LoadNameKeyboardPage(void)
{
    unsigned scroll=U16(S+0x16A);const uint8_t *text=PageText();
    if(!scroll && (Length(text)>>1)<154 && PAGE!=5)for(unsigned i=0;i<0x4D00;++i)gBackgroundBuffer[0x8620+i]=0;
    CopyText(S+0x34,text+scroll*2,0x134);RenderNameText(gBackgroundBuffer+0x8620,S+0x34);UploadNameTiles();
}
/*08001BD0*/
void InitializeNameEntry(void)
{
    for(unsigned i=0;i<0x4314;++i)S[i]=0;CopyText(S+14,gPlayerName,19);
    for(unsigned i=0;i<8;++i)if(!U16(S+14+i*2))W16(S+14+i*2,0x4081);
    W16(S+0x1E,0);W16(S+0x16C,0x100);W16(S+0x16E,0x100);PAGE=3;
}
static int CanVoice(uint16_t glyph)
{
    switch(glyph) {
    case 0x4A83:case 0x4C83:case 0x4E83:case 0x5083:case 0x5281:case 0x5283:case 0x5481:case 0x5483:
    case 0x5683:case 0x5883:case 0x5A83:case 0x5C83:case 0x5E83:case 0x6083:case 0x6383:case 0x6583:
    case 0x6783:case 0x6E83:case 0x7183:case 0x7483:case 0x7783:case 0x7A83:case 0xA982:case 0xAB82:
    case 0xAD82:case 0xAF82:case 0xB182:case 0xB382:case 0xB582:case 0xB782:case 0xB982:case 0xBB82:
    case 0xBD82:case 0xBF82:case 0xC282:case 0xC482:case 0xC682:case 0xCD82:case 0xD082:case 0xD382:
    case 0xD682:case 0xD982:return 1;default:return 0;
    }
}
static int CanSemiVoice(uint16_t glyph)
{
    switch(glyph) { case 0x6E83:case 0x7183:case 0x7483:case 0x7783:case 0x7A83:case 0xCD82:case 0xD082:case 0xD382:case 0xD682:case 0xD982:return 1;default:return 0; }
}
/*08001C40*/
void InsertNameGlyph(void)
{
    if(PAGE==5)return;unsigned position=POSITION;uint8_t *slot=S+14+position*2;
    W16(S+0x20+position*2,U16(slot));W16(slot,U16(S+0x34+Y*44+X*4));
    if(position) {
        uint16_t glyph=U16(slot);
        if(glyph==0x4A81 || glyph==0x4B81) {
            W16(slot,U16(S+0x20+position*2));uint16_t previous=U16(slot-2);
            if(glyph==0x4A81 && previous==0x4583) { --POSITION;W16(slot-2,0x9483); }
            else if(glyph==0x4A81?CanVoice(previous):CanSemiVoice(previous)) { --POSITION;W16(slot-2,previous+(glyph==0x4A81?256:512)); }
            else W16(slot,glyph);
        }else if(position>7) { POSITION=7;W16(S+0x1C,U16(S+0x1E)); }
    }
    for(unsigned i=0;i<8;++i)DrawNameGlyph(i);UploadNameTiles();if(POSITION<8)++POSITION;if(POSITION==8)PAGE=5;
}
/*0800244C*/
void DeleteNameGlyph(void)
{ if(PAGE!=5) { if(POSITION)--POSITION;W16(S+14+POSITION*2,0x4081);DrawNameGlyph(POSITION);UploadNameTiles(); } }
/*080022EC*/
static void ScrollKeyboard(void)
{
    if(Length(PageText())<=308)return;unsigned scroll=U16(S+0x16A);
    if((gKeysRepeated&64) && Y==0)scroll=scroll<12?0:scroll-11;
    if((gKeysRepeated&128) && Y==6) { unsigned n=Length(PageText())>>1;scroll=scroll+165<n?scroll+11:n-154; }
    W16(S+0x16A,scroll);if(gKeysRepeated&192)LoadNameKeyboardPage();
}
static void ReturnToCharacterGroup(void)
{ PAGE=2;X=U16(S+10);Y=U16(S+12);W16(S+0x16A,0);LoadNameKeyboardPage(); }
/*08002078*/
static void HandleKeyboardInput(void)
{
    if(gKeysRepeated&64) {
        PlayGameAudio(54);if(Y==7)Y=6;else if(!Y) { if(!U16(S+0x16A) && (Length(PageText())>>1)<155)Y=6; }else --Y;
    }
    if(gKeysRepeated&128) {
        PlayGameAudio(54);if(Y==255)Y=0;else if(Y<6)++Y;else if(!U16(S+0x16A) && (Length(PageText())>>1)<155)Y=0;
    }
    if(gKeysRepeated&32) { PlayGameAudio(54);if(!X) { X=10;FOCUS=1;PAGE=5; }else if(PAGE<3 && X==6)X=4;else --X; }
    if(gKeysRepeated&16) { PlayGameAudio(54);if(X<10) { if(PAGE<3 && X==4)X=6;else ++X; }else { X=0;FOCUS=1;PAGE=5; } }
    if(gKeysRepeated&1) {
        PlayGameAudio(55);
        if(PAGE==2) {
            if(U16(S+0x34+Y*44+X*4)==0x4081)InsertNameGlyph();
            else { PAGE=X+6+Y*11;W16(S+10,X);W16(S+12,Y);X=Y=0;W16(S+0x16A,0); }
            LoadNameKeyboardPage();
        }else { InsertNameGlyph();if(PAGE>5)ReturnToCharacterGroup(); }
    }
    if(gKeysRepeated&2) { PlayGameAudio(56);if(PAGE<6)DeleteNameGlyph();else ReturnToCharacterGroup(); }
}
static void HideOam(unsigned i) { gOamBuffer[i][0]=0xA0;gOamBuffer[i][1]=0xF0;gOamBuffer[i][2]=0xC00; }
static void CopyOam(unsigned i,const uint8_t *source,uint16_t flags)
{ gOamBuffer[i][0]=U16(source);gOamBuffer[i][1]=U16(source+2);gOamBuffer[i][2]=U16(source+4)|flags; }
static unsigned DrawFrame(unsigned at,const uint8_t *frame,uint16_t flags,int visible)
{
    const uint8_t *parts=ROM(U32(frame+4));for(unsigned j=0;j<frame[1];++j,++at) { if(visible)CopyOam(at,parts+j*8,flags);else HideOam(at); }return at;
}
/*080024D4*/
static void DrawKeyboardLabels(void)
{
    unsigned at=0;for(unsigned i=0;i<5;++i)if(PAGE<=5 || i!=2)at=DrawFrame(at,ROM(U32(ROM(0x08D30C28)+i*4)),0x400,1);
    if(PAGE>5)for(unsigned i=0;i<2;++i)CopyOam(at+i,ROM(0x08D306F0)+i*8,0x400);
}
/*08002A00 writes both attributes and affine padding as32-bit stores.*/
static void DrawNameCursors(void)
{
    if(!FOCUS) { gOamBuffer[23][0]=0x300|((Y*16+31)&255);gOamBuffer[23][1]=0x4000|((X*16+3)&511);gOamBuffer[23][2]=0x514E; }
    else HideOam(23);gOamBuffer[23][3]=0;
    if(POSITION<8) { gOamBuffer[24][0]=0x8408;gOamBuffer[24][1]=0x200|((POSITION*8+64)&511);gOamBuffer[24][2]=0x458B; }
    else HideOam(24);gOamBuffer[24][3]=0;
}
static void UploadBlend(void) { REG(0x04000050)=gBgOffsetsRaw[8];REG(0x04000052)=gBgOffsetsRaw[14];REG(0x04000054)=gBgOffsetsRaw[12]; }
/*08002E24*/
static void FadeOutNameEntry(void)
{
    int delay=6;gBgOffsetsRaw[8]=0x6D6;gBgOffsetsRaw[14]=0xC0A;gBgOffsetsRaw[12]=0;POSITION=8;DrawNameCursors();UploadOam();
    for(unsigned i=0;i<30;++i)WaitForFrame();FadeGameMusic(8);
    for(unsigned i=0;i<150;++i) {
        if(gBgOffsetsRaw[12]<16) { if(!delay) { ++gBgOffsetsRaw[12];UploadBlend();delay=6; }else --delay; }WaitForFrame();
    }
}
/*080026BC: acceptance guarantees first glyph is not blank before trimming.*/
static void DrawNameConfirmation(void)
{
    if(S[9]==1) {
        for(unsigned i=0;i<6;++i)CopyOam(10+i,ROM(0x08D30748)+i*8,0x400);UploadOam();W16(S+0x1E,0);
        unsigned i=7;while(U16(S+14+i*2)==0x4081 || !U16(S+14+i*2)) { W16(S+14+i*2,0);--i; }
        CopyText(gPlayerName,S+14,19);FadeOutNameEntry();
    }else for(unsigned i=0;i<5;++i)CopyOam(10+i,ROM(0x08D30720)+i*8,0x400);
}
static const uint8_t *AdvanceFrame(const uint8_t *table,unsigned timer,unsigned frame)
{
    if(S[timer]==table[S[frame]*8]) { S[timer]=0;++S[frame]; }else ++S[timer];
    if(!table[S[frame]*8])S[frame]=0;return table+S[frame]*8;
}
/*080027DC*/
static void DrawScrollArrows(void)
{
    const uint8_t *up=AdvanceFrame(ROM(0x08077E48),7,8);unsigned at=DrawFrame(21,up,0x400,U16(S+0x16A)!=0 && PAGE!=5);
    DrawFrame(at,ROM(0x08077E70)+S[8]*8,0x400,U16(S+0x16A)+154<(Length(PageText())>>1));
}
/*08002BE4*/
static void DrawFocusedLabel(void)
{
    for(unsigned i=25;i<34;++i)HideOam(i);if(FOCUS!=1)return;
    const uint8_t *table=PAGE<6?ROM(U32(ROM(0x08D30C28)+(PAGE+15)*4)):ROM(0x08077EF8);
    DrawFrame(25,AdvanceFrame(table,5,6),0,1);
}
/*08002ECC/03A6C/03A9C: fixed8.8 multiply with truncation toward zero.*/
static int16_t MultiplyFixed(int16_t a,int16_t b) { return (int16_t)((int32_t)a*b/256); }
static void DrawNameAffine(void)
{
    unsigned angle=U16(S+0x170);int16_t cosine=U16(ROM(0x0807F1A0)+(angle+64)*2),sine=U16(ROM(0x0807F1A0)+angle*2);
    int16_t invX=65536/(int16_t)U16(S+0x16C),invY=65536/(int16_t)U16(S+0x16E);
    gOamBuffer[0][3]=MultiplyFixed(cosine,invX);gOamBuffer[1][3]=MultiplyFixed(sine,invX);
    gOamBuffer[2][3]=MultiplyFixed(-sine,invY);gOamBuffer[3][3]=MultiplyFixed(cosine,invY);
    gOamBuffer[4][3]=204;gOamBuffer[5][3]=0;gOamBuffer[6][3]=0;gOamBuffer[7][3]=204;
}
static void DrawNameEntry(void)
{ DrawKeyboardLabels();DrawNameConfirmation();DrawScrollArrows();DrawNameCursors();DrawFocusedLabel();DrawNameAffine(); }
/*08003048, direct callback instruction recovery.*/
static void NameEntryDisplayCallback(void)
{
    for(unsigned i=0;i<128;++i) { HideOam(i);gOamBuffer[i][3]=0; }
    REG(0x0400000A)=0x1F09;REG(0x0400000C)=0x1E02;REG(0x04000208)=1;REG(0x04000200)=1;REG(0x04000004)=8;REG(0x04000000)=0x1600;
    gBgOffsetsRaw[8]=0x610;gBgOffsetsRaw[14]=0xC0A;UploadBlend();
    gBgOffsetsRaw[18]=gBgOffsetsRaw[10]=gBgOffsetsRaw[20]=gBgOffsetsRaw[2]=0;UploadBackgroundOffsets();
}
static int ConfirmName(void)
{
    if(U16(S+14)==0x4081) { PlayGameAudio(57);return 0; }
    PlayGameAudio(55);S[9]=1;DrawNameConfirmation();return 1;
}
/*0800181C*/
void RunNameEntry(void)
{
    ClearMenuGraphics();InitializeNameEntry();PlayGameAudio(46);
    BiosLz77UnpackWram(ROM(0x08070A84),gBackgroundBuffer);BiosCpuSet(ROM(0x080774D8),gPaletteBuffer,0x100);
    for(unsigned row=0;row<20;++row)BiosCpuSet(ROM(0x080776D8)+row*60,gBackgroundBuffer+0xF000+row*64,0x1E);
    BiosCpuSet(ROM(0x08077FA8),gBackgroundBuffer+0xF800,0x260);BiosCpuSet(ROM(0x08077B88),gPaletteBuffer+0x200,0x100);
    BiosLz77UnpackWram(ROM(0x08075388),gActorGraphicsBuffer);RenderNameText(gBackgroundBuffer+0x8020,S+14);LoadNameKeyboardPage();
    SetVBlankCallback(NameEntryDisplayCallback);WaitForFrame();DrawNameEntry();UploadOam();UploadMenuGraphics();UploadPalettes();
    for(;;) {
        if(gKeysPressed&4) { PlayGameAudio(54);FOCUS=FOCUS?0:1;X=Y=0;W16(S+0x16A,0); }
        if(gKeysPressed&8) { if(PAGE==5) { if(ConfirmName())return; }else { PlayGameAudio(54);PAGE=5; }W16(S+0x16A,0); }
        if((gKeysPressed&1) && PAGE==5 && ConfirmName())return;
        if(gKeysRepeated&256) { if(POSITION<8) { PlayGameAudio(54);++POSITION; } }
        else if((gKeysRepeated&512) && POSITION) { PlayGameAudio(54);--POSITION; }
        if(!FOCUS) { ScrollKeyboard();HandleKeyboardInput(); }
        else if(FOCUS==1) {
            if(gKeysPressed&1) { if(PAGE!=5)PlayGameAudio(55);X=Y=0;FOCUS=0; }
            if(gKeysPressed&2) {
                if(PAGE==5) { PlayGameAudio(56);PAGE=3;FOCUS=0;W16(S+0x16A,0);LoadNameKeyboardPage(); }
                else { PlayGameAudio(55);X=Y=0;FOCUS=0; }
            }
            if(gKeysRepeated&32) { FOCUS=0;X=10;PAGE=3; }
            else if(gKeysRepeated&16) { FOCUS=0;X=0;PAGE=3; }
        }
        if(PAGE==5)FOCUS=1;DrawNameEntry();
        if(S[4]==0) { W16(S+0x16C,U16(S+0x16C)+16);W16(S+0x16E,U16(S+0x16E)+16);if(U16(S+0x16C)==512)S[4]=1; }
        else if(S[4]==1) { W16(S+0x16C,U16(S+0x16C)-16);W16(S+0x16E,U16(S+0x16E)-16);if(U16(S+0x16C)==320)S[4]=0; }
        else S[4]=0;UploadOam();WaitForFrame();
    }
}
