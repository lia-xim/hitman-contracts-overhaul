# Testing boundary

Automated checks validate Lua syntax, bootstrap isolation, contract lifecycle, persistence, objective rollback, social stealth, drone construction and movement, visual assets, audio, and completion feedback against controlled engine-interface fixtures.

These checks do not prove live AI behavior or rendering. A release candidate is promoted only after this in-game pass on Intravenous 2 1.4.12HF3:

RC27 specifically reports `HCO RC27 DRONE ROSTER`. The expected values are `quadtree ACTIVE`, `batch READY`, `sprite READY`, and at least one body. The four fields isolate world-entity visibility, native batch creation, atlas loading, and spawn state respectively.

1. Reach the main menu without an HCO traceback.
2. Start a compatible mission from the beginning and confirm at least one native optional contract.
3. Recover field intelligence and verify the moving target marker.
   HCO tactical notices must appear one at a time in the lower third and must not overlap the native contract/objective announcement.
4. Reset all Cheat Trainer settings, if installed.
5. Let an HCO guard confirm the player. Verify the response deployment notice, that the target flees away with its close bodyguards, and that only the separate response units converge and fire.
6. Verify that passive patrol drones use an actor-sized Scout/light silhouette above the active searchlight. Body heading follows motion while the sensor nose and cone may gimbal independently. Hover bob, rotor pulses and a short cyan pixel wake should make movement readable; light rotor audio must react to distance. Three suppressed player shots and NPC fire must not trigger aggressive mode.
7. Fire at least three loud player shots within eight seconds or damage one guard without immediately killing the target; verify `DRONE SUPPORT INBOUND`, the aggressive-search notice, faster drones, rotor audio, scan cones, and destructibility.
8. Stand visibly inside a drone cone for at least one second. Verify the cone changes color, stays attached to the player instead of sweeping away, `DRONE CONTACT` appears, and response units receive the last-known position. Move around the drone and verify gimbal-first/body-second rotation plus a stable standoff slot.
9. Electronically disrupt a drone. It must flicker blue and stop acquiring/relaying until disruption ends.
10. Trigger at least two escalated wings and identify different entry directions and models. Verify every destination remains inside the playable map and no drone parks behind an unreachable world boundary.
11. Face a Pistol or SMG drone. Its visible aim must precede native bullets, obstruction must block fire, and the native weapon sound must play. Light variants take one hit. Heavy variants take two or three ordinary hits, show a full-airframe tint, expanding sparks and armor pips on every surviving hit, and may fall in one high-caliber hit.
12. Face light and heavy Laser drones. Their aim lines must remain on target through visible 0.9/1.4-second charges; breaking LOS or leaving the gimbal cancels the charge. The adapted light/heavy fire sounds and cooldowns must differ.
13. Shoot down a drone. Its body, light and loop sound must stop, a local crash alert must occur and available response guards should investigate the crash position.
14. Resolve the target and verify the compact completion banner, sound, payout, and persistence after reload.

If drone construction fails, RC13 displays either `HCO DRONE SUPPORT OFFLINE` with the concrete spawn reason or `HCO DRONE RUNTIME ERROR` with the failing subsystem call. Capture that full message in the report.

Open issues must include the game version, map, active mods, whether the mission began fresh or from a save, exact reproduction steps, and any `[HCO]` log or traceback.
