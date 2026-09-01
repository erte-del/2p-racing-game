# 2P Racing Game

A split-screen two-player racing game, built in Godot 4.7 (GDScript).

## Requirements

- Godot 4.7.2 (standard build, not .NET)
- Blender 5.2 LTS — only needed to re-export the car models

## Layout

```
assets/models/    imported .glb models
scenes/           main.tscn and per-entity scenes
scripts/          GDScript
tools/            Blender export scripts (not shipped in the game)
```

## Controls

| Action     | Player 1 |
| ---------- | -------- |
| Accelerate | W        |
| Brake      | S        |
| Steer      | A / D    |

Player 2 (arrow keys) arrives in Phase 2. The car script reads its actions from
an `input_prefix` export, so a second car only needs a new prefix and a new set
of `p2_*` actions.

## Car models

The car is authored in Blender and committed as a `.glb`. `.glb` is preferred
over `.fbx` here: the original `car1.fbx` contained only the body, while the
`.blend` has the four wheels as separate objects, which the game needs in order
to steer and spin them.

The export is scripted so it can be reproduced rather than hand-repeated:

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b "path/to/Low Poly Car.blend" --python tools/export_car1.py
```

It drops the Camera/Floor/Sun, applies the Mirror modifier, scales the car to
4.3 m long, sits it on the ground at the origin, moves each wheel's pivot to its
own centre so it spins in place, and names the wheels from their measured
position (`Wheel_FL`, `Wheel_FR`, `Wheel_BL`, `Wheel_BR`).

## Phases

- [x] **0** — repo, Godot project, `.gitignore`
- [ ] **1** — one car driving (WASD)
- [ ] **2** — second car (arrow keys)
- [ ] **3** — split screen
- [ ] **4** — a hand-made track
- [ ] **5** — procedural track generation
- [ ] **6** — countdown, checkpoints, finish, winner, timer
- [ ] **7** — polish: models, environment, audio, particles, UI, themes, boosts
