/* AY7E synchronous link protocol0801EE10..1FAF4. Local 16-bit counts wrap
 * as on ARM; they do not update the asynchronous state's remaining field.
 * Wrong packet tags do not consume a slave retry in the original. */
#include "link_transport.h"
static void BeginMaster(void)
{ EnableSerialInterrupt();InitializeLinkTimer();EnableLinkTimerInterrupt();StartLinkTimer(); }
static void EndMaster(void)
{ StopLinkTimer();DisableLinkTimerInterrupt();DisableSerialInterrupt(); }
/*0801F180. An initially empty send returns failure.*/
uint8_t LinkMasterSend(void)
{
    uint16_t count=gLinkState.remaining;uint8_t success=0;BeginMaster();
    while(count) { WaitLinkTimer();SetLinkOutgoing(LinkReadSendByte()|0x500);SendMultiplayerWord();--count;if(!PollSerialInterrupt())break;if(!count)success=1; }
    EndMaster();return success;
}
/*0801F1EC: request includes one byte from the send buffer, even if count0.*/
uint8_t LinkMasterReceive(void)
{
    uint16_t count=gLinkState.remaining;uint8_t retries=60,success=0;
    SetLinkOutgoing(LinkReadSendByte()|0x600);BeginMaster();
    do { WaitLinkTimer();SendMultiplayerWord();
        if(PollSerialInterrupt()==1 && (gLinkIncoming[1]>>8)==5) { LinkWriteReceiveByte(gLinkIncoming[1]);--count; }else --retries;
        if(!count) { success=1;break; }
    }while(retries);
    EndMaster();return success;
}
/*0801F27C*/
uint8_t LinkSlaveSend(void)
{
    uint16_t count=gLinkState.remaining;uint8_t retries=60,success=0;EnableSerialInterrupt();
    do { if(WaitSerialInterrupt()==1) { if((gLinkIncoming[0]>>8)==6) { SetLinkOutgoing(LinkReadSendByte()|0x500);SendMultiplayerWord();--count; } }else --retries;
        if(!count && WaitSerialInterrupt()==1) { success=1;break; }
    }while(retries);
    DisableSerialInterrupt();return success;
}
/*0801F2F4*/
uint8_t LinkSlaveReceive(void)
{
    uint16_t count=gLinkState.remaining;uint8_t retries=60,success=0;EnableSerialInterrupt();
    do { if(WaitSerialInterrupt()==1) { if((gLinkIncoming[0]>>8)==5) { LinkWriteReceiveByte(gLinkIncoming[0]);--count;SetLinkOutgoing(0x600);SendMultiplayerWord(); } }else --retries;
        if(!count) { success=1;break; }
    }while(retries);
    DisableSerialInterrupt();return success;
}
/*0801EF5C/1EFA4: both use the same send/receive buffer assignment.*/
static void AssignPayloads(void)
{ gLinkState.send=(uintptr_t)gLinkSecondaryPayload;gLinkState.receive=(uintptr_t)gLinkPrimaryPayload; }
uint8_t LinkSendPrimaryDirection(void)
{ AssignPayloads();if(!gLinkState.role)return LinkMasterSend();if(gLinkState.role<4)return LinkSlaveReceive();return 0; }
uint8_t LinkSendReverseDirection(void)
{ AssignPayloads();if(!gLinkState.role)return LinkMasterReceive();if(gLinkState.role<4)return LinkSlaveSend();return 0; }
/*0801F950/1FA8C share the timer-poll structure; finish tag9 aborts early.*/
static uint8_t MasterHandshake(uint16_t outgoing,uint8_t expected,uint8_t finish)
{
    uint8_t success=0,retries=60;SetLinkOutgoing(outgoing);BeginMaster();
    do { WaitLinkTimer();SendMultiplayerWord();if(PollSerialInterrupt()==1) { unsigned tag=gLinkIncoming[1]>>8;if(tag==expected) { success=1;break; }if(finish && tag==9)break; } }while(--retries);
    EndMaster();return success;
}
uint8_t LinkMasterHandshake(void) { return MasterHandshake(0x300,4,0); }
uint8_t LinkMasterFinish(void) { return MasterHandshake(0x700,8,1); }
/*0801F9BC/1FAF4. Success requires one more serial interrupt after reply.*/
static uint8_t SlaveHandshake(uint8_t expected,uint8_t finish)
{
    uint16_t reply=0;uint8_t success=0,retries=60;SetLinkOutgoing(0);SendMultiplayerWord();EnableSerialInterrupt();
    do { if(WaitSerialInterrupt()==1 && (gLinkIncoming[0]>>8)==expected) {
            reply=finish?(gLinkState.error?0x900:0x800):0x400;SetLinkOutgoing(reply);SendMultiplayerWord();
            if(WaitSerialInterrupt()==1) { success=1;break; }
        }SetLinkOutgoing(reply);SendMultiplayerWord();
    }while(--retries);
    DisableSerialInterrupt();return success;
}
uint8_t LinkSlaveHandshake(void) { return SlaveHandshake(3,0); }
uint8_t LinkSlaveFinish(void) { return SlaveHandshake(7,1); }
/*0801F8EC/1FA2C*/
uint8_t LinkHandshake(void)
{
    uint8_t success=0;gLinkState.phase=2;gLinkState.subphase=4;ClearLinkBuffers();
    if(gLinkState.role<4)success=gLinkState.role?LinkSlaveHandshake():LinkMasterHandshake();
    if(!success)gLinkState.error=1;gLinkState.phase=1;gLinkState.subphase=0;return success;
}
uint8_t LinkFinishHandshake(void)
{
    uint8_t success=0;gLinkState.phase=9;gLinkState.subphase=4;
    if(gLinkState.role<4)success=gLinkState.role?LinkSlaveFinish():LinkMasterFinish();
    if(!success)gLinkState.error=1;gLinkState.phase=0;gLinkState.subphase=0;return success;
}
/*0801EE10. Dormant stress loop has a 96-bit iteration counter and three
 * retries in each direction. Counters map0201EE5C..0201EE70. */
extern volatile uint32_t gLinkDiagnosticCounters[6];
uint8_t RunLinkStressDiagnostic(void)
{
    uint8_t success=0;for(unsigned i=0;i<6;++i)gLinkDiagnosticCounters[i]=0;FillLinkSecondaryPayload();
    for(;;) {
        success=0;
        for(unsigned retries=3;retries && !success;--retries) {
            InitializeLinkState();InitializeLinkPayloads();gLinkState.remaining=2000;
            if(WaitLinkReady()==1) { DetectLinkRole();if(LinkHandshake()==1 && LinkSendPrimaryDirection()==1 && LinkFinishHandshake()==1)success=1; }
            if(!success)++gLinkDiagnosticCounters[4];
        }
        if(success) { success=0;
            for(unsigned retries=3;retries && !success;--retries) {
                InitializeLinkState();gLinkState.remaining=2000;
                if(WaitLinkReady()==1) { DetectLinkRole();if(LinkHandshake()==1 && LinkSendReverseDirection()==1 && LinkFinishHandshake()==1)success=1; }
                if(!success)++gLinkDiagnosticCounters[5];
            }
        }
        if(!success)++gLinkDiagnosticCounters[3];
        if(gLinkDiagnosticCounters[0]!=UINT32_MAX)++gLinkDiagnosticCounters[0];
        else if(gLinkDiagnosticCounters[1]!=UINT32_MAX) { ++gLinkDiagnosticCounters[1];gLinkDiagnosticCounters[0]=0; }
        else if(gLinkDiagnosticCounters[2]!=UINT32_MAX) { ++gLinkDiagnosticCounters[2];gLinkDiagnosticCounters[1]=gLinkDiagnosticCounters[0]=0; }
        else break;
    }return success;
}
