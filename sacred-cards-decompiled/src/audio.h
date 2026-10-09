#ifndef AY7E_AUDIO_H
#define AY7E_AUDIO_H
#include <stdint.h>
struct MusicPlayer { uint8_t bytes[0x40]; };
struct SongEntry { const uint8_t *header;uint16_t player,reserved; };
struct PlayerEntry { struct MusicPlayer *player;void *tracks;uint32_t settings; };
extern uint8_t *gSoundInfo; /* pointer03007FF0 */
#define SOUND_MAGIC 0x68736D53u
static inline uint16_t Read16(const uint8_t *p) { return p[0]|(uint16_t)p[1]<<8; }
static inline uint32_t Read32(const uint8_t *p) { return p[0]|(uint32_t)p[1]<<8|(uint32_t)p[2]<<16|(uint32_t)p[3]<<24; }
static inline void Write16(uint8_t *p,uint16_t n) { p[0]=(uint8_t)n;p[1]=(uint8_t)(n>>8); }
static inline void Write32(uint8_t *p,uint32_t n) { for(unsigned i=0;i<4;++i)p[i]=(uint8_t)(n>>(i*8)); }
static inline uint8_t *Pointer(const uint8_t *p) { return (uint8_t *)(uintptr_t)Read32(p); }
void StopMusicTrack(struct MusicPlayer *,uint8_t *);
void UnlinkSoundChannel(uint8_t *);
void ClearMusicRecord(uint8_t *);
void FinishMusicTrack(struct MusicPlayer *,uint8_t *);
void TickMusicFade(struct MusicPlayer *);
void CalculateTrackVolumePitch(struct MusicPlayer *,uint8_t *);
void m4aMPlayMain(struct MusicPlayer *);
void m4aNote(uint32_t,struct MusicPlayer *,uint8_t *);
void TickPsgSound(void);
void StopPsgOscillator(uint8_t);
uint32_t MidiKeyToPsgFrequency(uint8_t,uint8_t,uint8_t);
typedef void (*MusicCommand)(struct MusicPlayer *,uint8_t *);
extern const MusicCommand gRecoveredMusicCommands[30];
#endif
