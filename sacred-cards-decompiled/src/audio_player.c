/* AY7E music-player routing, start/stop and fade setup. Raw byte records retain
 * native ARM layout. Mixer, sequencer and PSG bodies are in companion modules;
 * this does not establish hardware playback equivalence. */
#include "audio.h"
extern const struct SongEntry gSongTable[]; /* 089F42C0 */
extern const struct PlayerEntry gMusicPlayerTable[]; /* 089F423C */
extern uint8_t *gSoundInfo; /* pointer03007FF0 */
extern void SuspendSoundDma(void);
extern void SetSoundFrequency(uint32_t);
/* 08037588: stop PSG through the SoundInfo callback with channel ID in R0.
 * The draft misses this argument; assembly080375A2..375B0 retains it. */
void StopMusicTrack(struct MusicPlayer *player,uint8_t *track) {
    (void)player;if(!(track[0]&0x80))return;
    for(uint8_t *channel=Pointer(track+0x20);channel;channel=Pointer(channel+0x34)) {
        if(channel[0]) {
            unsigned id=channel[1]&7;
            if(id)((void (*)(uint32_t))(uintptr_t)Read32(gSoundInfo+0x2C))(id);
            channel[0]=0;
        }
        Write32(channel+0x2C,0);
    }
    Write32(track+0x20,0);
}
/* 08037ECC */
void SetSoundMode(uint32_t mode) {
    uint8_t *info=gSoundInfo;if(Read32(info)!=SOUND_MAGIC)return;
    Write32(info,SOUND_MAGIC+1);
    if(mode&255)info[5]=mode&127;
    if(mode&0xF00) { info[6]=(mode>>8)&15;for(unsigned i=0;i<12;++i)info[0x50+i*0x40]=0; }
    if(mode&0xF000)info[7]=(mode>>12)&15;
    if(mode&0xB00000) { volatile uint8_t *bias=(volatile uint8_t *)0x04000089;*bias=(*bias&0x3F)|(uint8_t)((mode&0x300000)>>14); }
    if(mode&0xF0000) { SuspendSoundDma();SetSoundFrequency(mode&0xF0000); }
    Write32(info,SOUND_MAGIC);
}
/* 080380E8 */
void m4aMPlayStart(struct MusicPlayer *player,const uint8_t *song) {
    uint8_t *p=player->bytes;if(Read32(p+0x34)!=SOUND_MAGIC)return;
    uint32_t status=Read32(p+4);uint8_t *tracks=Pointer(p+0x2C);
    if(p[0xB] && ((Read32(p)!=0 && (tracks[0]&0x40)) || ((status&0xFFFF)!=0 && !(status&0x80000000u))) && song[2]<p[9])return;
    Write32(p+0x34,SOUND_MAGIC+1);Write32(p+4,0);Write32(p,(uint32_t)(uintptr_t)song);
    Write32(p+0x30,Read32(song+4));p[9]=song[2];Write32(p+0xC,0);
    Write16(p+0x1C,150);Write16(p+0x20,150);Write16(p+0x1E,256);Write16(p+0x22,0);Write16(p+0x24,0);
    unsigned i=0;
    for(;i<song[0] && i<p[8];++i) {
        uint8_t *track=tracks+i*0x50;StopMusicTrack(player,track);track[0]=0xC0;Write32(track+0x20,0);Write32(track+0x40,Read32(song+8+i*4));
    }
    for(;i<p[8];++i) { uint8_t *track=tracks+i*0x50;StopMusicTrack(player,track);track[0]=0; }
    if(song[3]&0x80)SetSoundMode(song[3]);Write32(p+0x34,SOUND_MAGIC);
}
/* 080379B4 / 080379E0 */
void m4aSongNumStart(uint16_t id) {
    const struct SongEntry *entry=&gSongTable[id];m4aMPlayStart(gMusicPlayerTable[entry->player].player,entry->header);
}
void m4aSongNumStartOrChange(uint16_t id) {
    const struct SongEntry *entry=&gSongTable[id];struct MusicPlayer *p=gMusicPlayerTable[entry->player].player;
    uint32_t status=Read32(p->bytes+4);
    if(Pointer(p->bytes)!=entry->header || !(status&0xFFFF) || (status&0x80000000u))m4aMPlayStart(p,entry->header);
}
/* 080381CC */
void m4aMPlayStop(struct MusicPlayer *player) {
    uint8_t *p=player->bytes;if(Read32(p+0x34)!=SOUND_MAGIC)return;
    Write32(p+0x34,SOUND_MAGIC+1);Write32(p+4,Read32(p+4)|0x80000000u);
    unsigned count=p[8];uint8_t *track=Pointer(p+0x2C);
    for(unsigned i=0;i<count;++i,track+=0x50)StopMusicTrack(player,track);
    Write32(p+0x34,SOUND_MAGIC);
}
/* 08037910 via08037B4C. */
void SetMusicFade(struct MusicPlayer *player,uint16_t interval) {
    uint8_t *p=player->bytes;if(Read32(p+0x34)==SOUND_MAGIC) { Write16(p+0x26,interval);Write16(p+0x24,interval);Write16(p+0x28,256); }
}

/* Native mixer frequency/timer setup. Hardware register access and raster wait
 * are preserved; hardware scheduling still requires a GBA runtime. */
#include "gba_bios.h"
extern const uint16_t gSoundSamplesPerFrame[]; /* 089DF6A0 */
#define AUDIO_REG32(a) (*(volatile uint32_t *)(uintptr_t)(a))
#define AUDIO_REG16(a) (*(volatile uint16_t *)(uintptr_t)(a))
#define AUDIO_REG8(a) (*(volatile uint8_t *)(uintptr_t)(a))
/* 08037FB8 */
void SuspendSoundDma(void) {
    uint8_t *info=gSoundInfo;uint32_t magic=Read32(info);
    if(magic-SOUND_MAGIC>=2)return;
    Write32(info,magic+10);
    if(AUDIO_REG32(0x040000C4)&0x02000000)AUDIO_REG32(0x040000C4)=0x84400004;
    if(AUDIO_REG32(0x040000D0)&0x02000000)AUDIO_REG32(0x040000D0)=0x84400004;
    AUDIO_REG16(0x040000C6)=0x400;AUDIO_REG16(0x040000D2)=0x400;
    uint32_t zero=0;BiosCpuSet(&zero,info+0x350,0x05000318);
}
/* 08038034 */
void ResumeSoundDma(void) {
    uint8_t *info=gSoundInfo;uint32_t magic=Read32(info);
    if(magic==SOUND_MAGIC)return;
    AUDIO_REG16(0x040000C6)=0xB600;AUDIO_REG16(0x040000D2)=0xB600;
    info[4]=0;Write32(info,magic-10);
}
/* 08037E28. Native frequency table entries are nonzero. */
void SetSoundFrequency(uint32_t mode) {
    uint8_t *info=gSoundInfo;unsigned index=(mode>>16)&15;info[8]=index;
    uint32_t count=gSoundSamplesPerFrame[index-1];Write32(info+0x10,count);info[0xB]=1584/count;
    uint32_t rate=(count*0x91D1Bu+5000)/10000;Write32(info+0x14,rate);Write32(info+0x18,(0x1000000u/rate+1)>>1);
    AUDIO_REG16(0x04000102)=0;AUDIO_REG16(0x04000100)=(uint16_t)-(0x44940u/count);
    ResumeSoundDma();
    while(AUDIO_REG8(0x04000006)==159) {}
    while(AUDIO_REG8(0x04000006)!=159) {}
    AUDIO_REG16(0x04000102)=0x80;
}

extern uint32_t gSoundCommandCallbacks[36]; /* 020247A0 */
extern uint8_t gSoundInfoStorage[0xFB0],gPsgChannels[0x100],gMusicSharedMemory[16]; /* 020237F0 / 02024830 / 02024B70 */
static void EmptySoundCallback(void) {} /* 08038E20 */
#define CALLBACK(f) ((uint32_t)(uintptr_t)(f))
/* 08037110 command-table copy expressed using recovered functions. The ROM
 * table source always passes0803712A's source-address check. */
static void InitializeSoundCallbacks(void)
{
    for(unsigned i=0;i<30;++i)gSoundCommandCallbacks[i]=CALLBACK(gRecoveredMusicCommands[i]);
    gSoundCommandCallbacks[8]=gSoundCommandCallbacks[28]=CALLBACK(FinishMusicTrack);
    gSoundCommandCallbacks[30]=CALLBACK(SetSoundFrequency);gSoundCommandCallbacks[31]=CALLBACK(StopMusicTrack);
    gSoundCommandCallbacks[32]=CALLBACK(TickMusicFade);gSoundCommandCallbacks[33]=CALLBACK(CalculateTrackVolumePitch);
    gSoundCommandCallbacks[34]=CALLBACK(UnlinkSoundChannel);gSoundCommandCallbacks[35]=CALLBACK(ClearMusicRecord);
}
/* 08037D30. Intermediate magic values during timer setup are retained. */
void InitializeSoundInfo(uint8_t *info)
{
    Write32(info,0);
    if(AUDIO_REG32(0x040000C4)&0x02000000)AUDIO_REG32(0x040000C4)=0x84400004;
    if(AUDIO_REG32(0x040000D0)&0x02000000)AUDIO_REG32(0x040000D0)=0x84400004;
    AUDIO_REG16(0x040000C6)=0x400;AUDIO_REG16(0x040000D2)=0x400;
    AUDIO_REG16(0x04000084)=0x8F;AUDIO_REG16(0x04000082)=0xA90E;
    AUDIO_REG8(0x04000089)=(AUDIO_REG8(0x04000089)&0x3F)|0x40;
    AUDIO_REG32(0x040000BC)=(uint32_t)(uintptr_t)(info+0x350);AUDIO_REG32(0x040000C0)=0x040000A0;
    AUDIO_REG32(0x040000C8)=(uint32_t)(uintptr_t)(info+0x980);AUDIO_REG32(0x040000CC)=0x040000A4;
    gSoundInfo=info;uint32_t zero=0;BiosCpuSet(&zero,info,0x050003EC);info[6]=8;info[7]=15;
    Write32(info+0x38,CALLBACK(m4aNote));
    Write32(info+0x28,CALLBACK(EmptySoundCallback));Write32(info+0x2C,CALLBACK(EmptySoundCallback));
    Write32(info+0x30,CALLBACK(EmptySoundCallback));Write32(info+0x3C,CALLBACK(EmptySoundCallback));
    InitializeSoundCallbacks();Write32(info+0x34,(uint32_t)(uintptr_t)gSoundCommandCallbacks);
    SetSoundFrequency(0x40000);Write32(info,SOUND_MAGIC);
}
/* 08037BEC. The hardware reset happens before the magic check. */
void InitializePsgChannels(uint8_t *channels)
{
    uint8_t *info=gSoundInfo;
    AUDIO_REG16(0x04000084)=0x8F;AUDIO_REG16(0x04000080)=0;
    AUDIO_REG8(0x04000063)=8;AUDIO_REG8(0x04000069)=8;AUDIO_REG8(0x04000079)=8;
    AUDIO_REG8(0x04000065)=0x80;AUDIO_REG8(0x0400006D)=0x80;AUDIO_REG8(0x0400007D)=0x80;
    AUDIO_REG8(0x04000070)=0;AUDIO_REG8(0x04000080)=0x77;
    if(Read32(info)!=SOUND_MAGIC)return;
    Write32(info,SOUND_MAGIC+1);
    const unsigned patches[]={8,17,19,28,29};
    for(unsigned i=0;i<5;++i)gSoundCommandCallbacks[patches[i]]=CALLBACK(gRecoveredMusicCommands[patches[i]]);
    gSoundCommandCallbacks[30]=CALLBACK(SetSoundFrequency);gSoundCommandCallbacks[31]=CALLBACK(StopMusicTrack);
    gSoundCommandCallbacks[32]=CALLBACK(TickMusicFade);gSoundCommandCallbacks[33]=CALLBACK(CalculateTrackVolumePitch);
    Write32(info+0x1C,(uint32_t)(uintptr_t)channels);Write32(info+0x28,CALLBACK(TickPsgSound));
    Write32(info+0x2C,CALLBACK(StopPsgOscillator));Write32(info+0x30,CALLBACK(MidiKeyToPsgFrequency));info[0xC]=0;
    uint32_t zero=0;BiosCpuSet(&zero,channels,0x05000040);
    for(unsigned i=0;i<4;++i) { channels[i*0x40+1]=i+1;channels[i*0x40+0x1C]=0x11u<<i; }
    Write32(info,SOUND_MAGIC);
}
/* 08038070 */
void OpenMusicPlayer(struct MusicPlayer *player,uint8_t *tracks,uint8_t count)
{
    if(!count)return;if(count>16)count=16;uint8_t *info=gSoundInfo,*p=player->bytes;
    if(Read32(info)!=SOUND_MAGIC)return;
    Write32(info,SOUND_MAGIC+1);ClearMusicRecord(p);Write32(p+0x2C,(uint32_t)(uintptr_t)tracks);p[8]=count;
    Write32(p+4,0x80000000u);for(unsigned i=0;i<count;++i)tracks[i*0x50]=0;
    if(Read32(info+0x20)) { Write32(p+0x38,Read32(info+0x20));Write32(p+0x3C,Read32(info+0x24));Write32(info+0x20,0); }
    Write32(info+0x24,(uint32_t)(uintptr_t)player);Write32(info+0x20,CALLBACK(m4aMPlayMain));
    Write32(info,SOUND_MAGIC);Write32(p+0x34,SOUND_MAGIC);
}
/* 08037930. Preserve the native mixer copy even though audio_mixer.c also
 * recovers its semantics. Native RAM/ROM linking remains a separate task. */
void m4aSoundInit(void)
{
    BiosCpuSet((const void *)0x08036D04,(void *)0x03000000,0x04000100);
    InitializeSoundInfo(gSoundInfoStorage);InitializePsgChannels(gPsgChannels);SetSoundMode(0x97FC00);
    for(unsigned i=0;i<11;++i) {
        const struct PlayerEntry *e=gMusicPlayerTable+i;OpenMusicPlayer(e->player,e->tracks,(uint8_t)e->settings);
        e->player->bytes[0xB]=(uint8_t)(e->settings>>16);Write32(e->player->bytes+0x18,(uint32_t)(uintptr_t)gMusicSharedMemory);
    }
}
/* 080372D4, called at VBlank. The unsigned magic delta accepts busy=magic+1. */
void m4aSoundVSync(void)
{
    uint8_t *info=gSoundInfo;if(Read32(info)-SOUND_MAGIC>1)return;
    int countdown=(int)info[4]-1;info[4]=(uint8_t)countdown;if(countdown>0)return;
    info[4]=info[0xB];
    if(AUDIO_REG32(0x040000C4)&0x02000000)AUDIO_REG32(0x040000C4)=0x84400004;
    if(AUDIO_REG32(0x040000D0)&0x02000000)AUDIO_REG32(0x040000D0)=0x84400004;
    AUDIO_REG16(0x040000C6)=0x400;AUDIO_REG16(0x040000D2)=0x400;
    AUDIO_REG16(0x040000C6)=0xB600;AUDIO_REG16(0x040000D2)=0xB600;
}
