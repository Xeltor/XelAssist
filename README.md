# XelAssist 0.8.53

XelAssist is a private, input-driven combat decision addon for OctoWoW 1.18.
It discovers the character's known spell ranks and evaluates them as an action
graph. Curated semantics cover known Octowow abilities, while conservative live
tooltip inference admits unambiguous unknown combat spells. It does not contain
a class rotation or an ordered cast list. The evidence and consequence coverage
for every class is tracked in `docs/class-mechanics.md`; withheld entries are
deliberate graph boundaries, not hidden priorities or assumed rotations.
The pass/fail release contract for a playable all-class 1.0 lives in
`docs/playable-1.0.md`.

Aegis_SBR and other installed addons are read-only research references, not
runtime dependencies. XelAssist capability-checks the required SuperWoW,
SuperAPI, Nampower, and available ClassicAPI DLL globals directly.

The graph evaluates continuously outside `/xa`. Each physical press consumes at
most one fresh, complete recommendation publication; macro spam cannot replay a
publication, execute an expired result, or start graph evaluation in the input
call. The on-screen
decision runway shows the current action and up to four simulated future actions
as actor-to-target contracts with modeled start times and visible evidence state.
Predicted rows are never executable. The explanation describes the tradeoff that
won, such as finishing the target, avoiding excess healing, limiting threat,
interrupting a cast, or preserving resources.

Evaluation is bounded by an intra-frame profiler clock and counts every
action-target edge it examines, including learned spell ranks that do not enter
the final beam. Unchanged state is polled at a low enough cadence to leave frame
time for the client. A plan remains as old as the live snapshot that began its
search; range and identity are checked again before publication and execution.

Actions on the selected target use Nampower 4.7.0+'s one normal-GCD spell queue.
XelAssist protects an occupied slot across repeated macro taps until matching
server evidence with an unambiguous opaque attempt ID resolves the cast; an
ambiguous same-spell result remains conservatively latched until its bounded
timeout. With Nampower 4.7.1+, on-next-swing abilities use a separate exact
attempt-owned lane; 4.7.0 retains a conservative single-owner fallback. Native
replacement buffering is disabled so repeated input cannot overwrite the armed
action. Their resource, cooldown, damage, and threat occur at the verified
main-hand round rather than when the button is pressed. Non-GCD actions remain
independent and can be evaluated inside the shared-GCD window without resetting it.
Normal-GCD self actions use the same owned queue with the captured player GUID,
so a displayed future self buff can be armed safely during the current GCD.
Non-GCD self actions and ready-now party or mouseover actions retain SuperWoW's
unit-targeted cast path; future party actions remain a conservative hold.
Hostile actions remain selected-only by default. A per-character, default-off
`Cast at engaged enemies` policy may let ordinary single-target player spells
address an observed enemy whose exact victim is the player, companion, or group.
It never changes the selected target. Pets, Attack/Auto Shot/Shoot, melee and
combo builders, reactive procs, area/ground actions, and fixed or indirect
effects remain selected-only. An engaged cast must be ready now; identity,
hostility, death, engagement, and reach are revalidated immediately before one
GUID-pinned queue submission.

Active hostile casts use a bounded, session-only exact-GUID ledger fed by
Nampower and corroborated by SuperWoW. When the installed DBC proves one direct
single-target damage or healing effect and its exact recipient is retained, the
graph schedules that consequence at the observed deadline. Known projected
shields absorb damage first, incoming damage can increase pre-heal and absorb
value, and interrupts compete on the consequence they actually prevent. Mixed,
scripted, periodic, area, channel, missing-recipient, and unknown-level spells
remain explicit uncertainty with one bounded interrupt fallback.

Exact Mage Mana Shield and Priest Power Word: Shield consequences use that
same frozen incoming-event model. Mana Shield values and consumes only physical
damage up to the mana-backed capacity left after its cast cost; magic-only
aggro adds no proxy value. Power Word: Shield projects its exact recipient's
Weakened Soul lockout, so a future branch cannot shield the same unit again
while another ally remains independently eligible.

Shadowform is likewise an exact setup edge, not a Priest rule. The graph pays
its captured effective mana cost, projects form 28, applies the installed 15%
bonus to later player-owned Shadow damage before resistance, and reduces exact
physical incoming damage by 15% before absorbs. The form action starts at zero
value and survives only when those descendants repay it. Leaving Shadowform is
not yet projected, so unavailable consumer legality fails closed.

Health-funded companion channels use exact installed-client effect semantics
rather than ordinary mana or pet-heal approximations. Health Funnel pays its
initial player-health cost and each upkeep tick causally, heals only after a
successful nonlethal payment, prices overhealing and incoming damage, and can
be continued or deliberately clipped by the same weighted channel graph used
by other classes. Unproven server-side talent modifiers remain unknown.

The installed-client semantic foundation decodes multi-effect mechanics for
every class as separate damage, healing, resource, dispel, threat, summon,
aura, form, and triggered-child atoms. It also describes all 64 local implicit
target codes without collapsing target A and B. Druid form discovery is its
first audited recommendation consumer. A bounded dispel-capture adapter is also
available for the future frozen-observation path, but is not yet wired into
recommendation scoring or execution. Validation rejects every unaudited caller.

Druid form actions are discovered from exact installed-client shapeshift atoms,
not localized names. When ClassicAPI exposes the active form, explicit power
slots, effective spell cost, and cancellation endpoint, Cat/Bear hidden mana is
paid causally and a stale cancellation is rejected at dispatch. Destination
rage or energy remains unknown unless a narrower exact bound exists: rank-five
Furor now proves Cat Form's 40-energy floor, while Bear rage remains unknown.
Prowl is likewise discovered from exact installed facts. It is an indefinite
Cat-form, out-of-combat stealth setup with its real rank movement penalty, and
receives no standalone value: a retained future action must actually require or
benefit from stealth before the graph can justify it.

Hunter special ranged attacks now share one causal ammunition ledger with Auto
Shot. An ambient launch that spends the last round blocks a later casted shot
before it can gain value or spend mana. The graph can track exact Hunter-aspect
replacement on the player, but deliberately suppresses aspect recommendations
until their actual ranged power, avoidance, movement, resistance, melee power,
or mana effects are represented downstream; it does not substitute proxy scores.
Installed-client Web and Charge identities now retain their exact root, range,
linked-effect, and movement-trigger topology without being mislabeled as cast
interrupts. Intimidation arms a target-pinned next-pet-melee effect and can stop
a modeled hostile cast only when the frozen pet swing phase, melee delivery,
recipient, and arrival time prove that consequence. Missing evidence holds.
All four installed Hunter's Mark ranks use numeric target-local aura evidence.
Mark receives no generic debuff score: its ranged attack power is added only to
later Auto Shots and exact ranged-weapon effects against that same hostile,
after the weapon spell coefficient exactly as the server formula does.

Player reactive actions use the exact Nampower aura-state bit required by the
installed spell record. For client records that omit that requirement, an
explicit positive root `IsSpellUsable` result may admit only the immediate edge.
Neither source is projected through a wait, and choosing the action consumes the
window in that graph branch without inventing a cooldown.

Active leech channels now deliver damage, healing, and scaled player threat at
their exact remaining tick boundaries. Resistance, lethal target-health caps,
movement/action clipping, and target identity changes are resolved before any
paired healing is granted.

The exact first-rank Windfury Totem chain is represented for a solo Shaman.
Placement itself has zero invented duration value; later qualifying main-hand
white or melee-ability packets gain the expected nonrecursive extra attack and
retire deterministic swing timing when a proc becomes possible. Group fanout
and unaudited higher ranks remain explicit unknowns.

Warrior melee now has a causal, non-executable continuation edge. Once an exact
main-hand phase has been observed, the graph can wait through ordinary attacks,
project their conservative damage-derived rage, and expose a later affordable
ability instead of ending at a resource horizon. The wait coalesces swings up
to the next learned rage threshold or target defeat. On-next-swing replacements
still suppress the displaced white hit and its rage, and raw DBC rage costs are
normalized to the same displayed units as live player power.

Charge is also a causal graph edge rather than a scripted opener. Its exact
installed-client rank produces 9, 12, or 15 rage and proves only arrival in the
selected hostile's ordinary melee band. It does not invent damage, threat,
facing, a white swing, an active Attack state, or value for its one-second stun.
The root snapshot must prove the action usable and outside combat, and the live
dispatch boundary checks both facts again before accepting a macro press. A
target-scoped in-flight reservation prevents repeated fresh publications from
resubmitting it while combat and cooldown evidence catch up.

Player Taunt is a distinct threat-ownership edge, not a damage action or a
Warrior priority rule. In tank posture, the graph may recommend it only from a
live selected hostile that is provably attacking the player's current pet or a
current party/raid member. It projects the bounded forced-target window without
inventing a numeric threat lead or rewriting the immutable observed victim.
Publication and immediate dispatch independently revalidate Defensive Stance,
exact usability, cooldown, five-yard reach, hostile identity, victim
identity, and roster ownership; a target that has already switched to the
player cancels the recommendation instead of wasting Taunt. A proven ally or
pet pull remains valid before the player's own combat flag arrives.

Sunder Armor now keeps armor projection separate from threat projection. Its
five installed ranks contribute the VMaNGOS build-5875 server profile's 45,
99, 153, 207, or 261 base flat threat only after expected effect delivery,
while remaining explicitly runtime-unverified for Octowow. Armor stacks and
partial-delivery branches cap at five; a landed cast at the cap refreshes the
projected aura and adds threat without inventing a sixth stack. Because stance
and talent multipliers are not yet included, the resulting player-threat delta
is deliberately marked inexact and never used to fabricate an aggro switch.

Warrior stance passives and exact Defiance ranks now travel with every branch:
Defensive Stance rank-five threat is 1.56, while its damage and mitigation and
Berserker's critical/damage-taken effects remain explicit causal evidence.
Rogue Feint is a separate selected-hostile flat threat edge whose level-scaled
amount is multiplied once by melee weapon-skill delivery. It never clears other
hostiles or asserts who wins threat afterward. Paladin all-threat blessings
compose their exact recipient-owned multiplier with those ordinary player
threat components; the graph values the later consequences instead of carrying
a preferred blessing list.

## Requirements

- OctoWoW's 1.12.1-compatible client
- SuperWoW and its SuperAPI compatibility addon
- Nampower 4.7.0 or newer; 4.7.1+ is recommended for exact on-swing generations
- The matching ClassicAPI fork is optional but recommended for exact hidden
  combo-point ownership and combo-scaled duration endpoints

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
   role, optional-action policy, Soul Shard reserve, intent, and number of
   predicted actions.

The primary recommendation is also clickable. A click consumes the same fresh,
one-shot publication as `/xa` and performs at most one action; it never starts
graph evaluation inside the input call. XelAssist never acquires or changes a
hostile target and never casts from an update handler.

## Character and global settings

Decision policy is stored per character: Smart/Single/Area/Support intent, role,
visible decision steps, area-action permission, cooldown/reagent/consumable
permission, engaged-enemy casting, companion actions, crowd-control permission,
companion threat posture, and a Warlock Soul Shard reserve (default three).
Display scale, position, lock state, and visibility are global.
Finite consumables are always opt-in per character and default disabled.

Smart mode reacts to live need. It can prefer an interrupt, unwanted-aggro escape,
defensive, efficient heal, missing utility, or damage action without dispatching
into a class rotation. Single, Area, and Support constrain the goal without
ordering spells.

## Commands

`/xa` executes once. Other commands are `why`, `smart`, `single`, `aoe`,
`support`, `cooldowns`, `reagents`, `consumables`, `engaged`, `resistance`, `diagnostics`, `log`,
`clearlog`, `config`, `show`, and `hide`.

The per-character decision log keeps the latest 200 attempted recommendations and
their local state evidence. `/xa log` prints the latest five. It contains combat
numbers and action names, not player or target names.

`/xa diagnostics` also refreshes a durable, privacy-safe runtime audit containing
dependency/API availability, discovered versus inferred action-node counts,
Hunter focus plus player energy/mana evidence, controlled-companion swing evidence, and player
main-hand/on-swing ownership evidence. It reports
whether each clock is learning, dormant, or executable; it does not persist pet
identity.

## Graph model

The evaluator automatically explores up to twenty-four actions or forty-five
modeled seconds with a five-path beam. It expands 256 states under an 8 ms soft
budget when an action is immediately due, 512 states/12 ms during short observed
cast/GCD slack, and up to 768 states/18 ms out of combat or when at least one
second of observed cast/GCD downtime gives the graph safe compute slack.
The graph samples at 5 Hz and independently shows one to five requested steps.
The first two decisions are completed before the soft limit can shorten the
runway; an otherwise usable current action never becomes a budget HOLD. It accounts for:

- separate current-cast and shared-GCD clocks, predicted action cast time,
  independent-action weaving, and own cooldowns;
- normalized live command-range verdicts and independently enforced effect
  reach, including minimum/maximum DBC bands, hitbox-only melee effects, and
  movement;
- hitbox-aware actor-to-target distance and behind-position evidence. UnitXP's
  `inSight` hint is deliberately excluded because it is not a proven cast-LOS
  verdict;
- live main-hand, off-hand, and ranged weapon skill versus target Defense,
  including the white dual-wield penalty and exact equipped item/enchant +hit
  when the matching ClassicAPI bridge is available;
- current resources, per-rank cost, effective healing, overheal, and damage needed
  to finish the target; health-to-resource actions retain one bounded investment
  lane only until a later action proves that the gained resource was necessary;
- graph-native Warlock Soul Shard stock with a character-specific reserve of
  three, level-scaled kill eligibility, credible Drain Soul death windows, and
  marginal scarcity pricing for shard consumers instead of a typed rotation;
- talent-adjusted client tooltip facts, refreshed whenever talent points change;
- group role, current target-of-target aggro, and relative action threat;
- exact root-only Warrior Taunt rescue for a current pet or group member, with
  target/victim/roster race protection and no fabricated damage or threat total;
- exact Warrior stance/Defiance threat, selected-target Rogue Feint,
  recipient-owned Paladin all-threat blessings, target-local Hunter's Mark,
  Priest Shadowform, and solo Windfury consequences, composed on later actions
  without class priority rules;
- exact Mage physical-only mana-backed absorbs and Priest recipient-local
  Weakened Soul exclusion over the same frozen hostile-cast timeline;
- interrupts, proc/stance usability, combo points, buffs, debuffs, ranks,
  area policy, cooldown policy, and reagents;
- generic DBC-discovered combo generation and finishing moves, including
  target-owned landed/missed branches and combo-scaled durations when exposed
  by ClassicAPI, plus the marginal value lost by spending a nonlethal
  direct-damage finisher too early;
- session-only player energy timing learned from clean exact ticks, without a
  hardcoded server cadence or allowing a predicted tick to make the current
  macro press executable;
- session-only player mana timing learned from exact power changes with
  attributed spell energizes excluded. A root clock may fund a future action,
  but a mana-funded cast closes it unless repeated observations prove that
  exact spell's successful GO-to-passive-regeneration boundary;
- exact Bloodrage immediate and finite delayed rage, base-health payment,
  combat entry, and cooldown consequences, retained only when a later legal
  rage spender proves the investment useful;
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
  button press is never modeled as melee damage. A productive DBC-proven opener
  can establish the same sustained Attack edge, so bare Attack does not waste a
  press or precede a stealth opener;
- exact target-pinned player main-hand phase learned only from classified attack
  rounds. DBC-classified on-next-swing actions reserve one independent lane and
  their cost until that round, replace the ordinary white result rather than
  double-counting it, and are scored only for their marginal improvement over
  the displaced white swing. Unknown phase, damage, geometry, target identity,
  or area recipients holds the action instead of inventing a melee outcome;
- equipped weapon durability and ammunition, plus opt-in immediate-use healing
  and mana consumables discovered conservatively from live bag tooltips;
- OctoWoW VMaNGOS weapon-effect coefficients and delivered
  damage-per-resource value, so a legal rear Backstab is compared with Sinister
  Strike from graph evidence rather than a Rogue priority list. Ordinary and
  normalized weapon bases use live equipped-weapon speed, type, attack power,
  and damage multipliers, while mixed direct damage stays outside the weapon
  coefficient;
- future resource, health, target-health, aura, threat-drop, and cooldown state;
- bounded session-only target survival pressure learned from repeated exact
  health observations. Cast, channel, and periodic output is integrated over
  the resulting evidence window, so a direct or zero-mana action can beat a
  long DoT on a mob already dying quickly. Large heals, health-regime changes,
  observation gaps, and inexact health reset or withhold the model;
- captured future spatial contracts that never call live APIs or invent
  movement. Predicted rows disclose the range, line-of-sight, behind, and
  stationary facts that must remain true or be proven at execution time. An
  out-of-combat Stealth against a proven aggressive target may expose a
  conditional approach-and-rear Backstab path, but movement, detection, facing,
  and the actual opener remain revalidated rather than treated as accomplished;
- root movement/range/line-of-sight/behind failures with immediate blocking and
  short settled recovery, plus atomic recommendation/cooldown publication so
  equivalent 5 Hz recomputations do not visually blink;
- target/ally/controlled-actor identity plus instance, zone, creature ID,
  classification, raid marker, combat state, and owned timed aura evidence.
  Friendly spell expansion admits only proven player characters plus the
  player's explicitly controlled companion; ordinary friendly NPCs are never
  buff or healing recipients regardless of their unit token;
- a deterministic, GUID-deduplicated snapshot of at most five hostiles visible
  through selected, mouseover, pet-target, and party/raid-target unit tokens,
  with target-local health, aura, resistance, modifier, geometry, victim, and
  threat projections; this is not full nameplate or encounter-roster discovery;
- DBC-derived per-effect recipient topology and installed-client radius data,
  plus an isolated full target-enum and composable spell-mechanics decoder.
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
- a final hostile dispatch guard that rechecks identity, relation, hostility,
  death state, engagement authority, player/pet command and effect reach,
  behind state, movement, and companion dual-target requirements before any
  hostile queue, Auto Shot, pet ability, or attack command can execute. The
  optional engaged-enemy lane is exact-GUID, ready-now, and never changes the
  selected target. Pet
  Attack remains an approach command and therefore does not pretend the pet is
  already in effect range.

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
