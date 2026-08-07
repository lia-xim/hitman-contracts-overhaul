# Hitman Contracts Overhaul — Implementation Status

**Current version:** `0.14.2-rc36`
**Status date:** 2026-08-07
**Target game:** Intravenous 2 `1.4.12HF3`  
**Authority:** `SPECIFICATION.md` remains the product and technical source of truth.

## Verified live so far

- HCO reaches the main menu and creates native optional contracts in compatible missions.
- Multi-line start/finish presentation was reduced to readable native-sized cards.
- Contract settlement no longer calls the hideout-only `studio` reward path; the completion banner and campaign payout have been observed in game.
- Protection actors, target movement and drone searchlights have appeared in a real mission.
- RC20 proved the custom drone body can render through a registered decor-quadtree entity and native sprite batch. The first visible pass was oversized and rotated incorrectly; RC21 contains the correction but is not yet live-approved.
- RC26 live evidence confirms small drones can be shot down through the synchronized/fallback projectile path. RC27 corrected heavy balance/readability, RC28 added complete-silhouette targeting and the physical crash, and RC29 completed automated balance/semantic/presentation hardening. RC30 replaced pathable indoor placement with native roof-aware outdoor placement and fail-closed combat readiness. RC31 added family-specific wreck frames and terminal weapon/light cleanup. RC32 fixed disappearing wrecks and unaided Heavy-edge shots. The next live pass proved the persistent wreck stayed on damage frame one because its destroyed carrier no longer drove repeated decor draws; RC33 now advances the atlas and finite effects from the persistent mission update. Live confirmation of the full sequence remains pending.

Automated harnesses support these systems, but do not replace the remaining real-mission acceptance tests.

## Specification coverage audit

| Product area | Current state | What remains |
| --- | --- | --- |
| Optional contracts | Implemented and seen live | Broader per-map compatibility and full one-to-three-contract live matrix |
| Native objective, clue and target marker | Implemented and seen live | Imperfect-information variants beyond the current dead-drop reveal |
| Mobile target | Implemented | Prove routine, shelter, breached-cover reselection and physical escape across several maps |
| Heavy protection detail | Five close guards plus difficulty-scaled 5/10/15/20 archetype response demand, bounded by safe actors | Guarantee mission-appropriate strong weapon upgrades and verify every response tier fights effectively |
| Hunt and last-known-position search | Implemented | Tune pursuit pressure, containment and stand-down from real gameplay evidence |
| Disguise and social stealth | RC36 candidate path: RC34 native identity system plus weapon-neutral cover, observer-local hostility, position-only sound/casualty searches and native-sight-only body discovery | Full real-mission pass in `SPECIFICATION_TRACEABILITY.md` |
| Credentials and radio propagation | RC34 keycard/keychain capture before native drop, consistent off-limits queries, interruptible identity/body reports and reload restoration | Verify real mission doors, radio audio/range and checkpoint matrix |
| Multi-contract persistence and payout | Implemented | Live active/terminal reload matrix and multi-target exactly-once payout |
| Drone presence and patrol | Seven-model RC22 roster implemented; previous native body seen live | Live-approve every new atlas row, scale, heading, rotor profile and varied deployment |
| Drone detection and response relay | Stable slot pursuit, independent gimbal and strict native geometry authority implemented | Prove cone lock, LOS loss and response convergence without wall tracking |
| Drone disruption and destruction | Implemented across all seven models; RC33 mission-ticked wreck animation, durable native wreck batch, full first-shot sweep and terminal weapon/light cleanup | Live-test frame 1→2→3→4 progression, free fire without right-click, EMP lockout and crash-site response |
| Drone perception semantics | Implemented for observer-local behavior risk, compromised identity and body/source-uniform evidence; held weapons are neutral | Live-test routine versus aggressive identity timing, body concealment and source-uniform compromise |
| Drone navigation | Native roof-map outdoor footprints, floor-grid steering, search rings, flanks, separation and safety recovery implemented | Live-approve zero indoor spawns, exterior boundaries and long aggressive-search behavior |
| Drone command infrastructure | Missing | Add meaningful drone operators, radio dependency and sabotage/power counterplay |
| Thermal surveillance | Missing | Build readable thermal-camera subtype with LOS, disruption and power/operator counters |
| Armed drone variants | RC22 implemented: Pistol/SMG native bullets and charged Laser | Live-test damage, friendly obstruction, telegraphs, cooldowns, God Mode compatibility and counterplay |
| Custom archetype identity | Partial | Native full animation variants plus original insignia exist; complete custom character atlases are deliberately deferred until animation coverage is safe |
| Contract variety | Partial | Data theft, accidents, special weapon conditions, rescue/extraction and other systemic contract types |
| Localization/audio callouts | Partial | English runtime text exists; translated strings and an authored localized radio-callout pack remain |

## RC22 roster / RC23–RC36 live corrections

- Airframe footprint reduced to roughly 27 world pixels and the generated art rotated by -90 degrees to match the native sensor/flight heading.
- Hover bob, offset shadow, four-frame rotor animation, rotor pulse rings, state-colored sensor pulse and a short pixel wake make flight readable without adding a detached HUD layer.
- Every Scout/light model is a strict one-hit target. Heavy Pistol takes two ordinary hits and Heavy SMG/Laser take at most three; doctrine scaling is hard-capped at three. High-damage/high-penetration rifles remove multiple points.
- Native electronic disruption now also suspends HCO acquisition and relay logic.
- RC28 uses 44/48/54-unit self-repairing Scout/light/heavy fixtures plus an atlas-derived fallback radius, covering the complete rotated silhouette instead of only its hull.
- Destruction atomically cancels detection, aim, queued fire and rotor audio, then destroys the native light buffer. A dedicated four-stage damage atlas tumbles along the last vector with smoke, sparks and debris into an unmistakable persistent wreck. The landing records local evidence, escalates the hunt and dispatches up to three non-close-protection guards to investigate.
- RC29 adds native-difficulty pressure/payout tuning, an all-contract twelve-airframe ceiling, Heavy/Laser composition caps, type-colored effects, true Laser charge progress, damaged-Heavy smoke/wobble and spatially weighted crash audio.
- RC30 consumes the engine's finalized `roofObstructed` map, rejects roofed/locked destinations, requires a nine-sample clear outdoor footprint, and disables any carrier whose visible airframe or physical bullet target is unavailable. Player sensing and weapons now fail closed unless the native geometry trace completes.
- RC31 separates active and destroyed textures for every roster row, releases the intact batch slot on impact, and tears down the native searchlight atlas allocation so a stopped wreck cannot appear alive or continue a burst.
- RC32 gives wrecks an independent registered renderer batch instead of relying on direct drawing from a decor-quadtree callback. Its projectile fallback starts at `shootX/shootY` on first observation, covering the engine's pre-list bullet advance and making free-fire rotor hits equivalent to assisted aim hits.
- RC33 separates animation time from decor visibility: every contract tick advances its destroyed shells, writes the next wreck frame directly into the registered batch and reinserts the decor shell only during the bounded tumble/smoke window.
- RC34 closes the hidden-action gap in social stealth: native action enumeration/cache refresh makes the body option reachable, death-time capture preserves credentials/equipment, three visible identity tiers persist through reload and world-space transitions make acquisition/check/compromise readable.
- RC35 corrects the first live social-stealth balance failure: a plausible visible Security weapon is normal, a different Security family is only mildly suspicious, the post-change window is no longer full exposure and body evidence cannot propagate from distance without native sight.
- RC36 adopts the final simple identity rule: every held weapon and reload is neutral. It removes the global post-shot exposure timer and global-combat recognition, while loud fire, wounded guards and casualties now send response units to a position without handing them the player's identity.
- Routine drones now consume social-stealth risk instead of treating every player silhouette identically. Their real cone/raycast can detect each exposed body once and compromise the stolen identity when its source is found.

The Scout deliberately does not shoot. Six armed variants join escalated wings: light/heavy Pistol, SMG and Laser. Ballistic models use native bullets; laser models display an uninterrupted charge cue. No model attacks without confirmed line of sight, range, gimbal alignment and cooldown readiness.

## Immediate acceptance gate

1. Completely restart the game and confirm `0.14.2-rc36` loads without traceback and without an internal RC render diagnostic on the HUD.
2. Observe multiple deployments and identify Scout, light and heavy silhouettes; heavy variants must be larger but remain actor-scaled.
3. Stand visibly inside the cone: the cone should enter contact state and response guards should move to the reported position.
4. Break line of sight behind solid geometry: the drone must not keep perfect live tracking through the wall.
5. Disrupt a drone: its body should flicker and it must stop acquiring/relaying until disruption ends.
6. Shoot the visible center and deliberately the outer rotors/corners of moving light and heavy drones. Every visible region must register. The light model must fall on the first registered hit. Heavy hits must tint the complete airframe, emit an expanding spark ring and briefly show two/three pips; every heavy must fall on hit two or three, including against Model-700-class fire.
7. Watch one light and one heavy destruction: firing, aim cue, rotor loop and light cone must stop immediately; the airframe must visibly change into damaged frames, tumble for roughly 0.78/0.95 seconds, trail smoke/sparks, produce a landing ring/debris burst and remain as an asymmetric inert wreck. Response actors should investigate that landing point.
8. Trigger an armed wing: verify a Pistol/SMG native projectile and a Laser that holds its aim line for 0.9/1.4 seconds before firing.
9. Circle a tracking drone: the gimbal should follow first, then the body should yaw; the drone must hold a standoff slot instead of flying through or endlessly orbiting the player.
10. Observe an aggressive wing for at least 20 seconds: no drone should remain unexpectedly still for more than roughly half a second, and blocked drones should choose a new heading.
11. Observe initial deployment and draw a drone toward a building exterior: no armed drone may spawn or route beneath a native roof, and it must steer around walls, closed doors and windows instead of crossing the boundary; low outdoor cover may be overflown.
12. Keep response units in combat/search long enough for follower instruction timers to advance; no `getWatchBack` traceback may occur.
13. Confirm normal weapon fire, vanilla objectives, mission completion, checkpoint reload and return to menu still work.
14. Compare a calm valid disguise with aiming/sprinting/firing in a patrol cone; the former must buy time without granting invisibility and the latter must restore rapid scrutiny.
15. Leave the stolen-uniform source body exposed to a patrol drone; the body must be reported once, show a compact evidence cue and compromise that identity. A disrupted drone must not scan it.
16. On a multi-contract map, confirm no more than twelve active airframes globally and no contract fields more than two Heavy or two Laser models.

The complete fourteen-step disguise/social-stealth live gate and its native engine boundaries are maintained in `SPECIFICATION_TRACEABILITY.md`.

## Release boundary

HCO is a code-complete production candidate for its current contract/stealth/drone feature surface, not yet a proven `1.0`. RC36 replaces weapon-plausibility and global-alert shortcuts with the final observer-local identity rule while retaining RC35's body-sight correction, RC33's persistent wreck correction, RC32's durable batch/projectile sweep, RC31's terminal destruction and RC30's outdoor/reciprocal-combat correction. Promotion requires both live matrices; optional future systems such as dedicated operators, thermal cameras and new contract families remain explicitly outside this candidate rather than being silently claimed.
