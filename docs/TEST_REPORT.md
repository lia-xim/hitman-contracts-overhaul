# Automated Test Report — 0.11.1-rc23

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

**Date:** 2026-08-06  
**Source modules:** 28 Lua files  
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

Expected marker: `HCO_EVIDENCE_COLLECTOR_PASS`

## Final results

- Lua syntax: **PASS** — all 31 Lua modules parse, including the RC23 outline and bounded-flight correction.
- Full simulated runtime: **PASS** — `HCO_RUNTIME_SMOKE_PASS`.
- Boot/failure isolation: **PASS** — `HCO_BOOT_FAILURE_ISOLATION_PASS`.
- Drone orchestration: **PASS** — `HCO_DRONE_SMOKE_PASS`.
- Seven-model flight/weapon behavior: **PASS** — `HCO_DRONE_ROSTER_SMOKE_PASS`.
- Native airframe rendering: **PASS** — `HCO_AIRFRAME_SMOKE_PASS`.
- Post-test evidence collector: **PASS** — `HCO_EVIDENCE_COLLECTOR_PASS` with 0 hash mismatches.
- Source/install relative-file parity: **PASS** — 40 payload files including 31 Lua modules and nine runtime media files.
- Source/install SHA-256 parity: **PASS** — every installed RC23 payload file matches the repository source; zero extras.
- Workshop ZIP integrity: **PASS** — `Hitman-Contracts-Overhaul-0.11.1-rc23.zip` contains the required nested `files/` root and has SHA-256 `A5AC090CD81B5E4CDA482672BA0063CEC46EA79E64ABB7B5196C388C2A1AD015`.

The report will be updated with the final markers and package hashes before handoff. Automated results prove internal behavior and failure handling only; they do not replace the final live-mission pass.
