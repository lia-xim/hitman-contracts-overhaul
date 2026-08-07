# Automated Test Report — 0.14.13-rc47

## RC47 native interaction-quadtree recovery

- The runtime fixture now models the selector's real spatial prerequisite: a direct native `_die()` drops equipment but deliberately leaves the body outside the interaction quadtree.
- HCO must restore that fallen body to the current world's native interaction tree before cached action reconciliation or object priority can matter.
- The regression requires the body to become interaction-enabled, exist in the selector tree, expose takeover first and retain exactly one tree insertion after periodic refresh.
- Current-world ownership is verified through `interactQuadTree`; a stale checkpoint flag pointing at a replaced tree no longer counts as a selectable body.
- All seven LÖVE suites must pass against `0.14.13-rc47`; archive and exact local-install parity are recorded in Final results after packaging. Live confirmation remains mandatory.

## RC46 native object-priority and hook-recovery correction

- The runtime fixture proves an eligible unused uniform returns interaction priority `45`, above native `VHIGH=40`, while a consumed body immediately returns to its vanilla priority.
- A render-only menu read starts from a deliberately incomplete cache with the disguise bit already set and must still restore takeover as its first visible action using the active player context.
- The fixture replaces both critical Goon methods after bootstrap without replacing the class or action registry. The periodic verifier must restore both hooks, recover takeover and retain body-first selection.
- The Windows runner now cleans only newly spawned HCO smoke-test LÖVE processes after the suite, preventing an orphaned test harness from presenting `HCO_SOURCE_ROOT is required` outside the intended runner.
- All seven LÖVE suites pass against `0.14.12-rc46`; archive and exact local-install parity are recorded in Final results after packaging. Live confirmation remains mandatory.

## RC45 native selector handoff, stable IDs and body-marker correction

- The runtime fixture now reproduces the complete native selector sequence: `getInteractOptions(player, true)` validates an eligible body, followed by the render-only `getInteractOptions(nil, false)` call used by `setInteractionData`. The second call must preserve takeover as the first visible action.
- Native action objects retain their original slots and IDs. HCO takeover/restore append with the next free power-of-two IDs, while only the returned per-body list is reordered for first-visible presentation.
- A lifecycle regression removes both HCO class actions, runs the periodic repair and requires exactly one restored pair while both original native IDs remain unchanged.
- The interaction callback no longer owns `postInteract`; the fixture models the selector's one native post-action refresh and rejects the former double-refresh behavior.
- Visual coverage renders the new eligible-body stitch marker separately from acquisition, identity-check and compromise effects.
- All seven LÖVE suites pass against `0.14.11-rc45`; archive and exact local-install parity are recorded in Final results after packaging. Live confirmation remains mandatory.

## RC44 authoritative cached body-menu correction

- The runtime fixture now inherits `getInteractOptions`, `updateInteractionList`, `addInteractionOption` and `postInteract` from the registered Goon class, matching the engine boundary wrapped by HCO instead of attaching simplified methods to each fake instance.
- A regression first creates an eligible dead body, then deliberately removes HCO's visible takeover option while retaining the current registration generation and takeover action bit. It queries the native selector with `update=false` and requires takeover to be restored in that exact returned list.
- Query-time reconciliation removes stale/duplicate HCO action objects, preserves native ID order and synchronizes only HCO's action bits. It does not replace the native body selector or its unrelated options.
- All seven LÖVE suites pass against `0.14.10-rc44`; archive and exact local-install parity are recorded in Final results after packaging. Live confirmation remains mandatory.

## RC43 native patrol, combat-continuity and interaction-lifecycle correction

- Runtime coverage models the native Goon patrol callback creating a destination/path and proves initial target activation plus the nine-second recovery preserve that path rather than clearing it. The complete close-protection detail is asserted as one exact target-to-guard chain because the engine owns only one follower slot per leader.
- Drone coverage confirms an already exposed/current appearance can be reacquired through fresh unobstructed LOS after the shared last-known report becomes stale. Location alert alone still cannot identify clean cover.
- Weapon coverage kills both the selected response guard and principal after an initial shot, then proves the intact drone fires again through its stable valid native attribution proxy.
- Disguise coverage simulates a mission-restart body with stale action bit `1` but no visible HCO option. The periodic native Goon-list verifier rebinds missing actions and the registration generation rebuilds the body's cached menu so takeover returns.
- All seven LÖVE suites pass against `0.14.9-rc43`; archive and exact local-install parity are recorded in Final results after packaging. Live confirmation remains mandatory.

## RC42 disguise-aware drone identity and navigation-progress correction

- Drone coverage proves that an alarmed drone observing a clean disguise from 300 units may build only capped amber suspicion: it cannot track, confirm, publish a network sighting or fire.
- The same drone must bring the disguised player inside its 205-unit alarm scrutiny range and maintain real cone/raycast contact before it progressively confirms that exact appearance token. A compromised or overt identity still follows the immediate hostile path.
- A confirmed sighting stores the current identity token across the HCO security network. Changing or restoring clothing invalidates each drone's stale local lock, tracking slot, sight grace and weapon authorization rather than carrying hostility into the new appearance.
- Disguise takeover and checkpoint restoration publish their reduced behavior risk atomically, closing the one-update-frame window in which a fresh disguise could still look fully exposed to a drone.
- Flight coverage proves a blocked drone keeps one deterministic wall-follow side instead of oscillating. A separate moving-without-progress fixture verifies that failure to reduce destination distance for 2.4 seconds forces a new route/search or flank approach.
- All seven LÖVE suites pass against `0.14.8-rc42`; archive and exact local-install parity are recorded in Final results after packaging. Live confirmation remains mandatory.

## RC41 exterior-transition, principal-awareness and identity-readability correction

- Flight coverage models both an indefinitely wide blocked region and a narrow wall between valid outdoor cells. The wide span remains impassable; after the steering delay the narrow span creates an eased transition and lands beyond the barrier on a verified footprint.
- Drone orchestration injects an active transition beside the player and proves acquisition/sight grace reset while the inherited camera path and HCO weapon authority remain unavailable.
- Runtime coverage holds a protected target stationary in `ROUTINE` for nine seconds and proves the controller advances its original native patrol route. A single nearby audible player shot produces cautious movement without assigning player identity; confirmed threat still escalates to the established flight/shelter path.
- Historical RC41 coverage placed takeover/restore at class positions one/two with IDs `1`/`2`. RC45 supersedes that unsafe registry mutation: existing IDs stay fixed, HCO appends unused IDs and the returned visible menu still presents takeover/restore first.
- All seven LÖVE suites pass against `0.14.7-rc41`; archive and exact local-install parity are recorded in Final results after packaging. Live confirmation remains mandatory.

## RC40 patrol continuity and shared-alarm correction

- Drone coverage forces an authored patrol sector to collapse onto the current airframe position and proves the selector creates a distinct deterministic fallback destination instead of remaining still.
- A second update proves the distant patrol destination remains identical until arrival instead of being replaced by the former 1.1-second timer.
- A simulated second contract context proves one confirmed sighting changes every wing to `AGGRESSIVE`, clears stale drone routes, writes shared sighting knowledge and sends a native response guard into actionable combat.
- Presentation coverage proves an alarmed wing retains its red search color even when a particular drone does not currently have an unobstructed shot. Existing strict-geometry assertions continue to prove that color/network state alone grants no weapon authority.
- All seven LÖVE suites pass against `0.14.6-rc40`; archive and exact local-install parity are recorded in Final results after packaging. Live confirmation remains mandatory.

## RC39 consequential close-inspection correction

- Runtime coverage keeps a calm armed disguise below native suspicion success at medium distance, then gives the same observer real FOV/raycast contact at 60 units. That point-blank sight establishes observer-local compromise, sets native enemy knowledge and executes the original sight/combat callback.
- A separate 120-unit case proves 250 ms of proximity does not expose the player, while sustained visibility completes role-scaled scrutiny and hands control to native combat.
- Local exposure uses a distinct `exposed` world effect and does not globally compromise the uniform by itself. Global propagation still requires the observer's real radio report to complete.
- All seven LÖVE suites pass against `0.14.5-rc39`; archive and exact local-install parity are recorded in Final results after packaging. Live confirmation remains mandatory.

## RC38 follower-state and identity-knowledge correction

- The runtime fixture now models follower-only methods on `goon_idle_following` instead of incorrectly placing them on every Goon state. It transitions an HCO close guard to `goon_combat`, exercises the native leader lookup and proves the stale link is removed before `advanceFollowerInstructions` can call missing `getWatchBack`/watch-distance methods.
- Native alert state and a fresh native hunch are injected into the protected target while a clean disguise is active. The security director retains zero target-specific threat and the target remains in `ROUTINE`; explicit security evidence then still transitions it to safety.
- Calm social cover is capped at 39%, below native suspicion's 40% success boundary. The separate timed colleague check can still cross the 55% identity/radio threshold.
- All seven LÖVE suites pass against `0.14.4-rc38`; archive and exact local-install parity are recorded in Final results after packaging. Live confirmation remains mandatory.

## RC37 native AI-state identity correction

- Installed-engine tracing identified four direct sight paths—suspicion, alert, body investigation and combat—that could bypass scaled detection and create hostility at close range.
- The runtime fixture now gives Goon state instances a native-style `onSightHitPlayer` that raises detection, marks the player in sight and enters combat. A calm fresh disguise suppresses all three consequences.
- A separate regression calls native `setEnemyInSight(true, player)` directly and proves the hard observer-knowledge boundary rejects it.
- The same state executes its original hostility path when the player directly aims, proving the interception is conditional rather than disabling AI combat.
- A pre-disguise observer seeded with full detection, `seenPlayer`, a vision target and a player-specific sight entry is cleanly rebound when it did not witness the takeover. A real current AABB/FOV/raycast witness instead becomes locally compromised.
- All seven LÖVE suites passed against `0.14.3-rc37`; archive and exact local-install parity passed. Live confirmation remained mandatory.

## RC36 observer-local identity correction

- Held weapon model/family, drawn/holstered state and ordinary reload now contribute zero disguise risk for every identity tier.
- Runtime regressions distinguish stale `getSeenPlayer()` memory, an unobserved shot and a current native-vision/raycast witness: only the current witness is compromised until a valid radio report propagates it.
- Global combat no longer grants unrelated observers player identity. Loud-fire escalation records a search position with no player actor and never marks response guards as already seeing the player.
- Protection damage and casualties use the same position-only native alert/search path until sight or communicated evidence confirms contact.
- All seven LÖVE suites pass against `0.14.2-rc36`; archive and exact local-install parity pass. Live confirmation remains mandatory.

## RC35 armed-cover and native body-sight correction

- Installed-game tracing confirms the player's native `holster_weapon` command and `getWeaponConcealed` state; the user's current binding is `H`.
- Weapon regressions prove that a visible matching Security weapon family and a different ordinary Security family both remain below immediate exposure, while active native combat still restores full detection.
- Same-unit, elite and close-protection multipliers remain stronger than unrelated scrutiny but are reduced from RC34's abrupt first live result.
- HCO's distance-only corpse scan was removed. Body propagation now begins at the existing Goon `setSeenBody` hook; drone body evidence still requires its strict cone and completed geometry raycast.
- All seven LÖVE suites pass against `0.14.1-rc35`; live confirmation remains mandatory.

## RC34 native identity and social-stealth rebuild

- Engine tracing proved that appending a Lua table was insufficient: Goon actions are assigned power-of-two IDs by `entity:enumerateActions`, while each body can retain a cached `_interactionList` and action bitmask. The runtime now owns both boundaries and refreshes them after death, choke, falling and body drop.
- Runtime coverage constructs a body interaction cache before HCO loads, then reaches the new identity action through `getInteractOptions(..., true)`. It proves ID `4`, tracker `8`, successful `postInteract`, source consumption and persistence across reload.
- The death fixture strips its live weapon/keycard inside `_die`; the test still acquires the correct SECURITY identity and credential, proving HCO captured source data before the native drop path.
- STAFF, SECURITY and ELITE SECURITY switching, keycards, keychains, original appearance, bloodied condition, reload/lock-breaking exposure, same-unit radio checks, local/global body knowledge and drone source compromise pass.
- Visual coverage proves the player draw chain renders a persistent matching faction insignia and separate acquisition, identity-check and compromise world-space primitives without a detached HUD layer.
- All seven LÖVE suites pass against `0.14.0-rc34`; live confirmation remains mandatory.

## RC33 first-frame freeze correction

- Live evidence proved RC32's dedicated batch retained a destroyed drone but left it on the initial damage frame after its native sensor carrier exited the dynamic-object list.
- The airframe harness now advances the persistent contract tick without requiring another decor draw. It proves the registered wreck slot changes from frame one to frame two and later to the final fourth frame.
- Crash time, batch transforms and atlas selection are updated before drone-deployment early returns; quadtree reinsertion is bounded to the tumble/impact/smoke window rather than becoming permanent per-frame work.
- All seven LÖVE suites pass against `0.13.2-rc33`; live confirmation remains mandatory.

## RC32 durable wreck renderer and free-fire correction

- Engine-projectile tracing confirms player weapons call `bullet:update(shotDelta)` before `game.addBullet()`. The fallback now begins its first per-drone sweep at the native `shootX/shootY` muzzle point, so a visible Heavy edge crossed during that initial advance is not lost.
- Drone coverage proves an unaided Heavy rotor-edge shot registers even when reconstructing only the latest frame would no longer cross the target. Later segments use independent per-bullet/per-drone previous positions, and a pooled bullet reused for another shot resets stale hit/sweep state.
- Native-airframe coverage proves destruction immediately releases the intact slot, allocates a dedicated wreck slot, registers the wreck batch with the priority renderer, advances the tumble and retains the fourth-frame slot after landing.
- All seven LÖVE suites pass against `0.13.2-rc32`; payload verification checks both 384×672 runtime atlases and all four audio profiles.
- Source, delivery and local installation contain the exact same 42 files with zero SHA-256 mismatches. The evidence collector reports 32/32 Lua files with zero mismatch, an empty current debug log and no running game process; the newest stored crash log predates RC32.

## RC31 terminal destruction and wreck-state correction

- A second exact 384×672 atlas now covers four destroyed frames for each of the seven live roster rows. The source sheet and exact built-in ImageGen prompt are retained under `artwork/`.
- Native-airframe coverage proves impact switches from the intact shared batch to `drone-wreck-atlas.png`, releases the stale intact slot, moves and tumbles through damaged frames, lands on frame four, persists as a wreck and no longer exposes an aim outline.
- Drone coverage seeds a queued burst, Laser charge, aim target, detection/tracking state and active light buffer immediately before a registered fatal hit. The post-hit assertion proves every weapon/perception value is terminally cleared.
- Light cleanup coverage proves casting, normal rendering, forward rendering and buffer effects are disabled; the buffer is removed, stopped, destroyed exactly once and its carrier reference is cleared.
- All seven LÖVE suites pass against `0.13.2-rc31`. Payload verification also checks that both runtime atlases exist at the required dimensions.
- Local installation contains the exact 42-file source payload. The evidence collector reports 32/32 Lua files with zero mismatch, an empty current debug log and no running game process; the newest stored crash log predates RC31.

## RC30 indoor-spawn and one-way-combat blocker correction

- Engine tracing identified `envController:getRoofReady()`, `getPosUnderRoof()` and `floorTileGrid.tiles[index].roofObstructed` as the authoritative indoor/outdoor contract. Walkable patrol points are no longer treated as proof of an exterior flight cell.
- Flight coverage proves a roofed but pathable tile is rejected and deterministically migrated to a fully clear exterior footprint. Movement retains low-cover traversal while rejecting roofs, walls, doors, windows and map boundaries.
- Deployment coverage proves requests remain queued until roof data is finalized and that a carrier without a physical bullet target never becomes active.
- Perception coverage proves an absent native geometry trace cannot produce detection, tracking or weapon state.
- Runtime coverage destroys a carrier body/fixture, forces repair to fail, and proves the drone becomes inert and safely retires instead of continuing one-way fire.
- Live approval remains mandatory on the reported map for zero indoor spawns, reliable destruction of every exterior Scout/Light/Heavy model and wall-blocked ballistic/Laser attacks.

## RC29 production-candidate balance, perception and presentation

- Lua syntax/payload verification passes for all 32 Lua modules and seven drone atlas rows plus four adapted audio profiles.
- Runtime coverage proves Easy lowers threat/response/drone pressure and slows acquisition, True increases pressure/reward, and Custom derives bounded tuning from native vision/damage settings.
- Five close bodyguards remain structural while only autonomous response demand scales with difficulty.
- Roster coverage enforces a maximum of two Heavy and two Laser models per contract; orchestration enforces twelve active airframes globally across simultaneous contracts.
- Drone coverage proves a calm valid disguise slows routine identity acquisition without preventing it, suspicious behavior restores full acquisition, and aggressive security retains a hard scrutiny floor.
- A dead/unconscious NPC inside the real sensor cone and unobstructed raycast is reported once through shared evidence memory. Runtime coverage proves discovery of the stolen-uniform source globally compromises that identity.
- Airframe coverage retains every RC28 hit/crash assertion while adding family accents, evidence pulse, true Laser charge progress and damage-state propagation.
- Internal render diagnostics are disabled in the release configuration. Live approval remains required for map-specific balance, effect mix, body concealment and full multi-contract performance.

## RC28 complete-silhouette hits and crash presentation

- The physical Scout/light/heavy target sizes are now asserted at 44/48/54 world units, matching the complete rotated silhouettes rather than the old Heavy hull-sized center.
- A Heavy rotor-edge projectile path at 25.5 world units from center registers and removes armor through the post-world collision fallback.
- The fixture watchdog test destroys a live carrier body, advances one update, and proves that a new centered body/fixture is created before combat continues.
- Airframe coverage proves a destroyed drone travels and rotates during its light/heavy-specific tumble, leaves the active-airframe count, enters the wreck count, changes to a dark landed tint and is removed on context cleanup.
- Lua syntax, runtime, boot isolation, drone orchestration, seven-model behavior, native airframe, faction visual and feedback suites all pass. Live approval remains required for hit feel, crash timing/scale and map-specific landing readability.

## RC27 fragile-drone balance and impact readability

- Live RC26 evidence confirms the player-projectile counterplay now works for small drones, but heavy drones appeared immune and registered no readable impact.
- Roster coverage now enforces one armor point for every light model and a hard two/three-point range for every heavy model, including doctrine scaling.
- Runtime coverage proves an ordinary projectile removes one heavy armor point while a Model-700-class `65 damage / 11 penetration` projectile removes two without bypassing the required first surviving impact.
- Airframe coverage proves surviving hits propagate a 0.42-second impact state and render nine sparks plus two/three armor pips instead of the former five tiny pixels.
- Live boundary: RC27 still requires confirmation that the user's high-caliber weapon produces the expected obvious flash/ricochet and that all visible heavy models fall within the strict two/three-hit window.

## RC26 live blocker correction

- Live RC25 evidence on `iv2_map6` produced `attempt to call method 'getWatchBack' (a nil value)` after a long mission and still did not allow the player to shoot down a drone.
- Engine tracing identified two independent causes: response units remained referenced as native followers after HCO moved them to states without the follower interface, and the generic-object Box2D body followed top-left `x/y` instead of the visible aim center.
- Runtime coverage now proves response units never enter or remain in protected-target/bodyguard follower chains.
- Drone coverage proves body/aim-center parity and destroys a light drone through an actual one-frame player-projectile segment rather than directly invoking the damage callback.
- The fallback observes bullets only after native world collision processing; a bullet stopped by geometry is no longer active and cannot reach the fallback.
- Live boundary: RC26 still requires immediate real-game confirmation of light/heavy hits and a longer response-unit combat pass without the former traceback.

## RC25 idle-recovery and building-boundary correction

- User live evidence after RC24 found that some drones could stop unexpectedly and that flight could enter building geometry.
- Flight coverage now samples the native path-grid state across the airframe footprint, permits low-cover flyover and rejects walls, doors, windows, climbable/high-obstruction cells.
- A blocked direct route proves that deterministic alternate-heading steering remains active without crossing the blocked cell.
- A 0.55-second idle watchdog proves that tracking drones select a new flank and searching drones advance their relocation phase rather than remaining still.
- Existing speed caps, playable-world clamping, wing separation, synchronized physical hitboxes and ordinary bullet destruction remain covered.
- Live boundary: RC25 still requires real-map confirmation that every relevant building material reports a blocked native grid state and that the recovery motion feels natural under combat pressure.

## RC24 compact counterplay and tactical-flight correction

- Live RC23 evidence confirmed that armed drones can acquire and fire, but rejected their visual scale, inability to receive player bullet hits and static-feeling aggressive movement.
- Engine inspection proved the shootability defect: camera `setPos()` updates aim quadtrees but not the physical body, and `setSize()` does not update `hitboxW`/`hitboxH`.
- Drone orchestration now proves an explicit physical hitbox exists, its body coordinates follow every carrier move, the aim point stays centered and an ordinary bullet invokes destruction.
- Roster coverage fixes compact 0.32/0.35/0.39 Scout/light/heavy scales.
- Flight coverage proves sustained contact changes flank slots, lost contact advances exploration phases and aggressive search-ring destinations remain within playable bounds.
- Live boundary: RC24 still requires real projectile-hit confirmation while drones move, visual scale approval and observation of multiple search/flank cycles under combat pressure.

## RC23 live outline-crash and speed correction

- Live RC22 evidence confirmed that an aggressive drone could acquire and reach the player after gunfire.
- The same pass exposed a deterministic crash while the player aimed at that drone: native `genericObject:drawOutline()` received `xOff=nil` because the invisible runtime camera carrier intentionally has no native sprite `quadStruct`.
- RC23 delegates `drawOutline`/`rawDraw` to the real HCO airframe atlas frame. The drone and airframe harnesses execute both sides of that delegation and pass.
- Base speed drops from 130 to 95. Patrol/aggressive multipliers drop to 0.52/0.82 and hard caps limit actual movement to 64/108 world units per second.
- The movement cap is applied after wing separation, preventing the former 84-unit avoidance correction from becoming a one-frame teleport.
- Live boundary: RC23 still requires confirmation that aiming, shooting and sustained pursuit remain crash-free and that the new caps feel fair in a real mission.

## RC22 seven-model wing delta

- Lua syntax validation covers the new roster, flight, weapon, airframe and orchestration modules.
- Roster harness proves exactly seven stable atlas rows: Scout plus light/heavy Pistol, SMG and Laser.
- Flight harness proves world-bound spawn clamping, stable tracking slots and independent body/gimbal angles.
- Weapon harness proves native bullet creation/sound for ballistic models and that laser damage occurs only after the full telegraph.
- Airframe harness proves per-model scale, roster sprite-batch registration, body-heading render and independent sensor propagation.
- Four creator-supplied audio adaptations pass PCM-WAV decode/duration checks: light/heavy rotor and light/heavy laser.
- Live boundary: RC22 still requires a fresh-mission pass for model frequency, real projectile collision, laser damage/God Mode, LOS cancellation, EMP interruption, heavy armor, audio mix and map-edge behavior.

## RC21 flight and counterplay delta

- All 28 Lua source files parse successfully.
- Native-airframe harness verifies 0.28 scale, -90-degree sprite-forward alignment, native sprite-batch update, pixel wake generation and propagation of aggressive/disrupted state.
- Drone behavior harness verifies patrol launch, movement, confirmed sighting, EMP acquisition suppression, bullet destruction, localized crash evidence and response-guard dispatch.
- Boot, full runtime, drone, airframe, faction-visual and completion-feedback smoke suites pass.
- Live boundary: the RC20 screenshot proves the native body render path. RC21's scale/orientation/effects and new counterplay behavior are not yet live-approved.

## RC8 live-fix delta

- Confirmed-contact-to-drone-deployment assertion passed independently of body evidence.
- Drone deployment/flight harness now verifies a launched deployment rather than only class creation.
- Completion-feedback harness verifies animated banner text, payout, bonus result, stinger, and confirmation cue.
- Lua parse plus boot, runtime, multi-contract, reward, reload, rollback, drone, faction-visual, and feedback suites remain green.

## RC7 visual-identity delta

- Native target variant selection, protection-detail faction identity, and profile-specific drone doctrine assertions passed.
- Original four-cell insignia sheet passed alpha/crop validation and the guarded goon post-draw render harness.
- Existing boot, runtime, multi-contract, payout, reload, escape, rollback, drone-flight, and destruction coverage remains green.

## RC6 automated delta

- Lua parse: 25 source files passed under Lua runtime validation.
- Degraded boot: passed with missing objective/disguise/camera engine services isolated.
- Full runtime harness: passed target selection, movement phases, security knowledge, disguise/radio compromise, environment/NPC kills, campaign payout without `studio`, reload, escape, invalid-target fail-closed, rollback, and duplicate-listener prevention.
- Multi-contract harness: passed two unique targets, contract-exclusive protection actors, at least five guards per detail on the synthetic large map, separate objective slots, and a two-record persistence-v3 bundle.
- Drone engine-contract harness: passed custom security-camera subclass registration, three physical world-object launches, dynamic flight update, and bullet-break destruction.
- Remaining proof boundary: rendering, scanlight, and physical interaction must now be visually confirmed inside Intravenous 2 `1.4.12HF3`.

**Date:** 2026-08-07
**Source modules:** 33 Lua files
**Target game:** Intravenous 2 `1.4.12HF3`  
**Real-game validation:** main-menu boot passed; mission validation in progress

## Test layers

### Lua syntax

Every `.lua` file is parsed individually with `luaparse`.

Expected marker: `HCO_LUA_SYNTAX_PASS`

### Full simulated runtime

The Fengari smoke harness exercises:

- conservative deterministic selection and vanilla-objective actor exclusion;
- one HCO objective beside an existing vanilla objective;
- native start-indicator enablement and moving marker;
- profile-sized elite escort assignment;
- active reload with stable target and no duplicate objective;
- visible disguise and native keycard restoration;
- valid-disguise detection reduction and same-unit recognition;
- published calm/risky semantic identity state and networked source-uniform compromise;
- local body compromise, nearby knowledge, native radio opening/closing, completed global propagation, and disrupted-call cancellation;
- explicit radio-operator assignment, low-confidence local reaction, direct-sighting pressure hunt, and distinct physical search sectors while close protection stays with the target;
- threat relocation, physical shelter arrival, camera evidence, and breached-shelter reselection;
- ten-second anti-stuck recovery;
- neutralization completion and exactly one native reward;
- no second payout when death follows neutralization;
- terminal completion and escape persistence across reload;
- unsupported-map skip;
- empty custom-map skip;
- physical evacuation and no reward on escape;
- evacuation triggered by complete escort loss;
- direct environmental and NPC-caused death completion with exactly-once rewards;
- missing saved target failing closed without reroll;
- missing objective attachment rolling back target, escort role, experience, health, state, and route;
- duplicate bootstrap listener prevention and unload cleanup.

Expected marker: `HCO_RUNTIME_SMOKE_PASS`

### Boot and degraded mode

The boot harness intentionally omits the world, native objective base task, goon interaction system, and camera hook. It verifies that HCO logs isolated subsystem failures, keeps lifecycle/runtime ownership valid, disables contracts safely, and never crashes the process.

Expected marker: `HCO_BOOT_FAILURE_ISOLATION_PASS`

### Post-test evidence collector

The PowerShell collector is executed from a disposable copy against the real local installation. It verifies the installed version, confirms source/install Lua hashes, handles the game's debug log as either a file or directory, records process state, and copies the newest crash log without modifying saves or game files.

Expected marker: `HCO_TEST_EVIDENCE_READY` followed by the report path.

## Final results

- Lua syntax: **PASS** — all 33 Lua modules parse, including RC47's native body-quadtree recovery and RC46's priority/cache/hook paths.
- Full simulated runtime: **PASS** — `HCO_RUNTIME_SMOKE_PASS`.
- Boot/failure isolation: **PASS** — `HCO_BOOT_FAILURE_ISOLATION_PASS`.
- Drone orchestration: **PASS** — `HCO_DRONE_SMOKE_PASS`.
- Seven-model flight/weapon behavior: **PASS** — `HCO_DRONE_ROSTER_SMOKE_PASS`.
- Native airframe rendering: **PASS** — `HCO_AIRFRAME_SMOKE_PASS`.
- Portable repository batch: **PASS** — `HCO_TEST_SUITE_PASS suites=7`; no harness contains a machine-local source path.
- Post-test installation audit: **PASS** — installed `0.14.13-rc47`, 43 source payload files, 43 installed payload files and 0 mismatches. The game was not running after installation.
- Source/output/install relative-file parity: **PASS** — 43 payload files including 33 Lua modules and ten runtime media files.
- Source/output/install SHA-256 parity: **PASS** — zero missing, extra or mismatched files across all three trees.
- Workshop ZIP integrity: **PASS** — `Hitman-Contracts-Overhaul-0.14.13-rc47.zip` contains all 43 payload files below the required nested `files/` root and has SHA-256 `68A8F7842E3373DD58AE7015728D2F9787EB02092C66C01C1CC279376BAC4A63`.
- Repository release gate: **PASS** — `HCO_RELEASE_CHECK_PASS version=0.14.13-rc47 payload=43`.
- Post-install evidence collector: **PASS** — installed 33/33 Lua files with zero mismatches at 21:59:21; the game was not running, the current debug log was empty and the newest stored crash log at 12:07:42 predates RC47.

The markers above were collected from RC47 source and its exact local installation. Automated results prove internal behavior, packaging and failure handling only; they do not replace the final live-mission pass.
