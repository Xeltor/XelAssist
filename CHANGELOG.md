# Changelog

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
