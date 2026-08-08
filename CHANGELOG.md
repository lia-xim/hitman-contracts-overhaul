# Changelog

## 0.14.18-rc52 — 2026-08-08

- Turned routine drone deployment into a maintained ambient security layer. Every active contract now records an archetype/difficulty-scaled passive baseline; a bounded supervisor removes stale carriers and quietly replaces only missing airframes without exceeding the existing seven-per-contract or twelve-global fleet ceilings.
- Fixed one-shot deployment loss. A temporarily unavailable native camera carrier or safe outdoor spawn no longer consumes the request: remaining airframes stay queued with capped exponential retry backoff, while roof-map readiness and global-cap waits remain fail-closed and non-spamming.
- Added an eight-second ambient replacement ceiling so a destroyed or safety-retired patrol does not wait through the full 28-second combat-wave cooldown before the network can restore coverage.
- Added a real alarm stand-down lifecycle. After security knowledge and target threat remain clear for twelve seconds, surviving drones cancel tracking, stale destinations, queued bursts/laser charge and red search presentation, then resume ordinary map patrol. Contact/gunfire gates are rearmed for a later independent incident.
- Added runtime and physical-drone regressions for maintained passive presence, exact-deficit replacement, failed-spawn recovery, automatic quiet stand-down and weapon/tracking cleanup. Existing target-route, social-stealth, combat, destruction, render and packaging suites remain mandatory.
- Added the native Steam Workshop staging workflow with paste-ready title, tags, BBCode description, change note, preview validation, publication checklist and preservation of Steam's existing item metadata on later updates.
- Made release ZIP creation byte-reproducible and extended the release gate to validate Workshop title, tag, description, preview-size and version metadata alongside the 43-file runtime payload.

## 0.14.17-rc51 — 2026-08-08

- Replaced tiny target-only shuttle routes with deterministic map-wide principal routines. When a compatible mission exposes enough safe authored patrol nodes, HCO selects five to eight points across several eligible security sectors instead of keeping the target inside its original two/three-point pocket.
- The expanded route is still native: it reuses real Intravenous 2 patrol-point objects, the Goon idle patrol state, asynchronous pathfinding, door interaction and the existing close-protection follower chain. HCO does not invent off-grid coordinates or teleport the principal.
- Added 160-unit node deduplication, a 1,250-unit adjacent-leg budget, seed-based route variation and circular traversal only when the closing leg is also bounded. Sparse maps retain the original authored route rather than accepting unsafe points.
- Checkpoint reload reconstructs the exact same routine from the persisted contract seed. Detach/rollback restores the untouched vanilla route, and RC50's path/cursor plus nine-second recovery rules remain authoritative for failed map legs.
- Added regressions for five-plus-node coverage, three-sector diversity, meaningful map span, bounded adjacent legs, native path ownership and deterministic checkpoint reconstruction.

## 0.14.16-rc50 — 2026-08-08

- Fixed the native patrol-cursor regression that left protected targets standing at one repeated route point. Intravenous 2's idle-state callback advances the route cursor while creating its path; HCO now primes that callback and preserves its resulting index instead of rewinding it behind the active destination.
- Corrected the nine-second mobility watchdog to advance exactly once from the live native cursor. Reassertion no longer skips a waypoint or desynchronizes the current path and route index.
- Made `CORNERED` a recovery phase instead of a permanent AFK state. A principal under sustained pressure periodically selects another authored secure point and proceeds to physical evacuation when the threat/escort thresholds demand it.
- Direct damage to the principal now mobilizes protection and immediate flight even before the attacker is identified. Unseen or suppressed fire still supplies only location-level evidence and does not grant guards wall-omniscience.
- Added native-shaped patrol-callback, path/cursor synchronization, sustained-corner recovery and direct-principal-damage regressions.

## 0.14.15-rc49 — 2026-08-07

- Fixed armed ballistic drones spawning native bullets inside their own 48/54-pixel carrier hitboxes. Pistol and Light/Heavy SMG projectiles now originate beyond the complete physical fixture instead of being consumed by the firing drone.
- A ballistic shot is accepted only when `weapon:createBullet` returns a real native projectile. Missing registrations, attribution actors, instantiation failures and nil projectiles now fail closed with a one-time model-specific diagnostic instead of playing a false gunshot.
- Rebuilt the laser discharge presentation around immutable shot endpoints. Light and Heavy laser beams now survive later AI/cooldown updates, render a readable accent glow, bright core, pixel-energy trail and impact flare, and remain visible even when God Mode prevents health loss.
- Added exact native-ID coverage for `p320`, `mp5` and `disruptor`, complete Light/Heavy SMG burst tests, carrier-clear muzzle assertions, persistent laser endpoint/lifetime tests and an airframe render regression that draws the fired beam without a live aim target.

## 0.14.14-rc48 — 2026-08-07

- Fixed a save-lifecycle regression that could make the entire mod appear absent. A persisted `failed_escaped` or `failed_invalid` contract was terminal forever, so loading that mission created no contract context, objective, target marker, drones, or disguise interactions.
- Failed, unpaid contracts now become a deterministic new attempt when that mission is loaded again. The new attempt receives its own contract ID and seed; the failed attempt never pays a reward.
- Successfully completed and paid contracts remain terminal, preventing reward farming. Their loaded save now emits one compact native feedback message explaining why HCO did not create another contract.
- Added regression coverage for legacy records without an attempt counter, failed-contract replay, distinct attempt identity, zero retry payout, completed-save terminal visibility, and exactly-once successful payout.

## 0.14.13-rc47 — 2026-08-07

- Fixed the actual native-selection failure behind the missing disguise action. Some direct death/state paths left a visible eligible body outside the world's interaction quadtree, so `Q` could only discover its dropped weapon, ammunition or keycard regardless of body priority or cached actions.
- Restores the engine's intended fallen-body interaction state after death, choking, falling, body drops and periodic checkpoint recovery. A valid body is inserted only when it is absent from the current world's interaction tree.
- Detects stale `withinInteraction` state carried across a replaced `worldObject`/checkpoint quadtree and reconnects the body to the current selector without repeatedly inserting healthy entries.
- Added a native-shaped regression in which `_die()` drops inventory but deliberately does not register the body. The suite now requires body presence in the selector quadtree, takeover as its first action and exactly one insertion across later refreshes.

## 0.14.12-rc46 — 2026-08-07

- Corrected the live screenshot diagnosis: the native selector was displaying object `1. HS2000`; the unconscious body was object `2`, so its actions were intentionally hidden until the player cycled with `Q`.
- Raised only eligible unused-uniform bodies to a native interaction priority above dropped equipment. Walking up to a fresh body now selects the body and exposes takeover immediately; consumed/ineligible bodies retain vanilla priority.
- Reconciled render-only body-menu reads against the active player even if the render path owns a separate or incomplete cache.
- Added periodic recovery when another later-loaded mod replaces HCO's `getInteractOptions` or interaction-priority hook without replacing the Goon class/action registry.
- Hardened the Windows test runner to terminate only newly spawned HCO smoke-test LÖVE processes, preventing an orphaned harness window from being mistaken for an Intravenous 2 crash.

## 0.14.11-rc45 — 2026-08-07

- Fixed the live disguise-menu regression at the exact native selector handoff. Intravenous 2 validates body actions with the player interactor, then reads the cached list again with `interactor=nil` while constructing the visible description box. RC44 incorrectly treated that second render-only read as a failed eligibility check and removed takeover immediately before drawing it.
- Preserved the already validated list on nil-interactor reads and added a regression matching the engine's validate-then-render sequence.
- Stopped globally re-enumerating the Goon action registry. HCO now appends unique power-of-two IDs without changing native or third-party IDs, then reorders only its two visible per-body entries so takeover/restore remain first in the selector.
- Removed HCO's duplicate `postInteract` call; the native object selector again owns the single post-action cache refresh.
- Added a subtle cyan/teal world-space stitch marker around nearby eligible bodies, making available identities readable without a hotkey, cursor or detached HUD layer.
- Added lifecycle coverage that removes HCO's class actions at runtime, requires exactly one repaired pair and proves both native action IDs remain unchanged.

## 0.14.10-rc44 — 2026-08-07

- Fixed the remaining live case where the native body selector returned a cached `update=false` option list without the disguise action even though its action bit was already set.
- Wrapped the real Goon `getInteractOptions` boundary. Before the native query, stale action generations are invalidated; after it, takeover and original-identity actions are reconciled directly into the exact list consumed by the selector.
- Kept the native bitmask and visible options synchronized while removing duplicate/stale HCO action objects from prior lifecycle generations. Native carry, weapon, inventory and finish-off options remain engine-owned and retain ID order.
- Accepts the actual active player object as the body interactor even if a runtime/mod combination does not expose the inherited `PLAYER` flag on that instance.
- Reworked the runtime fixture so body interaction methods are inherited from the Goon class like the real engine, and added a regression that deliberately drops the visible action while retaining its bit and current generation before an `update=false` query.

## 0.14.9-rc43 — 2026-08-07

- Restored real principal movement by preserving the path created by the native Goon patrol-state callback. Initial activation, routine restoration and the nine-second mobility watchdog now advance the original authored route without clearing its newly created destination.
- Rebuilt close protection as one verified native follower chain. Intravenous 2 supports one follower per leader; the former branched layout overwrote earlier links and could leave the principal's detail standing still. Broken ownership is now repaired even while guards remain physically close.
- Kept confirmed drones combat-capable through temporary contact loss. An exposed, appearance-matched player can be reacquired through fresh unobstructed line of sight even after an old last-known-position report expires.
- Made native projectile attribution stable for each airframe. Killing the response guard or principal first no longer silently removes an intact armed drone's ability to shoot; the stored valid world actor remains its attribution proxy until the drone is disabled or destroyed.
- Repaired the disguise actions after mission restart, class replacement and stale body-menu caches. HCO periodically verifies the real Goon interaction list, rebinds missing takeover/restore actions, re-enumerates native action IDs and rebuilds a body's visible option cache once per registration generation.
- Added regressions for native patrol-path preservation and watchdog recovery, complete close-protection ownership, post-casualty drone fire, stale-location visual reacquisition and takeover recovery from a stale native action bitmask.

## 0.14.8-rc42 — 2026-08-07

- Separated an aggressive search from confirmed player identity. An alarmed drone no longer receives cone-less tracking or a 72% minimum detection rate merely because security has a last-known position.
- Added appearance-scoped identity handoff. Guard/drone confirmation records the exact original appearance or disguise acquisition token; changing clothes invalidates stale drone tracking, recent-fire authorization and old visual confirmation without erasing the location-level search.
- Added drone social-stealth distance bands. A clean disguise at long range is capped at amber suspicion, while close cone/raycast scrutiny inside 155 units (205 during an active search) builds progressively before red confirmation. Compromised cover, aiming and overt behavior retain fast recognition.
- Made disguise risk atomic with acquisition and checkpoint restoration, removing the single exposed update frame that could let a nearby drone instantly classify freshly changed clothing as hostile.
- Replaced frame-flipping obstacle avoidance with stable handed wall following and a destination-progress watchdog. Drones now invalidate a route that shuffles without getting closer for 2.4 seconds, choose a new search/flank approach and keep the existing bounded, blind/disarmed barrier hop for legitimate narrow exterior separations.
- Added regressions for long-range alarmed disguise concealment, amber suspicion, progressive close scrutiny, appearance-token handoff, atomic disguise risk, stable wall-follow direction and movement-without-progress recovery.

## 0.14.7-rc41 — 2026-08-07

- Added bounded drone barrier overflight for narrow exterior walls, gates, fences and door separations. A drone first attempts ordinary steering, then crosses only when it finds a fully verified outdoor landing within 144 units and the obstructed span is no wider than 96 units; roofed buildings and map void remain forbidden.
- Made overflight an explicit movement-only state. Native camera perception, HCO acquisition, body scans, tracking confirmation and every weapon family are disabled until the drone has landed in a fair combat cell. The airframe rises through a short eased hop with cyan pixel lift cues while its physical hit target continues to follow it.
- Added a routine-mobility watchdog for protected targets. A principal stationary for nine seconds is advanced to another point on the original native patrol route instead of becoming permanently AFK.
- Added location-only principal awareness for the first nearby unsuppressed player shot. It causes cautious relocation without leaking the player's identity; protection damage/casualties and confirmed evidence still escalate to full flight and can force a sheltered target to change safe area.
- Promoted disguise takeover to the first native body-menu action and added a dedicated second action, **Restore original identity**. Removing a disguise restores the original player appearance and clears active disguise persistence while preserving legitimately stolen credentials, consumed sources and learned compromise history.
- Replaced the one-second-only disguise indication with a two-layer native world effect: the existing acquisition/compromise transition plus a restrained persistent cyan identity shimmer (red when compromised) around the player.
- Added regressions for bounded wall overflight, inert transition state, continuous routine target movement, first-shot target awareness, native interaction ordering, explicit disguise removal and persistence cleanup.

## 0.14.6-rc40 — 2026-08-07

- Fixed live drones appearing permanently stationary because patrol/search destinations were replaced every 1.1 seconds before distant waypoints could be reached. Non-tracking destinations are now committed until arrival, a tactical relocation or the idle watchdog invalidates them.
- Replaced the one-shot authored-sector choice with a complete valid-sector search plus twelve deterministic outdoor fallback candidates. A roofed, duplicate or current-position sector can no longer leave an active wing with no patrol route.
- Added a continuous 360-degree body/sensor sweep when geometry genuinely offers no movement destination, so a boxed-in but valid drone remains an active observer rather than staring into one narrow arc.
- Promoted confirmed drone contact from a per-contract slot to the shared map security network. Every HCO wing enters aggressive search, drops stale routes and receives the reported position; response teams receive actionable native contact.
- Alarmed wings retain red searchlights. Individual weapons still require that drone's own completed world raycast, range and gimbal alignment, preserving wall-safe combat.
- Extended native ballistic/laser attribution across all live contract contexts, preventing an armed drone from becoming harmless merely because its own target/detail died while another HCO security team remained active.
- Added regressions for fallback patrol travel, destination commitment, all-contract drone/guard alarm propagation and persistent red network-search presentation.

## 0.14.5-rc39 — 2026-08-07

- Rebalanced social stealth around meaningful proximity risk. A clean disguise remains credible at normal distance with any held or holstered weapon, but a guard with a real native FOV/raycast now performs observer-local close scrutiny inside 150 world units.
- Added an intentional 72-unit point-blank failure boundary. A guard who can genuinely see the player at that distance immediately recognizes that this is not their colleague; red detection now hands control back to the original threaten/startle/surrender/combat path instead of becoming a harmless voice line.
- Sustained close inspection exposes the disguise after a short dwell rather than instantly. Same-unit guards, elites, close protection and the protected target complete that check faster, while broken sight or backing away drains accumulated scrutiny.
- Kept knowledge local at first. The recognizing guard becomes hostile and may open a real interruptible radio report; the uniform is compromised globally only if that report completes or other established network evidence exists.
- Added a compact orange-red `COVER BLOWN` world transition distinct from the global `DISGUISE COMPROMISED` effect, with rate limiting when several nearby guards recognize the player together.
- Added regressions proving that point-blank red recognition enters native hostility, brief close proximity is survivable, sustained close observation becomes hostile, and weapon-neutral medium-distance cover remains intact.

## 0.14.4-rc38 — 2026-08-07

- Fixed the recurring native `advanceFollowerInstructions` / missing `getWatchBack` crash. Every HCO close-protection link now records both leader and follower ownership, and the native `getFollower` boundary atomically rejects that link when the follower has entered alert, combat, fear or another state without the four follower-instruction methods.
- Corrected teardown and reassignment of escort chains. HCO now clears the leader's follower pointer as well as the guard's reverse ownership instead of accidentally clearing only that guard's own child follower.
- Separated alert presentation from identity knowledge. A yellow/red native alert state or a generic last-known hunch no longer tells HCO that an otherwise valid disguised player has been identified, so the protected target and bodyguards do not flee merely because someone is scrutinizing the disguise.
- Kept real escalation authoritative: direct enemy sight, observer-local or global compromise, witnessed overt behavior, explicit gunfire/body/sensor evidence and completed radio propagation still mobilize protection and make the target seek safety.
- Lowered calm social-cover detection to 39%, below the native suspicion success threshold. The timed same-unit identity-check system can still push a close colleague across its 55% radio-check boundary.
- Added live-shaped regressions for a close guard transitioning from a native follower state into combat and for an uninformed target remaining in routine despite native alert presentation.

## 0.14.3-rc37 — 2026-08-07

- Fixed the live one-second disguise failure at its native source. Goon suspicion, alert, body-investigation and combat states contain close-range branches that bypass scaled detection and force combat; HCO now intercepts each instantiated state's player-sight callback while an uncompromised calm identity is active.
- Added a second hard boundary around native `setEnemyInSight(true, player)`. An uninformed observer cannot silently turn suspicion into player-specific hostility, while direct witnesses, compromised identities, aiming and overtly illicit player states still execute the original game behavior.
- Replaced partial detection reduction after changing clothes with a clean observer-local identity rebind. Uninformed guards lose stale full detection, `seenPlayer`, sight target and player-specific enemy-map entries; a guard that actually sees the clothes change remains locally compromised and may complete a real radio report.
- Removed full native detection as proof of identity and added a 54% calm-social-cover ceiling below the 55% radio-check threshold. Same-unit scrutiny can still cross that threshold through the explicit timed identity-check system.
- Added regressions for native instant-detect/combat bypasses, the hard enemy-sight boundary, stale pre-disguise identity data, direct aiming exposure and real takeover witnesses.

## 0.14.2-rc36 — 2026-08-07

- Made disguise recognition completely weapon-neutral. A held, drawn, concealed or holstered weapon of any model or family adds zero identity risk for STAFF, SECURITY and ELITE SECURITY disguises; reloading alone is also ordinary behavior.
- Removed the global five-second exposure applied after every player shot. Only an observer that passes the engine's current vision AABB, FOV and world-raycast path learns that identity; persistent `getSeenPlayer()` memory is deliberately rejected, and a valid radio report may then propagate the current witness's knowledge.
- Removed global combat as a source of identity. An unrelated guard no longer recognizes a disguised player merely because combat exists elsewhere on the map.
- Changed loud-fire, damaged-guard and protection-casualty escalation from forced player contact to a location-based native alert/search. Security receives the incident position but not the player's actor identity until a real observer confirms contact.
- Added regressions for arbitrary held weapons, reload, unobserved fire, direct firing witnesses, unrelated global combat and sound-only response mobilization.

## 0.14.1-rc35 — 2026-08-07

- Rebalanced armed social stealth from the first live disguise pass. A visible weapon matching the stolen guard's native weapon family now carries only baseline scrutiny; a different ordinary Security weapon family raises mild suspicion rather than causing a near-instant reveal. STAFF identities still cannot openly carry a firearm.
- Reduced same-unit, elite and close-protection recognition multipliers so colleagues remain the strongest inspectors without collapsing a fresh valid identity in one glance.
- Replaced the blanket three-second full-exposure window after changing clothes with a short 1.5-second, 25% takeover-risk window. Actual witnesses, aiming, firing and active native combat still expose the player normally.
- Removed HCO's distance-only corpse scan. Body evidence now enters the security network through the game's real `setSeenBody` investigation path or a physical drone cone/raycast, preventing guards from discovering bodies through walls.
- Added regression coverage for visible matching and alternate Security weapon families plus full exposure during native combat.

## 0.14.0-rc34 — 2026-08-07

- Rebuilt disguise acquisition on the engine's real interaction ownership path. HCO now re-enumerates Goon actions, advances the native bit tracker, refreshes interaction caches created before the mod, hooks death/choke/fallen/drop transitions and calls `postInteract` after a successful takeover.
- Captures uniform, weapon family, keycard, keychain, blood condition and familiarity data before native death/choke code strips the source actor. Used bodies remain consumed across checkpoint reloads.
- Added complete STAFF, SECURITY and ELITE SECURITY identity switching with visible player animation variants, matching HCO faction insignia, original-appearance rollback and atomic rejection of incompatible variants.
- Expanded recognition with same-unit/elite/close-protection scrutiny, matching and mismatched weapons, reload states, post-body-interaction exposure, bloodied uniforms, fresh disturbances, target lingering and full vanilla detection during combat.
- Added interruptible native-radio identity checks, locally scoped body knowledge, uniform-class propagation, keycard/keychain restoration, consistent off-limits/trespass queries and source-body drone compromise.
- Added compact world-space cyan/teal/amber/red pixel transitions for acquisition, reload restoration, identity checks and compromise. They attach to the native player draw path and reuse existing game sounds instead of adding a detached HUD/menu.
- Added specification traceability and live acceptance documentation. Automated coverage now exercises the real option-list path, pre-drop identity capture, three identity tiers, credentials, reload, identity checks, compromise and transition rendering.

## 0.13.2-rc33 — 2026-08-07

- Fixed destroyed drones remaining permanently on the first wreck frame. Once the native sensor carrier leaves the dynamic list, its airframe now advances from the persistent per-contract update instead of waiting for another static decor draw.
- Added an explicit crash clock, runtime batch-frame updates and bounded quadtree reinsertion for tumble, sparks and smoke. The fourth asymmetric wreck frame remains cached after the finite effect window ends.
- Added a regression that advances damage frame one to frame two and then the final wreck without calling the decor draw callback between ticks, matching the live-reported failure.

## 0.13.2-rc32 — 2026-08-07

- Moved destroyed airframes from an unreliable direct quadtree texture draw into a second registered native sprite batch dedicated to the wreck atlas. The intact slot is still released atomically, while the tumble stages and final wreck retain their own durable renderer slot until context cleanup.
- Corrected free-fire hit registration for newly fired player bullets. The fallback now covers the engine's real muzzle-to-current segment, including the initial projectile advance that occurs before `activeBullets` insertion, rather than seeing only the latest frame.
- Kept per-drone sweep history so later projectile frames remain bounded and each visible drone is tested independently without requiring right-click aim assistance. Pooled bullet reuse resets all HCO sweep/hit state from the native shot identity.
- Expanded automated coverage for native wreck-batch registration, persistent final-wreck slots and a Heavy rotor-edge hit whose current-frame segment alone no longer crosses the target.

## 0.13.2-rc31 — 2026-08-06

- Added an original generated 4×7 wreck atlas: every Scout, light and heavy family now has impact, damaged tumble, hard-crash and final inert-wreck frames instead of reusing a darkened intact sprite.
- Removed the intact airframe from its shared sprite-batch slot at destruction and switched the native world-quadtree shell to the dedicated wreck texture. Landed drones remain visibly asymmetric, broken and sensor-dark.
- Made destruction terminal before any native callback runs. Detection, tracking, aim targets, queued ballistic bursts, Laser charge/pulse, cooldown and native weapon ownership are cancelled atomically.
- Fully retired the native searchlight buffer by disabling casting/rendering, clearing effects, removing it from render registries and destroying its atlas allocation. A destroyed drone can no longer keep a cone or reacquire the player.
- Added regression coverage for both atlases, intact-slot release, progressive wreck frames, final-wreck persistence, missing wreck outlines, weapon cancellation and complete light-buffer teardown.

## 0.13.1-rc30 — 2026-08-06

- Replaced pathability-only drone placement with Intravenous 2's finalized native roof-obstruction map. Armed drones now deploy, patrol and recover only on fully clear outdoor footprints; roofed patrol-route points and locked interiors are rejected.
- Added deterministic local outdoor search plus a spawn-only whole-map fallback, so large covered compounds retain drone support without accepting an unreachable indoor attacker.
- Changed walls, doors, windows, roofs and map boundaries into hard flight constraints while retaining intentional traversal over low outdoor cover.
- Made native raycast completion mandatory for player acquisition and attacks. Missing or failed geometry queries now mean no detection and no fire instead of optimistic wall vision.
- Added a combat-readiness invariant: no drone may attack unless its visible airframe, centered Box2D bullet target and outdoor position are all valid in the same update.
- Deployment now fails closed when a physical hitbox cannot be created. A hitbox lost at runtime is repaired briefly; persistent invisible/unhittable carriers are inert and quietly retired.
- Kept deployment requests queued until the engine finishes building roof data and throttled tracking-destination refreshes to avoid map-query churn.
- Added regressions for roofed path tiles, indoor-to-outdoor migration, strict geometry authority, roof-map readiness and automatic retirement of persistently unhittable drones.

## 0.13.0-rc29 — 2026-08-06

- Added native-difficulty balance snapshots. Easy/Normal/Hard/True and bounded Custom settings now scale response count, guard/target health, drone count, sensor range/acquisition, displayed threat and payout together.
- Added archetype threat ratings I–V to the compact native contract announcement without increasing its two-line footprint.
- Preserved five close bodyguards at every difficulty while scaling only autonomous response strength; target and guard durability now follow both archetype and difficulty.
- Added a twelve-airframe global fleet ceiling and hard per-contract limits of two Heavy and two Laser models, preventing up to three simultaneous contracts from producing an unreadable 21-drone swarm.
- Rebalanced baseline acquisition from 0.25 to 0.55 seconds before model, doctrine, mode and difficulty modifiers. Routine patrols are readable; confirmed aggressive pressure remains fast.
- Integrated social stealth with drone identity sensing. Calm plausible disguises slow routine acquisition without granting immunity, while aiming, sprinting, firing, incompatible equipment or compromise restores full scrutiny.
- Added real cone-and-raycast body evidence scans. Drones report each exposed dead/unconscious NPC once, escalate security, request support and compromise the stolen identity if its source uniform is discovered.
- Added type-specific cyan/amber/red/violet flight effects, an expanding evidence-scan pulse, true Laser charge-progress rings, heavy-damage smoke/wobble and weight/pitch-aware spatial crash audio.
- Kept release diagnostics disabled by default so internal RC airframe probes never leak into the normal mission HUD.
- Expanded automated coverage for difficulty tuning, fleet composition limits, disguise-aware acquisition, drone body evidence, source-uniform compromise and the complete RC28 combat/crash regression set.
- Published all seven LÖVE 11.5 smoke harnesses with a portable repository test runner so external maintainers can reproduce the automated RC gate without machine-local paths.

## 0.12.4-rc28 — 2026-08-06

- Expanded Scout/light/heavy bullet targets to 44/48/54 world units so the physical target covers the complete rotated rotor silhouette instead of only its central body.
- Derived the post-world projectile fallback radius from the actual 96-pixel atlas cell and model render scale, keeping native-fixture and fallback targeting consistent at visible corners.
- Added a runtime fixture watchdog that rebuilds a missing or destroyed Box2D body/fixture and continuously resynchronizes it with the visible aim center.
- Replaced instant airframe removal with a weight-sensitive crash lifecycle: last-vector travel, rotor-loss tumble, pixel smoke and sparks, an expanding impact ring, scattered debris and a persistent dark wreck.
- Moved crash evidence and response investigation to the computed landing point and added deterministic regression coverage for rotor-edge hits, fixture recovery, crash motion, landing state and context cleanup.

## 0.12.3-rc27 — 2026-08-06

- Rebalanced drones as fragile tactical threats: every Scout/light model is a strict one-hit target, Heavy Pistol has two armor points, and Heavy SMG/Laser have three. Doctrine scaling can never push a heavy model beyond three hits.
- Added weapon-aware armor damage using the native bullet damage and armor-penetration APIs. Ordinary rounds remove one point and strong rifle/hand-cannon rounds remove two, but every heavy model always survives its first hit: large drones consistently take two or three shots.
- Replaced the nearly invisible five-pixel hit flash with a 0.42-second tinted airframe flash, expanding impact ring, nine-pixel spark burst and a temporary two/three-pip armor readout.
- Increased spatial ricochet feedback and let the wall-safe projectile fallback process every intersecting pellet/projectile in the frame until the drone breaks.
- Added regression coverage for one-hit light armor, bounded heavy armor, normal-versus-high-caliber damage, impact state propagation and visible spark/pip rendering.

## 0.12.2-rc26 — 2026-08-06

- Fixed the native `getWatchBack` crash after long missions: autonomous response units are no longer inserted into close-protection follower chains before being reassigned to search/combat states.
- Corrected generic-object/Box2D coordinate semantics. The moving bullet fixture now follows the visible aim center instead of the airframe's top-left corner, which had placed the visible center on the fixture edge.
- Added a player-projectile path fallback for runtime combinations that do not expose a late-created generic-object fixture to the native raycast. It runs only after native bullet/world processing, so solid geometry remains authoritative.
- Added regression coverage proving response units remain autonomous, protected-target/bodyguard follower chains never retain them, the physical body follows the visible aim center and an actual one-frame player bullet path destroys a light drone.

## 0.12.1-rc25 — 2026-08-06

- Added a native path-grid flight-footprint check so drones steer around walls, closed doors, windows and high obstructions while remaining able to cross low cover.
- Added deterministic alternate-heading recovery instead of letting a blocked drone stop or push through a building boundary.
- Added a 0.55-second idle watchdog that invalidates stale destinations and advances the flank/search phase when a drone has stopped moving unexpectedly.
- Increased tactical movement variety with stronger tracking sway, changing standoff range and continued deterministic search relocation.
- Added regression coverage for active wall avoidance, blocked-tile containment and idle recovery without sacrificing the existing speed, world-edge and wing-separation limits.

## 0.12.0-rc24 — 2026-08-06

- Reduced all seven runtime airframes to 0.32/0.35/0.39 scout/light/heavy scale instead of the former 0.32–0.57 oversized family.
- Fixed moving-drone counterplay: runtime cameras now rebuild an explicit bullet-hitable fixture, move that Box2D body with the visible airframe every frame and expose a centered aim position.
- Added aggressive tactical contact: recent shared intelligence plus direct line of sight starts tracking immediately instead of waiting for a passing scan cone.
- Added deterministic timed search rings around the last known position and periodic left/right flank relocations during sustained contact. Each drone receives distinct angles, radii and timing while retaining world-floor snapping and the RC23 speed caps.
- Added regression proof for hitbox creation/body synchronization, centered aiming, ordinary bullet destruction, compact model scales, flank relocation and lost-contact exploration.

## 0.11.1-rc23 — 2026-08-06

- Fixed the live `drawOutline` crash (`xOff` was nil) when the player aimed at a runtime drone. Aim highlighting now delegates to the real HCO airframe sprite instead of the invisible native camera carrier.
- Reduced ordinary and aggressive flight speeds and added hard 64/108 world-unit-per-second patrol/aggressive caps so archetype doctrine can no longer create extreme pursuit bursts.

## 0.11.0-rc22 — 2026-08-06

- Replaced the single drone body with a seven-row runtime atlas: Scout plus light/heavy Pistol, SMG and Laser designs.
- Separated body heading from sensor heading. The airframe follows its velocity while a constrained gimbal tracks the player and yaws the body only after reaching its mechanical limit.
- Replaced player-centered orbiting with stable standoff formation slots, small breathing motion, last-known search sectors, varied deterministic entry points and hard world-bound clamping.
- Snapped endpoints through the native pathfinding floor grid, added 84-unit wing separation during spawn and flight, and avoided duplicate models while unused roster rows remain. Drones may cross low obstacles but no longer choose unreachable void as a destination or stack inside one another.
- Fixed the native security-camera update ordering that previously overwrote HCO's sensor angle every frame and made a locked cone sweep away from the player.
- Added armed escalation wings. Pistols and SMGs use engine-created native bullets and sounds; light/heavy lasers require uninterrupted aim and line of sight through a visible 0.9/1.4-second charge before dealing damage.
- Kept the Scout unarmed and every model destructible/disruptable. Light models take one hit; heavy models use reinforced doctrine-scaled armor.
- Enlarged the physical aimable carrier to match each light/heavy silhouette and added ricochet audio plus visible hit sparks so reinforced armor hits are legible before destruction.
- Added custom light/heavy rotor loops and laser fire assets adapted from creator-supplied source audio.
- Added deterministic coverage for the seven-model roster, world bounds, stable tracking slots, independent gimbal movement, native bullet creation and delayed laser damage.

## 0.10.0-rc21 — 2026-08-06

- Reduced the native drone airframe from the oversized first live pass to a roughly 27-pixel world footprint and rotated the source artwork by -90 degrees so its sensor nose follows the scanlight and flight heading.
- Added native-world flight presentation: subtle hover bob, offset altitude shadow, animated rotor pulses, state-colored sensor pulse and a short pixel wake opposite the current movement vector.
- Made electronic disruption authoritative for both the native camera carrier and HCO detection; a disrupted drone now flickers and cannot confirm or relay the player.
- Completed bullet destruction behavior: a destroyed drone loses its light and airframe, stops its rotor sound, creates localized crash evidence, raises the local hunt state and sends up to three available response guards to investigate.
- Kept baseline drones information-first rather than adding unavoidable hitscan damage. A separately telegraphed, counterable armed Hunter/Interceptor remains an explicit future item.

## 0.10.0-rc20 — 2026-08-06

- Replaced the external drone overlay with a registered native `hco_drone_airframe` world entity.
- Airframes now enter the same decor-quadtree visibility lifecycle used by enemies and other drawable world entities.
- Added a dedicated engine-managed sprite batch at depth 68; quadtree drawing updates its slots immediately before the native priority renderer runs.
- Kept the security-camera carrier only for physics, searchlight, obstruction and bullet interaction, with the native airframe synchronized to it.
- Added a texture-independent quadtree fallback and a diagnostic that separately reports quadtree draw activity, sprite-batch readiness, texture readiness and body count.

## 0.10.0-rc19 — 2026-08-06

- Fixed the live map-transition failure where the engine rebuilt `priorityRenderer.renderOrder` but HCO retained a stale `activeRenderMap` registration.
- The runtime now validates the actual render list every half-second and safely reinserts the drone layer whenever a map or renderer reset removes it.
- Updated the one-shot airframe diagnostic to identify RC19 explicitly.

## 0.10.0-rc18 — 2026-08-06

- Decoupled drone rendering from faction/NPC visual initialization so a temporarily unavailable goon class can no longer disable drone bodies for the whole session.
- Added an idempotent live retry for engine builds that expose `priorityRenderer` only after local mods initialize.
- Replaced the fragile wrapped draw function with a native `priorityRenderer` layer registered at the final world-space priority.
- Added a high-contrast procedural quadrotor silhouette over the flight sprite, including a texture-independent fallback.
- Reduced confirmed-contact acquisition to 0.25 seconds in aggressive mode and 0.35 seconds during patrol while retaining cone, range, and obstruction checks.
- Rate-limited repeated confirmed-sighting dispatches while keeping response-team knowledge and combat orders current.

## 0.10.0-rc17 — 2026-08-06

- Corrected RC16's install-layout diagnosis after decompiling `love.filesystem.loadMods()`: local mods explicitly load `<mod>/files/main.lua`.
- Restored the required nested `files/` archive layout and local installation.
- Moved drone drawing to the final `priorityRenderer:draw()` world pass, immediately before the camera transform is removed.
- Added a one-shot in-game diagnostic reporting renderer activity, sprite load state, and registered airframe count.
- Accepted unobstructed raycasts that reach fraction `1`, matching native combat visibility handling.

## 0.10.0-rc16 — 2026-08-06

- Fixed the release archive layout: `main.lua`, `hco/`, and `assets/` are now packaged at the mod root instead of below an ignored `files/` directory.
- Corrected manual installation instructions and explicitly require removal of stale older mod directories.
- Added package validation that fails unless root `main.lua`, `hco/config.lua`, and the drone flight sheet exist in the ZIP.
- Identified and corrected a live local installation where RC8 at the real mod root shadowed RC12–RC15 files under a nested directory.

## 0.10.0-rc15 — 2026-08-06

- Corrected the render hook after engine inspection proved that the main renderer never invokes `world:postDraw()`.
- Drone bodies now render immediately after `world:drawActors()` while the world camera transform is active.
- Replaced stationary-camera detection assumptions with explicit distance, cone-angle, and obstruction checks.
- Added a short sight-contact grace period so a moving drone cannot lose a player between adjacent samples.
- Reduced aggressive confirmation time to 0.55 seconds and passive patrol confirmation to roughly one second.
- Added deterministic coverage for sustained in-cone player detection and confirmed drone sightings.

## 0.10.0-rc14 — 2026-08-06

- Fixed invisible drone bodies while their searchlights remained active.
- Moved animated drone drawing from the skipped runtime-camera `postDraw` path into a dedicated world render hook.
- Added an active-drone render registry with automatic pruning of broken or removed drones.
- Increased the bundled flight-sheet render scale slightly for clearer in-game readability.
- Added fixture coverage proving every active drone is drawn once while the native world render pass is preserved.

## 0.10.0-rc13 — 2026-08-06

- Fixed the live `quadStruct` crash caused by sending runtime-created camera carriers through finalized native sprite batches.
- Drone carriers now bypass native sprite updates and use the bundled animated flight sheet for rendering.
- Replaced simultaneous fading-text indicators with a deduplicating sequential notification queue.
- Moved HCO tactical notices to the lower third to avoid native objective announcements.
- Made contract completion the only notification that can pre-empt stale tactical messages.
- Reset pending notifications across map unload, reset, level completion, and main-menu transitions.

## 0.10.0-rc12 — 2026-08-06

- Replaced late custom drone-class creation with per-instance behavior on an engine-owned security-camera carrier.
- Kept a visible native drone body when the custom flight sprite is unavailable and removed the invalid camera-booth dependency from drone destruction.
- Added exact on-screen drone spawn/runtime diagnostics instead of a silent `INBOUND` dead end.
- Split protection into five close bodyguards and archetype-scaled 5/10/15/20 response units.
- Fixed the confirmed-hostile-contact path so it mobilizes the full response rather than only queuing drones.
- Prevented HCO from ordering the target into combat and continuously reasserted its native fear-run escape state when vanilla perception tries to re-enter combat.
- Added a compact response deployment notice containing the actual number of available response units.

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
