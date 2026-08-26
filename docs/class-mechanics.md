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
| Druid | Exact form identity and hidden mana/rage/energy state; neutral Cat/Bear shifts; Cat Furor floor; Prowl as a consumer-dependent stealth setup; Bear and Cat player-threat multipliers; one-charge Omen/Clearcasting costs; Frenzied Regeneration's fresh one-second phase, ten rage-consuming ticks, self-healing and bounded healing threat; bounded Bear rage from projected delivered hostile damage; exact installed Maul on-next-swing and Bear attack rank identities without invented per-action threat multipliers. | Destination Bear rage without proof; Enrage, Barkskin, Innervate, Thorns, and form-specific offensive/defensive passives that do not yet have exact consumers. Incoming-rage server rate modifiers remain estimated. Swipe, Maul and Savage Bite retain the exact global Bear threat multiplier, but action-specific threat is withheld because neither installed data nor the local server mirror proves one. Frenzied Regeneration's server profile is visibly runtime-unverified and an already-live unknown tick phase fails closed. |
| Hunter | Generic controlled-pet lifecycle, commands, spellbook, focus, happiness, training, diet, targets, ranges, autocast and threat; ammunition and Auto Shot timeline; Hunter's Mark and Hawk ranged-power consequences; Web, Charge and deferred Intimidation control; selected-target Distracting Shot threat; Rapid Fire's exact current-phase preservation, later main/off/ranged reset intervals and low-mask Aimed Shot cast-time consequence; target-owned Mongoose Bite Stinging Nettle application with exact talent/rank/duration evidence and conservatively estimated Sting magnitude. | Sting exclusivity and resource/defensive effects; Stinging Nettle's fire-trap trigger; trap arming and triggering; Carve's unobservable cone recipients; special-shot projectile/clipping rules; deeper pet-family rank, loyalty and ability scheduling. Steady Shot's high-word Rapid Fire mask and the live server haste profile remain visibly unverified. |
| Mage | Mana Shield capacity and mana debit; one-charge Clearcasting costs; Presence of Mind as a one-use cast-time setup; Cold Snap's exact changed-Frost-cooldown reset lane; Arcane Rupture's direct-damage identity; exact channel breakpoints where tick evidence exists; numeric Evocation and linked custom-talent recognition that explicitly withholds the action when its dynamic mana consequences cannot be projected. | Current-Octo Arcane Power's periodic maximum-mana drain, gain suppression, cast haste, noncancelability and lethal low-mana boundary; Icicles self-freeze, cancellation rules and self-damage; Accelerated Arcana tick timing; Evocation's Spirit/MP5/global-phase decomposition and linked Evocation Mastery/Nether Overcharge branches; any channel tick whose amount or phase cannot be frozen at the root. These unsafe custom actions must fail closed until owned. |
| Paladin | Aura, Seal, Blessing and Judgement lifecycle discovery; exclusive replacement; exact all-threat Blessing and Righteous Fury multipliers; root-relative Blessing of Might melee attack-power consequences; single-target self Blessing of Wisdom amount, five-second phase, expiry and future mana reachability; Seal of Righteousness rank identity, seal consumption and linked hidden Judgement Holy-damage result; exact Hand of Reckoning victim-aware player taunt; installed Consecration ground topology with one conservative selected-hostile pulse and ordinary Holy threat. | Consecration's later stationary-ground recipients and Octo runtime pulse weighting remain uncredited rather than following the cast-time target. Other Seal/Judgement damage, healing and mana consequences that remain lifecycle-only; Greater Blessing class fanout; non-self Wisdom recipients and downstream aura effects without exact recipient evidence. |
| Priest | Power Word: Shield and Weakened Soul; Shadowform's cost, Shadow output and physical mitigation; Inner Focus and Power Infusion as consumer-dependent setups; healing triage; Fade's level-scaled current-reference application and temporary-threat expiry lifecycle; exact hostile Chastise Holy-damage branch. | Chastise's ally-damaging, health/level-gated haste branch is explicitly withheld. Fade's server-side dummy-aura bridge remains visibly runtime-unverified; current Spirit Tap's kill-or-Mind-Blast-critical predicate and mana regime; Shadow Mend self-damage; Pain Spike's deferred hostile heal; Vampiric Embrace/Touch delivered-damage fanout; multi-recipient prayer and other recipient-ambiguous support effects. |
| Rogue | Target-owned combo state and landed/missed branches; measured builder-versus-finisher damage/energy/time investment when combo, energy-clock and target-survival evidence are exact; generic marginal fallback otherwise; Slice and Dice swing haste; Ruthlessness post-finisher branches; exact Preparation cooldown resets; Feint and bounded Vanish threat changes; stealth and rear-position action admission; Octo Dagger Mastery's learned 2.3 normalized speed. | Poison stocks/procs, Blade Flurry fanout, Blade Rush cadence, Honor Among Thieves/Vigor/Nightblade resource procs, and non-direct finisher utility curves. Preparation remains a neutral setup until a spell it actually made ready is selected. |
| Shaman | Exact four-slot totem replacement/lifetime; solo first-rank Windfury main-hand proc consequence; one-charge Clearcasting costs; solo fresh-placement Mana Spring tick amount, cadence, expiry and stationary range; all seven Earth Shock ranks with sealed raw Nature damage, binary delivery, exact hostile-cast predicate, target-local two-second school lock and current build-5875 two-times damage-threat profile; exact installed Lightning Strike rank coefficients and separate Physical/Nature mitigation lanes; all installed Molten Blast ranks refresh only the caster's existing Flame Shock while preserving its periodic tick phase. | Lightning Strike's exact shield trigger is recorded but its private consequence is unvalued. Group totem fanout; higher-rank Windfury chains; live-existing totem pulse phase; charged Earth/Water Shield behavior and its unobservable proc-ICD phase, Spirit Link redistribution, and other offensive, defensive and resistance totems whose recipients or server effects cannot be proven. Earth Shock's live Octo profile acceptance and target mechanic-immunity verdict remain unavailable. |
| Warlock | Demon identity, spellbook, resources, health, commands, autocast, targets, range and threat; summon/shard stock and reserve; Voidwalker threat actions; Health Funnel and leech-channel ticks; guarded DoT application; Dark Pact; Soul Link outgoing damage and post-absorb demon split; one-charge Fel Domination summon cast-time and mana setup; exact patch-5 Soul Fire ranks with atomic mana and shard payment. | Talent-modified pet/spell interactions without live modifier evidence; Demonic Empowerment, Mana Funnel, Power Overwhelming, Dark Harvest and Demon Gate custom consequences; ambient passive-pet Soul Link attribution; curse/debuff consequences that are recognized but not yet represented downstream. |
| Warrior | Stances, Tactical Mastery retention and Defiance/threat/mitigation profiles; outgoing white-hit and bounded incoming-damage rage; Charge, Bloodrage, Taunt, Sunder Armor, Battle Shout, Revenge, Heroic Strike and Thunder Clap damage/threat; Thunder Clap's future-reset attack-speed slow; installed-Octo Execute rank, threshold, base damage and variable-rage conversion with bounded hit-side payment; grouped Battle Shout's exact self AP plus bounded subgroup/pet and flat-threat fanout; Demoralizing Shout's per-recipient flat threat and aura lifecycle; exact Shield Wall damage-taken composition. | Execute's private server hit-side script remains visibly runtime-unverified and uncertain delivery ends exact later rage planning. Demoralizing Shout's attack-power mitigation and Shield Block remain withheld until the hostile counterfactual inputs exist; Berserker Rage and server income-rate modifiers for incoming rage; other defensive consequences; exact Shield Bash/Hamstring/Disarm/Overpower/Shield Slam packets; server threat and Shield Wall profiles remain visibly runtime-unverified where the live server cannot attest them. |

## Shared combat domains

Every class uses the same graph domains: health and learned target survival;
mana/rage/energy/focus and finite inventory; GCD, cast, channel, swing and
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
