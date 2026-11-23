"""Compares two parity traces line by line; prints the first differences."""
import json, sys, math
a = [json.loads(l) for l in open(sys.argv[1])]
b = [json.loads(l) for l in open(sys.argv[2])]
diffs = []
def cmp(x, y, path):
    if len(diffs) > 12: return
    if isinstance(x, bool) or isinstance(y, bool):
        if x != y: diffs.append((path, x, y)); return
    if isinstance(x, (int, float)) and isinstance(y, (int, float)):
        if x != y and not (abs(x - y) <= 1e-9 * max(1, abs(x))): diffs.append((path, x, y))
        return
    if type(x) != type(y): diffs.append((path, x, y)); return
    if isinstance(x, dict):
        for k in x.keys() | y.keys():
            if k not in x or k not in y: diffs.append((path + '.' + k, x.get(k, '<missing>'), y.get(k, '<missing>')))
            else: cmp(x[k], y[k], path + '.' + k)
    elif isinstance(x, list):
        if len(x) != len(y): diffs.append((path + '.len', len(x), len(y)))
        for i, (p, q) in enumerate(zip(x, y)): cmp(p, q, path + '[%d]' % i)
    elif x != y: diffs.append((path, x, y))
for i, (p, q) in enumerate(zip(a, b)):
    cmp(p, q, p['tag'])
    if diffs:
        print('FIRST DIFF at snapshot', i, p['tag'])
        for d in diffs[:12]: print(' ', d[0], '|', str(d[1])[:120], '|', str(d[2])[:120])
        sys.exit(1)
if len(a) != len(b): print('length differs', len(a), len(b)); sys.exit(1)
print('IDENTICAL', len(a), 'snapshots')
