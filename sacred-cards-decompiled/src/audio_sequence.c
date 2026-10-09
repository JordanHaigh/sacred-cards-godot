/* AY7E sequence handlers and per-track arithmetic, reviewed against Thumb
 * instructions. Raw native addresses and valid track records are required.
 * No mixer/hardware execution comparison or compiler matching is claimed. */
#include "audio.h"

/* 080370A8 clears exactly64 bytes, including for a track whose record is80. */
void ClearMusicRecord(uint8_t *p) { for(unsigned i=0;i<64;++i)p[i]=0; }
/* 080370C0 */
void UnlinkSoundChannel(uint8_t *c)
{
    uint8_t *track=Pointer(c+0x2C);if(!track)return;
    uint32_t next=Read32(c+0x34),previous=Read32(c+0x30);
    if(previous)Write32((uint8_t *)(uintptr_t)previous+0x34,next);
    else Write32(track+0x20,next);
    if(next)Write32((uint8_t *)(uintptr_t)next+0x30,previous);
    Write32(c+0x2C,0);
}
/* 080370E0, also the fallback for unused command slots. */
void FinishMusicTrack(struct MusicPlayer *player,uint8_t *t)
{
    (void)player;
    for(uint8_t *c=Pointer(t+0x20);c;c=Pointer(c+0x34)) {
        if(c[0]&0xC7)c[0]|=0x40;
        UnlinkSoundChannel(c);
    }
    t[0]=0;
}
/* 0803712A filters the loaded value by its source address. Keeping the literal
 * predicate avoids silently substituting a generic "valid GBA pointer" rule. */
static uint32_t FilterSequenceValue(const uint8_t *source,uint32_t value)
{
    uint32_t address=(uint32_t)(uintptr_t)source;
    return (address>>25)||(address>=0x089DF52Cu && !(address>>14))?value:0;
}
/* 08037144/146/128; the byte load occurs before filtering. */
static uint8_t ReadSequenceByte(uint8_t *t)
{
    uint8_t *p=Pointer(t+0x40);Write32(t+0x40,(uint32_t)(uintptr_t)(p+1));
    return (uint8_t)FilterSequenceValue(p,*p);
}
/* 08037150 */
void MusicCommandGoto(struct MusicPlayer *player,uint8_t *t)
{
    (void)player;uint8_t *p=Pointer(t+0x40);
    uint32_t target=(uint32_t)p[3]<<24|(uint32_t)p[2]<<16|(uint32_t)p[1]<<8;
    Write32(t+0x40,target|FilterSequenceValue(p,p[0]));
}
/* 08037170 / 0803718C */
void MusicCommandPattern(struct MusicPlayer *p,uint8_t *t)
{
    if(t[2]>=3) { FinishMusicTrack(p,t);return; }
    Write32(t+0x44+t[2]*4,Read32(t+0x40)+4);++t[2];MusicCommandGoto(p,t);
}
void MusicCommandPatternEnd(struct MusicPlayer *p,uint8_t *t)
{ (void)p;if(t[2]) { --t[2];Write32(t+0x40,Read32(t+0x44+t[2]*4)); } }
/* 080371A0. Compare the untruncated increment (256 at overflow) to the limit. */
void MusicCommandRepeat(struct MusicPlayer *p,uint8_t *t)
{
    uint8_t *cursor=Pointer(t+0x40);
    if(!*cursor) { Write32(t+0x40,(uint32_t)(uintptr_t)(cursor+1));MusicCommandGoto(p,t);return; }
    unsigned count=(unsigned)t[3]+1;t[3]=(uint8_t)count;
    unsigned limit=ReadSequenceByte(t);
    if(count<limit)MusicCommandGoto(p,t);
    else { t[3]=0;Write32(t+0x40,(uint32_t)(uintptr_t)(cursor+5)); }
}
/* 080371D0 / 080371DC / 080371F0 */
void MusicCommandPriority(struct MusicPlayer *p,uint8_t *t) { (void)p;t[0x1D]=ReadSequenceByte(t); }
void MusicCommandTempo(struct MusicPlayer *p,uint8_t *t)
{
    unsigned tempo=ReadSequenceByte(t)*2;Write16(p->bytes+0x1C,tempo);
    Write16(p->bytes+0x20,(tempo*Read16(p->bytes+0x1E))>>8);
}
void MusicCommandKeyShift(struct MusicPlayer *p,uint8_t *t) { (void)p;t[0xA]=ReadSequenceByte(t);t[0]|=12; }
/* 08037204 filters all three words against the SAME voice base address. */
void MusicCommandVoice(struct MusicPlayer *p,uint8_t *t)
{
    uint8_t *cursor=Pointer(t+0x40);unsigned voice=*cursor;
    Write32(t+0x40,(uint32_t)(uintptr_t)(cursor+1));
    uint8_t *v=Pointer(p->bytes+0x30)+voice*12;
    for(unsigned i=0;i<3;++i)Write32(t+0x24+i*4,FilterSequenceValue(v,Read32(v+i*4)));
}
/* 08037234/248/25C/270/284/290/2A8 */
void MusicCommandVolume(struct MusicPlayer *p,uint8_t *t) { (void)p;t[0x12]=ReadSequenceByte(t);t[0]|=3; }
void MusicCommandPan(struct MusicPlayer *p,uint8_t *t) { (void)p;t[0x14]=ReadSequenceByte(t)-64;t[0]|=3; }
void MusicCommandBend(struct MusicPlayer *p,uint8_t *t) { (void)p;t[0xE]=ReadSequenceByte(t)-64;t[0]|=12; }
void MusicCommandBendRange(struct MusicPlayer *p,uint8_t *t) { (void)p;t[0xF]=ReadSequenceByte(t);t[0]|=12; }
void MusicCommandLfoDelay(struct MusicPlayer *p,uint8_t *t) { (void)p;t[0x1B]=ReadSequenceByte(t); }
void MusicCommandModType(struct MusicPlayer *p,uint8_t *t)
{ (void)p;uint8_t n=ReadSequenceByte(t);if(t[0x18]!=n) { t[0x18]=n;t[0]|=15; } }
void MusicCommandTune(struct MusicPlayer *p,uint8_t *t) { (void)p;t[0xC]=ReadSequenceByte(t)-64;t[0]|=12; }
/* 080372BC writes a byte to hardware base04000060+operand. */
void MusicCommandPort(struct MusicPlayer *p,uint8_t *t)
{
    (void)p;uint8_t *cursor=Pointer(t+0x40);unsigned port=*cursor;
    Write32(t+0x40,(uint32_t)(uintptr_t)(cursor+1));
    *(volatile uint8_t *)(uintptr_t)(0x04000060u+port)=ReadSequenceByte(t);
}
/* 0803783C / 08037864 / 08037878. These operands bypass the address filter. */
static void ResetModulation(uint8_t *t) { t[0x16]=t[0x1A]=0;t[0]|=t[0x18]?3:12; }
static uint8_t ReadRawSequenceByte(uint8_t *t)
{ uint8_t *c=Pointer(t+0x40);Write32(t+0x40,(uint32_t)(uintptr_t)(c+1));return *c; }
void MusicCommandLfoSpeed(struct MusicPlayer *p,uint8_t *t)
{ (void)p;t[0x19]=ReadRawSequenceByte(t);if(!t[0x19])ResetModulation(t); }
void MusicCommandModDepth(struct MusicPlayer *p,uint8_t *t)
{ (void)p;t[0x17]=ReadRawSequenceByte(t);if(!t[0x17])ResetModulation(t); }
/* 080377FC releases only the first active matching key. */
void MusicCommandEndTie(struct MusicPlayer *p,uint8_t *t)
{
    (void)p;uint8_t *cursor=Pointer(t+0x40);uint8_t key=*cursor;
    if(key<128) { t[5]=key;Write32(t+0x40,(uint32_t)(uintptr_t)(cursor+1)); } else key=t[5];
    for(uint8_t *c=Pointer(t+0x20);c;c=Pointer(c+0x34))
        if((c[0]&0x83) && !(c[0]&0x40) && c[0x11]==key) { c[0]|=0x40;break; }
}
/* 0803820C. Fade bit0 preserves track state when pausing; bit1 fades in. */
void TickMusicFade(struct MusicPlayer *player)
{
    uint8_t *p=player->bytes;uint16_t interval=Read16(p+0x24);if(!interval)return;
    uint16_t countdown=Read16(p+0x26)-1;Write16(p+0x26,countdown);if(countdown)return;
    Write16(p+0x26,interval);uint16_t volume=Read16(p+0x28);
    if(volume&2) {
        volume+=16;Write16(p+0x28,volume);
        if(volume>255) { volume=256;Write16(p+0x28,volume);Write16(p+0x24,0); }
    } else {
        volume-=16;Write16(p+0x28,volume);
        if((int16_t)volume<=0) {
            uint8_t *t=Pointer(p+0x2C);
            for(unsigned i=0;i<p[8];++i,t+=0x50) { StopMusicTrack(player,t);if(!(volume&1))t[0]=0; }
            Write32(p+4,(volume&1)?Read32(p+4)|0x80000000u:0x80000000u);
            Write16(p+0x24,0);return;
        }
    }
    uint8_t *t=Pointer(p+0x2C);
    for(unsigned i=0;i<p[8];++i,t+=0x50)if(t[0]&0x80) { t[0x13]=volume>>2;t[0]|=3; }
}
/* 080382D4: signed modulation/pan/bend, unsigned channel volumes. */
void CalculateTrackVolumePitch(struct MusicPlayer *player,uint8_t *t)
{
    (void)player;
    if(t[0]&1) {
        uint32_t volume=((uint32_t)t[0x13]*t[0x12])>>5;
        if(t[0x18]==1)volume=(volume*((int8_t)t[0x16]+128))>>7;
        int32_t pan=(int8_t)t[0x14]*2+(int8_t)t[0x15];
        if(t[0x18]==2)pan+=(int8_t)t[0x16];
        if(pan<-128)pan=-128;else if(pan>127)pan=127;
        t[0x10]=(uint8_t)(((pan+128)*volume)>>8);t[0x11]=(uint8_t)(((127-pan)*volume)>>8);
    }
    if(t[0]&4) {
        int32_t pitch=((int8_t)t[0xE]*t[0xF]+(int8_t)t[0xC])*4;
        pitch+=((int8_t)t[0xA]+(int8_t)t[0xB])*256+t[0xD];
        if(!t[0x18])pitch+=(int8_t)t[0x16]*16;
        t[8]=(uint8_t)(pitch>>8);t[9]=(uint8_t)pitch;
    }
    t[0]&=0xFA;
}

/* 08038BA8, MEMACC. Comparison operations use an immediate for6..11 and
 * a byte in player memory for12..17. An unknown operation consumes3 bytes. */
void MusicCommandMemory(struct MusicPlayer *p,uint8_t *t)
{
    uint8_t operation=ReadRawSequenceByte(t),index=ReadRawSequenceByte(t),operand=ReadRawSequenceByte(t);
    uint8_t *memory=Pointer(p->bytes+0x18),*target=memory+index;
    switch(operation) {
    case 0:*target=operand;return;
    case 1:*target+=operand;return;
    case 2:*target-=operand;return;
    case 3:*target=memory[operand];return;
    case 4:*target+=memory[operand];return;
    case 5:*target-=memory[operand];return;
    default:if(operation>17)return;
    }
    uint8_t value=operation>=12?memory[operand]:operand;unsigned compare=(operation-6)%6;
    unsigned take=compare==0?*target==value:compare==1?*target!=value:compare==2?*target>value:
                  compare==3?*target>=value:compare==4?*target<=value:*target<value;
    if(take) {
        /*08038CE0 calls the mutable GOTO slot, not a fixed function address.*/
        extern uint32_t gSoundCommandCallbacks[36];
        ((MusicCommand)(uintptr_t)gSoundCommandCallbacks[1])(p,t);
    }else Write32(t+0x40,Read32(t+0x40)+4);
}
/* 08038D00 plus the twelve native callback slots. Indices outside0..11 have
 * no valid native callback and are outside this recovered command domain. */
void MusicCommandExtended(struct MusicPlayer *p,uint8_t *t)
{
    unsigned command=ReadRawSequenceByte(t);
    if(command==0 || command==3) { FinishMusicTrack(p,t);return; } /* 08038D20 */
    if(command==1) { /* 08038D34 */
        uint8_t *cursor=Pointer(t+0x40);Write32(t+0x28,Read32(cursor));
        Write32(t+0x40,(uint32_t)(uintptr_t)(cursor+4));return;
    }
    static const uint8_t offsets[12]={0,0,0x24,0,0x2C,0x2D,0x2E,0x2F,0x1E,0x1F,0x26,0x27};
    if(command<12)t[offsets[command]]=ReadRawSequenceByte(t);
}
extern const uint8_t gSoundKeyScale[180],gMusicDurations[49]; /* 089DF5BC / 089DF7A0 */
extern const uint32_t gSoundPitchTable[12]; /* 089DF670 */
/* 0803788C. 08036C70/674 computes the high word of unsigned32x32. */
uint32_t MidiKeyToPcmFrequency(const uint8_t *wave,uint8_t key,uint8_t fine)
{
    if(key>178) { key=178;fine=255; }
    uint8_t a=gSoundKeyScale[key],b=gSoundKeyScale[key+1];
    uint32_t low=gSoundPitchTable[a&15]>>(a>>4),high=gSoundPitchTable[b&15]>>(b>>4);
    uint32_t interpolated=low+(uint32_t)(((uint64_t)(high-low)*((uint32_t)fine<<24))>>32);
    return (uint32_t)(((uint64_t)Read32(wave+4)*interpolated)>>32);
}
/* 080375CC uses nativeR4/R5; this adapter receives those records explicitly. */
void CalculateChannelVolumes(uint8_t *channel,const uint8_t *track)
{
    uint32_t velocity=channel[0x12];int32_t pan=(int8_t)channel[0x14];
    uint32_t left=((uint32_t)(128+pan)*velocity*track[0x10])>>14;
    uint32_t right=((uint32_t)(127-pan)*velocity*track[0x11])>>14;
    channel[2]=left>255?255:left;channel[3]=right>255?255:right;
}
static void TickTrackModulation(uint8_t *t)
{
    if(!t[0x19] || !t[0x17])return;
    if(t[0x1C]) { --t[0x1C];return; }
    unsigned sum=(unsigned)t[0x1A]+t[0x19];t[0x1A]=(uint8_t)sum;
    int32_t triangle=(int8_t)(sum-64)<0?(int8_t)sum:128-(int32_t)sum;
    int32_t modulation=(triangle*t[0x17])>>6;
    if((uint8_t)modulation!=t[0x16]) { t[0x16]=(uint8_t)modulation;t[0]|=t[0x18]?3:12; }
}
/* 08037320. SoundInfo callback pointers remain native runtime bindings.
 * Valid initialized players have1..16 tracks and terminated command streams. */
void m4aMPlayMain(struct MusicPlayer *player)
{
    uint8_t *p=player->bytes;if(Read32(p+0x34)!=SOUND_MAGIC)return;
    Write32(p+0x34,SOUND_MAGIC+1);
    if(Read32(p+0x38))((void (*)(void *))(uintptr_t)Read32(p+0x38))(Pointer(p+0x3C));
    if(Read32(p+4)&0x80000000u)goto done;
    uint8_t *info=gSoundInfo;TickMusicFade(player);
    if(Read32(p+4)&0x80000000u)goto done;
    uint32_t tempo=(uint32_t)Read16(p+0x22)+Read16(p+0x20);
    Write16(p+0x22,tempo);
    while(tempo>=150) {
        uint32_t active=0;uint8_t *t=Pointer(p+0x2C);
        for(unsigned i=0;i<p[8];++i,t+=0x50)if(t[0]&0x80) {
            active|=1u<<i;
            for(uint8_t *c=Pointer(t+0x20);c;c=Pointer(c+0x34)) {
                if(!(c[0]&0xC7))UnlinkSoundChannel(c);
                else if(c[0x10] && !--c[0x10])c[0]|=0x40;
            }
            if(t[0]&0x40) { ClearMusicRecord(t);t[0]=0x80;t[0xF]=2;t[0x13]=64;t[0x19]=22;t[0x24]=1; }
            while(!t[1]) {
                uint8_t *cursor=Pointer(t+0x40);unsigned command=*cursor;
                if(command<128)command=t[7];
                else { Write32(t+0x40,(uint32_t)(uintptr_t)(cursor+1));if(command>=0xBD)t[7]=command; }
                if(command>=0xCF)
                    ((void (*)(uint32_t,struct MusicPlayer *,uint8_t *))(uintptr_t)Read32(info+0x38))(command-0xCF,player,t);
                else if(command>0xB0) {
                    p[0xA]=command-0xB1;
                    uint32_t callback=Read32(Pointer(info+0x34)+(command-0xB1)*4);
                    ((void (*)(struct MusicPlayer *,uint8_t *))(uintptr_t)callback)(player,t);
                    if(!t[0])break;
                } else t[1]=gMusicDurations[command-0x80];
            }
            if(t[0]) { --t[1];TickTrackModulation(t); }
        }
        Write32(p+0xC,Read32(p+0xC)+1);
        if(!active) { Write32(p+4,0x80000000u);goto done; }
        Write32(p+4,active);tempo=(uint32_t)Read16(p+0x22)-150;Write16(p+0x22,tempo);
    }
    uint8_t *t=Pointer(p+0x2C);
    for(unsigned i=0;i<p[8];++i,t+=0x50)if((t[0]&0x80) && (t[0]&15)) {
        CalculateTrackVolumePitch(player,t);
        for(uint8_t *c=Pointer(t+0x20);c;c=Pointer(c+0x34)) {
            if(!(c[0]&0xC7)) { UnlinkSoundChannel(c);continue; }
            unsigned id=c[1]&7;
            if(t[0]&3) { CalculateChannelVolumes(c,t);if(id)c[0x1D]|=1; }
            if(t[0]&12) {
                int32_t key=(int32_t)c[8]+(int8_t)t[8];if(key<0)key=0;
                uint32_t frequency;
                if(id) {
                    frequency=((uint32_t (*)(uint32_t,uint32_t,uint32_t))(uintptr_t)Read32(info+0x30))(id,key,t[9]);
                    Write32(c+0x20,frequency);c[0x1D]|=2;
                } else Write32(c+0x20,MidiKeyToPcmFrequency(Pointer(c+0x24),(uint8_t)key,t[9]));
            }
        }
        t[0]&=0xF0;
    }
done:Write32(p+0x34,SOUND_MAGIC);
}

/* 080375FC. Allocation prefers a free channel, then a releasing channel,
 * then lowest priority. Equal priorities prefer greater owner addresses;
 * exact ties select the later channel. Native32-bit address order is used. */
void m4aNote(uint32_t duration,struct MusicPlayer *player,uint8_t *t)
{
    uint8_t *info=gSoundInfo;t[4]=gMusicDurations[duration];uint8_t *cursor=Pointer(t+0x40);
    if(*cursor<128) {
        t[5]=*cursor++;
        if(*cursor<128) { t[6]=*cursor++;if(*cursor<128)t[4]+=*cursor++; }
        Write32(t+0x40,(uint32_t)(uintptr_t)cursor);
    }
    uint8_t *voice=t+0x24,type=voice[0],key=t[5],pan=0;
    if(type&0xC0) {
        unsigned index=key;if(type&0x40)index=Pointer(t+0x2C)[key];
        voice=Pointer(t+0x28)+index*12;if(voice[0]&0xC0)return;
        if(type&0x80) { if(voice[3]&0x80)pan=(uint8_t)((voice[3]-192)*2);key=voice[1]; }
    }
    unsigned priority=(unsigned)t[0x1D]+player->bytes[9];if(priority>255)priority=255;
    unsigned id=voice[0]&7;uint8_t *channel=0;
    if(id) {
        if(!Read32(info+0x1C))return;
        channel=Pointer(info+0x1C)+(id-1)*0x40;
        if((channel[0]&0xC7) && !(channel[0]&0x40)) {
            if(channel[0x13]>priority)return;
            if(channel[0x13]==priority && Read32(channel+0x2C)<(uint32_t)(uintptr_t)t)return;
        }
    } else {
        unsigned releasing=0,best_priority=priority;uint32_t owner=(uint32_t)(uintptr_t)t;
        for(unsigned i=0;i<info[6];++i) {
            uint8_t *candidate=info+0x50+i*0x40;
            if(!(candidate[0]&0xC7)) { channel=candidate;break; }
            if((candidate[0]&0x40) && !releasing) {
                releasing=1;best_priority=candidate[0x13];owner=Read32(candidate+0x2C);channel=candidate;continue;
            }
            if(!(candidate[0]&0x40) && releasing)continue;
            uint32_t candidate_owner=Read32(candidate+0x2C);
            if(candidate[0x13]<best_priority || (candidate[0x13]==best_priority && candidate_owner>=owner)) {
                best_priority=candidate[0x13];owner=candidate_owner;channel=candidate;
            }
        }
        if(!channel)return;
    }
    UnlinkSoundChannel(channel);Write32(channel+0x30,0);
    uint32_t first=Read32(t+0x20);Write32(channel+0x34,first);
    if(first)Write32((uint8_t *)(uintptr_t)first+0x30,(uint32_t)(uintptr_t)channel);
    Write32(t+0x20,(uint32_t)(uintptr_t)channel);Write32(channel+0x2C,(uint32_t)(uintptr_t)t);
    t[0x1C]=t[0x1B];if(t[0x1C])ResetModulation(t);CalculateTrackVolumePitch(player,t);
    Write32(channel+0x10,Read32(t+4));channel[0x13]=priority;channel[8]=key;channel[0x14]=pan;channel[1]=voice[0];
    Write32(channel+0x24,Read32(voice+4));Write32(channel+4,Read32(voice+8));Write16(channel+0xC,Read16(t+0x1E));
    CalculateChannelVolumes(channel,t);int32_t pitch=(int32_t)key+(int8_t)t[8];if(pitch<0)pitch=0;
    uint32_t frequency;
    if(id) {
        channel[0x1E]=voice[2];uint8_t sweep=voice[3];if((sweep&0x80) || !(sweep&0x70))sweep=8;channel[0x1F]=sweep;
        frequency=((uint32_t (*)(uint32_t,uint32_t,uint32_t))(uintptr_t)Read32(info+0x30))(id,pitch,t[9]);
    } else frequency=MidiKeyToPcmFrequency(Pointer(voice+4),(uint8_t)pitch,t[9]);
    Write32(channel+0x20,frequency);channel[0]=0x80;t[0]&=0xF0;
}
/* Initialized command domain B1..CE, including the patches in08037BEC. */
const MusicCommand gRecoveredMusicCommands[30]={
    FinishMusicTrack,MusicCommandGoto,MusicCommandPattern,MusicCommandPatternEnd,MusicCommandRepeat,
    FinishMusicTrack,FinishMusicTrack,FinishMusicTrack,MusicCommandMemory,MusicCommandPriority,
    MusicCommandTempo,MusicCommandKeyShift,MusicCommandVoice,MusicCommandVolume,MusicCommandPan,
    MusicCommandBend,MusicCommandBendRange,MusicCommandLfoSpeed,MusicCommandLfoDelay,MusicCommandModDepth,
    MusicCommandModType,FinishMusicTrack,FinishMusicTrack,MusicCommandTune,FinishMusicTrack,
    FinishMusicTrack,FinishMusicTrack,MusicCommandPort,MusicCommandExtended,MusicCommandEndTie
};
