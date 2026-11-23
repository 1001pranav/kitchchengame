"""Concatenates game/sim/parts/*.gd into game/sim/sim.gd."""
import glob, os
here = os.path.dirname(__file__)
parts = sorted(glob.glob(os.path.join(here, '../sim/parts/*.gdp')))
out = ''.join(open(p).read().rstrip('\n') + '\n' for p in parts)
open(os.path.join(here, '../sim/sim.gd'), 'w').write(out)
print(len(out.splitlines()), 'lines')
