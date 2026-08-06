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

Native alert state calls `getWatchBack()` and `getWatchDistance()` on an actor returned by its leader's `getFollower()`. HCO previously inserted response units into that chain and later changed them to combat/search states that do not implement the follower interface. RC26 reserves native follower ownership for close protection; response units remain autonomous from creation onward.

The world floor exposes the same path-grid state used by native navigation. RC25 samples that grid for the center and cardinal edges of the airframe before each movement step. High obstruction, door, garage-door, climbable and window states block flight; low obstruction remains flyable. This is stronger than a screen-rectangle clamp and prevents crossing known building boundaries, while real-map testing remains necessary because the engine does not expose a single universal semantic `inside building` flag to runtime mods.

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

## Known real-engine validation boundary

The interfaces above are source-verified and exercised by mocks with their important return semantics. Only the final in-game pass can prove cross-system timing, map-specific path quality, rendered objective behavior, and AI-state interactions in a live mission.
