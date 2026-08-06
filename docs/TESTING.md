# Testing boundary

Automated checks validate Lua syntax, bootstrap isolation, contract lifecycle, persistence, objective rollback, social stealth, drone construction and movement, visual assets, audio, and completion feedback against controlled engine-interface fixtures.

These checks do not prove live AI behavior or rendering. A release candidate is promoted only after this in-game pass on Intravenous 2 1.4.12HF3:

1. Reach the main menu without an HCO traceback.
2. Start a compatible mission from the beginning and confirm at least one native optional contract.
3. Recover field intelligence and verify the moving target marker.
4. Reset all Cheat Trainer settings, if installed.
5. Let an HCO guard confirm the player and verify that the detail enters combat and fires.
6. Damage one guard without immediately killing the target; verify a drone deployment notice, visible moving drones, rotor audio, scan cones, and destructibility.
7. Let a drone detect the player and verify coordinated pressure toward the last known position.
8. Resolve the target and verify the compact completion banner, sound, payout, and persistence after reload.

Open issues must include the game version, map, active mods, whether the mission began fresh or from a save, exact reproduction steps, and any `[HCO]` log or traceback.
