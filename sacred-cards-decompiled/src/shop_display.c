/* AY7E shop transfer and popup text routines. Copies retain native sizes and
 * ordering, including the large1C00-byte transfer beginning at BG+F520. */
#include "gba_bios.h"
extern uint8_t gBackgroundBuffer[],gPaletteBuffer[];
extern uint16_t gOamBuffer[128][4],gBgOffsetsRaw[22];
extern void RenderBitmapString(void *,const uint8_t *,uint16_t),UploadMenuGraphics(void),UploadPalettes(void),UploadBackgroundOffsets(void);
#define ROM(a) ((const uint8_t *)(uintptr_t)(a))
#define REG(a) (*(volatile uint16_t *)(uintptr_t)(a))
static void CopyBg(unsigned offset,unsigned halfwords)
{ BiosCpuSet(gBackgroundBuffer+offset,(void *)(uintptr_t)(0x06000000+offset),halfwords); }
static void Blend(void)
{ REG(0x04000050)=gBgOffsetsRaw[8];REG(0x04000052)=gBgOffsetsRaw[14];REG(0x04000054)=gBgOffsetsRaw[12]; }
static void CopyShopPalette(void) { BiosCpuSet(gPaletteBuffer+0x160,(void *)0x05000160,0x20); }
/*0801E5C8/1E5E8*/
void SetShopListBlend(void) { gBgOffsetsRaw[8]=0xCC;gBgOffsetsRaw[14]=0;gBgOffsetsRaw[12]=4; }
void SetShopPopupBlend(void) { gBgOffsetsRaw[8]=0xDC;gBgOffsetsRaw[14]=0;gBgOffsetsRaw[12]=8; }
/*0801C67C/1C698/1C6B4/1C6D0*/
void DrawShopBuyLabels(void) { RenderBitmapString(gBackgroundBuffer+0xD000,ROM(0x080CB7E4),0x901); }
void DrawShopSellLabels(void) { RenderBitmapString(gBackgroundBuffer+0xD000,ROM(0x080CB89C),0x901); }
void DrawShopSortLabels(void) { RenderBitmapString(gBackgroundBuffer+0xD000,ROM(0x080CB954),0x901); }
void HideShopPopupCursor(void) { gOamBuffer[5][0]=0xA0;gOamBuffer[5][1]=0xF0;gOamBuffer[5][2]=0xC00;gOamBuffer[5][3]=0; }
/*0801EC5C/1ECB4 have intentionally different offset upload order.*/
void UploadShopRowThenOffsets(uint8_t row)
{ CopyBg(0x40+row*0x1C00,0xE00);CopyShopPalette();CopyBg(0xF520,0xE00);UploadBackgroundOffsets(); }
void UploadShopOffsetsThenRow(uint8_t row)
{ UploadBackgroundOffsets();CopyBg(0x40+row*0x1C00,0xE00);CopyShopPalette();CopyBg(0xF520,0xE00); }
/*0801EBB4/1E988*/
void UploadShopAllRows(void)
{
    UploadBackgroundOffsets();CopyBg(0x7040,0xE00);
    for(unsigned i=0;i<4;++i)CopyBg(0x40+i*0x1C00,0xE00);CopyShopPalette();CopyBg(0xF520,0xE00);
}
void UploadShopSortResults(void) { UploadShopAllRows();CopyBg(0xA800,0x400); }
/*0801EAF8/1EAC0/1EA58/1E908/1E94C*/
void UploadShopTransaction(uint8_t row) { CopyBg(0x40+row*0x1C00,0xE00);CopyShopPalette();CopyBg(0xF520,0xE00);CopyBg(0xA000,0x400); }
void UploadShopActionPopup(void) { CopyBg(0xD000,0x800);CopyBg(0xA000,0x400); }
void UploadShopSortPopup(void) { CopyBg(0xD000,0xC00);CopyBg(0xA800,0x400); }
void UploadShopSortChoice(void) { CopyBg(0xA800,0x400);CopyBg(0xF520,0xE00); }
void UploadShopSortClosed(void) { CopyBg(0xF520,0xE00); }
/*0801ED54/1ED94*/
void RestoreShopActionDisplay(void)
{ REG(0x04000008)=0x140C;UploadMenuGraphics();UploadPalettes();Blend();UploadBackgroundOffsets();REG(0x04000000)=0x9F00; }
void RestoreShopListDisplay(void)
{ UploadMenuGraphics();UploadPalettes();Blend();UploadBackgroundOffsets();REG(0x04000000)=0x9E00; }
/* VBlank callbacks0801EDC8/EA90/EB64/EB94/EA38/E968. Other reviewed
 * callbacks1E940/1EC50/1ED10/1ED88/1EDB8 call UploadOam directly. */
extern void UploadOam(void);
void InitializeShopDisplayCallback(void)
{
    REG(0x05000000)=0;REG(0x04000000)=0;REG(0x0400000A)=0x1F0D;REG(0x0400000C)=0x9282;
    REG(0x0400000E)=0x170F;REG(0x0400004A)=0x1C3F;UploadBackgroundOffsets();Blend();
}
void ShowShopSortCallback(void) { REG(0x04000008)=0x150C;REG(0x04000000)|=0x100;UploadOam();Blend(); }
void ShowShopActionCallback(void) { REG(0x04000008)=0x140C;REG(0x04000000)|=0x100;UploadOam();Blend(); }
void CloseShopPopupCallback(void) { REG(0x04000000)&=0xFEFF;UploadOam();Blend(); }

/*0801ED1C/1ED48: unused transfer/OAM-only callback variants.*/
void UploadShopPanelOnly(void) { CopyShopPalette();CopyBg(0xF520,0xE00); }
void UploadShopCursorOnly(void) { UploadOam(); }
