# XelAssist action graph

## Boundary

XelAssist does not encode `A → B → C` rotations. `XelAssist_Actions.lua` only
describes semantics the client cannot reliably infer from a spell name: damage,
healing, periodic effects, interrupts, threat modifiers, ground targeting,
resource recovery, optional cooldown/reagent use, and special prerequisites.
Weights and ordering do not live in that file.

For a spell absent from that cheat sheet, an unambiguous active-spell tooltip can
conservatively infer damage, periodic damage, healing, periodic healing, absorb,
interrupt, defensive, or resource semantics. Passives and ambiguous utility are
excluded, and inferred nodes are visibly marked as estimated.

The spellbook supplies the available nodes and every learned rank. Live state and
client records supply edges and costs. The same evaluator scores every class.

## Evidence order

1. Live authoritative verdicts: known spellbook slot, `IsSpellUsable`, cooldown,
   `IsSpellInRange`, current cast/GCD, aura presence, target state, resources,
   exact Nampower unit health, movement, pet, combo points, and target-of-target aggro.
   UnitXP's NPC-capable hitbox distance is preferred over center/player-only
   distance fallbacks when a direct spell-range verdict is unavailable.
   Explicit combat-log miss/resist/immunity outcomes and UI line-of-sight errors
   are retained briefly against the exact target and action that produced them.
   Nampower's target `resistances` vector supplies Armor/Holy/Fire/Nature/Frost/
   Shadow/Arcane values before the first cast and reflects the current unit state.
2. Nampower spell/unit records: spell ID, rank, mana/resource cost, cast time,
   GCD, own/shared cooldown, duration, range band, effect base values, weapon
   damage, exact health, and school-specific bonus damage.
3. The client tooltip: talent-adjusted cost and displayed damage/healing ranges;
   cached facts are invalidated when the client reports changed talent points.
4. Conservative estimation from rank and cost when neither record nor tooltip
   exposes effect magnitude. The UI labels the result `estimated`; otherwise it
   says `client data`, which describes provenance rather than promising exact
   post-mitigation output.

An explicit false can block. Missing capability data remains unknown. That
asymmetry favors one failed physical press over silently excluding a lifesaving
action.

## Search state

The root state records current and target health, resources, movement, combat
state, cast/GCD remaining, group size, inferred/configured tank role, aggro,
range, aura state, controlled actors, and future ready times. Player and pet
clocks are independent: a pet interrupt can remain immediately available while
the player is casting. Applying a candidate advances the responsible actor's
clock and updates that actor's resource, health, targets, auras, threat state,
summon/sacrifice state, dispels, and known cooldowns before the next layer.
Equipped main-hand, off-hand, ranged weapon, durability, ammunition identity,
and ammunition count are structured state. Explicit ammunition users are
blocked at zero ammo, broken melee weapons block melee weapon actions, and a
broken ranged weapon blocks weapon-ranged actions; ordinary ranged spells do
not inherit those constraints.
Immediate-use health and mana restoratives are discovered from live bag tooltips
as item action nodes with bag location, count, effect range, cooldown, actor, and
future state. Food, over-time restoration, and ambiguous item effects are not
admitted. Item use is character opt-in and remains one action for one input.

The bounded beam compares complete discounted paths, so a future cooldown, aura,
resource shortage, or downtime can change which current action wins. It returns
one executable action plus up to four simulated future actions.
Future nodes are predictions, not queued casts; every `/xa` press takes a fresh
snapshot and may choose differently.

## Utility and safety

- Damage is valued by effective output per occupied GCD/cast window. Output past
  the target's remaining health is not rewarded.
- Periodic damage is capped to the damage an exact-health target can still
  consume, then charged for unrealized ticks and mana. This allows a direct or
  zero-mana recovery action such as Shoot to beat a DoT on a dying target.
- A submitted DoT/debuff/CC becomes a target-scoped pending edge immediately.
  It stays unavailable through cast completion and the short aura-visibility
  delay, preventing tap-driven duplicate casts. Confirmed cast failure or
  interruption (including movement interrupting a cast), miss, or resist clears
  the edge so the next press may retry; immunity is deliberately not treated as
  a retry signal.
- Healing is capped by missing health, then balanced against cost, downtime, and
  overheal. This lets a lower rank win without a downrank rule.
- Non-tanks receive a threat penalty in groups. When they already hold aggro the
  penalty steepens, allowing lower-rank/lower-threat actions or a threat drop to
  win from the same utility equation.
- Interrupts preempt throughput only during a detected cast. Cast-time actions
  are excluded while moving. Direct range verdicts are authoritative; discovered
  minimum/maximum bands cover units where no direct verdict exists. Reactive
  abilities require an explicit usable result.
- Major cooldowns, including unknown actions whose client record reports at
  least 30 seconds, reagents, and incidental area damage remain character opt-ins.
- Pet nodes come from the live pet spellbook plus executable action-bar slots.
  Autocast-enabled abilities are represented as ambient ownership and are not
  redundantly recommended for manual execution. Warlock demon semantics include
  threat, interrupts, dispels, crowd control, Consume Shadows, Sacrifice, and
  shard-aware summoning without keying decisions to localized demon family names.
- Evaluation errors, missing dependencies, and budget overruns hold without a cast.

## Known evidence gaps

- Target-of-target is an aggro signal, not a numeric threat meter. XelAssist can
  react to ownership of aggro and relative spell threat but cannot know the tank's
  exact threat lead from the current APIs.
- Vanilla hostile health may be percentage-scaled. Damage-to-health and finisher
  math is enabled only when Nampower exposes exact `health` and `maxHealth` fields.
- Tooltip/DBC effect magnitude is still estimated for weapon formulas, triggered
  child spells, absorb formulas, and effects whose final value depends on server
  scripts. Those recommendations are visibly marked `estimated` and logged.
- Future movement, target swaps, incoming damage, other players' casts, proc
  arrivals, and shared cooldown categories cannot be predicted. Re-evaluation on
  every physical press is the correctness boundary.
- Autocast state is observed, but autonomous future pet casts are not yet inserted
  as timed graph events. Pet line of sight, pathing, exact numeric threat lead,
  command stance, and encounter hazards remain unknown unless the client exposes
  them; they are not silently treated as safe.
- Observed immunity is deliberately spell-and-target scoped and expires after a
  short anti-loop window; XelAssist does not infer a permanent creature or school
  immunity from one event. Observed line-of-sight failure is target scoped and
  expires quickly because either actor may move.
- Full-resist evidence also feeds a separate target-and-damage-school edge. It
  decays over time and discounts expected damage across actions of that school;
  it never becomes a hard immunity conclusion. Physical and unrelated schools
  remain independent.
- When the live resistance vector exists, magical damage is discounted by its
  level-scaled average mitigation (`resistance / (playerLevel * 5)`, capped at
  75%). This is a relative expected-value input, not a promise of the discrete
  partial-resist result of the next cast. Learned outcomes are the fallback when
  the live vector is unavailable.
- Real client play remains the final authority for UI dimensions, custom spell
  records, and server-side mechanics. The local scenario suite proves evaluator
  behavior and load order, not live combat outcomes.

## Runtime evidence loop

`XelAssistLog` keeps the latest 200 executed decisions per character, including
rank, reason, confidence, utility, modeled downtime/threat, health/resources,
movement, aggro, role, and distance. It deliberately omits player and target names.
This turns future tuning into a comparison against real recommendations instead
of a rewrite of a hand-authored rotation.

`XelAssistCharDB.runtime` records a privacy-safe load audit: addon/schema and
dependency versions, guarded API availability, discovered/inferred node counts,
load time, and the latest graph failure. `/xa diagnostics` refreshes and prints
that evidence without player, realm, target, or party names.
