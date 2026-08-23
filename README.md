# XelAssist 0.2.0

XelAssist is a private, input-driven combat assistant for OctoWoW 1.18. It
chooses one legal action from a bounded, explainable graph and executes only in
response to a physical binding press or click. It never acquires or switches a
hostile target and never performs combat actions from `OnUpdate`.

## Requirements

- SuperWoW
- SuperAPI
- Nampower

ClassicAPI is optional. Missing required runtime capabilities disable execution
and produce a clear local-chat error.

## Controls

Bind actions under the XelAssist heading in Key Bindings, or click the large
native action button. `/xassist` and `/xa` accept `execute`, `why`, `smart`,
`single`, `aoe`, `support`, `cooldowns`, `consumables`, `reagents`,
`diagnostics`, `show`, and `hide`.

Cooldowns, consumables, and limited reagents start disabled per character.
Healing chooses mouseover, then the current friendly target, then the most
injured party or raid token. Damage requires an already-selected hostile target.

When Smart mode has a selected friendly target, it recommends an applicable
missing buff and casts it directly on that unit without changing targets.
Self-only and mana-only rules prevent invalid recommendations.

## Safety fallback

The graph is limited to depth three, width four, 40 expanded states, and a 2 ms
budget. Missing data, evaluation errors, and budget overruns conservatively hold
without casting.

## Validation

```sh
python3 scripts/validate_xelassist.py
```

This checks the TOC, XML, Lua policy, execution invariants, nine class profiles,
friendly-buff routing, and the mocked evaluator budget.

