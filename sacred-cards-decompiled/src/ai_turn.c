/* AY7E opponent candidate-search orchestration. Native entries 08009A48..09C88,
 * 0801145C..1156C and dispatchers08009200/09224/1174C. This recovers selection,
 * state snapshots and execution order. The five callback tables are recovered
 * in ai_actions.c, ai_validation.c and ai_scoring.c. Not execution-compared or compiler-matched.
 */
#include "ai.h"
#define AI_CANDIDATES 616
struct AiScore { uint16_t candidate,unused;uint32_t value; };
extern const struct AiAction gAiActionDefinitions[AI_CANDIDATES]; /* 080AAED4 */
extern uint16_t gAiCandidateId;                                  /* 02020C28 */
extern struct AiAction gAiAction;                                /* 02020C30 */
extern uint8_t gSuppressEffectPresentation;                      /* 02020C38 */
extern uint8_t *gAiScratch; /* ROM pointer08D41B28 ->02018800, shared with save */
extern uint8_t gDuelStateBytes[252];                              /* 02023160 */
extern uint8_t gDuelDeckRecords[2][84];                           /* 02023390 */
extern uint16_t gDuelLifePoints[2];                              /* 0202347C */
extern uint8_t gDuelAuxiliaryFlags[2];                            /* 02020D88 */
extern uint8_t gDuelResolutionFlag;                              /* 02023158 */
extern void (*const gAiSimulate[25])(void);                       /* 08D349EC */
extern void (*const gAiExecute[25])(void);                        /* 08D34A50 */
extern void (*const gAiScoreBefore[25])(void);                    /* 08D34AB8 */
extern void (*const gAiScoreAfter[25])(void);                     /* 08D34B1C */
extern uint8_t (*const gAiValidate[25])(void);                     /* 08D356C0 */
extern void ClearBattleDisplay(void);
extern void BeforeAiActionPresentation(void);
extern void RestoreDuelDisplay(void);
extern void PresentBattleAnimation(void);
extern void RestoreDuelAfterBattle(void);
extern void AfterAiActionAudio(void);
extern void CheckDestinyBoardWin(void);
extern void CheckExodiaWin(void);
extern uint8_t DuelHasEnded(void);
extern void WaitForFrame(void);
static uint16_t Read16(const uint8_t *p) { return p[0]|(uint16_t)p[1]<<8; }
static void Write16(uint8_t *p,uint16_t v) { p[0]=(uint8_t)v;p[1]=(uint8_t)(v>>8); }
static uint32_t Read32(const uint8_t *p)
{
    return p[0]|(uint32_t)p[1]<<8|(uint32_t)p[2]<<16|(uint32_t)p[3]<<24;
}
static void Write32(uint8_t *p,uint32_t v)
{
    for (unsigned i=0;i<4;++i) p[i]=(uint8_t)(v>>(8*i));
}
/* 08009A48 / 08009AB8 copy252 state bytes, two deck-position bytes,
 * two16-bit life totals, and two auxiliary bytes. Other scratch data is retained.
 */
void SnapshotAiState(void)
{
    for (unsigned i=0;i<252;++i) gAiScratch[i]=gDuelStateBytes[i];
    for (unsigned side=0;side<2;++side) {
        gAiScratch[0x14C+side*84]=gDuelDeckRecords[side][80];
        Write16(gAiScratch+0x1A4+side*2,gDuelLifePoints[side]);
        gAiScratch[0x1A8+side]=gDuelAuxiliaryFlags[side];
    }
}
void RestoreAiState(void)
{
    for (unsigned i=0;i<252;++i) gDuelStateBytes[i]=gAiScratch[i];
    for (unsigned side=0;side<2;++side) {
        gDuelDeckRecords[side][80]=gAiScratch[0x14C+side*84];
        gDuelLifePoints[side]=Read16(gAiScratch+0x1A4+side*2);
        gDuelAuxiliaryFlags[side]=gAiScratch[0x1A8+side];
    }
}
/* 08009BD0: only ID/score are cleared; two padding bytes per record stay intact. */
void ClearAiScores(void)
{
    Write16(gAiScratch+0x14EC,0);
    for (unsigned i=0;i<AI_CANDIDATES;++i) {
        Write16(gAiScratch+0x1AC+i*8,0);Write32(gAiScratch+0x1B0+i*8,0);
    }
}
/* 0801145C / 08011498 */
void SelectAiCandidate(uint16_t id)
{
    gAiCandidateId=id;gAiAction=gAiActionDefinitions[id];
}
void ResetAiCandidate(void)
{
    gAiCandidateId=0;gAiAction.kind=0;
    for (unsigned i=0;i<6;++i) gAiAction.cells[i]=0;
}
/* 08009B30 */
void BeginAiScore(void)
{
    Write32(gAiScratch+0x14F0,0);
    uint16_t count=Read16(gAiScratch+0x14EC);
    Write16(gAiScratch+0x1AC+count*8,gAiCandidateId);
    gAiScoreBefore[gAiAction.kind]();
}
/* 08009B80 */
void FinishAiScore(void)
{
    gAiScoreAfter[gAiAction.kind]();
    uint16_t count=Read16(gAiScratch+0x14EC);
    Write32(gAiScratch+0x1B0+count*8,Read32(gAiScratch+0x14F0));
    Write16(gAiScratch+0x14EC,(uint16_t)(count+1));
}
/* 08009C1C: unsigned strictly-greater comparison, so first equal score wins.
 * No positive score returns sentinel0, including an empty result list.
 */
uint16_t BestAiCandidate(void)
{
    uint16_t best=0,count=Read16(gAiScratch+0x14EC);uint32_t score=0;
    for (unsigned i=0;i<count;++i) {
        uint32_t value=Read32(gAiScratch+0x1B0+i*8);
        if (value>score) { score=value;best=Read16(gAiScratch+0x1AC+i*8); }
    }
    return best;
}
/* 080114BC */
void RunOpponentTurn(void)
{
    for (;;) {
        ResetAiCandidate();ClearAiScores();gSuppressEffectPresentation=1;
        for (uint16_t candidate=0;candidate<AI_CANDIDATES;++candidate) {
            SelectAiCandidate(candidate);
            if (gAiValidate[gAiAction.kind]()==1) {
                SnapshotAiState();BeginAiScore();
                ClearBattleDisplay();gAiSimulate[gAiAction.kind]();
                FinishAiScore();RestoreAiState();
            }
        }
        gSuppressEffectPresentation=0;
        uint16_t best=BestAiCandidate();
        if (!best) break;
        SelectAiCandidate(best);BeforeAiActionPresentation();
        ClearBattleDisplay();gAiExecute[gAiAction.kind]();
        if (!gDuelResolutionFlag) RestoreDuelDisplay();
        else { PresentBattleAnimation();RestoreDuelAfterBattle(); }
        AfterAiActionAudio();CheckDestinyBoardWin();CheckExodiaWin();
        if (DuelHasEnded()==1) break;
    }
    for (unsigned frame=0;frame<30;++frame) WaitForFrame();
}

extern uint32_t gOpponentIdentifier; /* 02020D5C */
struct AiAttackTag { uint16_t opponent,card,tag,padding; };
extern const struct AiAttackTag gAiAttackTags[]; /* 080AC214 */
/* 08011700, called through080116F4. Native scans with a byte-sized index. */
uint8_t FindAiAttackTag(uint16_t record[3]) {
    uint8_t i=0;
    while(gAiAttackTags[i].opponent!=record[0] || gAiAttackTags[i].card!=record[1]) {
        ++i;if(!gAiAttackTags[i].opponent) { record[2]=0;return 0; }
    }
    record[2]=gAiAttackTags[i].tag;return 1;
}
/* 08011570: attack-tag result remains unused; monster effect plays song64. */
void BeforeAiActionPresentation(void) {
    switch(gAiAction.kind) {
    case 7:case 8:case 9:case 10:case 12:case 13: {
        uint16_t record[3]={(uint16_t)gOpponentIdentifier,*AiCell(0),0};FindAiAttackTag(record);break;
    }
    case 23:PlayGameAudio(64);break;
    }
}
/* 0801164C */
void AfterAiActionAudio(void) {
    switch(gAiAction.kind) {
    case 1:PlayGameAudio(62);break;
    case 2:case 3:case 4:case 11:case 14:case 15:case 18:case 21:PlayGameAudio(58);break;
    case 5:case 6:PlayGameAudio(60);break;
    }
}
