# Specification traceability

**Candidate:** `0.14.10-rc44`
**Target runtime:** Intravenous 2 `1.4.12HF3`  
**Authority:** `SPECIFICATION.md`  
**Rule:** `Automated` means the controlled LÖVE harness exercised the contract. It never means the behavior has been accepted in a real mission.

This document prevents future work from collapsing the product specification into a list of loosely related features. Every release candidate must update this matrix, preserve the engine boundary named here, and keep live evidence separate from simulated evidence.

## Whole-product matrix

| Specification area | Runtime owner | Candidate state | Automated evidence | Live gate |
| --- | --- | --- | --- | --- |
| Native-first presentation | `contracts/objective.lua`, `feedback.lua`, native interaction lists, actor/world draw hooks | Implemented for the current feature surface | Boot, runtime, feedback and visual suites | Confirm no detached menu, overlapping banners or cursor capture |
| Deterministic optional contracts | `contracts/core.lua`, `selector.lua`, `persistence.lua` | Implemented | Runtime lifecycle, reload, rollback and multi-contract cases | Test compatible campaign maps and one unsupported map |
| Mobile target and secure movement | `targets/controller.lua` | RC43 native patrol-path preservation and routine/incident watchdog candidate | Native `onPatrolRouteSet` path creation/preservation, routine recovery, first-shot caution, threatened, sheltered, incident reselection, escape and stuck-route cases | Long live route/reload/incident pass on several maps |
| Protection and response roles | `security/escort.lua`, `security/director.lua` | RC43 complete single-follower chain for close protection and autonomous response | Exact five-guard ownership chain, reconstruction, search and follower safety cases | Verify moving detail, weapons, combat pressure and difficulty balance in game |
| Knowledge and hunt phases | `security/director.lua` | Implemented | Local evidence, pressure, decay and stand-down cases | Verify no wall omniscience and readable convergence |
| Disguise acquisition and switching | `social/disguise.lua` plus native Goon interaction machinery | RC44 first-action takeover, authoritative query-time reconciliation, lifecycle rebinding, stale-cache repair, explicit rollback and persistent-state presentation candidate | Native two-action enumeration/order, stale-bitmask generation reset, cached `update=false` selector repair, runtime class/menu rebind, death-time identity capture, three switches, rollback and persistence cleanup | Must be accepted from the real body interaction wheel after fresh start and restart |
| Social recognition | `social/disguise.lua` plus instantiated native Goon sight states | Implemented for the observer-local uniform-class model | Instant-bypass interception, 150-unit timed close scrutiny, 72-unit point-blank exposure, native hostile handoff, arbitrary held weapon, witnessed/unwitnessed fire, access, evidence and compromise cases | Prove distance bands and native response in a real mission |
| Credentials and restricted areas | Native `playerActor:addKey` and off-limits queries, coordinated by `social/disguise.lua` | Implemented for keycard and keychain IDs | Acquisition/reload and adjusted trespass-query cases | Verify actual mission doors and STAFF/SECURITY/ELITE areas |
| Existing cameras | `security/sensors.lua` | Implemented | Camera risk scaling and disruption/break evidence in runtime fixtures | Live camera cone, disguise and wall/EMP pass |
| Physical drone system | `security/drones.lua` and drone modules | RC43 appearance-scoped sensing, live-LOS reacquisition, stable projectile attribution, progress watchdog, stable wall following, bounded inert barrier hop, outdoor fallback and shared map alarm candidate | Dedicated drone, roster and airframe suites, including stale-location and post-casualty fire continuity | RC43 live disguise-distance/patrol/barrier/network/combat-continuity matrix remains mandatory |
| Rewards and persistence | `contracts/rewards.lua`, `persistence.lua` | Implemented | Exactly-once reward, active reload, terminal reload and bundle cases | Campaign save/reload across mission transitions |
| Authored map profiles | Contract archetypes provide visual/doctrine identity; per-map authored safe-area profiles remain partial | Partial | Profile selection and deterministic doctrine cases | Author and approve high-value mission profiles |
| Expanded contract families | Eliminate/neutralize plus bonus conditions are present; theft, extraction and authored accidents are not | Partial expansion | Current contract-resolution cases | New families require their own engine proofs |
| Thermal cameras | Specified as a later advanced-security system | Not implemented | None | Do not advertise until a physical native subtype exists |
| Dedicated operators and power sabotage | Specified as advanced security | Not implemented | None | Do not advertise until operator/radio/power ownership is real |
| Full localization and authored radio pack | English runtime text and native radio behavior exist | Partial | String and radio-state cases | Translation tables plus localized live pass |

## Disguise and social-stealth contract

### Native interaction ownership

The game owns body interaction through `goon.interactionList`, `entity:enumerateActions`, `entity:getInteractOptions`, `entity:updateInteractionList`, `currentActionBitmask`, and `entity:postInteract`. RC41 owns two sentinel entries in that native list: takeover at position one and original-identity restoration directly behind it.

The integration contract is:

1. Find or create exactly one takeover sentinel and one original-identity restore sentinel on the real Goon class list; remove duplicate entries left by reload/hot-load.
2. Re-run native action enumeration so IDs remain powers of two and `actionTrackerID` advances correctly, including actions added by other mods.
3. Refresh already-cached interaction lists instead of assuming all bodies are created after HCO.
4. Refresh after `_die`, `_choke`, `makeFallen`, and `onBodyDropped`.
5. Call native `postInteract` after takeover or restoration so the body menu updates immediately.
6. Never expose takeover without an active HCO contract, a player interactor, an eligible dead/unconscious Goon, a valid appearance variant, and an unused source identity. Expose restoration only while an identity is active.

This closes the RC33 test gap where the harness called `option.interact` directly but never proved that the engine would display the option.

### Identity data

An active identity now records and persists:

- actor animation/uniform group;
- source actor ID and consumed-source set;
- STAFF, SECURITY or ELITE SECURITY tier;
- native off-limits reduction;
- keycard and keychain IDs;
- source weapon type and weapon ID as identity metadata only, never as recognition inputs;
- pre-disguise player appearance;
- acquisition timestamp;
- dead/unconscious source condition;
- bloodied condition;
- HCO faction-insignia variant;
- local and globally compromised uniform knowledge.

Identity data is captured before native death/choke code drops weapons and credentials. Reconstructing it later from a stripped corpse is not allowed.

### Recognition inputs

The release model multiplies native detection instead of replacing sight, distance, time, geometry or alert-state behavior.

| Input | Result |
| --- | --- |
| Calm, distant, unrelated unit | 8% baseline native detection growth |
| Same animation/familiarity group | 22% baseline before experience/role scaling |
| Elite observer | Familiarity factor ×1.35 |
| Close protection / protected target | Familiarity factor ×1.2 / ×1.45 |
| Any merely held weapon, weapon family or holster state | 0 additional identity risk for every tier |
| Sprint | 75% scrutiny |
| Aim, lock breaking, sabotage, body carry or violent native state | Immediate exposure when the observer can perceive the action |
| Reload alone | 0 additional identity risk |
| Fire seen by this observer | Immediate local compromise; radio may propagate it |
| Fire heard but not seen | Search position only; no player identity |
| First 1.5 seconds after taking a uniform | 25% close scrutiny; real witnesses/body discovery remain authoritative |
| Bloodied uniform | Minimum 28% scrutiny and an explicit acquisition warning |
| Fresh nearby HCO evidence | Minimum 45% scrutiny for up to twelve seconds |
| Repeated target lingering | 35% warning after four seconds, 65% danger after eight |
| Global alert/combat elsewhere | No identity information; observer-local knowledge remains authoritative |
| Locally informed observer | Immediate exposure to that observer |
| Globally compromised uniform | Immediate exposure everywhere in the contract network |

The values are intentionally centralized in `config.lua`; live balancing changes must not be scattered through hooks.

### Access and credentials

- STAFF reduces one native off-limits level.
- SECURITY reduces two.
- ELITE SECURITY reduces three.
- Risk at or above 50% suspends the access reduction, so sprinting through a protected area or lingering at the target cannot remain authorized.
- Both `getOfflimits` and `getOfflimitsActive` use the same adjusted result so AI and native trespass presentation cannot disagree.
- Keycards/keychains are granted through the native player key inventory and remain valid after uniform compromise, matching the specification.
- The engine does not expose semantic names such as `PRIVATE_TARGET` on its area objects. RC34 maps the specification tiers onto the existing numeric off-limits ladder. Per-area identity allowlists require authored map profiles and remain a profile-level expansion, not a fake parallel zone system.

### Local knowledge, radio and compromise

- A body investigator learns locally and informs nearby guards.
- HCO never discovers a body by distance alone. A guard must enter the native `setSeenBody` investigation path; drone evidence requires the physical cone and world raycast.
- The real NPC radio is opened; a disruption, unconscious/dead carrier, lost identity-check proximity or timeout cancels the transmission.
- A completed body report compromises the uniform class globally.
- Same-unit scrutiny can start an explicit, visible, interruptible identity check once native detection reaches 55%.
- Moving away breaks an identity check; remaining nearby until the radio completes compromises the uniform.
- Player gunfire compromises direct witnesses locally and lets their valid radios propagate it.
- A drone uses its actual cone and world raycast to inspect bodies; discovery of the active source identity compromises it through the network.
- Hidden bodies are not discovered by this module. There is no timer-based omniscient compromise.

### Appearance and transition language

The permanent state is communicated by the player's real animation variant, matching restrained torso insignia and a low-alpha segmented identity shimmer around the player (cyan while credible, red while compromised). Transitions use the same world-space `playerActor:postDraw` hook, never a detached screen/menu layer:

- cyan segmented ring, brackets and pixel stitch burst for acquisition/switching;
- muted teal confirmation on reload restoration;
- amber progress sweep while a real radio identity check is active;
- broken red ring, brackets and breach cross on compromise.

Acquisition and compromise reuse known native UI sounds. Identity checks deliberately rely on the real NPC radio audio so the player can locate and disrupt the source. Compact lower-third native-style feedback gives tier, credentials, bloodied risk and compromise state without remaining permanently on screen.

### Persistence and rollback

- All identity fields are copied through the v3 contract bundle without invalidating older records.
- The original player appearance is preserved across reload instead of being inferred from an already-disguised save actor.
- Consumed source IDs survive checkpoint reload.
- The current animation variant, credentials, faction mark and compromised-class map are restored together.
- Contract cleanup restores the original player variant and removes HCO's player insignia/effects.
- The explicit restore action clears only the active disguise record/visual and pending identity calls. Copied credentials, consumed-source IDs and learned compromised-uniform history remain authoritative.
- If a variant cannot be applied and read back, takeover fails atomically and the previous appearance/identity remains authoritative.

## RC34 automated acceptance

RC34 is not allowed to advance unless all of the following remain green:

- HCO puts takeover/restore at native positions one/two, assigns IDs `1`/`2`, and advances the tracker to `16` in the controlled vanilla two-action fixture.
- A body whose interaction cache predates HCO receives the action through the real update-list path.
- `_die` captures weapon/keycard identity before native stripping.
- A successful interaction calls native `postInteract` and cannot be repeated from the same source, including after reload.
- STAFF, SECURITY and ELITE SECURITY identities can be acquired and visibly switch the player variant.
- Keycards and keychains reach the native player inventory.
- Original appearance, active identity, used sources and compromise knowledge survive reload.
- Lock breaking restores full detection when perceived; held weapons and reloading remain identity-neutral.
- Same-unit scrutiny opens a real interruptible radio check.
- Body discovery stays local until a completed radio transmission.
- Drone discovery of the source identity compromises it globally.
- The player-world draw hook renders all acquisition/check/compromise transition primitives and the active faction insignia.
- All existing contract, target, guard, reward, drone, visual, feedback and degraded-boot suites remain green.

## RC35 live-balance correction

The first reachable in-game disguise revealed that weapon and takeover scrutiny were too abrupt. RC35 introduced the following intermediate regressions; its weapon-family distinctions are superseded by RC36's fully weapon-neutral rule:

- a visible weapon with the same native Security family does not immediately reveal a new identity;
- a different ordinary Security weapon family creates mild scrutiny instead of an instant failure;
- STAFF with a visible firearm, aiming, firing and native combat remain fully exposing;
- same-unit and elite observers stay faster than unrelated guards without completing recognition in one ordinary glance;
- the post-change window is short scrutiny, not three seconds of globally unmodified detection;
- nearby guards cannot report the source body until the game's real body-sight event occurs.

## RC36 observer-local correction

The second live pass established a simpler product rule and exposed two engine-integration leaks. RC36 therefore makes these non-negotiable:

- weapon model, weapon family, drawn/holstered state and reload never affect identity for STAFF, SECURITY or ELITE SECURITY;
- an unobserved shot never compromises the disguise and never starts a global post-shot exposure timer;
- persistent vanilla `getSeenPlayer()` memory is not current sight; direct witnesses must pass the native current vision AABB, FOV and world raycast at the firing event;
- a direct visual witness recognizes the firing player locally and may propagate that knowledge through a valid radio;
- global combat elsewhere never grants identity knowledge to an uninformed observer;
- loud gunfire, guard damage and protection casualties mobilize responders toward an incident position without calling `setEnemyInSight` or attaching the player actor;
- only confirmed sight, body/camera/drone evidence or completed communication can turn a location search into player-specific pursuit.

## RC37 native instant-detect correction

The next live pass proved that scaling `goon:increaseDetection()` was not sufficient. Native suspicion, alert, body-investigation and combat states each own a direct close-range path that can call `setEnemyInSight(true, player)` and/or enter combat without honoring the scaled result. RC37 therefore adds these invariants:

- every existing and newly requested Goon state instance with `onSightHitPlayer` is guarded while a clean, calm disguise is active;
- the guarded path retains the state's native `advanceDetection` calculation; RC38 caps ordinary social suspicion at `0.39`, immediately below the native suspicion state's `0.40` success boundary, while the timed colleague check can still cross the explicit `0.55` identity-check threshold;
- a class-level `setEnemyInSight(true, player)` boundary rejects any other native state that attempts to create player-specific hostility without observer knowledge;
- aiming, directly witnessed fire, suspicious interaction states, a local compromise, a globally compromised uniform and communicated evidence bypass the guard and retain the original game behavior;
- changing clothes clears stale player detection, `seenPlayer`, vision/hearing target and player-specific enemy-map entries for uninformed observers;
- a guard that passes the current native AABB/FOV/raycast during the takeover keeps local knowledge of the new identity and may radio it;
- checkpoint restoration performs a clean rebind without inventing takeover witnesses merely because a guard sees the already-restored appearance.

## RC38 follower and alert-knowledge correction

The next live pass showed two distinct systems being conflated. First, an HCO close guard could leave `goon_idle_following` for combat while the native leader retained it as a follower; native alert code then called `getWatchBack` on that combat state and crashed. HCO now records both sides of every close-protection link and validates all four follower-instruction methods at the leader's real `getFollower` boundary. An incompatible HCO link is removed before native alert code receives it, without changing vanilla-owned followers.

Second, a native yellow/red alert state or last-known hunch is not proof that an observer recognized the person inside a clean disguise. The security director and target controller now require direct enemy sight, observer-local/global compromise or explicit communicated evidence before treating those native values as player-specific. Gunfire, bodies, sensors and radio propagation continue to move the principal and mobilize response units normally.

## RC39 close-inspection risk and native response

- Below 72 world units, a current unobstructed native visual contact immediately establishes observer-local identity knowledge.
- Between 72 and 150 units, scrutiny accumulates over 2.4 seconds before role modifiers. Same uniform multiplies time by `0.55`, elite experience by `0.75`, close protection by `0.75` and the protected target by `0.60`, with a hard 0.55-second minimum.
- Breaking FOV/raycast contact or backing outside the band drains progress at `1.8×` elapsed time. A momentary close crossing is therefore recoverable.
- Recognition sets only that observer's detection to full and calls its patched state sight method after local knowledge is recorded; the wrapper then reaches the original native threaten/startle/surrender/combat implementation.
- The observer may transmit a non-cancellable-by-distance recognition report through its real radio. Death, unconsciousness or disruption still cancels that report before global compromise.
- The orange-red local exposure transition is rate-limited and visually distinct from global uniform compromise.

## RC40 patrol continuity and shared drone alarm

- A patrol/search destination is stable until the airframe reaches it, direct player tracking needs a refresh, tactics request a flank/search relocation, or the existing idle watchdog invalidates it. A timer alone may not replace a distant waypoint.
- A candidate must be a safe outdoor point and move the airframe at least 96 world units. The selector tries every authored sector in a deterministic per-drone order, then up to twelve deterministic outdoor ring candidates; current-position and roofed/invalid results are rejected.
- If no valid travel destination exists, the drone remains a functioning sensor and rotates its body/gimbal through a continuous 360-degree sweep. Hovering is allowed only as this geometry fallback, not as an inert state.
- A confirmed sighting is shared across every active HCO contract context on the current map. All living wings drop stale destinations, enter `AGGRESSIVE`, retain red searchlights and search the reported last-known position; all response details receive actionable native contact.
- Network alarm never bypasses local weapon geometry. An armed drone still needs its own current raycast, range, aim tolerance, valid outdoor footprint and physical hitbox before firing. The Scout remains deliberately unarmed and contributes detection/relay only.
- A weapon carrier may use a living response actor from any active HCO context for native projectile attribution, so a surviving armed wing does not become inert after its own principal/detail dies while another network detail remains alive.
- Automated coverage must prove fallback travel, destination commitment, cross-context wing/guard propagation and red network-search presentation. Live acceptance must hold for at least 30 seconds on a multi-contract map.

## RC41 exterior transition, target awareness and identity readability

- Ordinary steering remains the first response to a wall. Only after 0.85 seconds of blocked progress may a drone inspect the intended heading for a landing no farther than 144 units away; the obstructed run may be at most 96 units and the destination must pass the complete outdoor footprint check.
- The resulting eased hop is a named movement-only state. Native camera update, HCO player/body acquisition, contact relay and weapon authority are all suspended until landing. The carrier and hitbox follow the visible airframe, which gains a short lift arc and cyan pixel cues.
- A wide roof/building or map void produces no valid landing. Safety retirement/recovery still applies outside the explicit transition, preventing a hidden or unreachable armed carrier.
- Protected targets now sample routine movement. Nine seconds without progress advances the original native patrol route rather than leaving a principal indefinitely AFK.
- One nearby unsuppressed shot writes only a location-level protection incident and cautious target threat. It cannot identify the shooter. Damage/casualties or confirmed evidence still produce full flight; a fresh local incident can invalidate a sheltered safe area.
- Takeover is the first eligible native body action, restoration is the second HCO action, and a persistent world shimmer makes the active/compromised identity readable. Restoration returns the original player variant and clears campaign disguise fields while retaining copied credentials, consumed identities and previous compromise knowledge.
- Automated coverage must prove bounded landing selection, transit sensing lockout, target routine recovery, first-shot caution, action order, removal and persistence cleanup. Live acceptance must prove geometry, native-AI movement and render behavior.

## RC42 drone identity and navigation continuity

- `AGGRESSIVE` is a location-search order only. It may change route and speed, but it may not supply player identity, cone-less tracking or weapon authority by itself.
- Every confirmed guard/drone handoff records an appearance token: `original` or the active disguise group plus acquisition timestamp. A clothing change invalidates per-drone tracking, detection grace, recent confirmation and weapon authorization tied to the previous token.
- A clean disguise outside 155 world units in patrol or 205 during an alarm can accumulate only 42% amber sensor suspicion. It cannot create `droneSighting`, tracking or fire. Inside the applicable band, sustained real cone/raycast contact builds progressive scrutiny before confirmation. Compromise, aiming and other overt risk still remove this protection.
- Disguise acquisition/restoration publishes its semantic risk in the same transaction as the actor variant, so there is no one-frame unmasked sensor state.
- Building avoidance keeps one deterministic handed tangent instead of changing side every frame. In addition to physical-idle recovery, a 0.6-second sampled watchdog rejects any route that fails to improve destination distance by seven units for 2.4 seconds, changes the search/flank approach and retains the existing no-sensing/no-fire barrier transition rules.
- Automated coverage must prove amber long-range cover under alarm, delayed close scrutiny, current-token confirmation, atomic risk publication, stable wall-follow direction and recovery from non-progressing motion. Live acceptance must prove the distance colors, no instant attack and continuous map movement.

## Required live acceptance for this feature

Automated completion is not production acceptance. On Intravenous 2 `1.4.12HF3`, fully restart the game and verify:

1. Kill and separately choke a guard. The native interaction selector must show `Take disguise / search body` as the first eligible action without a custom key or menu.
2. Take the disguise. Confirm an immediate actor change, short cyan transition, compact identity message and a restrained persistent cyan shimmer with no input/cursor regression.
3. Confirm takeover disappears from that body and **Restore original identity** becomes the first remaining identity action. Restore once: the original appearance and persisted active disguise must clear, while credentials and consumed-source history remain. Reacquire another eligible identity and quicksave/quickload it.
4. Repeat with an unarmed staff actor, normal guard and elite guard. The appearances and tier messages must differ where the map supplies distinct variants.
5. Take a carried keycard/keychain identity and open the corresponding real door. A uniform without credentials must not fabricate the key.
6. Walk normally while holding several arbitrary weapons, including the player's normal silenced pistol. At normal distance, holster/unholster and reload must remain neutral. Make one brief close pass and retreat before scrutiny completes; then remain in unobstructed close view until that observer exposes you. Finally enter point-blank view and confirm immediate native threatening/combat. Matching colleagues and elite guards must resolve the close check faster.
7. Fire one suppressed shot without any visual witness and relocate. Guards may investigate a heard impact/body according to native perception but must not identify the player. Then let one guard directly see aiming/firing and confirm only that observer knows until a real radio report completes.
8. Remain close to the protected target, then leave. Scrutiny must rise after sustained lingering and recover after withdrawal.
9. Expose the source corpse to one guard. Only that guard/nearby witnesses should know before its real radio completes. Disrupt or neutralize it and confirm no global compromise.
10. Repeat and allow the radio to finish. Confirm the red compromise transition and full recognition by a previously uninformed guard.
11. Trigger a same-unit identity check. Walk out of range to cancel once; remain nearby to fail once.
12. Leave the source body in a drone's unobstructed cone, then repeat with the drone disrupted. Only the valid scan may compromise the identity.
13. Save/reload while clean and while compromised. Appearance, persistent cyan/red shimmer, credentials, source consumption and compromise state must agree after both reloads.
14. Finish/restart/leave the mission. The player's campaign appearance, shimmer and normal no-disguise combat must be restored with no HCO traceback.

Any failed item returns this matrix to `implemented, live-blocked`; it must not be described as production-proven.
