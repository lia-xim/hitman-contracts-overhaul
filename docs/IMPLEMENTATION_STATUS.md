# Hitman Contracts Overhaul — Implementation Status

**Current version:** `0.12.4-rc28`
**Status date:** 2026-08-06  
**Target game:** Intravenous 2 `1.4.12HF3`  
**Authority:** `SPECIFICATION.md` remains the product and technical source of truth.

## Verified live so far

- HCO reaches the main menu and creates native optional contracts in compatible missions.
- Multi-line start/finish presentation was reduced to readable native-sized cards.
- Contract settlement no longer calls the hideout-only `studio` reward path; the completion banner and campaign payout have been observed in game.
- Protection actors, target movement and drone searchlights have appeared in a real mission.
- RC20 proved the custom drone body can render through a registered decor-quadtree entity and native sprite batch. The first visible pass was oversized and rotated incorrectly; RC21 contains the correction but is not yet live-approved.
- RC26 live evidence confirms small drones can now be shot down through the synchronized/fallback projectile path. RC27 corrected heavy balance/readability. RC28 corrects intermittent Heavy rotor/corner misses and adds the requested visible crash/landing aftermath; live approval is pending.

Automated harnesses support these systems, but do not replace the remaining real-mission acceptance tests.

## Specification coverage audit

| Product area | Current state | What remains |
| --- | --- | --- |
| Optional contracts | Implemented and seen live | Broader per-map compatibility and full one-to-three-contract live matrix |
| Native objective, clue and target marker | Implemented and seen live | Imperfect-information variants beyond the current dead-drop reveal |
| Mobile target | Implemented | Prove routine, shelter, breached-cover reselection and physical escape across several maps |
| Heavy protection detail | Implemented with 5/8/11/15 allocation | Guarantee mission-appropriate strong weapon upgrades and verify every response tier fights effectively |
| Hunt and last-known-position search | Implemented | Tune pursuit pressure, containment and stand-down from real gameplay evidence |
| Disguise and social stealth | Implemented in code | Full live pass for appearance, weapon plausibility, same-unit recognition, identity checks and compromised uniforms |
| Credentials and radio propagation | Implemented in code | Full live pass for access, interruptible radio and checkpoint restoration |
| Multi-contract persistence and payout | Implemented | Live active/terminal reload matrix and multi-target exactly-once payout |
| Drone presence and patrol | Seven-model RC22 roster implemented; previous native body seen live | Live-approve every new atlas row, scale, heading, rotor profile and varied deployment |
| Drone detection and response relay | Stable slot pursuit and independent gimbal implemented | Prove cone lock, LOS loss and response convergence without wall tracking |
| Drone disruption and destruction | Implemented across all seven models; RC28 crash lifecycle and wreck | Live-test EMP lockout, complete-silhouette hits, light/heavy tumble, sound/light cleanup and crash-site response |
| Drone perception semantics | Partial | Add exposed-weapon, body and unauthorized-disguise classification instead of player geometry alone |
| Drone navigation | Partial | Replace straight derived-sector travel with validated aerial corridors and obstruction recovery |
| Drone command infrastructure | Missing | Add meaningful drone operators, radio dependency and sabotage/power counterplay |
| Thermal surveillance | Missing | Build readable thermal-camera subtype with LOS, disruption and power/operator counters |
| Armed drone variants | RC22 implemented: Pistol/SMG native bullets and charged Laser | Live-test damage, friendly obstruction, telegraphs, cooldowns, God Mode compatibility and counterplay |
| Custom archetype identity | Partial | Native full animation variants plus original insignia exist; complete custom character atlases are deliberately deferred until animation coverage is safe |
| Contract variety | Partial | Data theft, accidents, special weapon conditions, rescue/extraction and other systemic contract types |
| Localization/audio callouts | Partial | English runtime text exists; translated strings and an authored localized radio-callout pack remain |

## RC22 roster / RC23–RC28 live corrections

- Airframe footprint reduced to roughly 27 world pixels and the generated art rotated by -90 degrees to match the native sensor/flight heading.
- Hover bob, offset shadow, four-frame rotor animation, rotor pulse rings, state-colored sensor pulse and a short pixel wake make flight readable without adding a detached HUD layer.
- Every Scout/light model is a strict one-hit target. Heavy Pistol takes two ordinary hits and Heavy SMG/Laser take at most three; doctrine scaling is hard-capped at three. High-damage/high-penetration rifles remove multiple points.
- Native electronic disruption now also suspends HCO acquisition and relay logic.
- RC28 uses 44/48/54-unit self-repairing Scout/light/heavy fixtures plus an atlas-derived fallback radius, covering the complete rotated silhouette instead of only its hull.
- Destruction stops the searchlight and loop sound, then tumbles the airframe along its last vector with smoke, sparks and debris into a persistent dark wreck. The landing records local evidence, escalates the hunt and dispatches up to three non-close-protection guards to investigate.

The Scout deliberately does not shoot. Six armed variants join escalated wings: light/heavy Pistol, SMG and Laser. Ballistic models use native bullets; laser models display an uninterrupted charge cue. No model attacks without confirmed line of sight, range, gimbal alignment and cooldown readiness.

## Immediate acceptance gate

1. Completely restart the game and confirm `0.12.4-rc28` loads without traceback.
2. Observe multiple deployments and identify Scout, light and heavy silhouettes; heavy variants must be larger but remain actor-scaled.
3. Stand visibly inside the cone: the cone should enter contact state and response guards should move to the reported position.
4. Break line of sight behind solid geometry: the drone must not keep perfect live tracking through the wall.
5. Disrupt a drone: its body should flicker and it must stop acquiring/relaying until disruption ends.
6. Shoot the visible center and deliberately the outer rotors/corners of moving light and heavy drones. Every visible region must register. The light model must fall on the first registered hit. Heavy hits must tint the complete airframe, emit an expanding spark ring and briefly show two/three pips; every heavy must fall on hit two or three, including against Model-700-class fire.
7. Watch one light and one heavy destruction: the airframe must tumble for roughly 0.78/0.95 seconds, trail smoke/sparks, produce a landing ring/debris burst and remain as a dark wreck. Response actors should investigate that landing point.
8. Trigger an armed wing: verify a Pistol/SMG native projectile and a Laser that holds its aim line for 0.9/1.4 seconds before firing.
9. Circle a tracking drone: the gimbal should follow first, then the body should yaw; the drone must hold a standoff slot instead of flying through or endlessly orbiting the player.
10. Observe an aggressive wing for at least 20 seconds: no drone should remain unexpectedly still for more than roughly half a second, and blocked drones should choose a new heading.
11. Draw a drone toward a building exterior: it should steer around walls, closed doors and windows instead of crossing the boundary; low outdoor cover may be overflown.
12. Keep response units in combat/search long enough for follower instruction timers to advance; no `getWatchBack` traceback may occur.
13. Confirm normal weapon fire, vanilla objectives, mission completion, checkpoint reload and return to menu still work.

## Release boundary

HCO is still an active release candidate. The contract core and native render path are functional. RC28 retains the movement, follower and fragile-balance corrections while covering the entire rotated drone silhouette and adding a readable native-world crash lifecycle. Those live counterplay and presentation changes still need the pass above. The larger missing specification items remain explicit.
