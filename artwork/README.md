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
