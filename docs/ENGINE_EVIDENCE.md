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
