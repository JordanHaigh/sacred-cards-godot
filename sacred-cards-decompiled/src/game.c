/* AY7E Thumb game entry08016928. Reset CPU mode/stack setup lives in
 *startup.s; physical placement and a linked ROM are not required for reuse. */
#include <stdint.h>
#include "save_storage.h"
extern uint8_t gBootState[8]; /*02020D20/24*/
extern uint8_t gLanguage;
extern void InitializeGameHardware(void),ResetGameKeys(void),m4aSoundInit(void),SetSoundMode(uint32_t),InitializeSramAccess(void),InitializeRandom(void),RunIntro(void),RunTitleScreen(void),RunOverworld(void),WaitForFrame(void);
#define REG(a) (*(volatile uint16_t *)(uintptr_t)(a))
void RunGame(void)
{
    gBootState[4]=0;gBootState[0]=0;InitializeGameHardware();ResetGameKeys();
    REG(0x04000208)=0;REG(0x04000200)=0x2001;REG(0x04000004)=8;REG(0x04000208)=1;REG(0x04000000)=0x80;
    m4aSoundInit();SetSoundMode(0x97FC00);InitializeSramAccess();
    struct SaveStorage storage={(volatile uint8_t *)0x0E000000,(uint8_t *)0x02018800,(volatile uint16_t *)0x04000204};RepairInterruptedSave(&storage);
    InitializeRandom();gLanguage=0;RunIntro();RunTitleScreen();RunOverworld();
}
/*08035AE4 uses a signed count and performs no waits for nonpositive counts.*/
void WaitFrames(int32_t frames) { while(frames-->0)WaitForFrame(); }
