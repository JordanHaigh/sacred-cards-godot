#!/usr/bin/env python3
"""Export reviewed runtime tables for scene rules, event motion, text and audio."""
import argparse,csv,hashlib,html,json,struct
from pathlib import Path
from rip_asset_tables import EXPECTED_SHA256
ROOT=Path(__file__).resolve().parents[1]
MOTIONS=[(0,0xD4F124,0xD4F16C,0xD4F124),(1,0xD4F1B4,0xD4F1C8,0xD4F124),
 (16,0xD4F1DC,0xD4F204,0xD4F1DC),(18,0xD4F22C,0xD4F254,0xD4F22C),
 (27,0xD4F27C,0xD4F2A0,0xD4F27C),(37,0xD4F2C4,0xD4F2E8,0xD4F2C4),
 (38,0xD4F30C,0xD4F330,0xD4F30C),(52,0xD4F354,0xD4F378,0xD4F354),
 (53,0xD4F39C,0xD4F3BC,0xD4F39C),(56,0xD4F3DC,0xD4F408,0xD4F3DC)]
def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('rom',type=Path)
    ap.add_argument('--out',type=Path,default=Path('build/assets/runtime'));a=ap.parse_args()
    rom=a.rom.read_bytes()
    if hashlib.sha256(rom).hexdigest()!=EXPECTED_SHA256:raise SystemExit('Unsupported ROM')
    a.out.mkdir(parents=True,exist_ok=True);files=[]
    def save(name,at,size):
        raw=rom[at:at+size];(a.out/name).write_bytes(raw);files.append(dict(file=name,address=f'0x{at+0x08000000:08X}',size=size,sha256=hashlib.sha256(raw).hexdigest()))
    rules=[]
    for i in range(256):
        row=struct.unpack_from('<12h',rom,0xFBB54+i*24)
        if row[0]==-1:break
        rules.append(dict(index=i,scene=row[0],variant=row[1],flags=list(row[2:10]),replacement=row[10],padding=row[11]))
    else:raise ValueError('No scene-rule terminator')
    save('scene-variant-rules.bin',0xFBB54,(len(rules)+1)*24)
    with (a.out/'scene-variant-rules.csv').open('w',newline='') as f:
        w=csv.writer(f);w.writerow(['index','scene','variant','required_event_flags','replacement'])
        for r in rules:w.writerow([r['index'],r['scene'],r['variant'],';'.join(str(n) for n in r['flags'] if n!=-1),r['replacement']])
    motion=[]
    for event,x,y,termination in MOTIONS:
        steps=[];i=0
        while True:
            steps.append(dict(dx=struct.unpack_from('<i',rom,x+i*4)[0],dy=struct.unpack_from('<i',rom,y+i*4)[0]));i+=1
            if struct.unpack_from('<i',rom,termination+i*4)[0]==127:break
            if i>=196:raise ValueError('No motion terminator')
        motion.append(dict(event=event,x=f'0x{x+0x08000000:08X}',y=f'0x{y+0x08000000:08X}',termination=f'0x{termination+0x08000000:08X}',steps=steps))
    save('script-motion-words.bin',0xD4F124,196*4)
    tags=[]
    for i in range(256):
        row=struct.unpack_from('<4H',rom,0xAC214+i*8)
        if not row[0]:break
        tags.append(dict(opponent=row[0],card=row[1],tag=row[2],padding=row[3]))
    else:raise ValueError('No attack-tag terminator')
    save('ai-attack-tags.bin',0xAC214,(len(tags)+1)*8)
    save('choice-glyph-next.bin',0xD4EF4C,56*4);save('dialogue-glyph-next.bin',0xD4F02C,56*4)
    save('initial-collection.bin',0x8673C,901);save('initial-shop-stock.bin',0xC8304,901)
    save('audio-samples-per-frame.bin',0x9DF6A0,24)
    audio_tables={}
    for name,at,count,fmt in [('sequence-callbacks',0x9DF52C,36,'I'),('extended-callbacks',0x9DF7D4,12,'I'),
        ('pcm-key-scale',0x9DF5BC,180,'B'),('pcm-pitch',0x9DF670,12,'I'),('psg-key-scale',0x9DF6B8,132,'B'),
        ('psg-pitch',0x9DF73C,12,'h'),('psg-noise',0x9DF754,60,'B'),('psg-wave-volume',0x9DF790,16,'B'),
        ('sequence-durations',0x9DF7A0,49,'B')]:
        save('audio-'+name+'.bin',at,count*struct.calcsize(fmt))
        audio_tables[name]=dict(address=f'0x{at+0x08000000:08X}',values=list(struct.unpack_from('<'+fmt*count,rom,at)))
    registry=json.loads((ROOT/'semantic_script_events.json').read_text())
    result=dict(rom_sha256=EXPECTED_SHA256,scene_rules=rules,motions=motion,ai_attack_tags=tags,events=registry['entries'],files=files,
                choice_glyph_next=list(struct.unpack_from('<56I',rom,0xD4EF4C)),dialogue_glyph_next=list(struct.unpack_from('<56I',rom,0xD4F02C)),
                audio_samples_per_frame=list(struct.unpack_from('<12H',rom,0x9DF6A0)),audio_driver_tables=audio_tables,
                notes=['Scene rules can cascade in stored order; every nonnegative flag must be set.',
                       'Event 1 reads its termination from event 0\'s X table, including accesses beyond its short X/Y arrays. These are literal native reads.',
                       'The twelve standard audio frequency entries are exported; mode values 13..15 index following ROM data in native code.',
                       'C entry coverage does not mean menu/duel dependencies, native linkage or timing are complete.'])
    (a.out/'manifest.json').write_text(json.dumps(result,indent=2)+'\n')
    rows=''.join(f'<tr><td>{r["index"]}</td><td>{r["scene"]}</td><td>{r["variant"]}</td><td>{html.escape(str([n for n in r["flags"] if n!=-1]))}</td><td>{r["replacement"]}</td></tr>' for r in rules)
    moves=''.join(f'<details><summary>Event {m["event"]}: {len(m["steps"])} movement steps</summary><pre>{html.escape(json.dumps(m,indent=2))}</pre></details>' for m in motion)
    (a.out/'index.html').write_text('<!doctype html><meta charset="utf-8"><title>Runtime data</title><style>body{font:16px system-ui;margin:2rem;background:#171c24;color:#eee}a{color:#9bd7ff}td,th{padding:.4rem;text-align:left}</style><h1>Runtime data</h1><p><a href="../index.html">Assets</a> · <a href="manifest.json">Manifest</a> · <a href="scene-variant-rules.csv">Rule CSV</a></p><p>58 event bodies, '+str(len(rules))+' scene-variant rules, 10 motion sequences and '+str(len(tags))+' AI attack tags. Includes glyph traversal, initial inventory and audio-frequency tables.</p><h2>Scripted motion</h2>'+moves+'<h2>Scene variant rules</h2><table><tr><th>Index</th><th>Scene</th><th>Variant</th><th>Required flags</th><th>Replacement</th></tr>'+rows+'</table>')
    print(f'Exported {len(rules)} scene rules, {len(motion)} motions, {len(tags)} attack tags and runtime tables')
if __name__=='__main__':main()
