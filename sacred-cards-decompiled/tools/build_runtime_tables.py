#!/usr/bin/env python3
"""Emit reviewed immutable ROM tables as C; native pointers stay native addresses."""
import argparse,hashlib,json,math,struct
from pathlib import Path
from rip_asset_tables import EXPECTED_SHA256
ROOT=Path(__file__).resolve().parents[1]
# Symbol, scalar format, literal native view address, dimensions.
TABLES=[
 ('gCardBaseAttack','H',0x886E6,[901]),('gCardBaseDefense','H',0x87FDC,[901]),('gCardCosts','I',0x88DF0,[901]),
 ('gCardAttributes','B',0x89C04,[901]),('gCardLevels','B',0x89F89,[901]),('gCardTypes','B',0x8A30E,[901]),
 ('gCardFrames','B',0x8A693,[901]),('gCardMetadata1A','B',0x8AD9D,[901]),('gCardMetadata1B','B',0x8AA18,[901]),
 ('gCardMetadata1C','B',0x8B122,[901]),('gMetadata1DBySpellIndex','B',0x8B4A7,[132]),
 ('gCardNameAddresses','I',0xD310E0,[901]),('gCardDescriptionAddresses','I',0xE94E78,[901]),
 ('gTerrainModifiers','B',0x8B533,[7,24]),('gInitialDeck','H',0xEBAF0,[40]),('gUntracedDeckPreset','H',0xB4690,[40]),
 ('gInitialCardCollection','B',0x8673C,[901]),('gInitialShopStock','B',0xC8304,[901]),
 ('gCardBasePrices','Q',0xD32D08,[901]),('gRewardSpecialCards','H',0xBA280,[50]),
 ('gLevelCapacityThresholds','H',0xB3EC0,[1000]),('gCardTypeClasses','b',0xD4BD48,[24]),
 ('gTributesByLevel','b',0xD4C6D0,[13]),('gCategoryRequirements','B',0xBA25C,[30]),('gSpellTargetClasses','b',0xD4BD60,[132]),
 ('gAttributeBeats','B',0xD4BD30,[12]),('gAttributeLosesTo','B',0xD4BD3C,[12]),('gOwnerDefeatMask','B',0xD4BD2C,[2]),
 ('gEquipmentCompatibility','B',0x175804,[33,113]),('gDuelBitMasks','H',0xD4BCFC,[8]),('gRitualRecipes','H',0xD36328,[30,4]),
 ('gGateGuardianMaterialPairs','H',0xFB8F4,[3,2]),('gEffectImmuneCards','H',0xD36678,[4]),('gEventBitMasks','B',0xD4F434,[8]),
 ('gDuelViewportOffsets','B',0xD4C2C1,[256]),('gOppositeSide','B',0xAAED0,[2]),('gScriptMotionWords','i',0xD4F124,[196]),
 ('gChoiceGlyphNext','I',0xD4EF4C,[56]),('gDialogueGlyphNext','I',0xD4F02C,[56]),('gChoiceLinePositions','B',0xD4EF48,[4]),
 ('gSmallFontBitmap','B',0xD2AAEA,[806*10]),('gLargeFontBitmap','B',0xD2CA66,[806*18]),
 ('gBlinkDurations','h',0x17578C,[30]),('gBlinkFrames','H',0x1757C8,[30]),
 ('gMouthDurations','h',0xD4F10C,[4]),('gMouthFrames','H',0xD4F114,[4]),
 ('gDirectionDX','b',0xD4F11C,[4]),('gDirectionDY','b',0xD4F120,[4]),
 ('gActorWalkPhases','B',0xD4C71C,[20]),('gActorSpecialFrames','B',0xD4C730,[256]),
 ('gActorFrameTileOffsets','H',0xFBB10,[18]),('gActorDestinationTiles','H',0xFBB34,[16]),
 ('gAudioCategories','B',0xD1278,[225,2]),('gSoundSamplesPerFrame','H',0x9DF6A0,[12]),('gSceneMusic','H',0xD4C87C,[58]),
 ('gSoundKeyScale','B',0x9DF5BC,[180]),('gSoundPitchTable','I',0x9DF670,[12]),('gMusicDurations','B',0x9DF7A0,[49]),
 ('gPsgKeyScale','B',0x9DF6B8,[132]),('gPsgPitchTable','h',0x9DF73C,[12]),('gPsgNoiseFrequencies','B',0x9DF754,[60]),
 ('gPsgWaveVolumes','B',0x9DF790,[16]),
 ('gCardPasswords','B',0xD4F43C,[902,8]),('gBonusPasswords','B',0xD5106C,[4,8]),
 ('gPasswordEnd','B',0xD5108C,[8]),('gPasswordSkip','B',0xD51094,[8]),
 ('gActorShadowTiles','B',0x2B16EC,[0x280]),('gActorShadowPalette','B',0x2B268C,[32]),
 ('gDialogueBlankLz','B',0x2B26AC,[0x1BC]),('gDialogueInitialMap','B',0x2B2868,[0x500]),('gDialoguePalette','B',0x2B3068,[32])]
TYPES={'B':'uint8_t','b':'int8_t','H':'uint16_t','h':'int16_t','I':'uint32_t','i':'int32_t','Q':'uint64_t'}
def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('rom',type=Path);a=ap.parse_args();rom=a.rom.read_bytes()
    if hashlib.sha256(rom).hexdigest()!=EXPECTED_SHA256:raise SystemExit('Unsupported ROM')
    lines=['/* Generated literal ROM views; addresses/overlaps retained in manifest. Not a native-layout link. */','#include <stdint.h>','#include "../../src/ai.h"','#include "../../src/audio.h"'];records=[]
    def array(name,ctype,at,dims,values):
        def render(v,d):
            if len(d)==1:return '{'+','.join(str(x) for x in v)+'}'
            stride=math.prod(d[1:]);return '{\n'+',\n'.join(render(v[i:i+stride],d[1:]) for i in range(0,len(v),stride))+'\n}'
        lines.append(f'const {ctype} {name}'+''.join(f'[{d}]' for d in dims)+'='+render(values,dims)+';')
        records.append(dict(symbol=name,address=f'0x{at+0x08000000:08X}',dimensions=dims,type=ctype))
    for name,fmt,at,dims in TABLES:
        array(name,TYPES[fmt],at,dims,struct.unpack_from('<'+fmt*math.prod(dims),rom,at))
    for name,at in [('gTrapDamageSpellIndices',0xD5113C),('gTrapHealingSpellIndices',0xD51148),('gTrapEquipmentSpellIndices',0xD51154),('gTrapRaigekiSpellIndices',0xD51198)]:
        vals=[]
        for i in range(256):
            v=struct.unpack_from('<H',rom,at+i*2)[0];vals.append(v)
            if v==65535:break
        else:raise ValueError('No trap-list terminator')
        array(name,'uint16_t',at,[len(vals)],vals)
    # Structures with the same declarations as their consuming translation units.
    lines+=['struct AiAttackTag { uint16_t opponent,card,tag,padding; };',
            'struct SceneVariantRule { int16_t scene,variant,flags[8],replacement,padding; };',
            'struct SceneMusicOverride { int16_t scene,variant,song; };']
    array('gAiActionDefinitions','struct AiAction',0xAAED4,[616],[f'{{{k},{{'+','.join(map(str,c))+'}}' for k,*c in struct.iter_unpack('<H6B',rom[0xAAED4:0xAC214])])
    array('gAiAttackTags','struct AiAttackTag',0xAC214,[11],['{'+','.join(map(str,r))+'}' for r in struct.iter_unpack('<4H',rom[0xAC214:0xAC26C])])
    vals=[]
    for i in range(256):
        r=struct.unpack_from('<12h',rom,0xFBB54+i*24);vals.append('{'+f'{r[0]},{r[1]},'+'{'+','.join(map(str,r[2:10]))+'},'+f'{r[10]},{r[11]}'+'}')
        if r[0]==-1:break
    array('gSceneVariantRules','struct SceneVariantRule',0xFBB54,[len(vals)],vals)
    vals=[]
    for i in range(256):
        r=struct.unpack_from('<3h',rom,0xD4C8F4+i*6);vals.append('{'+','.join(map(str,r))+'}')
        if r[0]==-1:break
    array('gSceneMusicOverrides','struct SceneMusicOverride',0xD4C8F4,[len(vals)],vals)
    for name,at in [('gDuelTerrainTiles',0xD4BE58),('gDuelTerrainMaps',0xD4BE74),('gDuelTerrainPalettes',0xD4BE90)]:
        array(name,'uint8_t *const',at,[7],[f'(const uint8_t *)0x{v:08X}' for v in struct.unpack_from('<7I',rom,at)])
    array('gOpponentRecords','uint8_t *const',0xD35C28,[200],[f'(const uint8_t *)0x{v:08X}' for v in struct.unpack_from('<200I',rom,0xD35C28)])
    array('gAsciiGlyphCodes','uint8_t *const',0xD35FB8,[96],[f'(const uint8_t *)0x{v:08X}' for v in struct.unpack_from('<96I',rom,0xD35FB8)])
    # Remaining scene/actor/portrait tables used by the recovered C. Pointer
    # targets remain native addresses, exactly as in the existing ROM views.
    for name,at,count in [('gActorSheets',0xD511A0,102),('gActorPalettes',0xD51338,102),
                          ('gSceneBackgroundTiles',0xD514D0,58),('gSceneBackgroundMaps',0xD515B8,58),
                          ('gSceneForegroundMaps',0xD516A0,58),('gSceneBackgroundPalettes',0xD51788,58),
                          ('gPortraitCompressedTiles',0xD4EDBC,33),('gPortraitPalettes',0xD4EE40,33)]:
        array(name,'uint8_t *const',at,[count],[f'(const uint8_t *)0x{v:08X}' for v in struct.unpack_from('<'+str(count)+'I',rom,at)])
    lines.append('struct PortraitFrame { uint8_t unknown,count;uint16_t reserved;const uint16_t (*oam)[4]; };')
    array('gPortraitParts','struct PortraitFrame *const *const',0xD4EEC4,[33],
          [f'(const struct PortraitFrame *const *)0x{v:08X}' for v in struct.unpack_from('<33I',rom,0xD4EEC4)])
    lines.append('struct SaveRegion { uint8_t *ram; uint32_t size; };')
    array('gSaveRegions','struct SaveRegion',0xD1490,[14],
          [f'{{(uint8_t *)0x{p:08X},{size}}}' for p,size in struct.iter_unpack('<II',rom[0xD1490:0xD1500])])
    array('gSongTable','struct SongEntry',0x9F42C0,[225],[f'{{(const uint8_t *)0x{ptr:08X},{player},{reserved}}}' for ptr,player,reserved in struct.iter_unpack('<IHH',rom[0x9F42C0:0x9F49C8])])
    array('gMusicPlayerTable','struct PlayerEntry',0x9F423C,[11],[f'{{(struct MusicPlayer *)0x{p:08X},(void *)0x{t:08X},{settings}}}' for p,t,settings in struct.iter_unpack('<III',rom[0x9F423C:0x9F42C0])])
    out=ROOT/'build/semantic';out.mkdir(parents=True,exist_ok=True);(out/'runtime_tables.c').write_text('\n'.join(lines)+'\n')
    (out/'runtime_tables.json').write_text(json.dumps(dict(rom_sha256=EXPECTED_SHA256,tables=records,notes=[
        'Some arrays are native index views, not physical object boundaries. Actor-special-frame view retains all byte indices including adjacent ROM data.',
        'Pointer-valued card name/description words remain native ROM addresses. The ROM and RAM layout is not linked.']),indent=2)+'\n')
    print(f'Generated {len(records)} immutable ROM table definitions')
if __name__=='__main__':main()
