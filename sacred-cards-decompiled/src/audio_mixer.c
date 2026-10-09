/* AY7E PCM mixer, semantic reconstruction of08036C80/08036D04..080370A2.
 * Register/stack inputs to the copied Thumb/ARM block are explicit C arguments.
 * The native packed-word additions and wrapping are retained, not replaced by
 * clipping or independent sample sums. Valid initialized mixer records are
 * required. This has not been execution-compared or compiler-matched. */
#include "audio.h"
static uint32_t RotateRight(uint32_t n,unsigned bits)
{ bits&=31;return bits?(n>>bits)|(n<<(32-bits)):n; }
/* 08036DBC..08036E76 */
static unsigned TickPcmEnvelope(uint8_t *info,uint8_t *c,const uint8_t *wave)
{
    unsigned state=c[0],volume=c[9];if(!(state&0xC7))return 0;
    if(state&0x80) {
        if(state&0x40)goto stop;
        state=3;Write32(c+0x28,(uint32_t)(uintptr_t)(wave+16));Write32(c+0x18,Read32(wave+12));
        volume=0;c[9]=0;Write32(c+0x1C,0);if(wave[3]&0xC0)state|=16;c[0]=state;
        goto attack;
    }
    if(state&4) {
        unsigned old=c[0xD];c[0xD]=old-1;if(old<=1)goto stop;
    } else if(state&0x40) {
        volume=(volume*c[7])>>8;if(volume<=c[0xC])goto echo;
    } else if((state&3)==2) {
        volume=(volume*c[5])>>8;
        if(volume<=c[6]) { volume=c[6];if(!volume)goto echo;--state;c[0]=state; }
    } else if((state&3)==3) {
attack:volume+=c[4];if(volume>=255) { volume=255;--state;c[0]=state; }
    }
    goto scaled;
echo:volume=c[0xC];if(!volume)goto stop;state|=4;c[0]=state;
scaled:
    c[9]=volume;volume=(volume*((unsigned)info[7]+1))>>4;
    c[10]=(volume*c[2])>>8;c[11]=(volume*c[3])>>8;return 1;
stop:c[0]=0;return 0;
}
/* 08036D04..08036D90. The native sample counts are >=16 and divisible by4. */
static void PreparePcmBuffer(uint8_t *info,uint8_t *buffer,uint32_t count,uint8_t dma_period)
{
    if(!info[5]) {
        for(uint32_t i=0;i<count;++i)buffer[i]=buffer[i+0x630]=0;
    } else {
        uint8_t *other=dma_period==2?info+0x350:buffer+count;
        for(uint32_t i=0;i<count;++i) {
            int32_t sum=(int8_t)buffer[i]+(int8_t)buffer[i+0x630]+(int8_t)other[i]+(int8_t)other[i+0x630];
            int32_t sample=(sum*info[5])>>9;if(sample&0x80)++sample;
            buffer[i+0x630]=(uint8_t)sample;buffer[i]=(uint8_t)sample;
        }
    }
}
/* Native ARM loops tag the output pointer's top two bits to count four
 * samples per word. This adapter expresses that tag as the lane variable. */
static void MixPcmChannel(uint8_t *info,uint8_t *c,uint8_t *buffer,uint32_t count)
{
    const uint8_t *wave=Pointer(c+0x24);if(!TickPcmEnvelope(info,c,wave))return;
    uint32_t loop_length=0;const uint8_t *loop=0;
    if(c[0]&16) { uint32_t start=Read32(wave+8);loop=wave+16+start;loop_length=Read32(wave+12)-start; }
    uint32_t remaining=Read32(c+0x18),phase=Read32(c+0x1C);
    const uint8_t *cursor=Pointer(c+0x28);
    uint32_t left_gain=(uint32_t)c[10]<<16,right_gain=(uint32_t)c[11]<<16;
    uint32_t step=Read32(info+0x18)*Read32(c+0x20);unsigned direct=c[1]&8;
    int32_t sample=0,difference=0;
    if(!direct) { sample=(int8_t)*cursor++;difference=(int8_t)*cursor-sample; }
    for(uint32_t word=0;word<count;word+=4) {
        uint32_t left=Read32(buffer+word),right=Read32(buffer+word+0x630);
        for(unsigned lane=0;lane<4;++lane) {
            int32_t value=direct?(int8_t)*cursor++:sample+((int32_t)(phase*(uint32_t)difference)>>23);
            left=RotateRight(left,8)+((left_gain*(uint32_t)value)&0xFF00FFFFu);
            right=RotateRight(right,8)+((right_gain*(uint32_t)value)&0xFF00FFFFu);
            unsigned ended=0;
            if(direct) {
                --remaining;
                if(!remaining) { remaining=loop_length;if(remaining)cursor=loop;else ended=1; }
            } else {
                phase+=step;uint32_t advance=phase>>23;
                if(advance) {
                    phase&=0xC07FFFFFu;remaining-=advance;
                    if((int32_t)remaining<=0) {
                        if(!loop_length)ended=1;
                        else {
                            uint32_t overshoot=0u-remaining;
                            while((int32_t)(remaining+=loop_length)<=0)overshoot-=loop_length;
                            cursor=loop+overshoot;sample=(int8_t)*cursor++;
                            difference=(int8_t)*cursor-sample;
                        }
                    } else {
                        if(advance==1)sample+=difference;
                        else { cursor+=advance-1;sample=(int8_t)*cursor; }
                        ++cursor;difference=(int8_t)*cursor-sample;
                    }
                }
            }
            if(ended) {
                c[0]=0;Write32(buffer+word+0x630,RotateRight(right,(3-lane)*8));
                Write32(buffer+word,RotateRight(left,(3-lane)*8));return;
            }
        }
        Write32(buffer+word+0x630,right);Write32(buffer+word,left);
    }
    if(!direct) { --cursor;Write32(c+0x1C,phase); }
    Write32(c+0x18,remaining);Write32(c+0x28,(uint32_t)(uintptr_t)cursor);
}
/* 08036C80 plus its shared-register copied body08036D04. The scanline cutoff
 * is checked before each channel, after preparing the reverb/clear buffer. */
void m4aSoundMain(void)
{
    uint8_t *info=gSoundInfo;if(Read32(info)!=SOUND_MAGIC)return;Write32(info,SOUND_MAGIC+1);
    uint32_t cutoff=0;
    if(info[0xC]) { unsigned line=*(volatile uint8_t *)0x04000006;if(line<160)line+=228;cutoff=line+info[0xC]; }
    if(Read32(info+0x20))((void (*)(void *))(uintptr_t)Read32(info+0x20))(Pointer(info+0x24));
    ((void (*)(void))(uintptr_t)Read32(info+0x28))();
    uint32_t count=Read32(info+0x10);uint8_t period=info[4];uint8_t *buffer=info+0x350;
    if(period>1)buffer+=((uint32_t)info[0xB]-(period-1))*count;
    PreparePcmBuffer(info,buffer,count,period);
    for(unsigned i=0;i<info[6];++i) {
        if(cutoff) { unsigned line=*(volatile uint8_t *)0x04000006;if(line<160)line+=228;if(line>=cutoff)break; }
        MixPcmChannel(info,info+0x50+i*0x40,buffer,count);
    }
    Write32(info,SOUND_MAGIC);
}
