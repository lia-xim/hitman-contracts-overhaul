# Completion Audit — 0.14.0-rc34

**Audit date:** 2026-08-07
**Goal status:** production-candidate code complete for the current feature surface; final live acceptance is not complete
**Authority inspected:** RC34 source, `SPECIFICATION.md`, `SPECIFICATION_TRACEABILITY.md`, current smoke harnesses, decompiled `1.4.12HF3` interaction/actor/off-limits/follower/camera/projectile/damage/outline/physics/path-grid/roof interfaces and user-supplied live screenshots/errors

## Evidence classification

| Area | Automated | Observed in game | Verdict |
| --- | --- | --- | --- |
| Clean bootstrap | Pass | Main-menu boot passed | Live pass |
| Native optional contract | Pass | Objective and target contract appeared | Live pass |
| Readable HUD feedback | Pass | Start overflow was found and corrected; completion banner observed | Live pass with ongoing polish |
| Safe campaign payout | Pass | Completion and reward observed after `studio` crash fix | Live pass |
| Target/protection presence | Pass | Target and guards observed | Partial live pass; behavior/difficulty tuning remains |
| Multi-contract isolation | Pass | Not yet proven across a full live mission | Live test required |
| Disguise/social stealth | RC34 native interaction, three tiers, visuals, credentials, recognition, radio, compromise and persistence pass | Earlier build had no reachable identity action | RC34 real body-menu/appearance/behavior gate required |
| Save/reload semantics | Pass | Individual mission behavior observed, full matrix incomplete | Live test required |
| Drone deployment/searchlight | Pass | Searchlight and movement observed | Live pass |
| Native drone body | Seven-row atlas pass | Earlier native body visible in screenshot | RC22 row/scale/orientation pass pending |
| Drone detection relay | Strict-raycast pass | RC29 could infer contact when geometry lookup was unavailable | RC30 wall/roof live test required |
| Drone tracking/gimbal | RC22 pass in harness | Earlier cone swept away from player | Live fix confirmation required |
| Armed drone attacks | Native bullet and charged-laser harness pass | Not yet observed | Live test required |
| Drone EMP/destruction | RC34 retains RC33 terminal cleanup, durable wreck batch, projectile sweep and mission-ticked animation | Latest live pass proved the previous build's wrecks remained visible but froze on their first damage frame | RC34 regression pass required |
| Difficulty/fleet balance | Native preset/custom assertions and roster/global caps pass | Not yet compared live | Live comparison required |
| Drone semantic sensing | Disguise-risk, body-evidence and source-compromise assertions pass | Not yet observed | Live test required |
| Vanilla mission/coexistence | No mock can prove fully | Normal shooting issue was mission-script behavior, not HCO | Broader live pass required |

## Requirement verdict

The core optional-contract product exists and works far enough to be played. HCO is not specification-complete yet. The remaining substantive product work is:

1. Validate and tune the mobile target's retreat/escape behavior and protection-detail combat pressure on several real maps.
2. Guarantee stronger mission-appropriate weapons and reliable active response for the protection tiers.
3. Complete the RC34 fourteen-step live acceptance for the now-rebuilt disguise, credentials, identity checks, visual transitions, body evidence and radio compromise.
4. Live-test the implemented semantic drone perception for calm/risky identities, bodies and source-uniform compromise.
5. Live-approve the retained native roof-map placement, outdoor footprint recovery, unaided complete-silhouette hits and the complete animated inert-wreck handoff; meaningful operator/radio dependency remains a future expansion.
6. Treat thermal surveillance and additional systemic contract types as explicit post-1.0 expansions unless promoted into the release scope.
7. Live-test and tune the implemented Pistol/SMG/Laser attacks. Every attack must remain telegraphed and counterable.
8. Complete the live map, reload and compatibility matrix; localization/audio callouts remain post-candidate content work.

## RC34 acceptance

RC34 is approved for local production-candidate testing, not yet as final `1.0`. Automated proof now traverses the real Goon option list instead of calling a hidden Lua action directly, captures identity before native inventory stripping, switches/persists all three tiers and renders the four world-space identity transitions. The next pass must prove that these behaviors are reachable and readable in a real mission while also confirming RC33's drone wreck progression. The exact promotion matrix is maintained in `PRODUCTION_READINESS.md`.
