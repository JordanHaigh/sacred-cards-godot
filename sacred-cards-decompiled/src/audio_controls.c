/* AY7E additional M4A controls, including unused song/player/track APIs.
 * Entry addresses378F4,37A2C..37BEC,37F64 and38934..38BA8. */
#include "audio.h"
extern const struct SongEntry gSongTable[];
extern const struct PlayerEntry gMusicPlayerTable[11];
extern void m4aMPlayStart(struct MusicPlayer *,const uint8_t *),m4aMPlayStop(struct MusicPlayer *);
void CallMusicCallbackB(void *);
/*080378F4/37B14*/
void m4aMPlayContinue(struct MusicPlayer *player)
{ if(Read32(player->bytes+0x34)==SOUND_MAGIC)Write32(player->bytes+4,Read32(player->bytes+4)&0x7FFFFFFF); }
/*08037A2C*/
void m4aSongNumStartOrContinue(uint16_t id)
{
    const struct SongEntry *e=&gSongTable[id];struct MusicPlayer *p=gMusicPlayerTable[e->player].player;uint32_t status=Read32(p->bytes+4);
    if(Pointer(p->bytes)!=e->header || !(status&0xFFFF))m4aMPlayStart(p,e->header);
    else if(status&0x80000000u)m4aMPlayContinue(p);
}
/*08037A80/37AB4*/
void m4aSongNumStop(uint16_t id)
{ const struct SongEntry *e=&gSongTable[id];struct MusicPlayer *p=gMusicPlayerTable[e->player].player;if(Pointer(p->bytes)==e->header)m4aMPlayStop(p); }
void m4aSongNumContinue(uint16_t id)
{ const struct SongEntry *e=&gSongTable[id];struct MusicPlayer *p=gMusicPlayerTable[e->player].player;if(Pointer(p->bytes)==e->header)m4aMPlayContinue(p); }
/*08037AE8/37B20*/
void m4aMPlayAllStop(void) { for(unsigned i=0;i<11;++i)m4aMPlayStop(gMusicPlayerTable[i].player); }
void m4aMPlayAllContinue(void) { for(unsigned i=0;i<11;++i)m4aMPlayContinue(gMusicPlayerTable[i].player); }
/*08037B5C/37B7C. Low fade bits choose temporary stop or fade-in.*/
void SetMusicTemporaryFade(struct MusicPlayer *player,uint16_t interval)
{ uint8_t *p=player->bytes;if(Read32(p+0x34)==SOUND_MAGIC) { Write16(p+0x26,interval);Write16(p+0x24,interval);Write16(p+0x28,0x101); } }
void SetMusicFadeIn(struct MusicPlayer *player,uint16_t interval)
{ uint8_t *p=player->bytes;if(Read32(p+0x34)==SOUND_MAGIC) { Write16(p+0x26,interval);Write16(p+0x24,interval);Write16(p+0x28,2);Write32(p+4,Read32(p+4)&0x7FFFFFFF); } }
/*08037BA4: only active tracks whose reset bit is set are reinitialized.*/
void ResetPendingMusicTracks(struct MusicPlayer *player)
{
    uint8_t *t=Pointer(player->bytes+0x2C);for(unsigned i=0;i<player->bytes[8];++i,t+=0x50)if((t[0]&0xC0)==0xC0) { CallMusicCallbackB(t);t[0]=0x80;t[0xF]=2;t[0x13]=64;t[0x19]=22;t[0x24]=1; }
}
/*08037F64. Stop all12 PCM channels and the optional four PSG oscillators.*/
void m4aSoundClear(void)
{
    uint8_t *p=gSoundInfo;if(Read32(p)!=SOUND_MAGIC)return;Write32(p,SOUND_MAGIC+1);
    for(unsigned i=0;i<12;++i)p[0x50+i*0x40]=0;
    uint8_t *psg=Pointer(p+0x1C);if(psg)for(unsigned i=1;i<=4;++i,psg+=0x40) { ((void (*)(uint8_t))(uintptr_t)Read32(p+0x2C))(i);psg[0]=0; }
    Write32(p,SOUND_MAGIC);
}
/*08038934*/
void SetMusicTempo(struct MusicPlayer *player,uint16_t scale)
{ uint8_t *p=player->bytes;if(Read32(p+0x34)==SOUND_MAGIC) { Write16(p+0x1E,scale);Write16(p+0x20,(int32_t)((uint32_t)Read16(p+0x1C)*scale)>>8); } }
/*08038AA0*/
void ResetTrackModulation(uint8_t *t) { t[0x1A]=t[0x16]=0;t[0]|=t[0x18]?3:12; }
/* Shared control shape3895C/389C4/38A38/38AC0/38B34. Mask bits select
 *active tracks. The player magic is busy for the duration of each change.*/
static void ChangeTracks(struct MusicPlayer *player,uint16_t mask,uint16_t value,uint8_t operation)
{
    uint8_t *p=player->bytes;if(Read32(p+0x34)!=SOUND_MAGIC)return;Write32(p+0x34,SOUND_MAGIC+1);
    uint8_t *t=Pointer(p+0x2C);uint32_t bit=1;
    for(unsigned i=0;i<p[8];++i,t+=0x50,bit<<=1)if((bit&mask) && (t[0]&0x80))switch(operation) {
    case 0:t[0x13]=value>>2;t[0]|=3;break;
    case 1:t[0xB]=(int16_t)value>>8;t[0xD]=value;t[0]|=12;break;
    case 2:t[0x15]=value;t[0]|=3;break;
    case 3:t[0x17]=value;if(!(uint8_t)value)ResetTrackModulation(t);break;
    case 4:t[0x19]=value;if(!(uint8_t)value)ResetTrackModulation(t);break;
    }
    Write32(p+0x34,SOUND_MAGIC);
}
void SetMusicVolume(struct MusicPlayer *p,uint16_t mask,uint16_t volume) { ChangeTracks(p,mask,volume,0); }
void SetMusicPitch(struct MusicPlayer *p,uint16_t mask,int16_t pitch) { ChangeTracks(p,mask,pitch,1); }
void SetMusicPan(struct MusicPlayer *p,uint16_t mask,int8_t pan) { ChangeTracks(p,mask,(uint8_t)pan,2); }
void SetMusicModDepth(struct MusicPlayer *p,uint16_t mask,uint8_t depth) { ChangeTracks(p,mask,depth,3); }
void SetMusicLfoSpeed(struct MusicPlayer *p,uint16_t mask,uint8_t speed) { ChangeTracks(p,mask,speed,4); }
/*08021EC0*/
void StopAllGameAudio(void) { m4aMPlayAllStop(); }
/*08037578: a separate empty entry in the original command support code.*/
void MusicUnusedNoop(void) {}
/*080379A8: public mixer tick wrapper.*/
extern void m4aSoundMain(void);
void m4aSoundMainTick(void) { m4aSoundMain(); }
/*08037D08/08037D1C: the callbacks are patched in RAM, so resolve on each
 * call rather than fixing them to the initial ROM table. Native arg is R0.*/
extern uint32_t gMusicCallbackA,gMusicCallbackB; /*02024828/0202482C*/
void CallMusicCallbackA(void *argument)
{ ((void (*)(void *))(uintptr_t)gMusicCallbackA)(argument); }
void CallMusicCallbackB(void *argument)
{ ((void (*)(void *))(uintptr_t)gMusicCallbackB)(argument); }
