# Checks forever_builds.py against Forever's trees; writes the Lua picks.
import json, sys, importlib.util
F = json.load(open(sys.argv[1]))
spec = importlib.util.spec_from_file_location('fb', sys.argv[2]); fb = importlib.util.module_from_spec(spec); spec.loader.exec_module(fb)
out, ok_all = [], True
for cls in sorted(fb.B):
    nodes = F[cls]
    byname = {}
    for m in sorted(nodes, key=lambda m: m['tier']):  # duplicates: the lowest one
        byname.setdefault(m['name'], m)
    bynode = {m['node']: m for m in nodes}
    out.append(f'  {cls} = {{')
    for key, (title, picks) in sorted(fb.B[cls].items()):
        have, spent, problems, lines, level = {}, {}, [], [], 10
        for name, ranks in picks:
            m = byname.get(name)
            if not m:
                problems.append(f'unknown talent {name}'); continue
            if have.get(m['node'], 0) + ranks > m['max']:
                problems.append(f'{name}: {have.get(m["node"], 0) + ranks} > max {m["max"]}')
            if spent.get(m['tab'], 0) < m['needs']:
                problems.append(f'{name}: row needs {m["needs"]} in tree {m["tab"]}, has {spent.get(m["tab"], 0)}')
            for p in m['prereq']:
                if have.get(p, 0) < bynode[p]['max']:
                    problems.append(f'{name}: needs {bynode[p]["name"]} {bynode[p]["max"]}/{bynode[p]["max"]} first')
            have[m['node']] = have.get(m['node'], 0) + ranks
            spent[m['tab']] = spent.get(m['tab'], 0) + ranks
            lv = f'{level}' if ranks == 1 else f'{level}-{level + ranks - 1}'
            lines.append(f'        {{ {m["tab"]}, {m["tier"]}, {m["col"]}, {ranks}, "{name}", {m["node"]} }}, -- {lv}')
            level += ranks
        total = sum(spent.values())
        if total != 51:
            problems.append(f'total {total}')
        pts = '/'.join(str(spent.get(i, 0)) for i in (1, 2, 3))
        print(f'{cls:8} {key:14} {title} ({pts}) ' + ('OK' if not problems else 'PROBLEMS: ' + '; '.join(problems)))
        ok_all = ok_all and not problems
        out += [f'    {key} = {{', f'      name = "{title} ({pts})",', '      gamePositions = true,', '      picks = {'] + lines + ['      },', '    },']
    out.append('  },')
open(sys.argv[3], 'w').write('\n'.join(out) + '\n')
sys.exit(0 if ok_all else 1)
