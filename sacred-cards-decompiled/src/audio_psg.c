/* AY7E PSG pitch conversion and oscillator stop. The envelope/register tick
 * engine remains separate. Hardware accesses have not been executed here. */
#include "audio.h"
extern const uint8_t gPsgNoiseFrequencies[60],gPsgKeyScale[132]; /* 089DF754 / 089DF6B8 */
extern const int16_t gPsgPitchTable[12]; /* 089DF73C */
/* 08038388 */
uint32_t MidiKeyToPsgFrequency(uint8_t channel,uint8_t key,uint8_t fine)
{
    if(channel==4) {
        unsigned index=key<21?0:key-21;if(index>59)index=59;
        return gPsgNoiseFrequencies[index];
    }
    unsigned index;
    if(key<36) { fine=0;index=0; }
    else { index=key-36;if(index>130) { index=130;fine=255; } }
    uint8_t a=gPsgKeyScale[index],b=gPsgKeyScale[index+1];
    int32_t low=gPsgPitchTable[a&15]>>(a>>4),high=gPsgPitchTable[b&15]>>(b>>4);
    return (uint32_t)(low+(((high-low)*fine)>>8)+2048);
}
/* 08038430; all IDs except1/2/3 follow the channel4 branch. */
void StopPsgOscillator(uint8_t channel)
{
    if(channel==3) { *(volatile uint8_t *)0x04000070=0;return; }
    uintptr_t address=channel==1?0x04000063:channel==2?0x04000069:0x04000079;
    *(volatile uint8_t *)address=8;
    *(volatile uint8_t *)(address+(channel==1?2:4))=0x80;
}

/* 08038480: only the single-sided branches clamp target volume to15. */
void CalculatePsgEnvelopeVolume(uint8_t *c)
{
    unsigned left=c[2],right=c[3],volume=(left+right)>>4;
    if(left<right && left<=right/2) { c[0x1B]=0xF0;if(volume>15)volume=15; }
    else if(left>=right && right<=left/2) { c[0x1B]=15;if(volume>15)volume=15; }
    else c[0x1B]=255;
    c[10]=volume;c[0x19]=(volume*c[6]+15)>>4;c[0x1B]&=c[0x1C];
}
extern const uint8_t gPsgWaveVolumes[16]; /* 089DF790 */
#define PSG8(a) (*(volatile uint8_t *)(uintptr_t)(a))
#define PSG32(a) (*(volatile uint32_t *)(uintptr_t)(a))
/* 080384E8. Labels retain the native envelope transitions, including the
 * extra envelope step once every15 frames and signed byte countdown tests. */
void TickPsgSound(void)
{
    uint8_t *info=gSoundInfo;info[10]=info[10]?info[10]-1:14;
    uint8_t *c=Pointer(info+0x1C);
    for(unsigned id=1;id<=4;++id,c+=0x40) {
        if(!(c[0]&0xC7))continue;
        static const uintptr_t ports[4][5]={
            {0x04000060,0x04000062,0x04000063,0x04000064,0x04000065},
            {0x04000061,0x04000068,0x04000069,0x0400006C,0x0400006D},
            {0x04000070,0x04000072,0x04000073,0x04000074,0x04000075},
            {0x04000071,0x04000078,0x04000079,0x0400007C,0x0400007D}};
        const uintptr_t *port=ports[id-1];uint8_t envelope=PSG8(port[2]);int frame=info[10];
        if(c[0]&0x80) {
            if(c[0]&0x40)goto stop;
            c[0]=3;c[0x1D]=3;CalculatePsgEnvelopeVolume(c);
            if(id==1)PSG8(port[0])=c[0x1F];
            if(id<=2)PSG8(port[1])=(uint8_t)(c[0x1E]+(Read32(c+0x24)<<6));
            else if(id==3) {
                if(Read32(c+0x24)!=Read32(c+0x28)) {
                    PSG8(port[0])=0x40;uint8_t *wave=Pointer(c+0x24);
                    for(unsigned i=0;i<4;++i)PSG32(0x04000090+i*4)=Read32(wave+i*4);
                    Write32(c+0x28,Read32(c+0x24));
                }
                PSG8(port[0])=0;PSG8(port[1])=c[0x1E];c[0x1A]=c[0x1E]?0xC0:0x80;
            } else { PSG8(port[1])=c[0x1E];PSG8(port[3])=(uint8_t)(Read32(c+0x24)<<3); }
            if(id!=3) { envelope=c[4]+8;c[0x1A]=c[0x1E]?0x40:0; }
            c[0xB]=c[4];if(!c[4])goto start_decay;c[9]=0;goto decrement;
        }
        if(c[0]&4) { --c[0xD];if((int8_t)c[0xD]<=0)goto stop;goto registers; }
        if((c[0]&0x40) && (c[0]&3)) {
            c[0]&=0xFC;c[0xB]=c[7];if(!c[7])goto echo;
            c[0x1D]|=1;if(id!=3)envelope=c[7];goto decrement;
        }
envelope_step:
        if(c[0xB])goto decrement;
        if(id==3)c[0x1D]|=1;
        CalculatePsgEnvelopeVolume(c);
        switch(c[0]&3) {
        case 0:--c[9];if((int8_t)c[9]<=0)goto echo;c[0xB]=c[7];break;
        case 1:goto sustain;
        case 2:--c[9];if((int8_t)c[9]<=(int8_t)c[0x19])goto enter_sustain;c[0xB]=c[5];break;
        case 3:++c[9];if(c[9]>=c[10])goto start_decay;c[0xB]=c[4];break;
        }
        goto decrement;
start_decay:
        --c[0];c[0xB]=c[5];if(!c[5])goto enter_sustain;
        c[0x1D]|=1;c[9]=c[10];if(id!=3)envelope=c[5];goto decrement;
enter_sustain:
        if(!c[6]) { c[0]&=0xFC;goto echo; }
        --c[0];c[0x1D]|=1;if(id!=3)envelope=8;
sustain:
        c[9]=c[0x19];c[0xB]=7;
decrement:
        --c[0xB];if(!frame) { frame=-1;goto envelope_step; }goto registers;
echo:
        c[9]=((unsigned)c[10]*c[0xC]+255)>>8;if(!c[9])goto stop;
        c[0]|=4;c[0x1D]|=1;if(id!=3)envelope=8;
registers:
        if(c[0x1D]&2) {
            if(id<4 && (c[1]&8)) {
                uint8_t bias=PSG8(0x04000089);uint32_t frequency=Read32(c+0x20);
                if(bias<64)Write32(c+0x20,(frequency+2)&0x7FC);
                else if(bias<128)Write32(c+0x20,(frequency+1)&0x7FE);
            }
            PSG8(port[3])=id==4?(uint8_t)Read32(c+0x20)|(PSG8(port[3])&8):(uint8_t)Read32(c+0x20);
            c[0x1A]=(uint8_t)(c[0x21]+(c[0x1A]&0xC0));PSG8(port[4])=c[0x1A];
        }
        if(c[0x1D]&1) {
            PSG8(0x04000081)=(PSG8(0x04000081)&~c[0x1C])|c[0x1B];
            if(id==3) {
                PSG8(port[2])=gPsgWaveVolumes[c[9]];
                if(c[0x1A]&0x80) { PSG8(port[0])=0x80;PSG8(port[4])=c[0x1A];c[0x1A]&=0x7F; }
            } else {
                PSG8(port[2])=(uint8_t)(c[9]*16+(envelope&15));PSG8(port[4])=c[0x1A]|0x80;
                if(id==1 && !(PSG8(port[0])&8))PSG8(port[4])=c[0x1A]|0x80;
            }
        }
        c[0x1D]=0;continue;
stop:StopPsgOscillator(id);c[0]=0;c[0x1D]=0;
    }
}
