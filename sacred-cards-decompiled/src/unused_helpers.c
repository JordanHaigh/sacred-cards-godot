/* AY7E auxiliary helpers found by the expanded code-boundary pass. Each
 * address below identifies the original entry; quirks are retained. */
#include "gba_bios.h"
#include "card_effects.h"
extern uint8_t gBackgroundBuffer[],gActorGraphicsBuffer[],gPaletteBuffer[],gCardCollection[901],gCardMetadataBytes[0x1E];
extern uint16_t gBgOffsetsRaw[22];
extern uint8_t gBattleAnimationScratch[0x4314];
extern uint32_t gUnusedDeckCost; /*02020C50*/
extern uint16_t gUnusedDeckPreset[40]; /*020233E4*/
extern const uint16_t gUntracedDeckPreset[40];
extern void RenderBitmapString(void *,const uint8_t *,uint16_t),RenderBitmapGlyph(void *,uint16_t,uint16_t),UndoByteDeltas(uint8_t *,uint32_t),UndoTiledRowDeltas(uint8_t *,uint8_t,uint8_t);
extern void LoadCardMetadata(uint32_t),ApplyCardStatModifiers(uint16_t *,uint16_t *,uint8_t,uint8_t,uint8_t,uint8_t);
extern uint32_t PlayerDeckCost(void),GetDeckCapacity(void);
extern uint8_t PlayerDeckCount(void),NextRandomByte(void);
#define ROM(a) ((const uint8_t *)(uintptr_t)(a))
static uint16_t U16(const uint8_t *p) { return p[0]|(uint16_t)p[1]<<8; }
static void W16(uint8_t *p,uint16_t v) { p[0]=v;p[1]=v>>8; }
/*080035DC: OR tile bits, rather than replacing the existing tile.*/
void OrStatusTile(uint8_t x,uint8_t y,uint16_t value)
{ uint16_t *p=(uint16_t *)(gBackgroundBuffer+0xF800)+y*32+x;*p|=(uint32_t)value+0x77; }
/*080043F8*/
void FillCollectionWithFifty(void) { gCardCollection[0]=0;for(unsigned i=1;i<901;++i)gCardCollection[i]=50; }
/*08006D2C: an input record is card halfword then signed stage byte.*/
void LoadCardWithRecordStats(const uint8_t *record)
{
    LoadCardMetadata(U16(record));uint16_t attack=U16(gCardMetadataBytes+0x12),defense=U16(gCardMetadataBytes+0x14);
    ApplyCardStatModifiers(&attack,&defense,gCardMetadataBytes[0x1A],gCardMetadataBytes[0x16],gTerrain,record[2]);W16(gCardMetadataBytes+0x12,attack);W16(gCardMetadataBytes+0x14,defense);
}
/*08006F54: card ID clamps900; FFFF leaves the existing tiles intact.*/
void DrawLegacyCardNumber(void)
{
    unsigned card=U16(gCardMetadataBytes+0x10);if(card==65535)return;if(card>900)card=900;
    unsigned digits[3]={card/100,(card/10)%10,card%10};static const unsigned offsets[3]={0x4020,0x4040,0x40A0};
    for(unsigned i=0;i<3;++i) { if(i<2 && card<(i?10:100))RenderBitmapGlyph(gBackgroundBuffer+offsets[i],0x4081,0x100);else { uint16_t code=0x824F+digits[i];RenderBitmapGlyph(gBackgroundBuffer+offsets[i],(code<<8)|(code>>8),0x901); } }
}
/*08007E90/07EFC*/
static void DrawLegacyCardBanner(uint32_t map,uint32_t text)
{ for(unsigned row=0;row<20;++row)BiosCpuSet(ROM(map)+row*60,gBackgroundBuffer+0x7800+row*64,0x0400000F);uint16_t zero=0;BiosCpuSet(&zero,gBackgroundBuffer+0x4000,0x01000010);RenderBitmapString(gBackgroundBuffer+0x4020,ROM(text),0x900); }
void DrawLegacyCardBannerA(void) { DrawLegacyCardBanner(0x0808250C,0x080AA8D0); }
void DrawLegacyCardBannerB(void) { DrawLegacyCardBanner(0x080829BC,0x080AA9C8); }
/*08008B94/08BB4*/
uint16_t LegacyDeckCostPalette(void) { return PlayerDeckCost()>GetDeckCapacity()?0x4000:0x5000; }
uint16_t LegacyDeckCountPalette(void) { return PlayerDeckCount()<40?0x4000:0x5000; }
/*08009130/09148*/
void UnpackLzByteDeltas(const void *source,uint8_t *destination,uint32_t count)
{ BiosLz77UnpackWram(source,destination);UndoByteDeltas(destination,count); }
void UnpackLzCardArt(const void *source,uint8_t *destination)
{ BiosLz77UnpackWram(source,destination);UndoTiledRowDeltas(destination,10,10); }
/*080116E8*/
void PlayUnusedDuelSound(void) { PlayGameAudio(61); }
/*080131EC: the two RNG draws jitter only the selected background.*/
void JitterBattleBackground(uint8_t side)
{
    gBgOffsetsRaw[2]=4;gBgOffsetsRaw[20]=0x1FC;gBgOffsetsRaw[6]=4;gBgOffsetsRaw[0]=4;
    uint8_t radius=ROM(0x08D35948)[gBattleAnimationScratch[1]];unsigned y=side?6:2,x=side?0:20;
    gBgOffsetsRaw[y]+=radius-NextRandomByte()%(radius*2+1);radius=ROM(0x08D35948)[gBattleAnimationScratch[1]];gBgOffsetsRaw[x]+=radius-NextRandomByte()%(radius*2+1);
}
/*08014174/1452C. The latter's reversed comparison is native, including
 * unsigned wrap; replacing it by a conventional cap would change behavior.*/
void InitializeUnusedDeckPreset(void) { for(unsigned i=0;i<40;++i)gUnusedDeckPreset[i]=gUntracedDeckPreset[i]; }
void AddUnusedDeckCost(uint32_t amount) { if(amount<99999u-gUnusedDeckCost)gUnusedDeckCost=99999;else gUnusedDeckCost+=amount; }
/*08019978*/
void LoadUnusedIntroPalette(void) { BiosCpuSet(ROM(0x08D3992C),gPaletteBuffer,0x100); }

/*080042CC/042E0/042F4/04308: single palette-row copy helpers.*/
void CopyAttackDigitPalette(void *destination) { BiosCpuSet(ROM(0x080845DC),destination,0x10); }
void CopyDefenseDigitPalette(void *destination) { BiosCpuSet(ROM(0x080845FC),destination,0x10); }
void CopyCostDigitPalette(void *destination) { BiosCpuSet(ROM(0x0808461C),destination,0x10); }
void CopyListTextPalette(void *destination) { BiosCpuSet(ROM(0x08084F9C),destination,0x10); }
/*08004348/043C0/047A0*/
void RemoveCollectionCard(uint16_t card,uint8_t count)
{ gCardCollection[card]=gCardCollection[card]<count?0:gCardCollection[card]-count; }
uint8_t GetCollectionCardCount(uint16_t card) { return gCardCollection[card]; }
/*08009100: unlike09118, the caller supplies a byte-delta count.*/
void DecompressHuffmanByteDeltas(const void *source,uint8_t *destination,uint32_t count)
{ BiosHuffmanUnpack(source,destination);UndoByteDeltas(destination,count); }
/*08007380/073A8 and2319C/231BC: metadata labels through literal tables.*/
static const uint8_t *LegacyLabel(uint32_t table,uint8_t index)
{ const uint8_t *p=ROM(table+index*4);return ROM(p[0]|(uint32_t)p[1]<<8|(uint32_t)p[2]<<16|(uint32_t)p[3]<<24); }
const uint8_t *GetCardTypeLabel(uint8_t type) { return LegacyLabel(0x08D4BC3C,type); }
/*080231AC, unused attribute label accessor.*/
const uint8_t *GetCardAttributeLabel(uint8_t attribute) { return LegacyLabel(0x08D4BC9C,attribute); }
/*080231BC*/
uint16_t GetDuelBitMask(uint8_t bit) { return U16(ROM(0x08D4BCFC)+bit*2); }
void DrawLegacyCardTypeLabel(void) { RenderBitmapString(gBackgroundBuffer+0x4880,GetCardTypeLabel(gCardMetadataBytes[0x16]),0x901); }
void DrawLegacyCardAttributeLabel(void) { RenderBitmapString(gBackgroundBuffer+0x4C00,LegacyLabel(0x08D419E0,gCardMetadataBytes[0x17]),0x901); }
/*0802B2D8: called by InitializeDuel. Source is the opponent record's
 * two starting-LP halfwords at02020D70/72, not the money field at02020D30.*/
extern uint16_t gDuelLifePoints[2],gInitialDuelLifePoints[2];
void CopyInitialDuelLifePoints(void) { gDuelLifePoints[0]=gInitialDuelLifePoints[0];gDuelLifePoints[1]=gInitialDuelLifePoints[1]; }

/*08017EFC: checked before the terminator, and writes zero on no match.*/
uint8_t LookupOpponentSpecialCard(uint16_t record[2])
{
    uint8_t i=0;
    do { if(U16(ROM(0x080B81B4)+i*4)==record[0]) { record[1]=U16(ROM(0x080B81B6)+i*4);return 1; }++i; }
    while(U16(ROM(0x080B81B4)+i*4));record[1]=0;return 0;
}
/*08034A48: unlike CardY, this accessor does not subtract viewport offset.*/
int16_t GetDuelRowBaseY(uint8_t column,uint8_t row)
{ (void)column;return (int16_t)U16(ROM(0x08D51130)+row*2); }
/*080047CC*/
extern uint8_t gCollectionMenu[12],gPlayerDeckState[10],gCardSortState[12];
uint8_t GetCollectionSortMethod(void) { return gCollectionMenu[2]; }
/*08008EB4: transparent zeros leave the destination byte intact.*/
void Overlay64NonzeroBytes(const uint8_t *source,uint8_t *destination)
{ for(unsigned i=0;i<64;++i)if(source[i])destination[i]=source[i]; }
/*080140C0*/
extern uint32_t gDeckCapacity;
void SubtractNativeDeckCapacity(uint32_t amount)
{ gDeckCapacity=amount>gDeckCapacity?0:gDeckCapacity-amount; }
/*080144A8 returns the original amount when it fits, excess when it does not.*/
uint8_t AddPlayerDeckCount(uint8_t amount)
{ unsigned total=gPlayerDeckState[8]+amount;if(total>40) { amount=total-40;total=40; }gPlayerDeckState[8]=total;return amount; }
/*08016C30 writes only OAM0's first word and attr2; attr3 is untouched.*/
extern uint16_t gOamBuffer[128][4];
extern uint8_t gUnusedStatusSelection; /*02020D24*/
void DrawUnusedStatusCursor(void)
{ uint8_t y=ROM(0x08D35F62)[gUnusedStatusSelection*2];gOamBuffer[0][0]=y;gOamBuffer[0][1]=0;gOamBuffer[0][2]=0x800; }
/*0801A634*/
const uint8_t *GetDuelRecordLabel(uint8_t id) { return LegacyLabel(0x08D41A14,id); }
/*08021E3C: padding byte11 is not initialized.*/
void ResetCardSortState(void) { for(unsigned i=0;i<11;++i)gCardSortState[i]=0; }
/*080272F0*/
void ShowUnusedDuelScreen(void) { *(volatile uint16_t *)0x04000000=0x140; }
/*080276A4/080276B0*/
extern uint8_t gDuelCursorState[6],gPlayerTurnDone;
void ResetDuelMenuChoice(void) { gDuelCursorState[5]=0; }
void AdvanceDuelMenuChoice(void) { gDuelCursorState[5]=ROM(0x08D4C678)[gDuelCursorState[5]]; }
/*080282D8*/
void ResetPlayerTurnDone(void) { gPlayerTurnDone=0; }
/*0802B2F4/0802B31C update physical LP only, without the battle display.*/
void AddAbsoluteDuelLifePoints(uint8_t side,uint16_t amount)
{ unsigned total=gDuelLifePoints[side]+amount;gDuelLifePoints[side]=total>9999?9999:total; }
void SubtractAbsoluteDuelLifePoints(uint8_t side,uint16_t amount)
{ gDuelLifePoints[side]=amount>=gDuelLifePoints[side]?0:gDuelLifePoints[side]-amount; }
/*0803419C/080343F0: dormant banks, separate from the50-byte event bank.*/
extern uint8_t gUnusedOverworldFlags[8],gUnusedSceneFlags[113]; /*02023743/02023750*/
void ClearUnusedOverworldFlags(void) { for(unsigned i=0;i<8;++i)gUnusedOverworldFlags[i]=0; }
void ClearUnusedSceneFlags(void) { for(unsigned i=0;i<113;++i)gUnusedSceneFlags[i]=0; }
/* Empty/constant entries retain their behavior in shared functions. The
 * complete address mapping is recorded in semantic_function_families.json.*/
void RomUnusedNoop(void) {}
uint8_t RomUnusedReturnZero(void) { return 0; }
uint8_t RomUnusedReturnOne(void) { return 1; }
/*080257F4*/
extern uint8_t gDuelViewMode;
void ResetDuelViewMode(void) { gDuelViewMode=4; }
