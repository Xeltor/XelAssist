# Changelog

## 0.5.1

- Replaced hover-only future icons with a readable action-contract runway. The
  current and predicted steps now expose actor, target, action, modeled start
  time, and `LIVE`/`MODEL`/`EST`/`OPEN` evidence state without relying on color.
- Kept future steps read-only and made the current-action tooltip state the
  execution boundary explicitly: each click or `/xa` press re-evaluates current
  state and performs at most one action.
- Disabled and desaturated the primary button when the graph holds, collapsed
  stale predictions on errors or missing dependencies, restored execution on a
  later valid plan, and added deterministic UI-state/click-cardinality coverage.

## 0.5.0

- Split stateless delivery mechanics and attributable target-modifier discovery
  out of the resistance and graph monoliths. Resistance remains the sole owner
  of target profiles/submissions/mitigation, Delivery owns ordinary-hit traits,
  weapon/Defense keys and evidence records, and observations can recover active
  modifiers without depending back on graph search.
- Added a target resistance subsystem that prefers capability-proven Turtle
  `UnitResistance` Armor/school values and learns privacy-safe NPC profiles from
  exact Nampower damage and miss events when live target data is unavailable.
- Separated ordinary, physical, and binary-combined delivery evidence from
  landed-hit mitigation so periodic ticks cannot inflate application success;
  exact outcomes train the appropriate roll without becoming false raw-resistance proof.
- Split tooltip-confirmed hybrid spells such as Immolate into separately modeled
  direct and periodic shares with one application roll, including reduced
  periodic resistance, negative vulnerability, and future tick transitions.
- Applied expected post-mitigation power before damage utility, overkill, DoT
  lifetime, future target health, leech, and threat calculations; the selected
  plan and tooltip now expose school, source, confidence, and comparison reason.
- Added equipped spell/armor penetration discovery, DBC binary and
  correctly decoded normal-ranged/always-hit/ignore-resistance semantics,
  armor-ignoring bleeds, observed dynamic schools, and weighted Physical/Nature
  mixed damage. Positive-resistance bypass retains negative vulnerability, while
  physical always-hit remains conservative about later weapon-table mechanics.
- Keyed observed wand/seal/pet-result schools to their current source, propagated
  component-local penetration uncertainty, and combined resistance plus
  vulnerability per component instead of multiplying aggregate averages.
- Added Turtle's high-resistance mitigation bend and exact integer-truncated
  level-difference resistance (including Holy), target-field availability guards,
  capped/decaying context learning, and session-only handling for player targets.
- Isolated learned mitigation by the resistance modifier active at application,
  direct impact, or periodic tick time; projected debuffs can improve a learned
  baseline without polluting it when no raw target vector is available.
- Added actual main/off/ranged and no-weapon-form skill against NPC or PvP
  Defense, observable PvP Defense bonuses, DBC-aware actual-skill versus
  level-max attacks, broken-off-hand-aware white dual-wield miss, and exact
  outcome fingerprints for hand, skill, equipment or form, front/behind
  position, and target Defense. The cold prior now exposes omitted +hit and
  active-defense sub-rolls instead of presenting skill-versus-Defense as total
  hit chance.
- Wired Nampower's resolved player/pet white-swing stream into delivery-only
  learning, with main/off-hand selection, full-block and active-defense failures,
  full-absorb/resist success, melee-spell packet exclusion, and an explicit
  white-versus-yellow table key. DBC `DmgClass` now selects delivery independently
  from school; only MAGIC normal-ranged attacks override to weapon delivery, and
  exact Combat Range index 2 selects actual weapon skill.
- Kept elemental physical mechanic rejects independent of school-resistance
  modifiers and restored facts-derived melee/ranged subtypes on delayed events,
  preventing exact evidence from being discarded or written under the wrong
  graph edge.
- Withheld modifier-dependent mitigation and binary evidence from off-target
  ticks/rejects when a target swap makes the old target's current debuffs
  unknowable; submission-time direct impacts retain their captured state.
- Probability-weighted binary debuffs, control, taunts, and interrupts before
  valuing them or projecting their resistance and damage-taken changes.
- Added attributable active target modifiers, causal debuff-path coverage,
  projected modifier expiry, retained setup exploration, uncertain-refresh
  failure state, and resistance-aware damage-plus-interrupt/leech value.
- Re-evaluated stored DoTs, channels, and ambient pet autocasts across modifier
  timing boundaries; added generic own-caster exclusive families so a new
  Warlock curse replaces the player's old curse without erasing another
  Warlock's attributable curse.
- Enabled and audited the gated Nampower aura/start/go evidence CVars, registered
  the Nampower 4.5+ auto-attack stream, accounted for unconditional damage/miss
  streams, and corrected exact player/pet argument mapping.
- Hardened finite consumables as default-off character policy, excluded
  equippable items, re-resolved exact item identity before use, consumed future
  counts, and used native individual/category cooldown evidence when available.
- Added target-scoped nonlocalized Nampower cast/go/fail/miss/aura lifecycle
  handling, actor-specific LoS, UnitXP behind/LoS geometry, channel occupancy,
  interrupt deadlines, terminal targets, combo transitions, true absorb state,
  reagent counts, and polarity-correct buff/debuff-cap application evidence.
- Added structured encounter/target identity, ally and controlled-actor
  collections, ClassicAPI aura ownership/stacks/timing/dispel/boss metadata, and
  ambient pet autocast transitions in copied future graph branches.
- Added focused resistance/action semantics tests and end-to-end graph coverage
  proving school selection, hybrid transitions, component math, learned delivery,
  and debuff-then-exploit choices with negative controls.
- Added a source-aware Lua 5.0 syntax guard and verified every production file
  with the official Lua 5.0.3 compiler.

## 0.4.0

- Added generic controlled-actor state with independent player/pet clocks.
- Added live pet spellbook and action-bar discovery, ranks, resource, health,
  target, range, cooldown, usability, autocast metadata, and commands.
- Added Warlock demon semantics for threat, interrupts, dispels, crowd control,
  buffs, self-healing, Sacrifice, and shard-aware summoning.
- Added companion action, control, and threat policies plus companion-marked
  current and predicted actions in the compact decision runway.
- Added deterministic scenarios for pet actions during player downtime, resource
  isolation, attack/retreat, taunt policy, dispels, Sacrifice, summoning, shard
  availability, and Consume Shadows combat safety.
- Added target-scoped pending aura applications to prevent duplicate DoT casts
  during cast/server-aura latency, with immediate failure, movement interruption,
  miss, and resist retry handling.
- Added realizable-tick and mana valuation so short-lived targets can favor
  direct damage or wanding over a DoT that cannot pay back its cost.
- Added target/action-scoped combat observations: resist and miss permit retry,
  while explicit immunity and line-of-sight failures create short conservative
  graph blockers without inventing permanent immunity knowledge.
- Added decaying target-school resistance evidence so repeated resists reduce
  expected value across related damage actions without becoming a boolean ban.
- Added pre-cast Nampower target resistance-vector discovery and level-scaled
  expected mitigation, allowing the graph to favor a better damage school from
  the first recommendation while retaining observed-outcome fallback.
- Added structured equipment durability and ammunition state, including
  Hunter ranged-weapon/ammunition constraints that do not affect caster spells.
- Added opt-in bag-discovered immediate healing and mana consumables with live
  tooltip magnitude, cooldown, effective restoration, waste, execution, and
  projected cooldown/resource/health state; food and ambiguous items are excluded.

## 0.3.0

- Replaced typed class priority lists with a spellbook-discovered semantic action graph.
- Added ranked DBC/tooltip facts, exact health, cast/GCD/cooldown/range modeling,
  role and aggro-aware threat, downranking, spell/weapon scaling, and bounded beam search.
- Added a compact current-plus-future decision runway with evidence-rich tooltips.
- Added per-character intent, role, graph-depth, and optional-action settings plus
  global display controls and a minimap entry point.
- Added `/xa` macro execution guidance and a privacy-safe per-character decision trace.
- Added deterministic Lua scenarios, Nampower capability contracts, and a mocked
  TOC-order addon/UI initialization test.
- Added talent-change invalidation and a verified clean-archive packaging path.
- Added conservative tooltip inference for unknown active spells, live long-cooldown
  policy enforcement, NPC-capable hitbox range priority, and durable runtime diagnostics.
- Corrected selected-target execution to use Nampower's one-spell queue while
  preserving explicit friendly, self, and ground targeting.
