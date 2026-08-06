# Testing boundary

Automated checks validate Lua syntax, bootstrap isolation, contract lifecycle, persistence, objective rollback, social stealth, drone construction and movement, visual assets, audio, and completion feedback against controlled engine-interface fixtures.

The seven portable harnesses are committed under `tests/` and run with `./scripts/test.ps1 -LovePath C:\path\to\lovec.exe` (LÖVE 11.5 recommended). A successful batch ends with `HCO_TEST_SUITE_PASS suites=7`.

These checks do not prove live AI behavior or rendering. A release candidate is promoted only after this in-game pass on Intravenous 2 1.4.12HF3. RC30 intentionally disables the old RC render diagnostic in normal play; an internal `HCO RC.. DRONE ROSTER` HUD message is now a failure, not an expected result.

1. Reach the main menu without an HCO traceback.
2. Start a compatible mission from the beginning and confirm at least one native optional contract.
3. Recover field intelligence and verify the moving target marker.
   HCO tactical notices must appear one at a time in the lower third and must not overlap the native contract/objective announcement.
4. Reset all Cheat Trainer settings, if installed.
5. Let an HCO guard confirm the player. Verify the response deployment notice, that the target flees away with its close bodyguards, and that only the separate response units converge and fire.
6. Verify that passive patrol drones use an actor-sized Scout/light silhouette above the active searchlight. Body heading follows motion while the sensor nose and cone may gimbal independently. Hover bob, rotor pulses and a short cyan pixel wake should make movement readable; light rotor audio must react to distance. Three suppressed player shots and NPC fire must not trigger aggressive mode.
   Verify cyan Scout, amber Pistol, red SMG and violet Laser effects without confusing any of them with hostile/contact state.
7. Fire at least three loud player shots within eight seconds or damage one guard without immediately killing the target; verify `DRONE SUPPORT INBOUND`, the aggressive-search notice, faster drones, rotor audio, scan cones, and destructibility.
8. Stand visibly inside a drone cone for at least one second. Verify the cone changes color, stays attached to the player instead of sweeping away, `DRONE CONTACT` appears, and response units receive the last-known position. Move around the drone and verify gimbal-first/body-second rotation plus a stable standoff slot.
9. Electronically disrupt a drone. It must flicker blue and stop acquiring/relaying until disruption ends.
10. Trigger at least two escalated wings and identify different entry directions and models. Verify every drone first appears on an exterior tile, never beneath a building roof, remains inside the playable map and never attacks from behind an unreachable world boundary.
11. Face a Pistol or SMG drone. Its visible aim must precede native bullets, obstruction must block fire, and the native weapon sound must play. If its visible/physical target is ever unavailable, it must stop detecting and firing, then retire. Light variants take one hit. Heavy variants take two or three ordinary hits and show a full-airframe tint, expanding sparks and armor pips on every surviving hit. Deliberately shoot the outer rotors/corners of a moving Heavy: those visible regions must register instead of passing through.
12. Face light and heavy Laser drones. Their aim lines must remain on target through visible 0.9/1.4-second charges; breaking LOS or leaving the gimbal cancels the charge. The adapted light/heavy fire sounds and cooldowns must differ.
13. Shoot down one light and one heavy drone. The light should tumble for roughly 0.78 seconds and the heavy for roughly 0.95 seconds along their last movement vector. Verify rotor loss, visible smoke/sparks, an impact ring/debris burst, a persistent dark wreck, stopped loop audio and response guards investigating the actual landing position.
14. Acquire a valid disguise and walk normally through a routine cone; identification must be slower but still progress. Repeat while aiming, sprinting or just after firing; scrutiny must accelerate. Aggressive search must retain at least 72% acquisition speed.
15. Leave a dead/unconscious NPC in an unobstructed patrol cone. Verify one `DRONE EVIDENCE SCAN` cue and an expanding scan pulse. Repeated passes must not duplicate the report. If it is the source of the active uniform, that disguise must become compromised; disruption must suppress the scan.
16. Resolve the target and verify the compact completion banner, sound, difficulty-scaled payout, and persistence after reload.

If drone construction fails, RC13 displays either `HCO DRONE SUPPORT OFFLINE` with the concrete spawn reason or `HCO DRONE RUNTIME ERROR` with the failing subsystem call. Capture that full message in the report.

Open issues must include the game version, map, active mods, whether the mission began fresh or from a save, exact reproduction steps, and any `[HCO]` log or traceback.
