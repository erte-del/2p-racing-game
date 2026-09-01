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

| Action     | Player 1 (red) | Player 2 (blue) |
| ---------- | -------------- | --------------- |
| Accelerate | W              | Up              |
| Brake      | S              | Down            |
| Steer      | A / D          | Left / Right    |

Both players use the same `scenes/car/car.tscn`. A car reads its actions from an
`input_prefix` export (`p1` / `p2`) and takes its paint from a `body_color`
export, so adding a third player would mean one more instance and one more set
of `p3_*` actions.

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

## Split screen

The cars live in `main.tscn` so they share one `World3D` and can collide. Each
half of the screen is a `SubViewport` that inherits that same world and adds
only its own `ChaseCamera`, which the level wires to a car in `main.gd`. The
cameras are deliberately *not* children of the cars: two cameras in one viewport
would fight over which is current.

## Phases

- [x] **0** — repo, Godot project, `.gitignore`
- [x] **1** — one car driving (WASD)
- [x] **2** — second car (arrow keys)
- [x] **3** — split screen
- [ ] **4** — a hand-made track
- [ ] **5** — procedural track generation
- [ ] **6** — countdown, checkpoints, finish, winner, timer
- [ ] **7** — polish: models, environment, audio, particles, UI, themes, boosts
