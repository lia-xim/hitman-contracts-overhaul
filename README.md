# Hitman Contracts Overhaul

![Hitman Contracts Overhaul](docs/images/workshop-header.png)

Hitman Contracts Overhaul (HCO) turns compatible Intravenous 2 missions into systemic high-value-target operations. It adds optional native objectives, mobile targets, escalating protection details, field intelligence, disguises, credentials, social stealth, evidence-driven searches, physical drones, and campaign rewards without placing a separate menu over the game.

**Current build:** `0.12.1-rc25`
**Target game:** Intravenous 2 `1.4.12HF3`
**Status:** public release candidate. RC25 keeps the compact, synchronized and shootable seven-model roster moving, actively steers it around native wall/door/window boundaries and recovers stalled flight automatically. The complete armed-drone behavior still needs a crash-free live mission pass.

## Highlights

- One to three deterministic optional contracts per compatible mission.
- Executive, Broker, Fixer, and Commander archetypes with distinct appearance, rewards, drone doctrines, five close bodyguards, and 5/10/15/20 separate response units, constrained by the map's safe NPC population.
- Stronger protected targets and elite guards with archetype-scaled health.
- Mobile target phases, safe-area relocation, physical evacuation, and anti-stuck recovery without teleporting targets.
- Field-intelligence dead drops that reveal exact moving target markers.
- Body-search disguises, plausible weapons, restricted areas, credentials, colleague recognition, compromise, and interruptible radio checks.
- Seven physical, actor-scaled drone models: one unarmed Scout plus light/heavy Pistol, SMG and Laser airframes.
- Stable standoff pursuit replaces continuous player orbiting; bodies turn with flight while independent sensor gimbals retain the player inside their allowed arc.
- Native floor-grid endpoint validation and wing separation keep drones out of unreachable void and prevent stacked airframes; unused roster models are preferred before duplicates.
- Armed drones fire only after confirmed line-of-sight tracking. Pistol/SMG models create native game bullets; lasers expose an aim line and full charge window before damage.
- Light/heavy rotor profiles and laser one-shots are adapted from creator-supplied audio, while ballistic drones retain native weapon sounds.
- Native-airframe flight presentation with hover motion, rotor/sensor pulses, a short pixel wake, state colors and a readable sensor heading.
- One to three archetype-scaled drones patrol around each protected target from contract start, then switch to a faster and more exact aggressive search after escalation.
- Immediate protection mobilization and drone request on confirmed contact, guard damage, or protection casualties.
- Three loud player shots within eight seconds trigger aggressive drone support independently of visual-contact hand-off; NPC fire and suppressed player fire do not.
- Engine-owned security-camera carriers provide physics, searchlights, obstruction and bullet interaction. A registered `hco_drone_airframe` world entity supplies the visible body through the same quadtree and sprite-batch lifecycle used by normal world actors.
- Drones can be electronically disrupted or shot down. Crashes create local evidence and pull available response guards toward the crash position.
- Confirmed contact sends the target and its five close guards toward safety while response units hunt the player instead of dragging the principal into combat.
- Native contract-completion banner, audio feedback, campaign payout, and save/reload persistence.
- Transactional activation, duplicate-copy protection, and isolated subsystem failure handling.

## How it plays

No menu or hotkey is required. Start a compatible mission from the beginning. HCO selects safe mission actors and adds optional contracts through the native objective system. Follow the intelligence marker, recover the dead drop, and then track the moving target.

Approach a dead or unconscious guard and choose **Search body / take disguise**. Normal movement and plausible equipment reduce suspicion; running, aiming, firing, lockpicking, carrying a body, restricted access, or close colleagues can expose you.

If security confirms you, takes fire, or loses a protection member, the detail enters combat, shares the last known position, and requests its archetype's drone response.

The Scout remains an information weapon: it exposes and relays your last known position. Armed models join escalated wings according to archetype. They must maintain real line of sight and gimbal alignment, expose their aim, respect range/cooldowns, and remain shootable or disruptable throughout the attack.

## Cheat Trainer compatibility

The companion Intravenous 2 Cheat Trainer recognizes HCO security. HCO targets and guards remain able to detect the player even if ordinary enemy visual detection is disabled. God mode still prevents damage, while damage multipliers and one-hit mode still make HCO targets easy to kill. For a meaningful balance test, use **Reset all cheats** first.

## Installation

1. Download the latest pre-release archive.
2. Remove an older `Hitman-Contracts-Overhaul` directory, then create `<Intravenous 2>/mods/Hitman-Contracts-Overhaul`.
3. Extract the archive so the final path is `<Intravenous 2>/mods/Hitman-Contracts-Overhaul/files/main.lua`, with `files/hco/` and `files/assets/` beside it. Intravenous 2's local loader explicitly loads this nested `files/` directory.
4. Restart the game completely and begin a compatible mission from its start.

Do not enable both a local and Workshop copy at the same time.

## Repository layout

- `files/` — complete installable mod payload.
- `docs/SPECIFICATION.md` — full product and systems specification.
- `docs/ENGINE_EVIDENCE.md` — documented native interface research; no decompiled source is redistributed.
- `docs/IMPLEMENTATION_STATUS.md` — honest requirement-by-requirement current state and remaining work.
- `docs/TESTING.md` — reproducible automated and in-game acceptance boundary.
- `workshop/` — Steam Workshop copy and preview; excluded from release ZIPs.
- `scripts/` — verification and packaging helpers.

## Build a release archive

```powershell
./scripts/package.ps1
```

## Contributing and license

See [CONTRIBUTING.md](CONTRIBUTING.md). Code is under the [MIT License](LICENSE). Original runtime media is dedicated under [CC0](ASSET_LICENSE.md). Game imagery and trademarks are excluded; see [THIRD_PARTY_NOTICE.md](THIRD_PARTY_NOTICE.md).
