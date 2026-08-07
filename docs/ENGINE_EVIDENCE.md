# Engine Evidence — Intravenous 2 1.4.12HF3

This file records the game interfaces used by HCO and the decompiled `1.4.12HF3` source locations from which their behavior was verified. Decompiled game code is research evidence only and is not distributed with the mod.

## Lifecycle and process ownership

Source: `game/game.lua`

- Event declarations: `MAP_LOADED` 280, `GAME_UNLOADED` 287, `PRE_REMOVE_GAME` 288, `RETURNING_TO_MAIN_MENU` 289, `RESET_STARTED` 293, `RESET_FINISHED` 295, `LEVEL_FINISHED` 297, and `PLAYER_SET` 301.
- `PLAYER_SET` fires when the player actor is assigned at 527.
- `MAP_LOADED` fires after map setup at 3424.

HCO dynamically includes only event values that exist. Runtime state is stored on the engine-owned `playerActor` class table because the local/Workshop sandbox does not expose `_G`.

## Native objective and reward path

Source: `game/objectives/objective_handler.lua`

- `registerNewTask` at 25 creates task metatables and the native `_handleEvent` completion bridge.
- `registerNewObjective` at 133 registers objective configs.
- `getObjectiveData` at 270 and `createObjective` at 274 expose config lookup and runtime creation.
- `createObjectiveTask` at 283 instantiates the registered task.
- `removeObjective` at 307 and `getObjectives` at 396 expose active-objective lifecycle.

Source: `game/objectives/objective.lua`

- `start` uses the native HUD/start-indicator path.
- `doFinishCheck`, `attemptAutoClaim`, and `giveReward` complete and auto-claim objectives.
- `giveReward` routes fund rewards through `studio:addFunds`.
- `finish` adds the objective ID to the playthrough finished-objective list.

Source: `game/objectives/tasks/objective_task.lua`

- Native task event initialization, moving-position-marker setup, HUD tracking, completion verification, save/load, and removal behavior were used as the base-task contract.

Source: `game/objectives/tasks/neutralize_enemy.lua` and `kill_enemy.lua`

- Vanilla neutralization catches `actor.EVENTS.NEUTRALIZED`.
- Vanilla kill catches `actor.EVENTS.DIED`.
- HCO intentionally catches both in one custom task and settles only once.

Important registration detail: `registerNewObjective` replaces literal `startString = true` with `description`. HCO therefore keeps a truthy string and supplies dynamic `getStartString`/`getDescription` methods so the native start indicator remains enabled.

## Campaign persistence

Source: `playthrough_record.lua`

- `addFinishedObjective` at 318.
- `hasFinishedObjective` at 322; its result is truthy rather than guaranteed to be the Boolean `true`.
- `setPersistentMapData` at 326 serializes arbitrary map-keyed data through bitser.
- `getPersistentMapData` at 330 restores it or errors when absent; HCO therefore reads it through `pcall`.

HCO stores only serializable primitives/tables under `__hco_contract_v2::<mapID>` and never persists actor references.

## Goons, movement, knowledge, and protection

### Native actor and airframe rendering path

The RC20 airframe migration was based on a fresh decompilation of the complete rendering lifecycle, not on the prior overlay assumptions:

- `game/world/world.lua`: `world:drawActors()` delegates to `decorQuadTreeVisHandler:draw()`.
- `game/quadtree_visibility_handler.lua`: visible `QT_DRAWABLE` entities receive `enterVisibilityRange()` and `draw()`; leaving entities receive `leaveVisibilityRange()`.
- `game/actors/goon.lua`: moving enemies reinsert themselves into both the actor and render quadtrees; `goon:draw()` updates the avatar at its current draw position.
- `game/visual/avatar.lua`: entering visibility allocates native sprite-batch slots and `avatar:draw()` updates those slots immediately before priority rendering.
- `engine/spritebatchcontroller.lua`: `newSpriteBatch`, `allocateSlot`, `increaseVisibility`, `updateSprite`, and `deallocateSlot` provide the complete native batch lifecycle.
- `game/main_renderer.lua`: `world:drawActors()` runs while the world camera is active, immediately before `priorityRenderer:draw()`.

HCO now registers `hco_drone_airframe` through `objects.registerNew`, inserts each instance into the world decor quadtree, and gives visible instances a slot in the dedicated `hco_drone_roster_airframes` sprite batch. The security-camera object remains a sensor/physics carrier only. No global draw-function wrapper is used for drone bodies.

### Native drone sensing, projectiles and damage

Source: `game/objects/security_camera.lua`

- `setLightAngle` updates `curViewAngRad`, the physical object angle and shadow buffer.
- `update` normally sweeps toward its own `targetAng`. RC22 therefore invokes native maintenance first and writes the HCO gimbal angle afterwards; reversing this order caused the live cone to sweep away from an acquired player.
- `runGenericRaycast`, the player fixture and camera FOV/range are used as the firing authorization boundary. A wall or intervening fixture cancels tracking attacks.
- `AIMABLE`, `DISRUPTABLE`, bullet/melee physics categories and the native light buffer remain on the engine-owned carrier.

Source: `game/weapons/weapon.lua`

- `weapons:instantiate(id)` initializes an isolated weapon and bullet buffer.
- `weapon:createBullet(x, y, angle, height, verticalAngle, speed, shotDelta)` sets the weapon owner as firer, activates the projectile and adds it through `game.addBullet`.
- `getBulletSpeed`, `getFireSound`, `getDamage` and `remove` provide projectile configuration, native audiovisual identity and cleanup.

Source: `game/actor.lua`

- `actor.DAMAGE_TYPE.BULLET` is `1`.
- `takeDamage(damage, damageType, attacker, inflictor)` passes through normal health/state/death handling.

RC22 ballistic drones use instantiated `p320`/`mp5` native bullets with a living response actor as attacker. Lasers use `takeDamage` only after their visible, uninterrupted charge and verified raycast. This preserves normal God Mode/damage hooks and avoids unattributed magical kills.

### Runtime camera outline contract

`genericObject:drawOutline()` unpacks five values from `getDrawPosition()` and performs arithmetic on the returned `xOff`/`yOff`. A runtime-created camera has no map-finalized sprite `quadStruct`, while HCO intentionally renders its body through a separate decor airframe. The RC22 carrier returned only `x,y`, producing the live `xOff=nil` traceback when the player aimed at it. RC23 overrides `drawOutline` and `rawDraw` on each carrier and draws the airframe's current atlas frame directly in the native outline pass.

### Moving camera physics contract

`entity:setPos()` reinserts aimable objects into the aim quadtree, but `security_camera:setPos()` does not move its Box2D body; fixed map cameras never need that behavior. `entity:setSize()` also changes only logical width/height, not `hitboxW`/`hitboxH`. RC24 rebuilt and moved the inherited bullet-hitable fixture, but live RC25 evidence proved one more engine distinction: generic-object `x/y` is top-left while Box2D rectangles are centered at their body position. Moving the body to raw `x/y` therefore placed the visible center on the fixture edge. RC26 moves the body to `getAimPos()`, preserves the native camera category and additionally checks the already world-processed player-bullet segment when a late-created fixture is not returned by the runtime raycast.

The native bullet exposes both `getDamage()` and `getArmorPenetration()`; the shipped Model 700 reports `damage=65` and `armorPenetration=11`. RC27 uses those interfaces only to collapse a three-point heavy to the requested two-hit floor. It does not import actor-health scaling, create a parallel hit-point system or allow any heavy drone to skip its first surviving impact.

The drone atlas uses 96-pixel cells, but its rendered airframes rotate continuously. A 38-unit Heavy rectangle covered the central hull while visible diagonal rotors could extend outside both the fixture and the former fallback circle. RC28 uses 44/48/54-unit Scout/light/heavy targets and derives fallback reach from `96 * renderScale * 0.72`. It also checks the carrier body and fixture every update and calls the engine-owned `initHitbox` path again if either was destroyed or invalidated. Destruction leaves the engine-owned carrier path, then animates the registered decor airframe toward a computed landing point before retaining it as a non-aimable wreck; no HUD overlay or parallel actor class is introduced.

RC29 does not introduce a parallel perception service. Drone player sensing reuses the carrier's current world-space cone, `runGenericRaycast`, the social-stealth module's published behavior risk and the existing security knowledge hand-off. Body evidence uses the same cone/raycast against engine NPC objects and shared contract evidence memory; disrupted carriers return before this scan. This keeps walls, native player states, visible equipment, radio/security escalation and uniform compromise authoritative in their existing modules.

RC30 removes the former optimistic player-sight fallback: missing or failed `runGenericRaycast` data now denies detection and weapon authority. The carrier must also retain its synchronized native `BULLET_HITABLE` fixture and registered visual airframe in the same update. This makes the attack path fail closed whenever the player cannot receive reciprocal physical counterplay.

Difficulty tuning reads the active game-owned `game.difficulty` ID and, for Custom, its exposed enemy-vision and player-damage multipliers. Values are copied into a bounded per-contract snapshot before assignment. No difficulty object is mutated, and unknown IDs fall back to Normal. A twelve-airframe cross-contract ceiling and two-Heavy/two-Laser composition limits bound the decor batch, native carriers, loop audio and attack updates independently of map population.

Native alert state calls `getWatchBack()` and `getWatchDistance()` on an actor returned by its leader's `getFollower()`. HCO previously inserted response units into that chain and later changed them to combat/search states that do not implement the follower interface. RC26 reserves native follower ownership for close protection; response units remain autonomous from creation onward.

The world floor exposes the same path-grid state used by native navigation. RC25 samples that grid around the airframe before each movement step. High obstruction, door, garage-door, climbable and window states block flight; low obstruction remains flyable. RC30 additionally uses the engine's actual roof classification: `envController:setupRoofTiles()` marks `floorTileGrid.tiles[index].roofObstructed`, exposes readiness through `getRoofReady()` and point queries through `getPosUnderRoof()`. The nine-sample airframe footprint rejects roofed cells for spawn, destination, movement and recovery rather than guessing interior status from patrol routes or rectangles.

Source: `game/world/world.lua`

- `world:getSize()` returns the real map width and height. RC22 clamps every aerial entry and destination to a 48-unit interior margin.

Source: `game/actors/goon.lua`

- `getRadio` 1636.
- `receiveSightingData` 2624.
- `increaseDetection` 3147.
- `setSightPos` 3195.
- `setDestPos` 3297 and `getDestPosObj` 3319.
- `setExperienceLevel` 3428 and `maxOutHealth` 3453.
- `setActivePatrolRoute` 3707, `setPatrolRouteIndex` 3733, `getPatrolRouteIndex` 3737/3821, and `getActivePatrolRoute` 3745.
- `getKeycard` 4254.
- `setSeenBody` 4408.
- `getEnemyInSight` 6017.
- Native body interaction list at 7281.

Source: `game/actor.lua`

- `setAnimVariant` 269.
- `setHealth`/`getHealth` 637/641.
- `setMaxHealth`/`getMaxHealth` 661/667.

HCO uses native destinations and patrol routes. It never teleports a target. Guard experience, health, state, route, and follow-chain changes are recorded and restored during cleanup or transactional rollback.

## Radios and interruptible identity reports

Source: `game/items/radio.lua`

- `disrupt` 54, `isDisrupted` 64, `isOpen` 83, `open` 87, and `close` 96.
- Radios begin closed and close automatically when disrupted.

HCO opens the real body-investigator radio for a 2.5-second report, closes it only if HCO opened it, and cancels global disguise compromise if the carrier is disrupted, killed, or made unconscious.

## Player appearance, behavior, and credentials

Source: `player_controller.lua`

- `playerActor.PLAYER = true` at 10.
- `getOfflimits` 1534.
- `addKey` 1700 and `hasKey` 1721.
- `getWeaponConcealed` 3129.
- `isSprinting` 4021 and `getSprinting` 4059.
- `getAiming` 4650.
- `getWeapon` 6236.

HCO wraps only detection/off-limits calculations and player-fired-weapon notification. It does not hook mouse buttons, action bindings, firing, weapon handling, or input dispatch.

## Existing security cameras

Source: `game/objects/security_camera.lua`

- `calculateDetectionIncrease` 313.
- `disrupt` 215.
- `breakCam` 744.

HCO scales existing camera detection for valid disguises and records camera disruption/destruction as security evidence. It does not claim to add physical thermal-camera or drone entities in `0.9.0-rc2`.

RC31 mirrors `security_camera:breakCam()` but strengthens it for runtime drone carriers: `broken` is set before callbacks, queued HCO weapon/detection state is cancelled, the carrier is explicitly removed from the dynamic list, and the owned light buffer is made non-casting/non-renderable, removed, stopped and destroyed before its reference is cleared. The independent native-world airframe then owns only the generated damage/wreck animation.

## RC32 renderer and projectile timing correction

Sources: `engine/spritebatchcontroller.lua`, `game/bullet.lua`, `game/weapon.lua`

- `controlledSpriteBatch:increaseVisibility()` registers the batch with `priorityRenderer`; `decreaseVisibility()` removes it when visibility reaches zero. RC32 therefore gives wrecks a distinct batch/visibility count rather than releasing the intact slot and relying on a direct texture draw from the decor callback.
- `weapon:createPlayerBullet()` calls `bul:update(shotDelta)` before `game.addBullet(bul)`. A fallback that only reconstructs `bullet.x - travel * dt` after list insertion can miss the complete first flight segment.
- Every bullet records its muzzle through `setShootPos(x, y)` before that update. RC32 uses this native origin for the first sweep, then stores a previous point per bullet and drone.
- Bullets come from `objectBuffer:retrieve()` and return through `store()`. The native shot number/muzzle identity resets HCO's consumed-hit and sweep tables when a pooled bullet object begins another player shot.

## RC33 decor versus dynamic update ownership

The live RC32 screenshot proved the wreck batch was durable but froze on its first frame. This separates persistence from animation ownership: `security_camera:setBroken(true)` removes the destroyed carrier through `game.removeDynamicObject(self)`, while the independent airframe remains in the decor quadtree. The moving carrier previously called `airframes.sync()` every dynamic update; after destruction that source of reinsertion and frame refresh no longer exists. RC33 advances crash time and batch transforms from the already persistent HCO contract update before deployment early-returns, while limiting decor reinsertion to the finite effects window.

## RC39 native close-recognition handoff evidence

RC38 correctly prevented an uninformed native alert state from manufacturing player identity, but the live result revealed the other side of that boundary: a red close-range reaction could remain only presentation because every patched `onSightHitPlayer` invocation was still suppressed while behavior risk stayed below one. The observer spoke an alert line but never received authoritative enemy knowledge, so combat waited for the player to attack first.

RC39 makes proximity an explicit identity source rather than reopening the old arbitrary instant-detect path. The hard 72-unit boundary and timed 150-unit band both require current native `updateVisionData`, `isWithinView` and `runGenericRaycast` success. Historical `seenPlayer`, a wall, or an observer facing away cannot advance scrutiny. Progress is stored by observer and decays while contact is broken.

After recognition, HCO marks only that observer's uniform group as locally compromised, sets its player detection to full and invokes the already-instantiated state object's sight callback. Because the local knowledge now exists, RC37's wrapper deliberately passes through to the saved original callback. Native suspicion/alert code therefore retains ownership of `attemptStartleDetection`, off-limits confrontation, surrender and `goToCombat`. A real radio on the recognizing actor may subsequently propagate global compromise.

## RC40 drone patrol and network-alarm evidence

The live RC39 report separated an intact/aimable drone from a useful active patrol: several airframes could be destroyed normally but remained stationary, did not fire and did not visibly join combat. The movement loop showed that every non-tracking destination was refreshed after 1.1 seconds even though patrol speed is capped at 64 world units per second and ordinary sectors are hundreds of units apart. A drone could therefore reverse toward a new deterministic point before reaching the old one. `sectorDestination` also returned immediately after one authored point; if that point was roofed, collapsed to the current cell or otherwise invalid, it never tried the remaining sectors or its outdoor fallback.

RC40 retains a non-tracking destination until arrival or an explicit tactics/watchdog transition. The destination owner now exhausts every authored sector and then twelve deterministic outdoor ring candidates, rejecting points too close to the current airframe. If geometry truly offers no travel point, `updateAim` advances a continuous patrol sweep angle so the body eventually rotates through the complete circle and the existing cone/raycast remains authoritative.

The root runtime already owns all active contract contexts in `state.contracts`; RC40 uses that existing ownership rather than creating a global overlay. `notifyConfirmedSighting` writes the same exact last-known position and PRESSURE/AGGRESSIVE state into each context, invalidates every live wing's stale destination and hands each response actor through its native sight/combat methods. Searchlights remain red for the network alarm, while `droneWeapons.update` still receives `canAttack=true` only from that individual carrier's valid outdoor footprint, hitbox and completed player raycast. Native projectile attribution searches living HCO response actors across the same root network before declining to fire.

## RC41 barrier-flight, target-awareness and body-action evidence

The native floor/roof evidence can classify both endpoints but offers no flying pathfinder. RC41 therefore keeps ordinary outdoor steering authoritative and adds only a bounded transition after sustained blockage: sampled intermediate cells may be obstructed for at most 96 units, the total hop is at most 144 units and the landing must pass the same complete outdoor footprint check used for armed readiness. While `hcoTransit` exists, the inherited security-camera update is not called, body/player scans are skipped and `droneWeapons.update` receives no authority. This preserves the native camera carrier and synchronized hitbox without allowing one-way perception/fire through geometry.

The target remains a real Goon using its original patrol route and native movement states. RC41 samples route progress and reissues that existing route at a new index after nine stationary seconds; it does not teleport the actor or introduce parallel movement. Unsuppressed player fire already enters through `weapons.EVENTS.FIRED`; RC41 records a location-only incident for nearby principals before the established three-shot full-response threshold, leaving actor identity unset until normal sight/radio/drone evidence confirms it.

The Goon interaction list is still the sole disguise UI owner. RC41 deterministically places takeover/restoration at the first two list positions, re-enumerates power-of-two action IDs and refreshes cached body menus through the existing hooks. The persistent identity shimmer reuses the already installed `playerActor:postDraw` world hook; restoring clothes writes through the same campaign disguise persistence path.

## RC42 drone identity and navigation evidence

The native `security_camera:update` owns sweep/disruption/light-buffer upkeep but does not itself call `monitorCamera`; HCO's explicit cone/raycast and detection accumulator remain the player-contact authority for runtime drone carriers. The RC41 loop nevertheless had two semantic leaks: `AGGRESSIVE` forced disguise acquisition to at least `0.72`, and any recent `lastKnown` point enabled cone-less tracking. A location-only gunshot/casualty escalation could therefore identify a clean disguise in less than a second even while nearby Goon observers correctly remained at suspicion.

RC42 records confirmed knowledge against the current appearance token and makes location alert, visual suspicion and actionable identity separate values. Long-range clean cover can fill only an amber 42% sensor cap; only real cone/raycast contact inside the 155/205-unit scrutiny band may cross to confirmation. A new actor variant/acquisition timestamp clears each drone's stale detection grace, tracking slot, recent confirmation and weapon token. The existing weapon controller remains unchanged and receives authority only when that same current token has been locally confirmed.

The movement trace also showed why the physical-idle watchdog could miss a visually stuck drone: alternating tangent choices produced non-zero per-frame displacement without reducing destination distance. RC42 retains one deterministic wall-follow side for a blocked episode and separately samples route distance. Failure to improve by seven units across 2.4 seconds invalidates the route and changes the flank/search approach; no teleport or new through-building attack surface is introduced.

## RC38 native follower-state and threat-knowledge evidence

The live `getWatchBack` traceback resolves to the base game's alert-state `advanceFollowerInstructions(follower, dt)`. That method fetches `follower:getState()` and unconditionally calls `getWatchBack`, `setWatchBack`, `getWatchDistance` and `setWatchDistance`. These methods belong to following states; combat, fear and other ordinary Goon states do not implement that contract. `goon:setFollower` and `goon:getFollower` only write/read a raw actor reference, so a leader can retain a follower after that follower changes state.

RC38 preserves native following instead of replacing it. HCO records `_hcoFollowLeader` only after `goToFollow(..., "goon_idle_following")` produced a compatible state and the leader really owns that follower. Its class-level `getFollower` wrapper checks only HCO-owned links and clears both sides before returning when the current follower state lacks any required watch method. Vanilla-owned follower links are returned unchanged.

The same live pass distinguished visible alert UI from identity knowledge. Native Goon alertness and best-hunch data can describe suspicion or a place to investigate without proving that an observer recognized a disguised actor. RC38 therefore allows those values to become HCO target threat only when the observer already has direct enemy sight or local/global identity compromise. Explicit sound, casualty, body, camera, drone and radio evidence continue through their dedicated security paths.

## RC37 native disguise bypass evidence

Source: `game/actors/states/suspicion.lua`

- `onSightHitPlayer` 448–474 has an instant-detect branch that calls `increaseDetection(player, 1)` and then enters off-limits/combat handling without checking the scaled detection result.

Source: `game/actors/states/alert.lua`

- `onSightHitPlayer` 641–657 can call `goToCombat(true)` at close range before its ordinary `advanceDetection` branch.

Source: `game/actors/states/investigate_body.lua`

- `onSightHitPlayer` 295–309 calls `setEnemyInSight(true, player)` before either its instant or progressive detection branch and may then enter combat.

Source: `game/actors/states/combat.lua`

- `onSightHitPlayer` 1696–1748 refreshes player-specific sight while combat weapon logic depends on `goon:getEnemyInSight()`.

Source: `game/actors/goon.lua`

- `setEnemyInSight` 5835 records persistent `seenPlayer`, maximizes vision range and writes player-specific `enemiesInSight` knowledge.
- `getEnemyInSight(target)` 6017 reads that target-specific map; `getSeenPlayer` 6025 is historical memory rather than proof of current contact.

RC37 patches instantiated state objects rather than replacing the global state classes, preserving every non-player and no-disguise path. It additionally guards the Goon enemy-sight setter as a fail-closed integration boundary and rebinds only player-specific memory when an identity changes.

## Known real-engine validation boundary

The interfaces above are source-verified and exercised by mocks with their important return semantics. Only the final in-game pass can prove cross-system timing, map-specific path quality, rendered objective behavior, and AI-state interactions in a live mission.
