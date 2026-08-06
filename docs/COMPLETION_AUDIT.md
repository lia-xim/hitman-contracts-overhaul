# Completion Audit — 0.12.3-rc27

**Audit date:** 2026-08-06  
**Goal status:** active; the native drone-render breakthrough is proven, but the full specification and final live acceptance are not complete  
**Authority inspected:** RC27 source, `SPECIFICATION.md`, current smoke harnesses, decompiled `1.4.12HF3` follower/camera/projectile/damage/outline/physics/path-grid interfaces and user-supplied live screenshots/errors

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
| Drone EMP/destruction | RC27 armor/impact pass in harness | Small drone destruction confirmed after RC26; heavy response rejected | Heavy live pass required |
| Vanilla mission/coexistence | No mock can prove fully | Normal shooting issue was mission-script behavior, not HCO | Broader live pass required |

## Requirement verdict

The core optional-contract product exists and works far enough to be played. HCO is not specification-complete yet. The remaining substantive product work is:

1. Validate and tune the mobile target's retreat/escape behavior and protection-detail combat pressure on several real maps.
2. Guarantee stronger mission-appropriate weapons and reliable active response for the protection tiers.
3. Complete live acceptance for disguise, credentials, identity checks, body evidence and radio compromise.
4. Upgrade drone perception from geometric player detection to semantic detection of bodies, exposed weapons and unauthorized identities.
5. Add validated aerial corridors/obstruction recovery, a meaningful operator/radio dependency and sabotage counterplay.
6. Build thermal surveillance and the remaining systemic contract types.
7. Live-test and tune the implemented Pistol/SMG/Laser attacks after native projectile and damage API verification. Every attack must remain telegraphed and counterable.
8. Complete map profiles, localization, audio callouts and the full reload/compatibility matrix.

## RC27 acceptance

RC27 is approved for local testing, not final Workshop release. Small-drone destruction is now live-proven. The next pass must prove that every heavy model gives the expanding spark/tint/pip response and falls after two or three ordinary hits, with high-caliber rifles removing multiple points. It must also prove the former `getWatchBack` crash cannot recur when response units enter combat/search, then validate search-ring exploration, flank relocations, idle recovery and real-map building boundaries. The remaining weapon/audio/EMP/counterplay behaviors must run without a traceback.
