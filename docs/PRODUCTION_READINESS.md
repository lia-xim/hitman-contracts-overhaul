# Production Readiness Gate

**Candidate:** `0.14.11-rc45`
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
- Patrol/search destinations remain committed until arrival or an explicit tactical/idle transition. Invalid/current-position authored sectors are exhausted before deterministic outdoor fallbacks; if the map offers no route, the sensor performs a continuous 360-degree scan instead of becoming inert.
- A stalled drone may cross only a narrow obstructed span between two verified outdoor footprints. During the eased transition the inherited camera update, HCO sensing, evidence scan and every weapon are disabled; wide roofed structures and void have no valid landing and remain impassable.
- Confirmed drone contact is map-network evidence: all active HCO wings enter a visible red aggressive search and all contract response teams receive the reported position. Weapons remain local and fail closed behind geometry.
- Disguise transitions remain world-space and the active identity adds a restrained persistent cyan/red player shimmer. A small stitch marker identifies unused nearby uniforms. Takeover is the first visible eligible body action and restoration the second HCO action, but both are appended with unused bit IDs so native/third-party class action identities never change. No separate menu or cursor is introduced.
- Native patrol activation owns the target destination/path. HCO never clears that path after `setActivePatrolRoute`; a target stationary in routine for nine seconds advances through the same authored route. All five close guards form one verified follower chain instead of competing for the target's single follower slot.
- A nearby unsuppressed shot creates location-only caution; confirmed protection incidents escalate flight and can invalidate an occupied shelter without granting magical player identity.
- An intact armed drone keeps a stable valid native attribution proxy for its lifetime and may reacquire an already confirmed current appearance through fresh unobstructed LOS. Death of the principal/guards or expiry of an old location report may not silently disable its weapon.
- Native takeover/restore actions are revalidated during mission runtime. A replaced Goon class/list is rebound, stale per-body action bitmasks/options are rebuilt once per interaction generation, and the exact `getInteractOptions` result is reconciled whenever the player opens a cached body selector.
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
5. Complete the RC43 social-stealth matrix: takeover first in the real body selector both before and after mission restart, three tiers, persistent active shimmer, explicit original-identity restore, arbitrary armed distance cover, survivable brief close pass, sustained close exposure, immediate point-blank hostile handoff, unobserved-shot isolation, direct-witness recognition, credentials, behavior exposure, local/global radio compromise, drone source scan and reload.
6. Scout plus every Light/Heavy Pistol, SMG and Laser row: silhouette, scale, heading, sound, attack cue, damage and cooldown.
7. Player LOS loss, zero roofed/indoor spawns, ordinary wall steering, one successful narrow exterior hop, one rejected wide/roofed crossing, no sensing/fire during hop, world-edge containment, wing separation, committed patrol travel, invalid-sector fallback, rotating boxed-in scan and at least 30 seconds of aggressive search.
8. On a multi-contract map, let one Scout or armed drone confirm the player: every wing must turn red and leave stale patrol routes, every response detail must receive the reported position, and only drones with their own unobstructed aim may fire.
9. EMP/disruption, Light one-hit destruction, Heavy two/three-hit destruction, outer-rotor hits, crash landing, wreck cleanup and crash-site response.
10. Target and all five bodyguards continuously traverse the authored routine beyond 15 seconds; then verify first nearby loud-shot relocation without identity leak, shelter reselection after a local protection incident, evacuation and resolution, plus exactly-one payout after reload.
11. Confirm an armed drone, break LOS until the last position is stale, re-enter a clear firing lane and then kill its nearby response guard/principal attribution candidates. Every intact armed drone must reacquire and continue firing.
12. No HCO traceback, stuck update, duplicate local/Workshop copy, broken vanilla objective, blocked player input or lingering audio after returning to menu.

Any failure keeps the build at RC status. Automated proof is necessary but cannot establish live renderer, map geometry, native AI or mod-combination behavior on its own.
