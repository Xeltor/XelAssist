# Changelog

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
