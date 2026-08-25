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
  `Game/HitBonuses.lua` owns the capability-gated equipped-hit snapshot and
  keeps unresolved talent/aura contributions explicit.
  `Game/Hostiles.lua` owns bounded GUID-deduplicated hostile observation, while
  `Game/SpellTopology.lua` translates installed-client DBC effect-target and
  radius fields without deciding which action is useful. The session-only
  `Game/Pets/EffectRuntime.lua` ledger correlates confirmed casts, observable
  pet auras, and exact melee outcomes so fresh snapshots retain pet effects
  without writing opaque identities or inferred state to saved variables.
  `Game/Pets/FocusEvidence.lua` owns session-only Hunter cadence learning,
  `FocusEvents.lua` owns standard/Nampower invalidation and attribution events,
  and `Resources.lua` owns conservative graph-clock arithmetic.
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
  fallback for active player channel identity. `EnergyEvidence.lua`,
  `EnergyEvents.lua`, and `Resources.lua` own
  live player-energy cadence learning, attribution/reset events, and projected
  resource arithmetic respectively. `Game/SpatialEvidence.lua` owns immediate
  blocking and settled recovery for noisy live geometry edges.
- `Combat` owns declarative player and companion spell meaning, stateless
  delivery rules, transient observations, and target evidence. Pet knowledge is
  ID-first metadata over live-discovered actions, never a family priority list.
  It does not depend on graph search.
- `Game/SpellPower.lua` decodes OctoWoW's VMaNGOS weapon-effect aggregation
  from live Spell.dbc rows. `Game/WeaponPower.lua` owns the ordinary and
  normalized live equipped-weapon basis. `Graph/ActionPower.lua` combines those
  facts with scripted effects, tooltip evidence, and spell power;
  strategic utility and delivery stay outside raw potency.
- `Graph/State.lua` is the live observation boundary for planning, and
  `Graph/HostileState.lua` owns target-local copies, context switching, and
  commits back to the canonical bounded hostile collection.
  `Graph/ChannelCommitment.lua` owns the remaining-value comparison between
  continuing and deliberately clipping a live player channel.
  `Graph/AreaRecipients.lua` resolves conservative per-effect recipient sets;
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
  `Graph/Timeline.lua` orders projected combat events without owning their
  mechanics. `Graph/ActorScoring.lua` and `Graph/ThreatScoring.lua` keep
  controlled-actor utility, actor-owned threat, and delivered
  damage-per-resource value out of core potency scoring.
  `Graph/PlayerEngagement.lua` projects productive Attack starts;
  `Graph/StealthSetup.lua` owns target-pinned conditional stealth approach
  opportunities without projecting movement; `Graph/ComboState.lua`,
  `ComboEffects.lua`, and `ComboScoring.lua` own target-owned probabilistic DBC
  combo transitions, combo-scaled durations, and marginal efficiency;
  `Graph/SearchPolicy.lua` owns the
  automatic time/state horizon independently of visible HUD rows, and
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
  while the visual frame is hidden and publishes complete plans after target
  changes settle. `UI/RunwayPlaceholder.lua` distinguishes path-local gates,
  graph time, and bounded search without inventing future actions.
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
  `Core/TargetGuard.lua` pins hostile dispatch to the captured selected-target
  identity and revalidates it around actor/range checks.
  `Core/PlayerNormalQueue.lua` owns session-only evidence for Nampower's single
  normal-GCD queue slot and consumes Nampower 4.7.0+'s opaque attempt-result
  identity; it does not merge on-swing or non-GCD queue classes.
  `Core/PlayerQueueEvents.lua` gates queue evidence before it can change graph
  reservations, keeping same-spell attempt generations isolated.
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
| `Core/Runtime.lua` | startup/commands versus combat-event routing |
| `UI/HUD.lua` | formatting, tooltip, layout, recommendation presenter |

## Enforcement

`python3 scripts/validate_xelassist.py` resolves production Lua from the TOC and
fails for duplicate/missing/orphan modules, root-level `XelAssist_*.lua` files,
post-Lua-5.0 syntax, forbidden execution shortcuts, or a file growing beyond
its architecture ceiling. The mocked full-load test also reads the TOC directly,
so tests, packages, and the client share one load order.
