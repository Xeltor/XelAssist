# Playable 1.0 release contract

## Definition

XelAssist 1.0 is playable when any Vanilla class can start at level 1 and keep
using the addon through level 60 without a class-specific rotation catalogue.
The graph must produce safe, useful and coherent actions from discovered ranks,
talents and combat state. A niche mechanic may remain a visible gap after 1.0;
a missing core loop, role, resource, actor or execution boundary may not.

Passing unit tests alone does not make a class playable. Every class requires
deterministic scenario evidence and an authenticated in-game smoke test on the
release candidate. Until both exist, its 1.0 status is **not proven**.

## Global release gates

- `/xa` consumes at most one fresh, still-valid player action per physical
  input. Repeated input never starts graph work, replays an old publication or
  races target, range, resource, aura, cooldown, cast or equipment state.
- Independently executable companion actions retain their own clocks, targets,
  resources and acknowledgement without causing an extra player action.
- Current and future recommendations remain visually stable through movement,
  GCD, casts, channels, resource waits and target motion. A wait or movement
  edge must not erase later causal actions.
- No recommendation chat spam, client crash or perceptible combat stutter is
  acceptable. Production search remains sliced at about 3.23 ms maximum in the
  deterministic benchmark, including rank-heavy and multi-actor catalogues.
- Damage, healing, overhealing, target survival, threat, aggro, resistance,
  delivery, range, movement, positioning, aura application, cooldowns, finite
  stock and uncertainty remain target- and actor-owned. Unknown evidence cannot
  silently become success, zero cost, infinite stock or fixed utility.
- Mouseover support admits proven player characters only; incidental friendly
  NPCs under the cursor are not buff or healing recipients.
- Consumables remain disabled by default and character policy controls finite
  resource use. Presentation remains global while combat behavior is primarily
  character-specific.
- Racial-specific combat optimization is deferred for 1.0. Shared graph
  mechanics may represent independently proven ordinary effects, but an
  unmodeled racial trigger or utility consequence receives no invented value.
- Lua 5.0 policy, module/function size ceilings, deterministic packaging, the
  complete automated suite, pushed Git state and exact two-root deployment all
  pass from the same commit.
- Login and decision processing automatically persist class, level, role,
  version, decision count, worst graph slice, budget-limit count and errors;
  the offline smoke audit reads this evidence without requiring a player command.

## Required scenario bands

Each class must pass three catalogue bands using discovered actions rather than
a test-only action order:

1. **Low level:** levels 1-10, sparse spellbook, missing talents, weak resources
   and an ordinary solo target.
2. **Mid level:** levels 20-40, rank replacement, at least one class-defining
   state machine, resource starvation/recovery, movement and a resistant or
   interruptible target.
3. **Level 60:** rank-heavy catalogue, allocated talents, equipment effects,
   cooldowns, threat/role pressure and a controlled or friendly actor where the
   class supports one.

Every band exercises out-of-combat setup, engage, sustained combat, target death
and recovery. Tank and healer classes also require role scenarios; pet classes
require summon/absence, command, resource, threat and recovery scenarios.

The current deterministic matrix contains unordered low-level and partial
mid-level and level-60 tranches for all nine classes, covering setup,
engagement, starvation/recovery, disruption, death and post-combat recovery.
The level-60 tranche additionally exercises rank-heavy catalogues and partial
role, equipment, resistance, interrupt and pet participation. Exact focused
proofs cover Mana Spring expiry, Seal replacement and Judgement consumption,
and Druid hidden-mana form transitions. Full tank, healer, pet and specialized
class-state obligations remain open, so no class row is promoted solely by
these tests.

## Class playability contracts

| Class | Core 1.0 proof obligations | Current status |
| --- | --- | --- |
| Druid | Caster and healing basics; Cat/Bear forms, hidden resources, stealth, combo/rage/energy, threat and survival; safe shift reachability. | Not proven |
| Hunter | Melee/ranged distance transition, dead zone, ammunition, Auto Shot and special shots; pet absence/summon/commands/focus/happiness/threat/recovery; sting/trap lifecycle sufficient for leveling. | Not proven |
| Mage | School-aware direct/periodic damage, mana recovery, control and channel decisions; Clearcasting, major cast/cooldown setups and defensives without clipping useful channels. | Not proven |
| Paladin | Seal/Judgement cycle, blessings/auras, melee and Holy threat, healing/defense, mana recovery and role-aware tank/healer behavior. | Not proven |
| Priest | Damage and healing triage, Shield/Weakened Soul, mana recovery, threat reduction, Shadowform and support targeting across solo and healer roles. | Not proven |
| Rogue | Energy cadence, stealth/rear openers, combo ownership and builder/finisher investment, Slice and Dice, threat escape and poison lifecycle sufficient for leveling. | Not proven |
| Shaman | Melee/caster/healing basics, shocks and shared cooldown, weapon imbues, totem slots/range/pulses, Clearcasting and threat consequences. | Not proven |
| Warlock | DoT/curse survival value, Life Tap and drains, shard reserve, summon costs, demon identity/spellbook/resources/commands/range/threat/recovery and channel safety. | Not proven |
| Warrior | Rage generation/spending, white and queued swings, stances, Charge/Bloodrage, tank threat/taunt/mitigation, weapon requirements and defensive survival. | Not proven |

## Confirmed blocking evidence

Current Octo `patch-5.mpq` is authoritative for custom class mechanics; older
patch data can be materially stale. The following are release blockers, not a
request to add a class priority rule:

- **Shared incoming melee:** a bounded attacker/victim white-round ledger now
  projects observed post-mitigation health loss and baseline Warrior/Bear rage.
  Exact counterfactual block/armor/absorb value, attack-power and speed debuffs,
  Shield Block facing/skill/value, defensive pet autocasts and avoidance-driven
  reactive windows remain global gates for tank and healer proof.
- **Mage:** custom Arcane Power changes cast speed, drains maximum mana every
  second, suppresses mana gain, cannot be cancelled and kills the caster below
  ten-percent mana. Icicles can shatter into large self-damage, while
  Accelerated Arcana changes Arcane Missiles tick timing. These actions must
  fail closed until branch-local mana, terminal-health and effective-channel
  timing consequences exist. Exact Evocation planning additionally requires
  Spirit/MP5 regimes and the player-global mana-tick phase.
- **Priest:** Shadow Mend's heal also damages the Priest, and Pain Spike heals
  its hostile target back after a delay; generic heal/direct-damage semantics
  are unsafe. Spirit Tap's current kill-or-Mind-Blast-critical predicate and
  active regeneration require exact server/observed proc evidence plus the same
  mana-regime work. Vampiric Embrace/Touch and party-heal progression require
  target-owned delivered-damage triggers and bounded recipient fanout.
- **Shaman:** Earth Shock now carries the exact current build-5875 two-times
  damage-threat profile, but live Octo acceptance and target mechanic-interrupt
  immunity remain blockers for claiming complete tank/interrupt behavior. Its
  damage, binary delivery, cast predicate and school-lock lifecycle are modeled.
  Molten Blast now refreshes only the caster's existing Flame Shock and preserves
  its tick phase. Earth/Water Shield charges and proc amounts are known, but the
  live three-second proc phase is not observable and repeated procs remain withheld.
  Stormstrike now owns its exact two-charge direct-Nature amplifier and distinct
  landed/missed expiry branches; periodic, pet and ambient charge consumption
  remains explicitly uncredited pending an Octo event contract.
- **Warrior:** low-level grouped play requires the character role to be set to
  Tank because Defensive Stance evidence does not exist yet; onboarding must
  make that explicit rather than inventing an automatic role. Mid/60 threat
  has exact learned Charge-in-combat legality and all four Overpower rank
  packets without inventing action-specific threat. Mid/60 threat still needs
  exact Hamstring, Disarm and Shield Slam packets; Shield Bash now has exact
  rank, cost, stance, equipment, range and interrupt semantics, with only its
  private supplemental threat withheld. Defensive
  Tactics rank and shield ownership are observable, but its
  dummy-aura server arithmetic is not; cross-stance threat therefore remains
  unknown rather than guessed. Grouped Battle Shout is now usable through exact
  self AP and bounded subgroup/pet fanout instead of hard-HOLDing. Berserker
  Rage now owns its exact ten-second 30-percent incoming-damage rage modifier;
  fear/incapacitate utility and Improved Berserker Rage talent packets remain
  withheld without a hostile-control or exact triggered-resource contract.
- **Hunter and Warlock pets:** actor, command, resource, range, threat and
  recovery coverage is substantial, and Voidwalker Sacrifice already applies
  the player shield before removing the demon. Defensive autocasts remain
  effect-unknown until incoming melee exists. Manual Feed Pet is acceptable for
  1.0 if compatible-food automation remains explicitly unavailable.
- **Paladin and Druid tanks:** Consecration now has exact installed ground
  topology and conservatively credits one selected-hostile Holy pulse; later
  stationary-ground recipients and Octo's runtime pulse weighting remain
  unknown instead of following the target. Bear Swipe/Maul/Savage Bite rank and
  packet identities are installed-data exact, including Maul's on-next-swing
  behavior; action-specific threat bonuses remain withheld because only the
  global Bear threat multiplier is proven. Existing forms, resources and threat
  profiles alone cannot yet prove tank playability.
- **Rogue:** current combo, energy, target-survival, stealth/rear, Slice and
  Dice, Ruthlessness, Preparation and Feint coverage is sufficient for focused
  scenario proof. Poison stocks and Blade Flurry remain optimization unless a
  live smoke test proves they block ordinary leveling.

The patch-5-wide divergence audit also promoted these unowned ordinary-loop
mechanics into the tracked backlog: Druid Blood Frenzy and Ancient Brutality's
Bear branch; Hunter Coordinated Assault; Shaman Spirit Armor; and Warrior hidden
haste, recipient, threat and cost passives. Frostfire resistance selection and
Improved Chain Heal timing are now exact. Seal of
the Martyr, Resurgent Shield, Improved Shadowform, Shiv, two-charge Elemental
Focus and Nightfall/Shadow Trance now have installed-client ownership, with
their remaining private health, refund, regeneration, poison-delivery or
proc-generation boundaries explicitly withheld. Client topology is available
for the remaining backlog, but private arithmetic, proc phase or recipient
behavior stays bounded until Octo-authoritative evidence exists.

The wider topology sweep also searches changed ranks, replacement actions,
triggered children, proc auras, forms, pet modifiers, equipment masks and
hidden SpellMods rather than relying on custom spell names. Its current
evidence-ranked queue includes:

- Druid remaining Moonkin/Tree party and tooltip-only consequences, Enrage's
  baseline/armor lifecycle, Blood Frenzy haste, plus Feral Adrenaline;
- Hunter Snake/Swift Aspects proc generation, non-Serpent Sting consequences,
  traps and Lock and Load;
- Mage Hot Streak/Flash Freeze proc generation and post-proc baseline timing,
  Arcane Power, Temporal Convergence and Resonance Cascade;
- Paladin Holy Shock proc generation/post-consumption baseline and Blessed
  Strikes;
- Priest Resurgent Shield break arithmetic, custom mana-loop passives and
  unresolved future Ascendance consequences;
- Rogue Noxious Assault and observed Nightblade procs;
- Shaman charged shield phases, additional Elemental Focus triggers, Totemic
  Alignment and Calming Winds;
- Warlock pet-cast modifiers, Mana Funnel and Shadow Strikes; and
- Warrior Devastate's private supplemental threat, Shield Block value,
  Shield Mastery/Reprisal, weapon-dependent Master Strike and hidden
  cooldown/cost modifiers.

An exact observed-aura plus engine-effective cost/cast/cooldown/duration layer
can own deterministic SpellMods across classes. Proc generation, refunds,
passive regeneration, threat, recipient fanout and private arithmetic remain
separate causal domains and may not inherit value from DBC descriptions alone.

## Evidence ledger

For each class, the release candidate records:

- scenario test names and exact commit;
- low, mid and level-60 pass/fail results;
- applicable damage, tank, healer and pet-role results;
- remaining explicit gaps and why none blocks ordinary play;
- in-game character, level, role, target type and observed outcome;
- FrameXML/client errors, graph timing and decision-log review;
- tester acceptance or the exact blocker to fix.

The 1.0 tag is allowed only when every class row is proven and every global gate
passes on the same deployed commit. `docs/class-mechanics.md` remains the deeper
mechanic ledger; it cannot substitute for this playability proof.
