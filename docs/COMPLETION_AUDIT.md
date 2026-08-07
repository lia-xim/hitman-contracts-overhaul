# Completion Audit — 0.14.6-rc40

**Audit date:** 2026-08-07
**Goal status:** production-candidate code complete for the current feature surface; final live acceptance is not complete
**Authority inspected:** RC40 source, `SPECIFICATION.md`, `SPECIFICATION_TRACEABILITY.md`, current smoke harnesses, installed `1.4.12HF3` interaction/actor/state/vision/weapon/off-limits/follower/camera/projectile/damage/outline/physics/path-grid/roof interfaces and user-supplied live screenshots/errors

## Evidence classification

| Area | Automated | Observed in game | Verdict |
| --- | --- | --- | --- |
| Clean bootstrap | Pass | Main-menu boot passed | Live pass |
| Native optional contract | Pass | Objective and target contract appeared | Live pass |
| Readable HUD feedback | Pass | Start overflow was found and corrected; completion banner observed | Live pass with ongoing polish |
| Safe campaign payout | Pass | Completion and reward observed after `studio` crash fix | Live pass |
| Target/protection presence | Pass | Target and guards observed | Partial live pass; behavior/difficulty tuning remains |
| Multi-contract isolation | Pass | Not yet proven across a full live mission | Live test required |
| Disguise/social stealth | RC39 native interaction, three tiers, weapon-neutral distance cover, FOV/raycast-gated close scrutiny, hard point-blank exposure, local radio propagation and persistence pass | User reports the RC39 close-risk behavior now works very well; full matrix remains incomplete | Partial live pass |
| Save/reload semantics | Pass | Individual mission behavior observed, full matrix incomplete | Live test required |
| Drone deployment/searchlight | RC40 committed patrol, invalid-sector fallback, 360-degree scan and shared map alarm pass | RC39 live pass exposed some permanently hovering/inert drones during combat | RC40 correction requires live pass |
| Native drone body | Seven-row atlas pass | Earlier native body visible in screenshot | RC22 row/scale/orientation pass pending |
| Drone detection relay | Strict-raycast plus RC40 all-contract network propagation pass | Some RC39 wings remained slot-local/inert while other actors fought | RC40 red-network search and local-fire authority require live proof |
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
3. Complete the remaining RC39 live matrix for direct witnesses, body evidence, radio compromise and reload; the user has accepted the core close-inspection/point-blank response.
4. Live-test the implemented semantic drone perception for calm/risky identities, bodies and source-uniform compromise.
5. Live-approve RC40's committed patrol travel, outdoor fallback, stationary 360-degree scan, all-wing alarm propagation, retained roof-map placement, unaided complete-silhouette hits and animated inert-wreck handoff; meaningful operator/radio dependency remains a future expansion.
6. Treat thermal surveillance and additional systemic contract types as explicit post-1.0 expansions unless promoted into the release scope.
7. Live-test and tune the implemented Pistol/SMG/Laser attacks. Every attack must remain telegraphed and counterable.
8. Complete the live map, reload and compatibility matrix; localization/audio callouts remain post-candidate content work.

## RC40 acceptance

RC40 is approved for local production-candidate testing, not yet as final `1.0`. The user has accepted RC39's close-recognition behavior, then exposed a separate live drone defect: some intact airframes could hover without patrolling, detecting or joining the wider alarm. RC40 commits non-tracking destinations until arrival, exhausts valid outdoor candidates, keeps boxed-in sensors rotating, shares confirmed contact across every active HCO context and retains per-drone LOS authority for fire. The next pass must prove sustained motion and red network escalation without wall fire.
