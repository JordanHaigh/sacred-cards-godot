#!/usr/bin/env python3
"""Export native animation descriptors and code-backed playback contracts.

This decodes static ROM data. Timelines are derived from the maintained native
recovery; no recovered implementation or emulator is executed here.
"""
import argparse,hashlib,json,re,struct
from pathlib import Path
from rip_asset_tables import EXPECTED_SHA256
ROOT=Path(__file__).resolve().parents[1]
BASE=0x08000000
def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('rom',type=Path);a=ap.parse_args();rom=a.rom.read_bytes()
    if hashlib.sha256(rom).hexdigest()!=EXPECTED_SHA256:raise SystemExit('Unsupported ROM')
    out=ROOT/'build/assets/animations';out.mkdir(parents=True,exist_ok=True);files=[]
    def raw(name,at,n):
        data=rom[at:at+n];(out/name).write_bytes(data)
        files.append(dict(file=name,address=f'0x{at+BASE:08X}',size=n,sha256=hashlib.sha256(data).hexdigest()))
        return name
    def words(at,n,signed=False):return list(struct.unpack_from('<'+str(n)+('h' if signed else 'H'),rom,at))
    def u32(at):return struct.unpack_from('<I',rom,at)[0]
    def decode_object(row):
        a0,a1,a2,pad=row;shape=a0>>14;size=a1>>14;affine=bool(a0&0x100)
        dimensions=(((8,8),(16,16),(32,32),(64,64)),
                    ((16,8),(32,8),(32,16),(64,32)),
                    ((8,16),(8,32),(16,32),(32,64)))
        return dict(y=a0&255,x=a1&511,shape=shape,size=size,
                    dimensions=list(dimensions[shape][size]) if shape<3 else None,
                    affine=affine,hidden=bool(a0&0x200) if not affine else False,
                    affine_double_size=bool(a0&0x200) if affine else False,
                    affine_matrix_index=(a1>>9)&31 if affine else None,
                    horizontal_flip=bool(a1&0x1000) if not affine else None,
                    vertical_flip=bool(a1&0x2000) if not affine else None,
                    object_mode=(a0>>10)&3,mosaic=bool(a0&0x1000),color_depth=8 if a0&0x2000 else 4,
                    tile_index=a2&1023,priority=(a2>>10)&3,palette_bank=a2>>12,affine_parameter_raw=pad)
    def descriptor(at,name,index):
        duration,count,unused,ptr=struct.unpack_from('<BBHI',rom,at)
        if not (BASE<=ptr<BASE+len(rom)) or count>128:raise ValueError('Invalid descriptor '+hex(at))
        objects=[list(r) for r in struct.iter_unpack('<4H',rom[ptr-BASE:ptr-BASE+count*8])]
        return dict(index=index,address=f'0x{at+BASE:08X}',duration_field=duration,count=count,reserved=unused,
                    objects_address=f'0x{ptr:08X}',objects=objects,decoded_objects=[decode_object(r) for r in objects],
                    oam_file=raw(name+f'-{index:02d}.oam',ptr-BASE,count*8))
    def sequence(at,name,rule):
        frames=[]
        for i in range(128):
            pos=at+i*8;duration,count,unused,ptr=struct.unpack_from('<BBHI',rom,pos)
            if (rule=='zero_duration' and not duration) or (rule=='repeated_pointer' and frames and ptr==int(frames[-1]['objects_address'],16)):break
            if rule=='repeated_first_tile' and frames:
                tile=struct.unpack_from('<H',rom,ptr-BASE+4)[0]&1023
                if tile==frames[-1]['objects'][0][2]&1023:break
            frames.append(descriptor(pos,name,i))
        else:raise ValueError('No sequence terminator '+name)
        return dict(id=name,address=f'0x{at+BASE:08X}',frames=frames,termination=rule,
                    descriptors_file=raw(name+'.frames.bin',at,(len(frames)+1)*8))
    hit=sequence(0xAC2A0,'battle-hit','repeated_pointer')
    attribute=sequence(0xAC390,'battle-attribute','zero_duration')
    destruction=sequence(0xAC26C,'battle-destruction','repeated_first_tile')
    for s in (hit,attribute):
        s.update(ticks_per_descriptor=2,draw_ticks=2*len(s['frames']),
                 duration_field_used=False,setup_ticks=1,cleanup_ticks=1)
    attribute['affine_matrices']=[words(0xB1E20+i*8,4,True) for i in range(16)]
    attribute['affine_file']=raw('battle-attribute.affine.i16',0xB1E20,128)
    attribute['affine_rule']='Initialize matrix 0; after each draw/upload tick increment byte tick and write that matrix for the next upload. The final matrix write is not an additional draw tick.'
    source=(ROOT/'src/battle_animation.c').read_text()
    flagbody=re.search(r'flags\[18\]\[2\]=\{(.*?)\n    \};',source,re.S).group(1)
    flags=[[int(v,0) for v in row.split(',')] for row in re.findall(r'\{([^{}]+)\}',flagbody)]
    battle=dict(source='src/battle_animation.c',native_entry='0x08012358',result_flags=flags,
                flag_bits={'card_visible':1,'hit':2,'destroy':4,'show_attack':8,'show_defense':16,'show_attribute':32,'life_points':64,'attribute_hit':128},
                order=[1,0],left_side=0,initial_hold_ticks=15,hit_followup_hold_ticks=6,both_sides_gap_ticks=30,
                extra_final_hold_results=[5,8],extra_final_hold_ticks=30,
                side_gate='A side runs only if its flags & 6 is nonzero; then hit, destruction and LP run in that order.',
                setup='Blank-display callback tick, upload staged backgrounds, show-display callback tick, then initial hold.',
                hit=hit,attribute_hit=attribute,
                destruction=dict(destruction,source='src/battle_animation.c:InitializeDestruction/StepDestruction/DrawDestruction',
                    steps=list(range(1,18)),ticks_per_step=3,draw_ticks=51,setup_ticks=1,cleanup_ticks=1,
                    particles=12,layers_per_particle=5,oam_planes=[0,60],
                    alpha_cycle=list(rom[0xAC29C:0xAC29F]),seeds=list(struct.unpack_from('<4I',rom,0xD35750)),
                    rng_rule='Draw one global random seed selector in [0,3], save the post-draw RNG, use the selected particle seed and restore the saved RNG.',
                    palette_rule='At each step subtract 2 from each RGB555 component with values below 3 becoming zero; retain bit15.',
                    descriptor_rule='Particle frame timers use duration_field; repeat on adjacent equal low-10-bit OAM tile index. Particle delays, lifetimes, horizontal flips and offsets are procedural.'),
                life_points=dict(native_entry='0x08013464',initial_hold_ticks=15,final_damage_hold_ticks=30,setup_ticks=1,cleanup_ticks=1,
                    decrement_per_tick=72,maximum_decrement_ticks=10000,sound=71,sound_tick_modulus=2,
                    rule='Only decreasing LP animates; subtract 72 or clamp to final LP. Damage ticks = min(10000, ceil((initial-final)/72)). Final 30-tick hold occurs only for a decrease.'),
                sounds={'hit':68,'attribute_hit':69,'destruction':70,'life_points':71},
                dormant_jitter=dict(native_entry='0x080131EC',radii=list(rom[0xD35948:0xD3594C]),
                    note='Recovered helper uses two RNG draws but the stock hit loop does not call it. Do not add camera shake to that loop.'))
    portraits=json.loads((ROOT/'build/assets/portraits/manifest.json').read_text())
    p=portraits['animation_tables']
    portrait=dict(source='src/script_runtime.c',scheduler='One update per RunSceneScript loop before dispatch and WaitForFrame; portrait 0 bypasses animation.',
                  initial_state=dict(blink_index=29,blink_ticks=1,mouth_index=3,mouth_ticks=1,speaking=0),
                  blink=[dict(table_index=i,part=0,frame=p['blink_frames'][i],hold_ticks=p['blink_durations'][i]*4) for i in range(29,-1,-1)],
                  speaking_mouth=[dict(table_index=i,part=1,frame=p['mouth_frames'][i],hold_ticks=p['mouth_durations'][i]) for i in range(3,-1,-1)],
                  silent_mouth=[dict(table_index=i,part=1,frame=p['mouth_frames'][i],hold_ticks=p['mouth_durations'][i]*4) for i in range(3,-1,-1)],
                  silent_rule='After index0 is applied, set index0 and ticks1; keep applying closed frame each scheduler tick. Speaking changes the multiplier at the next timer expiry.',
                  assets='../portraits/manifest.json',parts='Part2 is the static portrait body; optional part3 selection comes from portrait_flags in ComposePortraitPart.')
    offsets=words(0xFBB10,18);walk=list(rom[0xD4C71C:0xD4C730]);run=list(rom[0xD4C737:0xD4C751])
    actors=dict(sources=['src/script_actors.c','src/overworld.c','src/scene_graphics.c'],assets='../actors/manifest.json',
                directions=list(range(4)),frame_tile_offsets=offsets,walk_phases=walk,run_phases=run,
                special_pose_bytes=list(rom[0xD4C730:0xD4C737]),frame_rule='direction*3 + phase[phase_index]',
                normal_walk=dict(initial_phase=19,cycle=list(range(19,-1,-1)),ticks_per_update=1,order='Draw selected frame, then decrement; zero/out-of-range phase wraps to19.'),
                script_walk=dict(initial_phase=19,cycle=list(range(18,-1,-1))+[19],ticks_per_coordinate_step=2,
                    order='Move one coordinate, update height, decrement phase, select frame, perform two scene frame/upload cycles; finishing sets phase19 and performs one final cycle.'),
                running=dict(player_sheet=89,follower_sheet=90,initial_phase_from_scene=19,cycle=list(range(25,-1,-1)),ticks_per_update=1,
                    order='Draw selected phase then decrement; zero phase wraps to25. Walking phase is reused on entry.'),
                note='Time is measured in caller update ticks. Menus, scripts and movement can suspend or replace the normal overworld scheduler.')
    name_sequences=[sequence(0x77E48,'name-arrow-up','zero_duration'),sequence(0x77E70,'name-arrow-down','zero_duration')]
    for i in range(6):name_sequences.append(sequence(u32(0xD30C28+(i+15)*4)-BASE,f'name-focused-page-{i}','zero_duration'))
    name_sequences.append(sequence(0x77EF8,'name-focused-extended','zero_duration'))
    for s in name_sequences:
        s['steady_hold_ticks']=[f['duration_field']+1 for f in s['frames']]
    names=dict(source='src/name_entry.c',sequences=name_sequences,
               scheduler='AdvanceFrame compares timer to duration before incrementing; on equality reset timer, advance index and wrap at zero duration. It returns the new descriptor to draw.',
               startup_rule='With zero timer/index, the first descriptor is drawn duration_field times before the first transition. Later descriptors have duration_field+1 draws. The initial screen draw also advances these timers.',
               arrow_rule='Only the up-arrow table advances timer7/frame8; down-arrow uses that same frame8. Visibility follows scroll position and page length.',
               focused_rule='Advance timer5/frame6 only while focus==1; phase is shared across keyboard page changes.',
               affine=dict(initial_scale_8_8=256,step=16,upper=512,cycle_lower=320,
                   rule='Draw using current matrix, then advance both scales. First expansion starts at256; subsequent cycles oscillate320..512. Matrix uses signed 65536/scale and sine/cosine fixed multiplication truncated toward zero.'),
               fade=dict(pre_hold_ticks=30,fade_loop_ticks=150,brightness_step_ticks=7,maximum_brightness=16))
    title=dict(source='src/title_screen.c',alpha_table=words(0xD4BC00,30),pulse_ticks_per_entry=1,
               pulse_rule='Use (alpha[phase]&15)|0x1000, phase0..29. Native timer resets to zero, so each pulse call advances one entry.',
               fade=dict(brightness_updates=16,ticks_between_updates=4,total_ticks=61),
               static_sprites=[descriptor(0xD3560+i*16,'title-choice',i) for i in range(6)],
               note='Title sprites are selection-dependent compositions, not a sequential animation. Main menu iterations also draw gameplay RNG.')
    other=dict(intro=dict(source='src/intro.c',hold_ticks=120,fade_levels=16,ticks_per_level=4,fade_ticks=64,
                         note='Copyright holds before the two logo fade/hold/fade sequences; each screen callback also consumes a tick.'),
               credits=dict(source='src/credits.c',page_durations=words(0xD30558,6),page_layouts=list(rom[0xD30544:0xD30558]),
                    page_period_ticks=[n+1 for n in words(0xD30558,6)],
                    scroll_step_ticks=3,final_scroll_phase=0x760,background_load_phases=[2+i*256 for i in range(6)],
                    upload_modulus=0x600,upload_phases={'bank0':0x300,'bank1':0,'maps':[3,0x303]},
                    backdrop_rule='Load at each matching phase update, including repeated updates while phase is held. Increment scroll phase only when frame counter modulo3 is zero, until phase0x760. The native frame counter wraps at16 bits.',
                    text_rule='Page duration table contains an inclusive timer threshold: a complete page period is threshold+1 calls. Tick0 renders headers, ticks1..5 render rows, tick6 uploads. Alpha rises on ticks7..199 and falls on200..299 except for final page19.',
                    note='20 text chapters; language5 skips17/18; chapter19 persists. Text rendering/upload and alpha changes follow StepCreditsText; sequence never returns.'),
               city=dict(source='src/city_map.c',selection='Static two-object composition; no descriptor animation timer.',fade_pre_hold=15,fade_post_hold=15,fade_step_ticks=2,fade_ticks=32,total_fade_ticks=62),
               duel_text=dict(source='src/duel_text.c',prompt_cycle_ticks=30,prompt_visible_tick=0,prompt_hidden_tick=15,
                    note='One text VM step and frame upload per tick. Name and number substitutions have their own states.'))
    result=dict(rom_sha256=EXPECTED_SHA256,kind='Static native animation playback contracts',asset_base='animations/',
                time_unit='GBA VBlank/update ticks, with scheduler boundaries stated per family',battle=battle,portraits=portrait,actors=actors,
                name_entry=names,title=title,other_sequences=other,files=files,
                instruction_review=dict(document='docs/animation_audit.md',method='Static Thumb instruction inspection; no implementation execution or emulator comparison.',
                    battle=['0x08012358','0x080127D8','0x08012928','0x08012964','0x080129EC','0x08012A74','0x08012B3C','0x08012B70','0x08012C74','0x08012DD0','0x08012DDC','0x08013090','0x080130F0','0x080131EC','0x080132D0','0x0801331C','0x08013330','0x08013420','0x08013464','0x0801351C','0x0801353C','0x0801376C','0x080137C4','0x08013828','0x0801384C','0x08013978','0x08013B24','0x08006AA0','0x08006B08'],
                    portraits=['0x08032744','0x080327AC'],
                    actors=['0x080305A4','0x08030620','0x08030914','0x08030940','0x08030960','0x08030974','0x08032944'],
                    name_title=['0x080027DC','0x08002BE4','0x08002E24','0x08002ECC','0x08022424','0x080227B8'],
                    other_sequences=['0x08019534','0x08019598','0x080195E8','0x08000224','0x0800038C','0x0800053C','0x08000CF8','0x0800116C','0x08025098','0x080253F4','0x08031D84']),
                notes=['Frame/OAM data is decoded from original ROM. Timing contracts are derived from recovered source and instruction review, not execution comparison.',
                       'Do not play every exported descriptor as a frame: repeated-pointer and zero-duration records have distinct termination rules.',
                       'OAM attributes retain wrapping coordinates, OBJ mapping, priority, palette, blend and affine bits; flattened sprite sheets do not encode these.',
                       'Procedural particles, dynamic LP digits, scene transitions and menu selection require the accompanying recovered code.'])
    (out/'manifest.json').write_text(json.dumps(result,indent=2)+'\n')
    runtime=ROOT/'build/assets/runtime';(runtime/'animations.json').write_text(json.dumps(result,indent=2)+'\n')
    print(f'Exported {len(files)} animation source files; battle, portrait, actor, name/title and screen timing contracts')
if __name__=='__main__':main()
