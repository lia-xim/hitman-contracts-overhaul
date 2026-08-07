# Hitman Contracts Overhaul — Implementation Status

**Current version:** `0.14.9-rc43`
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
| Mobile target | RC43 preserves the native patrol-state path, advances the authored route through its watchdog and owns all five close guards as one verified follower chain | Prove long patrol continuity, local-incident relocation and escape across several maps |
| Heavy protection detail | Five close guards plus difficulty-scaled 5/10/15/20 archetype response demand, bounded by safe actors | Guarantee mission-appropriate strong weapon upgrades and verify every response tier fights effectively |
| Hunt and last-known-position search | Implemented | Tune pursuit pressure, containment and stand-down from real gameplay evidence |
| Disguise and social stealth | RC43 candidate path: weapon-neutral distance cover, close scrutiny, point-blank exposure, first-position native takeover, explicit rollback, persistent identity shimmer and mission-lifecycle interaction repair | Full real-mission pass in `SPECIFICATION_TRACEABILITY.md` |
| Credentials and radio propagation | RC34 keycard/keychain capture before native drop, consistent off-limits queries, interruptible identity/body reports and reload restoration | Verify real mission doors, radio audio/range and checkpoint matrix |
| Multi-contract persistence and payout | Implemented | Live active/terminal reload matrix and multi-target exactly-once payout |
| Drone presence and patrol | Seven-model roster plus RC41 committed patrol, bounded barrier hop, invalid-sector fallback and stationary 360-degree scan implemented | Live-approve sustained movement, exterior transitions and boxed-in fallback |
| Drone detection and response relay | Stable pursuit, independent gimbal, strict geometry authority, map-wide alarm, transition lockout and RC43 post-LOS/post-casualty combat continuity implemented | Prove red network search, LOS loss/reacquisition, no overflight fire and response convergence |
| Drone disruption and destruction | Implemented across all seven models; RC33 mission-ticked wreck animation, durable native wreck batch, full first-shot sweep and terminal weapon/light cleanup | Live-test frame 1→2→3→4 progression, free fire without right-click, EMP lockout and crash-site response |
| Drone perception semantics | Implemented for observer-local behavior risk, compromised identity and body/source-uniform evidence; held weapons are neutral | Live-test routine versus aggressive identity timing, body concealment and source-uniform compromise |
| Drone navigation | Native outdoor footprints, steering, search rings, flanks, separation, safety recovery and bounded unarmed narrow-barrier overflight implemented | Live-approve zero indoor spawns, wall/gate hops, rejected roof crossings and long aggressive-search behavior |
| Drone command infrastructure | Missing | Add meaningful drone operators, radio dependency and sabotage/power counterplay |
| Thermal surveillance | Missing | Build readable thermal-camera subtype with LOS, disruption and power/operator counters |
| Armed drone variants | RC22 implemented: Pistol/SMG native bullets and charged Laser | Live-test damage, friendly obstruction, telegraphs, cooldowns, God Mode compatibility and counterplay |
| Custom archetype identity | Partial | Native full animation variants plus original insignia exist; complete custom character atlases are deliberately deferred until animation coverage is safe |
| Contract variety | Partial | Data theft, accidents, special weapon conditions, rescue/extraction and other systemic contract types |
| Localization/audio callouts | Partial | English runtime text exists; translated strings and an authored localized radio-callout pack remain |

## RC22 roster / RC23–RC43 live corrections

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
- RC37 closes the remaining native AI bypass: suspicion, alert, body-investigation and combat states may no longer force `setEnemyInSight` or combat merely because a calm disguised player is close. A fresh identity clears stale actor-specific sight memory for uninformed guards; actual takeover witnesses retain local knowledge and can radio it.
- RC38 closes the native close-protection follower crash when a follower changes to combat/fear and removes alert-state/hunch shortcuts that made an uninformed protected target flee from a valid disguise. Calm cover now stays below the native 40% suspicion-success threshold.
- RC39 restores deliberate infiltration risk: FOV/raycast-confirmed point-blank contact exposes immediately, sustained 150-unit scrutiny exposes after a role/familiarity-scaled dwell, lost contact decays progress and successful recognition resumes the original Goon response instead of stopping at a red indicator.
- RC40 stops patrol destinations from being replaced before arrival, tries every authored sector before deterministic outdoor fallbacks, gives truly boxed-in sensors a continuous 360-degree scan and propagates confirmed drone contact to every active HCO wing and response team on the map. Alarmed wings remain visibly red, but each weapon still requires its own unobstructed shot.
- RC41 bridges narrow exterior walls/gates only after steering stalls and a second outdoor footprint is proven. The eased hop is visibly lifted but completely disarmed and blind until landing. Protected targets also regain stalled routine patrols, react to nearby audible incidents and reselect compromised shelter; active disguises gain a persistent world shimmer and an explicit native rollback action.
- RC42 separates an aggressive location search from confirmed appearance knowledge. Clean disguises remain capped amber suspicion outside 155/205-unit close scrutiny, shared confirmation is tied to the observed outfit token, changing clothes invalidates stale drone fire/tracking, and disguise risk is published in the acquisition frame. Stable handed wall following plus a 2.4-second destination-progress watchdog replaces oscillating movement that never approached its route.
- RC43 stops deleting the path produced by native patrol activation and replaces overwritten follower branches with one complete bodyguard chain. Confirmed drones may reacquire current exposed identity through fresh LOS after stale location reports and retain a stable native projectile-attribution actor after protection casualties. Disguise takeover/restore bindings now self-repair after mission/class/menu lifecycle resets and rebuild stale body caches by generation.
- Routine drones now consume social-stealth risk instead of treating every player silhouette identically. Their real cone/raycast can detect each exposed body once and compromise the stolen identity when its source is found.

The Scout deliberately does not shoot. Six armed variants join escalated wings: light/heavy Pistol, SMG and Laser. Ballistic models use native bullets; laser models display an uninterrupted charge cue. No model attacks without confirmed line of sight, range, gimbal alignment and cooldown readiness.

## Immediate acceptance gate

1. Completely restart the game and confirm `0.14.9-rc43` loads without traceback and without an internal RC render diagnostic on the HUD.
2. Observe multiple deployments and identify Scout, light and heavy silhouettes; heavy variants must be larger but remain actor-scaled.
3. With the original/exposed identity, stand visibly inside the cone: the cone should enter contact state and response guards should move to the reported position. Repeat with clean cover beyond 205 units: the cone must remain amber and must not track, confirm or fire. Move inside 155 units during patrol or 205 during an alarm and verify progressive close scrutiny before red contact.
4. Break line of sight behind solid geometry: the drone must not keep perfect live tracking through the wall.
5. Disrupt a drone: its body should flicker and it must stop acquiring/relaying until disruption ends.
6. Shoot the visible center and deliberately the outer rotors/corners of moving light and heavy drones. Every visible region must register. The light model must fall on the first registered hit. Heavy hits must tint the complete airframe, emit an expanding spark ring and briefly show two/three pips; every heavy must fall on hit two or three, including against Model-700-class fire.
7. Watch one light and one heavy destruction: firing, aim cue, rotor loop and light cone must stop immediately; the airframe must visibly change into damaged frames, tumble for roughly 0.78/0.95 seconds, trail smoke/sparks, produce a landing ring/debris burst and remain as an asymmetric inert wreck. Response actors should investigate that landing point.
8. Trigger an armed wing: verify a Pistol/SMG native projectile and a Laser that holds its aim line for 0.9/1.4 seconds before firing.
9. Circle a tracking drone: the gimbal should follow first, then the body should yaw; the drone must hold a standoff slot instead of flying through or endlessly orbiting the player.
10. Observe patrol and aggressive wings for at least 30 seconds: drones must keep their route long enough to visibly travel, choose alternate outdoor sectors when an authored point is invalid, keep one wall-follow direction and abandon any route that produces shuffling without destination progress. Only a genuinely boxed-in drone may hover, and it must continue a full rotating scan.
11. Observe initial deployment and draw a drone toward exterior separation: no armed drone may spawn beneath a native roof. It should steer first, then visibly hop a narrow wall/gate between verified outdoor cells without scanning or firing during transit. It must refuse a roofed building or wide inaccessible span.
12. Keep response units in combat/search long enough for follower instruction timers to advance; no `getWatchBack` traceback may occur.
13. Confirm normal weapon fire, vanilla objectives, mission completion, checkpoint reload and return to menu still work.
14. Take a disguise from the first body action, confirm the persistent cyan player shimmer, then use **Restore original identity** from a body menu. The original actor appearance must return, active disguise persistence must clear, and copied credentials/consumed sources must remain. Compare calm cover with aiming/sprinting/firing; the former buys time without granting invisibility and the latter restores rapid scrutiny.
15. Leave the stolen-uniform source body exposed to a patrol drone; the body must be reported once, show a compact evidence cue and compromise that identity. A disrupted drone must not scan it.
16. Watch the principal and all five close guards for more than 15 seconds in routine. The target must traverse its authored route and the detail must remain one moving chain. Break LOS with a confirmed armed drone for more than ten seconds, return to a clear firing lane and kill nearby HCO guards or the principal: every intact armed drone must reacquire and continue firing. Restart the mission, kill or choke a fresh eligible Goon and verify that the first outfit action is present again.
16. On a multi-contract map, confirm no more than twelve active airframes globally and no contract fields more than two Heavy or two Laser models.

The complete fourteen-step disguise/social-stealth live gate and its native engine boundaries are maintained in `SPECIFICATION_TRACEABILITY.md`.

## Release boundary

HCO is a code-complete production candidate for its current contract/stealth/drone feature surface, not yet a proven `1.0`. RC43 corrects the live stationary-principal, stopped-drone-fire and missing-restart-action reports while retaining RC42's disguise-aware sensing and navigation work. Promotion requires both live matrices; optional future systems such as dedicated operators, thermal cameras and new contract families remain explicitly outside this candidate rather than being silently claimed.
