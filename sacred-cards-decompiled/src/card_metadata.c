/* AY7E shared card metadata and preview-stat loaders. Uses explicit 32-bit ROM
 * addresses in the raw metadata record, not host-sized C pointers. The native
 * callers provide card IDs 0..900. Not linked, execution-compared or matched. */
#include <stdint.h>
#include "native_state.h"
extern uint8_t gCardMetadataBytes[0x1E];         /* 02020B00 */
extern uint8_t gPreviewTerrain,gPreviewStage;   /* 0201CB30/31 */
extern uint32_t gDuelistLevel;                  /* 02020C40 */
extern const uint16_t gCardBaseAttack[901];      /* 080886E6 */
extern const uint16_t gCardBaseDefense[901];     /* 08087FDC */
extern const uint32_t gCardCosts[901];           /* 08088DF0 */
extern const uint8_t gCardAttributes[901];       /* 08089C04 */
extern const uint8_t gCardLevels[901];           /* 08089F89 */
extern const uint8_t gCardTypes[901];            /* 0808A30E */
extern const uint8_t gCardFrames[901];           /* 0808A693 */
extern const uint8_t gCardMetadata1A[901];       /* 0808AD9D */
extern const uint8_t gCardMetadata1B[901];       /* 0808AA18 */
extern const uint8_t gCardMetadata1C[901];       /* 0808B122 */
extern const uint8_t gMetadata1DBySpellIndex[];  /* 0808B4A7 */
extern const uint32_t gCardNameAddresses[901];   /* 08D310E0 */
extern const uint32_t gCardDescriptionAddresses[901]; /* 08E94E78 */
extern const uint8_t gTerrainModifiers[7][24];
extern uint16_t ApplyTerrainModifier(uint32_t,uint32_t);
extern uint16_t ApplyStatStage(uint32_t,uint32_t);
static uint16_t Read16(unsigned at) { return gCardMetadataBytes[at]|(uint16_t)gCardMetadataBytes[at+1]<<8; }
static void Write16(unsigned at,uint16_t value)
{
    gCardMetadataBytes[at]=(uint8_t)value;gCardMetadataBytes[at+1]=(uint8_t)(value>>8);
}
static void Write32(unsigned at,uint32_t value)
{
    for (unsigned i=0;i<4;++i) gCardMetadataBytes[at+i]=(uint8_t)(value>>(i*8));
}
/*08006B90 deliberately leaves the three text pointers untouched.*/
void ResetCardMetadata(void)
{
    Write16(0x10,0);Write16(0x12,65535);Write16(0x14,65535);Write32(0x0C,0);
    for(unsigned i=0x16;i<0x1E;++i)gCardMetadataBytes[i]=0;
    gPreviewTerrain=gPreviewStage=0;
}
/*080073F4 is an unused alternate name table, distinct from080073E4.*/
uint32_t GetAlternateCardNameAddress(uint16_t card)
{ const uint8_t *p=(const uint8_t *)(uintptr_t)(0x08D31EF4+card*4);return p[0]|(uint32_t)p[1]<<8|(uint32_t)p[2]<<16|(uint32_t)p[3]<<24; }
/* 080073E4 and 08014110. */
uint32_t GetCardNameAddress(uint32_t input) { return gCardNameAddresses[(uint16_t)input]; }
uint32_t GetDuelistLevel(void) { return gDuelistLevel; }
/* 08006BD0: both arguments truncate to a byte. */
void SetCardPreviewModifiers(uint8_t terrain,int32_t stage)
{
    gPreviewTerrain=terrain;gPreviewStage=(uint8_t)stage;
}
/* 08006BE4: 1D is indexed by 1A, unlike the per-card fields. Names are fetched
 * twice and the description is gated by Duelist Level versus card cost. */
void LoadCardMetadata(uint32_t input)
{
    uint16_t card=(uint16_t)input;
    Write16(0x12,gCardBaseAttack[card]);Write16(0x14,gCardBaseDefense[card]);
    Write32(0x0C,gCardCosts[card]);
    gCardMetadataBytes[0x17]=gCardAttributes[card];
    gCardMetadataBytes[0x18]=gCardLevels[card];
    gCardMetadataBytes[0x16]=gCardTypes[card];
    gCardMetadataBytes[0x19]=gCardFrames[card];
    gCardMetadataBytes[0x1A]=gCardMetadata1A[card];
    gCardMetadataBytes[0x1B]=gCardMetadata1B[card];
    gCardMetadataBytes[0x1C]=gCardMetadata1C[card];
    gCardMetadataBytes[0x1D]=gMetadata1DBySpellIndex[gCardMetadataBytes[0x1A]];
    Write16(0x10,card);
    Write32(0,GetCardNameAddress(card));Write32(4,GetCardNameAddress(card));
    Write32(8,GetDuelistLevel()<gCardCosts[card]?0x08D30F40u:gCardDescriptionAddresses[card]);
}
/* 08006CB4: terrain modifies both stats before stage modifies either stat. */
void LoadCardWithPreviewStats(uint16_t card)
{
    LoadCardMetadata(card);
    if (gCardMetadataBytes[0x1A]==2) {
        uint8_t modifier=gTerrainModifiers[gPreviewTerrain][gCardMetadataBytes[0x16]];
        Write16(0x12,ApplyTerrainModifier(Read16(0x12),modifier));
        Write16(0x14,ApplyTerrainModifier(Read16(0x14),modifier));
        Write16(0x12,ApplyStatStage(Read16(0x12),gPreviewStage));
        Write16(0x14,ApplyStatStage(Read16(0x14),gPreviewStage));
    }
}
