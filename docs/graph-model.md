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
Additive +hit is not yet part of the analytic prior and remains explicitly
unknown.
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

The bounded beam compares complete discounted paths, so a future cooldown, aura,
resource shortage, or downtime can change which current action wins. It returns
one executable action plus up to four simulated future actions.
Future nodes are predictions, not queued casts; every `/xa` press takes a fresh
snapshot and may choose differently.
Candidate pruning retains one meaningful target-modifier branch when raw
immediate-damage branches would otherwise fill the beam, allowing a resistance
or Armor setup to prove its value through a later exploit action. This is still
a bounded heuristic, not an exhaustive proof of every long setup chain.

## Utility and safety

- Damage is valued by effective output per occupied GCD/cast window. Output past
  the target's remaining health is not rewarded.
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
  the multiplier that existed when they were first stored.
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
  are excluded while moving. Direct range verdicts are authoritative; discovered
  minimum/maximum bands cover units where no direct verdict exists. Reactive
  abilities require an explicit usable result.
- Major cooldowns, including unknown actions whose client record reports at
  least 30 seconds, reagents, and incidental area damage remain character opt-ins.
- Pet nodes come from the live pet spellbook plus executable action-bar slots.
  Autocast-enabled abilities become actor-owned timed future transitions and are
  not redundantly recommended for manual execution. Each simulated path copies
  actor/autocast state so one branch cannot spend another branch's pet resource.
  Warlock demon semantics include
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
- No external addon is a runtime dependency. Installed addons are used only as
  read-only API/mechanics references; XelAssist calls capability-checked DLL and
  stock client globals itself.
- Pet line of sight, pathing, exact numeric threat lead, and encounter hazards
  remain unknown unless the client exposes them; they are not silently treated
  as safe.
- Equipment/talent/aura +hit is not yet sourced analytically. Matching exact
  outcomes refine delivery statistically, while diagnostics state that +hit was
  excluded from the prior. White-swing outcomes are exact but post-resolution,
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
event CVar status, discovered/inferred node counts, load time, and the latest
graph failure. `/xa diagnostics` refreshes and prints that evidence without
player, realm, target, or party names. `/xa resistance` prints per-school
expected output split into delivery and landed-hit value, with unknowns preserved.
