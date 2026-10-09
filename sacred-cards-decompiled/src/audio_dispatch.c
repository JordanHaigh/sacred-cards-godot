/* Semantic reconstruction from AY7E Thumb 0x08021EB0 and 0x08021E50.
 * Dependencies name ROM tables and driver functions; they are not yet linked.
 * Original code assumes valid IDs. Not compiler-matched or execution-compared.
 */
#include <stdint.h>

struct MusicPlayer;
extern const uint8_t gAudioCategories[225][2]; /* ROM 0x080D1278 */
extern struct MusicPlayer gMusicPlayer;       /* RAM 0x020249F0 */
extern void m4aSongNumStart(uint16_t song);    /* Thumb 0x080379B4 */
extern void m4aSongNumStartOrChange(uint16_t song); /* Thumb 0x080379E0 */
extern void m4aMPlayStop(struct MusicPlayer *player); /* Thumb 0x080381CC */

uint8_t GetAudioCategory(uint32_t value)
{
    return gAudioCategories[(uint16_t)value][0];
}

void PlayGameAudio(uint32_t value)
{
    uint16_t song = (uint16_t)value;
    switch (GetAudioCategory(song)) {
    case 1:
    case 5:
        m4aSongNumStartOrChange(song);
        break;
    case 2:
    case 3:
        m4aSongNumStart(song);
        break;
    case 4:
        m4aMPlayStop(&gMusicPlayer);
        break;
    default:
        break;
    }
}

/* Thumb 0x08031144 selects an override before the scene default. */
struct SceneMusicOverride { int16_t scene, variant, song; };
extern const struct SceneMusicOverride gSceneMusicOverrides[]; /* 0x08D4C8F4 */
extern const uint16_t gSceneMusic[58]; /* 0x08D4C87C */

void PlaySceneMusic(uint16_t scene, uint16_t variant)
{
    for (const struct SceneMusicOverride *row = gSceneMusicOverrides;
         row->scene != -1; ++row) {
        if (row->scene == scene && row->variant == variant) {
            PlayGameAudio((uint32_t)(int32_t)row->song);
            return;
        }
    }
    PlayGameAudio(gSceneMusic[scene]);
}

extern struct MusicPlayer gEffectMusicPlayer; /* 02024B80 */
extern void SetMusicFade(struct MusicPlayer *,uint16_t);
/* 08021ECC: native calls the SAME player twice, intentionally preserved. */
void StopEffectMusicPlayer(void) { m4aMPlayStop(&gEffectMusicPlayer);m4aMPlayStop(&gEffectMusicPlayer); }
/* 08021F10 */
void FadeGameMusic(uint16_t interval) { SetMusicFade(&gMusicPlayer,interval); }
