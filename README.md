# LootProof Prototype

Godot 4.x MVP prototype based on `LootProof_GDD_Prototype_Plan.pdf`.

## Start

Open this folder in Godot 4.x and run the project. The main scene is `Scenes/MainMenu.tscn`.

## Controls

- Move: `A/D` or arrow keys
- Jump: `Space` or `W`
- Dash: `J` or `Shift`
- Toggle build mode: `B`
- Cycle build item: `Q`
- Place item: `E` or left mouse click
- Restart run: `R`
- Scoreboard: hold `Tab`

Xbox / PlayStation style controllers:

- Move: left stick or D-pad
- Jump: bottom face button (`A` / `Cross`)
- Dash: left face button or right bumper (`X` / `Square`, `RB` / `R1`)
- Toggle build/proof: top face button (`Y` / `Triangle`)
- Cycle build item: left bumper (`LB` / `L1`)
- Place item: right face button (`B` / `Circle`)
- Restart run: Start / Options

## Prototype Loop

The build contains one local dungeon with Build, Proof, Raid, Solution Replay and Score phases. Build edits reset proof status. A dungeon is considered proven after two successful clears within the timer. Replays are input/transform samples, not video.

Two players alternate roles. Each player gets 3 builder rounds. Builder points come from raider deaths and timeout defenses. Raider points come from successful clears, remaining time and clean runs.

Builder layouts are tracked per player. If a raider clears a builder's dungeon, that dungeon is carried into the builder's next build phase with bonus build points so it can be made harder. If the raider times out, the defense scores and that builder starts fresh next time.

The build area is bounded on the left and right. Wall contact now slows the player's fall briefly and allows a wall jump away from the wall without continuously holding into it.
