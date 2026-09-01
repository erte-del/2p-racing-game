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

Finishing a lap generates a new circuit and pauses for three seconds.

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

Circuits are generated at run time by `scripts/track.gd` from a seed, so the
same seed always gives the same track.

The shape is a closed loop whose radius comes from three harmonics around the
circle rather than from independent random values per point. Independent values
had to be smoothed so hard to avoid undrivable spikes that every circuit came
out a near-circle. Keeping the control-point angles strictly increasing and the
radii positive makes the loop star-shaped, which is what guarantees it cannot
cross itself.

The road is a generated mesh, not a `CSGPolygon3D` extrusion, because CSG has a
single fixed cross-section for the whole path and so cannot narrow the road in
the corners. Width is driven by local curvature: tight corners taper to
`narrow_half_width`, open sweepers reach `wide_half_width`. Building the ribbon
by hand also gives the collision shape and the mountains the same sampling.

Triangles are wound clockwise seen from above, which is Godot's front face.
Getting that backwards makes the road invisible from above and, because a
`ConcavePolygonShape3D` only collides with its front faces, drivable straight
through.

## Mountains

A ridge runs down each side, built from a foot, a crest and an outer foot per
cross-section, with heights from `FastNoiseLite`. The inner slopes are far too
steep to climb, which is what keeps the cars on the circuit.

On the inside of a corner the cross-section is scaled down to fit within the
local radius of curvature: offsetting a curve inwards by more than that radius
folds the offset line through itself, which threw mountain geometry across the
road. The scaling is smoothed along the track, or neighbouring sections shrink
by different amounts and the range breaks into slivers.

## Race loop

Completing a lap swaps in a freshly generated circuit, then holds both cars
still for `preview_seconds` (3 s) so the players can read the new track before
it starts.

A lap is counted with four ordered sectors rather than by watching progress
wrap past zero. Progress alone cannot tell a car that has driven all the way
round from one sitting just behind the line, since both read as almost a full
lap; and the curve's start and end coincide, so a car on the grid can report
either nearly zero or nearly a whole lap. Requiring all four sectors in order
fixes both, and rejects course-cutting for free. These sectors become Phase 6's
checkpoints.

## Slipstream

Tucking in behind the other car raises top speed by up to `slipstream_bonus`
(22%), fading out by `slipstream_range` (22 m). It applies only to the car
behind: the rival must be ahead within a cone and both must be travelling the
same way, which makes it an overtaking aid rather than a free boost.

## Phases

- [x] **0** — repo, Godot project, `.gitignore`
- [x] **1** — one car driving (WASD)
- [x] **2** — second car (arrow keys)
- [x] **3** — split screen
- [x] **4** — a hand-made track
- [x] **5** — procedural track generation
- [ ] **6** — countdown, checkpoints, finish, winner, timer
- [ ] **7** — polish: models, environment, audio, particles, UI, themes, boosts
