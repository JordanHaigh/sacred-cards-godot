#!/usr/bin/env python3
"""Resolve a native address to exported original bytes and known source uses."""
import argparse,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('address',help='Hex native address, e.g.080AC2A0')
    ap.add_argument('--catalog',type=Path,default=ROOT/'build/assets/runtime/resources.json');a=ap.parse_args()
    at=int(a.address,16);catalog=json.loads(a.catalog.read_text())
    ref=next((r for r in catalog['references'] if int(r['address'],16)==at),None)
    spans=[dict(s,file_offset=at-int(s['address'],16)) for s in catalog['original_file_spans'] if int(s['address'],16)<=at<int(s['address'],16)+s['size']]
    archive=catalog['archive'];base=int(archive['native_base'],16)
    result=dict(address=f'0x{at:08X}',original_files=spans,known_reference=ref,
                archive=dict(file='rom-data/'+archive['file'],offset=at-base) if base<=at<base+archive['size'] else None)
    print(json.dumps(result,indent=2))
if __name__=='__main__':main()
