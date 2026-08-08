# Hitman Contracts Overhaul

## Product and Technical Specification

**Status:** Source of truth; Phase 0–5 RC implemented, automated validation complete, final in-game validation pending  
**Target game:** Intravenous 2  
**Verified game version:** 1.4.12HF3  
**Working title:** Hitman Contracts Overhaul  
**Short name:** HCO  
**Document purpose:** Preserve all product decisions, technical findings, implementation boundaries, phases, and acceptance criteria for future Codex agents and human contributors.

---

## 1. Executive summary

Hitman Contracts Overhaul adds optional assassination contracts to compatible campaign missions and combines them with a native-feeling social-stealth and security simulation.

Each supported mission may contain an additional high-value target. The target is not a stationary objective or a bullet-sponge boss. It follows a believable routine, moves between authored or derived locations, is protected by elite security, retreats into safer areas when threatened, and may attempt to escape during a confirmed attack.

The player can complete the contract through direct combat, conventional stealth, stolen uniforms, stolen credentials, sabotage, or carefully manipulated security responses. The system must integrate with Intravenous 2's existing objectives, interactions, suspicion feedback, inventory, keycards, cameras, radio behavior, weapons, money, saving, and mission lifecycle. It must not feel like a separate minigame or an unnecessary overlay.

The first implementation is a narrow vertical slice: one compatible mission, one selected target, one mobile routine, one elite escort group, one native optional objective, one reward, and one functional disguise class. Later phases expand the same systems rather than replacing them.

### Live-validation expansion decision — 2026-08-06

The vertical slice has now been observed working in a real `1.4.12HF3` campaign mission. The full product direction is expanded as follows:

- Compatible large maps may host one to three simultaneous contracts. Count is deterministic but varies by map capacity and seed.
- Every target, escort, objective, marker, reward, terminal state, and disguise/security reference must be contract-scoped. Targets and guards may not be shared between active contracts.
- Protection is deliberately intimidating: Broker 5, Executive 8, Fixer 11, and Commander up to 15 guards when the map has enough safe non-story actors.
- The protection pool may recruit safe armed unnamed goons without an existing patrol route; the actual contract target still requires a validated mobile route.
- Guards use native elite competence and health, layered roles, radios, existing strong weapons, physical search routes, and fair information propagation. Targets remain lethal rather than becoming bullet sponges.
- The desired sensor escalation includes audible and visible drone or thermal-surveillance pressure. Engine inspection found no native drone or thermal actor/API in `1.4.12HF3`, so physical drones require a custom actor, presentation assets, navigation, damage/disruption behavior, and explicit counterplay; camera/radio/search integration is not to be mislabeled as a physical drone.
- Money is paid through `game.playthrough:changeMoney`; native objective `funds` auto-claim is forbidden because it dereferences the hideout-only `studio` global and crashes campaign missions.

---

## 2. Vision

The intended player reaction is:

> "This feels like it was always supposed to be part of the game. I cannot believe how much deeper the same mission became."

HCO should make existing maps support a second layer of infiltration without rewriting the main campaign. A familiar mission should become meaningfully different because the target, its security detail, and the player's social identity create new opportunities and new failure states.

The mod is not a quest log, a challenge checklist, a stat dashboard, or a generic mutator pack. It is a systemic expansion of the game world.

---

## 3. Non-negotiable design pillars

### 3.1 Native first

- Use the existing objective list for contracts.
- Use existing interaction prompts for bodies, credentials, and disguises.
- Use existing suspicion and detection feedback wherever possible.
- Use existing money and skill systems for rewards.
- Use existing actor, patrol, alert, radio, keycard, camera, and pathfinding systems.
- Add new UI only when no native surface can communicate the required information.
- Never require a permanent floating contract dashboard.
- Never require a separate out-of-game executable.

### 3.2 Systemic, not scripted theater

- Target behavior reacts to actual world state.
- Security knowledge propagates through observation, nearby warnings, cameras, and radio.
- A compromised disguise is caused by discoverable evidence and communicated knowledge.
- Guards search last-known areas rather than reading the player's current coordinates.
- Darkness, noise, doors, bodies, credentials, weapons, and access levels interact consistently.

### 3.3 Lethality stays Intravenous

- Targets are not health-sponges.
- A clean headshot or appropriately powerful hit can kill a target.
- Difficulty comes from access, positioning, protection, sensors, response, and escape pressure.
- Elite guards may have better armor, weapons, awareness, and tactics, but they remain governed by normal damage rules.

### 3.4 Fair counterplay

- Every strong security feature must have readable behavior and at least one counter.
- Thermal cameras do not see through solid walls.
- Drones require line of sight and can be disrupted or destroyed.
- Radio calls take time and can be interrupted.
- A target escape must be telegraphed and must use a physical route.
- Search teams use evidence and last-known information, not omniscience.

### 3.5 Campaign safety

- Contracts are optional unless a future dedicated HCO campaign explicitly says otherwise.
- Failure or target escape must never block the original mission.
- Story-critical actors must never be selected as random targets.
- HCO data must be namespaced and must not corrupt vanilla saves.
- If a map is unsupported or cannot produce a safe contract, HCO quietly skips it.

---

## 4. Core player loop

1. A compatible mission begins.
2. HCO deterministically creates or restores a contract for the mission.
3. The native objective display announces the target, broad location, and reward.
4. The target begins a believable routine among valid locations.
5. The player gathers access through observation, stealth, stolen clothing, credentials, or force.
6. Security reacts to suspicious behavior and evidence.
7. The target adapts to the threat: routine, caution, relocation, lockdown, or evacuation.
8. The player kills or neutralizes the target, or the target escapes.
9. Contract resolution is communicated through the native objective system.
10. A successful contract grants normal campaign money and, where technically safe, normal earned skill experience.
11. The original mission continues normally.

---

## 5. Contract lifecycle

### 5.1 Eligibility

A contract may start only when all required conditions are true:

- The world and player actor exist.
- The map is explicitly supported or passes a conservative generic compatibility check.
- The mission is not a cutscene-only map, hideout, tutorial segment, or known story-sensitive sequence.
- There is at least one eligible non-story NPC or a validated spawn profile.
- There are enough valid navigation locations for a mobile target.
- The native objective handler can accept the optional objective without replacing existing objectives.

### 5.2 Deterministic selection

Each contract has a seed based on stable mission and playthrough information. The seed controls:

- target archetype;
- eligible target selection or target spawn profile;
- initial routine;
- safe-area ordering;
- escort composition;
- reward range;
- optional conditions.

Reloading a save must not reroll the contract into an easier result. Restarting a mission should normally preserve the contract for fairness and reproducibility. A future setting may permit full rerolls, but it is not part of the first release.

### 5.3 Contract states

- `INACTIVE`: no contract for this map.
- `PREPARING`: world exists; target and security are being validated.
- `ACTIVE`: target is alive and contract can be completed.
- `COMPLETED`: target was killed or neutralized according to the contract.
- `FAILED_ESCAPED`: target physically reached an escape point.
- `FAILED_INVALID`: target became invalid because of an external script or incompatible map behavior.
- `CLEANED_UP`: hooks, markers, listeners, and temporary references are removed.

`FAILED_INVALID` must fail quietly and must never punish the player.

---

## 6. Target system

### 6.1 Target identity

Every contract target receives runtime metadata:

- stable HCO contract ID;
- target display name;
- archetype;
- security tier;
- routine node set;
- safe node set;
- evacuation node set;
- escort references;
- current target state;
- threat knowledge;
- last valid position and movement progress;
- completion and escape status.

The target should use a normal actor class whenever possible. New actor subclasses are allowed only when the vanilla actor cannot safely express required behavior.

### 6.2 Target archetypes

Initial archetypes:

- **Executive:** avoids fighting, relies on security, evacuates early.
- **Fixer:** armed, cautious, changes rooms regularly, may fight when cornered.
- **Commander:** heavily protected, can coordinate nearby guards, retreats methodically.
- **Broker:** moves between public and restricted zones, creating strong disguise opportunities.

Later archetypes:

- paranoid recluse;
- corrupt official;
- field operative;
- protected witness;
- mobile convoy leader.

### 6.3 The target must not be stationary

The target owns a dedicated movement director. It moves for a reason, not simply to create noise.

Routine locations may include:

- office or workstation;
- meeting point;
- balcony or smoking area;
- security room;
- storage or archive room;
- dining or break area;
- patrol inspection point;
- private room;
- vehicle or exit staging area.

The target pauses for a believable duration, performs an available idle interaction when possible, then selects another suitable node.

Generic missions derive a stable routine from existing safe Goon patrol points rather than accepting the selected actor's tiny route as the whole contract space. When the map supplies enough candidates, the director chooses five to eight deduplicated nodes across several selector-approved security sectors, varies their order from the persisted contract seed and keeps adjacent legs bounded. The route is handed to the native Goon idle/path/door machinery. Sparse or fragmented maps fail back to the untouched original patrol route; no arbitrary off-grid point or teleport is allowed.

### 6.4 Target behavior state machine

#### `ROUTINE`

- Selects from public and semi-private routine nodes.
- Traverses at least five distinct nodes across several sectors when the compatible map exposes them.
- Moves with normal escort spacing.
- May occasionally remain in place for 8-25 seconds.
- Avoids repeating the same two nodes in a loop; checkpoint reload reconstructs the same contract-specific route.
- Does not know the player's location.

#### `UNEASY`

Triggered by local suspicion, a disrupted camera, a missing check-in, nearby noise, or an unexplained body that has not yet confirmed an attack.

- Cancels low-security destinations.
- Moves toward a semi-secure node.
- Close escort tightens formation.
- Outer guards may inspect the disturbance.
- Returns to `ROUTINE` only after a substantial calm period and no confirming evidence.

#### `THREATENED`

Triggered by confirmed hostile activity, a compromised perimeter, a nearby body, a direct sighting, or a security message.

- Chooses the best currently viable safe node.
- Uses a physical path.
- Close escorts move with the target.
- Security guards cover likely approaches.
- The target may lock or pass through controlled doors using assigned credentials.
- If the chosen safe node becomes compromised, another is selected.

#### `SHELTERED`

- Remains inside a validated secure area.
- Re-evaluates safety periodically.
- May move between two defensive positions to avoid becoming trivially static.
- May initiate evacuation if pressure continues, the safe area is breached, or too many guards are lost.

#### `EVACUATING`

- Chooses a validated exit or extraction node.
- The route is physical and interruptible.
- Remaining guards form a moving escort or delay the player.
- The objective displays a native warning that the target is escaping.
- Reaching the extraction node resolves the contract as escaped.

#### `CORNERED`

Archetype-dependent behavior:

- surrender;
- hide;
- use a sidearm;
- move between nearby cover;
- attempt one final alternate escape route.

#### `NEUTRALIZED`, `DEAD`, `ESCAPED`

Terminal states.

### 6.5 Secure-area selection

A safe node has attributes:

- minimum security tier;
- map position;
- optional associated room or area ID;
- nearby door count or controlled door reference;
- camera coverage;
- guard capacity;
- escape route availability;
- whether it is suitable during a power outage;
- whether it is compromised.

Selection score should consider:

- distance from player last-known position;
- distance from current target position;
- path validity;
- living guard presence;
- intact camera coverage;
- controlled-door availability;
- known bodies or disturbances nearby;
- whether the player was recently seen in the area;
- whether the node was used recently.

The highest score is not always selected. A small deterministic variance prevents identical behavior while preserving reproducibility.

### 6.6 Anti-stuck movement contract

Mobile targets must never become permanently stuck and invalidate the contract.

The target director records movement progress at a low frequency. It checks:

- current destination;
- path existence;
- distance to destination;
- distance reduction since last sample;
- actor state compatibility;
- number of recent path failures;
- time spent without meaningful progress.

Recovery sequence:

1. Ask the native destination/path handler to adjust the destination.
2. Recompute the path to the same node.
3. Select a different valid node of the same security tier.
4. Fall back to the nearest validated pathfinding tile.
5. Cancel relocation and enter a temporary defensive hold if no route is safe.

Teleportation is not a normal recovery mechanism. If a future last-resort teleport is ever added, it may occur only when the target is far off-screen, not visible to the player, and after a long irrecoverable failure. The initial release must not teleport targets.

Acceptance requirement: no target may remain in a failed movement state for more than ten seconds without a recovery action.

### 6.7 Target marking

- Use native objective tracking and position indicators.
- Do not permanently reveal the target through walls.
- Initial information may mark a broad search area rather than exact coordinates.
- Exact tracking may be granted after obtaining a phone, terminal record, camera observation, or target confirmation.
- A confirmed visual may briefly update the marker.
- Losing intelligence may return the marker to an approximate area.

The vertical slice may use a direct native position marker as a temporary development simplification, but the full design uses imperfect intelligence.

Implementation note for `0.9.0-rc2`: the RC intentionally retains the direct native moving marker so the first end-to-end gameplay test can validate target selection, movement, escape, and reload behavior without an additional intelligence layer. Imperfect-information tracking remains a post-RC improvement and is not silently claimed as complete.

---

## 7. Security ecosystem

### 7.1 Security roles

- **Close protection:** stays near the target and prioritizes evacuation.
- **Outer security:** controls approaches and investigates disturbances.
- **Response unit:** uses strong weapons and reacts to confirmed danger.
- **Radio operator:** propagates high-confidence information and requests backup.
- **Camera operator:** monitors camera alerts and disruptions.
- **Drone operator:** supports drone deployment in later phases.

### 7.2 Elite guard properties

Elite guards may receive:

- elite native experience level;
- stronger but existing weapons;
- armor appropriate to the mission;
- radios and flashlights;
- increased vision competence within fair limits;
- better cover and backup behavior;
- lower likelihood of abandoning the target without reason;
- role-specific priorities.

They must not receive exact player coordinates without a valid information source.

### 7.3 Moving security bubble

Security moves with the target in layers:

- one or two close guards remain within a short leash;
- one advance guard may move toward the next routine node;
- outer guards remain at useful choke points or nearby patrol routes;
- during evacuation, the formation compresses and response units cover rear approaches.

If an escort cannot path with the target, it must not block the target. The escort either chooses a nearby reachable support position or relinquishes the close-protection slot to another living guard.

---

## 8. Security knowledge and hunt behavior

### 8.1 No hive mind

Each security actor has knowledge rather than universal truth:

- last known player position;
- last known disguise class;
- visible weapon or behavior;
- confidence;
- timestamp;
- source: direct sight, nearby warning, camera, radio, body, sound, or alarm.

Knowledge can be shared through:

- nearby warning;
- completed radio transmission;
- camera operator response;
- alarm panel interaction;
- direct observation.

### 8.2 Hunt phases

- `LOCAL_REACTION`: nearby guards respond to direct evidence.
- `CONTAIN`: exits and key approaches are covered.
- `SEARCH`: teams inspect the last-known sector and adjacent rooms.
- `PRESSURE`: confirmed sightings cause flanking and suppression.
- `DECAY`: confidence falls when no new evidence appears.
- `STAND_DOWN`: guards return to heightened patrol rather than instantly forgetting.

### 8.3 Smart search requirements

- Search the last-known location first.
- Expand through physically connected areas.
- Check likely escape routes, doors, vents, and hiding areas when supported by the map.
- Avoid a single-file rush into a known kill zone.
- Use two-person teams where enough guards remain.
- Leave protection with the target.
- Do not endlessly converge on the player's live coordinates.

---

## 9. Disguise and social-stealth system

### 9.1 Acquiring a disguise

Eligible unconscious or dead NPCs expose a native body interaction:

- `Search body`
- `Take keycard`
- `Steal uniform`

The initial version may combine these into a single context action if the native interaction list cannot safely show multiple entries.

### 9.2 Disguise data

A disguise contains:

- uniform class;
- faction or security company;
- access tier;
- source actor ID;
- clean or compromised state;
- bloodied or visibly damaged state;
- source weapon metadata for persistence/appearance only, never recognition;
- familiarity group;
- acquisition timestamp.

Initial uniform classes:

- civilian/staff;
- regular security;
- elite security;

### 9.3 Recognition model

Disguise effectiveness modifies detection; it does not make the player invisible.

Suspicion factors:

- distance;
- time observed;
- observer experience;
- same-unit familiarity;
- restricted-zone mismatch;
- running or sprinting;
- aiming;
- firing when directly observed;
- lockpicking, bashing, sabotage, or body interaction;
- blood or damage on the disguise;
- compromised uniform class;
- player proximity to a fresh disturbance;
- repeated lingering near the target.

Normal walking with a valid uniform remains credible at medium distance regardless of the held weapon, weapon family or holster state. Elite or same-unit guards identify behavioral and identity inconsistencies faster, but do not infer hostility from equipment alone.

### 9.4 Access tiers

- `PUBLIC`: civilians and all uniforms allowed.
- `STAFF`: staff or security uniform required.
- `SECURITY`: security uniform required.
- `ELITE`: elite security identity or credentials required.
- `PRIVATE_TARGET`: only target, close protection, and specifically authorized identities.

Access checks should reuse the game's off-limits and frustration/suspicion behavior rather than create a completely separate detection channel.

### 9.5 Weapons and behavior

- Held weapon model, weapon family and holster/concealment state add no disguise risk for any identity tier.
- Reloading by itself is ordinary behavior and does not break social cover.
- Aiming at a person breaks social cover for observers that can actually see it.
- Gunfire compromises the current disguise only to direct visual witnesses and recipients of a completed report.
- Heard but unseen gunfire creates a location-based investigation at the shot origin; it never supplies the shooter's actor identity.
- A global alert or combat state elsewhere on the map contains no identity information. Uninformed observers remain uninformed until sight, body evidence, camera/drone evidence or radio communication establishes a link.

### 9.6 Compromised disguises

When the source body is discovered and correctly processed:

1. The investigating guard identifies missing clothing or credentials.
2. The guard gains a high-confidence disguise warning.
3. Nearby guards are warned.
4. If radio is available and undisrupted, the warning is transmitted.
5. Recipients treat that disguise class as compromised for the contract.

If the body is hidden or the radio call is interrupted, global compromise does not occur. Direct witnesses may still know.

Compromise can be scoped:

- specific stolen identity;
- uniform class;
- faction-wide, only at maximum alert.

The first implementation uses uniform-class compromise because it is observable and testable. Later versions may distinguish individual identities.

### 9.7 Appearance

The player must visibly change enough for the mechanic to be readable. Preferred order:

1. Reuse an existing compatible actor animation/appearance set.
2. Apply a dedicated uniform layer or color/variant supported by player sprites.
3. Add authored player-compatible sprites for missing uniforms.

Detection logic must not ship without any visual indication that a disguise is active.

---

## 10. Keycards and credentials

- NPCs may already carry keycards or keychains.
- Searching or neutralizing eligible guards may expose their credentials.
- HCO should use native keycard objects and door verification.
- Contract targets and elite guards may receive access appropriate to their safe areas.
- A uniform and a keycard solve different problems: clothing reduces suspicion; credentials open controlled access.
- A stolen keycard may remain valid even after a uniform is compromised unless security explicitly enters a future credential-lockdown state.

---

## 11. Cameras, thermal cameras, and drones

### 11.1 Existing cameras

- Integrate with native security camera behavior.
- Disguises affect camera suspicion based on zone and visible behavior.
- Broken or disrupted cameras create security information, not instantaneous omniscience.
- Camera operators are meaningful security roles.

### 11.2 Thermal cameras

Thermal cameras are a later system built on the native camera class where possible.

Rules:

- require line of sight;
- ignore normal darkness penalties;
- do not see through solid walls;
- may have wider long-range detection but readable sweep behavior;
- can be disrupted by EMP/disruptor effects;
- can be disabled through power or operator sabotage;
- may be partially degraded by dense smoke or environmental obstruction if technically supportable.

### 11.3 Drones

Drones began as phase-three content outside the first playable slice. The RC6 decision in section 26 promoted physical search drones into the active release candidate; RC21 adds the native-airframe and counterplay decisions that now govern them.

Rules:

- follow authored patrol zones or validated aerial paths;
- use line of sight and a visible sensor direction;
- detect exposed weapons, bodies, or unauthorized identities;
- update a last-known position rather than track through walls;
- communicate through radio/security systems;
- can be shot down or electronically disrupted;
- crashing or disappearing creates a localized alert;
- must have unique sprites, sounds, and readable states.

---

## 12. Contract types

Initial:

- eliminate target;
- neutralize target.

Expansion:

- eliminate without raising a confirmed alarm;
- eliminate without civilian casualties;
- neutralize and extract intelligence;
- steal data from the target, then optionally eliminate;
- prevent target escape;
- eliminate while preserving the close-protection team;
- staged accident or environmental kill, only if the map supports it;
- specific weapon-family condition;
- no-disguise or disguise-only variant.

Optional conditions increase rewards. They should not obscure the primary contract condition.

---

## 13. Rewards and progression

- Use normal campaign money.
- Manual HCO rewards must be granted once only.
- Rewards become persistent through the normal campaign save path.
- The contract seed and resolution state must prevent duplicate reward exploits after reload.
- Earned skill experience may be granted only after the exact progression path is verified.
- Do not add a separate contract currency in the initial product.
- Do not add an external progression tree merely to inflate scope.

Reward drivers:

- target security tier;
- map difficulty;
- optional conditions;
- alarm state at resolution;
- target escape risk;
- non-lethal extraction versus elimination.

---

## 14. Native presentation

### 14.1 Allowed presentation

- existing objective list;
- existing objective start indicator;
- existing position indicator;
- existing interaction prompts;
- existing pickup notifications;
- existing suspicion/detection visualization;
- mobile dialogue or radio lines;
- existing money/reward feedback;
- subtle outline or icon behavior already used by the game.

### 14.2 Disallowed presentation

- permanent custom contract dashboard;
- floating health bar above the target;
- MMO-style quest arrows visible through all geometry;
- custom currency panel;
- separate F-key menu during normal play;
- constant textual explanation of AI state;

### 14.3 Required player information

The player must be able to understand:

- who the target is;
- approximate target area or last known information;
- current primary contract condition;
- whether the target is escaping;
- whether a disguise is active;
- whether the current disguise has become compromised;
- whether the contract completed or failed.

This information should be delivered with the least new UI possible.

---

## 15. Map compatibility model

### 15.1 Authored profiles

High-quality support uses a profile per map:

- excluded story actor IDs;
- eligible target actor IDs or spawn definitions;
- routine nodes;
- safe nodes;
- evacuation nodes;
- security anchor nodes;
- restricted zones;
- camera and power relationships;
- target archetype whitelist;
- unsupported mission phases;
- reward modifier.

### 15.2 Generic fallback

Generic mode may select an existing eligible goon and reuse its patrol route. It must remain conservative:

- never select named/story NPCs;
- never select actors referenced by vanilla objectives;
- require a valid active patrol route or several reachable fallback points;
- require enough other guards to create protection;
- skip the map when confidence is low.

Generic support is not a substitute for authored profiles on important campaign maps.

---

## 16. Persistence and reload semantics

Persist:

- contract seed;
- selected target identity or reconstruction data;
- target state where safe;
- contract completion/failure;
- reward-granted state;
- active disguise;
- compromised disguise classes;
- relevant security knowledge only when save compatibility allows it.

On mission reload:

- the same contract must be reconstructed;
- rewards must not duplicate;
- target and escort references must be rebound by stable IDs, never stale Lua object references;
- invalid references must fail closed and skip the contract rather than crash;
- vanilla mission state must remain authoritative.

On returning to the main menu:

- remove dynamic listeners;
- clear runtime actor references;
- restore hooked methods only if the module owns them and restoration is safe;
- leave registered data classes idempotent for the process lifetime.

---

## 17. Technical findings already verified

The following capabilities exist in Intravenous 2 1.4.12HF3 and are relevant to HCO:

- `game.EVENTS.MAP_LOADED`, `GAME_UNLOADED`, `RESET_STARTED`, `RESET_FINISHED`, `LEVEL_FINISHED`, `PLAYER_SET`, and related lifecycle events.
- `game.worldObject:getNPCs()` exposes loaded NPCs.
- Actor classes can be resolved through `actor.getClassData("goon")` in the Workshop environment.
- The goon class exposes native detection methods including `increaseDetection`, `setDetection`, and `setEnemyInSight`.
- Goon actors expose experience levels, radios, flashlights, vision ranges, keycards, keychains, inventory, patrol routes, destination handlers, suspicion, alert, combat, body, unconscious, and death state.
- Native objective tasks include `kill_enemy`, `neutralize_enemy`, `optional_task`, sequence tasks, progress tracking, and position markers.
- `objectiveHandler:registerNewObjective`, `addObjectivesToList`, `createObjective`, and `fillObjectives` provide a path for native dynamic objectives.
- Objective rewards can use normal funds and auto-claim behavior.
- Native security cameras expose detection and disruption behavior.
- Native keycards and keycard doors already support physical credential pickup and verification.
- Native radio states and backup requests already exist.
- Native body investigation, missing patrol, suspicion, alert, and combat behavior can be extended rather than replaced.

Important compatibility lesson from the existing Cheat Trainer:

- The restricted Workshop environment may not expose the internal `goon` global. Always resolve the registered class through the public actor registry.
- Hooks must be idempotent because a mod may accidentally be loaded both locally and from Workshop.
- Never replace global weapon input/fire handling for HCO.
- Never interfere with mouse capture or GUI ownership; HCO does not need a custom in-mission menu.

---

## 18. Proposed module architecture

```text
Hitman-Contracts-Overhaul/
  preview.jpg
  files/
    main.lua
    hco/
      bootstrap.lua
      constants.lua
      runtime.lua
      lifecycle.lua
      diagnostics.lua
      contracts/
        catalog.lua
        generator.lua
        contract.lua
        rewards.lua
      targets/
        target_director.lua
        target_states.lua
        routing.lua
        archetypes.lua
      security/
        security_director.lua
        knowledge.lua
        hunt.lua
        escorts.lua
      disguises/
        disguise.lua
        recognition.lua
        body_interactions.lua
        access.lua
      sensors/
        cameras.lua
        thermal_camera.lua
        drone.lua
      integration/
        objectives.lua
        actors.lua
        keycards.lua
        radio.lua
        saves.lua
      maps/
        registry.lua
        generic.lua
        iv2_mapX.lua
      localization/
        english.lua
```

The initial slice may contain fewer physical files, but responsibilities must remain separable. Do not recreate a single giant `main.lua`.

---

## 19. Runtime ownership

One process-wide namespaced state should own:

- installation version;
- installed hook references;
- registered listeners;
- current world generation token;
- current contract;
- actor metadata maps;
- disguise state;
- cleanup functions;
- diagnostic level.

Recommended namespace:

```lua
playerActor._hcoState
```

or another globally reachable game-owned table that survives duplicate mod loads without depending on a mission player instance. The final owner must be chosen after runtime validation.

Every event callback must validate:

- current world token;
- object existence;
- object validity where `isValid()` exists;
- expected actor type;
- contract state.

---

## 20. Implementation phases

**Implementation checkpoint (`0.14.18-rc52`, 2026-08-08):** Phases 0–5 and the seven-model physical-drone portion of Phase 6 are present in the RC source and covered by syntax, simulated runtime, lifecycle, persistence, failure-isolation and rollback tests. RC24–RC33 established compact, outdoor, shootable, armed and persistently wrecked drone airframes. RC34 rebuilds Phase 3/4 social stealth on the real Goon interaction ID/cache path. RC35–RC37 corrected takeover, weapon-neutrality and native sight bypasses. RC38 hardens close-protection follower ownership and separates alert presentation from identity knowledge. RC39 adds FOV/raycast-gated close scrutiny, point-blank exposure and a consequential native hostile handoff. RC40 commits patrol destinations, exhausts outdoor fallbacks, retains a 360-degree boxed-in scan and shares confirmed contact across HCO security contexts. RC41 adds bounded disarmed exterior-barrier flight, principal patrol/incident watchdogs, explicit original-identity restoration and a persistent player identity shimmer. RC42 prevents aggressive searches from becoming automatic identity knowledge and adds disguise-aware drone scrutiny. RC43 preserves native target patrol paths, builds one bodyguard follower chain and sustains armed-drone reacquisition. RC44–RC45 repair cached selector semantics and stable action identities. RC46 raises eligible bodies above overlapping dropped equipment and repairs independent caches/hooks. RC47 repairs the earlier spatial prerequisite by restoring eligible fallen actors to the current world's native interaction quadtree exactly once. RC48 repairs persisted failed-attempt replay so an escaped or invalid unpaid contract generates a distinct new attempt on mission reload instead of suppressing every HCO runtime system; successful paid contracts remain terminal. RC49 moves native ballistic muzzles outside their complete carrier fixtures, requires a returned engine projectile and gives fired Lasers immutable visible beam/impact endpoints independent of subsequent AI state. RC50 preserves the route cursor advanced by native idle patrol activation, keeps every path/index pair synchronized, retries physical safe movement from `CORNERED` under sustained pressure and mobilizes flight when the principal itself takes damage without fabricating shooter identity. RC51 derives a deterministic five-to-eight-node principal routine from several safe authored Goon sectors, keeps adjacent legs bounded, reuses native patrol points/pathfinding/doors/followers and reconstructs the same route after checkpoint reload without mutating vanilla routes. RC52 maintains the pre-combat drone baseline, retries unavailable native/safe spawns, replaces only missing airframes inside fleet caps and returns cleared aggressive wings to passive patrol after cancelling tracking and queued weapons. The exact specification-to-code/test/live matrix is `SPECIFICATION_TRACEABILITY.md`. A crash-free live acceptance pass remains mandatory. Thermal cameras, dedicated operators, authored private-area allowlists and expanded contract families remain incomplete expansions. Automated results are not substitutes for real-game proof.

### Phase 0: Runtime probe

Goal: collect stable public runtime fields and confirm lifecycle ordering without altering gameplay.

- Listen to `MAP_LOADED`, `RESET_FINISHED`, `GAME_UNLOADED`, and actor neutralization/death events.
- Enumerate eligible NPC IDs, names, classes, patrol-route availability, experience, weapon, radio, keycard, and state.
- Log map ID and objective IDs.
- Prove cleanup across reload and main menu.

Exit criteria:

- no crashes;
- no duplicate listeners;
- useful diagnostics from at least two missions;
- stable target eligibility rules can be written.

### Phase 1: Contract vertical slice

Goal: one native assassination contract in one mission.

- Select a non-story target conservatively.
- Mark it with namespaced runtime metadata.
- Register and start a native optional objective.
- Detect target death/neutralization.
- Grant one normal money reward.
- Make selected nearby guards elite using existing experience and equipment APIs.
- Keep the original mission fully functional.

Exit criteria:

- objective appears in native UI;
- target completion resolves exactly once;
- reload does not duplicate rewards;
- target is lethal under normal rules;
- no custom overlay.

### Phase 2: Mobile target and security bubble

- Give target a routine of at least three valid nodes.
- Implement `ROUTINE`, `UNEASY`, `THREATENED`, `SHELTERED`, and `EVACUATING`.
- Implement anti-stuck watchdog and alternate-node recovery.
- Assign close-protection guards.
- Target relocates to safer areas when alerted.
- Target can physically escape.

Exit criteria:

- target never remains stationary for the entire mission unless its archetype and state justify it;
- target reacts to nearby danger;
- target reaches at least two different nodes during a normal observation test;
- no unresolved movement failure exceeds ten seconds;
- guards do not permanently block target navigation.

### Phase 3: First disguise

- Add body interaction for eligible regular-security NPCs.
- Apply visible player disguise.
- Reduce detection for compatible guards during plausible behavior.
- Preserve normal detection for weapons, aiming, off-limits behavior, and close familiarity.
- Support one access tier.
- Restore default appearance when disguise is removed or invalidated.

Exit criteria:

- player can cross a guarded public/semi-restricted area while behaving normally;
- aiming or committing a witnessed hostile action breaks cover;
- normal combat remains unchanged when no disguise is active.

### Phase 4: Compromise and smarter hunt

- Body discovery compromises uniform class after valid communication.
- Radio interruption prevents remote propagation.
- Search uses last-known position and sectors.
- Target changes safe area after a breach.
- Elite guards contain exits and avoid uncontrolled single-file rushing where native APIs allow.

### Phase 5: Full contract product

- Authored profiles for multiple campaign missions.
- Several target archetypes.
- Three disguise tiers.
- Keycard integration.
- Multiple contract conditions.
- Target escape and differentiated rewards.
- Localization-ready text.
- Workshop packaging and visual assets.

### Phase 6: Advanced security

- Thermal camera subtype.
- Drone actors and operators.
- Power/security relationships.
- Advanced evidence and identity knowledge.

---

## 21. Vertical-slice acceptance test

The first playable slice is accepted only when all are true:

1. The game reaches the main menu without HCO errors.
2. Loading an unsupported mission does not create a contract and does not crash.
3. Loading the supported test mission creates exactly one contract.
4. The objective appears through the native objective system.
5. The target is an eligible non-story NPC.
6. The target has a stable HCO ID and visible/trackable contract identity.
7. The target moves between validated positions.
8. Danger causes the target to select a safer position.
9. A blocked route triggers recovery rather than permanent stalling.
10. Nearby assigned guards use elite native settings.
11. Killing or neutralizing the target resolves the objective once.
12. The normal mission can still be completed.
13. Reloading cannot award the same contract twice.
14. Returning to the main menu removes runtime references.
15. The Cheat Trainer remains untouched and independently functional.

---

## 22. Test matrix

### Lifecycle

- cold game start;
- local mod only;
- Workshop mod only;
- accidental local plus Workshop duplicate;
- new mission;
- mission restart;
- save and load;
- return to main menu;
- finish mission;
- enter another mission.

### Target

- target killed quietly;
- target knocked unconscious;
- target killed by environment;
- target killed by another NPC;
- target loses all escorts;
- target route blocked by door;
- target route becomes inaccessible;
- safe area compromised;
- target reaches evacuation;
- target removed by vanilla script.

### Disguise

- clean uniform at medium distance;
- close inspection by same-unit elite;
- visible legal weapon;
- visible illegal weapon;
- aiming;
- running;
- restricted zone;
- body discovered without radio;
- body discovered with radio;
- disrupted radio;
- combat started while disguised;
- save/load while disguised.

### Compatibility

- no Cheat Trainer installed;
- Cheat Trainer local installation present;
- several subscribed weapon mods;
- custom map without HCO profile;
- map with no NPCs;
- map with story-critical named NPCs.

---

## 23. Risk register

### High risk

- Reliable dynamic injection of native objectives after vanilla objective setup.
- Determining story-critical actors generically.
- Changing player appearance with complete weapon/stance animation coverage.
- Controlling target routes without fighting vanilla actor state logic.
- Adding drone navigation and sprites.

### Medium risk

- Clean reward persistence across every reload path.
- Identifying restricted zones without authored map profiles.
- Propagating compromised-disguise knowledge through native radio behavior.
- Keeping close escorts useful without blocking the target.
- Compatibility with mods that also override goon detection.

### Low risk

- Selecting NPCs from `worldObject:getNPCs()`.
- Listening for actor death/neutralization.
- Assigning native experience levels and weapons.
- Reading patrol-route and keycard data.
- Using normal funds as rewards after completion.

Mitigation principle: unknown or unsafe behavior causes HCO to skip a feature or contract, never to modify unrelated campaign state speculatively.

---

## 24. Explicit non-goals for the first release

- New standalone campaign.
- Procedural generation of map geometry.
- Full Hitman-style civilian conversation simulation.
- Perfect disguises for every faction and every player animation.
- Wall-penetrating or indestructible drones; physical search drones are now part of RC6.
- Thermal vision through walls.
- Target health bars or boss phases.
- Online daily contracts.
- Leaderboards.
- Separate currencies or battle-pass progression.
- Replacing every vanilla enemy AI state.

---

## 25. Future-agent handoff rules

1. Read this entire specification before changing HCO code.
2. Treat this file as the source of truth unless the user explicitly changes a decision.
3. Do not edit `Intravenous2-CheatMenu` while implementing HCO.
4. Keep HCO in a separate source, local-mod, and Workshop-staging directory.
5. Preserve native UI and avoid custom overlays.
6. Preserve the user's consolidated-RC decision: maintain the integrated Phase 0–5 build, run the final in-game validation as one coherent pass, then fix observed engine issues without reverting completed systems to isolated probes.
7. Never claim disguise, objectives, movement, or persistence work from a syntax test alone.
8. Record discovered runtime APIs and map-specific IDs in a dedicated evidence file.
9. Use idempotent hooks and restore or neutralize them on game unload.
10. Prefer authored compatibility profiles over risky generic behavior.
11. Never make security omniscient to simulate difficulty.
12. Never make the target a bullet sponge.
13. Never use teleportation as normal target movement.
14. Add new assets only with complete attribution and Workshop-safe licensing.
15. Update this specification when a user decision materially changes the product.

---

## 26. RC6 implementation decision — multi-contract intelligence and physical drones

The user's 2026-08-06 direction supersedes the former single-target/drone-future boundary:

- Compatible maps may create one, two, or three isolated contracts according to safe actor population.
- Every contract owns its target, protection roster, objective/marker UID, AI, security knowledge, reward, and terminal state.
- Campaign persistence uses a v3 bundle and migrates a v2 single record into slot one.
- Targets are reserved before protection assignment; no target or guard may be shared between contracts.
- The first marker leads to a persistent field-intelligence dead drop near mission entry. Proximity reveals the exact moving target marker; a 55-second fallback prevents inaccessible generated clues from blocking play.
- Protection remains heavy: five to fifteen elite guards per target, fairly capped when several details share one map.
- A body discovery by contract security requests a three-drone search deployment. Drones fly physical map-space sector patterns, use line-of-sight scan cones and shadow-mapped searchlights, can be shot or disrupted, and share only confirmed sightings.
- A confirmed drone sighting raises PRESSURE, sends the last-known player position to living response units, and triggers distributed native alert/search movement.
- Drone artwork is original generated project artwork stored in `files/assets/hco`; no external copyrighted asset is used.

Validate `0.10.0-rc6` in Intravenous 2 `1.4.12HF3` as an integrated build:

- confirm clean boot and one-to-three native optional objectives in a compatible campaign mission;
- follow each initial clue marker, acquire the intelligence, and confirm the marker switches to its own moving target;
- confirm targets and protection rosters are distinct and each detail has at least five guards on a sufficiently populated map;
- observe routine movement, threat relocation, shelter reselection, and physical escape behavior;
- expose a corpse near the protection team, confirm several visible drones launch and search separate sectors, then shoot one down;
- let a drone confirm the player and verify the scanlight changes state and response units converge on the reported position;
- acquire a disguise from an unconscious or dead guard and verify appearance, keycard access, plausible detection reduction, behavior exposure, local body evidence, radio propagation, and radio disruption;
- neutralize or kill targets and confirm exactly one campaign-money payout per contract without any `studio` traceback;
- reload during an active contract and after a terminal result to confirm stable target identity and no duplicate objective or reward;
- complete the vanilla mission and return to the main menu without errors;
- capture `[HCO]` diagnostics and any crash log, then correct only failures observed against the real engine.

Do not claim RC6's new visual drone layer as in-game verified until this pass is complete.

### RC7 archetype identity decision

- Full replacement character animation atlases are not used unless every stance, weapon, cover, hit, body, and death frame can be authored and registered safely.
- HCO instead assigns complete native animation variants per archetype and overlays a small original faction patch through the existing actor post-draw pass.
- Executive uses `gideon`/`bodyg`/`police` with a gold diamond.
- Commander uses `merc`/`police` with a red military chevron.
- Broker uses `bandit`/`motor` variants with a violet broker-serpent mark.
- Fixer uses `bodyg`/`merc`/`gideon` with a cyan crosshair.
- Original animation variants and HCO visual metadata must be restored during teardown and reload rollback.
- Drone behavior is archetype-specific: Watcher, Smuggler Eye, Hunter Swarm, and Interceptor doctrines vary count, speed, range, acquisition time, and armor.

### RC8 audiovisual feedback decision

- A confirmed nearby or radio-relayed hostile sighting deploys drones even without body evidence; body discovery remains an independent trigger.
- Every live drone has a seamless original rotor loop whose volume follows player distance and is stopped on destruction/removal.
- Contract completion uses a compact fading native HUD indicator containing archetype, payout and optional-condition result, plus an original chime and native confirmation cue.
- Custom audio failure must fall back to verified native sound IDs without affecting contract settlement.
- ElevenLabs voice/SFX is reserved for a later authored radio-callout pack after custom voice localization, volume ducking and Workshop asset-loading behavior are live-verified.

### RC21 drone role and counterplay decision

- The first native-airframe live pass proved that custom physical drones can render through the game's decor quadtree and sprite-batch lifecycle. Airframes must remain actor-scaled, align their sensor nose with the scanlight, and communicate flight through restrained pixel wakes, hover motion, rotor pulses and state color rather than a detached overlay.
- Every drone is a world object that can be shot down or electronically disrupted. Disruption suspends HCO detection and relay behavior; destruction removes the light/airframe/sound and creates localized crash evidence that nearby response guards investigate.
- Baseline Watcher and Smuggler Eye drones are information weapons: their danger is detection, last-known-position relay and coordinated response. They do not deal unavoidable off-screen damage.
- A future armed Hunter or Interceptor may attack only after confirmed tracking. Its attack must use an obvious red aim laser or charge cue, line of sight, a reaction window, a cooldown and ordinary destructibility/disruption. Prefer a shock dart or short suppressive burst over a continuous damage laser. The visible laser is a telegraph, never an instant magical damage ray.
- Armed-drone damage is not considered implemented until the native projectile/damage API is inspected and both player counterplay and AI friendly-fire behavior pass a real mission test.

### RC22 seven-model drone-wing decision

RC22 supersedes the single-baseline/future-armed split with a deliberately small seven-model production roster:

- one unarmed Scout;
- light and heavy Pistol drones;
- light and heavy SMG drones;
- light and heavy Laser drones.

There is no third medium weight class. Scout is common and information-first. Light armed models are fast, fragile and frequent; heavy models are larger, slower, more narrowly gimballed, reinforced and rarer. Executive wings bias toward lasers, Broker wings toward pistols/light SMGs, Commander wings toward heavy SMGs, and Fixer wings toward precision lasers. The first aggressive doctrine wave guarantees a readable signature model while later slots remain deterministically weighted.

Flight is split into two rotations. The body follows velocity and yaws toward a tracked target only when necessary. The sensor/weapon gimbal follows the player inside a model-specific mechanical arc; reaching that limit causes the body to turn. Confirmed drones occupy stable standoff slots with only a small breathing motion, never a continuous orbit through the player. Lost targets are searched from safe native patrol-route sector points. Spawn/destination coordinates are varied deterministically, clamped to `world:getSize()` margins and snapped through `world:getBestPFPoint()`/the native floor grid. Airframes retain at least 84 units of wing separation and prefer unused roster rows before a duplicate. They may cross low map objects, but may not park in unreachable void or stack inside one another.

Armed drones attack only in AGGRESSIVE mode after a confirmed HCO sighting. Pistol and SMG models instantiate the game's native weapon/projectile path, use a living response actor for attacker attribution, require an unobstructed ray to the player, originate beyond the complete carrier fixture and advance their burst only after the engine returns a projectile. Laser models use direct actor damage only after a visible, uninterrupted 0.9-second light or 1.4-second heavy charge; LOS or gimbal loss cancels that charge. A completed discharge snapshots independent muzzle/impact endpoints for a readable glow/core/pixel beam even if cooldown, God Mode or the next AI update clears live aim. Every attack exposes an aim cue, range, cadence and cooldown. Every carrier remains natively aimable, bullet-breakable and disruptable; its physical hitbox scales with the light/heavy silhouette, partial armor hits emit ricochet audio and sparks, and EMP cancels detection and attack state.

The runtime atlas contains exactly seven rows in the roster order above and four animation columns. Creator-supplied source audio is adapted into light/heavy rotor loops and light/heavy laser one-shots. Ballistic variants retain native Intravenous 2 weapon sounds. Automated API/harness proof is complete for the RC22 slice; real mission proof remains mandatory before the armed roster is called live-complete.

### RC23 aim-outline and bounded-flight correction

The engine may call `drawOutline()` as soon as the player aims at an aimable drone. The invisible `security_camera` carrier must never fall through to `genericObject:drawOutline()`: runtime carriers do not own the map-finalized `quadStruct` expected by that method. Carrier `drawOutline` and `rawDraw` therefore delegate to the visible airframe, which draws its current atlas frame directly during the native outline pass.

Drone speed is a physical fairness contract, not only a tuning multiplier. The complete displacement after steering and wing separation is limited to 64 world units per second during patrol and 108 during aggressive pursuit. Doctrine and model multipliers may select a lower speed but can never exceed these caps. Separation changes steering direction inside the same per-frame travel budget and cannot teleport a converging drone.

### RC24 compact, shootable and tactical flight correction

The visible roster uses compact top-down scale values of 0.32 for Scout, 0.35 for light armed models and 0.39 for heavy models. Weight remains readable through silhouette, armor and effects rather than near-vehicle-sized screen occupancy.

Every carrier owns a real bullet-hitable Box2D fixture created after runtime placement. Its logical size, `hitboxW`/`hitboxH`, aim position, quadtree location, physical body and airframe center must remain synchronized for the entire flight. A moving drone that can shoot the player must always be targetable and destructible at its visible position.

Aggressive behavior alternates between information search and pressure. With recent shared intelligence, direct line of sight immediately starts gimbal tracking and standoff movement even before the local scan cone is perfectly aligned; weapon fire still requires that drone's own confirmed sighting. After losing contact, each drone periodically samples a different playable search ring around the last known position. During sustained contact, it changes flank side and angle every 3.2–5.8 seconds instead of camping one static slot or continuously orbiting through the player. All destinations retain native floor snapping, wing separation and RC23 movement caps.

### RC25 building boundary and idle recovery

Flight must sample the native mission path grid across the drone footprint before applying movement. `OBSTRUCTED`, `DOOR`, `GARAGE_DOOR`, `CLIMBABLE` and `WINDOW` cells are aerial boundaries; `OBSTRUCTED_LOW` remains intentionally flyable. When a direct step is blocked, the drone tries deterministic alternate headings within the same per-frame speed budget and may never solve the obstacle by crossing its blocked cell.

A drone that moves less than 0.05 world units for 0.55 seconds while active is considered tactically stalled. Tracking drones immediately change flank side and angle; searching drones advance their search phase and invalidate the current destination. This watchdog complements path-grid steering and must not create teleports, violate world bounds or bypass wing separation.

### RC26 follower ownership and projectile counterplay

Only close-protection actors may enter native follower states. Response units are autonomous security-director assets and may transition freely among patrol, search, alert and combat without ever remaining referenced as another actor's follower. This prevents native alert logic from invoking follower-only methods on combat/search states.

Generic world objects use top-left `x/y`, while Box2D rectangles use a centered body position. Every drone fixture must therefore follow `getAimPos()` rather than raw carrier `x/y`. Native bullet raycasts remain authoritative. A secondary player-only segment test may run after native bullet/world processing to cover engines that omit late-created generic fixtures; it must consume only a path that intersects the visible drone, and a wall-hit bullet must already be inactive before this fallback executes.

### RC27 fragile-drone balance and hit language

Drones are dangerous because of mobility, information relay and weapon pressure, never because they are bullet sponges. Scout and all light variants have exactly one structural point. Heavy Pistol has two base points; Heavy SMG and Heavy Laser have three. Doctrine may raise a two-point heavy to three but may never exceed the global three-hit ceiling.

Projectile strength is read from the engine bullet's damage and armor-penetration interfaces. Ordinary rounds remove one point and strong rifle/hand-cannon rounds remove two, but the first hit against any heavy is clamped to leave at least one structural point. Heavy models therefore always take two or three shots. Every surviving impact must tint the complete airframe, play spatial metal feedback, emit an expanding nine-spark ring and briefly display the remaining two/three structural pips. The fallback must process multiple same-frame projectiles so shotgun pellets are not silently discarded.

### RC28 silhouette coverage and crash lifecycle

The shootable target must cover the complete rotating silhouette, including the outer rotor circles. Scout, light and heavy carriers use 44, 48 and 54 world-unit square fixtures respectively. If the engine destroys or invalidates a runtime body/fixture, the drone must rebuild it through the same native hitbox initializer during its next update and resynchronize it with the visible aim center. The post-world projectile fallback derives its radius from the same 96-pixel atlas cell and render scale, so neither collision path exposes a smaller target than the rendered airframe.

Destruction must read as loss of an airframe rather than instant sprite removal. The body travels along its last movement heading with a small lateral drift, loses stable rotor attitude, tumbles with light/heavy-specific weight, sheds pixel smoke and sparks, and lands inside the valid world bounds. The landing emits an impact ring and debris, leaves a dark non-aimable wreck until contract cleanup, creates crash evidence at the landing point and sends available response actors there. The effect remains a native world entity and must not introduce a HUD layer.

### RC29 production balance and semantic sensing

The contract must derive one immutable balance snapshot from the game's native difficulty at activation. That snapshot scales autonomous response count, guard/target health, drone count, acquisition time, sensor range, displayed threat I–V and reward together. Five close bodyguards remain structural at every difficulty. Custom difficulty values are clamped before use, and absent/unknown difficulty data falls back to Normal rather than disabling the contract.

Up to three simultaneous contracts share a global ceiling of twelve active airframes. A single contract may field at most two Heavy and two Laser models. Selection continues to prefer unused roster rows without violating those limits.

Drone identity sensing consumes the same behavior risk as social stealth. A calm plausible disguise slows routine acquisition to 22% speed but never creates invisibility. Aggressive security never drops below 72% acquisition speed. Aiming, sprinting, recent firing, suspicious native player states, incompatible visible weapons or a compromised uniform restore stronger scrutiny.

Each non-disrupted drone periodically inspects dead or unconscious NPCs through its current sensor cone and the same geometry raycast used for player sight. Shared per-contract memory prevents duplicate reports. A confirmed body becomes security evidence and may deploy support; if it is the source of the active stolen uniform, the network globally compromises that identity. The scan is represented by a brief world-space pulse and one rate-limited native feedback notice, never by a new HUD panel.

### RC30 outdoor placement and reciprocal combat fairness

Pathability alone is insufficient for an aerial combatant because interior floors, locked rooms and exterior roads are all walkable native path tiles. Deployment must wait for `envController:getRoofReady()` and reject any center or footprint sample for which `getPosUnderRoof()` / `floorTileGrid.tiles[index].roofObstructed` is true. Every spawn, patrol point, search ring, flank destination and recovery point must use a clear exterior footprint. Local deterministic rings are preferred; a whole-grid nearest-exterior scan is permitted only as a spawn/recovery fallback, never per frame. Low outdoor cover remains overflyable.

Combat authority is reciprocal. A drone may acquire or attack only after the native geometry raycast completes and only while its visual airframe, centered bullet-hitable fixture and exterior footprint are all valid. A missing API, failed raycast or invalid carrier is not interpreted as clear sight. Runtime fixture repair gets a brief bounded window; persistent invisible or unhittable carriers remain inert and are retired without creating fake player destruction evidence. A deployment whose physical hitbox cannot be created never enters the active fleet.

### RC31 terminal destruction and wreck readability

Destruction is one atomic state boundary, not merely zero movement. Before the crash begins the carrier must set `broken`, leave the dynamic update list, clear detection/tracking/identity state, cancel every queued ballistic or Laser action, release its native weapon, stop rotor audio and permanently remove the native camera light buffer from casting, forward rendering and atlas ownership. No delayed burst, charge, cone, outline or reacquisition may survive this boundary.

The visible native-world airframe must release its intact shared-batch slot and switch to `drone-wreck-atlas.png`. The wreck atlas preserves the seven roster rows and provides four generated stages per family: initial break, damaged tumble, impact and final asymmetric inert wreck. The final frame remains at the computed crash site until context cleanup and has no cyan sensor, aim cue or functional silhouette.

### RC32 durable wreck rendering and unaided projectile sweep

Active and destroyed textures require separate registered native sprite batches. Destruction releases only the intact slot, immediately acquires a wreck-batch slot, updates that slot through every tumble stage and retains the final-frame slot until the contract context is cleared. A direct texture draw from the decor-quadtree callback is not sufficient evidence of persistence because the engine's durable world-sprite path is batch-owned.

The player's weapon advances each newly created bullet once before adding it to `game.activeBullets`. On first observation, the fallback must therefore test from the bullet's recorded `shootX/shootY` muzzle point to its current position. Subsequent checks retain a per-bullet, per-drone previous position so the sweep stays bounded. Because native bullets are pooled, a changed shot number, muzzle or travel vector must clear all prior HCO hit/sweep state. Right-click target selection may improve aim but must never be required to hit any visible Scout, light or Heavy rotor edge.

### RC33 persistent crash clock

The destroyed sensor carrier immediately leaves the native dynamic-object list, while its visual shell remains a decor entity. Decor redraw frequency is therefore not animation authority. Every active contract update must advance an explicit crash clock for its destroyed shells and write the derived position, rotation, scale and atlas frame into the wreck batch even when `visual:draw()` is not called again. The shell is reinserted into the decor quadtree only during the bounded tumble, impact and smoke window so direct effects refresh; afterward the final batch frame remains static without permanent update churn.

### RC34 native identity and social-stealth contract

Disguise acquisition is owned by the engine's existing body-interaction chain. Adding an option table without invoking `entity:enumerateActions()` and refreshing existing `_interactionList` caches is not an implementation. HCO must retain one sentinel option, preserve power-of-two action IDs across other mods, refresh death/choke/fallen/drop transitions and call the body's native `postInteract()` after takeover.

Identity metadata is captured before `_die` or `_choke` drops the actor's weapon, keycard and keychain. The active identity persists its uniform/familiarity group, STAFF/SECURITY/ELITE tier, credentials, source and consumed-source set, allowed equipment, original player appearance, acquisition time, blood condition, faction insignia and compromise state. A failed appearance read-back restores the previous player variant atomically.

Recognition remains a modifier on native vision, distance, time, geometry, observer-local alertness, off-limits and detection presentation. It must account for same-unit familiarity, observer experience/role, sprint/aim, directly witnessed fire, illicit interactions, blood, fresh evidence and target lingering. Held equipment, holster state, reload and unrelated global combat add no identity risk. `getOfflimits` and `getOfflimitsActive` must agree, while real key/keychain IDs remain valid independently of uniform compromise.

Identity checks and body reports use a real NPC radio. Leaving check range, disrupting the radio or neutralizing the carrier prevents global compromise; successful transmission compromises the uniform class. Acquisition, restoration, checking and compromise receive short player-attached pixel transitions on the native world draw path. The permanent visual truth is the player's real actor variant and optional matching faction insignia, never a detached dashboard. Exact requirements, automated evidence and live gates are maintained in `SPECIFICATION_TRACEABILITY.md`.

### RC35 armed-cover and evidence-visibility correction

This historical intermediate rule is superseded by RC36. RC35 first reduced the abrupt weapon-family penalty, shortened the takeover window and removed distance-only body discovery; RC36 removes weapon plausibility from recognition entirely.

The first 1.5 seconds after changing clothes create only a short 25% scrutiny floor. They do not globally preserve the player's old identity. Guards who genuinely saw the preceding attack remain hostile through their observer-local knowledge, while source-body knowledge propagates only after the engine's real body-investigation sight event or a physical drone cone/raycast. HCO may never infer body discovery from distance alone.

### RC36 observer-local identity and weapon-neutral cover

Weapon plausibility is removed from the identity model. Any held or holstered sidearm, primary weapon or other normal loadout has zero influence on recognition for every disguise tier; reloading alone is likewise neutral. This is a deliberate product rule, not a balance value.

A shot has two separate consequences. A direct visual witness can associate the hostile act with the disguised player, locally compromises that identity and may radio the result. An observer that only hears the shot receives an incident position to investigate, never the player's actor identity. The same position-only rule applies to protection damage and casualties until a real observer confirms contact. Global combat state may alter native urgency but must never make an uninformed observer recognize the player.

### RC37 native AI-state identity boundary

The native Goon sight states are allowed to calculate and present suspicion, but they are not allowed to convert a clean disguise into player-specific hostility through an arbitrary instant-detect shortcut. While the active identity is neither locally nor globally compromised and the player is not performing an overt action, every instantiated `onSightHitPlayer` path retains native detection progression without executing direct combat until the explicit RC39 proximity rules or another authoritative evidence path establishes identity. A second class-level enemy-sight boundary fails closed for uninformed paths.

Ordinary medium-distance suspicion is capped below native suspicion success. Close range is intentionally risky: sustained unobstructed inspection inside 150 units accumulates per observer, with same-unit, elite, close-protection and protected-target roles completing it faster; broken sight or withdrawal decays progress. Unobstructed point-blank sight inside 72 units establishes immediate local knowledge. Either completion resumes the original native threaten/startle/surrender/combat path and may begin a real interruptible radio report. Weapons remain identity-neutral. A witnessed aim, shot, lock break, takedown or other overt action also passes through immediately.

### RC39 consequential close inspection

Disguise gameplay must create a navigation puzzle rather than a universal pass. Proximity recognition is observer-local and requires the same current native vision AABB, FOV and world raycast used for witnessed gunfire; walls, facing away and historical `seenPlayer` memory cannot advance it. A brief close crossing is recoverable, but loitering under direct observation is not. Point-blank inspection is a hard failure because face, voice and mannerisms are no longer plausible at that distance.

When an observer recognizes the player, HCO sets full detection only for that observer and invokes its already-instantiated sight state. The base game therefore chooses whether to threaten, startle, demand surrender or enter combat. A compact orange-red local-exposure effect communicates the failure without claiming global compromise. Additional guards learn the identity only through their own sight or a completed physical radio report.

### RC41 bounded exterior flight and readable identity state

Drones may cross a narrow wall, gate, fence or door separation only after ordinary steering has failed and a complete safe outdoor landing footprint exists on the intended heading. The transition is short, eased and visually elevated. It is not combat: native camera perception, HCO detection/body evidence, network confirmation and weapon authority are suspended from takeoff through landing. A roofed building, wide inaccessible span or map void must not produce a landing candidate.

The protected principal must remain a mobile systemic actor. On sufficiently populated compatible maps, its routine spans five to eight deduplicated native patrol points from several safe selector-approved Goon sectors; node order is contract-seeded, adjacent legs are bounded and sparse maps retain the original route. A routine target that makes no progress for nine seconds advances through its active derived/original native route. The first nearby unsuppressed shot creates cautious location-level awareness without identifying the shooter. Confirmed protection damage, casualties or communicated contact escalate the existing retreat/evacuation phases, and a fresh incident near occupied shelter forces reselection.

Disguise acquisition is the first eligible action in the native body selector. While active, a restrained cyan world-space shimmer surrounds the player and becomes red when the uniform is compromised. A second native action restores the original actor appearance and clears only the active disguise record: copied credentials, consumed uniform sources and already learned compromise history remain authoritative.
