# Completion Audit — 0.13.0-rc29

**Audit date:** 2026-08-06  
**Goal status:** production-candidate code complete for the current feature surface; final live acceptance is not complete
**Authority inspected:** RC29 source, `SPECIFICATION.md`, current smoke harnesses, decompiled `1.4.12HF3` follower/camera/projectile/damage/outline/physics/path-grid interfaces and user-supplied live screenshots/errors

## Evidence classification

| Area | Automated | Observed in game | Verdict |
| --- | --- | --- | --- |
| Clean bootstrap | Pass | Main-menu boot passed | Live pass |
| Native optional contract | Pass | Objective and target contract appeared | Live pass |
| Readable HUD feedback | Pass | Start overflow was found and corrected; completion banner observed | Live pass with ongoing polish |
| Safe campaign payout | Pass | Completion and reward observed after `studio` crash fix | Live pass |
| Target/protection presence | Pass | Target and guards observed | Partial live pass; behavior/difficulty tuning remains |
| Multi-contract isolation | Pass | Not yet proven across a full live mission | Live test required |
| Disguise/social stealth | Pass | Not yet systematically tested | Live test required |
| Save/reload semantics | Pass | Individual mission behavior observed, full matrix incomplete | Live test required |
| Drone deployment/searchlight | Pass | Searchlight and movement observed | Live pass |
| Native drone body | Seven-row atlas pass | Earlier native body visible in screenshot | RC22 row/scale/orientation pass pending |
| Drone detection relay | Pass | Prior cone did not consistently prove contact | Live test required |
| Drone tracking/gimbal | RC22 pass in harness | Earlier cone swept away from player | Live fix confirmation required |
| Armed drone attacks | Native bullet and charged-laser harness pass | Not yet observed | Live test required |
| Drone EMP/destruction | RC29 retains RC28 edge-hit, fixture-repair and crash lifecycle with spatial polish | Destruction works; last reported Heavy miss/crash-polish issues predate RC28 | RC29 live pass required |
| Difficulty/fleet balance | Native preset/custom assertions and roster/global caps pass | Not yet compared live | Live comparison required |
| Drone semantic sensing | Disguise-risk, body-evidence and source-compromise assertions pass | Not yet observed | Live test required |
| Vanilla mission/coexistence | No mock can prove fully | Normal shooting issue was mission-script behavior, not HCO | Broader live pass required |

## Requirement verdict

The core optional-contract product exists and works far enough to be played. HCO is not specification-complete yet. The remaining substantive product work is:

1. Validate and tune the mobile target's retreat/escape behavior and protection-detail combat pressure on several real maps.
2. Guarantee stronger mission-appropriate weapons and reliable active response for the protection tiers.
3. Complete live acceptance for disguise, credentials, identity checks, body evidence and radio compromise.
4. Live-test the implemented semantic drone perception for calm/risky identities, bodies and source-uniform compromise.
5. Live-approve the implemented floor-grid/footprint obstruction recovery; meaningful operator/radio dependency remains a future expansion.
6. Treat thermal surveillance and additional systemic contract types as explicit post-1.0 expansions unless promoted into the release scope.
7. Live-test and tune the implemented Pistol/SMG/Laser attacks. Every attack must remain telegraphed and counterable.
8. Complete the live map, reload and compatibility matrix; localization/audio callouts remain post-candidate content work.

## RC29 acceptance

RC29 is approved as a production candidate for local/Workshop testing, not yet as final `1.0`. Automated proof now covers native-difficulty tuning, bounded global/composition fleets, semantic identity/body sensing, family-specific effects and the complete RC28 hit/crash lifecycle. The next pass must compare pressure on at least two difficulties, prove calm/risky disguise timing and source-body compromise, then exercise every drone family, multi-contract cap, response-unit combat/search and real-map boundaries without traceback. The exact promotion matrix is maintained in `PRODUCTION_READINESS.md`.
