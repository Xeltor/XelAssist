# XelAssist action graph

## Boundary

XelAssist does not encode `A → B → C` rotations. `Combat/Knowledge.lua` only
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

## Module boundaries

`Combat/Delivery.lua` is stateless combat mechanics: DBC ordinary-hit traits,
magic/physical priors, weapon-skill versus Defense context keys, resolved
white-swing decoding, and delivery evidence records. It does not know about the
graph, encounters, or resistance storage. `Combat/TargetModifiers.lua`
discovers active attributable Armor/resistance/damage-taken effects and owns
their stacking groups. This lets outcome attribution query the current modifier
state without depending back on graph search.

`Combat/Resistance.lua` owns target identities, persisted profiles, outcome
attribution, and landed-hit mitigation. `Combat/ResistanceSubmissions.lua` owns
the bounded, session-only correlation ledger for pending and recently consumed
casts; it indexes opaque target and caster identities directly. Resistance uses
Delivery through a stable facade. `Game/Hostiles.lua` owns bounded exact-identity
observation and `Game/SpellTopology.lua` decodes per-effect DBC recipient shape,
center, relation, chain count, and radius. `Graph/HostileState.lua` owns isolated
hostile-local planning contexts; `Graph/AreaRecipients.lua` resolves conservative
per-effect sets, and `Graph/HostileEffects.lua` applies the supported
single-effect direct-damage subset while charging one action once. Mixed
effects and area modifiers remain unknown. `Graph/AutoShotEffects.lua` and
`Graph/CompanionEvents.lua` own target-pinned ambient events;
`Graph/CompanionScheduler.lua` arbitrates one pet cast/GCD clock, with focused
resource, tie, cast-event, cast-runtime, and chosen-consumption helpers, and
`Graph/CompanionEventThreat.lua` owns companion threat consequences.
`Graph/EventAuras.lua` advances event-created aura clocks by opaque hostile key,
while `Graph/ReadinessEffects.lua` owns chosen-action cooldown clocks.
`Game/Player/AttackRounds.lua` owns exact player main-hand phase evidence and
`Game/Player/OnSwing.lua` owns Nampower 4.7.1's attempt-identified on-swing slot
and conservatively owns the single live pending bit on Nampower 4.7.0.
`Game/Player/EnergyEvidence.lua` learns a session-only exact player-energy
cadence, `EnergyEvents.lua` owns its Nampower attribution/reset boundary, and
`Resources.lua` performs conservative graph-clock arithmetic.
`Graph/PlayerSwings.lua` schedules the corresponding target-pinned ambient
rounds and applies full replacement-hit consequences, while
`Graph/PlayerSwingScoring.lua` values only the gain over the displaced white hit.
`Graph/ComboState.lua` owns target-specific landed/missed branches and
combo-scaled durations, `Graph/ComboEffects.lua` applies DBC-derived combo
transitions, `Graph/ComboScoring.lua` owns marginal finisher efficiency, and
`Graph/SearchPolicy.lua` owns the bounded time horizon independently of the HUD.
`Graph/State.lua`, `Graph/Targets.lua`, `Graph/Effects.lua`,
`Graph/Scoring.lua`, `Graph/OngoingEffects.lua`, `Graph/ActionEffects.lua`,
`Graph/Timeline.lua`, and `Graph/Transitions.lua` own one planning stage each;
`Graph/Engine.lua` is the bounded-search facade.
Architecture tests prevent the old monolith or a dependency cycle from returning.

## Evidence order

1. Live authoritative verdicts: known spellbook slot, `IsSpellUsable`, cooldown,
   `IsSpellInRange`, current cast/GCD, aura presence, target state, resources,
   exact Nampower unit health, movement, pet, combo points, and target-of-target aggro.
   UnitXP's NPC-capable hitbox distance is preferred over center/player-only
   distance fallbacks when a direct spell-range verdict is unavailable.
   Explicit combat-log miss/resist/immunity outcomes and UI line-of-sight errors
   are retained against the exact target, caster, spell ID, and school that
   produced them. Turtle's `UnitResistance(target, 0..6)` second return is the
   preferred effective Armor/Holy/Fire/Nature/Frost/Shadow/Arcane vector. A
   positive hostile Armor result proves that capability for the session; the
   player's own Beast Lore also proves special-info visibility. Until then an
   all-zero vector is unknown, because a stock vMaNGOS server can hide hostile
   update fields and leave Nampower's raw memory table zero or stale.
2. Nampower spell/unit records: spell ID, rank, mana/resource cost, cast time,
   GCD, own/shared cooldown, duration, range band, effect base values, weapon
   damage, exact health, school-specific bonus damage, damage class, binary
   control effects, and the normal-ranged, always-hit, and ignore-resistances
   attributes. Magic always-hit bypasses its delivery roll, but nonbinary damage
   can still be partially resisted after landing. Physical always-hit remains
   conservatively subject to dodge/parry/block/mechanic uncertainty. Ignoring
   resistances bypasses positive resistance without discarding a real negative
   resistance vulnerability.
   Nampower 4.7.1 also supplies a reusable `GetOnSwingInfo()` snapshot and
   attempt-identified `SPELL_ON_SWING_STATE` transitions. State changes precede
   callbacks, so XelAssist can reconcile synchronous arm, consume, failure,
   cancellation, replacement, and buffer-pop evidence without guessing from an
   action-bar glow or a later generic cast event.
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
Encounter context records instance type, zone/subzone, target GUID and creature
ID, level, classification, creature type, reaction, raid marker, ownership and
controlled-unit classification. These are data join keys and constraints, never
NPC-name dispatch into a scripted priority list.

Player main-hand rounds form a third independent clock. Only an exact ordinary
AUTO_ATTACK result or an exactly owned on-swing GO anchors phase; selecting a
target, pressing Attack, or reading weapon speed never fabricates one. A queued
on-next-swing action reserves its resource but does not spend it, start cooldown,
or apply damage until the target-pinned round. At that event it replaces the
ordinary white result. A following white round advances normally and cannot
replay the special.

The hostile root is a deterministic, GUID-deduplicated collection of at most
five live identities exposed through `target`, `mouseover`, `pettarget`, and
party/raid target tokens. Each record retains its aliases and target-local
health, aura, resistance/modifier, player/pet geometry, victim/aggro, and
available cast evidence. Projected damage, aura, resistance, threat, and death
state commit back to that record before another hostile becomes the active
planning context. The collection is an observation boundary, not a claim that
every nearby or nameplate-visible enemy has been discovered.

When ClassicAPI aura data is available, target auras retain spell ID, stacks,
duration, remaining time, source unit/GUID, player ownership, dispel type,
stealability, and boss-aura flags. Unknown expiration or ownership remains
unknown. Owned DoTs are held until a conservative refresh window rather than
collapsed to an always-on boolean; simulated aura timers advance independently
along each beam path.
Nampower damage events separate absorption, block, and signed resistance. The
model learns mitigation from landed damage while keeping delivery in a separate
estimate. Exact code-1 misses and nonbinary code-2 magic failures train ordinary
delivery; a binary code-2 result trains only that spell's combined base-hit and
resistance roll. Code 2 cannot identify a raw resistance value, so it never feeds
the raw-resistance inverse. The DBC damage class, not damage school, selects the
ordinary hit table: MELEE and RANGED use weapon delivery, MAGIC uses spell
delivery except for its normal-ranged wand case, and NONE has no ordinary roll.
Physical delivery starts with the live main-hand, off-hand, or ranged skill when
the spell's DBC range is exact Combat Range index 2 or its equipment class
requires a weapon, and with level-max skill otherwise. Cat, Bear, and
Dire Bear use level-max no-weapon-form skill. NPC Defense is level based; a
player attacking another player checks maximum Defense plus permanent/temporary
bonuses, while a pet attacking a player uses current Defense. Player Defense is
exact only when the hostile-unit API proves its bonus/current term. White
dual-wield swings alone receive the additional miss term, and an equipped but
broken off hand does not activate it. If off-hand durability cannot be proved,
that white-swing prior remains unknown rather than silently choosing a table.
Exact equipped item/enchant +hit is added to the analytic prior when the
matching ClassicAPI aggregate is available and partitions learned outcomes.
Talent and non-equipment aura +hit remain explicitly unknown rather than being
silently folded into the gear-only number.
Physical hit, miss, dodge, parry, block, and deflect evidence is keyed by actor,
hand, current skill, target Defense, actual-skill mode, relevant weapon/form,
white-versus-yellow table, white dual-wield state, and proven front/behind
geometry. Ranged evidence marks position not applicable. Nampower's resolved
player and owned-pet attack-round events teach exact white hits and failures;
melee-spell packets carrying `NOACTION` are excluded, and resolved damage is
never inverted into Armor or resistance evidence. The computed
skill-versus-Defense value is only the server's initial miss sub-roll: cold
dodge/parry/block/mechanic rates and +hit are not fabricated, so total physical
landing stays visibly partial until matching exact outcomes accumulate. A
physical spell's mechanic-resist outcome
is kept spell-specific and independent of school-resistance debuffs, including
after a target swap. Periodic damage, leech, and channel ticks improve
periodic mitigation knowledge without pretending each tick was another
successful application. Numeric events suppress duplicate localized chat-text
training when Nampower supplies the exact stream.
Direct, periodic, and application evidence use separate context records. Most
Vanilla periodic ticks use one-tenth of the normal resistance chance, while the
application can still fail at the normal rate; a hybrid spell such as Immolate
therefore cannot teach direct spells from its repeated ticks. When the live
tooltip exposes both portions, the graph also weights the direct and periodic
damage separately before comparing the complete spell with another school.
Both shares use the same application landing roll. A pending refresh cannot be
confirmed by an older instance's tick; the exact caster-bearing aura event is
preferred, while a first tick is only a fallback for a non-refresh application
after its discovered cast time.
Resistance-changing auras also fingerprint their modifier state. Application and
direct-impact evidence use the reduction present when the cast was submitted;
later periodic ticks use the modifier present at tick time. Ordinary hit evidence
stays in the baseline delivery context because a resistance curse does not alter
that roll. This prevents samples collected under a curse from teaching a false
unmodified target profile, while allowing the graph to learn the modified state.
After a target swap, the old target's current modifiers are unknowable. Its
later ticks still confirm their school and numeric event, but modifier-dependent
mitigation and binary outcomes are withheld instead of being written into the
zero-modifier baseline. Direct impacts may still use the modifier fingerprint
captured when their cast was submitted.
Equipped main-hand, off-hand, ranged weapon, durability, ammunition identity,
and ammunition count are structured state. Explicit ammunition users are
blocked at zero ammo, broken melee weapons block melee weapon actions, and a
broken ranged weapon blocks weapon-ranged actions; ordinary ranged spells do
not inherit those constraints.
Immediate-use health and mana restoratives are discovered from live bag tooltips
as item action nodes with bag location, count, effect range, cooldown, actor, and
future state. Food, over-time restoration, and ambiguous item effects are not
admitted. Item use is character opt-in and remains one action for one input.
Finite consumables default disabled. Before execution the exact item ID is
re-resolved in bags, checked for lock/count/cooldown, and refused if it moved or
disappeared; equippable on-use gear is excluded from consumable inference.

Installed-client Spell DBC effect targets and SpellRadius values describe each
effect independently. A proven target- or caster-centered circle can resolve
selected and engaged secondary recipients only when its hostile provider marks
discovery complete; the current stock unit-token snapshot never makes that
claim. An observed unengaged unit still becomes collateral risk rather than
rewarded damage.
The action's resource and cooldown state advance once even when several
recipients resolve. Unknown target relation, unknown radius, cones, chain
secondaries, and ground/dynamic-object placement do not manufacture recipients.

The bounded beam compares elapsed-time-discounted paths, so a future cooldown, aura,
resource shortage, or downtime can change which current action wins. Player cast
occupancy and the shared GCD are separate clocks: normal actions advance the GCD,
while proven independent actions may occupy otherwise idle time without resetting
it. Intrinsic action value excludes time spent waiting, while the causal transition
still advances ambient attacks, periodic effects, and target state through that
wait. It returns
one current action contract plus up to four simulated future actions. A current
action with positive wait is submitted only through Nampower's forced selected-
target queue; exact-friendly, ground, and item paths hold until they are ready.
Future nodes are predictions, not queued casts; every `/xa` press takes a fresh
snapshot and may choose differently.
An active player channel is a weighted commitment rather than a hard cast lock.
The graph compares a non-executable continuation branch, valued from the exact
remaining time and the discovered channel action, with actions that would clip
it immediately. Interrupts, urgent support, threat safety, or lethal damage may
therefore win while routine actions preserve valuable remaining ticks. Attack,
Auto Shot, on-next-swing setup, and companion actions stay independent and do
not falsely cancel the player's channel. Unknown channel identity receives a
conservative hold value instead of being treated as free to cancel.
An exact out-of-range result creates a non-executable, target-pinned movement
instruction rather than terminating the runway. The graph may continue through
that edge, but measured distance is never changed: every downstream action is
marked conditional on the player actually reaching its range band. Pressing
`/xa` on the movement row safely holds and never executes a predicted row.
Stealth similarly requires a concrete hostile setup target and a discovered
dependent edge: either an action whose live spell facts require Stealth, or an
out-of-range rear opener whose approach to an aggressive target materially
benefits from remaining undetected. A neutral target with only ordinary
Backstab does not qualify. Eligible Stealth paths still price their movement-
speed penalty instead of behaving like free indefinite maintenance.
The automatic horizon is twenty-four decisions or forty-five modeled seconds,
with a five-path beam. Immediately actionable states receive a 256-state/8 ms
budget; short observed cast/GCD slack receives 512 states/12 ms; out-of-combat
states and at least one second of observed cast/GCD slack receive up to 768
states/18 ms, beginning after the live snapshot. The first two decisions complete before the soft
budget can shorten later look-ahead. Utility is discounted by modeled elapsed
time rather than layer number, so GCD, off-GCD, cast, and resource-wait edges
pay their actual clock cost. The one-to-five HUD setting is presentation-only.
If the limit is crossed, the best current frontier is returned with
`budgetLimited` evidence; it does not become a HOLD.
The decision runway renders each step as actor, target, action, modeled start
time, and evidence state. Only the current step is clickable; graph errors and
dependency holds disable it and remove stale future rows.
The presenter publishes only material path/target/evidence changes. A compatible
budget-short prefix may retain an already validated suffix, but a changed branch
can never splice old future steps. Presentation painting is slot-local: a new
future branch does not repaint the current card or an unchanged visible prefix,
and an unchanged `IF` row can receive newer tooltip evidence without visual
churn. Cooldown timers are rewritten only when their
timer tuple changes. Blocking movement/range/LOS/behind evidence applies at
once; recovery must remain positive for 150 ms. Transient live-only facts are
authoritative at the root and marked OPEN rather than frozen into future nodes.
Candidate pruning retains one meaningful target-modifier branch when raw
immediate-damage branches would otherwise fill the beam, allowing a resistance
or Armor setup to prove its value through a later exploit action. This is still
a bounded heuristic, not an exhaustive proof of every long setup chain.

## Utility and safety

- Damage is valued by effective output per occupied GCD/cast window. Output past
  the target's remaining health is not rewarded.
- Spell.dbc effect 80 supplies deterministic combo gains, while the installed
  finishing-move attributes consume all points. A surviving target charges a
  low-point direct finisher for discarded marginal efficiency; exact lethal
  output and capped-point spends remain authoritative. Each uncertain hostile
  delivery updates bounded target-owned branches: a failed builder retains the
  prior owner and count, a landed builder transfers ownership to its target,
  and a failed finisher retains that target's points. ClassicAPI duration
  endpoints interpolate combo-scaled auras against the conditional points
  owned by the candidate target. This is mechanic data, not a Rogue action order.
- Armor or school resistance is applied to expected damage before it enters
  throughput, overkill, periodic-payback, future-health, leech, and threat math.
  This lets a smaller Shadow hit beat a larger Fire hit when target evidence
  predicts enough Fire mitigation; no school-specific priority list is involved.
- Hybrid direct/periodic and mixed-school output is combined component by
  component as `share × delivery × school vulnerability`. Uncertainty reserves
  apply only to unresolved components. The tooltip and decision log expose the
  final graph-scored multiplier rather than labeling a resistance-only factor as
  complete expected output.
- An unresolved damage school/resistance carries a small decision-only
  uncertainty reserve. The displayed multiplier remains unknown rather than
  inventing mitigation, but a barely larger mystery hit cannot automatically
  beat a slightly smaller action backed by target evidence.
- Turtle magic mitigation uses the partial-resist expectation curve, including
  its bend above two-thirds of the resistance cap. The Vanilla prior applies the
  server's integer-truncated innate level-difference resistance to every magical
  school, including Holy. Physical damage combines a conservative level-based
  delivery prior with the level-scaled Armor formula. Exact outcomes supersede
  those priors. Equipped spell/armor penetration is subtracted when a complete
  English equipment-tooltip scan is available.
- Live tooltip reductions from Sunder Armor, Expose Armor, Faerie Fire, and
  resistance curses become projected target-state deltas. Future beam nodes can
  therefore compare “debuff, then exploit the lower resistance” with immediate
  damage, including school-specific damage-taken bonuses, stack/combo scaling,
  and the observed or modeled probability that the debuff itself lands.
- Uncertain applications remain probabilistic future state. A low-confidence
  debuff does not become a certain aura that suppresses retry; an uncertain
  refresh retains the still-active old aura on its failure share until that old
  aura expires.
- Damage-taken effects retain their non-stacking group: the strongest effect in
  one group applies, while independent groups combine multiplicatively. Their
  remaining duration is evaluated at the candidate's impact time.
- Attributable versions of those debuffs already active at the root seed the
  same state. A trusted effective live resistance vector is not reduced twice,
  and future projected modifiers are removed when their simulated aura expires.
- Periodic damage is capped to the damage an exact-health target can still
  consume, then charged for unrealized ticks and mana. This allows a direct or
  zero-mana recovery action such as Shoot to beat a DoT on a dying target.
  Applied periodic effects continue advancing health in later graph windows;
  hybrid direct damage lands immediately and only its periodic share is spread
  over the aura duration. Existing DoTs and channels re-evaluate resistance and
  damage-taken state across modifier start/expiry boundaries rather than freezing
  the multiplier that existed when they were first stored. Auto Shot launches
  and impacts, pet autocasts, stored periodic ticks, and the chosen action share
  one offset-sorted causal timeline, so only effects that really resolve first
  can suppress resource spending or consume a same-window pet trigger. Launched
  arrows and scheduled companion effects retain the opaque hostile GUID captured
  at launch/scheduling, so a later selected-target change cannot redirect them
  into the selected-target compatibility mirror. Auto Shot admission uses only
  the exact numeric client range verdict; projectile timing separately requires
  identity-bound center distance and live DBC speed. An observed launch whose
  timing is unavailable remains session-persistent target-local uncertainty that
  makes health and player-threat delta inexact rather than fabricating an impact.
  The bounded ledger summarizes eviction as target-local or global uncertainty;
  it never recovers certainty by forgetting an unresolved arrow.
- Mutually exclusive effects use generic family metadata. Applying one of the
  player's Warlock curses replaces only that player's prior curse in projected
  state; an attributable curse from another Warlock is preserved. Ambient pet
  autocasts use the same impact-time resistance, damage-taken, and uncertainty
  factors as explicitly recommended actions.
- A submitted DoT/debuff/CC becomes a target-scoped pending edge immediately.
  It stays unavailable through cast completion and the short aura-visibility
  delay, preventing tap-driven duplicate casts. Confirmed cast failure or
  interruption (including movement interrupting a cast), miss, or resist clears
  the edge so the next press may retry; immunity is deliberately not treated as
  a retry signal. Nampower's independent full-buff and full-debuff-bar flags are
  checked against the pending effect's polarity; an unrelated full bar cannot
  invalidate an exact application event.
- Healing is capped by missing health, then balanced against cost, downtime, and
  overheal. This lets a lower rank win without a downrank rule.
- Non-tanks receive a threat penalty in groups. When they already hold aggro the
  penalty steepens, allowing lower-rank/lower-threat actions or a threat drop to
  win from the same utility equation.
- Interrupts preempt throughput only during a detected cast. Cast-time actions
  are excluded while moving. ClassicAPI's geometric range verdict is preferred
  when available, with the legacy direct verdict as fallback. Command acceptance
  and effect reach are distinct: an explicit effect limit is still enforced when
  the client accepts a zero-effect command, and Attack requires proven five-yard
  hitbox reach. Discovered minimum/maximum bands cover units where no direct
  verdict exists. Reactive abilities require an explicit usable result.
- Major cooldowns, including unknown actions whose client record reports at
  least 30 seconds, reagents, and incidental area damage remain character opt-ins.
- Hostile dispatch remains selected-target-only. `Core/TargetGuard.lua`
  rechecks the captured GUID, relation, hostility, and death state immediately
  before dispatch and again around mutable actor/range evidence. Pet abilities,
  attack commands, Auto Shot, and Hunter dual-recipient effects cannot use an
  observed off-target hostile as implicit authority to change targets.
- Pet nodes come from the live pet spellbook plus executable action-bar slots.
  Autocast-enabled abilities become actor-owned timed future transitions and are
  not redundantly recommended for manual execution. Each simulated path copies
  actor/autocast state so one branch cannot spend another branch's pet resource.
  Enabled autocasts share one pet cast/GCD clock and recheck target-local range
  and line of sight. Simultaneous order, missing geometry, unfinished casts, and
  area recipients reserve conservative focus/cooldown state while remaining
  explicit recommendation unknowns instead of inventing damage.
  Warlock demon semantics include threat, interrupts, dispels, crowd control,
  Consume Shadows, Sacrifice, and shard-aware summoning without keying decisions
  to localized demon family names. Hunter pets use the same actor path. Their
  Growl/Cower, focus attacks, movement, control, self-defense, and family actions
  are ID-first facts taken from the installed Octowow DBCs; only actions present
  in the live pet spellbook and executable pet bar become graph nodes.
  Ordinary companion main-hand attacks are a separate actor clock: only an
  exact classified Nampower round anchors phase, and each future round stays
  pinned to that pet and hostile identity. It is independent of focus and the
  pet GCD, requires exact reach/line-of-sight evidence, and invalidates on
  identity, target, attack-state, speed, aura, level, world, or control changes.
  Same-time autocast/white order creates a causal boundary that withholds all
  later companion events in that projected window.
- DBC-classified player on-next-swing actions use their own exact slot. They
  require a verified active Attack target, main-hand phase, live normal-damage
  magnitude, exact melee geometry, and a single proven recipient. Repeated taps
  cannot replace the armed generation. Scoring subtracts the expected white hit
  that the special replaces, while transition state commits the full special at
  the round and charges its cost/cooldown once.
- Evaluation errors and missing dependencies hold without a cast. Search-budget
  pressure limits future depth but cannot suppress an otherwise usable immediate
  recommendation.

## Known evidence gaps

- Target-of-target is an aggro signal, not a numeric threat meter. XelAssist can
  react to ownership of aggro and relative spell threat but cannot know the tank's
  exact threat lead from the current APIs.
- Vanilla hostile health may be percentage-scaled. Damage-to-health and finisher
  math is enabled only when Nampower exposes exact `health` and `maxHealth` fields.
- OctoWoW VMaNGOS weapon opcodes 2/17/31/58/121 and live ordinary/normalized
  weapon bases are decomposed before scoring. Triggered child spells, absorbs,
  and server-scripted modifiers can still remain estimated; those recommendations
  are visibly marked `estimated` and logged.
- Future movement, target swaps, incoming damage, other players' casts, proc
  arrivals, and shared cooldown categories cannot be predicted. The independent
  producer continuously publishes fresh complete plans; each physical press
  consumes at most one publication and never starts graph work itself.
- Combo gain and spend transitions retain probabilistic landed/missed outcomes,
  but target time-to-die beyond exact current health is not yet a learned
  survival model, so short-lived-target finisher timing remains bounded
  heuristic reasoning rather than a full encounter forecast.
- Combo-scaled duration endpoints for Slice and Dice, Rupture, Expose Armor,
  and similar finishers are decoded when the matching ClassicAPI bridge is
  available and remain conservative otherwise. Duration-aware periodic and
  target-modifier projections are active; full marginal utility curves for
  every non-direct finisher remain a model gap. Stock `GetComboPoints()` still
  proves only the selected target, so exact off-target ownership also requires
  the ClassicAPI bridge.
- Hostile discovery is not a nameplate scan or a complete encounter roster. It
  sees only the selected, mouseover, pet-target, and group-target unit tokens,
  deduplicates them by exact GUID, and caps the planning collection at five.
  Secondary area credit therefore applies only inside that bounded evidence and
  is withheld when the snapshot reports capping or incomplete discovery.
- DBC topology identifies a spell effect's intended recipient relation and
  geometry, but current recipient resolution is limited to single targets and
  proven target- or caster-centered circles. Cone membership, chain jumps after
  the selected origin, ground/dynamic-object placement, and missing radius or
  relation data remain explicit unknowns.
- No external addon is a runtime dependency. Installed addons are used only as
  read-only API/mechanics references; XelAssist calls capability-checked DLL and
  stock client globals itself.
- Pet line of sight, pathing, exact numeric threat lead, and encounter hazards
  remain unknown unless the client exposes them; they are not silently treated
  as safe.
- A resolved companion round proves swing phase, not its next outcome magnitude.
  The live normal-damage envelope is retained for diagnostics, but white-round
  damage and threat remain unknown until crit, glancing, block, absorb, and
  resistance outcome magnitudes can be modeled without false precision.
- A player round is executable only after exact classified main-hand evidence
  and live normal-damage magnitude establish phase and replacement value. Before
  the first such round, after a target/weapon/form/control change, or when melee
  geometry is not exact, on-next-swing actions hold. Area on-next-swing abilities
  remain withheld until every replacement and secondary recipient can be proven.
- Hunter pet focus is observed exactly at each live snapshot and known pet costs
  are reserved across the shared autocast clock. Passive regeneration becomes
  executable only after three same-identity, uncapped `UNIT_FOCUS` gains establish
  a stable amount and observed cadence from live evidence; projection lengthens
  that cadence by the accepted jitter tolerance. Nampower 4.5+ energize
  attribution is required before the clock can make actions affordable, so a
  standard-API-only learner remains diagnostic rather than blessing repeated
  external gains. Energizes fully invalidate ordering-dependent evidence. Cap,
  source, lifecycle, max-focus, pet-aura, and talent ambiguity erase phase or the
  modifier regime. Player-control loss/gain also invalidates the model,
  conservatively covering Improved Eyes of the Beast entry and exit without
  localized names. Spending after cap re-anchors a full-interval lower bound, so
  lookahead can never bank suppressed ticks. Unknown pet cost makes resource
  exactness false and withholds later affordability instead of charging zero.
- The stock API exposes a localized Hunter family name but not its numeric
  CreatureFamily ID. XelAssist records an English-name family match for
  diagnostics only and never uses it to admit an action; the live spell ID/bar
  remains authoritative. Cower, pet-only defensives, and multi-effect family
  skills retain explicit semantic flags but stay conservatively undervalued
  until actor-local threat/health and simultaneous-effect projection consume
  those flags.
- Kill Command's 80% pet-attack-power description is client intent implemented
  by Turtle's private server script, not a DBC damage formula. Its graph power
  is therefore marked estimated until attributable runtime outcomes validate
  the script. Intimidation's 51556 +50% pet-threat aura is modeled from the
  installed client but remains runtime-unverified because the available public
  core does not apply that modifier to non-player units.
- Stock `CastPetAction(slot)` has no explicit recipient argument. A manual pet
  ability that needs a friendly recipient is therefore legal only when that
  recipient is the selected target; off-target pet buffs and dispels hold until
  a native GUID-addressed pet-action capability is available.
- Equipped item/enchant +hit is sourced analytically through ClassicAPI and
  included in physical and spell delivery priors. Talent and non-equipment aura
  +hit remain explicit gaps; matching exact outcomes refine those omitted terms
  statistically. White-swing outcomes are exact but post-resolution,
so their weapon, hand, and position fingerprint is sampled when the packet is
  received. Yellow abilities are sampled when submitted; for a queued or
  cast-time ability that snapshot can precede the server's launch-time roll, so
  an intervening weapon swap or move makes attribution approximate even though
  the reported outcome itself is exact.
- Observed immunity is deliberately spell-and-target scoped and expires after a
  short anti-loop window; XelAssist does not infer a permanent creature or school
  immunity from one event. Observed line-of-sight failure is target scoped and
  expires quickly because either actor may move.
- Resistance profiles are keyed by creature ID, level, and instance context;
  caster level, actor, and rounded penetration keep unlike observations apart.
  They are capped, decay with age, and never persist player GUIDs or names.
  Direct outcome samples can infer a reusable raw school prior, but live effective
  target data outranks it. Player targets remain in memory for the session only.
- For nonbinary magic spells, vMaNGOS reports the magic hit failure as Nampower
  miss code 2, so XelAssist trains ordinary delivery. For binary spells the same
  code represents a combined base-hit/resistance roll and is kept spell-specific.
  Neither case becomes a hard raw-resistance fact; exact partial damage is
  aggregated separately before any bounded raw-resistance inference.
  Immunity stays spell/target scoped and short-lived. Mixed or dynamically
  triggered damage stays unknown until components or an exact observed school
  resolve it; the graph does not force melee delivery to mean Physical damage.
  Observed wand, active-seal, and pet-result schools are keyed to the current
  ranged item, seal aura, or pet GUID so a source change cannot reuse stale data.
- Website/database creature values can become versioned build-time priors, but
  Lua has no runtime HTTP path and database templates can be stale. They must
  never outrank current `UnitResistance` data or exact combat outcomes.
  The installed Octowow WDB creature cache and pfQuest unit export contain no
  Armor or school-resistance fields and are deliberately not imported.
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
dependency versions, guarded API availability, required Nampower damage/miss
event CVar status, exact player/pet round and on-swing ownership status,
discovered/inferred node counts, load time, and the latest graph failure.
`/xa diagnostics` refreshes and prints that evidence without
player, realm, target, or party names. `/xa resistance` prints per-school
expected output split into delivery and landed-hit value, with unknowns preserved.
