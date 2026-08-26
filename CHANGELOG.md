# Changelog

## 0.8.79

- Added root-sealed engine-effective rage costs for Heroic Strike, Whirlwind,
  Bloodthirst and Mortal Strike. Improved Heroic Strike, Improved Whirlwind and
  the patch-5 Bloodthirst/Mortal Strike reduction now change graph affordability
  and efficiency without a class rotation or static action ordering.
- Required learned passive topology, the cost SpellMod and the engine's charged
  value to agree; divergent or forged discounts fail closed.

## 0.8.78

- Added exact patch-5 Improved Berserker Rage ownership and triggered-resource
  topology. Activating Berserker Rage now adds five or ten rage at the learned
  talent rank before later graph actions consume it.
- Kept the talent's movement-impairment break chance explicit but neutral until
  a hostile-control ledger can prove a useful active effect.

## 0.8.77

- Added exact learned Reprisal rank ownership and engine-effective Revenge
  damage modifiers. Rank one now contributes its proven twenty-five-percent
  damage increase and rank two its proven fifty-percent increase.
- Kept Reprisal's fifty/one-hundred-percent rage-refund chance explicit but
  uncredited because patch-5 does not expose the private successful-Revenge
  refund trigger as a safe branch-local resource event.

## 0.8.76

- Added exact Octo Overpowering Rage ownership and trigger topology. A learned
  passive now exposes its five-second, fifteen-percent melee-haste aura without
  relying on its localized talent or aura name.
- Root-observed and guaranteed projected Overpower haste now changes only
  future player swing resets, expires branch-locally, and thereby reaches
  ordinary white damage and rage generation without inventing a landed proc.
- Extracted player melee-clock modifier composition from `PlayerSwings.lua` so
  Hunter, Rogue, Druid and Warrior haste owners remain independent and the
  core swing scheduler stays below its architecture ceiling.

## 0.8.75

- Added name-independent discovery for every installed Rockbiter, Flametongue,
  Frostbrand and Windfury Weapon rank, verified through patch-5 spell topology
  and ClassicAPI's live temporary-enchant record.
- Modeled Rockbiter's level-scaled main-hand attack power and exact 1.35 weapon
  threat multiplier, and Flametongue's speed-scaled Fire packet. Flametongue
  damage is conditional on the parent melee delivery and receives its own Fire
  resistance/delivery consequence.
- Added exact hour-long main-hand enchant replacement and expiry state, early
  same-rank refresh suppression, and direct cast dispatch. Frostbrand and
  Windfury are recognized but fail closed because their private proc chance or
  conflicting installed proc evidence cannot yet support safe expected value.
- Closed a live Warrior Rend refresh gap: an observed matching periodic aura
  with incomplete expiry, tick-phase, or rank metadata is now retained instead
  of being treated as permission to overwrite damage it may still deliver.
  Refresh displacement evidence is also carried into the persistent decision
  log for the next runtime validation.

## 0.8.74

- Corrected Enrage's installed evidence boundary: `-75` is a private dummy
  magnitude, while patch-5 describes a twenty-seven-percent Bear and
  sixteen-percent Dire Bear base-armor reduction. The graph keeps its safe
  counterfactual upper bound without mislabeling the dummy as a literal
  seventy-five-percent armor loss.
- Completed Blood Frenzy's Enrage-side lifecycle. Rank one now contributes its
  exact five immediate rage plus ten-percent melee haste for nine seconds;
  rank two contributes ten rage plus twenty-percent haste for eighteen seconds.
- Root-observed and projected Blood Frenzy haste now normalize verified main-
  and off-hand clocks and accelerate only future swing resets. Expiry restores
  the sealed base cadence without changing a swing already in progress.

## 0.8.73

- Sealed installed Octo Enrage as an exact Bear/Dire Bear action with ten
  one-second two-rage ticks, a ten-second lifetime and a sixty-second cooldown.
  Its finite clock can now unlock later rage spenders without inventing an
  immediate resource packet.
- Represented Enrage's installed private armor-loss dummy instead of treating
  generated rage as free. Learned player-bound hostile white rounds receive a
  conservative four-times post-mitigation damage upper bound while the aura is
  active, and the bound expires with the rage clock.
- Added fail-closed topology drift, form legality, active-aura, resource-tick,
  incoming-exposure and lifecycle regression coverage.

## 0.8.72

- Sealed Hunter pet Shell Shield from the installed patch-5 spell row: ten
  focus, a sixty-second cooldown, the normal pet GCD, and twelve seconds of
  fifty-percent damage reduction are now exact autocast consequences.
- Applied Shell Shield only to hostile swings whose exact victim is that pet.
  The shared companion clock pays focus and cooldown before installing the
  effect, and the effect expires on the existing actor timeline.
- Preserved Shell Shield's thirty-five-percent melee-speed penalty without
  inventing pet white damage: activation retires the projected pet swing phase
  and records the offensive-timing uncertainty. Name fallbacks and changed DBC
  topology remain effect-unknown.

## 0.8.71

- Replaced the fixed periodic-progress score which could make one late Rend
  tick dominate immediate attacks. DoTs now value only causally deliverable
  damage, pay an equal resource-opportunity charge for forecast-unavailable
  damage, and earn overlap value in proportion to effect completion.
- Kept fully consumable periodic-only effects such as Rend and Corruption
  competitive across the bounded horizon without granting that overlap to
  direct-plus-periodic impact spells such as Pyroblast.
- Added late-Rend, monotonic tick-delivery and cross-class regression coverage,
  plus automatic logging of periodic damage forecast not to land.

## 0.8.70

- Gave Shield Block bounded selected-attacker prevention instead of a legal but
  permanently zero-value window. Stock block chance, exact non-rear geometry,
  phase-known hostile rounds and the minimum observed same-regime block packet
  now produce a conservative incremental mitigation value.
- Projected hostile swings consume Shield Block's one/two charges through a
  bounded probability distribution, reducing both expected health loss and the
  rage generated from that loss. Off-target facing and cold-start block value
  remain explicitly uncredited.
- Added automatic Shield Block evidence to the decision log and retire learned
  mitigation packets across spell, talent, level, equipment, form and aura
  changes.

## 0.8.69

- Learned exact normal-cast pushback increments from Octo's
  `SPELL_DELAYED_SELF` stream in an eight-sample character/session envelope.
  Talent, spell, equipment, level, form and world changes retire the profile.
- Added observed damaging-hit probability to mitigation-bound hostile white
  rounds. Phase-known rounds which can land during a normal player cast now
  extend its expected cast, occupancy and impact timing; an extension may
  causally admit a later swing. Channels, pet casts and exact Barkskin immunity
  remain separate.
- Added automatic diagnostics and decision-log evidence plus production
  scenarios for Druid, Hunter, Mage, Paladin, Priest, Shaman and Warlock cast
  timing. No cold-start Vanilla formula is invented before Octo evidence exists.

## 0.8.68

- Periodic refreshes now value only their marginal future ticks. An owned DoT's
  remaining ticks are subtracted from a reapplication, including the imminent
  tick that Vanilla resets when a refresh restarts the cadence. This prevents
  late Rend refreshes from claiming damage the existing Rend would deliver
  without spending another global cooldown and 10 rage.
- Preserved exact spell-rank identity on projected periodic auras and added
  bounded refresh displacement fields to the automatic decision log.

## 0.8.67

- Bound every learned hostile white-swing lane to the exact victim armor,
  defense, level and form regime under which its post-mitigation damage was
  observed. Stale Warrior, Bear, pet and ally damage can no longer survive a
  mitigation change and corrupt survival, rage or healing forecasts.
- Retire incoming-melee learning immediately on player equipment, form and
  aura changes. Pet and group recipients retain independent regimes, so one
  actor's armor change neither reuses nor erases another actor's evidence.

## 0.8.66

- Admitted Octo Shadow Mend through its exact patch-5 identity and documented
  50-percent caster-health consequence. The live maximum heal roll now guards
  caster lethality through known incoming damage, while expected raw healing
  provides a conservative graph health payment after ally or self healing.
- Self-casts are valued by net healing, ally casts price the Priest's health
  and aggro risk, and reduced healing threat remains conservatively
  overestimated instead of inventing Octo's private multiplier. Pain Spike
  remains withheld until its delayed hostile heal is observable.

## 0.8.65

- Prevented Rend and other periodic actions from earning setup value when
  target-survival evidence predicts fewer than one causally deliverable tick.
  This fixes the observed level-4 Rend cast at 8/95 target health without
  introducing a Warrior-specific rotation rule.
- Added expected periodic-tick counts to the bounded decision log so future
  short-fight tuning can distinguish a real late tick from fractional value.

## 0.8.64

- Added a character-specific Evocation learner. One complete, uninterrupted,
  uncapped Octo channel seals the minimum delivered mana and slowest tick
  cadence; later Evocations receive only the phase-independent lower bound.
- Retire learned Evocation value on aura, equipment, talent, level, world,
  energize, interruption or maximum-mana changes. Cold-start Evocation remains
  safely withheld instead of importing an upstream Spirit/MP5 formula.

## 0.8.63

- Added exact Octo patch-5 Hamstring rank identities. Its direct physical
  packet now enters the graph without accidental main-hand damage, while the
  unmodeled target-motion benefit and supplemental threat receive no proxy
  value.
- Sealed Disarm's exact stance, rage, range, duration and cooldown identity,
  but withhold the action until hostile weapon ownership and the resulting
  incoming-swing consequence can be proven.

## 0.8.62

- Added exact patch-5 Improved Shield Slam talent ownership and linked
  one-charge block-proc validation. Learned ranks now reduce Shield Slam's
  projected shared cooldown from 6 seconds to 5.25 or 4.5 seconds.
- Kept the proc's defensive value explicitly uncredited until an exact
  blockable incoming swing and shield block value are available.

## 0.8.61

- Replaced Shield Slam's localized-name fallback and invented `2.0` threat
  multiplier with exact patch-5 rank identities, shield/rage/range/cooldown
  legality and base physical damage.
- Prevented Shield Slam's DBC direct packet from receiving generic main-hand
  weapon damage. Private AP/block-value additions, hostile-dispel probability,
  Improved Shield Slam and Octo threat remain explicit uncredited gaps.

## 0.8.60

- Made target-survival pressure follow exact installed periodic tick cadence.
  A short-lived target no longer gives Rend or another DoT fractional credit
  for a tick which cannot occur, while targets surviving real ticks retain
  only those tick probabilities.
- Reduced the production search checkpoint from 1.50 to 1.25 ms after the
  latest level-four Warrior runtime session recorded a 3.449 ms slice. Search
  work and chosen plans remain unchanged and may span additional frames.

## 0.8.59

- Added exact Octo patch-5 Druid Growl ownership, including Bear/Dire Bear
  legality, off-GCD timing, cooldown, range and three-second fixate. Generalized
  the live taunt boundary so Warrior, Paladin and Druid taunts retain their own
  legality while still requiring a selected hostile attacking the player pet
  or a current group member.
- Added exact Barkskin branch consequences for physical mitigation, cast-time
  extension and player melee slowdown. Pushback prevention remains explicitly
  uncredited until the graph can observe a counterfactual incoming pushback.
- Added exact shield-gated Spirit Armor threat multipliers without inventing
  the private armor benefit.
- Sealed Octo's Lay on Hands ranks against generic free-heal inference. The
  action remains withheld until its private all-mana debit and recipient-mana
  ordering can be represented atomically.

## 0.8.58

- Admitted area-shaped on-next-swing actions when the installed DBC proves a
  target-centered chain origin. The graph credits only the selected-target
  replacement and marks possible server-selected secondaries uncertain rather
  than withholding Cleave or inventing its extra recipient.
- Split the chain-recipient boundary into `Graph/PlayerSwingArea.lua` so the
  main swing timeline remains within the human-review architecture ceiling.

## 0.8.57

- Protected Battle Shout as a graph-native zero-output setup until an exact
  main-hand attack realizes its AP benefit, preventing beam pruning from
  silently reducing low-level Warrior play to Attack and Heroic Strike.
- Reduced each production search checkpoint from 1.75 to 1.50 ms after a live
  Warrior session reached 3.292 ms. Aggregate work and chosen plans remain
  unchanged; the work may span one additional frame.
- Added rank-five Furor's exact in-combat 10-rage floor for Bear and Dire Bear
  shifts while retaining explicit uncertainty outside combat where rage decay
  can invalidate it.
- Added exact guards for Octo's divergent Arcane Power and Blade Flurry so
  their unsafe custom consequences cannot fall through to generic Vanilla
  buff or area scoring.

## 0.8.56

- Added exact patch-5 Berserker Rage ownership: its ten-second branch-local
  aura amplifies only incoming-damage rage by 30 percent. Fear and
  incapacitate utility remain unvalued without hostile-control evidence.
- Connected installed-client dispel semantics to action discovery, frozen
  per-recipient aura evidence, friendly/selected-hostile target selection and
  branch-local removal counts so a stale root cannot recommend extra dispels.
- Made healthy companion engagement competitive on exact durable targets
  without manufacturing long-fight value for short or health-unknown targets.
- Added the missing Lua 5.0 `math.huge` bootstrap fallback used by finite-value
  guards and graph sort sentinels.

## 0.8.55

- Added permutation-stable, rank-heavy level-60 scenario tranches for all nine
  classes. They cover setup, engagement, starvation/recovery, disruption,
  death and post-combat recovery without encoding rotations.
- Added partial level-60 role evidence for healing, tank pressure, interrupts,
  resistance, movement, equipment and pet participation, while retaining
  explicit fail-closed gaps where target threat or pet scheduling is unknown.
- Added exact scenario proofs for Mana Spring Totem expiry, Seal replacement
  and Judgement consumption, and Druid hidden-mana form transitions. These are
  partial release evidence and do not promote any class to proven status.

## 0.8.54

- Added unordered mid-level scenario tranches for all nine classes across
  setup, engagement, starvation/recovery, disruption, death and post-combat
  recovery. These are partial release evidence, not yet full role proof.
- Added exact Octo Stormstrike ownership: a landed strike creates a bounded
  twelve-second, two-charge, 25-percent direct Nature-damage amplifier.
  Probabilistic hits preserve distinct charge and expiry branches.
- Root snapshots now seal numeric Stormstrike charge/lifetime evidence. Direct
  player Nature actions consume charges causally; unverified periodic, pet and
  ambient consumption receives no invented benefit.

## 0.8.53

- Added an unordered nine-class low-level scenario tranche covering setup,
  engagement, sustain and target death without relying on catalogue order.
- Added exact Hunter Feign Death interruption, threat uncertainty, wake and
  expiry boundaries, plus one-per-caster Sting exclusivity. Serpent Sting is
  supported; unsafe drain, mitigation and delayed-control Stings fail closed.
- Added exact Warrior Shield Bash rank, stance, shield, range, cost and
  interrupt facts, while keeping unproven private threat withheld.
- Added exact Mage Arcane Surge reactive ranks and resistance bypass, and
  explicit fail-closed ownership for private Priest, Shaman and Paladin actions.
- Fixed Lua 5.0 branch retention when a candidate has no scheduled start time.

## 0.8.52

- Added zero-command session smoke evidence with exact addon version, class,
  level, role, decision count, worst observed graph slice, budget-limit count
  and graph-error count, plus a sandboxed offline SavedVariables audit tool.
- Added Accelerated Arcana's exact engine-effective five-tick Arcane Missiles
  channel cadence. Learned but incomplete timing fails closed; ordinary
  untalented channels retain their installed DBC cadence.
- Added Blood Frenzy's exact immediate five/ten-rage Enrage packet only after
  an already-admitted Enrage action. Baseline rage, armor loss and haste remain
  separate so the supplemental benefit cannot hide an unresolved tradeoff.
- Added Improved Flame Shock's exact engine-effective 12/15/18-second duration
  while preserving its three-second tick cadence and existing Molten Blast
  phase-safe refresh behavior.
- Centralized trusted channel-cadence provenance in a focused graph module
  instead of duplicating class knowledge in the breakpoint and commitment code.

## 0.8.51

- Added a patch-5-wide installed Spell.dbc topology audit that ranks class and
  linked family-neutral records, including replacement spells, passive auras,
  proc children, resource effects and hidden trigger relationships.
- Added exact Frostfire Bolt resistance selection: the graph uses the lower
  proven effective Fire/Frost resistance while preserving the spell's Frost
  damage school for vulnerability semantics. Missing evidence fails closed.
- Corrected Octo Improved Chain Heal ownership as an exact cast-time reduction,
  not a guessed throughput modifier; live engine cast time remains authoritative.
- Added Ancient Brutality's exact Cat-side three/five-energy consequence only
  after a scheduled, player-owned bleed tick causally deals damage. Bear dodge
  behavior and any private arithmetic remain withheld.

## 0.8.50

- Added Hunter Alone Against the World as an exact observed no-pet damage
  modifier. It requires an explicitly dismissed pet lifecycle and matching
  server aura, affects only player damage, and never guesses from a missing pet.
- Added legal one/two-charge Shield Block projection from installed shield,
  stance, rage and Improved Shield Block evidence. No mitigation is credited
  until exact block value and incoming outcomes can be represented.
- Bounded Seal of the Martyr's exact seal, melee child, Judgement child and
  self-recipient topology. Its outgoing damage remains uncredited while the
  private, material self-health arithmetic is unresolved.
- Added observed Resurgence ownership for Resurgent Shield while leaving its
  absorption-dependent Holy bonus and mana refund unprojected. Root engine
  spell power already embodies an observed aura, preventing double counting.
- Replaced the growing class-evidence call chain with ordered module dispatch
  and split root state attachment into class-local helpers for Lua 5.0 limits.

## 0.8.49

- Added observed-only Holy Shock GCD/cooldown modifier auras with exact numeric
  consumer topology and branch-local consumption. The graph never predicts
  their proc generation or reuses modified timing after consumption.
- Added exact Ascendance action/aura/Apotheosis topology and active-state
  engine healing costs. Future activation, control purging, private cast/cost
  arithmetic and Apotheosis fanout remain fail-closed until observable.
- Added Mark for Death's exact 135-percent main-hand packet, two target-owned
  combo points, Energy/cooldown/range/equipment gates and avoidance bypass.
  Ordinary weapon misses remain possible; Noxious Assault's private dual-weapon
  and poison script remains explicitly unresolved.

## 0.8.48

- Added Aspect of the Viper as an exact five-second, five-percent maximum-mana
  graph clock. Existing auras use a conservative one-period phase bound and a
  fresh projected cast starts an exact phase; Aspect of the Snake remains
  recognized but cannot fabricate its private attack-proc chance.
- Added bounded Devastate weapon damage, exact selected-target Sunder-stack
  damage and landed refresh. Octo's private supplemental threat arithmetic is
  deliberately uncredited until authoritative runtime evidence exists.
- Added observed Moonkin and Tree of Life identities, engine-effective mana
  costs and DBC-mask legality without inventing tooltip-only spell families or
  party aura effects.
- Added observed-only Hot Streak and Flash Freeze proc-window ownership with
  numeric aura topology and branch-local one-use consumption. Proc generation
  is never predicted, and post-consumption timing waits for fresh root evidence.

## 0.8.47

- Added exact installed Nightfall ownership and observed Shadow Trance state.
  Its next Shadow Bolt becomes instant and bypasses ordinary hit uncertainty
  once per branch; proc generation and mechanic resistance remain conservative.
- Replaced generic Shaman Clearcasting recognition with Octo's learned Elemental
  Focus and exact two-charge aura. Engine-reported costs are sealed per action,
  while unobserved critical-trigger timing is not fabricated.
- Added active Improved Shadowform's exact Shadow-spell mana costs and retained
  its in-casting regeneration as explicit unknown state until the rate and
  server tick phase can be observed safely.
- Added Shiv's exact off-hand packet, combo gain and equipment requirement. Its
  dynamic Energy cost must come from the live tooltip and poison delivery earns
  no speculative value without observable poison evidence.

## 0.8.46

- Made normal-cast pushback extend the fallback cast deadline and consumed
  Nampower's exact channel-start/update remaining time. Both paths trigger
  event-driven soft revisions, reject stale identities, and add no frame loop.
- Added Octo's learned Charge in Combat passive as a root-sealed legality fact;
  ordinary Warriors retain the pre-combat restriction and shifted passive data
  cannot manufacture in-combat admission.
- Added all installed Overpower ranks with exact Battle-Stance, rage, weapon,
  normalized-damage and dodge-reactive topology. Upstream threat tables remain
  corroborative only, so no action-specific Octo threat multiplier is invented.
- Added Surprise Attack's exact 90-percent main-hand packet, one combo point,
  Energy/cooldown timing and dodge/parry/block bypass. Ordinary weapon-skill
  misses and mechanic uncertainty remain live branches.
- Recorded a patch-5-wide class divergence backlog covering hidden talents,
  passives, proc auras, triggered spells, pets, forms, costs and threat effects.

## 0.8.45

- Re-audited the installed Bear attack families and removed unsupported typed
  threat multipliers from Swipe, Maul and Savage Bite. Maul retains its exact
  on-next-swing behavior and all three continue through the proven global Bear
  threat multiplier without inventing private server arithmetic.
- Recognized Evocation and its installed custom talent dependencies by numeric
  topology. The graph now fails the action closed instead of fabricating mana
  while Spirit/MP5 amount, global mana-tick phase, Accelerated Arcana timing,
  Evocation Mastery stacks and Nether Overcharge completion remain unresolved.
- Added all installed Molten Blast ranks and their ClassicAPI-backed owned Flame
  Shock refresh. A landed blast resets remaining duration without restarting
  the periodic tick phase; partial delivery and another Shaman's aura do not
  promise a refresh.
- Extended the frame-budget benchmark with rank-heavy Druid, Mage and Shaman
  catalogues so broader class data cannot quietly regress the 3.23 ms ceiling.

## 0.8.44

- Added exact patch-5 Soul Fire rank and reagent topology so mana and one Soul
  Shard are priced and consumed atomically; changed reagent or damage evidence
  now fails closed instead of becoming free generic damage.
- Added target-owned Mongoose Bite Stinging Nettle consequences from installed
  talent/rank data and the local ClassicAPI trigger contract. The shortened
  Serpent Sting is hit-conditional, keeps a longer existing Sting, and never
  leaks through the selected-target compatibility view.
- Replaced Consecration's generic immediate-AoE and guessed threat profile with
  its installed persistent-ground cadence and Holy damage. Only one nominal
  pulse on the selected hostile is conservatively credited; later ground
  recipients and Octo's runtime pulse weighting remain explicitly unverified.
- Explicitly deferred racial-specific combat optimization for 1.0 while still
  allowing independently proven ordinary shared consequences.

## 0.8.43

- Added exact installed-Octo Hand of Reckoning support. Its zero-cost,
  off-GCD, ranged Paladin taunt now uses the existing target-victim threat
  transition and is withheld when the hostile already attacks the Paladin or
  when any identifying client field changes.
- Added Chastise's exact hostile Holy-damage lane without exposing its
  polymorphic friendly lane. The latter remains explicit and withheld because
  Octo damages the ally while applying health-, level-, and critical-dependent
  haste consequences that are not yet represented.

## 0.8.42

- Replaced the localized, top-rank-only Lightning Strike profile with exact
  numeric topology for all three installed Octo ranks. Physical and Nature
  weapon packets now retain their own coefficients and resistance lanes; the
  custom shield trigger is recorded but receives no invented value.
- Applied Octo's learned Dagger Mastery normalized speed of 2.3 while retaining
  the ordinary 1.7 dagger basis when the passive is absent.
- Corrected Arcane Rupture from a pure debuff to direct damage and withheld
  Icicles with an explicit blocker until its self-freeze, cancellation rules,
  and potentially lethal self-damage are represented causally.

## 0.8.41

- Extracted Octo's customized Execute ranks directly from `patch-5.mpq` and
  modeled their exact 20-percent gate, 15-rage base cost, rank damage, and
  per-extra-rage conversion. A landed projection consumes remaining rage; a
  proven miss retains it, while uncertain delivery carries a bounded resource
  range and stops exact later rage planning until the private server profile is
  verified in play.

## 0.8.40

- Captured ClassicAPI's server-derived local-player school interrupt mask and
  duration as root graph evidence. Matching player spells are now illegal until
  exact expiry while other schools remain usable; malformed active evidence
  fails closed instead of guessing the interrupted school or lockout length.

## 0.8.39

- Kept zero-output movement and Shoot setup edges out of published plans until
  they reach a target-dependent attack or the first proven wand impact. This
  prevents `Move into range` from blocking useful lookahead and keeps a wand
  start alive through beam pruning without pretending the toggle dealt damage.
- Added branch-local mana opportunity pricing when an exact usable wand is
  available. Full mana retains ordinary spell valuation, while exhausting the
  last cast now accounts for the proven zero-mana damage alternative and exact
  regeneration lowers that opportunity cost again.
- Projected Thunder Clap's exact max-four damage and threat plus its ten-second
  attack-speed debuff into future hostile swing resets, without retroactively
  stretching an already-running attack round or inventing uncertain delivery.
- Projected delivered hostile damage now earns bounded incoming rage for an
  exact Warrior or Bear-form rage recipient. The graph uses the VMaNGOS
  `RewardRage` 2.5/conversion baseline, caps at live maximum rage, never rewards
  another recipient or absorbed/overkill damage, and labels the result estimated
  because server income-rate and Berserker Rage modifiers are not observable.
- Moved the resource owner ahead of incoming consequences in TOC order and
  covered the live load path, repeated hostile rounds and non-rage recipients.
- Coalesced repeated invalidations that describe one target-death or rejected
  dispatch transition. The first transition still retires execution immediately,
  while duplicate pre-frame events no longer advance publication epochs or
  repaint the HUD repeatedly.
- Anchored the Vanilla cooldown sweep to the visible icon corners so its GCD
  spiral exactly covers the rendered action texture at every HUD scale.
- Excluded every ordinary friendly NPC from buff and healing target discovery,
  whether selected, moused over, or exposed through a group-shaped token. The
  player and explicitly controlled companion remain valid owned recipients.

## 0.8.38

- Reduced the production search slice to 1.75 ms and made the 3.23 ms playable
  frame ceiling an asserted benchmark gate. The graph retains its total work
  and horizon across more frames instead of spending 4.25 ms in one live frame.
- Stopped a bare Attack command from outranking a productive melee opener. An
  initiating melee ability establishes the same ambient attack state, while
  Attack remains a low-value fallback when no useful opener is available.
- Added bounded hostile white-swing observations and projected post-mitigation
  damage events. Stable, target-owned rounds can now influence survival timing
  without inventing armor, block, shield, or rage counterfactuals.
- Limited mouseover friendly discovery to proven player characters. Friendly
  NPCs under the cursor no longer enter buff or healing recommendations.

## 0.8.37

- Kept the committed recommendation card visually stable while a consumed
  one-shot publication is replaced. Macro input no longer dims the entire HUD,
  swaps its status text, clears render keys, or repaints an unchanged runway;
  the invalidated atomic snapshot remains the actual execution safety boundary.
- Made a submitted wand start an acknowledgement barrier for player actions.
  Until the native Shoot repeat is confirmed active or inactive, another player
  spell cannot cancel the first bolt; independently clocked companion actions
  remain legal. This closes the observed Fire Blast, Shoot, immediate-cast
  cancellation loop without introducing a Mage rotation rule.

## 0.8.36

- Expanded every class through consequence-owned graph mechanics rather than
  priority lists. Root capture seals mutable DBC, aura, resource, cooldown,
  recipient and threat evidence once; branch-local class state is copied by a
  dedicated coordinator and incomplete mechanics continue to fail closed.
- Added measured Rogue combo investment. Direct finishers are compared against
  mechanically discovered builders using exact target-owned points, landed and
  missed attempts, damage curves, energy cost/time and fresh target survival.
  Exact lethal, imminent point loss and genuinely efficient low-point spending
  remain available; ambiguous evidence retains the generic marginal fallback.
- Added exact Mage Clearcasting, Presence of Mind and Cold Snap consequences.
  Cold Snap has zero standalone utility and opens a bounded setup lane only for
  Frost actions whose action-specific cooldown was actually delayed and reset;
  it never clears the GCD/category clocks or gains value from already-ready
  spells. Evocation remains withheld because its server mana phase is dynamic.
- Added exact Druid Cat/Bear threat composition and one-charge Omen/Clearcasting
  costs across mana, rage and energy; exact Hunter Hawk ranged power and
  selected-target Distracting Shot threat; and exact Shaman Clearcasting plus
  solo fresh-placement Mana Spring amount, cadence, expiry and stationary range.
- Added exact Hunter Rapid Fire reset consequences. Activating it preserves the
  current main-hand, off-hand and ranged phases, then shortens only later reset
  intervals; the exact low-word family mask also shortens Aimed Shot casts.
  Steady Shot's unresolved high-word mask and live server profile remain
  explicit, and Rapid Fire has no standalone priority value.
- Added all seven installed Earth Shock ranks as one binary Nature-damage and
  interrupt edge. Root capture seals level scaling, spell power, modifiers,
  hostile cast interruptibility and exact rank coefficients; one delivered roll
  owns both damage and the two-second target-local school lock. The current
  build-5875 server profile supplies an exact two-times damage-threat multiplier;
  live Octo acceptance and target interrupt immunity remain explicit gaps.
- Added exact Priest Inner Focus and Power Infusion consumer-dependent setup;
  Fade's level-scaled current-reference and expiry lifecycle; Paladin Righteous
  Fury, root-relative Blessing of Might and self Blessing of Wisdom periodic
  mana reachability; and branch-local state for every modeled aura, charge,
  proc and setup lane. Fade's server bridge remains visibly runtime-unverified.
- Added exact Seal of Righteousness Judgement consequences for every installed
  rank. Full family flags retain both words, the active seal selects its linked
  hidden Holy result, and ordinary delivery, resistance, target health, threat,
  cost and seal-consumption logic compose without a Paladin priority rule.
- Added Rogue Slice and Dice swing haste and Ruthlessness post-finisher point
  branches, including target ownership and delivery uncertainty. These mechanics
  alter later consequences without hardcoding combo thresholds or an opener.
- Added exact Rogue Preparation reset topology. It receives no standalone
  utility and retains one bounded setup lane only while a root-catalogued Rogue
  spell with positive recovery was delayed and becomes usable after the reset.
  Unowned category clocks remain conservative rather than being cleared.
- Added Druid Frenzied Regeneration as a fresh ten-tick branch-local timeline.
  It spends up to ten displayed rage per second, heals by exact rank, accounts
  for effective-heal threat and never applies a fake up-front heal. Unknown live
  tick phase, healing modifiers, destination Bear rage and server attestation
  remain explicit blockers or uncertainty.
- Added Warlock Dark Pact as an exact pet-mana transfer that must fund a later
  player spend, plus Soul Link's outgoing reduction and post-absorb demon split.
  Pet identity, health and delivery remain explicit causal inputs.
- Added one-charge Warlock Fel Domination as a bounded summon setup. Exact DBC
  masks, Master Summoner composition, expiry, successful consumption, cast time
  and mana deltas are projected without granting the setup standalone value.
- Added Warrior Battle Shout melee attack-power propagation, exact Revenge and
  Heroic Strike compound threat, max-four Thunder Clap damage/threat, and
  Demoralizing Shout's recipient-local flat threat/aura lifecycle. Unproven
  server identity stays visibly estimated; slows and attack-power mitigation
  receive no proxy value without hostile swing evidence.
- Replaced grouped Battle Shout's hard hold with a conservative recipient
  bound. The player always receives the exact attack-power consequence; frozen
  party/raid subgroup counts cap possible players and pets, while distance,
  pet presence and hostile-reference threat fanout remain explicitly inexact.
- Added exact Shield Wall damage-taken composition after Defensive Stance. Its
  temporary all-school multiplier changes frozen incoming consequences once,
  while unavailable live server attestation remains visibly estimated.
- Extracted identity-only class action dispatch from the shared coordinator.
  Multiple exact mechanics claiming one action now fail closed instead of
  depending on handler order, keeping class leaves independently reviewable.
- Preserved the sliced continuous-search contract and deterministic packaging.
  The production low-level Warrior, level-seven Warlock and rank-heavy Warlock
  benchmarks remain bounded at roughly 3.23 ms per active test slice.
- Defined the repository-owned playable 1.0 contract for every class, level
  band and role. Automated coverage is evidence, not proof of live playability;
  no class passes until deterministic gates and an authenticated in-game smoke
  test both succeed.

## 0.8.35

- Added exact target-local Hunter's Mark consequences for all four installed
  ranks. The aura itself has no proxy utility: only later Auto Shots and exact
  ranged-weapon actions receive its full post-coefficient ranged-attack-power
  component. Numeric aura identity, rank interaction, recipient identity, and
  ranged-lane evidence remain fail-closed.
- Added exact Priest Shadowform as a neutral strategic setup edge. Its captured
  forty-percent base-mana cost, fifteen-percent Shadow damage increase, and
  fifteen-percent physical damage reduction flow through future damage and
  frozen incoming events; consumer-side Holy/heal form exclusions remain
  enforced. Projecting an exit from Shadowform is intentionally still unknown.
- Added the installed first-rank Windfury Totem chain as a consequence-driven
  solo Shaman edge. Its twenty-percent nonrecursive main-hand extra attack is
  valued only on qualifying later attacks and makes subsequent swing phase
  stochastic. Party fanout and higher-rank chains remain fail-closed.
- Added exact Mage Mana Shield and Priest Power Word: Shield mechanics. Mana
  Shield admits only an unchanged live two-mana-per-physical-damage ratio,
  prices capacity after cast cost, and debits mana causally after ordinary
  absorbs; Power Word: Shield observes and projects the exact Weakened Soul
  recipient lockout. Its scorer now counts only frozen physical incoming casts;
  magic-only aggro cannot manufacture shield value. Modified or incomplete
  evidence fails closed.
- Added exact Rogue Feint as a selected-hostile flat threat consequence. Its
  level-scaled reduction uses the physical melee/weapon-skill delivery lane,
  touches no other hostile, and never fabricates a victim switch; uncertain
  delivery, ownership, and resource refund evidence remain conservative.
- Added exact Paladin all-threat blessing evidence. A self-applied installed
  25-percent reduction composes with stance/talent threat on later player
  actions, so usefulness emerges from descendants rather than a blessing rule.
  Greater/class fanout, ally output, changed topology, and unresolved stacking
  remain fail-closed.
- Corrected positive form-mask legality for installed spells carrying
  `ALLOW_WHILE_NOT_SHAPESHIFTED`: neutral form remains legal while an unrelated
  positive form does not. Negative masks such as Shadowform's Holy/heal
  exclusions continue to apply independently at every graph depth.
- Added exact Druid Prowl discovery without localized names or a class list.
  Its Cat-form and out-of-combat gates, indefinite stealth lifecycle, and real
  rank movement multipliers feed the existing setup graph, which still requires
  a target action that actually benefits from stealth before recommending it.
- Replaced Voidwalker Torment's taunt proxy with its exact installed
  damage-plus-flat-threat ranks and represented Suffering as a conservative
  selected-target threat lower bound. Delivery and pet threat modifiers scale
  the flat component once; unresolved area damage remains withheld.
- Corrected Warrior stance consequences from exact installed passives and
  Defiance ranks. Rank-five Defensive threat is 1.56 rather than 1.495; future
  stance edges immediately replace the old profile, while unknown live stance
  retains the DBC-sealed 0.80-to-1.56 range. Defensive mitigation/damage and
  Berserker critical/damage-taken evidence are retained for causal consumers.
- Added exact Bloodrage consequences from installed trigger topology and live
  base health: its immediate ten rage, ten one-rage ticks, sixty-second
  cooldown, combat entry, and twenty-percent base-health payment share one
  finite clock. It remains a neutral resource investment and is rejected when
  its exact health payment would be lethal.
- Added a session-learned player-mana clock without hardcoding Spirit, MP5,
  tick cadence, or the five-second rule. Exact player power changes exclude
  attributed energizes, learn a conservative passive envelope, and cross a
  projected cast only after repeated evidence proves that exact spell's
  successful GO-to-regeneration boundary; every mismatch fails closed.
- Recovered Expose Armor's exact installed per-combo reduction, stored in DBC
  as zero base plus 80/145/210/275/340 armor per point. The rank-safe value now
  reaches the existing probabilistic combo and target-modifier transitions.
  Target-modifier decoding was extracted from the capability catalogue into a
  focused module, reducing the former legacy file below its review exception.
- Added exact Warrior stance transitions and Druid form setup lanes that remain
  neutral until a later form-gated action proves their value. Tactical Mastery
  rage retention and rank-five Cat Furor's guaranteed 40-energy floor are
  projected from sealed evidence; unknown Bear destination rage stays unknown.
- Added one causal player dual-wield timeline. Main- and off-hand phases retain
  their own learned cadence while a shared cross-hand scheduler resolves
  simultaneous readiness, lethal first impacts, rage, and next-swing ownership
  without double damage or a permanently poisoned timer.
- Added exact direct-plus-periodic caster semantics for Fireball, Pyroblast, and
  Frostfire Bolt. Their impact can repeat while the existing tail remains a
  causal tick clock; Immolate and Holy Fire keep ordinary guarded-DoT behavior,
  and unknown lifecycle signatures fail closed.
- Added consequence-driven single-target crowd control, channel breakpoints,
  direct-heal triage, bounded player threat drops, and frozen resistance and
  weapon-skill evidence. Control without an exact lifecycle no longer receives
  the old fixed proxy score.
- Added exact installed-client Hunter Web, Charge, and Intimidation control
  chains. Roots retain their movement-control lifecycle without pretending to
  interrupt casts; Intimidation is valued only when a sealed target-pinned pet
  swing can deliver its stun before an exact incoming consequence.
- Preserved uncertainty when a combo action lacks an exact land probability,
  and kept deferred pet-melee trigger probability separate from result-spell
  delivery so a weaker later branch cannot replace a stronger control outcome.
- Added name-independent Paladin aura/Judgement and Shaman totem state adapters,
  exact form/equipment admission, and threat-drop coverage for Feign Death,
  Vanish, and Fade. Unrepresented downstream effects remain explicit holds.
- Reserved at most two deterministic strategic setup lanes inside the existing
  sliced search budget. Only a sealed destination-dependent consumer closes a
  lane, so form time cannot act as an implicit wait and setup-only paths cannot
  be published.
- Removed a cross-class root-observation hot path that reclassified every
  ordinary action through Warrior stance DBC reads. Root capture now also
  enumerates each recipient's auras once and shares identical weapon/school
  power evidence across ranks inside one evaluation. The production benchmark
  remains bounded at roughly 3.23 ms per test slice.
- Extracted friendly healing/buff/absorb transitions and incoming absorb
  ordering from the generic action-effect coordinators. The dedicated modules
  preserve ordinary behavior while keeping class-specific shields reviewable
  and all normal runtime files within the 450-line architecture ceiling.

## 0.8.34

- Added name-independent Druid form discovery from installed-client semantics,
  exact active/hidden mana-rage-energy snapshots, hidden-mana shapeshift
  payment, conservative unknown destination power, and a live race-checked
  cancel-to-caster executor. This is safe form mechanics, not yet a complete
  projected Cat/Bear combat strategy.
- Added preparatory exact player-aura replacement evidence for Hunter aspects,
  while failing their recommendations closed until each downstream combat
  effect is represented causally. Every modeled special ranged shot now
  consumes the same ammunition stock as Auto Shot; an earlier ambient launch
  can exhaust the final round before a casted shot, preventing phantom damage,
  resource payment, and recommendations.
- Added root-only player reactive-state evidence with an exact live-usability
  fallback for installed records that omit their aura-state requirement. Proc
  state is consumed branch-locally and never projected through an unknown wait.
- Added causal Warlock leech-channel ticks: delivered damage, capped paired
  healing, resistance, target identity, channel clipping, and scaled threat now
  resolve once at each exact remaining tick rather than at continuation choice.
- Added a bounded, identity-safe dispel evidence adapter as preparatory frozen
  capture infrastructure. It can infer dispel mechanics without localized
  names, but is deliberately not advertised as a usable recommendation path
  until RootObservation and scoring consume its frozen recipient decisions.
- Extracted action-context policy and capability-cache invalidation from shared
  modules, kept every normal runtime Lua file within the review ceiling, and
  retained the production search depth and approximately 3.23 ms maximum test
  slice.

## 0.8.31

- Added player Taunt as an exact root-only threat-rescue edge, distinct from
  companion taunts. It can take a selected hostile from the player's current
  pet or a current party/raid member while projecting only the bounded
  forced-target ownership window, never damage or a fabricated numeric threat
  lead.
- Required tank posture, Defensive Stance, exact rank/usability, cooldown,
  five-yard reach, and current victim evidence. Publication and
  immediate dispatch revalidate target, victim, and roster identity so a stale
  recommendation cannot Taunt an outsider or an enemy already attacking the
  player, while a proven ally pull remains rescuable before the player's own
  combat flag arrives.
- Added deterministic ally, pet, outsider, unknown-victim, partial-delivery,
  projected-repeat, three-second ownership-expiry, search-runway, stale-target,
  victim-race, roster-race, and immediate-versus-hostile-queue regressions
  without increasing the production graph benchmark.

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
