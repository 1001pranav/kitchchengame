#!/bin/bash
# Turns `var x := expr` into `var x = expr` on lines Godot cannot type, in the part files.
cd "$(dirname "$0")/.."
python3 tools/build_sim.py >/dev/null
out=$(timeout 100 /opt/godot/Godot_v4.5.1-stable_linux.x86_64 --headless --path . -s res://tools/chk3.gd 2>&1)
echo "$out" | grep -E 'Parse Error|sim.gd:' | grep -v hides > /tmp/claude-0/-home-user-kitchchengame/88a2cd32-a900-5c11-92f8-d2546ba43d4a/scratchpad/errs.txt
python3 - <<'P'
import re,glob
errs=open('/tmp/claude-0/-home-user-kitchchengame/88a2cd32-a900-5c11-92f8-d2546ba43d4a/scratchpad/errs.txt').read().splitlines()
pairs=[]
for i,l in enumerate(errs):
    if 'Parse Error' in l and i+1<len(errs):
        m=re.search(r'sim.gd:(\d+)',errs[i+1])
        if m: pairs.append((int(m.group(1)), l.split('Parse Error: ')[1]))
parts=sorted(glob.glob('sim/parts/*.gdp'))
lines=[]; owner=[]
for p in parts:
    t=open(p).read().rstrip('\n').split('\n')
    for j,x in enumerate(t): lines.append(x); owner.append((p,j))
fixed=0; other=[]
edits={}
for ln,msg in pairs:
    p,j=owner[ln-1]
    if ('Cannot infer' in msg or 'inferred from a Variant' in msg) and ':=' in lines[ln-1]:
        edits.setdefault(p,{})[j]=True; fixed+=1
    else: other.append((ln,msg,lines[ln-1].strip()))
for p,js in edits.items():
    t=open(p).read().split('\n')
    for j in js: t[j]=t[j].replace(':=','=',1)
    open(p,'w').write('\n'.join(t))
print('fixed',fixed)
for o in other: print(o)
P
