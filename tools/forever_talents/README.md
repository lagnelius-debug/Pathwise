# Forever talent builds

Data/Forever/TalentBuilds.lua is generated from these. To redo it after a
Forever patch:

1. Download the client tables (CSV) for the Forever build from
   wago.tools into a folder, e.g. for build 1.60.1.70790:
   `https://wago.tools/db2/<Table>/csv?build=1.60.1.70790` for TraitNode,
   TraitNodeEntry, TraitNodeXTraitNodeEntry, TraitDefinition,
   TraitNodeGroupXTraitNode, TraitNodeGroupXTraitCond, TraitCond, TraitEdge
   and SpellName.
2. `python3 export.py <csv folder> forever.json` - every class's tree:
   tabs left to right, each talent's row/column, ranks, prerequisites and
   the points its row needs.
3. Edit `forever_builds.py` (the builds by talent name, in point order).
4. `python3 validate.py forever.json forever_builds.py builds.lua` - checks
   every build (talents exist, ranks, rows open, prerequisites, 51 points)
   and writes the Lua picks for the `builds` table in
   Data/Forever/TalentBuilds.lua.
