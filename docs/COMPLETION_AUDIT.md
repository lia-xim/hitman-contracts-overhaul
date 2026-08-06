# Completion Audit — 0.10.0-rc21

**Audit date:** 2026-08-06  
**Goal status:** active; the native drone-render breakthrough is proven, but the full specification and final live acceptance are not complete  
**Authority inspected:** RC21 source, `SPECIFICATION.md`, current smoke harnesses, decompiled `1.4.12HF3` render interfaces and user-supplied live screenshots/errors

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
| Native drone body | Pass | RC20 body visible in screenshot | Live pass for render path; RC21 scale/orientation/effects pending |
| Drone detection relay | Pass | Prior cone did not consistently prove contact | Live test required |
| Drone EMP/destruction | RC21 pass in harness | Not yet observed after RC21 | Live test required |
| Vanilla mission/coexistence | No mock can prove fully | Normal shooting issue was mission-script behavior, not HCO | Broader live pass required |

## Requirement verdict

The core optional-contract product exists and works far enough to be played. HCO is not specification-complete yet. The remaining substantive product work is:

1. Validate and tune the mobile target's retreat/escape behavior and protection-detail combat pressure on several real maps.
2. Guarantee stronger mission-appropriate weapons and reliable active response for the protection tiers.
3. Complete live acceptance for disguise, credentials, identity checks, body evidence and radio compromise.
4. Upgrade drone perception from geometric player detection to semantic detection of bodies, exposed weapons and unauthorized identities.
5. Add validated aerial corridors/obstruction recovery, a meaningful operator/radio dependency and sabotage counterplay.
6. Build thermal surveillance and the remaining systemic contract types.
7. Prototype an armed Hunter/Interceptor only after the game's native projectile API is verified. Its attack must be telegraphed and counterable.
8. Complete map profiles, localization, audio callouts and the full reload/compatibility matrix.

## RC21 acceptance

RC21 is approved for local testing, not final Workshop release. The next live pass must prove corrected drone size and heading, flight effects, line-of-sight acquisition, EMP suppression, bullet destruction, doctrine armor and crash-site response without a traceback. Only then can this drone slice move from partial to live-complete.
