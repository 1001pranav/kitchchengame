import subprocess, sys, os
sys.path.insert(0, os.path.dirname(__file__))
from model_extra import EXTRA
gen = subprocess.check_output([sys.executable, os.path.join(os.path.dirname(__file__), 'gen_model.py'),
    os.path.join(os.path.dirname(__file__), '../../packages/sim_core/lib/src/model.dart')]).decode()
for k, v in EXTRA.items():
    assert f'\t#@{k}\n' in gen, k
    gen = gen.replace(f'\t#@{k}\n', v.lstrip('\n'))
import re
gen = re.sub(r'\t#@\w+\n', '', gen)
head = open(os.path.join(os.path.dirname(__file__), 'model_head.gd')).read()
open(os.path.join(os.path.dirname(__file__), '../sim/model.gd'), 'w').write(head + '\n' + gen)
