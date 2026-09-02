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

Reaching the finish generates a new course and pauses for three seconds.

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

Courses are generated at run time from a seed and run **point to point**: they
start at a start line and end somewhere else entirely, rather than looping.
Reaching the finish generates a new one.

`scripts/track_layout.gd` chains modular pieces - straights, corners and
climbs. Each piece joins the last at a socket, taking its position, heading and
height from the previous piece's exit, so a seam can never gap or kink. Not
having to close the loop is what keeps this simple: corner angles, directions
and climbs are all chosen freely, with no closure constraint to satisfy.

Piece lengths are rounded to a whole number of samples, so every point on the
centreline is exactly `sample_step` from the next and a distance along the
course indexes the sample arrays directly.

Two things can still go wrong, and both are checked with the caller retrying on
the next seed: a course can wander into itself, and it can wander off the
ground. Roughly three quarters of seeds pass, so a retry is cheap.

How twisty a course is comes from `max_straight` and `max_corner_radius`, not
from `self_clearance`. Clearance only rejects courses that fold too tightly; it
never makes the generator fold them, so lowering it alone barely changes the
result.

The ground is flat, and nothing currently stops a car leaving the road - the
mountain ranges that used to line the course were removed because they did not
work well enough to keep. Barriers are still to come.

Because the ground is a single flat plane, a course that descends does not cut
into a hillside, it is simply buried: the road vanishes under the grass and the
cars drive over the top of it, which looks exactly like the road has been cut
in half. The whole course is therefore lifted so its lowest point rests on the
ground, and raised sections are skirted down to it by an embankment. The
embankment carries no collision on purpose - driving off a raised section
should drop the car onto the grass, not run it into a wall.

`scripts/track.gd` turns that centreline into geometry. Nothing there wraps
from the last sample back to the first - on a course that does not rejoin
itself, wrapping would draw a road from the finish straight back to the start.

Corner pieces carry their own width: tight radii get `narrow_half_width`, open
sweepers the full width, blended across the seams so a hairpin opens out into
the straight rather than stepping.

Road triangles are wound clockwise seen from above, which is Godot's front
face. Getting that backwards makes the road invisible from above and, because a
`ConcavePolygonShape3D` only collides with its front faces, drivable straight
through.

## Steering

Steering is expressed as a **turning radius** rather than a turn rate, because
courses are built from corners of a known radius, so the numbers say directly
which corners the car can take. The radius grows with speed, the way a real car
washes wide.

An earlier version scaled the turn *rate* by speed. That cancelled the speed
out of the turning-circle equation entirely and left one fixed 13.9 m circle at
every speed, so no hairpin was drivable however slowly it was taken.

## Race loop

Reaching the finish line swaps in a freshly generated course, then holds both
cars still for `preview_seconds` (3 s) so the players can read the new one
before it starts.

The finish is painted as a chequered band across the road, drawn at
`Track.finish_offset()` - the same value the race checks - so the line the
players cross is exactly the line that ends the race, and the two cannot drift
apart. A plain white band marks the start, at `Track.start_offset()`, with the
grid placed `grid_setback` metres behind it; the start is deliberately not
chequered so the two are never confused on an unfamiliar course.

Crossing the line stops the clock, names the winner by the colour of their car
and holds both on screen for `result_seconds` (2 s) *before* the next course is
built, so the players
see the result over the course they just drove rather than over a track they
have not seen yet.

The clock sits in the bottom right of each half and runs only while the cars
are actually free, so neither the countdown nor the result screen is counted in
a player's time.

The winner's name comes from their `body_color` rather than from which player
they are, so recolouring a car renames it too.

A countdown fills the preview pause rather than adding to it: three, two, one,
GO, with the cars released on GO. It runs for the first course as well as every
later one, and appears in both halves of the screen. Each countdown carries a
run number so a timer left over from the previous one cannot blank the text of
the current one.

A car counts as finished only while it is still within `finish_corridor` of the
centreline: a car lost out in the scenery projects onto the nearest point of
the course, which can be the finish.

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
- [x] **6** — countdown, finish line, winner, timer
- [ ] **7** — polish: models, environment, audio, particles, UI, themes, boosts
