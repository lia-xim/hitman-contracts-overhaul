# Changelog

## 0.12.2-rc26 — 2026-08-06

- Fixed the native `getWatchBack` crash after long missions: autonomous response units are no longer inserted into close-protection follower chains before being reassigned to search/combat states.
- Corrected generic-object/Box2D coordinate semantics. The moving bullet fixture now follows the visible aim center instead of the airframe's top-left corner, which had placed the visible center on the fixture edge.
- Added a player-projectile path fallback for runtime combinations that do not expose a late-created generic-object fixture to the native raycast. It runs only after native bullet/world processing, so solid geometry remains authoritative.
- Added regression coverage proving response units remain autonomous, protected-target/bodyguard follower chains never retain them, the physical body follows the visible aim center and an actual one-frame player bullet path destroys a light drone.

## 0.12.1-rc25 — 2026-08-06

- Added a native path-grid flight-footprint check so drones steer around walls, closed doors, windows and high obstructions while remaining able to cross low cover.
- Added deterministic alternate-heading recovery instead of letting a blocked drone stop or push through a building boundary.
- Added a 0.55-second idle watchdog that invalidates stale destinations and advances the flank/search phase when a drone has stopped moving unexpectedly.
- Increased tactical movement variety with stronger tracking sway, changing standoff range and continued deterministic search relocation.
- Added regression coverage for active wall avoidance, blocked-tile containment and idle recovery without sacrificing the existing speed, world-edge and wing-separation limits.

## 0.12.0-rc24 — 2026-08-06

- Reduced all seven runtime airframes to 0.32/0.35/0.39 scout/light/heavy scale instead of the former 0.32–0.57 oversized family.
- Fixed moving-drone counterplay: runtime cameras now rebuild an explicit bullet-hitable fixture, move that Box2D body with the visible airframe every frame and expose a centered aim position.
- Added aggressive tactical contact: recent shared intelligence plus direct line of sight starts tracking immediately instead of waiting for a passing scan cone.
- Added deterministic timed search rings around the last known position and periodic left/right flank relocations during sustained contact. Each drone receives distinct angles, radii and timing while retaining world-floor snapping and the RC23 speed caps.
- Added regression proof for hitbox creation/body synchronization, centered aiming, ordinary bullet destruction, compact model scales, flank relocation and lost-contact exploration.

## 0.11.1-rc23 — 2026-08-06

- Fixed the live `drawOutline` crash (`xOff` was nil) when the player aimed at a runtime drone. Aim highlighting now delegates to the real HCO airframe sprite instead of the invisible native camera carrier.
- Reduced ordinary and aggressive flight speeds and added hard 64/108 world-unit-per-second patrol/aggressive caps so archetype doctrine can no longer create extreme pursuit bursts.

## 0.11.0-rc22 — 2026-08-06

- Replaced the single drone body with a seven-row runtime atlas: Scout plus light/heavy Pistol, SMG and Laser designs.
- Separated body heading from sensor heading. The airframe follows its velocity while a constrained gimbal tracks the player and yaws the body only after reaching its mechanical limit.
- Replaced player-centered orbiting with stable standoff formation slots, small breathing motion, last-known search sectors, varied deterministic entry points and hard world-bound clamping.
- Snapped endpoints through the native pathfinding floor grid, added 84-unit wing separation during spawn and flight, and avoided duplicate models while unused roster rows remain. Drones may cross low obstacles but no longer choose unreachable void as a destination or stack inside one another.
- Fixed the native security-camera update ordering that previously overwrote HCO's sensor angle every frame and made a locked cone sweep away from the player.
- Added armed escalation wings. Pistols and SMGs use engine-created native bullets and sounds; light/heavy lasers require uninterrupted aim and line of sight through a visible 0.9/1.4-second charge before dealing damage.
- Kept the Scout unarmed and every model destructible/disruptable. Light models take one hit; heavy models use reinforced doctrine-scaled armor.
- Enlarged the physical aimable carrier to match each light/heavy silhouette and added ricochet audio plus visible hit sparks so reinforced armor hits are legible before destruction.
- Added custom light/heavy rotor loops and laser fire assets adapted from creator-supplied source audio.
- Added deterministic coverage for the seven-model roster, world bounds, stable tracking slots, independent gimbal movement, native bullet creation and delayed laser damage.

## 0.10.0-rc21 — 2026-08-06

- Reduced the native drone airframe from the oversized first live pass to a roughly 27-pixel world footprint and rotated the source artwork by -90 degrees so its sensor nose follows the scanlight and flight heading.
- Added native-world flight presentation: subtle hover bob, offset altitude shadow, animated rotor pulses, state-colored sensor pulse and a short pixel wake opposite the current movement vector.
- Made electronic disruption authoritative for both the native camera carrier and HCO detection; a disrupted drone now flickers and cannot confirm or relay the player.
- Completed bullet destruction behavior: a destroyed drone loses its light and airframe, stops its rotor sound, creates localized crash evidence, raises the local hunt state and sends up to three available response guards to investigate.
- Kept baseline drones information-first rather than adding unavoidable hitscan damage. A separately telegraphed, counterable armed Hunter/Interceptor remains an explicit future item.

## 0.10.0-rc20 — 2026-08-06

- Replaced the external drone overlay with a registered native `hco_drone_airframe` world entity.
- Airframes now enter the same decor-quadtree visibility lifecycle used by enemies and other drawable world entities.
- Added a dedicated engine-managed sprite batch at depth 68; quadtree drawing updates its slots immediately before the native priority renderer runs.
- Kept the security-camera carrier only for physics, searchlight, obstruction and bullet interaction, with the native airframe synchronized to it.
- Added a texture-independent quadtree fallback and a diagnostic that separately reports quadtree draw activity, sprite-batch readiness, texture readiness and body count.

## 0.10.0-rc19 — 2026-08-06

- Fixed the live map-transition failure where the engine rebuilt `priorityRenderer.renderOrder` but HCO retained a stale `activeRenderMap` registration.
- The runtime now validates the actual render list every half-second and safely reinserts the drone layer whenever a map or renderer reset removes it.
- Updated the one-shot airframe diagnostic to identify RC19 explicitly.

## 0.10.0-rc18 — 2026-08-06

- Decoupled drone rendering from faction/NPC visual initialization so a temporarily unavailable goon class can no longer disable drone bodies for the whole session.
- Added an idempotent live retry for engine builds that expose `priorityRenderer` only after local mods initialize.
- Replaced the fragile wrapped draw function with a native `priorityRenderer` layer registered at the final world-space priority.
- Added a high-contrast procedural quadrotor silhouette over the flight sprite, including a texture-independent fallback.
- Reduced confirmed-contact acquisition to 0.25 seconds in aggressive mode and 0.35 seconds during patrol while retaining cone, range, and obstruction checks.
- Rate-limited repeated confirmed-sighting dispatches while keeping response-team knowledge and combat orders current.

## 0.10.0-rc17 — 2026-08-06

- Corrected RC16's install-layout diagnosis after decompiling `love.filesystem.loadMods()`: local mods explicitly load `<mod>/files/main.lua`.
- Restored the required nested `files/` archive layout and local installation.
- Moved drone drawing to the final `priorityRenderer:draw()` world pass, immediately before the camera transform is removed.
- Added a one-shot in-game diagnostic reporting renderer activity, sprite load state, and registered airframe count.
- Accepted unobstructed raycasts that reach fraction `1`, matching native combat visibility handling.

## 0.10.0-rc16 — 2026-08-06

- Fixed the release archive layout: `main.lua`, `hco/`, and `assets/` are now packaged at the mod root instead of below an ignored `files/` directory.
- Corrected manual installation instructions and explicitly require removal of stale older mod directories.
- Added package validation that fails unless root `main.lua`, `hco/config.lua`, and the drone flight sheet exist in the ZIP.
- Identified and corrected a live local installation where RC8 at the real mod root shadowed RC12–RC15 files under a nested directory.

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
