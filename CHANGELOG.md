# Changelog

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
