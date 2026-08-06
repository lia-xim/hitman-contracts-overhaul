# Changelog

## 0.10.0-rc15 — 2026-08-06

- Corrected the render hook after engine inspection proved that the main renderer never invokes `world:postDraw()`.
- Drone bodies now render immediately after `world:drawActors()` while the world camera transform is active.
- Replaced stationary-camera detection assumptions with explicit distance, cone-angle, and obstruction checks.
- Added a short sight-contact grace period so a moving drone cannot lose a player between adjacent samples.
- Reduced aggressive confirmation time to 0.55 seconds and passive patrol confirmation to roughly one second.
- Added deterministic coverage for sustained in-cone player detection and confirmed drone sightings.

## 0.10.0-rc14 — 2026-08-06

- Fixed invisible drone bodies while their searchlights remained active.
- Moved animated drone drawing from the skipped runtime-camera `postDraw` path into a dedicated world render hook.
- Added an active-drone render registry with automatic pruning of broken or removed drones.
- Increased the bundled flight-sheet render scale slightly for clearer in-game readability.
- Added fixture coverage proving every active drone is drawn once while the native world render pass is preserved.

## 0.10.0-rc13 — 2026-08-06

- Fixed the live `quadStruct` crash caused by sending runtime-created camera carriers through finalized native sprite batches.
- Drone carriers now bypass native sprite updates and use the bundled animated flight sheet for rendering.
- Replaced simultaneous fading-text indicators with a deduplicating sequential notification queue.
- Moved HCO tactical notices to the lower third to avoid native objective announcements.
- Made contract completion the only notification that can pre-empt stale tactical messages.
- Reset pending notifications across map unload, reset, level completion, and main-menu transitions.

## 0.10.0-rc12 — 2026-08-06

- Replaced late custom drone-class creation with per-instance behavior on an engine-owned security-camera carrier.
- Kept a visible native drone body when the custom flight sprite is unavailable and removed the invalid camera-booth dependency from drone destruction.
- Added exact on-screen drone spawn/runtime diagnostics instead of a silent `INBOUND` dead end.
- Split protection into five close bodyguards and archetype-scaled 5/10/15/20 response units.
- Fixed the confirmed-hostile-contact path so it mobilizes the full response rather than only queuing drones.
- Prevented HCO from ordering the target into combat and continuously reasserted its native fear-run escape state when vanilla perception tries to re-enter combat.
- Added a compact response deployment notice containing the actual number of available response units.

## 0.10.0-rc11 — 2026-08-06

- Added passive drone patrols from the beginning of every active contract.
- Added explicit `PATROL` and `AGGRESSIVE` drone modes with different movement speed, detection time, and destination logic.
- Existing patrol drones now accelerate and search last-known positions after escalation; additional doctrine drones may join them.
- Restricted the gunfire escalation to player-owned, unsuppressed weapons. NPC shots and suppressed player shots are ignored.
- Added automated coverage for passive startup, suppressor filtering, player-only firing, and aggressive transition.

## 0.10.0-rc10 — 2026-08-06

- Added a deterministic drone escalation after three player shots within eight seconds during an active contract.
- Added an on-screen `DRONE SUPPORT INBOUND` acknowledgement when a deployment is queued.
- Added a physical native-security-camera fallback when the engine rejects creation of the registered HCO drone class.
- Added automated coverage for fallback creation, movement, and diagnostics.

## 0.10.0-rc9 — 2026-08-06

- Exempted HCO security from the companion trainer's disabled-detection mode.
- Added immediate protection mobilization on confirmed contact, guard damage, and protection casualties.
- Corrected drone-to-guard contact hand-off to enter native combat rather than passing a player object as allied sighting data.
- Changed archetype protection targets to 5/10/15/20 guards, subject to safe map population and fair multi-contract allocation.
- Added archetype-scaled target and escort health.
- Expanded deployment diagnostics.

## 0.10.0-rc8 — 2026-08-06

- Added a compact animated contract-completion banner and original completion chime.
- Added original distance-reactive drone rotor audio.
- Added drone deployment requests from body evidence and confirmed mission contact.

## 0.10.0-rc6–rc7 — 2026-08-06

- Added multi-contract persistence, field-intelligence reveals, elite protection allocation, physical drones, and archetype visual identity.

## 0.9.0-rc1–rc5 — 2026-08-06

- Built the native contract vertical slice, targets, social stealth, rewards, persistence, rollback, and live crash fixes.
