/* AY7E card-specific AI scores. Reviewed semantic recovery; not compiler
 * matched or linked into the ROM. Address suffixes identify native entries. */
#include "ai.h"
extern uint8_t *gAiScratch;
extern uint16_t gDuelLifePoints[2];
extern const uint8_t gOppositeSide[2]; /* 080AAED0 */
extern uint16_t *gOpponentHandCells[5]; /* 02023364 */
extern void SetCardPreviewModifiers(uint8_t,int32_t);
extern void LoadCardWithPreviewStats(uint16_t);
#define LOW 0x7EE0ACE9u
static uint32_t Score(void) {
    uint8_t *p=gAiScratch+0x14F0;return p[0]|(uint32_t)p[1]<<8|(uint32_t)p[2]<<16|(uint32_t)p[3]<<24;
}
static void SetScore(uint32_t n) { for (unsigned i=0;i<4;++i) gAiScratch[0x14F0+i]=(uint8_t)(n>>(8*i)); }
static uint16_t Meta16(unsigned n) { return gCardMetadataBytes[n]|(uint16_t)gCardMetadataBytes[n+1]<<8; }
static uint8_t Flags(uint16_t *c) { return ((uint8_t *)c)[4]; }
static void Preview(uint16_t *c) {
    unsigned s=((uint8_t *)c)[2];SetCardPreviewModifiers(gTerrain,s<128?(int32_t)s:(int32_t)s-256);LoadCardWithPreviewStats(*c);
}
static uint16_t Attack(uint16_t *c) { Preview(c);return Meta16(0x12); }
static unsigned Count(uint16_t *const *row,uint16_t id) { unsigned n=0;for(unsigned i=0;i<5;++i)n+=*row[i]==id;return n; }
static unsigned Empty(unsigned row) { return Count(gEffectBoardCells[row],0); }
/* 080271C4 / 0802723C: classification also runs on empty cells. */
static uint32_t StatSum(unsigned row,int visible) {
    uint32_t n=0;for(unsigned i=0;i<5;++i) {
        uint16_t *c=gEffectBoardCells[row][i];
        if(ClassifyDuelCard(*c)==1 && (!visible || (Flags(c)&16))) { Preview(c);n+=Meta16(0x12)+Meta16(0x14); }
    }return n;
}
/* 08026F34 / 08026FD8 / 080270A8. Count every match; metadata loads have side effects. */
static unsigned CountDefense(unsigned row) {
    unsigned n=0;for(unsigned i=0;i<5;++i) { uint16_t *c=gEffectBoardCells[row][i];n+=*c && (Flags(c)&2)!=0; }return n;
}
static unsigned CountType(unsigned row,unsigned type) {
    unsigned n=0;for(unsigned i=0;i<5;++i) { uint16_t *c=gEffectBoardCells[row][i];
        if(*c && (Flags(c)&16)) { LoadCardMetadata(*c);n+=gCardMetadataBytes[0x16]==type; }
    }return n;
}
static unsigned CountAttack(unsigned row,unsigned minimum) {
    unsigned n=0;for(unsigned i=0;i<5;++i) { uint16_t *c=gEffectBoardCells[row][i];
        if(*c && (Flags(c)&16)) n+=Attack(c)>=minimum;
    }return n;
}
static void Choice(int condition,uint32_t priority) { SetScore(condition?priority:LOW); }
static uint16_t OpponentLife(void) { return gDuelLifePoints[gOppositeSide[GetActingSide()]]; }
static void DamageScore(unsigned damage) { SetScore(OpponentLife()<=damage?0x7FFFFFFF:0x7FF99749); }
static void TypeScore(unsigned type,int initialize) { if(initialize)SetScore(LOW);Choice(CountType(1,type)!=0,0x7FF99742); }
static void HiddenRow(uint16_t *const *row,uint32_t priority) {
    for(unsigned i=0;i<5;++i) if(*row[i] && !(Flags(row[i])&16)) { SetScore(priority);return; }SetScore(LOW);
}
static void RitualScore(unsigned recipe,int equality_first,int equality_second) {
    SetCardPreviewModifiers(gTerrain,0);LoadCardWithPreviewStats(gRitualRecipes[recipe][1]);uint16_t result=Meta16(0x12);
    uint16_t a=Attack(AiCell(2));
    if(equality_first?a<=result:a<result) {
        SetScore(0xFFFEu-a);uint16_t b=Attack(AiCell(3));
        if(equality_second?b<=result:b<result) SetScore(Score()-b+0x7FF42E91u);else SetScore(LOW);
    }else SetScore(LOW);
}
void AiCardScore_0800AF3C(void) { SetScore(StatSum(2,0)); }
void AiCardScore_0800AF5C(void) { uint32_t n=StatSum(2,0);Choice(Score()<n,n+0x7FC8750Bu); }
void AiCardScore_0800B00C(void) { SetScore(gDuelLifePoints[GetActingSide()]); }
void AiCardScore_0800B034(void) { Choice(Score()<gDuelLifePoints[GetActingSide()],0x7FF99748); }
void AiCardScore_0800B0E4(void) { DamageScore(50); }
void AiCardScore_0800B140(void) { DamageScore(100); }
void AiCardScore_0800B19C(void) { DamageScore(200); }
void AiCardScore_0800B1F8(void) { DamageScore(500); }
void AiCardScore_0800B258(void) { DamageScore(1000); }
void AiCardScore_0800B2B8(void) { Choice(Empty(2)==5 && Empty(1)!=5,0x7FF99745); }
void AiCardScore_0800B32C(void) { Choice(Empty(1)!=5,0x7FF99744); }
void AiCardScore_0800B374(void) { Preview(AiCell(1));SetScore((uint32_t)Meta16(0x12)+Meta16(0x14)); }
void AiCardScore_0800B3D8(void) { Preview(AiCell(1));Choice(Score()<(uint32_t)Meta16(0x12)+Meta16(0x14),Score()+0x7F083246u); }
void AiCardScore_0800B6E4(void) { Choice(CountDefense(1)!=0,0x7FB3184A); }
void AiCardScore_0800B72C(void) { TypeScore(1,0); }
void AiCardScore_0800B774(void) { Choice(!(gDuelSideState[1][2]&3),0x7EEB5B5A); }
void AiCardScore_0800B7C0(void) { HiddenRow(gEffectBoardCells[1],0x7FFFFFF7); }
void AiCardScore_0800B820(void) { if(Empty(1)==5)SetScore(LOW);else SetScore(StatSum(1,1)); }
void AiCardScore_0800B868(void) { if(Score()!=LOW)Choice(StatSum(1,1)<Score(),0x7FF55178); }
void AiCardScore_0800B8B0(void) { uint16_t c=*AiCell(1);Choice(c==62 || c==875,0x7FF55173); }
void AiCardScore_0800BB9C(void) { LoadCardMetadata(*AiCell(0));RitualScore(gCardMetadataBytes[0x1D],0,0); }
void AiCardScore_0800BD30(void) {
    uint8_t slots[3];unsigned r;
    if(FindThreeMaterials(slots,gRitualRecipes[29]))r=29;
    else if(FindThreeMaterials(slots,gRitualRecipes[28]))r=28;
    else if(FindThreeMaterials(slots,gRitualRecipes[27]))r=27;
    else if(FindThreeMaterials(slots,gRitualRecipes[5]))r=5;
    else { SetScore(LOW);return; }
    SetCardPreviewModifiers(gTerrain,0);LoadCardWithPreviewStats(gRitualRecipes[r][1]);uint16_t result=Meta16(0x12);
    uint16_t a=Attack(gEffectBoardCells[2][slots[1]]);
    if(a<result) { SetScore(0xFFFEu-a);uint16_t b=Attack(gEffectBoardCells[2][slots[2]]);Choice(b<=result,Score()-b+0x7FF42E91u); }
    else SetScore(LOW);
}
void AiCardScore_0800BF30(void) { Choice(Empty(0)!=5,0x7FF9974A); }
void AiCardScore_0800BFF8(void) { Choice(CountAttack(1,1500)!=0,0x7FF99742); }
void AiCardScore_0800C164(void) {
    LoadCardMetadata(*AiCell(0));unsigned r=gCardMetadataBytes[0x1D];uint16_t a=*AiCell(2),b=*AiCell(3);
    if((a==gRitualRecipes[r][2] && b==gRitualRecipes[r][3]) || (a==gRitualRecipes[r][3] && b==gRitualRecipes[r][2]))RitualScore(r,1,1);
    else SetScore(LOW);
}
void AiCardScore_0800C374(void) { TypeScore(4,0); }
void AiCardScore_0800C3BC(void) {
    for(unsigned i=0;i<5;++i) { uint16_t *c=gEffectBoardCells[2][i];if(*c && (((uint8_t *)c)[2]&128)) { SetScore(0x7FF55174);return; } }SetScore(LOW);
}
void AiCardScore_0800C418(void) { TypeScore(3,1); }
void AiCardScore_0800C480(void) { uint16_t c=*AiCell(1);if(c==391 || c==82 || c==885)AiCardScore_0800B374();else SetScore(LOW); }
void AiCardScore_0800C524(void) { if(Score()!=LOW) { Preview(AiCell(1));Choice(Score()<(uint32_t)Meta16(0x12)+Meta16(0x14),0x7FF55173); } }
void AiCardScore_0800C5C0(void) { TypeScore(15,1); }
void AiCardScore_0800C610(void) { TypeScore(10,1); }
void AiCardScore_0800C660(void) { TypeScore(19,1); }
void AiCardScore_0800C6B0(void) { TypeScore(13,1); }
void AiCardScore_0800C700(void) { HiddenRow(gOpponentHandCells,0x7FFFFFF6); }
void AiCardScore_0800C760(void) { LoadCardMetadata(*AiCell(0));unsigned r=*AiCell(1)==gRitualRecipes[gCardMetadataBytes[0x1D]][0]?24:26;RitualScore(r,0,0); }
void AiCardScore_0800C8D0(void) { Choice(Empty(4)>=2,0x7EEB5B58); }
void AiCardScore_0800C918(void) {
    unsigned n=5-Count(gOpponentHandCells,0);if(!n)SetScore(LOW);
    /* Native comparison is damage < life, including its counterintuitive direction. */
    else SetScore(n*200<OpponentLife()?0x7FFFFFFF:0x7FFFFFF5);
}
void AiCardScore_0800C9A8(void) { TypeScore(2,1); }
void AiCardScore_0800C9F8(void) { TypeScore(8,1); }
void AiCardScore_0800CA48(void) { Choice(Count(gEffectBoardCells[2],58)!=0 && Empty(2)!=0,0x7FF32E8B); }
void AiCardScore_0800CABC(void) { Choice(Empty(2)!=0 && Empty(1)!=5,0x7FF9974B); }
void AiCardScore_0800CB80(void) { Choice(Empty(2)!=0 && Empty(1)!=5,0x7FF9974B); }
void AiCardScore_0800CBF4(void) { Choice((gDuelSideState[1][0] || gDuelSideState[1][1]) && Empty(2)!=0,0x7FB31849); }
void AiCardScore_0800CCB4(void) { Choice(Empty(1)!=5,0x7FF77462); }
void AiCardScore_0800CD34(void) { Choice(gDuelSideState[0][0] || gDuelSideState[0][1],0x7EEB5B59); }
void AiCardScore_0800CD7C(void) { Choice(Empty(2)==5 && (Empty(1)!=5 || Empty(0)!=5),0x7FFFFFFD); }
void AiCardScore_0800CDFC(void) { Choice(Empty(2)==5 && (Empty(1)!=5 || Empty(0)!=5),0x7FFFFFFE); }
void AiCardScore_0800CE7C(void) {
    for(unsigned i=0;i<5;++i) { uint16_t *c=gEffectBoardCells[1][i];if(*c && !(Flags(c)&1) && Attack(c)>=1500) { SetScore(0x7EED7E3D);return; } }SetScore(LOW);
}
void AiCardScore_0800CF18(void) {
    for(unsigned i=0;i<5;++i) { uint16_t *c=gEffectBoardCells[2][i];if(*c && (Flags(c)&16) && !(Flags(c)&1)) {
        LoadCardMetadata(*c);if(gCardMetadataBytes[0x1B]) { SetScore(0x7FFFFFF9);return; }
    } }SetScore(LOW);
}
/* Monster scoring helpers: native 08026F7C/080269DC, 08027040,
 * 0802712C, 08026E5C, 08026EEC and the strongest-card selectors. */
extern uint32_t IsEffectImmune(uint16_t);
extern uint32_t CountEmptyOrImmuneCells(uint16_t *const *);
static unsigned CountMetadata(unsigned row,unsigned offset,unsigned value,int nonempty,int visible) {
    unsigned n=0;for(unsigned i=0;i<5;++i) { uint16_t *c=gEffectBoardCells[row][i];
        if((!nonempty || *c) && (!visible || (Flags(c)&16))) { LoadCardMetadata(*c);n+=gCardMetadataBytes[offset]==value; }
    }return n;
}
static unsigned Unlocked(unsigned row) {
    unsigned n=0;for(unsigned i=0;i<5;++i) { uint16_t *c=gEffectBoardCells[row][i];n+=*c && !(Flags(c)&1); }return n;
}
static unsigned Visible(unsigned row) {
    unsigned n=0;for(unsigned i=0;i<5;++i) { uint16_t *c=gEffectBoardCells[row][i];n+=*c && (Flags(c)&16)!=0; }return n;
}
static unsigned Strongest(unsigned row,unsigned filter,unsigned type) {
    unsigned slot=0;uint16_t best=0;
    for(unsigned i=0;i<5;++i) { uint16_t *c=gEffectBoardCells[row][i];if(!*c)continue;
        if(filter==1 && IsEffectImmune(*c)!=0)continue;
        if(filter==2 && !(Flags(c)&16))continue;
        uint16_t attack=Attack(c);if(filter==3 && gCardMetadataBytes[0x16]!=type)continue;
        if(attack>=best) { slot=i;best=attack; }
    }return slot;
}
static uint16_t Grave(unsigned side) { uint8_t *p=gDuelSideState[side];return p[0]|(uint16_t)p[1]<<8; }
static int DragonInGrave(void) { return Grave(1)==865 || Grave(0)==865 || Grave(1)==35 || Grave(0)==35; }
static void ScoreStatIncrease(uint32_t priority) { if(Score()!=LOW) { uint32_t n=StatSum(2,0);Choice(Score()<n,priority); } }
static void ScoreTerrain(unsigned terrain) { if(gTerrain==terrain)SetScore(LOW);else SetScore(StatSum(2,0)); }
static void ScoreCardBoost(uint16_t card) { if(!Count(gEffectBoardCells[2],card))SetScore(LOW);else SetScore(StatSum(2,0)); }
static void ScoreHeal(unsigned amount,uint32_t priority) { Choice(9999-(int32_t)gDuelLifePoints[GetActingSide()] >= (int32_t)amount,priority); }
static void ScoreAttackDamage(uint32_t priority) {
    uint16_t attack=Attack(AiCell(0));SetScore(attack<OpponentLife()?priority:0x7FFFFFFF);
}
static void ScoreOpposingTarget(uint32_t priority) { Choice(CountEmptyOrImmuneCells(gEffectBoardCells[1])!=5,priority); }
static void ScoreAttributeChange(unsigned required,unsigned excluded) {
    unsigned n=0;for(unsigned i=0;i<5;++i) {
        LoadCardMetadata(*gEffectBoardCells[2][i]);
        if(gCardMetadataBytes[0x17]==excluded) { SetScore(LOW);return; }
        n+=gCardMetadataBytes[0x17]==required;
    }Choice(n!=0,0x7EF2D575);
}
void AiCardScore_0800EDDC(void) { Choice(Empty(0)!=5,0x7FFFFFF8); }
void AiCardScore_0800EE44(void) { ScoreHeal(1000,0x7FFFFFEF); }
void AiCardScore_0800EEA0(void) { Choice(Empty(1)!=5,0x7FFBBA2B); }
void AiCardScore_0800EEE8(void) { Choice(Empty(1)!=5,0x7FFDDD0B); }
void AiCardScore_0800EF30(void) { Choice(Empty(4)!=0,0x7FB31848); }
void AiCardScore_0800EF78(void) { ScoreCardBoost(386); }
void AiCardScore_0800EFC4(void) { ScoreStatIncrease(0x7EFD83E4); }
void AiCardScore_0800F008(void) { ScoreCardBoost(386); }
void AiCardScore_0800F054(void) { ScoreStatIncrease(0x7EF2D582); }
void AiCardScore_0800F098(void) { Choice(Count(gEffectBoardCells[2],4) || Count(gEffectBoardCells[2],35) || Count(gEffectBoardCells[2],865),0x7EF2D571); }
void AiCardScore_0800F134(void) {
    /* Native BNE at 0800F152 explicitly skips OCCUPIED cells. */
    if(gTerrain==6) { unsigned n=0;for(unsigned i=0;i<5;++i) { uint16_t *c=gEffectBoardCells[2][i];n+=!*c && (Flags(c)&16)!=0; }
        if(!n) { SetScore(LOW);return; }
    }SetScore(StatSum(2,0));
}
void AiCardScore_0800F1B4(void) { ScoreStatIncrease(0x7FDDD1CB); }
void AiCardScore_0800F1F8(void) { if(Count(gEffectBoardCells[2],1) || Count(gEffectBoardCells[2],887))SetScore(StatSum(2,0));else SetScore(LOW); }
void AiCardScore_0800F258(void) { ScoreStatIncrease(0x7EF2D583); }
void AiCardScore_0800F29C(void) { ScoreTerrain(2); }
void AiCardScore_0800F2E4(void) { ScoreStatIncrease(0x7FB3184B); }
void AiCardScore_0800F328(void) { Choice(CountType(1,11)!=0,0x7FF7745E); }
void AiCardScore_0800F370(void) { ScoreTerrain(0); }
void AiCardScore_0800F3B8(void) { ScoreStatIncrease(0x7FB3184B); }
void AiCardScore_0800F3FC(void) { Choice(CountMetadata(1,0x17,5,1,1)!=0,0x7FF7745D); }
void AiCardScore_0800F444(void) { ScoreCardBoost(375); }
void AiCardScore_0800F490(void) { ScoreStatIncrease(0x7EF2D581); }
void AiCardScore_0800F4D4(void) {
    unsigned a=Count(gEffectBoardCells[2],96),b=Count(gEffectBoardCells[2],97),c=Count(gEffectBoardCells[2],98);
    if(a || b || c)SetScore(StatSum(2,0));else SetScore(LOW);
}
void AiCardScore_0800F548(void) { ScoreStatIncrease(0x7EF2D580); }
void AiCardScore_0800F58C(void) { Choice(Empty(1)!=5,0x7FF55177); }
void AiCardScore_0800F5D4(void) {
    unsigned n=0;for(unsigned i=0;i<5;++i) { uint16_t *c=gEffectBoardCells[2][i];
        if(i!=gMonsterInput.column && *c && *c!=89 && !(Flags(c)&1))++n;
    }
    if(!n) { SetScore(LOW);return; }
    /* The damage sum includes locked cells and does not exclude the input column. */
    uint32_t damage=0;for(unsigned i=0;i<5;++i) { uint16_t *c=gEffectBoardCells[2][i];if(*c && *c!=89)damage+=Attack(c); }
    SetScore(damage<OpponentLife()?0x7FFFFFF4:0x7FFFFFFF);
}
void AiCardScore_0800F6E4(void) { Choice(Empty(4)!=0,0x7FB31847); }
void AiCardScore_0800F72C(void) { ScoreTerrain(3); }
void AiCardScore_0800F774(void) { ScoreStatIncrease(0x7FB3184B); }
void AiCardScore_0800F7B8(void) { Choice(CountType(1,1)!=0,0x7FF7745C); }
void AiCardScore_0800F800(void) { Choice(Empty(0)!=0,0x7EF2D570); }
void AiCardScore_0800F848(void) { Choice(Empty(1)!=5,0x7FF5517C); }
void AiCardScore_0800F890(void) { Choice(Empty(1)!=5,0x7EED7E3B); }
void AiCardScore_0800F8D8(void) { Choice(Empty(1)!=5,0x7EEB5B5B); }
void AiCardScore_0800F920(void) { Choice(DragonInGrave(),0x7EF2D57F); }
void AiCardScore_0800F98C(void) { Choice(CountMetadata(2,0x16,20,1,0)!=0,0x7EF2D57D); }
void AiCardScore_0800F9D4(void) { Choice(Count(gEffectBoardCells[2],161)!=0,0x7EF2D57B); }
void AiCardScore_0800FA20(void) { Choice(Count(gEffectBoardCells[2],160)!=0,0x7EF2D57A); }
void AiCardScore_0800FA6C(void) { Choice(Empty(1)!=5,0x7EED7E3E); }
void AiCardScore_0800FAB4(void) { ScoreHeal(500,0x7FFFFFEE); }
void AiCardScore_0800FB10(void) { SetScore(OpponentLife()<=50?0x7FFFFFFF:0x7EEB5B57); }
void AiCardScore_0800FB6C(void) { ScoreTerrain(5); }
void AiCardScore_0800FBB4(void) { ScoreStatIncrease(0x7FB3184B); }
void AiCardScore_0800FBF8(void) {
    unsigned n=0;for(unsigned i=0;i<5;++i) { uint16_t *c=gEffectBoardCells[2][i];if(*c)n+=Attack(c)<=500; }Choice(n!=0,0x7EF2D579);
}
void AiCardScore_0800FC9C(void) { Choice(Count(gOpponentHandCells,0)!=5,0x7EED7E3F); }
void AiCardScore_0800FCFC(void) { Choice(Empty(2)!=0,0x7FF32E8E); }
void AiCardScore_0800FD44(void) { Choice(Count(gEffectBoardCells[2],554)!=0,0x7EF2D578); }
void AiCardScore_0800FD94(void) { Choice(Count(gEffectBoardCells[2],12)!=0,0x7EF2D577); }
void AiCardScore_0800FDE0(void) { ScoreTerrain(1); }
void AiCardScore_0800FE28(void) { ScoreStatIncrease(0x7FB3184B); }
void AiCardScore_0800FE6C(void) { Choice(Count(gEffectBoardCells[2],366)!=0,0x7EF2D577); }
void AiCardScore_0800FEB8(void) { Choice(Empty(2)!=0,0x7FF32E91); }
void AiCardScore_0800FF00(void) { Choice(Empty(2)!=5 && gDuelLifePoints[GetActingSide()]>1000,0x7EF2D576); }
void AiCardScore_0800FF7C(void) { Choice(Empty(2)>=4 && Empty(1)!=5,0x7FF5517B); }
void AiCardScore_0800FFF0(void) { Choice(Empty(1)!=5 && Unlocked(2)==1,0x7EED7E3C); }
void AiCardScore_08010060(void) { Choice(Empty(2)!=0,0x7FF32E90); }
void AiCardScore_080100A8(void) { ScoreAttributeChange(1,2); }
void AiCardScore_08010138(void) { Choice(Empty(1)!=5,0x7EED7E3B); }
void AiCardScore_08010180(void) { ScoreAttributeChange(2,1); }
void AiCardScore_08010210(void) { ScoreAttackDamage(0x7FFFFFF2); }
void AiCardScore_080102B0(void) { ScoreAttackDamage(0x7FFFFFF1); }
void AiCardScore_08010350(void) { unsigned a=CountMetadata(2,0x16,10,1,0),b=CountType(1,10);Choice(a+b!=0,0x7EF2D573); }
void AiCardScore_080103AC(void) { SetScore(OpponentLife()<=4000?0x7FFFFFFF:0x7FF99747); }
void AiCardScore_0801040C(void) { Choice(CountMetadata(4,0x1A,2,0,0)!=0,0x7F083244); }
void AiCardScore_08010454(void) {
    uint8_t other=gOppositeSide[GetActingSide()],self=GetActingSide();
    if(gDuelLifePoints[other]<gDuelLifePoints[self])SetScore(0x7FFFFFFF);
    else { other=gOppositeSide[GetActingSide()];self=GetActingSide();Choice(gDuelLifePoints[other]==gDuelLifePoints[self],0x7FFFFFEC); }
}
void AiCardScore_080105D0(void) { ScoreCardBoost(386); }
void AiCardScore_0801061C(void) { ScoreStatIncrease(0x7EF2D584); }
void AiCardScore_08010660(void) { Choice(DragonInGrave(),0x7EF2D57E); }
void AiCardScore_080106CC(void) { Choice(Count(gEffectBoardCells[2],757) && Count(gEffectBoardCells[2],850),0x7FF32E92); }
void AiCardScore_08010748(void) { Choice(Count(gEffectBoardCells[2],738) && Count(gEffectBoardCells[2],850),0x7FF32E92); }
void AiCardScore_080107C4(void) { Choice(Count(gEffectBoardCells[2],738) && Count(gEffectBoardCells[2],757),0x7FF32E92); }
void AiCardScore_08010840(void) { Choice(Empty(2)>=2,0x7FF32E8C); }
void AiCardScore_0801088C(void) { Choice(Empty(1)!=5,0x7FF55176); }
void AiCardScore_080108D4(void) { Choice(Empty(2)!=0 && CountEmptyOrImmuneCells(gEffectBoardCells[1])!=5,0x7FFFFFEB); }
void AiCardScore_08010948(void) { ScoreOpposingTarget(0x7FF5517A); }
void AiCardScore_080109C8(void) { ScoreOpposingTarget(0x7FF99746); }
void AiCardScore_08010A10(void) { ScoreOpposingTarget(0x7FF99743); }
void AiCardScore_08010A58(void) { Choice(Empty(0)!=5,0x7FFFFFF8); }
void AiCardScore_08010AC0(void) { Choice(CountType(1,1)!=0,0x7EF2D572); }
void AiCardScore_08010B08(void) { ScoreOpposingTarget(0x7FF7745F); }
void AiCardScore_08010B50(void) {
    if(CountEmptyOrImmuneCells(gEffectBoardCells[1])==5) { SetScore(LOW);return; }
    if(Visible(1)) { unsigned slot=Strongest(1,2,0);uint16_t attack=Attack(gEffectBoardCells[1][slot]);
        if(OpponentLife()<=attack) { SetScore(0x7FFFFFFF);return; }
    }SetScore(0x7FFFFFF0);
}
void AiCardScore_08010C18(void) {
    if(CountEmptyOrImmuneCells(gEffectBoardCells[1])==5) { SetScore(LOW);return; }
    uint16_t *c=gEffectBoardCells[1][Strongest(1,1,0)];
    if(Flags(c)&16) { uint16_t opposing=Attack(c),own=Attack(AiCell(0));if(opposing<=own) { SetScore(LOW);return; } }
    SetScore(0x7FF55179);
}
void AiCardScore_08010CF4(void) { ScoreHeal(500,0x7FFFFFED); }
void AiCardScore_08010D50(void) {
    if(!CountMetadata(4,0x16,10,1,0)) { SetScore(LOW);return; }
    uint16_t target=Attack(gEffectBoardCells[4][Strongest(4,3,10)]),own=Attack(AiCell(0));Choice(own<target,0x7FB31846);
}
void AiCardScore_08010E38(void) { Choice(Empty(1)!=5,0x7FF55175); }
void AiCardScore_08010E80(void) { Choice(Empty(2)!=0,0x7FF32E8D); }
void AiCardScore_08010EC8(void) { Choice(CountMetadata(2,0x16,1,1,0)!=0,0x7EF2D57C); }
void AiCardScore_08010F34(void) { Choice(Empty(2)!=0,0x7FF32E8F); }
void AiCardScore_08010F7C(void) {
    if(CountEmptyOrImmuneCells(gEffectBoardCells[1])==5)SetScore(LOW);else SetScore(OpponentLife()<=500?0x7FFFFFFF:0x7FF77460);
}
void AiCardScore_08011004(void) { ScoreAttackDamage(0x7FFFFFF3); }
