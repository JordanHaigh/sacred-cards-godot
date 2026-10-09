/* AY7E dormant serial/multiplayer transport, 0801F02C..1F8D4 and
 * 08022014..22180. Native register order, polling bounds and timer masks
 * are retained. Waiting for Timer3 has no timeout in the original. */
#include "link_transport.h"
#define REG16(a) (*(volatile uint16_t *)(uintptr_t)(a))
#define REG32(a) (*(volatile uint32_t *)(uintptr_t)(a))
extern volatile uint16_t gFrameInterruptFlags;
extern void WaitForFrame(void);
typedef char LinkStateSize[(sizeof(struct LinkState)==0x24)?1:-1];
/*0801F360/388/398/3B4*/
void InitializeLinkState(void)
{
    gLinkState.role=gLinkState.peer1=gLinkState.peer2=4;
    gLinkState.phase=gLinkState.subphase=gLinkState.error=0;
    gLinkState.send=gLinkState.receive=0;gLinkState.remaining=gLinkState.extra=0;
    gLinkState.field14=gLinkState.serialInterrupts=gLinkState.timerInterrupts=gLinkState.missedReplies=0;
}
void FillLinkSecondaryPayload(void) { for(unsigned i=0;i<2000;++i)gLinkSecondaryPayload[i]=i; }
void FillLinkPrimaryPayload(void) { for(unsigned i=0;i<2000;++i)gLinkPrimaryPayload[i]=17; }
void InitializeLinkPayloads(void) { FillLinkSecondaryPayload();FillLinkPrimaryPayload(); }
/*0801F3EC/40C/430/444/45C/48C*/
void EnableSerialInterrupt(void) { REG16(0x04000208)=0;REG16(0x04000200)|=0x80;REG16(0x04000208)=1; }
void DisableSerialInterrupt(void) { REG16(0x04000208)=0;REG16(0x04000200)&=0xFF7F;REG16(0x04000208)=1; }
void ClearSerialInterruptFlag(void) { gFrameInterruptFlags&=0xFF7F; }
void SignalSerialInterrupt(void) { REG16(0x04000202)=0x80;gFrameInterruptFlags|=0x80; }
uint8_t PollSerialInterrupt(void) { for(unsigned count=10000;count;--count)if(gFrameInterruptFlags&0x80)return 1;return 0; }
uint8_t WaitSerialInterrupt(void) { ClearSerialInterruptFlag();return PollSerialInterrupt(); }
/*0801F4BC/888/894/8AC/8BC/8D4*/
void ServiceMultiplayerInterrupt(void) { ReadMultiplayerInput();++gLinkState.serialInterrupts;SignalSerialInterrupt(); }
void SetLinkOutgoing(uint16_t value) { gLinkOutgoing=value; }
void ReadMultiplayerInput(void)
{
    ((volatile uint32_t *)gLinkIncoming)[1]=REG32(0x04000124);
    ((volatile uint32_t *)gLinkIncoming)[0]=REG32(0x04000120);
}
void ClearLinkOutgoing(void) { gLinkOutgoing=0; }
void ClearLinkIncoming(void) { for(unsigned i=0;i<4;++i)gLinkIncoming[i]=0; }
void ClearLinkBuffers(void) { ClearLinkOutgoing();ClearLinkIncoming(); }
/*0801F0A0/0C0/0D4/10C*/
void SendNormalWord(void) { REG32(0x04000120)=gLinkSendPacket;REG16(0x04000128)|=0x80; }
void ReadNormalWord(void) { gLinkReceivedPacket=REG32(0x04000120); }
void InitializeNormalSerial(void)
{ REG16(0x04000134)=0;REG16(0x04000128)=0x2000;REG16(0x04000134)=0;REG16(0x04000128)=0x1000;REG16(0x04000128)|=0x4000; }
void SelectNormalSerialClock(void) { REG16(0x04000128)&=0xFFFE;REG16(0x04000128)|=1; }
/*0801F02C/064/1EFEC: these probes return zero on success.*/
uint8_t ProbeNormalMaster(void)
{ gLinkSendPacket=0x01123456;SelectNormalSerialClock();SendNormalWord();WaitForFrame();ReadNormalWord();return (gLinkReceivedPacket>>24)!=2; }
uint8_t ProbeNormalSlave(void)
{ gLinkSendPacket=0x02645321;SendNormalWord();return WaitSerialInterrupt()==1?(gLinkReceivedPacket>>24)!=1:1; }
uint8_t DetectNormalMaster(void)
{ for(unsigned outer=10;outer;--outer)for(unsigned inner=2;inner;--inner)if(!ProbeNormalMaster()) { gLinkState.role=0;return 0; }return 1; }
/*0801F698/6D0/6F8/704*/
void ReplyToNormalProbe(void)
{ if((gLinkReceivedPacket>>24)==1) { gLinkSendPacket=0x02000000;SendNormalWord(); }SignalSerialInterrupt(); }
void AcknowledgeNormalSerial(void) { SignalSerialInterrupt(); }
void ReplyToNormalTransfer(void)
{ uint8_t kind=gLinkReceivedPacket>>24;if(kind!=5 && kind!=7)gLinkState.error=1;SendNormalWord();SignalSerialInterrupt(); }
void ServiceNormalSerialInterrupt(void)
{ DisableSerialInterrupt();ReadNormalWord();switch(gLinkState.role) { case 4:ReplyToNormalProbe();break;case 0:AcknowledgeNormalSerial();break;case 1:ReplyToNormalTransfer();break; }EnableSerialInterrupt(); }
/*0801F72C/758/7A8/7D8*/
void SendMultiplayerWord(void) { REG16(0x0400012A)=gLinkOutgoing;if(!gLinkState.role)REG16(0x04000128)|=0x80; }
uint8_t WaitLinkReady(void)
{
    uint8_t success=0;gLinkState.phase=8;gLinkState.subphase=0;
    for(unsigned remaining=60;remaining;--remaining) { if(REG16(0x04000128)&8) { success=1;break; }WaitForFrame(); }
    gLinkState.phase=1;gLinkState.subphase=0;return success;
}
void DetectLinkRole(void)
{ gLinkState.phase=7;gLinkState.subphase=0;gLinkState.role=(REG16(0x04000128)&4)?1:0;gLinkState.phase=1;gLinkState.subphase=0; }
void InitializeMultiplayerSerial(void)
{ DisableSerialInterrupt();REG16(0x04000134)=0;REG16(0x04000128)=0x1000;REG16(0x04000134)=0;REG16(0x04000128)=0x2000;REG16(0x04000128)|=0x4000;SetLinkBaud3(); }
/*0801F818/830/84C/868: a read/write remains even for baud0.*/
void SetLinkBaud0(void) { REG16(0x04000128)&=0xFFFC;REG16(0x04000128)=REG16(0x04000128); }
void SetLinkBaud1(void) { REG16(0x04000128)&=0xFFFC;REG16(0x04000128)|=1; }
void SetLinkBaud2(void) { REG16(0x04000128)&=0xFFFC;REG16(0x04000128)|=2; }
void SetLinkBaud3(void) { REG16(0x04000128)&=0xFFFC;REG16(0x04000128)|=3; }
/*08022014/034/058/0F8/2210C/124/144/154/168*/
void EnableLinkTimerInterrupt(void) { REG16(0x04000208)=0;REG16(0x04000200)|=0x40;REG16(0x04000208)=1; }
void DisableLinkTimerInterrupt(void) { REG16(0x04000208)=0;REG16(0x04000200)&=0xFFBF;REG16(0x04000208)=1; }
void ServiceLinkTimerInterrupt(void) { ++gLinkState.timerInterrupts;SignalLinkTimer(); }
void ClearLinkTimerFlag(void) { gFrameInterruptFlags&=0xFFBF; } /*080220E4*/
void SignalLinkTimer(void) { REG16(0x04000202)=0x40;gFrameInterruptFlags|=0x40; }
void InitializeLinkTimer(void) { DisableLinkTimerInterrupt();REG16(0x0400010E)=0;REG16(0x0400010C)=0xE4B1; }
void StartLinkTimer(void) { REG16(0x0400010E)|=0xC0; }
void StopLinkTimer(void) { REG16(0x0400010E)&=0xFF3F; }
void WaitLinkTimer(void) { ClearLinkTimerFlag();while(!(gFrameInterruptFlags&0x40)) {} }
/*08022070/0B0*/
void LinkTimerSendByte(void)
{ if(!gLinkState.role) { if(!gLinkState.remaining)StopLinkTimer();else { SetLinkOutgoing(LinkReadSendByte()|0x500);SendMultiplayerWord();--gLinkState.remaining; } } }
void LinkTimerRequestByte(void)
{ if(!gLinkState.role) { if(!gLinkState.remaining)StopLinkTimer();else { SetLinkOutgoing(0x600);SendMultiplayerWord(); } } }
/*0801F4D8/564/5CC/630. The fourth bad reply stops the timer.*/
static void MissedReply(void) { if(gLinkState.missedReplies<3)++gLinkState.missedReplies;else StopLinkTimer(); }
void LinkReceiveTick(void)
{
    if(!gLinkState.role) { if((gLinkIncoming[1]>>8)==5) { gLinkState.missedReplies=0;LinkWriteReceiveByte(gLinkIncoming[1]);if(!--gLinkState.remaining)gLinkState.phase=6; }else MissedReply(); }
    else if(gLinkState.role<4) { if((gLinkIncoming[0]>>8)==5) { LinkWriteReceiveByte(gLinkIncoming[0]);--gLinkState.remaining; }SetLinkOutgoing(0x600);SendMultiplayerWord(); }
}
void LinkSendTick(void)
{
    if(!gLinkState.role) { if((gLinkIncoming[1]>>8)==6)gLinkState.missedReplies=0;else MissedReply(); }
    else if(gLinkState.role<4 && gLinkState.remaining) { SetLinkOutgoing(LinkReadSendByte()|0x500);SendMultiplayerWord();--gLinkState.remaining; }
}
void LinkHandshakeTick(void)
{
    if(!gLinkState.role) { if((gLinkIncoming[1]>>8)==4) { gLinkState.missedReplies=0;StopLinkTimer(); }else MissedReply(); }
    else if(gLinkState.role<4) { SetLinkOutgoing((gLinkIncoming[0]>>8)==3?0x400:0);SendMultiplayerWord(); }
}
void LinkFinishTick(void)
{
    if(!gLinkState.role) { unsigned kind=gLinkIncoming[1]>>8;if(kind==8 || kind==9) { gLinkState.missedReplies=0;StopLinkTimer(); }else MissedReply(); }
    else if(gLinkState.role<4) { SetLinkOutgoing((gLinkIncoming[0]>>8)==7?0x800:0);SendMultiplayerWord(); }
}
/* Dormant normal-serial controls0801F128/140/158/168. Baud helpers use
 * bits0..1, while these entries concern clock and general-purpose data.*/
void SelectExternalSerialClock(void) { REG16(0x04000128)&=0xFFFE;REG16(0x04000128)=REG16(0x04000128); }
uint8_t ReadSerialInputBit(void) { return (REG16(0x04000128)&4)!=0; }
void SetSerialOutputBit(void) { REG16(0x04000128)|=8; }
void ClearSerialOutputBit(void) { REG16(0x04000128)&=0xFFF7; }
