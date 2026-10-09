#!/usr/bin/env python3
"""Collect Clang declarations and cross-module contract differences; no execution."""
import json,re,subprocess
from collections import defaultdict
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def main():
    variables=defaultdict(list);functions=defaultdict(list);records=defaultdict(list);layouts={}
    def walk(node,path,in_function=False):
        kind=node.get('kind');name=node.get('name','')
        if kind=='VarDecl' and name.startswith('g') and node.get('storageClass')!='static' and (not in_function or node.get('storageClass')=='extern'):
            variables[name].append(dict(source=path,type=node['type'].get('desugaredQualType',node['type']['qualType']),line=node.get('loc',{}).get('line'),defined=node.get('storageClass')!='extern'))
        elif kind=='FunctionDecl' and name and node.get('storageClass')!='static':
            functions[name].append(dict(source=path,type=node['type']['qualType'],defined=any(x.get('kind')=='CompoundStmt' for x in node.get('inner',[]))))
        elif kind=='RecordDecl' and name and node.get('completeDefinition'):
            fields=[dict(name=x.get('name',''),type=x.get('type',{}).get('desugaredQualType',x.get('type',{}).get('qualType'))) for x in node.get('inner',[]) if x.get('kind')=='FieldDecl']
            records[name].append(dict(source=path,fields=fields))
        for child in node.get('inner',[]):walk(child,path,in_function or kind=='FunctionDecl')
    generated=[ROOT/'build/semantic'/s for s in ('effect_tables.c','ai_card_scorers.c','runtime_tables.c')]
    for p in sorted((ROOT/'src').glob('*.c'))+generated:
        r=subprocess.run(['clang','--target=arm-none-eabi','-mcpu=arm7tdmi','-mthumb','-std=c99','-ffreestanding','-fno-builtin','-fsyntax-only','-Xclang','-ast-dump=json',str(p)],capture_output=True,text=True,check=True)
        walk(json.loads(r.stdout),str(p.relative_to(ROOT)))
        # Ask the target compiler for offsets, including packed records and
        # nested members. Host Python/C layout is not a substitute for ARM ABI.
        r=subprocess.run(['clang','--target=arm-none-eabi','-mcpu=arm7tdmi','-mthumb','-std=c99','-fsyntax-only','-Xclang','-fdump-record-layouts-complete',str(p)],capture_output=True,text=True,check=True)
        for block in r.stdout.split('*** Dumping AST Record Layout'):
            match=re.search(r'^\s*0 \| struct (\w+)\s*$',block,re.M)
            end=re.search(r'\[sizeof=(\d+), align=(\d+)\]',block)
            if not match or not end:continue
            name=match.group(1);fields=[]
            for line in block.splitlines():
                field=re.match(r'\s*(\d+) \|   (\S.*)',line)
                if field:fields.append(dict(offset=int(field.group(1)),declaration=field.group(2)))
            layout=dict(size=int(end.group(1)),alignment=int(end.group(2)),fields=fields)
            if name in layouts and layouts[name]!=layout:raise ValueError('Incompatible target record layouts: '+name)
            layouts[name]=layout
    def unique(rows):return list({json.dumps(r,sort_keys=True):r for r in rows}.values())
    variables={k:unique(v) for k,v in sorted(variables.items())};functions={k:unique(v) for k,v in sorted(functions.items())}
    differences={k:v for k,v in variables.items() if len({r['type'] for r in v})>1}
    function_differences={k:v for k,v in functions.items() if len({r['type'] for r in v})>1}
    record_differences={k:unique(v) for k,v in records.items() if len({json.dumps(r['fields'],sort_keys=True) for r in v})>1}
    incompatible_variables={k:v for k,v in differences.items() if len({re.sub(r'\[\d*\]','[]',r['type']) for r in v})>1}
    for k,v in differences.items():
        extents={tuple(re.findall(r'\[(\d+)\]',r['type'])) for r in v if not re.search(r'\[\]',r['type'])}
        if len(extents)>1:incompatible_variables[k]=v
    out=ROOT/'build/research';out.mkdir(parents=True,exist_ok=True)
    (out/'source-contracts.json').write_text(json.dumps(dict(kind='Compiler declaration inventory; differences require review, not all are incompatibilities',variables=variables,functions=functions,records=records,record_layouts=layouts,variable_differences=differences,incompatible_variable_declarations=incompatible_variables,function_differences=function_differences,record_differences=record_differences),indent=2)+'\n')
    print('Variable differences:')
    for k,v in differences.items():print(k,sorted({r['type'] for r in v}))
    print('Function differences:')
    for k,v in function_differences.items():print(k,sorted({r['type'] for r in v}))
    print('Record differences:',list(record_differences))
    print('Incompatible variable declarations:',list(incompatible_variables))
if __name__=='__main__':main()
