# XelAssist code organization

XelAssist targets the Octowow 1.12 client and its Lua 5.0 runtime. The addon is
organized for human review first: folders name responsibilities, files have one
reason to change, and the TOC is the only runtime dependency manifest.

## Runtime tree

```text
Core/       bootstrap, lifecycle, commands, events, and execution boundary
Game/       client API discovery and live actor, ally, encounter, and item state
Combat/     player/pet semantics, delivery mechanics, observations, and learned evidence
Graph/      snapshot, targets, effects, scoring, transitions, and bounded search
UI/         recommendation HUD, character settings, and minimap entry
```

Tests, scripts, and documentation are development-only and never listed in the
TOC. `XelAssist.toc` uses exact-case Windows paths and explicitly lists every
runtime file. Folders do not auto-load, production code does not use `require`
or `dofile`, and adding a TOC entry requires a full Octowow client restart.

## Namespace and module shape

`XelAssist` is the one addon-owned global namespace. Saved-variable names,
binding labels, slash-command aliases, and WoW named frames are the only
intentional extra globals. A source path mirrors its namespace:

```lua
-- Module: XelAssist.Graph.State
-- Owns: graph snapshots and isolated state copies
-- Depends: XelAssist.Game.Actors, XelAssist.Game.Friendlies

local XA = XelAssist
local State = {}
XA.Graph.State = State
```

Files export one module table. Helpers stay local unless another module has a
real dependency on them. There is no generic `Utils.lua`; a shared helper must
have a domain owner and a descriptive API. The graph receives action semantics,
never class rotations or ordered priority lists.

## Ownership boundaries

- `Game` reads the client and produces structured live facts. It does not cast,
  score recommendations, or persist learned combat outcomes. The session-only
  `Game/Pets/EffectRuntime.lua` ledger correlates confirmed casts, observable
  pet auras, and exact melee outcomes so fresh snapshots retain pet effects
  without writing opaque identities or inferred state to saved variables.
- `Combat` owns declarative player and companion spell meaning, stateless
  delivery rules, transient observations, and target evidence. Pet knowledge is
  ID-first metadata over live-discovered actions, never a family priority list.
  It does not depend on graph search.
- `Graph/State.lua` is the live observation boundary for planning.
  `Graph/Timeline.lua` orders projected combat events without owning their
  mechanics. `Graph/ActorScoring.lua` and `Graph/ThreatScoring.lua` keep
  controlled-actor utility and actor-owned threat out of core potency scoring.
  Targeting, scoring, transitions, and search consume passed state and do not
  mutate live game state.
- `UI` renders plans and settings. It does not score actions or execute cached
  previews.
- `Core` owns startup and the one-input execution boundary. Cast, queue, item,
  pet-command, and any future target-changing APIs must remain on that boundary.

Dependencies must follow TOC order and remain acyclic. A lower-level mechanics
module cannot reach back into `Graph`, `UI`, or runtime dispatch.

## Review limits

- Prefer 150–300 lines per behavioral file.
- 450 lines is the hard limit for new or fully migrated files.
- A function over 60 lines requires an extraction review; a new function over
  100 lines is not accepted.
- A temporary oversized exception records a fixed ceiling in
  `scripts/validate_xelassist.py`; the file may shrink but cannot grow.
- Declarative knowledge can exceed the preferred size only while it remains
  data rather than hidden control flow.

Current migration debt is deliberately bounded:

| File | Next boundary split |
| --- | --- |
| `Combat/Resistance.lua` | identity/store, learning, estimator, summary |
| `Game/Capabilities.lua` | spellbook, spell facts, units/range, equipment |
| `Core/Runtime.lua` | startup, decision log, commands, event routing |
| `UI/HUD.lua` | formatting, tooltip, layout, recommendation presenter |

## Enforcement

`python3 scripts/validate_xelassist.py` resolves production Lua from the TOC and
fails for duplicate/missing/orphan modules, root-level `XelAssist_*.lua` files,
post-Lua-5.0 syntax, forbidden execution shortcuts, or a file growing beyond
its architecture ceiling. The mocked full-load test also reads the TOC directly,
so tests, packages, and the client share one load order.
