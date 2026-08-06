# Drone roster artwork

The runtime atlas in `files/assets/hco/drone-roster-atlas.png` was derived from
the concept sheet in this directory. The concept was generated with OpenAI's
built-in ImageGen mode and then processed into transparent, aligned runtime
cells. The checked-in preview documents the final in-game scale.

## Exact ImageGen prompt

```text
Use case: stylized-concept
Asset type: production concept sheet for top-down 2D pixel-art game sprites
Primary request: Create seven genuinely distinct top-down combat drone designs matching the attached Intravenous-style drone sprite's crisp dark-metal pixel-art language. Arrange them as an exact 4-column by 2-row grid; seven occupied cells and the bottom-right cell intentionally empty.
Subjects in reading order: 1 ultra-light unarmed scout with compact sensor body; 2 light pistol quadcopter with one short forward barrel; 3 heavy pistol quadcopter with broad reinforced armor and one large forward barrel; 4 light submachine-gun drone with agile narrow body and twin short forward barrels; 5 heavy submachine-gun drone with bulky armor, heat vents and reinforced rotors; 6 light laser drone with sharp triangular body and one cyan energy emitter; 7 heavy laser drone with wide armored body, heat sinks and a large red/cyan focusing lens.
Composition: every drone centered inside an equally sized grid cell, identical top-down camera, nose pointing straight down, generous clear padding, no overlap, consistent scale family while heavy models visibly larger than light models.
Style: detailed but readable low-resolution pixel art, hard pixel edges, charcoal gunmetal, steel highlights, restrained cyan sensors, small red weapon accents. No text, labels, numbers, borders, UI, scenery, floor, cast shadows or watermark.
Background: perfectly flat solid #ff00ff chroma-key background, one uniform color with no gradient, texture, lighting variation or reflection. Do not use #ff00ff anywhere in the drones.
```

The original attached reference was the pre-roster HCO drone sprite. The source
sheet is retained as `drone-roster-concept-magenta.png`; the keyed transparent
version is `drone-roster-concept-alpha.png`.

## Destroyed-drone artwork

RC31 adds `files/assets/hco/drone-wreck-atlas.png`. Its retained ImageGen source
is `drone-wreck-concept-magenta.png`; the runtime conversion splits the 4×7
concept grid, removes the chroma key, normalizes each family to the matching
live-airframe footprint and packs exact 96×96 cells into a 384×672 atlas.

### Exact ImageGen prompt

```text
Edit the supplied Intravenous 2 top-down pixel-art drone atlas into a dedicated DESTROYED DRONE / WRECK atlas.

Preserve the exact atlas topology: 4 columns by 7 rows, one centered 96x96-style cell per sprite, same seven drone families and their silhouettes as the reference, same top-down viewpoint, same compact scale and crisp native pixel-art language.

Each row must show the same drone family in four clearly destroyed variants / sequential wreck frames:
1. violent impact with one broken rotor and a few orange sparks,
2. tumbling severely damaged airframe with bent arms and exposed red wiring,
3. hard-ground crash with detached parts and tiny smoke pixels,
4. final inert wreck: asymmetric broken chassis, missing rotor or weapon, scorched metal, no active cyan sensor light and absolutely no intact searchlight.

Make the final wrecks unmistakably dead even at small in-game scale. Keep debris inside each cell. No text, no UI, no floor texture, no cast shadows, no searchlight beams, no muzzle flashes. Crisp hard pixel edges, limited Intravenous 2-style palette: charcoal gunmetal, cool gray, rust, ember orange, small dark red details.

Use a perfectly flat, uniform chroma-key background color #FF00FF across the entire image and nowhere on the sprites. Maintain generous empty space and never let sprites cross cell boundaries.
```
