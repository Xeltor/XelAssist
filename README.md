# XelAssist 0.8.5

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

Actions on the selected target use Nampower 4.7.0+'s one normal-GCD spell queue.
XelAssist protects an occupied slot across repeated macro taps until matching
server evidence with an unambiguous opaque attempt ID resolves the cast; an
ambiguous same-spell result remains conservatively latched until its bounded
timeout. With Nampower 4.7.1+, on-next-swing abilities use a separate exact
attempt-owned lane; 4.7.0 retains a conservative single-owner fallback. Native
replacement buffering is disabled so repeated input cannot overwrite the armed
action. Their resource, cooldown, damage, and threat occur at the verified
main-hand round rather than when the button is pressed. Non-GCD actions remain independent.
Explicit party, mouseover, self, and ground targets retain SuperWoW's unit-targeted cast path.
Hostile recommendations remain pinned to the captured selected-target GUID at
dispatch; observing another enemy never gives XelAssist permission to target or
attack it.

## Requirements

- OctoWoW's 1.12.1-compatible client
- SuperWoW and its SuperAPI compatibility addon
- Nampower 4.7.0 or newer; 4.7.1+ is recommended for exact on-swing generations

The addon uses Nampower's guarded DBC access when present for per-rank cast time,
GCD/queue class, on-next-swing classification, cooldown, duration, cost, and
minimum/maximum range. Hidden tooltip scans are
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
dependency/API availability, discovered versus inferred action-node counts,
Hunter focus evidence, controlled-companion swing evidence, and player
main-hand/on-swing ownership evidence. It reports
whether each clock is learning, dormant, or executable; it does not persist pet
identity.

## Graph model

The evaluator is bounded to five actions, four branches, 80 expanded path states,
and a 3 ms soft budget for future look-ahead. The complete immediate candidate
set is always evaluated; crossing the budget returns the best current action and
shortens the prediction runway instead of producing a HOLD. It accounts for:

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
  commands, dispels, interrupts, crowd control, self-healing, sacrifice, and
  summons; enabled autocasts share one pet cast/GCD clock, and unresolved order,
  geometry, cast completion, or area recipients reserve cost without fake hits;
- Hunter pet lifecycle, happiness, focus, family abilities, Growl/Cower policy,
  Bestial Wrath's separate damage/immunity windows, Intimidation's deferred
  successful-melee proc, Kill Command's pet-owned result, five-second Mend Pet,
  and live-learned same-pet focus regeneration without a hardcoded server rate.
  The cadence becomes executable only when Nampower energize attribution can
  exclude non-passive gains; otherwise it remains diagnostic;
- target-pinned Hunter pet and Warlock demon main-hand swing timing learned from
  exact classified Nampower attack rounds, independently of focus and the pet
  spell GCD. Attack commands never fabricate a swing phase. Exact hitbox/reach
  and line-of-sight evidence gate each projected round; target, identity, speed,
  aura, control, or attack-state changes invalidate it. Normal pet damage is
  diagnostic only until crit, glancing, block, absorb, and resistance outcome
  magnitude can be distributed without inventing damage or threat;
- Auto Shot launch, projectile, impact, ammunition, movement/cast delay, and
  repeated-tap state on the shared event timeline with periodic ticks, companion
  events, and the chosen action. Exact numeric spell-range evidence owns its
  dead zone; center-to-center distance and live DBC projectile speed own flight
  timing. A real launch with missing timing makes only its captured target's
  health/threat inexact instead of becoming an invented or silently lost hit;
  ledger overflow retains target-local or global uncertainty until session reset.
  The generic player Attack command is likewise start-only and idempotent; its
  button press is never modeled as melee damage;
- exact target-pinned player main-hand phase learned only from classified attack
  rounds. DBC-classified on-next-swing actions reserve one independent lane and
  their cost until that round, replace the ordinary white result rather than
  double-counting it, and are scored only for their marginal improvement over
  the displaced white swing. Unknown phase, damage, geometry, target identity,
  or area recipients holds the action instead of inventing a melee outcome;
- equipped weapon durability and ammunition, plus opt-in immediate-use healing
  and mana consumables discovered conservatively from live bag tooltips;
- future resource, health, target-health, aura, threat-drop, and cooldown state.
- target/ally/controlled-actor identity plus instance, zone, creature ID,
  classification, raid marker, combat state, and owned timed aura evidence.
- a deterministic, GUID-deduplicated snapshot of at most five hostiles visible
  through selected, mouseover, pet-target, and party/raid-target unit tokens,
  with target-local health, aura, resistance, modifier, geometry, victim, and
  threat projections; this is not full nameplate or encounter-roster discovery;
- DBC-derived per-effect recipient topology and installed-client radius data.
  Proven target- and caster-centered circles retain geometry for multiple
  observed hostiles, but the stock unit-token snapshot is not exhaustive, so
  secondary benefit is withheld while known collateral pull risk still counts.
  Cones, chain secondaries, ground/dynamic-object placement, and unknown radii
  remain explicit unknowns rather than invented extra damage;
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
- target-local in-flight events: Auto Shot projectiles and companion autocasts
  retain the opaque hostile GUID captured at launch/scheduling across a later
  selected-target change instead of damaging the new selected-target mirror;
- a final selected-hostile dispatch guard that rechecks identity, relation,
  hostility, death state, and companion dual-target requirements before any
  hostile queue, Auto Shot, pet ability, or attack command can execute.

See [docs/graph-model.md](docs/graph-model.md) for evidence boundaries and current
limitations.

## Validation

```sh
python3 scripts/validate_xelassist.py
```

This validates the TOC and XML, Lua 5.0 policy, absence of typed rotations,
execution boundaries, real Lua graph scenarios, a clean installable archive, and
a mocked full TOC-order load through initialization, recommendation UI, settings,
and minimap construction. These checks prove local model and load behavior, not
authenticated in-world combat behavior on an Octowow character.
