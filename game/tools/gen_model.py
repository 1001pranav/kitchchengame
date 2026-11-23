"""Generates game/sim/model_gen.gd field declarations + serialisation specs from
packages/sim_core/lib/src/model.dart. Methods are written by hand in model.gd."""
import re, sys, json
src = open(sys.argv[1]).read()
out = []
classes = re.split(r'\nclass (\w+) \{', src)
prims = {'int': ('int', '0', 'i'), 'double': ('float', '0.0', 'd'), 'bool': ('bool', 'false', 'b'),
         'String': ('String', '""', 's'), 'int?': ('', 'null', 'ni'), 'String?': ('', 'null', 'ns'),
         'List<int>': ('Array', '[]', 'li'), 'List<String>': ('Array', '[]', 'ls'),
         'Map<String, int>': ('Dictionary', '{}', 'mi'), 'Map<String, double>': ('Dictionary', '{}', 'md'),
         'Map<String, String>': ('Dictionary', '{}', 'ms'), 'Set<String>': ('Dictionary', '{}', 'ss')}
def conv(v, kind):
    v = v.strip()
    if v.startswith("'"): return '"' + v[1:-1] + '"'
    if kind == 'd' and re.fullmatch(r'-?\d+', v): return v + '.0'
    if v == '1 << 30': return '1 << 30'
    return v
names = []
for i in range(1, len(classes), 2):
    name, body = classes[i], classes[i + 1]
    names.append(name)
    head = body.split('\n  ' + name + '(')[0]
    ctor = body[len(head):]
    fields = []
    for line in head.split('\n'):
        m = re.match(r'^  ((?:List|Map|Set)<[^;]*?>\??|[A-Za-z]+\??) ([a-zA-Z0-9_, ]+);', line)
        if not m or line.strip().startswith(('static', 'const', 'final')): continue
        for f in m.group(2).split(','):
            fields.append((m.group(1), f.strip()))
    defaults = dict(re.findall(r'this\.(\w+)\s*=\s*([^,}\)\n]+)', ctor))
    inits = dict(re.findall(r'(\w+) = \1 \?\? ([^,;]+)', ctor))
    out.append(f'class {name} extends Rec:')
    spec = []
    for t, f in fields:
        if t in prims:
            gt, dv, k = prims[t]
            if f in defaults: dv = conv(defaults[f], k)
            out.append(f'\tvar {f}' + (f': {gt}' if gt else '') + f' = {dv}')
            spec.append(f'"{f}": "{k}"')
        else:
            m = re.fullmatch(r'List<(\w+)>', t)
            if m:
                out.append(f'\tvar {f}: Array = []'); spec.append(f'"{f}": ["l", {m.group(1)}]'); continue
            m = re.fullmatch(r'Map<String, (\w+)>', t)
            if m:
                out.append(f'\tvar {f}: Dictionary = {{}}'); spec.append(f'"{f}": ["m", {m.group(1)}]'); continue
            m = re.fullmatch(r'(\w+)(\?)?', t)
            cls = m.group(1)
            if m.group(2):
                out.append(f'\tvar {f} = null'); spec.append(f'"{f}": ["n", {cls}]')
            else:
                init = inits.get(f, '').strip()
                out.append(f'\tvar {f}: {cls} = {cls}.new()'); spec.append(f'"{f}": ["o", {cls}]')
                if 'dayIndex: 0' not in init and init not in (f'{cls}()', ''):
                    print('CHECK', name, f, init, file=sys.stderr)
    out.append('\tfunc _spec() -> Dictionary:')
    out.append('\t\treturn {' + ', '.join(spec) + '}')
    out.append(f'\t#@{name}')
    out.append('')
print('\n'.join(out))
print('classes:', names, file=sys.stderr)
