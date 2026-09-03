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
| Reset      | R              | M               |
| View       | C              | L               |

Reaching the finish generates a new course and pauses for three seconds.

Both players use the same `scenes/car/car.tscn`. A car reads its actions from an
`input_prefix` export (`p1` / `p2`) and takes its paint from a `body_color`
export, so adding a third player would mean one more instance and one more set
of `p3_*` actions.

## Car model

Both players drive `car_low-poly_jdm.blend`, exported to `assets/models/car.glb`
by `tools/export_car.py`:

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b "path/to/car_low-poly_jdm.blend" --python tools/export_car.py
```

It replaced an earlier low poly car that was only a body shell and four wheels.
This one carries an interior, a steering wheel and a gear stick, which is what
makes the first person view worth having. The export turns it to face +Y, which
glTF maps to Godot's forward -Z - the model is authored facing -Y - re-origins
it to the centre of the wheelbase sitting on the ground, and renames the rear
wheels from RL/RR to the BL/BR the car script looks for. Its authored size,
4.87 m long, is left alone.

At run time the car takes private copies of two of its materials. The paint
carries the player's colour, and the glass is authored fully opaque, which
walls the driver in; it is made transparent instead. Everything else is left as
authored, including the double-sided faces: with a real interior, the shell
reading solid from within is what encloses the cockpit rather than leaving the
first person view open to the sky.

## Views

Each player can switch between the chase camera and the driver's eye - C for
player one, L for player two. The first person camera is bolted rigidly to the
car rather than smoothed: lagging a first person view behind the steering reads
as the whole world sliding about. The model's own steering wheel turns with the
front wheels, three times as far, about the column its disc sits on.

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

## Surroundings

The land around the circuit comes from "Low Poly Scenery Hills and Lake.blend",
exported by `tools/export_scenery.py`.

That blend is an island diorama about 2.8 units across: hills rising out of a
lake that covers its whole footprint, with no flat ground anywhere in it. It
cannot be the ground *under* a course - scaled up to cover the map its relief
is around 190 m, and a course, which is generated flat and lifted so its lowest
point rests at zero, would run through hillsides and under the water. So it
rings the play area instead, ten copies at about 900 m, well clear of the 480 m
half-extent a course is held inside. The ring is laid out from a fixed seed, so
the horizon stays put while courses come and go.

Two things about the asset needed handling, both of which look like rendering
bugs but are not:

- Its materials drive Base Color from a ColorRamp fed by a Geometry node, which
  glTF cannot express, so everything exported plain white. The exporter bakes
  each ramp down to one flat colour, which suits flat-shaded low poly anyway.
- Each island's lake is a single plate most of its width. Left above ground
  level, ten of them ring the horizon and read as a dark band across the sky,
  seen edge-on from beneath.
- An island is a cut-out piece of ground, so wherever its surface crosses the
  ground plane there is a seam. Sunk shallowly that seam falls on the gentle
  outer slope and reads as a ring round the foot of each hill.

Sinking them deeply solves both: the waterline goes under the ground, and the
seam lands high up where the terrain is steep enough to hide it. The islands
are enlarged to compensate, which also makes them overlap into a continuous
range rather than a row of separate lumps.

## Trees

The wood on the grass comes from "Low Poly trees pack.blend", exported by
`tools/export_trees.py`.

Each tree in that pack is a collection of loose parts - a trunk plus a pile of
leaf planes or spheres - so the exporter joins each of the five collections
into one mesh, standing on the origin, and drops the pack's rocks, lights and
camera. They come out at 350-1440 triangles each with flat colour materials,
so unlike the scenery nothing has to be baked down for glTF.

`Trees` plants 900 of them by rejection sampling: a point anywhere in a 600 m
disc - stopping short of the hills, or trees would grow out of the hillsides -
thrown away if it lands within `road_margin` of the road, on the embankment
under a raised section, or within `min_spacing` of a tree already standing.
The embankment allowance grows with the height of the road there, matching the
track's own batter, so trees keep off built-up ground instead of standing part
way up its slope.

The wood is replanted for every course, because the road it has to keep clear
of moves, but it is not random run to run: the seed is taken from the shape of
the course itself, so the same course is always planted the same way.

They are decoration and carry no collision. A car that leaves the road is
turned back by the rails long before it reaches one, and 900 collision shapes
would cost far more than that corner case is worth. Each kind of tree is drawn
as one MultiMesh, which is what makes a wood this size affordable in two
split-screen views; the placements are also kept in an array, since a
MultiMesh cannot be read back under the headless renderer.

## Day and night

The world runs a day/night cycle from the moment the game starts:
three minutes of daylight, a sunset, three minutes of night, a sunrise, and
round again. The holds are what those times name - "night lasts three minutes"
means three minutes of actual night, with the fades on either side of it rather
than eaten out of it. The clock is not reset when a new course is generated, so
a session that runs through several courses still gets to night.

`scripts/day_night.gd` drives three things together, because moving one alone
reads as a bug: the sun, the sky, and the ambient light. Dimming only the sun
leaves a bright blue sky at midnight; dimming only the sky leaves black grass
under a white sun.

Each fade runs through a middle keyframe rather than straight from day to
night, which is what puts an orange sun on the horizon on the way past instead
of simply turning the daylight down. The sun drops to the horizon over the
first half of a fade and the moon climbs over the second, swung round the
compass so it does not pop back up where the sun went down.

Night is moonlight, not darkness - the players still have to drive. The sky at
night is nearly black, so ambient taken from it is nearly nothing; the
environment's sky contribution is dropped below full so the ambient *colour*
fills in, and that blue is what the track is lit by. `night_amount()` reports
where the cycle stands, for anything that should react to nightfall later.

`tools/checks/day_night_shot.gd` renders the world at four points in the cycle:

```bash
Godot --path . --script tools/checks/day_night_shot.gd -- /tmp/shots
```

## Rails

A low barrier runs down both edges of the road and across both ends. It stands
on the outer part of the kerb rather than just beyond it, so on a raised
section it rests on solid road instead of hanging over the embankment's slope.

Both ends are capped. The sides alone leave the course open behind the start
line and past the finish, and a car that turns round simply drives out of the
open end and off the raised road - which is exactly what testing found.

Its collision shape takes backfaces, because a rail is a thin sheet that cars
arrive at from the inside; without that they would drive through it whichever
way its faces happened to point.

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
built, so the players see the result over the course they just drove rather than over a track they
have not seen yet.

Each half carries its own HUD: the player's position in the top left with the
clock beneath it, and their checkpoint tally centred at the top. All three are
per player, since each is tracking their own run.

Position shows a dash until somebody actually leads, rather than picking one of
two cars that are level on the grid. It takes `lead_margin` to claim a place
and a fall back inside the smaller `level_margin` to give it up, so the display
cannot strobe while the cars run wheel to wheel.

The clock runs only while the cars are actually free, so neither the countdown
nor the result screen is counted in a player's time.

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

## Checkpoints

Four checkpoints are spread evenly between the start and the finish, painted as
yellow bands. They exist to be reset to: a player who falls off, gets stuck or
ends up facing the wrong way presses their reset key and is put back on the
centreline at the last one they passed, stopped and facing down the course.
Before the first checkpoint that is the grid itself.

A checkpoint is only banked while the car is actually on the course, so a
player cannot collect them by driving across the scenery and then reset forward
onto ground they never drove. The tally at the top of each half counts them,
0/4 up to 4/4.

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
- [x] **6** — countdown, checkpoints, finish line, winner, timer
- [ ] **7** — polish: models, environment, audio, particles, UI, themes, boosts
