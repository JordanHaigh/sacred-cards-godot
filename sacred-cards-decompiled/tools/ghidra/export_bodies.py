#!/usr/bin/env python3
"""Read existing Ghidra function bodies without changing the analysis project."""
import os,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def main():
    project=ROOT/'build/ghidra-project'
    if not (project/'AY7E.gpr').exists():raise SystemExit('Existing AY7E Ghidra project required; run make decompile first.')
    env=os.environ.copy();env.update(JAVA_HOME=str(ROOT/'build/toolchains/jdk-21.0.12.1+1/Contents/Home'),
                                    JAVA_TOOL_OPTIONS='-Duser.home='+str(ROOT/'build/ghidra-home'),GHIDRA_HEADLESS_MAXMEM='2G')
    cmd=[str(ROOT/'build/toolchains/ghidra_12.1.4_PUBLIC/support/analyzeHeadless'),str(project),'AY7E',
         '-process','Yu-Gi-Oh! - The Sacred Cards (USA).gba','-noanalysis','-readOnly','-scriptPath',str(ROOT/'tools/ghidra'),
         '-postScript','ExportFunctionBodies.java',str(ROOT/'build/research')]
    log=ROOT/'build/research/function-bodies-export.log'
    with log.open('w') as stream:subprocess.run(cmd,env=env,stdout=stream,stderr=subprocess.STDOUT,check=True)
    if 'AY7E existing native function bodies exported' not in log.read_text():raise SystemExit('Function body export did not finish; inspect '+str(log))
    print('Exported existing native body ranges without modifying the Ghidra project')
if __name__=='__main__':main()
