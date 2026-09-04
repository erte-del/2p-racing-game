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

## Menu

`scenes/menu.tscn` is the game's main scene now, so it is what opens on launch:
the title and a Play button that swaps in `main.tscn`. The button takes
keyboard focus on its own, so Enter or Space starts the race - both players are
already on one keyboard and neither should have to reach for the mouse.

Behind the title is not a picture but the game itself: a real instance of
`main.tscn` in **attract mode**, with its own generated course, scenery and
day/night cycle, and the two cars parked on the grid. The camera turns slowly
about the point midway between them, a full circuit taking a minute and a half,
which reads as drifting rather than as a turntable. Being the real scene means
the menu can never go stale - and a player who sits on it watches the sun go
down and the headlights come on.

The cycle is wound right in for the menu: `attract_phase_seconds` (25 s) gives
day, evening, night, morning, round again in a hundred seconds, where the race
runs six minutes to a cycle. Nobody sits through three minutes of daylight
waiting to see whether a title screen does anything.

Attract mode does not merely hide the race. The split screen is switched off
rather than made invisible, because a SubViewport set to update always goes on
rendering behind a hidden container, and drawing the course twice more for
nobody would cost as much as the menu itself. The rival arrows have their
processing stopped rather than being hidden, because each decides for itself
every frame whether it should be visible and would simply turn itself back on.

A light shade sits between the world and the text. The backdrop is meant to
show through, but a white title over a bright noon sky is a coin toss, and the
shade settles it without hiding anything.

The title never sits perfectly still. It rocks a couple of degrees either side
of upright and bobs a few pixels, which is what keeps a screen that is doing
nothing from looking frozen. The two motions run on deliberately unrelated
periods: on the same beat they read as one mechanical wobble, drifting apart
they read as idling.

The label rides inside a slot that the layout positions, so its own resting
position is always zero. Bobbing it from a position captured at startup would
drift, and would be wrong again the moment the window was resized.

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

## Headlights

Each car carries two spot lights either side of its nose, and they come on by
themselves as the light goes. They are tied to the sky rather than to the race,
so they are already lit while a night course is counting down, and they fade up
across the sunset instead of snapping on at full dark - `lights_on_at` and
`lights_full_at` on the main scene are the two points of the cycle they ramp
between.

The car is told a *level*, not the time of day. It has no business knowing what
the sky is doing, and a level can just as well come from a tunnel or from a
player pressing a button later.

Two things light up together, because either alone looks wrong: the beams on
the road, and the lamp panels on the car's face. Those panels are a material in
the model rather than geometry of their own - the model authors them
permanently emissive, which is only right once they are switched on, so the
car's copy of that material starts at zero emission and is turned up with the
beams. Their position, x +/-0.602 and 0.683 above the ground, 2.179 ahead of
the wheelbase centre, is measured off the model's own lamp quads.

The beams cast no shadows. Two cars with two beams each, in two split-screen
views, is eight shadow-casting spot lights for something that is meant to be
decoration.

`tools/checks/headlight_shot.gd` looks at a car head on, by day and at night.
It also renders night with the lamps forced off, which is not redundant: the
painted white start band looks exactly like a headlight pool, and turning the
lamps off is the only way to tell which is which.

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

## Boost

`Car.boost(strength, seconds)` hands a car a temporary lift in top speed -
`boost_bonus` (55%) held for `boost_hold` (1.4 s), then bled away at
`boost_fade` (0.35 per second). Both arguments default to that tuning, so
whatever hands out a boost can simply call `boost()`.

It works the same way the slipstream does: nothing sets the car's speed, the
boost only raises the ceiling the throttle is working towards. That is what
makes the boost outlive its own timer - as it fades the car is left above its
own top speed and coasts back down to it, still carrying the surge into
whatever comes next. Holding the throttle while over the ceiling sheds the
overspeed at the coasting rate, so keeping your foot in can never slow the car
faster than lifting off would.

Boosts do not stack. A second one takes whichever bonus is larger and restarts
the hold, because a generated course will sometimes lay down a run of pads and
adding them together would leave a car nobody can drive. Steering is left out
of it too: the turning circle is worked out against `max_speed`, so a boosted
car does not wash any wider than one flat out on its own. Being fast enough to
miss the corner is the risk a pad should carry; being unable to steer is not.

`tools/checks/boost_trace.gd` runs two cars flat out from the tuned top speed,
gives one a boost, and prints the gap:

```
Godot --path . --headless --script tools/checks/boost_trace.gd
```

On the tuned numbers the boosted car peaks at 38.8 m/s, spends 3.7 s above its
own top speed, and finishes 27 m up the road - about six car lengths, on a
course of 620-1050 m.

## Speed rush

Anything that makes a car quicker than it has any right to be shows the same
way: the camera eases back and widens, and white streaks sweep out past the
edges of that player's half of the screen. A boost pad, a slipstream and a run
down a hill all read as one thing, so a player never has to learn a second
signal for a second kind of speed.

`Car.overspeed()` is the whole of it - one number from 0 to 1 for how far past
its own `max_speed` a car is, full at `overspeed_reference` (50%) over. A pad
is worth 55%, so it very nearly fills the gauge; a slipstream is worth 22%, so
it shows plainly without ever looking like one. The ceiling counts as well as
the speed itself, so the rush lands the instant a pad is crossed rather than a
second later once the car has caught up with its new top speed, and it is
scaled by how fast the car is actually going, which stops a car crawling along
in someone else's wake from putting on a light show.

`ChaseCamera` adds `rush_distance` (1.5 m) and `rush_fov` (7 degrees) at full
rush, eased in over `rush_ease`. Small on purpose: it should be felt as the car
pulling away from the camera, not noticed as the camera moving. The cockpit
view only gets the wider angle, since there is nowhere for a camera bolted to
the driver to pull back to. The resting field of view is read once at `_ready`
rather than off `fov`, or swapping in a course would bake the rush into it and
the view would creep wider every race.

`SpeedLines` is a `Control` inside each player's SubViewport, so the streaks
are clipped to that half of the screen and cannot bleed across the split. The
streaks sweep outward from the middle of the frame over an ellipse the shape of
the view - a circle would leave the sides bare and crowd the top and bottom -
starting well outside the middle, where the car and the road ahead are. Their
angles are one per equal slice of the circle rather than rolled freely, because
free angles clump and the bald patches read as the effect being broken.

`tools/checks/rush_shot.gd` parks two cars side by side on the same stretch of
road and gives only the top one anything, so the bottom half of every picture
is the control:

```
Godot --path . --script tools/checks/rush_shot.gd -- /tmp/shots
```

## Boost pads

A course is planned in two passes. `TrackLayout` chains the pieces and samples
the centreline; `TrackFeatures` then reads that finished chain and decides what
furniture goes on it. The planner builds no nodes and no meshes, so a plan can
be checked before any geometry is paid for, the same way a layout is. Every
piece now records the offsets it starts and ends at, which is what lets the
planner put a pad somewhere chosen rather than somewhere random - they are the
same offsets the curve, the finish line and the checkpoints are measured in.

Placements are an offset along the course plus a lateral position across it.
Lateral is normalised, -1 at the left edge of the road and +1 at the right,
never metres: the road narrows through the corners and chaos mode rerolls both
widths for every race, so a pad pinned at "2.4 m right" would sit on the kerb
on a narrow roll and in the middle of the road on a wide one.

Pads go on straights only, at least `min_pad_straight` (40 m) long, at most
`pad_chance` (0.72) of them, `min_pad_spacing` (60 m) apart, and `pad_margin`
(12 m) clear of the corner at either end - a pad on a corner exit fires before
the car is pointing anywhere useful, and one on the entry sends it in far too
hot to have had a choice about it. They also keep `pad_keep_out` (20 m) from
the grid, the finish and every checkpoint, because a free boost for being
respawned is not a reward anyone earned. Each pad sits in the left, middle or
right lane. Nothing is being avoided yet, so for now that only decides how far
off the racing line a pad is - but pads are lane furniture from the start,
because what eventually hangs off one is a hazard in that lane and clear road
in the other.

`TrackFurniture` builds the plan: a dark slab with glowing chevrons pointing
the way, and an `Area3D` over it that calls `Car.boost()`. It is the only part
of the track that makes nodes per course rather than rewriting a mesh in place,
so it clears itself out on every build - the endless loop lays a fresh course
after every race, and pads left over from the last one would pile up on the
new one. The pad is cut into its own grid rather than drawn on the road's
samples, which are 2.5 m apart, coarser than a whole chevron and no use for
drawing an arrow. The chevrons are emissive so a pad still reads as a pad at
midnight; the course runs through a whole day and night, and paint that only
showed up in sunlight would leave half the races with furniture nobody can see.

The furniture is seeded from the same seed the course is, so a given seed
describes a whole race and not just its shape.

`tools/checks/pad_layout.gd` lays out a hundred courses and checks every pad on
them - none over the kerb, none on a corner or at the end of a straight, none
on the grid or a respawn, none stacked on the one before - then parks a car on
a pad to confirm it pays, and one alongside to confirm it does not:

```
Godot --path . --headless --script tools/checks/pad_layout.gd
```

`tools/checks/pad_shot.gd` looks at a pad from the car's own view, by day and
at night:

```
Godot --path . --script tools/checks/pad_shot.gd -- /tmp/shots
```

## Barriers

Rows of striped barriers stood across part of the road, on the same straights
the pads go on and planned by the same `TrackFeatures` pass. A row never blocks
all of the road. Two things have to hold, and neither is visible from looking
at a single row:

- **There is always a way past.** A row is narrowed until the gap it leaves is
  at least `clear_lane` (3.4 m) - the car is 2.06 m wide, so that is it plus
  room either side to aim with. A row is never dropped for being too wide, it
  is cut back, because a narrower barrier somewhere interesting beats no
  barrier.
- **The way past one row can be reached from the way past the row before it.**
  Two rows blocking opposite sides are each perfectly passable alone and are a
  dead end together, if they sit close enough that no car could cross the road
  between them. A car crossing from one gap to the next turns in and back out
  again, which over a run of L metres at radius R shifts it about L²/4R
  sideways; turned around, the run needed for a shift of d is √(4Rd). Rows are
  spaced by that, times `dodge_margin` (1.4), because a player also has to see
  the row and decide before any of the turning starts.

`dodge_radius` (16 m) and `clear_lane` are the car's own numbers - its widest
turning circle and its width plus room. Change the car and these follow.

Rows are built to pass those rules rather than rolled and rejected: where a row
may stand is not known until it is known what it blocks, so each one is placed,
narrowed to fit the road where it ended up, and only then pushed downstream far
enough that the gap through it leads to the gap through the last one. Which
part of the road a row takes is rolled - in from the left edge, in from the
right, or down the middle with a way past on either side.

`TrackFeatures.faults()` then checks the finished plan against the same two
rules, so a mistake in the construction shows up as a fault rather than as a
course nobody can finish.

Hitting one costs speed. `move_and_slide` stops the car going through a
barrier, but will not take its speed away on its own, so a car held against one
would sit there at full throttle reading as fast while going nowhere.
`Car.obstacle_scrub` (72%) is charged against how square the hit was - from
everything for driving straight into one to almost nothing for a glancing blow
- and it ends the boost outright, because carrying a pad through the hazard it
was offered against would leave nothing to weigh up. `obstacle_recovery`
(0.4 s) is how long before another hit can cost anything: a car held against a
barrier touches it every frame, and charging for each of those takes a single
mistake to a dead stop before the player has a frame to steer out of it. Only
bodies in the `obstacle` group cost anything, so the rails at the edge of the
road still cost nothing - a car scraping down one is already being pushed back
where it belongs, and taking its speed as well would punish it twice for a
mistake it is in the middle of recovering from.

`tools/checks/barrier_layout.gd` lays out a hundred courses and checks every
barrier on them, then hands the validator two plans that break the rules on
purpose - a validator that has never rejected anything is not obviously
working - and finally runs a car at a barrier and through the gap beside it:

```
Godot --path . --headless --script tools/checks/barrier_layout.gd
```

On the tuned numbers that is 6.3 barriers a course, none with fewer than one,
no way past narrower than the 3.4 m rule, and no faults. Driving square into
one takes 25 m/s to 7 and wipes the boost; taking the gap beside it costs
nothing at all.

How many barriers a course carries is mostly decided by `same_side_chance`
(0.55) rather than by any count. Two rows holding the same side of the road
leave the same way past, so they can follow one another closely; two that swap
sides need most of a straight between them. Rows are laid down blocking the
same side as the one before them more often than not, and that is what lets a
straight carry a run of barriers instead of a pair.

A row is wound the way the road is - what Godot takes as the front of a face
is the opposite of the right hand rule on its corners - so the face a car
arrives at is the one turned towards it. Wound the other way every panel shows
the player its back, which lights as though the sun were behind it.

## The fork

Every course has one stretch where the road is split down the middle by a
divider: a boost pad and a run of barriers on one side of it, nothing at all on
the other. Take the boost and thread the barriers, or give up the boost and
have clear road. That choice is the point of the pads and the barriers both, so
a course that happened not to offer one would be missing the feature rather
than simply being quiet - the planner lays the fork down first and gives it the
best stretch of road on the course, and the loose pads and barriers fill in
around what it claims.

The divider is what makes it a choice rather than a scattering. Without one a
player who took the pad could drift across to the empty part of the road and
keep the boost for nothing; with it, taking the pad commits the car to the lane
the hazards are in for as long as the divider runs.

The pad sits *inside* the fast lane rather than in front of the fork. The split
and the reward then arrive together, so a player sees what is on offer and what
it costs in the same moment - and a fork needs only as much road as its
divider, instead of a pad's length and a gap on top. That is what lets one fit
on a course with no really long straight anywhere on it: with the pad out in
front, two courses in five had nowhere to put a fork at all.

A straight is not thrown away for having a checkpoint on it either. A fork is a
good deal shorter than the straights it goes on, so it is fitted into whichever
part of one is clear of the grid, the finish and the respawns; and on a course
where every long straight has a respawn planted in the middle of it, the fork
is built closer to one than it would like rather than not at all. Between them
those two changes took forks from 60 courses in a hundred to all of them.

Barriers down the fast lane alternate between the divider and the outer kerb,
so the lane is a slalom rather than a corridor, and each is set as far past the
last as crossing between the ways through them actually asks for - the same
arithmetic the loose rows use, applied inside a lane instead of across the whole
road. `TrackFeatures.faults()` checks the fast lane on its own as well as the
course as a whole: the divider means a car in the lane cannot cross out of it,
so a lane that closes up is a dead end even though the road around it is
perfectly driveable.

A divider is striped down its length rather than across its width, because a
wall 40 m long and a metre wide striped the way a row is comes out as one red
half and one white half and reads as a painted line.

`tools/checks/barrier_shot.gd` looks at a fork from the cars' own view, by day
and at night, with the top car in the fast lane and the bottom one in the clear
lane - the two halves of the picture are the two ways through the same stretch
of road:

```
Godot --path . --script tools/checks/barrier_shot.gd -- /tmp/shots
```

## Jumps

A jump is a fourth kind of track piece alongside straights, corners and
climbs, not a prop laid on the road: a ramp, a hole where there is no road at
all, and a long flat run to come down on. It is height neutral - the ramp
lifts the road and the landing puts it back - so a jump never moves the course
up or down and the height budget a climb is checked against is untouched.

Jumps go *after* a straight rather than in place of one, and only after a level
straight of at least `jump_run_up` (45 m). The straight is the run up: a car
reaches the ramp with the speed it chose to carry rather than whatever it
happened to have coming out of the corner behind it, and taking off from a
grade would throw the car at an angle nothing else on the course accounts for.
At most `max_jumps` (3) to a course.

`TrackLayout` now records `road_present` for every cross-section, and `Track`
skips the asphalt, the kerbs, the rails and the embankment wherever it is
false. The centreline itself carries on across the hole, on the line the road
would take if it were there, so progress, places and the rival arrow are all
unaffected by a car being in mid air. The ramp and the hole are snapped to the
sampling grid before anything is built from them: a hole of six and a half
metres sampled every two and a half comes out as ten metres of missing road,
which is a very different jump from the one the numbers describe.

Three things about the car had to change, and each was found by driving one at
a real ramp rather than by reasoning about it.

**A car on the ground has no vertical speed of its own** - it follows the road,
because `move_and_slide` slides it along the surface. That is right everywhere
except where the road runs out, and a car that leaves a ramp travelling flat
does not jump, it falls off the end. So the climb the road is giving it is
measured while it is still on the ground and handed to it as it goes.

**That climb has to be remembered, not read off the last step.** The car is a
single long box, so as it crests a lip the front of it loses the road while the
back is still on the ramp, and for a tenth of a second it settles rather than
climbs. Taking the climb from the last step alone reads that settling as the
launch and throws the car at the ground - which is exactly what it did. It is
kept as a peak that fades at `climb_memory` instead.

**The ramp cannot meet the road at its full angle.** A wedge makes a crease,
and a car driving at one catches its front edge on it: at some speeds it
climbed a little way and then jammed there and stopped dead, which is how the
same jump was cleared at 19.5 m/s and 38.8 m/s and impassable at 25. The ramp
comes up out of the road as a curve (`ramp_curve`, 1.5), leaving the steepest
part at the lip where the angle actually does any work.

The hole is 17 m, and it is the one thing about a course measured against the
cars rather than rolled freely. A hole a car cannot clear flat out is not a
risk, it is a wall across the road - and chaos rolls worlds where the cars are
slow and heavy and cannot throw themselves nearly as far. So `Chaos` shortens
the hole for the world it just rolled, by how far cars of that speed under that
gravity actually fly. It only ever shortens it: a quicker world could clear a
longer hole, but the road to come down on is a fixed length, and a hole that
grew every time chaos rolled a fast car would outrun its own landing. The floor
is half the tuned hole, below which it stops being longer than the car - and a
hole a car can lie across is one it drives over without ever leaving the ground.

How far a car flies is taken as powers of the speed and gravity rolls
(`FLIGHT_BY_SPEED`, `FLIGHT_BY_GRAVITY`), fitted to real flights rather than
worked out: the launch is capped, so range does not follow the clean projectile
square of speed.

The landing is long - 90 m - because the range of a jump is decided by the speed
it is taken at. The same ramp puts a car down 15 m past the lip at the slowest
the game rolls and 79 m past it at the fastest, and the road has to reach the
far end of that.

Nothing else is built on a jump. The pads and barriers keep off the stretch a
jump covers, plus `jump_keep_out` (12 m) either side, and a checkpoint that
would land on one is moved to whichever end of it is nearer - a car put back on
the road at a ramp would go over the edge with no run up, and one put back in
the hole would drop straight through. Falling in is recovered the way falling
off has always been recovered: the reset that puts a car back at its last
checkpoint.

`tools/checks/jump_flight.gd` drives a car off a real ramp at every corner of
what chaos can roll - speed from 0.78 to 1.7 of tuned, gravity from 0.65 to
1.4, and both at once - and asks the world what it came down on rather than
working it out from the curve. Each roll is given the hole that roll would
actually be built, since testing every one of them against the tuned hole would
be testing a course the game never lays down:

```
Godot --path . --headless --script tools/checks/jump_flight.gd
```

At tuned speed and gravity that is a 17.5 m hole cleared by 10 m; at the
slowest, heaviest roll chaos can produce it is a 10 m hole cleared by 4.6 m.
The longest flight is 79.1 m against 107.5 m of road to come down on, and no
roll crosses without leaving the ground. It then asks the opposite question,
because a jump every car clears whatever it does is scenery rather than a risk:
a car crawling at 8.8 m/s comes down 5.6 m short and ends up on the grass.

`tools/checks/jump_shot.gd` looks at one - the top car back on the run up where
the choice to commit is made, the bottom one held in the air over the hole,
which is the only way to see what is under a car in mid jump:

```
Godot --path . --script tools/checks/jump_shot.gd -- /tmp/shots
```

## Tilt

The car pitches to follow the road: nose up a climb and a ramp, nose down over
a crest and through the falling half of a jump. What tips is the shell, not the
body. The body is a `CharacterBody3D` that is only ever yawed, and its box is
what the car actually drives on - pitching that would change what the car can
climb, how it sits on a kerb and where its nose catches, all for something that
is only ever looked at. So the model, the headlights and the driver's eye all
hang off a `Body` pivot that tips underneath an upright collision box.

On the ground the angle comes from the surface the car is standing on, so it
reads the road it is on rather than the road it has been over. In the air it
comes from where the car is going, which is what puts the nose up off a ramp
and down again on the way to the landing. It is eased rather than set, because
the ground under a car changes in steps - one triangle to the next, and all at
once on landing - and a shell that followed that exactly would snap about.

Writing this turned up an older bug. `look_at` aims *whatever it is given*, so
putting a car on the grid or back on the course at a checkpoint pitched the
whole body whenever the point it was aimed at was not level with it - which on
a climb, and now on a ramp, it is not. A body left leaning drives itself into
the ground: the car takes its heading from its own -Z, so a nose-down car puts
part of its speed into the floor and quietly runs slow. The body is now levelled
every physics step, which is also what makes the jump numbers above right; they
were measured before against a car that had been leaning the whole way.

`tools/checks/tilt_trace.gd` drives a car over a jump, which has every case in
it in order - level road, a ramp, the nose coming up off the lip, the nose
dropping through the top of the flight, and the road again on landing - and
then over a plain climb:

```
Godot --path . --headless --script tools/checks/tilt_trace.gd
```

Level road reads 0.0 degrees, the ramp +24.6, the fall -29.8, and a 2.9 degree
climb reads +3.3.

## Laid-out tracks

Alongside the endless course there are tracks written down by hand. A track
file is a GDScript file that describes itself by building itself:

```gdscript
extends TrackDefinition

func describe() -> void:
	track_name = "First Light"
	straight(70.0)
	corner(55.0, 46.0)      # degrees, radius; positive turns right
	straight(30.0)
	pad(0.0)                # a boost pad, in the middle of the road
	straight(85.0)
```

There is no offset argument anywhere in it. Furniture goes down at the
distance the road has reached, so a track file reads as a description of
driving the track rather than as a table of numbers with distances in the
first column. Splitting a piece to make room costs nothing: two straights in a
row sample exactly as one straight of their combined length.

What comes out is the same `Piece` chain the generator produces and the same
`Placement` list the planner produces. `TrackLayout.adopt()` and
`TrackFeatures.adopt()` take them, and everything downstream - the road mesh,
the curve, the offsets, the rails, the embankment, the checks - neither knows
nor cares that a track was written down instead of rolled. The three numbers a
track file is not allowed to choose are the sampling step and the ramp, hole
and landing of a jump: `Track` sets those before calling `describe()`, so
every jump in the game is the same jump and a player who has cleared one knows
what the next one asks.

Nothing rejects a hand-made track. A generated course is one of thousands and
a bad one is thrown away for the next; a hand-made one is the only one there
is, and refusing to build it would leave whoever wrote it with a blank screen
and no idea why. `TrackLayout.problems()` says what a generated course would
have been rerolled for - passing too close to itself, running off the ground,
not enough straight for the grid or the flag - and `TrackFeatures.faults()`
still holds authored barriers to the same two rules as generated ones: there
is a way past every row, and it can be reached from the way past the row
before it. Both of those caught real mistakes in the first track.

`tools/checks/track_check.gd` builds a track and says what is wrong with it:

```
Godot --path . --headless --script tools/checks/track_check.gd -- res://tracks/01_first_light.gd
```

`tools/checks/track_map.gd` draws it from above, which is the answer to "is
that hairpin where I think it is" - the question authoring a track is mostly
made of:

```
Godot --path . --script tools/checks/track_map.gd -- /tmp/shots
```

And `tools/drive_track.gd` drives one, in the game as it stands - two cars and
a split screen, until solo mode exists:

```
Godot --path . --script tools/drive_track.gd
```

## Choosing a track

Play opens the mode page, and Tracks now opens out of it into a grid of
twenty. Each cell is the track's name over an overhead shot of the road it is.

The grid is as long as the game intends to be, not as long as it currently is.
A slot with nothing in it is still shown, framed and unpressable, because
nineteen doors that do not open yet say what the game is going to be - a short
grid that grew every few weeks would say nothing at all. An empty slot gets its
own dark outlined face rather than the theme's disabled grey, which fades a
button into the page until it reads as a hole rather than as a track to come.

The cells are built in code from `TrackRoster` rather than written into the
scene: twenty of them is a great deal of scene, and every one would have to be
edited again the day a track was added. A track's name is read off the track
itself by building its description, which costs a few array appends and no
geometry - a name written down in two places drifts, and the one on the button
would be the one nobody notices is wrong.

The overhead shots are checked in rather than drawn at load. A menu that built
twenty tracks to show twenty pictures of them would take a second to open, and
the pictures do not change between runs. `tools/track_thumbnails.gd` draws them,
and wants running after laying out a track or changing the shape of one:

```
Godot --path . --script tools/track_thumbnails.gd
```

Scenery is left out of them. At the size they are shown, trees and hills come
out as noise across the one thing the picture is for, which is the shape of the
road.

The track that was picked travels to the race in `GameSettings.track_file`, the
same way the chaos choice does, and is not written to disk: it is what was
picked on the way into this race rather than a preference, and a game that
opened straight back onto the last track someone tried would be answering a
question nobody asked. Infinite clears it. Tracks also turns chaos off - a
track is a road to learn and a time to beat, and a time set by a car nobody
will be given again is not a time.

Leaving a track puts a player back on the grid of tracks rather than at the
title, with the cursor on the one they were driving. A player who has just
driven a track is nearly always about to drive another, or the same one again,
and making them walk back in through two pages to do it is asking them to say
something they have already said.

The menu knows they came from a track because one is still picked - nothing
clears `GameSettings.track_file` but starting an infinite race - and that same
setting is how it knows which track to put the cursor back on. Opening the game
fresh, with nothing picked, still opens on the title.

`tools/checks/track_select.gd` presses the buttons and sees where they go,
which is three places for a track to be chosen and then quietly not raced: the
grid built in code, the setting carried across a scene change, and a Track that
has to divert from a seed to a file.

```
Godot --path . --headless --script tools/checks/track_select.gd
```

## Solo

A laid-out track is driven alone against the clock, in its own scene rather
than in the two-player race with a seat empty. Almost everything in `Main` is
about there being two of something - two viewports, two cameras, two arrows, a
leader, a winner - and threading a count through all of it would leave the
endless mode carrying a branch on every line for a mode it is not. What is
shared is shared as nodes instead: the car, the track, the chase camera, the
speed lines and the day and night cycle are the same ones the race uses.

The clock is the whole point. It starts on GO and stops on the line, and
nothing in between stops it. Going off the road, hitting a barrier, and being
put back at the last checkpoint all cost time rather than ending the run,
because time is already the punishment this mode has.

Enter runs again. It does not rebuild the track - it is the same track, and
rebuilding it would cost a second of watching a road appear that was already
there - so a retry is the car back on the line and the countdown again.
Instant retry is not a nicety in a mode like this: it is most of what makes
trying a corner again bearable.

Finishing measures the run against the best so far, which is kept in
`TrackTimes` and survives the game being closed.

`tools/checks/solo_run.gd` drives a whole run, from the line to the flag:

```
Godot --path . --headless --fixed-fps 60 --script tools/checks/solo_run.gd
```

The car is driven by the check rather than by a player: flat out where the
road ahead is straight, backing off as it bends, and aimed through whatever
`TrackFeatures.gaps_at()` says is open rather than down the middle. Both of
those had to be there. A car ambling at half throttle cannot clear the hole in
a jump, falls in, is put back at the checkpoint before it and ambles at the
same hole again for as long as anything lets it; and a car aimed down the
centreline drives nose first into the divider of a fork, which is not the
track being broken but a car refusing to pick a side.

`--fixed-fps` matters more than it looks. Without it the loop sleeps to hold
sixty ticks a second of wall clock, and driving a kilometre of road takes as
long as driving a kilometre of road; with it the same run takes about a second.

## Track times

`TrackTimes` is an autoload over a `ConfigFile` in `user://`, kept separate
from `GameSettings` because these are not preferences. A setting is something
a player chose and can change back; a time is something that happened, and the
only thing that may overwrite one is a better one.

Every time is stored next to a fingerprint of the track it was set on, which
is a hash of the track *file* rather than of the course built from it - the
file is what an author edits, and it changes if and only if they changed the
track. Edit a corner on track seven and every time set on the old track seven
stops meaning anything: it was a different road. Those records are dropped the
first moment anything asks for them, rather than standing as walls nobody can
get over because nobody ever drove them. `GEOMETRY` is bumped by hand for the
same reason when something outside the track files changes the road they are
all built from - the sampling step, the size of a jump, what a pad is worth.

A section per track rather than one section of many keys, so what a track has
to its name can grow - when the time was set, how many runs it took - without
moving what is already written down. Tracks are keyed by file name rather than
path, so moving the tracks folder does not lose everything anyone has driven.

The select screen shows each track's time under its picture, and rebuilds
itself every time the page opens: a player comes back to that screen straight
from having beaten something, and a grid built once at startup would still be
showing the old time. A track that has been driven shows the time, one that has
not says NO TIME, and a slot with no track in it says nothing at all - three
different things a player should be able to tell apart at a glance.

`tools/checks/track_times.gd` sets times, closes the game and sees what is
still there, then edits a track and sees that the time on the old one has gone.
It writes to a scratch file, so running it does not touch anyone's own record:

```
Godot --path . --headless --script tools/checks/track_times.gd
```

## Medals

Every track sets what a lap of it is worth - gold, silver and bronze in
seconds - in its own file, next to its corners. What counts as a good lap is a
fact about the road rather than a number that could be worked out from one: a
wide open kilometre and a kilometre of hairpins are not the same forty seconds.
First Light asks for 40, 45 and 50.

```gdscript
medals(40.0, 45.0, 50.0)
```

A target is a time to get under, not a time to match. 39.99 is gold and 40.00
is silver, because a medal for exactly the number on the screen would make that
number a lie in one direction or the other, and under is the one a player can
act on.

Nothing about a medal is stored. It is worked out from the best time and the
targets every time anything asks, so moving a target moves every medal that
depends on it at once - which is what you want while a track is still being
tuned, and costs nothing when it is not. A track that sets no targets has no
medals rather than every medal, and one that offers only some of them is walked
past rather than stalled on: a track with no silver takes a lap between the
gold and bronze times as bronze, and tells the player they are driving at gold.

The finish screen says the time, the medal in its own colour, and both of the
things a player might be chasing - how far under their own best the run was,
and how far off the next medal up. The corner keeps the standing best in the
colour of what it is worth, so the screen says how the track is going without
having to be read.

On the select screen each track carries a bar of its medal's colour directly
under its picture. Colouring the time alone was tried first and was not enough:
against a dark panel a silver time and a time worth nothing are two shades of
pale, and a medal that has to be compared with its neighbours to be seen is not
one. The medal colours are read against the game rather than taken from metal -
a true bronze disappears into the road, and a true silver comes out the same
white as the time printed above it, so it is pulled towards blue.

`tools/checks/medals.gd` works out what times are worth, including the edges
that are easy to get wrong: a lap exactly on a target, a track that offers only
some of the medals, and what to tell a player chasing the next one.

```
Godot --path . --headless --script tools/checks/medals.gd
```

## Adding a track

Everything a track needs is in place, so adding the next nineteen is three
steps and no code:

1. Write `tracks/NN_name.gd` extending `TrackDefinition`, set its `medals()`,
   and check it with `tools/checks/track_check.gd` and
   `tools/checks/track_map.gd`.
2. Add its path to `TrackRoster.FILES`, in the order it should appear.
3. Run `tools/track_thumbnails.gd` to draw its overhead shot.

The name on the button, the slot in the grid, the times, the solo race and the
checks all follow from those.

## Phases

- [x] **0** — repo, Godot project, `.gitignore`
- [x] **1** — one car driving (WASD)
- [x] **2** — second car (arrow keys)
- [x] **3** — split screen
- [x] **4** — a hand-made track
- [x] **5** — procedural track generation
- [x] **6** — countdown, checkpoints, finish line, winner, timer
- [ ] **7** — polish: models, environment, audio, particles, UI, themes, boosts
