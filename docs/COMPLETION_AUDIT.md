# Completion Audit — 0.14.12-rc46

**Audit date:** 2026-08-07
**Goal status:** production-candidate code complete for the current feature surface; final live acceptance is not complete
**Authority inspected:** RC46 source, `SPECIFICATION.md`, `SPECIFICATION_TRACEABILITY.md`, current smoke harnesses, installed `1.4.12HF3` interaction/actor/state/vision/weapon/off-limits/follower/camera/projectile/damage/outline/physics/path-grid/roof interfaces and user-supplied live screenshots/errors

## Evidence classification

| Area | Automated | Observed in game | Verdict |
| --- | --- | --- | --- |
| Clean bootstrap | Pass | Main-menu boot passed | Live pass |
| Native optional contract | Pass | Objective and target contract appeared | Live pass |
| Readable HUD feedback | Pass | Start overflow was found and corrected; completion banner observed | Live pass with ongoing polish |
| Safe campaign payout | Pass | Completion and reward observed after `studio` crash fix | Live pass |
| Target/protection presence | RC43 native patrol callback/path and exact follower-chain regressions pass | Target and guards observed; stationary target/detail reported on RC42 | RC43 correction requires live pass |
| Multi-contract isolation | Pass | Not yet proven across a full live mission | Live test required |
| Disguise/social stealth | RC46 eligible-body object priority, first-visible takeover, independent render-cache recovery, stable native IDs, replaced-hook/runtime rebind, explicit restore, nearby-body marker, persistent shimmer, three tiers, weapon-neutral distance cover, close scrutiny, point-blank exposure, radio and persistence pass | Latest screenshot showed the dropped HS2000 selected as object 1 while the body remained inactive object 2 | RC46 body-first correction requires live pass |
| Save/reload semantics | Pass | Individual mission behavior observed, full matrix incomplete | Live test required |
| Drone deployment/searchlight | RC41 committed patrol, invalid-sector fallback, bounded inert barrier hop, 360-degree scan and shared map alarm pass | Live pass exposed stalls at separated exterior areas | RC41 correction requires live pass |
| Native drone body | Seven-row atlas pass | Earlier native body visible in screenshot | RC22 row/scale/orientation pass pending |
| Drone detection relay | Strict-raycast plus RC41 all-contract propagation and transition lockout pass | One-way detection/fire during inaccessible transitions would be unfair | RC41 red-network search, barrier lockout and local-fire authority require live proof |
| Drone tracking/gimbal | RC22 pass in harness | Earlier cone swept away from player | Live fix confirmation required |
| Armed drone attacks | Native bullet/charged-laser plus RC43 stale-location reacquisition and post-casualty attribution continuity pass | User observed initial fire followed by silent cessation on RC42 | RC43 correction requires live pass |
| Drone EMP/destruction | RC34 retains RC33 terminal cleanup, durable wreck batch, projectile sweep and mission-ticked animation | Latest live pass proved the previous build's wrecks remained visible but froze on their first damage frame | RC34 regression pass required |
| Difficulty/fleet balance | Native preset/custom assertions and roster/global caps pass | Not yet compared live | Live comparison required |
| Drone semantic sensing | Disguise-risk, body-evidence and source-compromise assertions pass | Not yet observed | Live test required |
| Vanilla mission/coexistence | No mock can prove fully | Normal shooting issue was mission-script behavior, not HCO | Broader live pass required |

## Requirement verdict

The core optional-contract product exists and works far enough to be played. HCO is not specification-complete yet. The remaining substantive product work is:

1. Validate and tune the mobile target's retreat/escape behavior and protection-detail combat pressure on several real maps.
2. Guarantee stronger mission-appropriate weapons and reliable active response for the protection tiers.
3. Complete the RC46 live matrix for body-first selection, restart-safe action visibility/restore, eligible-body marker, persistent identity shimmer, drone disguise distance bands and fire continuity, direct witnesses, body evidence, radio compromise and reload; the user has accepted the core close-inspection/point-blank response.
4. Live-test the implemented semantic drone perception for calm/risky identities, bodies and source-uniform compromise.
5. Live-approve RC41's committed patrol travel, bounded disarmed wall/gate hop, rejected roof crossing, outdoor fallback, stationary 360-degree scan, all-wing alarm propagation, unaided complete-silhouette hits and animated inert-wreck handoff; meaningful operator/radio dependency remains a future expansion.
6. Treat thermal surveillance and additional systemic contract types as explicit post-1.0 expansions unless promoted into the release scope.
7. Live-test and tune the implemented Pistol/SMG/Laser attacks. Every attack must remain telegraphed and counterable.
8. Complete the live map, reload and compatibility matrix; localization/audio callouts remain post-candidate content work.

## RC46 acceptance

RC46 is approved for local production-candidate testing, not yet as final `1.0`. The latest screenshot proves the native UI was actively showing object `1. HS2000`; object `2` was the unconscious body, whose options are hidden until the object itself becomes active. RC46 temporarily raises only eligible unused uniforms above overlapping dropped equipment, repairs incomplete render caches with the active player context and periodically restores critical methods replaced by later-loaded mods. The next pass must prove a fresh body becomes object 1 and immediately exposes takeover after a complete restart.
