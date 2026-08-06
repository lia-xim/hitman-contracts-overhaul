# Hitman Contracts Overhaul — Implementation Status

**Current version:** `0.11.0-rc22`
**Status date:** 2026-08-06  
**Target game:** Intravenous 2 `1.4.12HF3`  
**Authority:** `SPECIFICATION.md` remains the product and technical source of truth.

## Verified live so far

- HCO reaches the main menu and creates native optional contracts in compatible missions.
- Multi-line start/finish presentation was reduced to readable native-sized cards.
- Contract settlement no longer calls the hideout-only `studio` reward path; the completion banner and campaign payout have been observed in game.
- Protection actors, target movement and drone searchlights have appeared in a real mission.
- RC20 proved the custom drone body can render through a registered decor-quadtree entity and native sprite batch. The first visible pass was oversized and rotated incorrectly; RC21 contains the correction but is not yet live-approved.

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
| Drone disruption and destruction | Implemented across all seven models | Live-test EMP lockout, light/heavy armor, sound/light cleanup and crash-site response |
| Drone perception semantics | Partial | Add exposed-weapon, body and unauthorized-disguise classification instead of player geometry alone |
| Drone navigation | Partial | Replace straight derived-sector travel with validated aerial corridors and obstruction recovery |
| Drone command infrastructure | Missing | Add meaningful drone operators, radio dependency and sabotage/power counterplay |
| Thermal surveillance | Missing | Build readable thermal-camera subtype with LOS, disruption and power/operator counters |
| Armed drone variants | RC22 implemented: Pistol/SMG native bullets and charged Laser | Live-test damage, friendly obstruction, telegraphs, cooldowns, God Mode compatibility and counterplay |
| Custom archetype identity | Partial | Native full animation variants plus original insignia exist; complete custom character atlases are deliberately deferred until animation coverage is safe |
| Contract variety | Partial | Data theft, accidents, special weapon conditions, rescue/extraction and other systemic contract types |
| Localization/audio callouts | Partial | English runtime text exists; translated strings and an authored localized radio-callout pack remain |

## RC22 drone behavior

- Airframe footprint reduced to roughly 27 world pixels and the generated art rotated by -90 degrees to match the native sensor/flight heading.
- Hover bob, offset shadow, four-frame rotor animation, rotor pulse rings, state-colored sensor pulse and a short pixel wake make flight readable without adding a detached HUD layer.
- All doctrines remain bullet-breakable; doctrine armor controls required hits.
- Native electronic disruption now also suspends HCO acquisition and relay logic.
- Destruction removes the searchlight, airframe and loop sound, records a local crash, escalates the hunt and dispatches up to three non-close-protection guards to investigate.

The Scout deliberately does not shoot. Six armed variants join escalated wings: light/heavy Pistol, SMG and Laser. Ballistic models use native bullets; laser models display an uninterrupted charge cue. No model attacks without confirmed line of sight, range, gimbal alignment and cooldown readiness.

## Immediate acceptance gate

1. Completely restart the game and confirm `0.11.0-rc22` loads without traceback.
2. Observe multiple deployments and identify Scout, light and heavy silhouettes; heavy variants must be larger but remain actor-scaled.
3. Stand visibly inside the cone: the cone should enter contact state and response guards should move to the reported position.
4. Break line of sight behind solid geometry: the drone must not keep perfect live tracking through the wall.
5. Disrupt a drone: its body should flicker and it must stop acquiring/relaying until disruption ends.
6. Shoot down a one-hit doctrine drone and a Commander armored drone: light, body and rotor audio must stop, while guards investigate the crash area.
7. Trigger an armed wing: verify a Pistol/SMG native projectile and a Laser that holds its aim line for 0.9/1.4 seconds before firing.
8. Circle a tracking drone: the gimbal should follow first, then the body should yaw; the drone must hold a standoff slot instead of flying through or endlessly orbiting the player.
9. Confirm normal weapon fire, vanilla objectives, mission completion, checkpoint reload and return to menu still work.

## Release boundary

HCO is still an active release candidate. The contract core and original native render path are functional, but RC22's seven-model visuals, tracking, attacks and adapted sound set need the live pass above. The larger missing specification items remain explicit.
