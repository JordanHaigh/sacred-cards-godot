#ifndef AY7E_LINK_TRANSPORT_H
#define AY7E_LINK_TRANSPORT_H
#include <stdint.h>
/* Native 02022830. Pointer fields stay 32-bit ROM ABI values. Roles 0 and
 * 1..3 are master and slaves; 4 means undetermined. Bytes 6..7 are padding. */
struct LinkState {
    uint8_t role,peer1,peer2,phase,subphase,error,padding[2];
    uint32_t send,receive;
    uint16_t remaining,extra;
    uint32_t field14,serialInterrupts,timerInterrupts,missedReplies;
};
extern volatile struct LinkState gLinkState;
extern volatile uint32_t gLinkReceivedPacket,gLinkSendPacket; /*02022048/4C*/
extern uint8_t gLinkPrimaryPayload[2000],gLinkSecondaryPayload[2000]; /*02022050/22860*/
extern volatile uint16_t gLinkOutgoing,gLinkIncoming[4]; /*02023030/38*/
void InitializeLinkState(void),InitializeLinkPayloads(void),FillLinkSecondaryPayload(void),FillLinkPrimaryPayload(void);
void EnableSerialInterrupt(void),DisableSerialInterrupt(void),ClearSerialInterruptFlag(void),SignalSerialInterrupt(void);
uint8_t WaitSerialInterrupt(void),PollSerialInterrupt(void);
void ServiceMultiplayerInterrupt(void),ReadMultiplayerInput(void),SetLinkOutgoing(uint16_t),SendMultiplayerWord(void);
void ClearLinkOutgoing(void),ClearLinkIncoming(void),ClearLinkBuffers(void);
void InitializeNormalSerial(void),SelectNormalSerialClock(void),SendNormalWord(void),ReadNormalWord(void);
void SelectExternalSerialClock(void),SetSerialOutputBit(void),ClearSerialOutputBit(void);
uint8_t ReadSerialInputBit(void);
void ServiceNormalSerialInterrupt(void),ReplyToNormalProbe(void),AcknowledgeNormalSerial(void),ReplyToNormalTransfer(void);
uint8_t ProbeNormalMaster(void),ProbeNormalSlave(void),DetectNormalMaster(void),WaitLinkReady(void);
void DetectLinkRole(void),InitializeMultiplayerSerial(void);
void SetLinkBaud0(void),SetLinkBaud1(void),SetLinkBaud2(void),SetLinkBaud3(void);
void EnableLinkTimerInterrupt(void),DisableLinkTimerInterrupt(void),ServiceLinkTimerInterrupt(void);
void ClearLinkTimerFlag(void),SignalLinkTimer(void),InitializeLinkTimer(void),StartLinkTimer(void),StopLinkTimer(void),WaitLinkTimer(void);
void LinkTimerSendByte(void),LinkTimerRequestByte(void);
void LinkReceiveTick(void),LinkSendTick(void),LinkHandshakeTick(void),LinkFinishTick(void);
uint8_t LinkMasterSend(void),LinkMasterReceive(void),LinkSlaveSend(void),LinkSlaveReceive(void);
uint8_t LinkSendPrimaryDirection(void),LinkSendReverseDirection(void);
uint8_t LinkHandshake(void),LinkMasterHandshake(void),LinkSlaveHandshake(void);
uint8_t LinkFinishHandshake(void),LinkMasterFinish(void),LinkSlaveFinish(void);
static inline uint8_t LinkReadSendByte(void)
{ uint32_t p=gLinkState.send;uint8_t value=*(const uint8_t *)(uintptr_t)p;gLinkState.send=p+1;return value; }
static inline void LinkWriteReceiveByte(uint8_t value)
{ uint32_t p=gLinkState.receive;*(uint8_t *)(uintptr_t)p=value;gLinkState.receive=p+1; }
#endif
