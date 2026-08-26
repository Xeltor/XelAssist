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
| Druid | Exact form identity and hidden mana/rage/energy state; neutral Cat/Bear shifts; observed Moonkin/Tree identities with engine-effective mana costs and exact DBC-mask legality; Cat Furor floor; Prowl as a consumer-dependent stealth setup; Bear and Cat player-threat multipliers; one-charge Omen/Clearcasting costs; Frenzied Regeneration's exact phase and bounded Bear incoming rage; installed Maul on-next-swing and Bear attack identities. | Tree/Moonkin party aura, movement, armor and tooltip-only family restrictions; destination Bear rage without proof; Ancient Brutality, Blood Frenzy and Berserk; Barkskin, Innervate, Thorns and other form passives without exact consumers. Bear action-specific threat remains withheld beyond the proven global multiplier. |
| Hunter | Generic controlled-pet lifecycle, commands, spellbook, focus, happiness, training, diet, targets, ranges, autocast and threat; ammunition and Auto Shot timeline; Hunter's Mark and Hawk ranged-power consequences; exact Viper periodic maximum-mana clock with bounded observed phase; Web, Charge and deferred Intimidation control; selected-target Distracting Shot threat; Rapid Fire timer consequences; target-owned Mongoose Bite Stinging Nettle application. | Snake attack-proc generation; Coordinated Assault handoff/ICD; Beast Mastery pet modifiers; Sting exclusivity and resource/defensive effects; trap arming/triggering; Carve recipients; special-shot projectile/clipping rules; deeper pet-family scheduling. |
| Mage | Mana Shield capacity and mana debit; one-charge Clearcasting costs; Presence of Mind; Cold Snap; observed-only Hot Streak and Flash Freeze numeric proc windows with branch-local consumption; Arcane Rupture identity; exact channel breakpoints; numeric Evocation recognition that withholds unsafe dynamic mana. | Proc generation remains observation-only; post-proc ordinary timing requires fresh root evidence; Frostfire resistance selection; Arcane Potency; current Arcane Power periodic maximum-mana mechanics; Icicles self-freeze/cancellation/self-damage; Accelerated Arcana; Evocation's Spirit/MP5/global-phase branches. |
| Paladin | Aura, Seal, Blessing and Judgement lifecycle discovery; exclusive replacement; exact all-threat Blessing and Righteous Fury multipliers; root-relative Blessing of Might melee attack-power consequences; single-target self Blessing of Wisdom amount, five-second phase, expiry and future mana reachability; Seal of Righteousness rank identity, seal consumption and linked hidden Judgement Holy-damage result; exact Hand of Reckoning victim-aware player taunt; installed Consecration ground topology with one conservative selected-hostile pulse and ordinary Holy threat. | Seal of the Martyr weapon-Holy/self-health/Judgement branches; Conviction's Holy strike and stacking critical aura; Crusader Strike's stacking Holy vulnerability; Consecration's later stationary recipients and runtime weighting; other Seal/Judgement consequences, Greater Blessing fanout and non-self Wisdom effects without exact recipient evidence. |
| Priest | Power Word: Shield and Weakened Soul; Shadowform's cost, Shadow output and physical mitigation; active Improved Shadowform's exact engine-reported Shadow mana costs and explicit non-projectable casting-regeneration evidence; Inner Focus and Power Infusion as consumer-dependent setups; healing triage; Fade's level-scaled current-reference application and temporary-threat expiry lifecycle; exact hostile Chastise Holy-damage branch. | Improved Shadowform's in-casting regeneration projection until the suppressed base rate and server phase are known; Chastise's ally-damaging haste branch; Fade's runtime-unverified bridge; Spirit Tap's predicate/mana regime; Shadow Mend self-damage; Pain Spike's deferred hostile heal; Vampiric Embrace/Touch delivered-damage fanout; multi-recipient support effects. |
| Rogue | Target-owned combo state and landed/missed branches; measured builder-versus-finisher investment; Slice and Dice swing haste; Ruthlessness; Preparation; Feint and bounded Vanish; stealth/rear admission; Dagger Mastery's learned normalized speed; exact Surprise Attack packet and builder semantics; Shiv's exact off-hand packet, combo gain, equipment gate, and live tooltip-sealed dynamic Energy cost. | Shiv's guaranteed poison delivery is deliberately uncredited until poison identity, stock and target effect are observable; Flourish parry duration; Fan of Knives recipients; Deadly Throw interrupt; Agitating Poison threat; Blade Flurry/Blade Rush and other custom resource procs. |
| Shaman | Exact four-slot totem replacement/lifetime; solo first-rank Windfury proc; installed Elemental Focus ownership and observed two-charge Clearcasting aura with exact branch-local engine costs; solo Mana Spring; exact Earth Shock damage/interrupt/lock/threat profile; Lightning Strike split packets; Molten Blast refresh of only the caster's Flame Shock while preserving its tick phase. | Elemental Focus proc generation remains observed-aura-only because private critical-event ordering is unproven; Spirit Armor's shield predicate, armor and threat; Totemic Recall refund; Lightning Strike shield trigger; group/higher-rank totem fanout and live pulse phase; charged Earth/Water Shield ICD phase; Spirit Link and other unproven recipients/effects. |
| Warlock | Demon identity, spellbook, resources, health, commands, autocast, targets, range and threat; summon/shard stock and reserve; Voidwalker threat actions; Health Funnel and leech-channel ticks; guarded DoT application; Dark Pact; Soul Link outgoing damage and post-absorb demon split; one-charge Fel Domination summon setup; exact Soul Fire ranks with atomic mana/shard payment; learned-rank and observed-aura-sealed Nightfall/Shadow Trance with one-use instant, guaranteed ordinary Shadow Bolt delivery. | Nightfall proc generation remains observed-aura-only; talent-modified pet/spell interactions; Demonic Empowerment, Mana Funnel, Power Overwhelming, Dark Harvest and Demon Gate; ambient passive-pet Soul Link attribution; unrepresented curse/debuff consequences. |
| Warrior | Stances, Tactical Mastery and Defiance profiles; white-hit/bounded incoming rage; Charge, Bloodrage, Taunt, Sunder, Battle Shout, Revenge, Heroic Strike, Thunder Clap, Execute, Demoralizing Shout and Shield Wall; exact Charge in Combat and Overpower; Devastate's exact weapon/Sunder-stack damage and landed Sunder refresh. | Devastate's private supplemental threat; Shield Bash/Hamstring/Disarm/Shield Slam packets and Octo threat; Shield Block counterfactual; Overpowering Rage haste, Whirlwind targets, reduced Heroic Strike/Slam threat and Bloodthirst/Mortal Strike cost passives; Berserker Rage and incoming-rage modifiers. |

## Shared combat domains

Every class uses the same graph domains: health and learned target survival;
mana/rage/energy/focus and finite inventory; GCD, pushback-aware cast and channel, swing and
cooldown clocks; exact or bounded range and position; target-local auras and
pending applications; physical weapon-skill and spell-delivery evidence;
school resistance and immunity observations; player, pet and group threat;
incoming cast consequences; crowd control, interrupts, absorbs and healing;
and bounded hostile/friendly recipient collections.

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
