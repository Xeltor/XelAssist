# XelAssist 0.7.0

XelAssist is a private, input-driven combat decision addon for OctoWoW 1.18.
It discovers the character's known spell ranks and evaluates them as an action
graph. Curated semantics cover known Octowow abilities, while conservative live
tooltip inference admits unambiguous unknown combat spells. It does not contain
a class rotation or an ordered cast list.

Aegis_SBR and other installed addons are read-only research references, not
runtime dependencies. XelAssist capability-checks the required SuperWoW,
SuperAPI, Nampower, and available ClassicAPI DLL globals directly.

Each physical press of `/xa` executes at most one recommendation. The on-screen
decision runway shows the current action and up to four simulated future actions
as actor-to-target contracts with modeled start times and visible evidence state.
Predicted rows are never executable. The explanation describes the tradeoff that
won, such as finishing the target, avoiding excess healing, limiting threat,
interrupting a cast, or preserving resources.

Actions on the selected target use Nampower's one-spell queue. Explicit party,
mouseover, self, and ground targets retain SuperWoW's unit-targeted cast path.

## Requirements

- OctoWoW's 1.12.1-compatible client
- SuperWoW and its SuperAPI compatibility addon
- Nampower with `QueueSpellByName`; recent builds add the most accurate graph data

The addon uses Nampower's guarded DBC access when present for per-rank cast time,
GCD, cooldown, duration, cost, and minimum/maximum range. Hidden tooltip scans are
the fallback. An unreadable fact stays unknown and lowers confidence; it is never
silently converted into a reason to cast.

Create a clean install archive with `python3 scripts/package_xelassist.py`. It
contains one `XelAssist` folder ready for `Interface\AddOns` and excludes tests,
repository metadata, and developer files.

Runtime Lua is grouped by responsibility under `Core/`, `Game/`, `Combat/`,
`Graph/`, and `UI/`. See [docs/code-organization.md](docs/code-organization.md)
for module ownership, Lua 5.0 constraints, review limits, and migration debt.

## Setup

1. Put the `XelAssist` folder in `Interface\AddOns`.
2. Enable XelAssist and its dependencies.
3. Create a macro containing `/xa` and bind it, or bind **Smart Execute** under
   the XelAssist heading in Key Bindings.
4. Right-click the minimap button or use `/xa config` to set this character's
   role, optional-action policy, intent, and number of predicted actions.

The primary recommendation is also clickable. A click takes a fresh snapshot and
performs one action; it does not execute the preview cached on screen. XelAssist
never acquires or changes a hostile target and never casts from an update handler.

## Character and global settings

Decision policy is stored per character: Smart/Single/Area/Support intent, role,
graph depth, area-action permission, cooldown/reagent/consumable permission, companion
actions, crowd-control permission, and companion threat posture. Display scale,
position, lock state, and visibility are global.
Finite consumables are always opt-in per character and default disabled.

Smart mode reacts to live need. It can prefer an interrupt, unwanted-aggro escape,
defensive, efficient heal, missing utility, or damage action without dispatching
into a class rotation. Single, Area, and Support constrain the goal without
ordering spells.

## Commands

`/xa` executes once. Other commands are `why`, `smart`, `single`, `aoe`,
`support`, `cooldowns`, `reagents`, `consumables`, `resistance`, `diagnostics`, `log`,
`clearlog`, `config`, `show`, and `hide`.

The per-character decision log keeps the latest 200 attempted recommendations and
their local state evidence. `/xa log` prints the latest five. It contains combat
numbers and action names, not player or target names.

`/xa diagnostics` also refreshes a durable, privacy-safe runtime audit containing
dependency/API availability and discovered versus inferred action-node counts.

## Graph model

The evaluator is bounded to five actions, four branches, 80 expanded path states, and
a 3 ms hot-path budget. It accounts for:

- current cast and GCD downtime, predicted action cast time, and own cooldowns;
- explicit live range verdicts, minimum/maximum DBC ranges, and movement;
- hitbox-aware actor-to-target distance, line of sight, and behind-position
  evidence when UnitXP exposes it;
- current resources, per-rank cost, effective healing, overheal, and damage needed
  to finish the target;
- talent-adjusted client tooltip facts, refreshed whenever talent points change;
- group role, current target-of-target aggro, and relative action threat;
- interrupts, proc/stance usability, combo points, buffs, debuffs, ranks,
  area policy, cooldown policy, and reagents;
- independent player and companion clocks; live pet identity, health, resource,
  target, action bar, spellbook ranks, cooldowns, autocast state, range, threat,
  commands, dispels, interrupts, crowd control, self-healing, sacrifice, and summons;
- Hunter pet lifecycle, happiness, focus, family abilities, Growl/Cower policy,
  Bestial Wrath's separate damage/immunity windows, Intimidation's deferred
  successful-melee proc, Kill Command's pet-owned result, and five-second Mend Pet;
- Auto Shot launch, projectile, impact, ammunition, movement/cast delay, and
  repeated-tap state on the same causal timeline as pet attacks, periodic ticks,
  and the chosen action;
- equipped weapon durability and ammunition, plus opt-in immediate-use healing
  and mana consumables discovered conservatively from live bag tooltips;
- future resource, health, target-health, aura, threat-drop, and cooldown state.
- target/ally/controlled-actor identity plus instance, zone, creature ID,
  classification, raid marker, combat state, and owned timed aura evidence.
- Turtle target Armor/Holy/Fire/Nature/Frost/Shadow/Arcane values, equipped
  spell/armor penetration, DBC binary/always-hit/ignore-resistance semantics, and
  target-school outcome learning separated into landing and landed-hit mitigation;
- dynamic wand/seal/pet schools, armor-ignoring bleeds, and weighted mixed-school
  and hybrid direct/periodic effects, with resistance-adjusted damage feeding
  overkill, target lifetime, threat, future health, debuff-then-exploit paths,
  and the final recommendation explanation.
- exact target delivery learning from ordinary magic misses, physical hit-table
  outcomes, Nampower white-swing rounds, binary combined rejects, landed damage,
  and caster-attributed aura
  events, with cast-time modifier fingerprints, tick-time resistance state,
  refresh-generation safety, and expiring projected modifiers.
- actual main-hand, off-hand, ranged, and no-weapon-form skill against
  source-correct NPC/PvP Defense and observable Defense bonuses, including
  white-only, durability-aware dual-wield miss rules, DBC damage-class and
  Combat-Range classification, and hand/weapon/form/position/white-table-specific
  outcome learning. The calculated value is the initial miss sub-roll; additive
  +hit and cold active-defense rates remain explicit unknown inputs until exact
  matching outcomes teach them.
- probabilistic debuff applications and refreshes, generic own-caster exclusive
  aura families, impact-time pet autocast modifiers, and a retained setup branch
  so bounded lookahead can discover resistance-debuff-then-damage cycles.

See [docs/graph-model.md](docs/graph-model.md) for evidence boundaries and current
limitations.

## Validation

```sh
python3 scripts/validate_xelassist.py
```

This validates the TOC and XML, Lua 5.0 policy, absence of typed rotations,
execution boundaries, real Lua graph scenarios, a clean installable archive, and
a mocked full TOC-order load through initialization, recommendation UI, settings,
and minimap construction.
