#!/usr/bin/env python3
"""Conservative local register dataflow at original duel-text call sites.

Uses existing Ghidra body ranges and reviewed instruction addresses. Joins keep
sets of possible values, branches are not condition-pruned, and caller-saved
registers become symbolic after calls. This is static analysis, not execution.
"""
import bisect,csv,json,re,struct,sys
from collections import defaultdict,deque
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'build/python-deps'))
from capstone import Cs,CS_ARCH_ARM,CS_MODE_ARM,CS_MODE_THUMB
from capstone.arm import ARM_OP_IMM,ARM_OP_REG,ARM_OP_MEM
BASE=0x08000000
def main():
    rom=(ROOT/'Yu-Gi-Oh! - The Sacred Cards (USA).gba').read_bytes()
    report=json.loads((ROOT/'build/disassembly/reachable_report.json').read_text())
    ranges=defaultdict(list)
    for r in csv.DictReader((ROOT/'build/research/native-function-bodies.csv').open()):
        ranges[int(r['function'],16)].append((int(r['start'],16),int(r['end_inclusive'],16)))
    decoders={}
    for mode,flag in [('thumb',CS_MODE_THUMB),('arm',CS_MODE_ARM)]:
        decoders[mode]=Cs(CS_ARCH_ARM,flag);decoders[mode].detail=True
    instructions={}
    for line in (ROOT/'build/disassembly/reachable.asm').read_text().splitlines():
        m=re.match(r'^([0-9A-F]{8})\s+(arm|thumb)\s+',line)
        if m:
            at=int(m[1],16);ins=next(decoders[m[2]].disasm(rom[at-BASE:at-BASE+4],at,count=1))
            instructions[at]=ins
    addresses=sorted(instructions);owner={};bodies={}
    for root,spans in ranges.items():
        body={at:instructions[at] for lo,hi in spans for at in addresses[bisect.bisect_left(addresses,lo):bisect.bisect_right(addresses,hi)]}
        bodies[root]=body
        for at in body:
            if at in owner and owner[at]!=root:raise ValueError('Overlapping function ownership '+hex(at))
            owner[at]=root
    jumps={int(t['branch_address'],16):t['targets'] for t in report['followed_manual_jump_tables']}
    targets={0x08024F2C,0x08024F64,0x08024F94,0x08024FC0,0x08017E74,0x08025098,0x080254CC,0x0802B33C}
    rows=[];all_calls=defaultdict(list)
    register_names=['r'+str(i) for i in range(13)]+['sp','lr','pc']
    def reg(ins,n):
        name=ins.reg_name(n);return {'sb':'r9','sl':'r10','fp':'r11','ip':'r12'}.get(name,name)
    def join(a,b):
        return frozenset({'unknown'}) if 'unknown' in a|b or len(a|b)>8 else a|b
    for root,body in bodies.items():
        if root not in body:continue
        initial={n:frozenset({'entry:'+n}) for n in register_names};states={root:initial};pending=deque([root])
        while pending:
            at=pending.popleft();ins=body[at];state=dict(states[at]);ops=ins.operands;op=ins.mnemonic
            def val(o):
                if o.type==ARM_OP_IMM:return frozenset({o.imm&0xFFFFFFFF})
                if o.type==ARM_OP_REG:return state.get(reg(ins,o.reg),frozenset({'unknown'}))
                return frozenset({'unknown'})
            reads,writes=ins.regs_access();written=[reg(ins,r) for r in writes]
            result=None
            if op in ('mov','movs') and len(ops)==2:result=val(ops[1])
            elif op in ('ldr','ldrb','ldrh','ldrsb','ldrsh') and len(ops)==2 and ops[1].type==ARM_OP_MEM:
                mem=ops[1].mem;where=None
                if reg(ins,mem.base)=='pc':where=((at+4)&~3)+mem.disp
                elif not mem.index:
                    values=state.get(reg(ins,mem.base),frozenset())
                    if len(values)==1 and isinstance(next(iter(values)),int):where=next(iter(values))+mem.disp
                n=1 if op in ('ldrb','ldrsb') else 2 if op in ('ldrh','ldrsh') else 4
                if where is not None and BASE<=where<=BASE+len(rom)-n:
                    v=int.from_bytes(rom[where-BASE:where-BASE+n],'little',signed=op in ('ldrsb','ldrsh'));result=frozenset({v&0xFFFFFFFF})
                else:result=frozenset({f'memory:{at:08X}'})
            for name in written:
                if name not in ('pc','cpsr'):state[name]=result if result is not None and ops and ops[0].type==ARM_OP_REG and name==reg(ins,ops[0].reg) else frozenset({f'derived:{at:08X}:'+name})
            is_call=op in ('bl','blx')
            target=ops[0].imm if ops and ops[0].type==ARM_OP_IMM else None
            if is_call:
                context=dict(call=f'0x{at:08X}',caller=f'0x{root:08X}',target=None if target is None else f'0x{target:08X}',
                             r8=sorted(states[at]['r8'],key=str))
                all_calls[target].append(context)
                for n in ('r0','r1','r2','r3','r12','lr'):state[n]=frozenset({f'call:{at:08X}:'+n})
            successors=[];next_at=at+ins.size
            if at in jumps:successors=jumps[at]
            elif op=='b':
                if target in body:successors=[target]
            elif op.startswith('b') and op not in ('bic','bics','bl','blx','bx') and target is not None:successors=[target,next_at]
            elif op=='bx' or (op=='pop' and 'pc' in written):successors=[]
            else:successors=[next_at]
            for successor in successors:
                if successor not in body:continue
                old=states.get(successor);merged=state if old is None else {k:join(old[k],state[k]) for k in state}
                if old!=merged:states[successor]=dict(merged);pending.append(successor)
    # A call can be visited repeatedly as dataflow reaches a fixed point.
    for target in sorted(targets):
        merged={}
        for c in all_calls.get(target,[]):
            key=c['call']
            if key in merged:c['r8']=sorted(join(frozenset(merged[key]['r8']),frozenset(c['r8'])),key=str)
            merged[key]=c
        rows.extend(merged.values())
    edges=json.loads((ROOT/'build/assets/duel-text/manifest.json').read_text())['inherited_r8_name_wrap_edges']
    affected=[dict(e) for e in edges]
    for e in affected:
        if e['card']==325:e.update(native_handler='0x0802D13C',effect_text_call='0x0802D1C4')
    expected={e['from'] for e in report['direct_call_edges'] if int(e['to'],16) in targets}
    recovered={c['call'] for c in rows}
    if expected-recovered:raise ValueError('Unreached reviewed call sites: '+str(sorted(expected-recovered)))
    result=dict(kind='Conservative native local R8 provenance at duel text and spell dispatch calls',calls=sorted(rows,key=lambda c:c['call']),
                affected_cards=affected,
                explicit_input='src/duel_text.h: PresentDuelTextWithContext / WriteDuelCardNameWithContext',
                notes=['entry:r8 means the function receives its caller register value. It does not mean zero.',
                       'memory/derived/call tokens retain an unknown value origin; no default value is fabricated.',
                       'Uses APCS callee-saved R8 across calls; indirect-call targets and original caller argument values are not globally solved.',
                       'The Machine Conversion Factory handler and text wrapper preserve incoming R8. A single constant for all duel messages is not supported.',
                       'Native wrap uses R8 only when >=26 name glyphs have no ASCII space before28; values0..27 add28-value blanks, larger values add none. The first byte is removed by the original no-space path.'])
    (ROOT/'build/research/duel-text-register-context.json').write_text(json.dumps(result,indent=2)+'\n')
    (ROOT/'build/assets/runtime/duel-text-register-context.json').write_text(json.dumps(result,indent=2)+'\n')
    inherited=sum(c['r8']==['entry:r8'] for c in rows)
    print(f'{len(rows)} native call sites cataloged; {inherited} preserve the function entry R8')
if __name__=='__main__':main()
