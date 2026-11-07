# Forever talent trees, per class: tabs left to right, each talent's
# tab/tier/column (as Pathwise computes them in game: distinct node
# positions, rounded to 50, within the tab), max rank, prerequisites and the
# points the tab needs before it. Source: wago.tools DB2 CSVs, 1.60.1.70790.
import csv, sys, os, json
D, OUT = sys.argv[1], sys.argv[2]
def rows(n): return list(csv.DictReader(open(os.path.join(D, n + '.csv'), encoding='utf-8')))
nodes = {int(r['ID']): r for r in rows('TraitNode')}
nxe = {}
for r in rows('TraitNodeXTraitNodeEntry'):
    nxe.setdefault(int(r['TraitNodeID']), []).append((int(r['_Index']), int(r['TraitNodeEntryID'])))
entries = {int(r['ID']): r for r in rows('TraitNodeEntry')}
defs = {int(r['ID']): r for r in rows('TraitDefinition')}
spells = {int(r['ID']): r['Name_lang'] for r in rows('SpellName')}
gnodes = {}
for r in rows('TraitNodeGroupXTraitNode'):
    gnodes.setdefault(int(r['TraitNodeGroupID']), set()).add(int(r['TraitNodeID']))
conds = {int(r['ID']): r for r in rows('TraitCond')}
gate = {}  # gated group -> (counted group, points)
for r in rows('TraitNodeGroupXTraitCond'):
    c = conds.get(int(r['TraitCondID']))
    if c and int(c['SpentAmountRequired']) > 0:
        gate[int(r['TraitNodeGroupID'])] = (int(c['TraitNodeGroupID']), int(c['SpentAmountRequired']))
prereq = {}
for r in rows('TraitEdge'):
    prereq.setdefault(int(r['RightTraitNodeID']), []).append(int(r['LeftTraitNodeID']))
CLASS_TREE = {'MAGE': 1112, 'DRUID': 1089, 'HUNTER': 1091, 'PALADIN': 1100, 'PRIEST': 1114, 'ROGUE': 1111,
              'SHAMAN': 1082, 'WARLOCK': 1116, 'WARRIOR': 1117}
out = {}
for cls, tree in CLASS_TREE.items():
    # The tabs: groups that other groups count points in (the gates).
    tabs = sorted({cg for g, (cg, pts) in gate.items() if pts == 30 and any(int(nodes[n]['TraitTreeID']) == tree for n in gnodes.get(cg, ()))},
                  key=lambda g: min(int(nodes[n]['PosX']) for n in gnodes[g]))
    result = []
    for ti, g in enumerate(tabs, 1):
        members = []
        for n in sorted(gnodes[g]):
            ents = sorted(nxe.get(n, []))
            e = ents and entries.get(ents[0][1]); d = e and defs.get(int(e['TraitDefinitionID']))
            if not d: continue
            members.append({'node': n, 'x': int(nodes[n]['PosX']), 'y': int(nodes[n]['PosY']),
                            'name': d['OverrideName_lang'] or spells.get(int(d['SpellID']), '?'),
                            'max': int(e['MaxRanks']), 'spell': int(d['SpellID'])})
        xs = sorted({round(m['x'] / 50) for m in members}); ys = sorted({round(m['y'] / 50) for m in members})
        for m in members:
            m['tab'], m['col'], m['tier'] = ti, xs.index(round(m['x'] / 50)) + 1, ys.index(round(m['y'] / 50)) + 1
            need = 0
            for gg, (cg, pts) in gate.items():
                if m['node'] in gnodes.get(gg, ()):
                    need = max(need, pts)
            m['needs'] = need
            m['prereq'] = prereq.get(m['node'], [])
            result.append(m)
    # A prerequisite is the talent above (an edge is drawn between the two;
    # some are listed both ways).
    pos = {m['node']: m for m in result}
    for m in result:
        m['prereq'] = [p for p in m['prereq'] if p in pos and pos[p]['tab'] == m['tab'] and pos[p]['tier'] < m['tier']]
    out[cls] = result
json.dump(out, open(OUT, 'w'), indent=0)
for cls, ms in out.items():
    print(cls, len(ms), 'tabs', sorted({m['tab'] for m in ms}),
          'needs ok' if all(m['needs'] == 5 * (m['tier'] - 1) for m in ms) else
          'needs differ: ' + ', '.join(f"{m['name']}({m['tier']},{m['needs']})" for m in ms if m['needs'] != 5 * (m['tier'] - 1)))
