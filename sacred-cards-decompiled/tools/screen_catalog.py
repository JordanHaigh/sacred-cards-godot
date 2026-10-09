#!/usr/bin/env python3
"""Index recovered screen entry points and object-level dependencies (no execution)."""
import json,re,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SCREENS={
 'duel':dict(entries=['RunDuel','RunPlayerDuelTurn'],root='duel_flow',sources=['duel_flow','duel_player','duel_menus','duel_ui','duel_graphics','duel_text','battle_animation'],assets=['duel','duel-text','full-cards','cards','player-menus','gameplay','opponents','ui','audio']),
 'shop':dict(entries=['RunBuyShop','RunSellShop'],root='shop_menu',sources=['shop_menu','shop_graphics','shop_panel','shop_display','shop','card_sort','currency'],assets=['player-menus','deck-builder','cards','ui','gameplay','audio']),
 'deck-builder':dict(entries=['RunDeckManagement','RunCollectionEditor','RunDeckEditor','ShowPlayerStatus'],root='deck_management',sources=['deck_management','deck_builder_menu','deck_builder_state','deck_builder_graphics','pre_duel_menu','pre_duel_graphics','pre_duel_display','collection_display','card_sort'],assets=['deck-builder','cards','ui','gameplay','player-menus','audio'])}

def main():
    objects={};owners={}
    for p in sorted((ROOT/'build/semantic').glob('*.o')):
        defined=set();used=set()
        for line in subprocess.run(['nm','-g',str(p)],capture_output=True,text=True,check=True).stdout.splitlines():
            m=re.match(r'^\s*(?:[0-9a-fA-F]+\s+)?([A-Za-z])\s+(\S+)$',line)
            if m:
                kind,symbol=m.groups();(used if kind=='U' else defined).add(symbol)
                if kind!='U':owners.setdefault(symbol,set()).add(p.stem)
        source=f'src/{p.stem}.c' if (ROOT/f'src/{p.stem}.c').exists() else f'build/semantic/{p.stem}.c'
        objects[p.stem]=dict(source=source,defines=sorted(defined),uses=sorted(used))
    for screen in SCREENS.values():
        pending=[screen['root']];seen=set();externals={}
        while pending:
            module=pending.pop()
            if module in seen:continue
            seen.add(module)
            for symbol in objects[module]['uses']:
                if symbol in owners:pending.extend(owners[symbol]-seen)
                else:externals.setdefault(symbol,[]).append(objects[module]['source'])
        screen['sources']=[f'src/{s}.c' for s in screen['sources']]
        screen['object_dependency_closure']=[objects[s]['source'] for s in sorted(seen)]
        screen['external_symbols']={s:sorted(v) for s,v in sorted(externals.items())}
        screen['assets']=[f'build/assets/{a}/' for a in screen['assets']]
    result=dict(kind='Object/module dependency index; compile-time references, not a runtime call graph',screens=SCREENS,
        caveats=['A shared module can pull in functions that this screen never executes. Closure is deliberately conservative.',
                 'Generated ROM tables can reference unrelated effect/audio data. External symbols include data aliases, hardware state and compiler helpers.',
                 'These sources still use GBA BIOS calls, memory-mapped registers, 32-bit pointer fields and original ROM addresses. They are not a standalone host library.',
                 'Known duel-name wrapping inherits R8 for two German names. No default replacement behavior has been invented.',
                 'No implementation tests or execution comparisons were performed for the deck-builder recovery.'])
    destination=ROOT/'build/research/screen-dependencies.json';destination.write_text(json.dumps(result,indent=2)+'\n')
    print('Indexed duel, shop and deck-builder source/dependency contracts')
if __name__=='__main__':main()
