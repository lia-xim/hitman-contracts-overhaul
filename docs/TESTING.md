# Testing boundary

Automated checks validate Lua syntax, bootstrap isolation, contract lifecycle, persistence, objective rollback, social stealth, drone construction and movement, visual assets, audio, and completion feedback against controlled engine-interface fixtures.

These checks do not prove live AI behavior or rendering. A release candidate is promoted only after this in-game pass on Intravenous 2 1.4.12HF3:

RC20 specifically reports `HCO RC20 NATIVE AIRFRAME`. The expected values are `quadtree ACTIVE`, `batch READY`, `sprite READY`, and at least one body. The four fields isolate world-entity visibility, native batch creation, asset loading, and spawn state respectively.

1. Reach the main menu without an HCO traceback.
2. Start a compatible mission from the beginning and confirm at least one native optional contract.
3. Recover field intelligence and verify the moving target marker.
   HCO tactical notices must appear one at a time in the lower third and must not overlap the native contract/objective announcement.
4. Reset all Cheat Trainer settings, if installed.
5. Let an HCO guard confirm the player. Verify the response deployment notice, that the target flees away with its close bodyguards, and that only the separate response units converge and fire.
6. Verify that passive patrol drones have a clearly visible animated four-rotor body above the active searchlight, move around the protected target, and produce distance-reactive rotor audio. Three suppressed player shots and NPC fire must not trigger aggressive mode.
7. Fire at least three loud player shots within eight seconds or damage one guard without immediately killing the target; verify `DRONE SUPPORT INBOUND`, the aggressive-search notice, faster drones, rotor audio, scan cones, and destructibility.
8. Stand visibly inside a drone cone for at least one second. Verify the cone changes color, `DRONE CONTACT` appears, and response units receive and move toward that last-known position.
9. Resolve the target and verify the compact completion banner, sound, payout, and persistence after reload.

If drone construction fails, RC13 displays either `HCO DRONE SUPPORT OFFLINE` with the concrete spawn reason or `HCO DRONE RUNTIME ERROR` with the failing subsystem call. Capture that full message in the report.

Open issues must include the game version, map, active mods, whether the mission began fresh or from a save, exact reproduction steps, and any `[HCO]` log or traceback.
