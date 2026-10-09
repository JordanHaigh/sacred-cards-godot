/* AY7E pre-duel popup maps, cursors and display callbacks08007878..08007D94. */
#include "gba_bios.h"
extern uint8_t gBackgroundBuffer[],gCollectionMenu[12];
extern uint16_t gOamBuffer[128][4];
extern void UploadOam(void),UploadPalettes(void),RenderBitmapString(void *,const uint8_t *,uint16_t);
extern uint16_t ReadBackgroundTile(uint8_t,uint8_t,uint16_t);
extern void WriteBackgroundTile(uint8_t,uint8_t,uint16_t,uint16_t);
#define ROM(a) ((const uint8_t *)(uintptr_t)(a))
#define REG(a) (*(volatile uint16_t *)(uintptr_t)(a))
static void Tile(unsigned x,unsigned y,uint16_t tile) { WriteBackgroundTile(x,y,0x7800,tile); }
static void LoadPopupMap(uint32_t source)
{
    for(unsigned row=0;row<20;++row)BiosCpuSet(ROM(source)+row*60,gBackgroundBuffer+0x7800+row*64,0x0400000F);
    uint16_t zero=0;BiosCpuSet(&zero,gBackgroundBuffer+0x4000,0x01000010);
}
static void DrawWagerCursor(uint32_t yTable,uint32_t xTable)
{
    unsigned i=gCollectionMenu[4];for(unsigned o=6;o<8;++o) {
        gOamBuffer[o][0]=ROM(yTable)[i]|(o==7?0x800:0);gOamBuffer[o][1]=ROM(xTable)[i]|0x4000;
        gOamBuffer[o][2]=o==6?0xC120:0x120;gOamBuffer[o][3]=0;
    }
}
void DrawWagerActionCursor(void) { DrawWagerCursor(0x08D34936,0x08D34939); }
void DrawSpecialWagerCursor(void) { DrawWagerCursor(0x08D34940,0x08D34942); }
void DrawNoWagerCursor(void) { DrawWagerCursor(0x08D34948,0x08D3494A); }
/*08007968*/
void DrawCardListActionPopup(uint32_t map,uint32_t text)
{
    LoadPopupMap(map);uint16_t pal=ReadBackgroundTile(9,9,0x7800)&0xFF00;
    for(unsigned i=0;i<20;++i) {
        unsigned n=ROM(0x08D30D70)[i];Tile(i+9,11,(n+0x15)|pal);Tile(i+9,12,(n+0x17)|pal);Tile(i+9,13,(n+0x3D)|pal);Tile(i+9,14,(n+0x3F)|pal);
    }
    RenderBitmapString(gBackgroundBuffer+0x4020,ROM(text),0x900);
}
void DrawWagerActionPopup(void) { DrawCardListActionPopup(0x08082E6C,0x080AA49C); }
/*08007A4C*/
void DrawSpecialWagerPopup(void)
{ LoadPopupMap(0x0808331C);RenderBitmapString(gBackgroundBuffer+0x4020,ROM(0x080AA5CC),0x900); }
/*08007BFC*/
void DrawNoWagerPopup(void)
{
    LoadPopupMap(0x0808331C);uint16_t blank=ReadBackgroundTile(0,3,0x7800),pal=ReadBackgroundTile(3,7,0x7800)&0xFF00;
    for(unsigned i=0;i<28;++i) {
        unsigned n=ROM(0x08D30D70)[i];Tile(i+1,7,(n+1)|pal);Tile(i+1,8,(n+3)|pal);Tile(i+1,9,(n+0x39)|pal);Tile(i+1,10,(n+0x3B)|pal);
    }
    for(unsigned i=0;i<4;++i) {
        unsigned n=ROM(0x08D30D70)[i];Tile(i+12,12,(n+0x71)|pal);Tile(i+12,13,(n+0x73)|pal);Tile(i+12,14,(n+0x79)|pal);Tile(i+12,15,(n+0x7B)|pal);
    }
    for(unsigned x=16;x<18;++x)for(unsigned y=12;y<16;++y)Tile(x,y,blank);
    RenderBitmapString(gBackgroundBuffer+0x4020,ROM(0x080AA744),0x900);
}
/*08007930/07BC4*/
void WagerPopupDisplayCallback(void)
{
    UploadPalettes();UploadOam();BiosCpuSet(gBackgroundBuffer+0x4000,(void *)0x06004000,0x2000);
    REG(0x04000000)=0xBF00;REG(0x04000052)=6;REG(0x04000054)=10;REG(0x04000050)|=8;
}

/*080049B8*/
void DrawCardListSortPopup(uint32_t map,uint32_t text)
{
    LoadPopupMap(map);uint16_t blank=ReadBackgroundTile(0,2,0x7800),pal=ReadBackgroundTile(2,2,0x7800)&0xFF00;
    for(unsigned i=0;i<6;++i)for(unsigned row=0;row<5;++row) {
        unsigned n=ROM(0x08D30D70)[i]+0x1D+row*32;Tile(4+i,6+row*2,n|pal);Tile(4+i,7+row*2,(n+2)|pal);
    }
    for(unsigned x=10;x<14;++x)for(unsigned y=6;y<16;++y)Tile(x,y,blank);
    for(unsigned i=0;i<10;++i)for(unsigned row=0;row<4;++row) {
        unsigned n=ROM(0x08D30D70)[i]+0x29+row*32;Tile(16+i,6+row*2,n|pal);Tile(16+i,7+row*2,(n+2)|pal);
    }
    for(unsigned i=0;i<12;++i) { unsigned n=ROM(0x08D30D70)[i];Tile(4+i,17,(n+0xA9)|pal);Tile(4+i,18,(n+0xAB)|pal); }
    RenderBitmapString(gBackgroundBuffer+0x4020,ROM(text),0x900);
}
void DrawCollectionSortPopup(void) { DrawCardListSortPopup(0x080829BC,0x08086C00); }
/*08008DD8/08E48*/
void DrawCollectionSortCursor(void) { DrawWagerCursor(0x08D34974,0x08D3497E); }
void CollectionSortPopupCallback(void)
{ UploadOam();REG(0x04000000)=0xBF00;REG(0x04000052)=6;REG(0x04000054)=10;REG(0x04000050)|=8; }
