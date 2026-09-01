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

`Low Poly Car.blend` is the only file in the author's Blender folder that
belongs to this project; the others there are unrelated work.

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

## Rival arrow

Each half of the screen shows a small arrow orbiting that player's car at a
fixed radius, pointing along the ground towards the other car and painted in
the rival's colour. It hides itself while the rival is already on screen, and
uses a wider margin to hide than to reappear, so it cannot flicker while the
rival sits on the edge of the view.

Both views render the same `World3D`, so each arrow sits on its own visual
layer that the *other* player's camera culls; otherwise both arrows would show
up in both halves. `main.gd` pairs each layer with the camera that must ignore
it. The arrow also rolls about its own nose to keep its flat face turned
towards its camera - without that it is edge-on and nearly invisible whenever
the rival is straight ahead or behind.

## Track

`scenes/track/track.tscn` is a `Path3D` whose `Curve3D` is extruded into a road
by two `CSGPolygon3D` nodes - a wider light one for the kerbs and a narrower
dark one for the asphalt - both with `use_collision` on. Drag the path's points
in the editor to reshape the circuit; nothing is baked.

The curve repeats its first point at the end so that it genuinely closes,
rather than relying on `path_joined` to close the road visually. That matters
beyond looks: `get_baked_length()` and `sample_baked()` are what lap timing and
checkpoints will use in Phase 6, and on an unclosed curve they silently omit the
final segment.

The starting grid is derived from the curve at run time in `main.gd`, so it
follows the track when the path is edited.

Current circuit: 12 control points, 701.6 m a lap, 14.4 m wide.

## Phases

- [x] **0** — repo, Godot project, `.gitignore`
- [x] **1** — one car driving (WASD)
- [x] **2** — second car (arrow keys)
- [x] **3** — split screen
- [x] **4** — a hand-made track
- [ ] **5** — procedural track generation
- [ ] **6** — countdown, checkpoints, finish, winner, timer
- [ ] **7** — polish: models, environment, audio, particles, UI, themes, boosts
