/* AY7E frame wait and key polling, native08003B94/03B98/03BC4/03C1C.
 * Interrupt setup/handler must provide gFrameInterruptFlags. Hardware only. */
#include <stdint.h>
extern volatile uint16_t gFrameInterruptFlags; /* 0201FCB0 */
extern void (*volatile gVBlankCallback)(void);  /* 0201CB24 */
extern uint16_t gKeysPressed,gKeysHeld,gKeysRepeated; /* 0201FCAC/A8/A4 */
extern uint8_t gKeyRepeatTimer; /* 0201FCB4 */
/* 08003B94 */ void IdleVBlankCallback(void) {}
/* 08003B58 */
void SetVBlankCallback(void (*callback)(void)) { gVBlankCallback=callback?callback:IdleVBlankCallback; }
/* 08003BF4 */
void ResetGameKeys(void)
{ gKeysHeld=0;gKeysPressed=0;gKeysRepeated=0;gKeyRepeatTimer=10; }
/* 08003C1C: retain the full16-bit complement, with no added 10-bit mask. */
void PollGameKeys(void) {
    uint16_t keys=(uint16_t)~*(volatile uint16_t *)0x04000130;
    gKeysPressed=keys&~gKeysHeld;
    if(gKeysHeld==keys) {
        gKeysRepeated=0;--gKeyRepeatTimer;
        if(!gKeyRepeatTimer) { gKeyRepeatTimer=3;gKeysRepeated=gKeysHeld; }
    }else { gKeyRepeatTimer=10;gKeysRepeated=keys; }
    gKeysHeld=keys;
}
void WaitForFrame(void) {
    gFrameInterruptFlags&=0xFFFE;
    while(!(gFrameInterruptFlags&1)) {}
    gVBlankCallback=IdleVBlankCallback;PollGameKeys();
}
