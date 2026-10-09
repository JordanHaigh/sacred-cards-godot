/* AY7E duel-record counters1679C..16924, including unused updates and
 *the completion grade consumed by the dormant record/communication menus. */
#include <stdint.h>
extern uint16_t gDuelRecordHeader[2],gDuelRecords[25][2]; /*02020CB0/CB4*/
/*167D8/167FC/16820/1683C:1000 is the saturated value (999 increments).*/
void IncrementDuelOpponentWins(uint8_t opponent) { if(gDuelRecords[opponent][0]<=999)++gDuelRecords[opponent][0]; }
void IncrementDuelOpponentLosses(uint8_t opponent) { if(gDuelRecords[opponent][1]<=999)++gDuelRecords[opponent][1]; }
void IncrementDuelTotalWins(void) { if(gDuelRecordHeader[0]<=999)++gDuelRecordHeader[0]; }
void IncrementDuelTotalLosses(void) { if(gDuelRecordHeader[1]<=999)++gDuelRecordHeader[1]; }
/*0801679C: native R1 is unused; R2 selects wins only when exactly1.*/
void RecordOpponentDuel(uint8_t opponent,uint8_t unused,uint8_t won)
{ (void)unused;if(opponent<=24) { if(won==1)IncrementDuelOpponentWins(opponent);else IncrementDuelOpponentLosses(opponent); } }
/*080167C0*/
void RecordTotalDuel(uint8_t won) { if(won==1)IncrementDuelTotalWins();else IncrementDuelTotalLosses(); }
/*08016858. The three byte-list views intentionally start one byte apart;
 *they are not three pointer-table entries. Empty lists qualify immediately.*/
uint8_t GetDuelRecordGrade(void)
{
    for(unsigned group=0;group<3;++group) {
        const uint8_t *p=(const uint8_t *)(uintptr_t)(0x080B6A9C+group);
        while(*p!=255)if(gDuelRecords[*p++][0]<=4)return group;
    }return 3;
}
/*08016900/16924*/
void InitializeDuelRecords(void)
{ gDuelRecordHeader[0]=gDuelRecordHeader[1]=0;for(unsigned i=0;i<25;++i)gDuelRecords[i][0]=gDuelRecords[i][1]=0; }
void DuelRecordsNoop(void) {}
