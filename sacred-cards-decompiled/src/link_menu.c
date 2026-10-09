/* AY7E dormant communication menu08022984..22EDC. The middle submenu
 * handlers are empty in the original ROM; they remain no-ops here. The last
 * choice enters the native long-running link stress diagnostic. */
#include "gba_bios.h"
#include "link_transport.h"
extern uint8_t gLinkMenuChoice; /*02023118*/
extern uint16_t gLinkMenuAscending[50],gLinkMenuDescending[50]; /*02023050/B4*/
extern uint8_t gBackgroundBuffer[],gActorGraphicsBuffer[],gPaletteBuffer[];
extern uint16_t gOamBuffer[128][4],gKeysPressed;
extern void PollMenuRepeat(void),SetVBlankCallback(void (*)(void)),WaitForFrame(void),RunCollectionEditor(void);
extern void RenderBitmapString(void *,const uint8_t *,uint16_t);
extern uint8_t RunLinkStressDiagnostic(void);
#define ROM(a) ((const uint8_t *)(uintptr_t)(a))
#define REG(a) (*(volatile uint16_t *)(uintptr_t)(a))
static void Frame(void (*fn)(void)) { SetVBlankCallback(fn);WaitForFrame(); }
static void W16(uint8_t *p,uint16_t v) { p[0]=v;p[1]=v>>8; }
/*08022A54/22B34, these equivalent readers ignore held-repeat output.*/
uint16_t ReadLinkMenuInput(void)
{ PollMenuRepeat();uint16_t key=0;for(unsigned bit=1;bit<1024;bit<<=1)if(gKeysPressed&bit)key=bit;return key; }
uint16_t ReadLinkSubmenuInput(void) { return ReadLinkMenuInput(); }
/*08022A50/22B1C/20/24/28/2C/30/22CDC*/
void LinkMenuCancel(void) {}
void LinkSubmenuUp(void) {}
void LinkSubmenuDown(void) {}
void LinkSubmenuLeft(void) {}
void LinkSubmenuRight(void) {}
void LinkSubmenuConfirm(void) {}
void LinkSubmenuCancel(void) {}
void DrawLinkSubmenu(void) {}
/*08022B74/8C/BA4*/
void PreviousLinkMenuChoice(void) { if(gLinkMenuChoice)--gLinkMenuChoice; }
void NextLinkMenuChoice(void) { if(gLinkMenuChoice<2)++gLinkMenuChoice; }
void InitializeLinkMenuState(void)
{ for(unsigned i=0;i<50;++i) { gLinkMenuAscending[i]=i;gLinkMenuDescending[i]=~i; }gLinkMenuChoice=0; }
/*08022DB8/22DD4/22E9C*/
void UploadLinkMenuCursor(void) { BiosCpuSet(gOamBuffer,(void *)0x07000000,0x04000002); }
void ShowLinkMenu(void)
{
    REG(0x04000050)=REG(0x04000052)=REG(0x04000054)=0;REG(0x0400000E)=0x1F03;REG(0x0400001E)=REG(0x0400001C)=0;REG(0x04000000)=0x1800;
    BiosCpuSet(gBackgroundBuffer,(void *)0x06000000,0x04001000);BiosCpuSet(gBackgroundBuffer+0xF800,(void *)0x0600F800,0x04000200);
    BiosCpuSet(gPaletteBuffer,(void *)0x05000000,0x04000020);BiosCpuSet(gActorGraphicsBuffer,(void *)0x06010000,0x04000008);
    UploadLinkMenuCursor();BiosCpuSet(gPaletteBuffer+0x200,(void *)0x05000200,0x04000008);
}
void UploadClearedLinkMenu(void)
{
    BiosCpuSet(gBackgroundBuffer,(void *)0x06000000,0x04004000);BiosCpuSet(gActorGraphicsBuffer,(void *)0x06010000,0x04002000);
    BiosCpuSet(gPaletteBuffer,(void *)0x05000000,0x04000100);BiosCpuSet(gOamBuffer,(void *)0x07000000,0x04000100);
}
/*08022CE0*/
void ClearLinkMenu(void)
{
    uint32_t zero=0;BiosCpuSet(&zero,gBackgroundBuffer,0x05004000);BiosCpuSet(&zero,gActorGraphicsBuffer,0x05002000);BiosCpuSet(&zero,gPaletteBuffer,0x05000100);
    for(unsigned i=0;i<128;++i) { gOamBuffer[i][0]=0xA0;gOamBuffer[i][1]=0xF0;gOamBuffer[i][2]=0xC00;gOamBuffer[i][3]=0; }Frame(UploadClearedLinkMenu);
}
/*08022D48*/
void DrawLinkMenuTileRun(uint8_t x,uint8_t y,uint16_t first,uint16_t count)
{ uint16_t *map=(uint16_t *)(gBackgroundBuffer+0xF800)+(unsigned)y*32+x;for(unsigned i=0;i<count;++i)map[i]=first+i; }
/*08022C00*/
void DrawLinkMenu(void)
{
    RenderBitmapString(gBackgroundBuffer+0x20,ROM(0x080D3788),0);DrawLinkMenuTileRun(2,1,1,10);
    RenderBitmapString(gBackgroundBuffer+0x160,ROM(0x080D37D0),0);DrawLinkMenuTileRun(2,2,4,20);
    RenderBitmapString(gBackgroundBuffer+0x3E0,ROM(0x080D3850),0);DrawLinkMenuTileRun(2,3,10,20);
    W16(gPaletteBuffer,0);W16(gPaletteBuffer+2,0x7FFF);W16(gPaletteBuffer+4,0);
    RenderBitmapString(gActorGraphicsBuffer,ROM(0x080D38D0),0);W16(gPaletteBuffer+0x200,0);W16(gPaletteBuffer+0x202,0x7FFF);W16(gPaletteBuffer+0x204,0);
    gOamBuffer[0][0]=(gLinkMenuChoice+1)*8;gOamBuffer[0][1]=gOamBuffer[0][2]=0;Frame(ShowLinkMenu);
}
/*08022BD4/229F0/22A00*/
void DrawLinkMenuCursor(void) { gOamBuffer[0][0]=(gLinkMenuChoice+1)*8;Frame(UploadLinkMenuCursor); }
void LinkMenuUp(void) { PreviousLinkMenuChoice();DrawLinkMenuCursor(); }
void LinkMenuDown(void) { NextLinkMenuChoice();DrawLinkMenuCursor(); }
/*08022A94*/
void RunLinkSubmenu(void)
{
    ClearLinkMenu();DrawLinkSubmenu();for(;;) { uint16_t key=ReadLinkSubmenuInput();switch(key) { case 16:LinkSubmenuRight();break;case 32:LinkSubmenuLeft();break;case 64:LinkSubmenuUp();break;case 128:LinkSubmenuDown();break;case 1:LinkSubmenuConfirm();break;case 2:LinkSubmenuCancel();break; }WaitForFrame();if(key==2)return; }
}
/*08022D8C*/
void StartLinkMenuDiagnostic(void)
{ InitializeMultiplayerSerial();InitializeLinkState();gLinkState.send=(uintptr_t)gLinkSecondaryPayload;gLinkState.receive=(uintptr_t)gLinkPrimaryPayload;gLinkState.remaining=100;RunLinkStressDiagnostic(); }
/*08022A10/22984*/
void ConfirmLinkMenuChoice(void)
{
    switch(gLinkMenuChoice) { case 0:RunCollectionEditor();break;case 1:RunLinkSubmenu();break;case 2:StartLinkMenuDiagnostic();return;default:return; }ClearLinkMenu();DrawLinkMenu();
}
void RunLinkMenu(void)
{
    InitializeLinkMenuState();ClearLinkMenu();DrawLinkMenu();for(;;) { uint16_t key=ReadLinkMenuInput();switch(key) { case 1:ConfirmLinkMenuChoice();break;case 2:LinkMenuCancel();break;case 64:LinkMenuUp();break;case 128:LinkMenuDown();break; }WaitForFrame();if(key==2) { ClearLinkMenu();return; } }
}
