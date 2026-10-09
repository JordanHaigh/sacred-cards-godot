#!/usr/bin/env python3
"""Inventory current recovery artifacts; this does not execute semantic C."""
import csv,json,re,subprocess
from collections import Counter
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
def read(relative):return json.loads((ROOT/relative).read_text())
def optional(relative):return read(relative) if (ROOT/relative).exists() else {}
registry=read('semantic_handlers.json')
drafts=read('build/decompiled/manifest.json')
deck_assets=read('build/assets/deck-builder/manifest.json')
reassembly=read('build/reassembly/report.json')
sources=sorted((ROOT/'src').glob('*.c'))
assembly=sorted((ROOT/'src').glob('*.s'))
coverage=read('build/research/function-coverage.json')
code_coverage=read('build/research/code-coverage.json')
ai=read('semantic_ai_callbacks.json')
scorers=read('build/semantic/ai_card_scorers.json')
dependencies={}
for p in sources+assembly+[ROOT/'build/semantic/ai_card_scorers.c']:
    for address in set(re.findall(r'\bNative_(0[89][0-9A-Fa-f]{6})\s*\(',p.read_text())):
        dependencies.setdefault(address.upper(),[]).append(str(p.relative_to(ROOT)))
# Inventory actual object references without executing recovered code. Global
# data, compiler runtime support and named native routines are included here.
definitions={};undefined={};missing_objects=[]
objects=[ROOT/'build/semantic'/f'{p.stem}.o' for p in sources+assembly]
objects += [ROOT/'build/semantic/effect_tables.o',ROOT/'build/semantic/ai_card_scorers.o',ROOT/'build/semantic/runtime_tables.o']
for p in objects:
    if not p.exists():missing_objects.append(str(p.relative_to(ROOT)));continue
    result=subprocess.run(['nm','-g',str(p)],check=True,capture_output=True,text=True)
    for line in result.stdout.splitlines():
        m=re.match(r'^\s*(?:[0-9a-fA-F]+\s+)?([A-Za-z])\s+(\S+)$',line)
        if not m:continue
        kind,symbol=m.groups();target=undefined if kind=='U' else definitions
        target.setdefault(symbol,[]).append(str(p.relative_to(ROOT)))
unresolved={k:v for k,v in sorted(undefined.items()) if k not in definitions}
linkage=dict(kind='Object symbol inventory; no linking or execution',missing_objects=missing_objects,
             resolved_global_symbols=len(definitions),unresolved_symbols=unresolved,
             multiply_defined_symbols={k:v for k,v in definitions.items() if len(v)>1})
(ROOT/'build/research/semantic-linkage.json').write_text(json.dumps(linkage,indent=2)+'\n')
draft_files={f['address'].upper():f['file'] for f in drafts['functions']}
out=ROOT/'build/research/native-dependencies.csv'
with out.open('w',newline='') as f:
    writer=csv.writer(f);writer.writerow(['address','semantic_sources','automatic_draft'])
    for a,paths in sorted(dependencies.items()):writer.writerow([a,';'.join(paths),draft_files.get(a,'')])
# Unbound game globals and ROM/RAM pointer views are integration contracts.
# Compiler helper symbols below are emitted by Clang, not missing ROM bodies.
unresolved_functions={s:paths for s,paths in unresolved.items()
                      if not s.startswith(('g','__aeabi_'))}
status=dict(
    status='known_code_mapped_contracts_cataloged_runtime_unverified',
    completion_target='Faithful readable C and original assets; no engine-specific port',
    rom_sha256=registry['rom_sha256'],
    byte_identical_build_required=False,original_compiler_match_required=False,
    native_linker_integration_required=False,
    semantic_c_modules=len(sources),semantic_c_sources=[str(p.relative_to(ROOT)) for p in sources],
    assembly_modules=len(assembly),assembly_sources=[str(p.relative_to(ROOT)) for p in assembly],
    generated_effect_dispatch_tables=2,generated_runtime_tables=len(read('build/semantic/runtime_tables.json')['tables']),
    semantic_c_linked_into_rom=False,
    discovered_function_roots=drafts['known_roots'],
    source_location_coverage=coverage['counts'],
    source_inventory='build/research/function-coverage.json',
    source_inventory_scope='Locators and reviewed shared mappings; not 2806 independent execution validations',
    reviewed_executable_interval=[code_coverage['reviewed_start'],code_coverage['reviewed_end']],
    unclassified_executable_spans=code_coverage['unclassified_spans'],
    byte_inventory='build/research/code-coverage.json',
    reviewed_switch_tables=sum(1 for _ in csv.DictReader((ROOT/'jump_tables.csv').open())),
    reviewed_callback_tables=sum(1 for _ in csv.DictReader((ROOT/'function_tables.csv').open())),
    reviewed_effect_handler_bodies=len(registry['entries']),
    ai_top_level_callback_slots=len(ai['entries']),
    ai_top_level_distinct_bodies=len({e['address'] for e in ai['entries']}),
    ai_card_scoring_distinct_bodies=len(scorers['functions']),
    ai_card_scoring_kinds=dict(Counter(e['kind'] for e in scorers['functions'])),
    explicitly_address_named_native_dependencies=len(dependencies),
    unresolved_named_function_symbols=unresolved_functions,
    unresolved_object_symbols=len(unresolved),
    unbound_game_data_symbols=sum(s.startswith('g') for s in unresolved),
    clang_compiler_support_symbols=[s for s in unresolved if s.startswith('__aeabi_')],
    multiply_defined_symbols=linkage['multiply_defined_symbols'],
    missing_objects=missing_objects,
    dependency_inventory='build/research/native-dependencies.csv',
    object_linkage_inventory='build/research/semantic-linkage.json',
    screen_reuse_guide='docs/screen_reuse.md',source_recovery_guide='docs/source_recovery.md',
    deck_builder_asset_previews=len(deck_assets['images']),
    deck_builder_asset_files=len(deck_assets['files']),
    deck_builder_text_records=len(deck_assets['strings']),
    automatic_c_export={k:drafts[k] for k in ('kind','ghidra','processor','analysis_abi','known_roots','statuses')},
    historical_instruction_reassembly=reassembly,
    all_rom_code_discovered_proven=False,all_rom_data_semantically_classified=False,
    new_semantic_c_execution_compared=False,
    limitations=[
        'Source references and compilation do not prove semantic or timing equivalence.',
        'GBA BIOS, memory-mapped IO, original pointer fields and global state remain runtime contracts.',
        'Two German duel names can consume an inherited R8 value, exposed as an explicit context input.',
        'All known asset families are exported; unused or adjacent ROM data is retained without invented interpretation.',
        'The older byte-identical reassembly uses original bytes for gaps and does not incorporate the recovered C.'])
state=optional('build/assets/runtime/state-contracts.json')
resources=optional('build/assets/runtime/resources.json')
animations=optional('build/assets/runtime/animations.json')
contracts=optional('build/research/source-contracts.json')
contexts=optional('build/research/duel-text-register-context.json')
status['rebuild_contracts']=dict(
    state_catalog='build/assets/runtime/state-contracts.json',
    state_views=len(state.get('views',[])),ram_storage_groups=len(state.get('storage_groups',[])),
    physical_state_intersections=len(state.get('overlaps',[])),target_record_layouts=len(state.get('records',{})),
    resource_catalog='build/assets/runtime/resources.json',
    original_file_spans=len(resources.get('original_file_spans',[])),referenced_rom_addresses=len(resources.get('references',[])),
    pointer_table_edges=len(resources.get('pointer_edges',[])),
    known_pointer_edges=len(resources.get('pointer_edges',[])),
    animation_catalog='build/assets/animations/manifest.json',animation_original_files=len(animations.get('files',[])),
    source_declaration_catalog='build/research/source-contracts.json',
    incompatible_variable_declarations=list(contracts.get('incompatible_variable_declarations',{})),
    differing_function_declarations=list(contracts.get('function_differences',{})),
    differing_record_declarations=list(contracts.get('record_differences',{})),
    native_text_call_sites=len(contexts.get('calls',[])),
    text_register_context_catalog='build/assets/runtime/duel-text-register-context.json')
(ROOT/'build/recovery-status.json').write_text(json.dumps(status,indent=2)+'\n')
print(f'{len(sources)} C + {len(assembly)} assembly modules; {drafts["known_roots"]} source locators; '
      f'{len(dependencies)} address-named and {len(unresolved_functions)} named missing function dependencies; '
      f'{len(code_coverage["unclassified_spans"])} unclassified code spans; runtime unverified')
