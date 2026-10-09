#!/usr/bin/env python3
"""Build local audio tools from pinned public sources. No global installation."""
from pathlib import Path
import subprocess
import os
import shutil
ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
SOURCES = [
 ('build/agbplay-source','https://github.com/ipatix/agbplay.git','d209cce0449edfa61bbf15a9d22735ddfe09dd4f'),
 ('build/audio-deps/fmt','https://github.com/fmtlib/fmt.git','40626af88bd7df9a5fb80be7b25ac85b122d6c21'),
 ('build/audio-deps/math','https://github.com/boostorg/math.git','529f3a759d83aa9437613666ea6293c9336d4069'),
 ('build/gba-mus-ripper-source','https://github.com/CaptainSwag101/gba-mus-ripper.git','98ddff94a53512f57b7a4883ae4c3f3a20ac18a5')]
for path,url,commit in SOURCES:
 if not Path(path).exists():
  subprocess.run(['git','clone',url,path],check=True)
  subprocess.run(['git','-C',path,'checkout','--detach',commit],check=True)
 actual=subprocess.check_output(['git','-C',path,'rev-parse','HEAD'],text=True).strip()
 if actual!=commit: raise SystemExit(f'Unexpected version at {path}: {actual}')
out=Path('build/audio-tools');out.mkdir(parents=True,exist_ok=True)
base=Path('build/agbplay-source/src/agbplay')
# The upstream AVX2 header is x86-only. Use its existing scalar resamplers.
s=(base/'Resampler.cpp').read_text().replace('#include "ResamplerAVX2.hpp"','')
for kind in ['Sinc','Blep','Blamp']:
 old=f'if (AVX2_SUPPORTED)\n            return std::make_unique<{kind}ResamplerAVX2>();\n        else\n            return std::make_unique<{kind}Resampler>();'
 if old not in s: raise SystemExit('Upstream resampler changed')
 s=s.replace(old,f'return std::make_unique<{kind}Resampler>();')
(out/'ResamplerScalar.cpp').write_text(s)
names='CGBPatterns Debug LoudnessCalculator MP2KChn MP2KChnPCM MP2KChnPSG MP2KContext MP2KPlayer MP2KScanner MP2KTrack ReverbEffect SequenceReader SoundMixer Types Xcept'.split()
subprocess.run(['c++','-std=c++20','-O2','-DFMT_HEADER_ONLY','-DBOOST_MATH_STANDALONE',
 '-I'+str(base),'-Ibuild/audio-deps/fmt/include','-Ibuild/audio-deps/math/include',
 '-I/opt/homebrew/include','-L/opt/homebrew/lib','tools/audio/render.cpp',str(out/'ResamplerScalar.cpp'),
 *[str(base/(n+'.cpp')) for n in names],'-lsndfile','-o',str(out/'render')],check=True)
b=Path('build/gba-mus-ripper-source')
# Fix upstream end-iterator dereference and bound the AY7E final bank before its key maps.
font=(b/'sound_font_ripper.cpp').read_text()
font=font.replace('uint32_t next_address = *next_it;', 'uint32_t next_address = next_it == addresses.end() ? 0xffffffff : *next_it;')
font=font.replace('unsigned int ninstr = 128;', 'unsigned int ninstr = current_address == 0x9f3dfc ? 16 : 128;')
font=font.replace('fprintf(out_txt, s.c_str());', 'fprintf(out_txt, "%s", s.c_str());').replace('fprintf(out_txt, s);', 'fprintf(out_txt, "%s", s);')
(out/'sound_font_ripper.cpp').write_text(font)
for name in ['psg_data.raw','goldensun_synth.raw']:
 shutil.copyfile(b/name,out/name)
for output,names in [('song_ripper',['song_ripper','midi']),('sound_font_ripper',['sound_font_ripper','gba_samples','gba_instr','sf2'])]:
 subprocess.run(['c++','-std=c++11','-O2','-I'+str(b),*[str((out if n=='sound_font_ripper' else b)/(n+'.cpp')) for n in names],'-o',str(out/output)],check=True)
print('Built audio tools in',out)
