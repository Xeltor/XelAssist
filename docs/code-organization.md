# XelAssist code organization

XelAssist targets the Octowow 1.12 client and its Lua 5.0 runtime. The addon is
organized for human review first: folders name responsibilities, files have one
reason to change, and the TOC is the only runtime dependency manifest.

## Runtime tree

```text
Core/       bootstrap, lifecycle, commands, events, and guarded execution boundary
Game/       client API discovery and live actor, ally, hostile, topology, and item state
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
  score recommendations, or persist learned combat outcomes.
  `Game/Range.lua` owns normalized native spell verdicts and pure independent
  command/effect bands so planning and final dispatch cannot disagree.
  `Game/Geometry.lua` exposes only proven positioning evidence and deliberately
  excludes UnitXP's non-authoritative `inSight` hint. `Game/ResourceExchange.lua`
  classifies exact DBC-backed health/resource conversions and tooltip magnitude.
  `Game/SoulShards.lua` owns live shard inventory, the character reserve, and
  level-scaled target-yield evidence without prescribing a Warlock sequence.
  `Game/HitBonuses.lua` owns the capability-gated equipped-hit snapshot and
  keeps unresolved talent/aura contributions explicit.
  `Game/Hostiles.lua` owns bounded GUID-deduplicated hostile observation and
  `Game/HostileEngagement.lua` owns exact victim-linked active-fight evidence,
  while `Game/HostileCasts.lua` owns the bounded session-only cast ledger and
  `Game/HostileSpellFacts.lua` admits only conservative direct single-recipient
  DBC consequences. `Game/TargetSurvival.lua` owns bounded session-only
  exact-health trend evidence without persisting or rendering opaque identity, and
  `Game/SpellTopology.lua` translates installed-client DBC effect-target and
  radius fields without deciding which action is useful. Its compact `Facts`
  output remains graph-facing, while `Describe` exposes fresh rich target-enum
  metadata only to explicit mechanics decoders. `Game/SpellSemantics.lua`
  owns cached raw DBC evidence, mutation-isolated per-effect mechanic atoms,
  contextual recipient resolution, and bounded immediate-trigger traversal.
  Only explicitly audited consumers are permitted: Druid form discovery and
  the bounded pre-search dispel-capture adapter. Static validation rejects any
  other recommendation caller. The session-only
  `Game/Pets/EffectRuntime.lua` ledger correlates confirmed casts, observable
  pet auras, and exact melee outcomes so fresh snapshots retain pet effects
  without writing opaque identities or inferred state to saved variables.
  `Game/Pets/FocusEvidence.lua` owns session-only Hunter cadence learning,
  `FocusEvents.lua` owns standard/Nampower invalidation and attribution events,
  and `Resources.lua` owns conservative graph-clock arithmetic.
  `Game/Pets/HunterControl.lua` seals exact installed-client Web, Charge, and
  Intimidation trigger chains; `Graph/HunterControl.lua` alone turns those
  facts into target-local control and deferred-melee consequences.
  `Game/AttackRounds.lua` owns session-only classified companion swing evidence,
  `AttackRoundEvents.lua` owns its invalidation boundary, and
  `PlayerAttack.lua` owns idempotent live player-Attack submission.
  `Game/Player/AttackRounds.lua` and `AttackRoundEvents.lua` own exact,
  target-pinned player main-hand phase evidence. `Game/Player/OnSwing.lua` owns
  one exact Nampower 4.7.1 attempt-generation lane with a conservative 4.7.0
  fallback, while `OnSwingEvents.lua` bridges native state and actual GO/miss
  recipients into graph evidence. None persists
  an actor identity or hardcodes a private-server regeneration rate.
  `Game/Player/Engagement.lua` owns exact DBC Attack-start/stop and stealth
  semantics. `Game/Player/ChannelRuntime.lua` owns the bounded native-event
  fallback for active player channel identity. `EnergyEvidence.lua` and
  `EnergyEvents.lua` own live player-energy cadence learning, while
  `ManaEvidence.lua` and `ManaEvents.lua` separately learn attributed passive
  mana and exact post-spend recovery. `Resources.lua` owns shared conservative
  projection arithmetic. Focused player-class evidence lives beside those
  resources: `MageManaShield.lua`, `PriestShield.lua`, `DruidProwl.lua`,
  `PriestShadowform.lua`, `RogueFeint.lua`, `HunterMark.lua`,
  `ShamanWindfuryTotem.lua`, `WarriorStanceEffects.lua`, and
  `PaladinBlessingThreat.lua` each seal one installed mechanic without scoring
  or ordering its class. `Game/SpatialEvidence.lua` owns immediate
  blocking and settled recovery for noisy live geometry edges.
- `Combat` owns declarative player and companion spell meaning, stateless
  delivery rules, transient observations, and target evidence. Pet knowledge is
  ID-first metadata over live-discovered actions, never a family priority list.
  `Combat/Wand.lua` owns native Shoot-slot discovery, repeat observation, live
  ranged stats, and the bounded submission latch. It does not depend on graph
  search.
- `Game/SpellPower.lua` decodes OctoWoW's VMaNGOS weapon-effect aggregation
  from live Spell.dbc rows. `Game/SpellEffectPower.lua` derives only complete
  scalar direct/periodic totals from installed-client effect arrays.
  `Game/TargetModifierFacts.lua` owns exact rank-safe DBC armor, resistance,
  damage-taken, and per-combo modifier shapes for both learned actions and
  attributable active auras; it contains no action ordering.
  `Game/RootAuraEvidence.lua` owns one bounded helpful or harmful aura-name
  snapshot per recipient and evaluation. It exposes only frozen presence or
  conservative unknown evidence to `Graph/RootObservation.lua`; rank-heavy
  action books never rescan the same unit once per candidate.
  `Game/RootPowerEvidence.lua` similarly shares only identical weapon and
  school-power lanes inside one evaluation while preserving separate immutable
  action records.
  `Game/HealthTransfer.lua` recognizes exact health-funded companion-channel
  signatures and exposes their start, upkeep, cadence, and per-tick healing
  without converting health power into mana cost. `Game/SpellFactCache.lua`
  keeps actor-identity-bound tooltip/DBC facts local to the current player or
  companion. `Game/WeaponPower.lua` owns the ordinary and
  normalized live equipped-weapon basis. `Graph/ActionPower.lua` combines those
  facts with scripted effects, tooltip evidence, and spell power;
  strategic utility and delivery stay outside raw potency.
- `Graph/State.lua` is the live observation boundary for planning, and
  `Graph/HostileState.lua` owns target-local copies, context switching, and
  commits back to the canonical bounded hostile collection.
  `Graph/HostileCastState.lua` isolates live cast generations per graph branch;
  `Graph/IncomingConsequences.lua` owns exact-recipient damage, healing, and
  projected-absorb consumption; `Graph/HostileCastEvents.lua` owns completion
  ordering and interrupt cancellation; and `Graph/IncomingScoring.lua` exposes
  those consequences to healing and absorb value without broadening admission.
  `Graph/IncomingAbsorbs.lua`, `MageManaShieldScoring.lua`, and
  `FriendlyActionEffects.lua` keep shield ordering, school eligibility, and
  friendly projection outside the generic coordinators. `Graph/RogueFeint.lua`
  owns selected-hostile threat reduction, while `PaladinBlessingThreat.lua`
  composes a proven recipient-owned multiplier through `PlayerThreat.lua`.
  `Graph/HunterMark.lua`, `PriestShadowform.lua`, and
  `ShamanWindfuryTotem.lua` own target-local ranged power, form-conditioned
  outgoing/incoming multipliers, and solo main-hand proc consequences.
  `Graph/SurvivalPressure.lua` converts learned target pressure into bounded
  cast, channel, periodic, and hostile-setup payoff without defining class
  strategy. `Graph/PeriodicScoring.lua` owns periodic combat progress and
  role/output weighting, leaving the main scoring coordinator human-sized.
  `Graph/DotProjection.lua` owns the direct/periodic transition split and keeps
  that expected survival factor causal across later aura ticks.
  `Graph/ChannelCommitment.lua` owns the remaining-value comparison between
  continuing and deliberately clipping a live player channel;
  `Graph/HealthTransfer.lua` contributes exact nonlethal payment, tick healing,
  incoming-damage ordering, and partial-channel value for health-funded support.
  `Graph/WandCommitment.lua` owns sustained Shoot continuation and clipping;
  `Graph/ResourceExchange.lua` owns conversion legality, value, and atomic
  state transitions; `Graph/ResourceInvestment.lua` retains a bounded setup
  lane only until later resource consumption proves its payoff;
  `Graph/PlayerResourceTimeline.lua` owns the causal start boundary that keeps
  pre-cast waits distinct from exact post-spend mana recovery;
  `Graph/SoulShardReserve.lua` prices bounded stock,
  eligible generation, and marginal consumption; `Graph/CooldownLedger.lua`
  captures exact-rank readiness
  once at the root and supplies pure projected clocks to descendants.
  `Graph/AreaRecipients.lua` resolves conservative per-effect recipient sets;
  `Graph/HostileTargetPolicy.lua` owns the default-off exclusions and authority
  for ordinary GUID-addressed engaged-enemy spells;
  `Graph/HostileEffects.lua` applies eligible hostile-local effects without
  spending one action more than once. `Graph/AutoShotEffects.lua` and
  `Graph/CompanionEvents.lua` own target-pinned ambient events;
  `Graph/PlayerSwings.lua` owns player main-hand and on-next-swing timeline
  consequences, while `Graph/PlayerSwingScoring.lua` owns displaced-white
  marginal utility;
  `Graph/CompanionTargets.lua` owns their identity boundary and
  `Graph/CompanionSwings.lua` owns ordinary melee scheduling.
  `Graph/CompanionScheduler.lua` arbitrates one pet cast/GCD clock;
  its resource, tie, cast-event, and cast-runtime helpers each own one phase of
  causal scheduling, while unknown cost makes later affordability inexact.
  `Graph/CompanionEventThreat.lua` owns companion threat consequences,
  `Graph/EventAuras.lua` owns GUID-keyed clocks for auras those events create,
  and `Graph/ReadinessEffects.lua` owns chosen-action cooldown clocks.
  `Graph/AmbientTargetHealth.lua` proves when scoring can skip an otherwise
  redundant causal health copy; `Graph/Timeline.lua` orders projected combat
  events without owning their mechanics. `Graph/ActorScoring.lua` and
  `Graph/ThreatScoring.lua` keep
  controlled-actor utility, actor-owned threat, and delivered
  damage-per-resource value out of core potency scoring.
  `Graph/PlayerEngagement.lua` projects productive Attack starts;
  `Graph/StealthSetup.lua` owns target-pinned conditional stealth approach
  opportunities without projecting movement; `Graph/ComboState.lua`,
  `ComboEffects.lua`, and `ComboScoring.lua` own target-owned probabilistic DBC
  combo transitions, combo-scaled durations, and marginal efficiency;
  `Graph/SearchPolicy.lua` owns the
  automatic active-CPU/state horizon independently of visible HUD rows, while
  `Graph/RootObservation.lua` slices mutable client capture and shares identical
  weapon-basis, school-power, and recipient-aura evidence only inside that one
  root snapshot. Sealing removes every live source reference before search.
  `Graph/SearchSession.lua` carries deterministic Lua 5.0 table cursors across
  short frame slices and exposes only complete accepted paths. The synchronous
  graph facade consumes the same continuation without yielding, so tests and
  production cannot drift into separate search algorithms. In addition,
  `Graph/SearchBranches.lua` protects distinct immediate/setup beam branches;
  `Graph/PlanDiagnostics.lua` describes only the selected path's terminal gate
  without inventing an executable wait or action.
  Targeting, scoring, transitions, and search consume passed state and do not
  mutate live game state.
- `UI` renders plans and settings. `UI/Theme.lua` owns the shared combat-instrument
  tokens and icon chrome, while `UI/CooldownPolicy.lua` explains only the
  live-discovered actions governed by the major-cooldown policy. The visual HUD
  remains fixed-height and owns no update callback;
  `UI/RecommendationController.lua` keeps its UIParent-owned producer alive even
  while the visual frame is hidden, resumes one graph slice per frame, and uses
  epoch tickets to publish a complete current plan atomically. Target changes
  start replacement work on the next frame; physical input only consumes the
  finished one-shot snapshot. `UI/RunwayPlaceholder.lua` distinguishes path-local gates,
  graph time, and bounded search without inventing future actions, while
  `UI/RunwayRenderer.lua` incrementally paints only visibly changed future
  slots and refreshes their underlying tooltip contracts independently.
  `UI/SurvivalTooltip.lua` renders the privacy-safe survival evidence contract.
  `UI/HUDCooldown.lua`
  suppresses duplicate native timer writes, while
  `UI/RecommendationStability.lua` atomically publishes material compatible
  paths without mixing branches. UI modules do not score actions or execute
  recommendation publications.
- `Core` owns startup and the one-input execution boundary.
  `Core/RecommendationSnapshot.lua` atomically publishes one-shot, mode-matched
  plans outside the input call, while `Core/DispatchReadiness.lua` owns the final
  live player/companion usability check before dispatch.
  `Core/DecisionLog.lua` owns bounded privacy-safe history and event status
  correlation; `Core/Diagnostics.lua` owns the durable capability/evidence audit.
  `Core/TargetGuard.lua` pins selected and explicitly engaged hostile dispatch
  to the captured identity and revalidates exact live authority after actor and
  range checks without changing the selected target.
  `Core/PlayerNormalQueue.lua` owns session-only evidence for Nampower's single
  normal-GCD queue slot and consumes Nampower 4.7.0+'s opaque attempt-result
  identity; it does not merge on-swing or non-GCD queue classes.
  `Core/PlayerQueueEvents.lua` gates queue evidence before it can change graph
  reservations, keeping same-spell attempt generations isolated.
  `Core/CastEventRouter.lua` normalizes Nampower and SuperWoW cast lifecycles
  before routing them to the hostile ledger or existing owned actor lanes.
  `Core/AuraApplicationReservations.lua` owns exact landing, visibility-gap,
  aura-cap uncertainty, and cast-pushback extensions after the base reservation
  module establishes identity and lifecycle records.
  Cast, queue, item, pet-command, and any future target-changing APIs must remain
  on that boundary.

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
| `UI/HUD.lua` | formatting, tooltip, layout, recommendation presenter |

## Enforcement

`python3 scripts/validate_xelassist.py` resolves production Lua from the TOC and
fails for duplicate/missing/orphan modules, root-level `XelAssist_*.lua` files,
post-Lua-5.0 syntax, forbidden execution shortcuts, or a file growing beyond
its architecture ceiling. The mocked full-load test also reads the TOC directly,
so tests, packages, and the client share one load order.
