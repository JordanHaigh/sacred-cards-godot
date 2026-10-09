#!/usr/bin/env python3
"""AY7E MP2K extraction: source data, PCM samples, WAV, MIDI and SoundFont."""
import argparse
import concurrent.futures
import csv
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess
import wave
from rip_asset_tables import EXPECTED_SHA256

ROOT = Path(__file__).resolve().parents[1]
TABLE, COUNT = 0x9F42C0, 225


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('rom', type=Path)
    ap.add_argument('--out', type=Path, default=Path('build/assets/audio'))
    ap.add_argument('--jobs', type=int, default=4)
    ap.add_argument('--reuse-converted', action='store_true', help='Reuse successful conversions from the existing manifest')
    ap.add_argument('--raw-only', action='store_true', help='Skip external WAV/MIDI/SF2 converters')
    args = ap.parse_args()
    rom_path = args.rom.resolve()
    rom = rom_path.read_bytes()
    if hashlib.sha256(rom).hexdigest() != EXPECTED_SHA256:
        raise SystemExit('Unsupported ROM')
    out = args.out.resolve()
    if args.raw_only and (out/'manifest.json').exists():
        existing=json.loads((out/'manifest.json').read_text())
        if existing.get('rom_sha256')==EXPECTED_SHA256 and any('wav' in s for s in existing.get('slots',[])):
            print('Preserving existing rendered audio export; use rip-audio to regenerate it')
            return
    for name in ['raw', 'samples', 'music', 'effects', 'midi', 'logs']:
        (out / name).mkdir(parents=True, exist_ok=True)
    previous = {}
    if args.reuse_converted:
        previous = json.loads((out/'manifest.json').read_text())
        if previous['rom_sha256'] != EXPECTED_SHA256 or previous['errors'] or previous['render']['revision'] != 'd209cce0449edfa61bbf15a9d22735ddfe09dd4f':
            raise SystemExit('Existing conversion does not match this extraction')
    files = []

    def save(name, start, size):
        data = rom[start:start+size]
        if len(data) != size: raise ValueError('ROM extent out of range')
        (out / name).write_bytes(data)
        files.append({'file': name, 'rom_offset': f'0x{start:X}', 'size': size,
                      'sha256': hashlib.sha256(data).hexdigest()})
        return name

    save('raw/audio-data-region.bin', 0x9DF52C, 0xD2A6E4-0x9DF52C)
    save('raw/song-table.bin', TABLE, COUNT*8)
    save('raw/player-table.bin', 0x9F423C, 11*12)
    save('raw/action-categories.bin', 0xD1278, COUNT*2)
    save('raw/scene-music.u16', 0xD4C87C, 58*2)
    save('raw/scene-music-overrides.bin', 0xD4C8F4, 28*6)
    scene_music = list(struct.unpack_from('<58H',rom,0xD4C87C))
    overrides = [{'scene':a,'variant':b,'song_id':c} for a,b,c in
                 struct.iter_unpack('<hhh',rom[0xD4C8F4:0xD4C8F4+27*6])]
    # Exact local range preserves definitions, key maps and PSG wave patterns,
    # including definitions that may not be reached during normal playback.
    save('raw/instrument-region.bin', 0x9DF52C, 0x9F423C-0x9DF52C)
    slots = []
    for i in range(COUNT):
        pointer, player, player2 = struct.unpack_from('<IHH', rom, TABLE+8*i)
        pos = pointer-0x08000000
        n, blocks, priority, reverb = rom[pos:pos+4]
        bank = struct.unpack_from('<I', rom, pos+4)[0]-0x08000000 if n else None
        tracks = list(struct.unpack_from('<'+'I'*n, rom, pos+8)) if n else []
        row = {'id': i, 'header_rom_offset': f'0x{pos:X}', 'player': player,
               'player2': player2, 'action_category': rom[0xD1278+i*2], 'tracks': n, 'blocks': blocks, 'priority': priority,
               'reverb': reverb, 'kind': 'empty' if not n else ('music' if player==0 else 'effects'),
               'bank_rom_offset': f'0x{bank:X}' if bank is not None else None,
               'track_rom_offsets': [f'0x{t-0x08000000:X}' for t in tracks]}
        row['raw_header'] = save(f'raw/{i:03d}.header.bin', pos, 8+4*n)
        if n:
            # This ROM places each sequence before its header, including local patterns.
            start = min(tracks)-0x08000000
            if not 0xCF0000 <= start < pos < 0xD2B000: raise ValueError('Unexpected sequence layout')
            row['raw_sequence_region'] = save(f'raw/{i:03d}.sequence-region.bin', start, pos-start)
        slots.append(row)
    active = [s for s in slots if s['tracks']]
    banks = sorted({int(s['bank_rom_offset'],16) for s in active})
    for s in active: s['soundfont_bank'] = banks.index(int(s['bank_rom_offset'],16))

    # Walk bank definitions and split/rhythm children. Only structurally valid
    # PCM headers inside the ROM's sample region become decoded samples.
    seen, sample_users, waves = set(), {}, set()
    def instrument(pos):
        if pos in seen or not 0x9DF52C <= pos <= 0x9F3EBC-12: return
        seen.add(pos)
        kind = rom[pos]
        ptr, tail = struct.unpack_from('<II',rom,pos+4)
        target = ptr-0x08000000
        if kind == 0x40:
            mapping = tail-0x08000000
            if not 0 <= mapping <= len(rom)-128: return
            for key in set(rom[mapping:mapping+128]): instrument(target+12*key)
        elif kind == 0x80:
            for key in range(128): instrument(target+12*key)
        elif kind in (0,8):
            if not 0x9F49C8 <= target < 0xCF8C34-16: return
            mode,freq,loop,length = struct.unpack_from('<IIII',rom,target)
            if mode not in (0,0x40000000) or not 1024<=freq<=192000*1024 or not 0<length<0x200000: return
            if target+16+length>0xCF8C34 or (mode and loop>=length): return
            sample_users.setdefault(target,set()).add(pos)
        elif kind in (3,11) and 0<=target<=len(rom)-16:
            waves.add(target)
    for i,bank in enumerate(banks):
        end = min(bank+128*12, banks[i+1] if i+1<len(banks) else 0x9F3EBC)
        save(f'raw/bank-{i:02d}.bin',bank,end-bank)
        for pos in range(bank,end-11,12): instrument(pos)
    samples=[]
    for pos,users in sorted(sample_users.items()):
        mode,freq,loop,length = struct.unpack_from('<IIII',rom,pos)
        raw = save(f'samples/{pos:08X}.pcm.bin',pos+16,length)
        header = save(f'samples/{pos:08X}.header.bin',pos,16)
        path = f'samples/{pos:08X}.wav'
        rate = round(freq/1024)
        with wave.open(str(out/path),'wb') as wav:
            wav.setnchannels(1); wav.setsampwidth(1); wav.setframerate(rate)
            wav.writeframes(bytes(b^0x80 for b in rom[pos+16:pos+16+length]))
        samples.append({'rom_offset':f'0x{pos:X}','sample_count':length,'middle_c_rate':freq/1024,
                        'wav_rate':rate,'loop_enabled':bool(mode),'loop_start':loop,
                        'raw':raw,'header':header,'wav':path,
                        'instrument_references':[f'0x{p:X}' for p in sorted(users)]})
    for pos in sorted(waves): save(f'samples/{pos:08X}.psg-wave.bin',pos,16)

    tools = ROOT/'build/audio-tools'
    errors=[]
    if not args.raw_only:
        for name in ['render','song_ripper','sound_font_ripper']:
            if not (tools/name).exists(): raise SystemExit('Run python3 tools/audio/build.py first')
        def finish_wav(s):
            if s.get('wav_gain') == 0.95: return
            original=out/s['wav']; temp=original.with_suffix('.convert.wav')
            subprocess.run(['ffmpeg','-v','error','-y','-i',str(original),'-af','volume=0.95',
                            '-c:a','pcm_s16le',str(temp)],check=True,capture_output=True)
            temp.replace(original)
            s['wav_gain']=0.95
            s['wav_peak']=s['peak']*0.95

        def convert(s):
            i=s['id']; logs=[]
            if previous:
                old=previous['slots'][i]
                if old['header_rom_offset']!=s['header_rom_offset'] or not all((out/old[k]).exists() for k in ['wav','midi']):
                    raise ValueError(f'Missing conversion for {i}')
                for k in ['wav','midi','frames','seconds','peak','ended','wav_gain','wav_peak']:
                    if k in old: s[k]=old[k]
                finish_wav(s)
                return
            midi=f'midi/{i:03d}.mid'
            result=subprocess.run([str(tools/'song_ripper'),str(rom_path),str(out/midi),s['header_rom_offset'],
                                   '-b'+str(s['soundfont_bank']),'-gs'],capture_output=True,text=True,timeout=60)
            logs.append(result.stdout+result.stderr)
            # Upstream returns the bank address, rather than a conventional exit code.
            if (out/midi).exists() and (out/midi).read_bytes()[:4]==b'MThd' and ' Done!' in result.stdout and 'Time out!' not in result.stdout:
                s['midi']=midi
            else: s['midi_error']='See log'; errors.append(f'MIDI {i}')
            wav=f'{s["kind"]}/{i:03d}.wav'
            result=subprocess.run([str(tools/'render'),str(rom_path),str(i),str(out/wav),'600'],
                                  capture_output=True,text=True,timeout=240)
            logs.append(result.stdout+result.stderr)
            match=re.search(r'render id=\d+ frames=(\d+) seconds=([\d.]+) peak=([\d.eE+-]+) ended=(\d)',result.stdout)
            if result.returncode==0 and match:
                s.update(wav=wav,frames=int(match[1]),seconds=float(match[2]),peak=float(match[3]),ended=True)
                finish_wav(s)
            else: s['render_error']='See log'; errors.append(f'WAV {i}')
            (out/f'logs/{i:03d}.txt').write_text('\n'.join(logs))
            print(f'Audio {i:03d}: {s["kind"]}, {s.get("seconds","FAILED")} seconds',flush=True)
        with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
            list(pool.map(convert,active))
        font=subprocess.run([str(tools/'sound_font_ripper'),'-s21024','-mv15',str(rom_path),str(out/'instruments.sf2'),
                             *[hex(b) for b in banks]],capture_output=True,text=True,timeout=180)
        (out/'logs/soundfont.txt').write_text(font.stdout+font.stderr)
        font_path=out/'instruments.sf2'
        if font.returncode or not font_path.exists() or font_path.read_bytes()[:4]!=b'RIFF': errors.append('SoundFont')
    manifest={'rom_sha256':EXPECTED_SHA256,'song_table_rom_offset':hex(TABLE),'slots':slots,
              'counts':{'slots':COUNT,'music':sum(s['kind']=='music' for s in slots),
                        'effects':sum(s['kind']=='effects' for s in slots),'empty':sum(s['kind']=='empty' for s in slots),
                        'banks':len(banks),'pcm_samples':len(samples),'psg_waves':len(waves)},
              'sample_definitions':samples,'files':files,'errors':errors,
              'scene_music':scene_music, 'scene_music_overrides':overrides,
              'engine':{'format':'MP2K','volume':15,'reverb':0,'frequency_index':7,'pcm_rate':21024,
                        'max_pcm_channels':12,'dac_config':9,'players':11},
              'render':{'renderer':'agbplay','revision':'d209cce0449edfa61bbf15a9d22735ddfe09dd4f',
                        'wav_format':'48000 Hz stereo 16-bit PCM', 'output_gain':0.95,'max_loops_setting':2,'max_seconds':600,
                        'notes':'Software rendition, not hardware capture; maximum loops is agbplay counter, followed by fade. Uniform 0.95 gain leaves headroom.'},
              'notes':['Slot 0 is a stop-music command in the game wrapper, despite its zero-track header.',
                       'Music/effect classification follows player zero versus other players; titles remain unidentified.',
                       'MIDI and SF2 are conversions; original MP2K data and sample headers are preserved.',
                       'Individual sample WAVs play once at rounded middle-C rate; loop metadata is in this manifest.',
                       'raw/audio-data-region.bin preserves the contiguous audio region, including patterns before track entry points.',
                       'Bank windows can include unused entries and adjacent data; raw files preserve those bytes.']}
    manifest['converted_files'] = [{'file':str(p.relative_to(out)),'size':p.stat().st_size,
                                    'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
                                   for p in sorted(out.rglob('*')) if p.suffix in ('.wav','.mid','.sf2')]
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    with (out/'catalog.csv').open('w') as f:
        cols=['id','kind','tracks','player','priority','header_rom_offset','bank_rom_offset','soundfont_bank','seconds','wav','midi']
        w=csv.DictWriter(f,fieldnames=cols,extrasaction='ignore');w.writeheader();w.writerows(slots)
    page=['<!doctype html><html lang="en"><meta charset="utf-8"><title>Sacred Cards audio</title>',
          '<style>body{background:#16191e;color:#eee;font:16px system-ui;margin:24px;max-width:1100px}a{color:#8cd1ff}article{padding:12px;background:#252b34;margin:8px 0;display:flex;gap:20px;align-items:center;flex-wrap:wrap}article[hidden]{display:none}audio{width:330px}input,select{padding:10px}small{color:#c0c8d5}</style>',
          '<h1>Music and sound effects</h1><p><a href="../index.html">All assets</a> · <a href="manifest.json">Manifest</a> · <a href="catalog.csv">Catalog CSV</a> · <a href="usage.html">Audio uses</a> · <a href="instruments.sf2">Instrument SoundFont</a></p>',
          f'<p>{manifest["counts"]["music"]} music entries · {manifest["counts"]["effects"]} effects · {len(samples)} PCM samples · {len(banks)} instrument banks. IDs are original song-table slots.</p>',
          '<p>WAVs use the agbplay software renderer, including looping and fade-outs. MIDI files need the supplied SoundFont; they are editable conversions, not exact playback replicas. Music/effect grouping follows the game’s playback slots. Titles remain unidentified.</p>',
          '<label>Filter <input id="search" placeholder="Song ID"></label> <select id="kind"><option value="">All</option><option>music</option><option>effects</option></select><main>']
    for s in active:
        links=''
        if 'wav' in s: links+=f'<audio controls preload="none" src="{s["wav"]}"></audio><a href="{s["wav"]}" download>WAV</a>'
        if 'midi' in s: links+=f'<a href="{s["midi"]}" download>MIDI</a>'
        page.append(f'<article id="song-{s["id"]:03d}" data-id="{s["id"]:03d}" data-kind="{s["kind"]}"><strong>{s["kind"].title()} {s["id"]:03d}</strong>{links}<small>{s["tracks"]} tracks · bank {s["soundfont_bank"]} · {s.get("seconds",0):.2f}s</small></article>')
    page.append('</main><h2>Scene music mapping</h2><p>Default songs and configuration overrides recovered from the scene loader. Song 000 stops music.</p><details><summary>58 scenes</summary>')
    for scene,song in enumerate(scene_music):
        links=', '.join(f'variant {o["variant"]}: <a href="#song-{o["song_id"]:03d}">{o["song_id"]:03d}</a>' for o in overrides if o['scene']==scene)
        page.append(f'<p><a href="../world/{scene:02d}.json">Scene {scene:02d}</a>: <a href="#song-{song:03d}">{song:03d}</a>'+(f' · {links}' if links else '')+'</p>')
    page.append('</details><p id="song-000">Song 000: stop music (no audio file).</p><h2>Individual PCM samples</h2><details><summary>Browse instrument samples</summary>')
    for s in samples:
        page.append(f'<article><strong>{s["rom_offset"]}</strong><audio controls preload="none" src="{s["wav"]}"></audio><a href="{s["wav"]}" download>WAV</a><small>{s["sample_count"]} samples · {s["wav_rate"]} Hz</small></article>')
    page.append('</details><script>function filter(){const q=document.querySelector("#search").value,k=document.querySelector("#kind").value;document.querySelectorAll("main article").forEach(a=>a.hidden=!a.dataset.id.includes(q)||(k&&a.dataset.kind!==k));}document.querySelector("#search").oninput=filter;document.querySelector("#kind").onchange=filter;document.addEventListener("play",e=>{document.querySelectorAll("audio").forEach(a=>{if(a!==e.target)a.pause();});},true);</script></html>')
    (out/'index.html').write_text('\n'.join(page)+'\n')
    print(json.dumps(manifest['counts']), 'errors:',errors)
    if errors: raise SystemExit('Some audio conversions failed; inspect manifest and logs')

if __name__=='__main__': main()
