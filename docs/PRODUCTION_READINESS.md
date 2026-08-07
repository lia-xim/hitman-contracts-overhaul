# Production Readiness Gate

**Candidate:** `0.14.3-rc37`
**Target:** Intravenous 2 `1.4.12HF3`  
**Decision:** code-complete production candidate; not promoted to `1.0` until the live matrix below passes.

## Balance contract

| Game difficulty | Response | Guard / target health | Drone pressure | Acquisition | Sensor range | Reward | Threat shift |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Easy | 75% | 82% / 86% | 80% | 128% time | 90% | 90% | -1 |
| Normal | 100% | 100% / 100% | 100% | 100% time | 100% | 100% | 0 |
| Hard | 108% | 108% / 108% | 108% | 90% time | 106% | 110% | 0 |
| True | 115% | 112% / 112% | 114% | 82% time | 112% | 118% | +1 |
| Custom | Bounded 82–114% | Bounded 88–113% | Bounded 86–114% | Derived from vision | 65–150% | 90–114% | -1 / 0 / +1 |

Five close bodyguards are structural and never removed by difficulty scaling. Only autonomous response units scale. Archetype strength remains meaningful: Broker II, Executive III, Fixer IV and Commander V before the difficulty shift.

Drones are pressure tools, not bullet sponges. Scout and Light airframes die in one registered hit. Heavy Pistol takes two ordinary hits; Heavy SMG and Heavy Laser take two or three. A strong rifle removes two structural points but every Heavy survives its first registered hit.

## Readability and performance limits

- Maximum seven active drones per contract and twelve across the whole mission.
- Maximum two Heavy and two Laser airframes per contract.
- Baseline identity acquisition is 0.55 seconds before model, doctrine, mode and difficulty modifiers.
- A calm valid disguise reduces routine acquisition to 22% speed; aggressive security never falls below 72% speed.
- Every attack requires a completed native geometry trace, an outdoor roof-map footprint, a valid visible airframe, a centered physical bullet target, range, gimbal alignment, a readable aim/charge cue and cooldown readiness.
- Release diagnostics are off by default. Player-facing notices are rate-limited and use the native feedback layer.
- Moving fixtures self-repair, follow the visible aim center and retain a post-world-collision projectile fallback for runtime combinations that omit late fixtures. A persistently unhittable carrier is inert and automatically retired.
- Destruction is a hard terminal boundary: every queued weapon state, detection accumulator, aim cue, rotor loop and native light-buffer allocation is cancelled before the family-specific wreck sequence begins.
- Disguise transitions are world-space and temporary. The persistent state is the real player animation variant plus an optional matching HCO faction insignia; no separate menu, cursor or permanent status dashboard is introduced.
- Weapon choice, drawn/holstered state and reload are identity-neutral. Sound-only incidents mobilize a position search; player-specific pursuit requires observer-local evidence or completed communication. Native short-range detection may raise suspicion but cannot bypass that identity boundary.
- Social-stealth values and the exact native/live boundary are centralized in `SPECIFICATION_TRACEABILITY.md`.

## Automated release gate

All of the following must pass from the repository source:

- Lua syntax and payload validation: `HCO_VERIFY_PASS`.
- Degraded boot isolation: `HCO_BOOT_FAILURE_ISOLATION_PASS`.
- Contract, persistence, payout, rollback, social-stealth and difficulty runtime: `HCO_RUNTIME_SMOKE_PASS`.
- Drone sensing, physical hitbox, combat, evidence and crash orchestration: `HCO_DRONE_SMOKE_PASS`.
- Seven-model selection, weapon and flight behavior: `HCO_DRONE_ROSTER_SMOKE_PASS`.
- Native airframe presentation: `HCO_AIRFRAME_SMOKE_PASS`.
- Archetype visual identity and completion feedback suites.
- Portable repository test batch: `HCO_TEST_SUITE_PASS suites=7`.
- Exact source/archive/local-install relative-file and SHA-256 parity.

Run the repository-owned archive gate with `./scripts/release-check.ps1`. It fails on version drift, missing/extra package entries or any source/archive hash mismatch.

## Live `1.0` promotion matrix

Run with the Cheat Trainer reset unless compatibility itself is being tested.

1. Fresh mission and checkpoint reload on at least three structurally different maps.
2. One-, two- and three-contract activation where actor population allows it.
3. At least one Easy/Normal and one Hard/True mission; confirm visibly different pressure without changing the five-bodyguard core.
4. Routine patrol, loud-fire escalation, direct HCO-guard contact, body evidence and protection-casualty deployment paths.
5. Complete the fourteen-step RC37 social-stealth matrix: real body selector, three tiers, visual transitions, arbitrary armed cover, calm point-blank pass without forced combat, unobserved-shot isolation, direct-witness recognition, keycard/keychain doors, behavior exposure, lingering/evidence, identity checks, local/global body compromise, drone source scan and clean/compromised reload.
6. Scout plus every Light/Heavy Pistol, SMG and Laser row: silhouette, scale, heading, sound, attack cue, damage and cooldown.
7. Player LOS loss, zero roofed/indoor spawns, wall/door/window steering, world-edge containment, wing separation, idle recovery and at least 30 seconds of aggressive search.
8. EMP/disruption, Light one-hit destruction, Heavy two/three-hit destruction, outer-rotor hits, crash landing, wreck cleanup and crash-site response.
9. Target routine, shelter, reselection, evacuation and resolution; exactly-one payout after reload.
10. No HCO traceback, stuck update, duplicate local/Workshop copy, broken vanilla objective, blocked player input or lingering audio after returning to menu.

Any failure keeps the build at RC status. Automated proof is necessary but cannot establish live renderer, map geometry, native AI or mod-combination behavior on its own.
