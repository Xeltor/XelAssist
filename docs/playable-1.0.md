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
- Lua 5.0 policy, module/function size ceilings, deterministic packaging, the
  complete automated suite, pushed Git state and exact two-root deployment all
  pass from the same commit.

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

- **Shared incoming melee:** Nampower exposes hostile white-swing attacker,
  victim, damage, block, absorb, resist and hit state, but the current runtime
  discards non-player-owned rounds. A bounded attacker/victim swing ledger is a
  global P0 gate: without it the graph cannot causally value Warrior Shield
  Block, Thunder Clap/Demoralizing Shout mitigation, Paladin Holy Shield/Redoubt,
  Druid tank mitigation, pet defensives or healer timing against melee damage.
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
- **Warrior:** low-level grouped play requires the character role to be set to
  Tank because Defensive Stance evidence does not exist yet; onboarding must
  make that explicit rather than inventing an automatic role. Mid/60 threat
  still needs exact Shield Bash, Hamstring, Disarm, Overpower and Shield Slam
  packets. Grouped Battle Shout is now usable through exact self AP and bounded
  subgroup/pet fanout instead of hard-HOLDing.
- **Hunter and Warlock pets:** actor, command, resource, range, threat and
  recovery coverage is substantial, and Voidwalker Sacrifice already applies
  the player shield before removing the demon. Defensive autocasts remain
  effect-unknown until incoming melee exists. Manual Feed Pet is acceptable for
  1.0 if compatible-food automation remains explicitly unavailable.
- **Paladin and Druid tanks:** Consecration needs periodic ground pulses and
  Holy threat rather than generic immediate AoE. Bear Swipe/Maul/Savage Bite
  packets need exact evidence after the shared incoming-melee gate; existing
  forms, resources and threat profiles alone cannot prove tank playability.
- **Rogue:** current combo, energy, target-survival, stealth/rear, Slice and
  Dice, Ruthlessness, Preparation and Feint coverage is sufficient for focused
  scenario proof. Poison stocks and Blade Flurry remain optimization unless a
  live smoke test proves they block ordinary leveling.

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
