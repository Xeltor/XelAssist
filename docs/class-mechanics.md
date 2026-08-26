# Class mechanic coverage

This document is a review ledger, not a rotation catalogue. XelAssist discovers
the character's available actions and lets graph consequences decide which edge
is useful. A mechanic belongs here only when its state, cost, timing, recipient,
and downstream effect have an explicit owner.

Coverage labels used below:

- **Modeled** means the graph has a causal transition backed by installed-client
  or live evidence.
- **Bounded** means the graph retains an explicit estimate or uncertainty flag.
- **Withheld** means XelAssist recognizes the domain but refuses to assign proxy
  value until the missing consequence can be proven.

## Current class coverage

| Class | Modeled causal mechanics | Important withheld or bounded work |
| --- | --- | --- |
| Druid | Exact form identity and hidden mana/rage/energy state; neutral Cat/Bear shifts; observed Moonkin/Tree identities with engine-effective mana costs and exact DBC-mask legality; rank-five Furor Cat floor and in-combat Bear/Dire Bear floor; Prowl as a consumer-dependent stealth setup; Bear and Cat player-threat multipliers; one-charge Omen/Clearcasting costs; Frenzied Regeneration's exact phase and bounded Bear incoming rage; exact Barkskin physical mitigation, cast delay and melee slowdown lifecycle; exact Growl form/range/cooldown/fixate with a live selected-victim boundary; Ancient Brutality's exact Cat-side energy from delivered owned bleed ticks; Blood Frenzy's exact immediate Enrage rage packet; installed Maul on-next-swing and Bear attack identities. | Tree/Moonkin party aura, movement, armor and tooltip-only family restrictions; out-of-combat destination Bear rage where ordinary decay can invalidate the Furor floor; Ancient Brutality's Bear dodge branch; Enrage baseline/armor and Blood Frenzy haste lifecycle; Berserk; Barkskin pushback counterfactual, Innervate, Thorns and other form passives without exact consumers. Bear action-specific threat remains withheld beyond the proven global multiplier. |
| Hunter | Generic controlled-pet lifecycle, commands, spellbook, focus, happiness, training, diet, targets, ranges, autocast and threat; ammunition and Auto Shot timeline; Hunter's Mark and Hawk ranged-power consequences; exact Viper periodic maximum-mana clock with bounded observed phase; exact observed Alone Against the World player-damage modifier with explicit dismissed-pet evidence; Web, Charge and deferred Intimidation control; selected-target Distracting Shot threat; Rapid Fire timer consequences; target-owned Mongoose Bite Stinging Nettle application; bounded Feign Death interruption/wake lifecycle and coupled threat uncertainty; exact own-Sting exclusivity with supported Serpent Sting. | Feign Death runtime acceptance; Viper/Scorpid/Wyvern downstream effects; Snake and Swift Aspects proc generation; Coordinated Assault handoff/ICD; Beast Mastery pet modifiers; trap arming/triggering; Carve recipients; special-shot projectile/clipping rules; deeper pet-family scheduling; quiver and item/set procs. |
| Mage | Mana Shield capacity and mana debit; one-charge Clearcasting costs; Presence of Mind; Cold Snap; observed-only Hot Streak and Flash Freeze numeric proc windows with branch-local consumption; Frostfire's lower proven Fire/Frost resistance selection; Accelerated Arcana's engine-effective five-tick Arcane Missiles cadence; exact reactive Arcane Surge ranks and positive-resistance bypass; Arcane Rupture identity; exact channel breakpoints; numeric Evocation recognition that withholds unsafe dynamic mana; exact Arcane Power identity guarded from lethal generic-buff fallthrough. | Proc generation remains observation-only; Arcane Rupture stacking modifier; Resonance Cascade; Temporal Convergence; mana-return passives; Arcane Potency; Arcane Power branch-local periodic maximum-mana drain, mana-gain suppression, uncancellable lifetime and terminal health consequence; Icicles self-freeze/cancellation/self-damage; Evocation's Spirit/MP5/global-phase branches. |
| Paladin | Aura, Seal, Blessing and Judgement lifecycle; exact Blessing/Righteous Fury threat, Might and self Wisdom consequences; Seal of Righteousness/Judgement; Hand of Reckoning; bounded Consecration; observed-only Holy Shock GCD/cooldown modifier auras with branch-local consumption; exact Seal of the Martyr linked topology with unsafe compound damage withheld; exact Crusader Strike identity guarded from generic fallthrough; exact Lay on Hands rank topology guarded from unsafe free-heal fallthrough. | Lay on Hands all-mana debit, recipient mana ordering/cap and Improved Lay on Hands aura; Crusader Strike private direct packet and flat-Holy stack lifecycle; Holy Shock and Blessed Strikes proc generation plus post-consumption baseline timing; Martyr self-health arithmetic; Conviction; later Consecration recipients; remaining Seal/Judgement and multi-recipient blessing effects. |
| Priest | PW:S/Weakened Soul; observed Resurgent Shield result identity without double-counting root engine power; Shadowform and active Improved Shadowform engine costs; Inner Focus/Power Infusion; healing triage; Fade; hostile Chastise; exact Ascendance action/aura/Apotheosis identity and active-state engine healing costs; exact Shadow Mend/Pain Spike identities guarded from generic fallthrough. | Shadow Mend self-damage and Pain Spike delayed hostile heal; Resurgent Shield future break linkage, refund and absorption-scaled Holy magnitude; Ascendance future activation, CC purge, private cast/cost arithmetic and Apotheosis fanout; Improved Shadowform casting regen; Chastise ally branch; Spirit Tap and custom mana-loop passives; Vampiric fanout and multi-recipient support. |
| Rogue | Target-owned combo state and landed/missed branches; builder/finisher investment; Slice and Dice; Ruthlessness; Preparation; Feint/Vanish; stealth/rear; Dagger Mastery; Surprise Attack; Shiv's off-hand/cost boundary; Mark for Death's exact main-hand packet, two combo points and avoidance/equipment gates; exact patch-5 Blade Flurry tradeoff identity guarded from harmful generic-AoE fallthrough. | Shiv poison delivery and Noxious Assault dual-weapon/AP/poison script; poison stocks/procs; Flourish; Fan of Knives; Deadly Throw; Agitating Poison; Blade Flurry's server-selected secondary recipient and Blade Rush/custom resource procs. |
| Shaman | Exact four-slot totem replacement/lifetime; solo first-rank Windfury proc; installed Elemental Focus ownership and observed two-charge Clearcasting aura with exact branch-local engine costs; solo Mana Spring; exact Earth Shock damage/interrupt/lock/threat profile; exact Stormstrike application, twelve-second lifetime and probabilistic two-charge 25-percent direct Nature amplification; Lightning Strike split packets; Improved Flame Shock's engine-effective duration; Molten Blast refresh of only the caster's existing Flame Shock while preserving its tick phase; Improved Chain Heal's exact engine cast-time reduction; exact shield-gated Spirit Armor all-threat multiplier; Totemic Slam and Ethereal Form guarded from unsafe generic fallthrough. | Stormstrike periodic/pet/ambient consumption remains withheld; Elemental Focus proc generation remains observed-aura-only because private critical-event ordering is unproven; Totemic Slam's private AP packet; Ethereal Form's coupled casting lock; Spirit Armor's shield-armor increase; Totemic Recall refund; Lightning Strike shield trigger; Chain Heal jump recipients; group/higher-rank totem fanout and live pulse phase; charged Earth/Water Shield ICD phase; Spirit Link and other unproven recipients/effects. |
| Warlock | Demon identity, spellbook, resources, health, commands, autocast, targets, range and threat; summon/shard stock and reserve; Voidwalker threat actions; Health Funnel and leech-channel ticks; guarded DoT application; Dark Pact; Soul Link outgoing damage and post-absorb demon split; one-charge Fel Domination summon setup; exact Soul Fire ranks with atomic mana/shard payment; learned-rank and observed-aura-sealed Nightfall/Shadow Trance with one-use instant, guaranteed ordinary Shadow Bolt delivery. | Nightfall proc generation remains observed-aura-only; talent-modified pet/spell interactions; Demonic Empowerment, Mana Funnel, Power Overwhelming, Dark Harvest and Demon Gate; ambient passive-pet Soul Link attribution; unrepresented curse/debuff consequences. |
| Warrior | Stances, Tactical Mastery and Defiance profiles; white-hit/bounded incoming rage; Charge, Bloodrage, Taunt, Sunder, Battle Shout, Revenge, Heroic Strike, selected-origin Cleave, Thunder Clap, Execute, Demoralizing Shout, Shield Bash and Shield Wall; legal Shield Block one/two-charge window; exact Charge in Combat and Overpower; exact Shield Slam ranks with shield/rage/range/cooldown/base packet and non-weapon boundary; Devastate's exact weapon/Sunder-stack damage and landed Sunder refresh; Berserker Rage's exact ten-second 30-percent incoming-damage rage modifier. | Cleave's server-selected secondary remains uncredited and invalidates possible secondary state; Shield Block value/facing and counterfactual mitigation; Shield Mastery/Reprisal/Improved Shield Slam; Shield Slam's private AP/block-value additions, hostile-dispel probability and Octo threat; Devastate's and Shield Bash's private supplemental threat; Hamstring/Disarm packets and Octo threat; Overpowering Rage haste, Whirlwind targets, reduced Heroic Strike/Slam threat and Bloodthirst/Mortal Strike cost passives; Berserker Rage control utility and Improved Berserker Rage talent packets. |

## Shared combat domains

Every class uses the same graph domains: health and learned target survival;
mana/rage/energy/focus and finite inventory; GCD, pushback-aware cast and channel, swing and
cooldown clocks; exact or bounded range and position; target-local auras and
pending applications; physical weapon-skill and spell-delivery evidence;
school resistance and immunity observations; player, pet and group threat;
incoming cast consequences; crowd control, interrupts, absorbs and healing;
exact recipient/type/count-bounded dispels; and bounded hostile/friendly
recipient collections.

Missing evidence remains a named graph horizon or blocker. It must not silently
turn into a boolean, fixed utility bonus, assumed target, or typed action order.

Octo divergence audits cover more than newly named spells. Installed patch DBC
rows are compared with the forked ClassicAPI behavior mirror and attributed live
events for changed ranks, talents, proc auras, triggered spells, hidden passives,
forms, pets, costs, cooldowns, duration modifiers, threat and resource rules.
Changed topology is either given a causal owner or recorded as explicitly
withheld; upstream Vanilla data is corroboration, never authority for Octo.

Racial combat optimization is explicitly deferred for 1.0. A racial may use an
ordinary direct damage, heal, resource, aura, cooldown, or control consequence
only when the shared installed-client evidence proves it independently; no
race-specific trigger, utility, recipient, or strategic bonus is inferred.
Unknown racial consequences therefore remain neutral or withheld rather than
becoming a hidden class priority.

This ledger describes mechanic ownership. It does not by itself prove that a
class is playable. The separate `playable-1.0.md` contract requires level-band,
role, input-safety, performance and authenticated in-game evidence.
