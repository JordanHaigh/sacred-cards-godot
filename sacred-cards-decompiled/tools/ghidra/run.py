#!/usr/bin/env python3
"""Export local Ghidra C drafts from reviewed function roots (not matching C)."""
import argparse
import hashlib
import os
import subprocess
import sys
from pathlib import Path


def main():
    root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('rom', nargs='?', default='Yu-Gi-Oh! - The Sacred Cards (USA).gba')
    parser.add_argument('--ghidra', type=Path, default=root/'build/toolchains/ghidra_12.1.4_PUBLIC')
    parser.add_argument('--java-home', type=Path, default=root/'build/toolchains/jdk-21.0.12.1+1/Contents/Home')
    args = parser.parse_args()
    rom = Path(args.rom).resolve()
    if hashlib.sha256(rom.read_bytes()).hexdigest() != '093f986a92d73c48e11de0a83c6678c3620f8def6173f5e69133815301b40d8f':
        raise SystemExit('Unsupported ROM: analysis inputs are AY7E USA Rev 00 only')
    ghidra = args.ghidra.resolve()
    java = args.java_home.resolve()
    if not (java/'bin/javac').is_file() or not (ghidra/'support/analyzeHeadless').is_file():
        raise SystemExit('Local Ghidra + full JDK required; see docs/decompilation.md.')
    for name in ['ghidra-home', 'ghidra-project', 'decompiled', 'research']:
        (root/'build'/name).mkdir(parents=True, exist_ok=True)
    subprocess.run([sys.executable, str(root/'tools/ghidra/prepare.py')], cwd=root, check=True)
    env = os.environ.copy()
    env.update(JAVA_HOME=str(java), JAVA_TOOL_OPTIONS=f'-Duser.home={root}/build/ghidra-home',
               GHIDRA_HEADLESS_MAXMEM='2G')
    command = [str(ghidra/'support/analyzeHeadless'), str(root/'build/ghidra-project'), 'AY7E',
               '-overwrite', '-import', str(Path(args.rom).resolve()), '-loader', 'BinaryLoader',
               '-loader-baseAddr', '0x08000000', '-processor', 'ARM:LE:32:v4t', '-cspec', 'apcs',
               '-noanalysis', '-scriptPath', str(root/'tools/ghidra'), '-postScript', 'RecoverRom.java',
               str(root/'build/ghidra-input'), str(root/'build/decompiled'),
               '-log', str(root/'build/research/ghidra-analysis.log'),
               '-scriptlog', str(root/'build/research/ghidra-script.log')]
    log = root/'build/research/ghidra-console.log'
    print(f'Exporting drafts; log: {log}', flush=True)
    with log.open('w') as stream:
        subprocess.run(command, cwd=root, env=env, stdout=stream, stderr=subprocess.STDOUT, check=True)
    if 'AY7E DONE:' not in log.read_text():
        raise SystemExit('Ghidra did not finish the export. Inspect the console log.')
    subprocess.run([sys.executable, str(root/'tools/ghidra/catalog.py')], cwd=root, check=True)

if __name__ == '__main__':
    main()
