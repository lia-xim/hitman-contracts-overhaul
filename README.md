# Hitman Contracts Overhaul

![Hitman Contracts Overhaul](docs/images/workshop-header.png)

Hitman Contracts Overhaul (HCO) turns compatible Intravenous 2 missions into systemic high-value-target operations. It adds optional native objectives, mobile targets, escalating protection details, field intelligence, disguises, credentials, social stealth, evidence-driven searches, physical drones, and campaign rewards without placing a separate menu over the game.

**Current build:** `0.14.13-rc47`
**Target game:** Intravenous 2 `1.4.12HF3`
**Status:** production-candidate test release. RC47 restores eligible dead/unconscious actors to the current world's native interaction quadtree before applying body priority and menu repair, so `Q` can discover the body instead of only its dropped equipment. Promotion to `1.0` remains gated by the documented crash-free live mission matrix.

## Highlights

- One to three deterministic optional contracts per compatible mission.
- Executive, Broker, Fixer, and Commander archetypes with distinct appearance, rewards, drone doctrines, five close bodyguards, and 5/10/15/20 separate response units, constrained by the map's safe NPC population.
- Native difficulty changes response strength, health, drone pressure, sensor performance, threat rating and payout instead of applying one hidden balance to every playthrough.
- Stronger protected targets and elite guards with archetype-scaled health.
- Mobile target phases, native authored-route patrol, one continuous close-protection follower chain, nearby-incident awareness, safe-area relocation, physical evacuation, and anti-stuck recovery without teleporting targets.
- Field-intelligence dead drops that reveal exact moving target markers.
- Native body-menu identities with three tiers, visible actor variants, matching faction insignia, weapon-neutral cover, restricted areas, keycards/keychains, colleague recognition, bloodied-uniform risk, compromise, interruptible radio checks, and lifecycle repair after mission restarts or class/menu replacement.
- Seven physical, actor-scaled drone models: one unarmed Scout plus light/heavy Pistol, SMG and Laser airframes.
- A global twelve-airframe ceiling plus per-contract Heavy/Laser limits prevents multi-contract missions from turning into an unreadable or expensive 21-drone pile-up.
- Stable standoff pursuit replaces continuous player orbiting; bodies turn with flight while independent sensor gimbals retain the player inside their allowed arc.
- Native roof-map and floor-grid footprint validation keep armed drones outside buildings, out of unreachable void and apart from other airframes. After ordinary steering fails, a bounded unarmed hop may cross only a narrow barrier between two verified outdoor cells; roofed structures remain forbidden.
- Armed drones fire only after a completed native line-of-sight trace and while their centered bullet target is valid. Pistol/SMG models create native game bullets; lasers expose an aim line and full charge window before damage.
- Light/heavy rotor profiles and laser one-shots are adapted from creator-supplied audio, while ballistic drones retain native weapon sounds.
- Native-airframe flight presentation with hover motion, rotor/sensor pulses, a short pixel wake, family-colored effects, real laser-charge progress, damage smoke and a readable sensor heading.
- Four-stage damaged sprites for all seven airframes replace the intact body during the tumble and end in a persistent asymmetric wreck; destroyed drones have no cone, aim cue, weapon state or rotor loop.
- One to three archetype-scaled drones patrol around each protected target from contract start. They commit to reachable outdoor waypoints, keep one wall-follow direction and abandon routes that produce motion without destination progress; a geometrically boxed-in sensor performs a continuous 360-degree sweep. Confirmed contact turns every HCO wing's searchlights red and shares the reported position and observed appearance across the map security network.
- Immediate protection mobilization and drone request on confirmed contact, guard damage, or protection casualties.
- Three loud player shots within eight seconds trigger aggressive drone support independently of visual-contact hand-off; NPC fire and suppressed player fire do not.
- Engine-owned security-camera carriers provide physics, searchlights, obstruction and bullet interaction. A registered `hco_drone_airframe` world entity supplies the visible body through the same quadtree and sprite-batch lifecycle used by normal world actors.
- Drones can be electronically disrupted or shot down. A destroyed airframe tumbles along its last movement vector, sheds sparks and smoke, hits the ground and remains as a dark wreck. The landing creates local evidence and pulls available response guards toward it.
- Patrol drones classify visible bodies through their real cone and world raycast. A clean disguise outside close scrutiny produces capped amber suspicion even during an aggressive search. Inside 155 units, or 205 during an alarm, sustained cone/raycast contact progressively confirms the identity; aiming, firing, compromise or other overt behavior restores rapid detection. Discovery of the stolen uniform's source compromises it.
- Confirmed contact sends the target and its five close guards toward safety while response units hunt the player instead of dragging the principal into combat.
- Native contract-completion banner, audio feedback, campaign payout, and save/reload persistence.
- Transactional activation, duplicate-copy protection, and isolated subsystem failure handling.

## How it plays

No menu or hotkey is required. Start a compatible mission from the beginning. HCO selects safe mission actors and adds optional contracts through the native objective system. Follow the intelligence marker, recover the dead drop, and then track the moving target.

Approach a dead or unconscious guard. A restrained cyan world-space stitch marker identifies an unused uniform in interaction range. RC47 first guarantees that eligible body exists in the current world's native interaction quadtree, then gives it priority over dropped equipment, so **Take disguise / search body** appears immediately as the first action in the normal interaction selector; `Q` still cycles to other overlapping objects. The player visibly adopts that actor variant and receives a restrained persistent cyan identity shimmer; compromised cover is shown in red. Open any dead/unconscious body selector while disguised and choose **Restore original identity** to put the original appearance back on. Stolen credentials remain in the native inventory and consumed uniforms cannot be duplicated. The held weapon, weapon model and holster state do not affect the identity. Keep a believable distance: sustained close eye contact builds observer-local scrutiny, same-unit/elite guards inspect faster, and point-blank visual contact blows the cover immediately. Running, aiming at someone, witnessed firing, lockpicking, carrying a body, a bloodied uniform, fresh evidence, restricted access or target lingering can also expose you. An unseen shot creates investigation at its location without revealing who fired it. A real radio report can be disrupted before local recognition becomes global compromise.

Drones participate in that same social-stealth model. Aggressive search means the wing knows where to look, not whom it is looking at. A calm valid identity remains amber suspicion at ordinary distance and must enter close sensor scrutiny before that drone can track, confirm or fire. A guard or drone can share an actually confirmed appearance, but changing into a new disguise invalidates the old visual match. A drone that finds the body from which the uniform was taken compromises that disguise over the security network.

If security confirms you, the detail enters combat and shares your last known position. Heard gunfire, a wounded guard or a protection casualty instead starts a search at the incident location and requests the archetype's drone response without giving uninformed guards your identity.

The Scout remains an information weapon: it exposes and relays your last known position. Armed models join escalated wings according to archetype. They must maintain real line of sight and gimbal alignment, expose their aim, respect range/cooldowns, and remain shootable or disruptable throughout the attack. During a narrow-wall overflight they cannot scan, confirm, relay or fire; combat resumes only after an outdoor landing.

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
- `docs/SPECIFICATION_TRACEABILITY.md` — specification-to-runtime/test/live-proof matrix, including the full social-stealth contract.
- `docs/TESTING.md` — reproducible automated and in-game acceptance boundary.
- `docs/PRODUCTION_READINESS.md` — balance contract, performance limits and the exact `1.0` promotion gate.
- `workshop/` — Steam Workshop copy and preview; excluded from release ZIPs.
- `scripts/` — verification and packaging helpers.
- `tests/` — portable LÖVE smoke harnesses for lifecycle, stealth, balance, drones and presentation.

## Build a release archive

```powershell
./scripts/release-check.ps1
```

The release check validates Lua/payload rules, enforces `VERSION`/runtime parity, packages the nested `files/` root and compares every archived file to source by SHA-256.

Run the complete simulated regression suite with LÖVE 11.5:

```powershell
./scripts/test.ps1 -LovePath C:\path\to\lovec.exe
```

## Contributing and license

See [CONTRIBUTING.md](CONTRIBUTING.md). Code is under the [MIT License](LICENSE). Original runtime media is dedicated under [CC0](ASSET_LICENSE.md). Game imagery and trademarks are excluded; see [THIRD_PARTY_NOTICE.md](THIRD_PARTY_NOTICE.md).
