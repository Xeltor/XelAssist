# Changelog

## 0.8.30

- Added Warrior Charge as an exact causal engage edge. The installed rank
  generates 9, 12, or 15 rage and grants only same-target ordinary melee reach;
  it does not invent damage, threat, a rear arc, a white swing, or Attack state.
- Required sealed positive usability and an out-of-combat root state before
  Charge can enter the graph, then revalidated live usability and combat state
  at dispatch so a stale recommendation cannot fire after combat begins. A
  target-scoped in-flight reservation closes the off-GCD repeat-tap latency
  window, and later movement invalidates old Charge-arrival evidence.
- Added zero-rage level-4 runway, rank/cap/cooldown, range, target identity,
  dispatch-race, and no-invented-effects regressions. The production benchmark
  completes the new low-level workload in three slices under 10 ms active time
  while reading each action's mutable facts only during root observation.

## 0.8.29

- Added an exact-phase player melee continuation edge so a running Warrior
  attack can remain the safe current instruction while the graph advances
  ordinary main-hand rounds toward the next learned rage threshold or target
  defeat. Repeated macro input on any instruction is non-executable and cannot
  cancel or force-restart the continuous graph producer.
- Projected conservative outgoing white-hit rage from the vanilla level/damage
  conversion and applied it only when the ordinary swing actually resolves.
  Heroic Strike and other next-swing replacements still pay once and receive no
  duplicate white damage or white-hit rage.
- Normalized raw Spell.dbc rage costs from internal tenths to the displayed
  units returned by UnitMana, with full graph, load, and Lua 5.0 regressions.

## 0.8.28

- Added a cached, fail-closed installed-client spell-semantics decoder that
  preserves each effect as composable damage, healing, power, dispel, threat,
  taunt, summon, aura, form, and immediate-trigger atoms. Nine-class fixtures
  cover Taunt, Cleanse, Tranquilizing Shot, Adrenaline Rush, Dispel Magic,
  Searing Totem, Evocation, Dark Pact, and Cat Form, plus mixed Fireball,
  Regrowth, and Bloodrage mechanics.
- Expanded the single target-code registry to all 64 Nampower enum values and
  exposed fresh rich descriptors without changing the compact topology copied
  into graph snapshots. Target A/B identity, polymorphic units, scripted
  recipients, locations, objects, and deployables remain distinct and
  unresolved evidence stays fail-closed.
- Kept the new layer recommendation-neutral while its first compact consumer is
  designed. Static validation and full-load traps forbid production callers;
  descriptors are mutation-isolated, trigger traversal is cycle/depth/node
  bounded, positive and negative caches invalidate explicitly, and passive
  spells cannot enter inference. Deterministic Warlock search depth, edge
  counts, active time, and maximum slice metrics remain identical to 0.8.27.

## 0.8.27

- Added a reusable graph-native health-transfer channel primitive, initially
  backed by all seven exact installed-client Health Funnel ranks. It separates
  zero mana cost from initial and per-second player-health payments, heals the
  controlled companion only after each strictly nonlethal payment, and mirrors
  both actors' health through causal graph state.
- Integrated health-funded channels with incoming-damage ordering, partial
  overheal, movement/action interruption, replacement channels, and weighted
  continuation versus clipping. The graph plans only useful and affordable
  ticks; a same-timestamp hostile hit resolves before upkeep and can safely stop
  the channel without granting that tick's healing.
- Added exact rank-signature, same-name exclusion, delayed-start, stale-plan,
  implicit-pet-target, continuation-cadence, and no-mana regressions. Unverified
  Soul Funnel talent behavior remains explicitly outside the model.

## 0.8.26

- Added a generic bounded resource-investment lane. A health-to-mana action may
  survive an initially negative edge only until a later player action proves it
  needed the gained resource; unresolved conversions and needless self-harm can
  never become a published recommendation.
- Corrected Life Tap's live low-level economics. Resource gain is no longer
  mistaken for hostile threat, missing mana is no longer repeatedly credited to
  every future wand shot, and aggro risk scales with post-Tap health plus proven
  incoming damage instead of imposing a flat veto. Exact level-7 coverage keeps
  a two-Tap damage runway at full health while preserving low-health wand safety.
- Added an exact player-GUID normal-queue lane for self buffs such as Demon
  Armor. A self buff displayed during the current GCD can now be submitted by
  `/xa`; queue ownership, duplicate-aura guards, and exact result release remain
  intact, while future party actions still hold and non-GCD self actions remain
  direct.

## 0.8.25

- Added a frame-sliced, evaluation-owned root observation contract. The graph
  now seals cloned action metadata plus exact usability, cooldown, power,
  recipient aura, pending-application, range, ownership, inventory, and config
  evidence before search; migrated admission, potency, targeting, spatial,
  channel, stealth, wand, cooldown, and Soul Shard readers cannot fall back to
  mutable client APIs when that sealed evidence is present.
- Split combat changes into hard topology revisions and soft health, resource,
  aura, cast, pet, threat, engagement, readiness, and inventory domains. Hard
  changes cancel an obsolete continuation, while ordinary combat traffic is
  recorded without repeatedly starving frame-sliced work. Observation age now
  begins at the actual captured snapshot rather than the UI request.
- Added a bounded final publication guard for the selected action's actor and
  recipient identities, current resource and reagent availability, and pending
  applications. A stale completion is rejected and replaced without exposing a
  half-built or unsafe recommendation.
- Added deterministic production-graph Warlock benchmarks. A level-7 Imp and
  DoT workload completes in three slices with a 3.10 ms maximum test slice; a
  deliberately abusive 48-rank catalogue remains sliced and preserves exact
  synchronous plan parity.
- Removed the low-health companion command cycle that could alternate Passive,
  Follow, and Attack forever. Recovery now has a 25% entry and 35% release
  threshold, retreat commands are acknowledged and submitted once, nested pet
  attack-state evidence is honored, and the final dispatch boundary rejects a
  stale re-engage command while the companion is recovering. Active Consume
  Shadows is preserved instead of interrupted by its own retreat loop, while
  pending and continuing Mend Pet-style channels retain their remaining heal.

## 0.8.24

- Replaced synchronous HUD graph evaluation with a Lua 5.0-compatible search
  continuation. Work now resumes in short frame slices while retaining the
  existing active-CPU, state, beam, depth, and horizon budgets; only a complete
  accepted path can reach plan construction or publication.
- Decoupled physical macro input from graph production. A press consumes at
  most one fresh publication and merely ensures an already scheduled
  evaluation when none is ready, without repeatedly cancelling or restarting
  same-mode work. Epoch and freshness guards reject superseded target, mode,
  and state observations.
- Kept the last complete recommendation visibly dimmed and non-executable while
  a forced replacement is calculated. Target changes begin replacement work on
  the next frame, stable periodic results avoid repainting the HUD, and
  display-only settings no longer trigger graph work.
- Preserved exact aura reservations through incremental cast pushback and the
  server-to-aura-bar visibility gap. Exact owned application reconstructs a
  bounded guard after provisional expiry, while buff/debuff-cap uncertainty
  remains bar-specific and never falsely claims that the effect landed.
- Added per-plan slice count and maximum-frame-slice telemetry to the bounded
  decision log and HUD diagnostics, and extracted exact aura application
  lifecycle handling from the core reservation module.

## 0.8.23

- Derived complete direct and periodic damage totals from the installed
  Spell.dbc effect arrays. Explicit tooltip totals remain authoritative, while
  per-tick prose can no longer make Corruption, Immolate, or similar effects
  look like one-tick spells; unknown cadence and combo-scaled durations remain
  conservative rather than invented.
- Gave periodic damage the same combat-progress and damage-role treatment as
  direct spells, then bounded that value by learned target survival. Fresh
  Warlock targets can now prefer a worthwhile DoT, while a direct lethal cast
  still wins when the target will die before the aura pays back.
- Applied the same learned lifetime/payback pressure to hostile utility
  debuffs, preventing Curse of Weakness and similar setup from being selected
  at the end of a fight while retaining their value on durable targets.
- Scoped cached spell facts to actor identity, rank, level, spellbook, and slot
  so a newly summoned demon or Hunter pet cannot inherit stale facts from a
  prior companion that reused its action-bar position.
- Removed unused non-hostile and proven zero-ambient target-health timeline
  copies, memoized only equivalent repeated-rank forecasts within one
  evaluation, and exposed graph time, completed depth, expanded edges, budget
  state, and probe reuse in `/xa log` for privacy-safe in-client hitch evidence.

## 0.8.22

- Added a bounded, session-only hostile-cast ledger from exact Nampower and
  SuperWoW caster, target, spell, generation, and deadline evidence. Player and
  companion casts stay on their existing owned lanes; names and GUIDs are never
  persisted or rendered.
- Admitted only DBC-proven direct single-target damage and healing into graph
  consequences. Mixed, triggered, scripted, periodic, area, channel,
  unknown-level, and unresolved-recipient spells stay explicit unknowns. DBC
  magnitudes remain estimated: they cannot claim exact death or earn an exact
  lethal interrupt bonus.
- Made hostile impacts causal timeline events. Exact-deadline impacts resolve
  before the chosen action, graph-cancelled generations cannot deliver, known
  projected absorbs are consumed first, and exact player, pet, ally, or hostile
  health mirrors stay recipient-local.
- Replaced the duplicated flat interrupt bonuses with prevented-consequence
  value plus one bounded unsupported-cast fallback. Active incoming damage now
  informs pre-healing and absorb value without claiming unknown live shields.
- Reworked persistent cast, friendly effect, and hostile aura advancement from
  full-window pre-aging into event-step clocks. Intermediate events now observe
  the state at their actual time without double-aging event-created auras.
- Extracted cast routing from the runtime monolith into a dedicated module while
  preserving player queue, channel, companion, and pending-application behavior.
  Only owned or currently proven-hostile casters enter either lane; unrelated
  friendly and unknown casts cannot consume hostile ledger capacity.

## 0.8.21

- Added a default-off, character-specific engaged-enemy lane for ordinary
  single-target player spells. Exact hostile victim evidence may expose another
  enemy to graph scoring without changing the selected target; melee/builders,
  combo actions, reactive procs, pets, repeats, area/ground, and indirect actions stay
  selected-only.
- Kept every hostile's health, auras, resistance, threat, cast, encounter, and
  death projection target-local across scoring, ambient events, transitions,
  future selected/off-selected switches, and final plan publication.
- Hardened execution around exact GUID, relation, hostility, death, engagement,
  and range revalidation. Off-selected casts must be ready immediately and get
  one final live validation immediately before their GUID-pinned queue call.
- Precomputed bounded group engagement identities once per snapshot, withheld
  correlation-only combat guesses, suppressed movement advice for the wrong
  target, labeled engaged recipients in the HUD, and reported the policy in
  diagnostics.

## 0.8.20

- Modeled Warlock Life Tap as a graph-native atomic health-to-mana exchange.
  Its identity comes from the installed DBC signature even under localized
  names; exact tooltip magnitudes, lethal-health and full-mana gates, future
  resource state, and a dispatch pending guard prevent wasteful double taps.
- Added a bounded, character-specific Soul Shard stock model with a default
  reserve of three. Drain Soul gains stock value only for a credible eligible
  death during its channel, is strongly disfavored at the reserve, and shard
  consumers pay only the marginal cost of dipping below that reserve.
- Made wand Shoot an idempotent client-owned commitment. Native action-slot and
  repeat state, live wand damage/speed, target identity, movement, continuation,
  and weighted clipping now compete with casts and DoTs without a repeated
  macro press toggling an active wand off.
- Bound each executable companion action-bar slot to its exact learned spellbook
  rank, with a deterministic highest-rank fallback when bar rank text is not
  usable. Enabled Imp autocasts therefore produce one exact graph node instead
  of duplicate or mismatched ranks.
- Captured player and companion cooldowns once per root evaluation in an
  exact-rank ledger. Descendant graph states now project pure cooldown clocks
  without repeatedly calling live APIs during beam expansion.
- Removed UnitXP's unproven `inSight` hint from planning and dispatch gates.
  Exact range bands, hitboxes, behind evidence, movement, and actual client cast
  failures remain authoritative without inventing a line-of-sight model.

## 0.8.19

- Bounded synchronous graph work with the client's intra-frame profiler clock
  and counted every evaluated action-target edge. Rank-heavy Warlock spellbooks
  can no longer evade the time/state budget and monopolize each target frame;
  unchanged polling also drops from five evaluations per second to under three.
- Aged recommendations from the start of their live observation and revalidated
  actor, target, and reach before publication. A long search can no longer make
  stale geometry look newly sampled.
- Combined Nampower, ClassicAPI, DBC, and measured-distance range evidence
  conservatively, so one permissive result cannot override an explicit range
  rejection from another exact source.
- Separated observable current line of sight from future graph uncertainty.
  A current native rejection may still veto an action, but it is never copied
  forward as a predicted obstruction or guaranteed clear path.
- Split immutable plan assembly out of the search engine to keep the runtime
  modules within the repository's human-review size limit.

## 0.8.18

- Added bounded target-survival learning from exact hostile health trends.
  Recent all-source pressure now discounts casts, channels, and DoTs that are
  unlikely to land or pay back before death, while large heals, observation
  gaps, max-health changes, and inexact health reset the session-only evidence.
  Recommendation tooltips and privacy-safe logs expose the estimate, observed
  rate, confidence, and action-output factor.
- Kept survival evidence target-local across graph copies and made unsupported
  per-recipient area survival forecasting an explicit capability gap.

## 0.8.17

- Made runway painting incremental: a changed future branch updates only its
  affected slot, while identical visible conditional rows refresh their tooltip
  evidence without flashing the current card or stable prefix.

## 0.8.16

- Replaced the hard player-channel lock with competing continuation and clip
  branches. The graph prices remaining channel output, preserves independent
  Attack/Auto Shot actions, and can clip for a higher-value interrupt, heal,
  defensive, threat response, or damage action.
- Added exact active channel spell/target identity when the client exposes it,
  conservative unknown-channel handling, and projected remaining channel value.
- Made every graph instruction a guaranteed non-executable macro hold, including
  channel continuation and movement rows.

## 0.8.15

- Made Stealth a dependency-backed setup edge: it now requires a discovered
  stealth-only action or a concrete undetected rear approach against an
  aggressive target. Neutral-target Backstab no longer justifies Stealth by
  itself.
- Added a ClassicAPI-backed exact aggregate for melee, ranged, and spell hit
  from equipped non-broken items, random properties, and live enchantments.
- Applied known equipment hit to weapon-skill-versus-Defense and spell delivery
  priors, with equipment values included in learned-evidence fingerprints.
  Talent and non-equipment aura hit remain visible gaps rather than being
  misreported as part of the gear total.
- Added privacy-safe hit diagnostics plus deterministic physical and magical
  delivery regressions.

## 0.8.14

- Made combo points target-owned throughout legality, power, scoring, and state
  projection. Missed builders retain the prior owner, landed builders transfer
  ownership to their target, and finishers consume only matching target branches.
- Applied ClassicAPI SpellDuration endpoints to combo-scaled aura projections,
  including conditional expected points after uncertain delivery. Wrong-target
  finishers remain blocked instead of spending another unit's points.
- Added runtime diagnostics and deterministic graph coverage for the exact
  ClassicAPI bridge and conservative stock-API fallbacks.

## 0.8.13

- Replaced an out-of-range terminal with a non-executable, target-pinned
  `Move into range` graph edge. The HUD can now show the real future action
  beyond movement while every later row remains explicitly conditional; `/xa`
  never dispatches the instruction or skips ahead to the predicted spell.
- Stealth is no longer treated as an idle permanent self-buff. It requires a
  live hostile setup target and its graph value now pays the known 50% movement
  penalty, with that tradeoff visible in the recommendation reason.
- Added capability-gated groundwork for ClassicAPI's exact combo-owner and
  SpellDuration-range APIs. The addon remains conservative and functional when
  those new DLL calls are absent.

## 0.8.12

- Doubled the automatic strategic horizon to twenty-four decisions and extended
  modeled combat time to forty-five seconds, independently of the one-to-five
  action rows selected for the HUD.
- Added three compute lanes: a low-latency 256-state/8 ms lane when an action is
  ready, a 512-state/12 ms lane during short cast/GCD slack, and a deep
  768-state/18 ms lane out of combat or with at least one second of observed
  downtime. The original urgency discount remains intact so deeper planning
  cannot postpone an executable off-GCD action.
- Published completed search depth and configured decision/time horizons with
  each recommendation, and added deterministic coverage proving a tractable
  state can complete all twenty-four future decisions.

## 0.8.11

- Added live ordinary and normalized VMaNGOS weapon bases for melee and ranged
  specials. Equipped weapon type/speed, attack power, attack-time multiplier,
  and total damage multiplier now feed normalized attacks; mixed direct-damage
  effects remain outside the weapon coefficient.
- Replaced deterministic future combo mutation with a bounded probability
  distribution. Missed builders retain the prior count, missed finishers retain
  their points, and finisher legality/power use availability and conditional
  expected points rather than inventing a guaranteed outcome.
- Added a target-pinned out-of-combat Stealth setup edge for proven aggressive
  targets. It can expose a conditional approach-and-rear Backstab continuation,
  while explicitly withholding movement, detection, facing, and execution proof.
- Expanded automatic search to twelve decisions/twenty modeled seconds with a
  five-path beam and adaptive 192-384-state, 7-12 ms budget. Out-of-combat and
  observed GCD/cast slack receive the larger budget; immediate independent and
  target-modifier branches remain protected from beam pruning.

## 0.8.10

- Decoupled `/xa` from graph evaluation. The HUD driver now atomically publishes
  complete recommendations, while each physical input may consume one fresh
  publication without ever starting evaluation or forcing another evaluation
  in the input call.
- Added fail-closed age, mode, target-change, completeness, and one-shot guards.
  Repeated taps between graph publications safely hold, and dispatch success or
  rejection only schedules the next controller refresh.
- Preserved Nampower's process-scoped player-energize registration across world
  entry resets, restoring verified Rogue energy waits and real future actions.
  A selected path that still lacks a recovery clock now shows a specific
  resource gate instead of falsely reporting a graph horizon or timestamp.
- Split recommendation production, future-row placeholders, path diagnostics,
  and final dispatch readiness into focused modules so the input, graph, and HUD
  boundaries remain independently reviewable.
- Decoded OctoWoW's VMaNGOS weapon-effect aggregation instead of treating a
  percentage lane as flat damage. Backstab rank one is now modeled as
  `1.5 * normalized weapon + 15`, while Sinister Strike is modeled as
  `normalized weapon + 3`; weapon formulas override misleading raw DBC
  magnitudes.
- Added delivered direct-damage-per-resource value alongside the existing
  scarcity reserve. A durable, mitigated target therefore prefers the stronger
  and more energy-efficient legal rear attack, while lethal damage, tank threat,
  position, equipment, and affordability remain generic graph evidence.
- Added a deterministic Rogue regression covering stealth, out-of-combat rear
  position, exact melee reach, full energy, physical mitigation, Attack start,
  stealth consumption, combo gain, and the frontal Sinister Strike fallback.
- Current-action help now retains root candidate gates, so an alternative such
  as Backstab reports whether position, resource, range, or live state excluded
  it instead of leaving the player unable to distinguish strategy from evidence.

## 0.8.9

- Centralized numeric/name spell-range queries and explicit command/effect
  bands. Attack and other hitbox-limited effects now require proven effect
  reach instead of accepting a soft command range or center-only distance, and
  invalid `UnitDistanceSquared` results no longer become zero-yard evidence.
- Made future geometry causal. Projected actions use only captured state, carry
  stable visible conditions for range, line of sight, behind position, and
  stationary casts, and cannot become legal merely because graph time passed.
  Unproven future reach contributes no guaranteed path value.
- Added one final live reach and identity boundary immediately before every
  player or companion dispatch. It independently validates the cast recipient
  and effect recipient, including dual-target pet effects, minimum range, soft
  effects, and actor/target races. Pet Attack remains usable as an approach
  command outside pet melee range. Authenticated in-world validation remains
  pending and is not claimed.

## 0.8.8

- Split the player's cast clock from the shared GCD clock. Normal actions own
  that GCD, while Attack, auto-repeat, on-next-swing, and proven independent
  actions can be evaluated inside it without consuming or resetting it. Future
  pet actions use their exact projected readiness instead of a layer-wide wait.
- Separated intrinsic action value from causal timeline advancement. Delayed
  actions now see ambient attacks, periodic effects, and target health at their
  scheduled impact, while readiness-aware pruning retains useful immediate
  independent actions. Partial UI module loads now fail closed instead of
  repeatedly faulting the HUD.
- Separated command acceptance from effect reach. ClassicAPI geometric range is
  preferred when available, explicit effect limits remain enforced even when a
  command is accepted, and Attack requires proven five-yard hitbox reach. Added
  deterministic timing, weaving, future-state, and soft-range regressions.
  Authenticated in-world validation remains pending and is not claimed.

## 0.8.7

- Separated graph search from presentation depth. Planning now explores up to
  eight decisions or twelve modeled seconds with a four-path beam, 128-state
  cap, six-millisecond soft budget, and elapsed-time discount; the character
  setting controls only the one-to-five rows shown in the HUD.
- Stabilized recommendation publication at the five-Hz display boundary.
  Equivalent plans no longer repaint or restart cooldown spirals, compatible
  budget-short paths retain their already validated suffix, and incompatible
  branches cannot be spliced. Movement, range, line-of-sight, and behind
  failures block immediately but must remain recovered for 150 ms before
  re-admitting an action.
- Opened transient future geometry, movement, aura, usability, and pending
  evidence instead of treating the root observation as permanent truth. The
  root remains authoritative and executable; future rows expose partial data.
- Added generic Spell.dbc combo generation and spend-all transitions. A
  nonlethal low-point direct finisher is charged for throwing away marginal
  combo efficiency, while exact lethal and capped-point spends remain valid.
  Player energy regeneration is projected only after three clean, uncapped,
  same-character ticks establish a conservative live cadence and Nampower's
  player energize event can exclude procs/refunds.
- Made productive hostile abilities own their exact Spell.dbc Attack-start
  edge, eliminating a redundant bare Attack recommendation. Bare Attack is
  suppressed while exact stealth is active; opener and stop-Attack attributes
  remain authoritative. Added focused graph, DBC, energy, HUD, spatial, and
  execution-boundary regressions. In-world UI and combat validation remains
  pending and is not claimed by the local suite.

## 0.8.6

- Restored the complete recommendation HUD and minimap entry on Vanilla 1.12
  clients. The cooldown spiral now uses the client-compatible `Model` frame
  type when no expansion-specific type is published, and remains optional if
  the native constructor or configuration is unavailable. A failed decorative
  overlay can no longer abort the action card or the later minimap build.

## 0.8.5

- Removed the target-acquisition crash boundary from the recommendation HUD.
  The crash report faulted in WoW build 5875's `Region:GetPoint`; the live 0.8.2
  HUD called that exact method while resizing and reanchoring `XelAssistFrame`
  inside its own `OnUpdate` callback.
  The current card is now fixed-height, prebuilt future rows extend below it
  without mutating the callback owner, a dedicated driver owns refreshes, row
  handlers are installed once, and a new target settles for one driver tick
  before presentation. A mocked HOLD-to-plan regression forbids geometry or
  handler mutation on the visual frame during that transition.
- Unified the recommendation HUD and settings as one restrained combat
  instrument: void-ink backdrop, gunmetal border, class stripe, quiet section
  rails, and one clean class/companion-aware frame per action icon. The numbered
  decision rail now keeps one truthful horizon placeholder visible when requested
  look-ahead has no reliable continuation. Settings explain that horizon, show a
  fixed `/xa` contract, and enumerate only the character's currently learned
  graph-gated major cooldowns on mouseover, including an explicit none-learned
  state.
- Changed the 3 ms graph clock from a hard recommendation failure into a soft
  future-look-ahead limit. Live snapshot collection no longer consumes that
  clock, and the graph always completes the immediate candidate set before it
  may shorten the runway. This prevents low-level or cold-client snapshots from
  showing `graph budget exceeded` instead of a usable action; a deterministic
  slow-snapshot regression reproduces the level-1 Rogue failure.
- Added a generic, session-only player main-hand round model from exact
  classified Nampower attack evidence. DBC-classified on-next-swing abilities
  such as Raptor Strike reserve a separate one-action lane and resource cost,
  stay pinned to the selected hostile, and commit cost, cooldown, damage, and
  threat only at the verified round. The yellow result replaces one ordinary
  white result, while scoring values only the marginal upgrade, so neither
  damage nor utility is double-counted.
- Added exact Nampower 4.7.1 on-swing ownership through `GetOnSwingInfo()` and
  `SPELL_ON_SWING_STATE` attempt generations. XelAssist arms ownership before
  dispatch to survive synchronous callbacks, disables native replacement
  buffering, blocks repeated taps, preserves reentrant retry generations, and
  retains ambiguous failures conservatively. Actual GO/miss recipients establish
  submission and swing evidence; a captured pre-cast target is never treated as
  proof that the later melee result hit it.
- Split player round observation, event routing, on-swing ownership, graph
  scheduling, and marginal scoring into focused modules under `Game/Player/`
  and `Graph/`. Added exact-generation, target-change, replacement, resource,
  cooldown, timing, ordinary-white, area-topology, runtime-routing, and soft
  budget regressions. Authenticated in-world Hunter and Rogue validation remains
  pending and is not claimed.

## 0.8.4

- Added a session-only owner for Nampower 4.7.0+'s single normal-GCD player-spell slot.
  A second `/xa` press cannot replace a queued Serpent Sting, DoT, or other
  selected-hostile normal action while its exact outcome is unresolved. On-swing and non-GCD
  queue classes remain independently executable. Live Spell.dbc attributes and
  recovery categories now classify Raptor Strike and other next-swing actions
  without typed rotation metadata. Delayed hostile casts now pass
  the validated opaque target GUID into Nampower instead of resolving whichever
  enemy happens to be selected when the queue later pops. Friendly, ground,
  pet-lifecycle, and GCD-triggering item paths now protect and establish the
  same ownership instead of bypassing it.
- Distinguished client attempt, queue pop, server acceptance, and server
  failure evidence. A pop or pre-server cast event no longer invents completion;
  an unambiguous server-result attempt ID releases the slot, while Nampower's
  synchronous failure-then-retry event order preserves ownership. If the server
  packet cannot be correlated uniquely among same-spell attempts, Nampower emits
  no usable ID and XelAssist retains its bounded conservative latch.
- Kept missing events conservative but bounded, reset all queue evidence on
  world entry, clear graph/resistance reservations when Nampower drops a queued
  action before attempting it, and preserve a reentrant retry across the failed
  generation's later pop. Ambiguous or mismatched failure/cast evidence cannot
  poison another exact same-spell generation. Added target/spell/attempt
  mismatch, same-spell prior-cast, retry, timeout, independent queue,
  execution-boundary, and runtime-routing tests.
  Authenticated in-world Hunter validation remains pending and is not claimed.

## 0.8.3

- Replaced Auto Shot's fixed 8–35 yard admission with Nampower's exact numeric
  `IsSpellInRange` verdict. Unsupported, missing, failed, or identity-raced
  queries now hold; they cannot fall through to tooltip or hitbox geometry.
- Separated range geometry from projectile geometry. Planned arrows use exact
  `UnitDistanceSquared` center distance, the server's five-yard travel floor,
  and the canonical spell's live Nampower DBC speed. Known long flights are not
  truncated by an invented timeout, and graph-projected starts recompute their
  executability from the carried target-bound evidence.
- Preserved exact launches whose flight clock could not be observed as a
  session-persistent, target-pinned uncertainty marker. A later measured launch
  cannot erase them, and bounded-ledger eviction leaves target-local or global
  overflow evidence instead of silently restoring certainty. Graph health and
  player-threat deltas stay inexact until the session ledger is explicitly reset.
- Split range, flight-ledger, and graph uncertainty behavior into focused Lua
  modules. Added deterministic dead-zone, unknown/error, target-race,
  center-distance, five-yard-floor, long-flight, spell-identity, carried-arrow,
  overflow, target-local uncertainty, and conservative threat regressions.
  Authenticated in-world Hunter validation remains pending and is not claimed.

## 0.8.2

- Added a session-only, target-pinned controlled-companion main-hand swing
  clock. Only exact classified Nampower rounds from the current pet establish
  phase; pet commands, action-bar glow, misses without exact actor attribution,
  and `NOACTION` packets do not. Identity, target, attack-state, speed, aura,
  level, world, and control-regime changes invalidate the clock.
- Scheduled verified Hunter pet and Warlock demon white rounds independently of
  focus and pet spell GCD, behind exact hitbox/combat-reach and line-of-sight
  evidence. Events retain their original hostile GUID and stop at timeline caps,
  target changes, overdue phase, or an unresolved same-time autocast order.
- Kept timing evidence separate from outcome magnitude. The stock normal pet
  damage envelope is visible diagnostically, but projected white rounds do not
  invent damage, threat, target survival, or deferred-melee proc order until the
  crit/glancing/block/absorb/resistance distribution is defensible.
- Made the generic player `Attack` action an idempotent start-only command using
  Nampower's exact live auto-attack state and a rewind-safe submission latch. A
  button press cannot score or apply an immediate white hit, enter the spell
  queue, or toggle the attack back off on repeated taps.
- Fixed deferred Hunter melee threat so Intimidation updates the captured
  hostile record and only mirrors into the root pet for the selected target.
  Added real hostile-context and same-window causal-boundary regressions.
- Split companion target identity and swing scheduling into focused modules and
  added privacy-safe swing diagnostics. All deterministic validators pass;
  authenticated in-world Hunter validation remains pending and is not claimed.

## 0.8.1

- Added a session-only Hunter focus learner without assuming a server or talent
  rate. Three clean, uncapped, same-pet `UNIT_FOCUS` gains establish amount and
  cadence, then projection adds a conservative timing envelope. Nampower 4.5+
  energize events are required to make that clock executable; without causal
  attribution, learned cadence stays diagnostic. Energizes, identity/lifecycle,
  max-focus, talent, pet-aura, and player-control regime changes invalidate
  ambiguous evidence, including Improved Eyes of the Beast transitions without
  localized spell names. Focus cap erases phase, and post-cap spending starts a
  full-interval lower bound instead of banking suppressed ticks.
- Put known-cost companion actions on one causal cast/resource timeline. Focus
  is paid once at cast start, tied autocasts share one atomic arbitration result,
  cooldown-expired identities can recur, and failed starts release pet occupancy.
  Unknown costs or a bounded-event overflow invalidate later affordability
  instead of becoming free. Pending and already-observed casts do not pay again.
- Split focus evidence, event routing, graph-clock arithmetic, decision logging,
  and runtime diagnostics into focused modules. `/xa diagnostics` reports the
  privacy-safe Hunter focus learner state without persisting pet identity.
- Added deterministic learner, lifecycle, cast arbitration, unknown-cost,
  failure, event-cap, and projection regressions. Authenticated in-world Hunter
  validation is still pending and is not claimed by this checkpoint.

## 0.8.0

- Added a deterministic hostile snapshot that deduplicates exact opaque GUIDs
  from selected, mouseover, pet-target, and party/raid-target tokens and keeps at
  most five target-local records. Health, aura, resistance/modifier, geometry,
  victim, aggro, and available cast evidence now stay attached to the hostile
  that produced them instead of leaking through the selected-target mirror.
- Added installed-client DBC topology for each spell effect, including implicit
  recipient relation, shape, center, chain count, and exact mapped SpellRadius
  values. Target- and caster-centered circles resolve geometry only from the
  bounded hostile snapshot. Because stock unit tokens are not exhaustive,
  secondary benefit is withheld; cones, chain secondaries, ground/dynamic
  objects, unknown radii, and unknown target relations remain explicit unknowns.
- Supported direct damage/builders with exactly one resolved hostile DBC area
  effect now apply health-capped damage and threat to each known physical
  recipient while charging the action's resource and cooldown cost once. Known
  unengaged recipients remain collateral risk, and incomplete discovery
  withholds secondary benefit without erasing known physical consequences.
  Mixed/multiple effects and area modifiers remain explicit unknowns.
- Kept launched Auto Shot projectiles attached to their captured hostile GUID
  across later selected-target changes. Fixed launch outcomes remain immutable;
  known living or unknown-health targets retain their arrows, while proven dead
  or missing targets are pruned conservatively.
- Added exact generic `pettarget` identity to the shared actor snapshot for both
  Hunter pets and Warlock demons. Scheduled companion autocasts retain that
  target identity and apply damage, periodic effects, threat, and
  taunt state to the matching hostile-local projection. Event-created periodic
  effects keep independent GUID-keyed tick and expiry clocks, including when
  two enemies carry an effect with the same name.
- Put enabled companion autocasts on one shared pet cast/GCD clock with
  target-local range and line-of-sight checks. Unknown simultaneous order,
  geometry, cast completion, or area recipients now reserves focus/cooldown
  conservatively and remains visible as uncertainty instead of inventing hits.
- Added an isolated hostile-state copy/commit boundary so projected auras,
  debuffs, expiry, resistance modifiers, and damage cannot cross GUIDs or source
  ownership when the selected target changes during lookahead.
- Added a final hostile dispatch guard. Every hostile queue, Auto Shot, pet
  ability, and attack command revalidates the captured selected-target GUID,
  hostility, relation, and death state; Hunter dual-recipient actions also
  revalidate the exact companion and its current hostile target.
- Added deterministic locality, area-recipient, DBC-topology, hostile-state, and
  execution-boundary regression scenarios. This release checkpoint has local
  model/load evidence; it does not yet claim authenticated in-world Hunter
  validation or complete nameplate discovery.

## 0.7.0

- Added first-class Hunter companion state: alive/dead/dismissed/unknown
  lifecycle, exact identity, family evidence, happiness damage, focus, loyalty,
  training, diet, target, attack state, pet spell ranks, cooldowns, and autocast
  become graph facts rather than a pet-present boolean.
- Moved companion meaning into focused `Combat/PetKnowledge.lua` and added
  ID-first Hunter pet semantics verified from the installed Octowow Spell,
  SkillLineAbility, and CreatureFamily DBCs. Growl, Cower, Bite/Claw, mobility,
  control, defensives, and classic/Turtle family actions remain live-discovered
  graph nodes rather than a Hunter priority list.
- Modeled Auto Shot as an idempotent ambient launch/projectile/impact state
  machine. It preserves exact spell and target identity, spends ammunition at
  launch, respects movement/cast shot-delay floors, carries launched arrows
  through later range/LOS changes, and cannot toggle itself off on repeated taps.
- Added dual-recipient Hunter actions: Kill Command and Intimidation retain the
  captured pet cast recipient and hostile effect target independently, recheck
  both identities plus pet reach/LOS at dispatch, and learn from their exact
  pet-owned result spell rather than the Hunter's command spell.
- Split Bestial Wrath into its verified 8-second +40% damage enrage and
  18-second control-immunity windows. Intimidation now has an independent
  8-second threat modifier and 15-second one-charge next-successful-melee proc,
  including pet-level flat threat and a three-second stun. Confirmed casts and
  live pet auras reconstruct these windows across fresh graph snapshots; exact
  successful pet swings and melee-ability outcomes consume the hidden proc.
- Model Kill Command's advertised 80% live-pet-attack-power result as an
  explicitly estimated private-server script, preserve its critical usability
  gate at dispatch, and apply pet happiness, delivery, resistance, and threat
  ownership to the result.
- Corrected Mend Pet to a five-tick, five-second interruptible channel with
  per-rank total healing, effective-healing threat owned by the Hunter,
  overheal/mana tradeoffs, post-combat relevance, and repeated-tap protection.
- Put Auto Shot events, pet autocasts, periodic ticks, and chosen-action impact
  onto one offset-sorted causal timeline. Earlier kills now preserve only the
  resources actually spent, while instant companion buffs can affect a later
  same-window pet action.
- Added explicit Auto/Tank/Assist/Avoid companion-threat policy and separated
  pet threat scoring from core action scoring.

## 0.6.0

- Replaced root-level `XelAssist_*.lua` modules with responsibility-based
  `Core/`, `Game/`, `Combat/`, `Graph/`, and `UI/` folders and one path-mirrored
  `XelAssist` namespace. The TOC remains the explicit dependency manifest.
- Split graph state observation, target expansion/legality, hostile effects,
  scoring, transitions, and bounded search into acyclic modules with fixed
  architecture ceilings instead of growing the graph monolith.
- Added a canonical bounded friendly snapshot that deduplicates aliases by
  opaque GUID and makes player, pet, party, raid, selected-friendly, mouseover,
  and hostile-victim allies first-class graph recipients.
- Co-optimized action, spell rank, and friendly recipient across direct heals,
  HoTs, absorbs, and buffs. Future graph steps can change recipient, project
  target-local health/aura state, and charge threat only for effective healing.
- Captured and revalidated friendly identity around range checks and dispatch;
  token recycling now holds without casting, queuing, logging, or creating a
  pending action, and a friendly selected target never falls through to the
  hostile Nampower queue.
- Bound discovered pet actions to the exact opaque companion identity and
  revalidate it at dispatch, so a replaced demon cannot inherit a queued pet
  spell or command. Rank-specific range checks and last-moment positive-aura
  checks now use the same exact action and recipient that will be dispatched.
- Conservatively hold manual pet buffs and dispels for an off-target friendly;
  stock `CastPetAction` cannot address that recipient explicitly, while selected
  targets and intrinsically self-resolving pet actions remain executable.
- Revalidate a selected target's captured opaque identity immediately before a
  pet ability or command, preventing `CastPetAction` from following a recycled
  target token during execution.
- Refuse to submit any positive-wait action that cannot use Nampower's forced
  selected-target queue, including exact-GUID friendly spells, ground spells,
  and items; the hold creates no false log, use, or pending aura.
- Snapshot friendly buff names through SuperWoW's `UnitBuff`/`SpellInfo` path
  when structured ClassicAPI auras are unavailable, preserving existing buffs
  and HoTs across projected graph transitions.
- Treat pet attack/follow/passive commands as immediate control actions instead
  of inheriting a companion spell's future ready time.
- Add bounded action-specific buff lanes alongside the urgent-healing pool, so
  large groups advance to the next unbuffed ally instead of stalling forever on
  three already-covered recipients.
- Split bounded cast/aura reservations and the one-input dispatcher into
  focused `Core/Reservations.lua` and `Core/Executor.lua` modules instead of
  adding more execution policy to the runtime/event monolith.
- Made the validator and mocked full-load test consume the TOC directly, reject
  unlisted nested Lua, obsolete prefixed globals/files, Lua 5.1 syntax, and
  architecture growth, while retaining deterministic nested-directory packages.
- Replaced string-concatenated transient target keys with bounded ledgers keyed
  by the opaque SuperWoW target and caster identities themselves for aura,
  line-of-sight, numeric-outcome, and resistance-submission correlation.

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
