#!/usr/bin/env python3
"""Export the 200 native opponent records, 40-card decks and duel music IDs."""
import argparse,csv,hashlib,html,json,struct
from collections import Counter
from pathlib import Path
from rip_asset_tables import EXPECTED_SHA256

def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('rom',type=Path)
    ap.add_argument('--out',type=Path,default=Path('build/assets/opponents'));a=ap.parse_args();rom=a.rom.read_bytes()
    if hashlib.sha256(rom).hexdigest()!=EXPECTED_SHA256:raise SystemExit('Unsupported ROM')
    a.out.mkdir(parents=True,exist_ok=True);records=[];reward_tables={}
    def reward_table(address):
        key=f'0x{address:08X}'
        if key in reward_tables:return key
        at=address-0x08000000;entries=[]
        for j in range(1000):
            card,threshold=struct.unpack_from('<HH',rom,at+j*4)
            entries.append(dict(card_id=card,threshold=threshold))
            if card==0:break
        else:raise ValueError(f'Unterminated reward table {key}')
        file=f'{address:08X}.rewards.bin';(a.out/file).write_bytes(rom[at:at+4*len(entries)])
        reward_tables[key]=dict(address=key,file=file,entries=entries)
        return key
    # 200 consecutive pointers to 40-byte records; the following bytes are a
    # different lookup table, not extra opponent pointers.
    pointers=struct.unpack_from('<200I',rom,0xD35C28)
    (a.out/'pointer-table.bin').write_bytes(rom[0xD35C28:0xD35F48])
    for i,address in enumerate(pointers):
        at=address-0x08000000
        if at!=0xB4B5C+i*40:raise ValueError('Opponent table layout differs')
        raw=rom[at:at+40];words=struct.unpack('<10I',raw);deck_at=words[1]-0x08000000
        deck=list(struct.unpack_from('<40H',rom,deck_at))
        if any(c>900 for c in deck):raise ValueError('Unknown card in opponent deck')
        record_file=f'{i:03d}.record.bin';deck_file=f'{i:03d}.deck.bin'
        (a.out/record_file).write_bytes(raw);(a.out/deck_file).write_bytes(rom[deck_at:deck_at+80])
        row=dict(index=i,address=f'0x{address:08X}',identifier=words[0],record_file=record_file,
                 deck_address=f'0x{words[1]:08X}',deck_file=deck_file,deck=deck,deck_counts=dict(sorted(Counter(deck).items())),
                 words=[f'0x{x:08X}' for x in words],deck_capacity_reward=words[6],
                 money_roll_bounds=list(struct.unpack_from('<2H',raw,28)),money_decimal_scale=raw[32],duel_music=words[9],
                 reward_tables={kind:reward_table(p) for kind,p in zip(('normal','shop','special'),words[2:5])})
        records.append(row)
    special_cards=list(struct.unpack_from('<50H',rom,0xBA280))
    result=dict(rom_sha256=EXPECTED_SHA256,records=records,reward_tables=reward_tables,special_wager_cards=special_cards,notes=[
        'Native08017CA8 copies ten words from table08D35C28; record+04 selects the forty-card deck at08027418.',
        'Record+24 selects duel music. Reward fields+18/+1C/+1E/+20 are used by08016254/080164EC.',
        'Record+08/+0C/+10 select normal, shop and special reward tables. First nonzero-card entry whose threshold exceeds the roll wins; zero card terminates.',
        'Player reward rolls use0..2047; shop rolls use0..29999. Special wager list selects record+10. Fifty shop rolls occur after a win.',
        'Identifiers are raw game values; opponent display names and all remaining record fields are not assigned speculative meanings.'])
    (a.out/'manifest.json').write_text(json.dumps(result,indent=2)+'\n')
    with (a.out/'opponents.csv').open('w',newline='') as f:
        w=csv.writer(f);w.writerow(['index','identifier','address','deck_address','duel_music','capacity_reward','money_min','money_max','money_scale'])
        for r in records:w.writerow([r['index'],r['identifier'],r['address'],r['deck_address'],r['duel_music'],r['deck_capacity_reward'],*r['money_roll_bounds'],r['money_decimal_scale']])
    with (a.out/'decks.csv').open('w',newline='') as f:
        w=csv.writer(f);w.writerow(['opponent','slot','card_id'])
        for r in records:
            for slot,card in enumerate(r['deck']):w.writerow([r['index'],slot,card])
    with (a.out/'rewards.csv').open('w',newline='') as f:
        w=csv.writer(f);w.writerow(['table','entry','card_id','cumulative_threshold'])
        for key,t in reward_tables.items():
            for j,e in enumerate(t['entries']):w.writerow([key,j,e['card_id'],e['threshold']])
    rows=''.join(f'<details><summary>Opponent slot {r["index"]}: identifier {r["identifier"]}, music {r["duel_music"]}</summary><p><a href="../audio/index.html#song-{r["duel_music"]:03d}">Listen</a> · <a href="{r["record_file"]}">Record</a> · <a href="{r["deck_file"]}">Deck</a></p><p>'+html.escape(', '.join(f'{card} × {count}' for card,count in r['deck_counts'].items()))+'</p></details>' for r in records)
    (a.out/'index.html').write_text('<!doctype html><meta charset="utf-8"><title>Opponent records</title><style>body{font:16px system-ui;background:#171c24;color:#eee;margin:2rem}a{color:#9bd7ff}details{padding:.7rem}</style><h1>Opponent records and decks</h1><p><a href="../index.html">Assets</a> · <a href="manifest.json">JSON</a> · <a href="opponents.csv">Opponent CSV</a> · <a href="decks.csv">Deck CSV</a> · <a href="rewards.csv">Reward tables CSV</a></p><p>200 native records with 40-card decks, music IDs and reward fields. Slot labels are raw identifiers, not character names.</p>'+rows)
    print(f'Exported {len(records)} opponent records, {len(records)*40} deck slots and {len(reward_tables)} reward tables')
if __name__=='__main__':main()
