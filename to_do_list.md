# To do

Five things to add to the game, written out properly: what each one is, why it
is worth having, the rules it has to obey, and the files it lands in. Damage
mode and traps are built (2026-09-16); nothing else here is yet.

The order below is the order they should be built in, and that order is not
arbitrary - damage needs nothing, traps need nothing, but the bot needs a
driver that does not exist, the medal gate needs the bot to be the thing it
gates, the shop needs coins to spend and customisation needs a shop to be
bought from. Anything built out of order ends up waiting on something.

Each feature follows the same shape the rest of the game already has:

- a setting or a store in `scripts/`, saved to `user://`, announced by signal
- rules that hold on every course, checked by a script in `tools/checks/`
- a README section saying what it does and why it is the way it is

A feature without its check is half a feature. Everything in this game that
can be got wrong quietly - whether a course can be driven, what a lap is
worth, whether chaos actually rerolls anything - has a headless script that
drives it and says so, and none of the five below is an exception.

## Contents

1. [Damage mode](#1-damage-mode) - **done**
2. [Traps](#2-traps) - **done**
3. [Acrobatic tracks](#3-acrobatic-tracks)
4. [The bot, and the medal gate](#4-the-bot-and-the-medal-gate)
5. [Coins](#5-coins)
6. [The shop](#6-the-shop)
7. [Car customisation](#7-car-customisation)
8. [What all of this touches](#what-all-of-this-touches)
9. [Questions worth settling first](#questions-worth-settling-first)

---

## 1. Damage mode

> **Done, 2026-09-16.** Built to the spec below, with the damage questions
> settled as follows:
>
> - Hitting the other car costs nothing.
> - Damage and chaos can both be on. Hits scale against the car's own
>   `max_speed`, so three flat-out hits break any car, chaos or not.
> - A boosted hit is not capped: a square hit on a pad costs about 53.
> - A broken car in solo sets no time.
>
> Differences from the spec:
>
> - The endless course does not roll on after a break.
> - The warning bar flashes red to white, not just red, because a red car's
>   bar is already red.
>
> What it does and why is in the README under **Damage**. The check is
> `tools/checks/damage.gd`. Everything below is the original spec, kept for
> the reasoning.

### What it is

A setting, off when the game is first opened, that gives each car a condition
as well as a speed. Hitting things wears the car down; wear it down far enough
and the car is finished and the run has to be started again.

Off by default is the important half of that sentence. The game as it stands
has one punishment for a mistake and it is time: you hit a barrier, you lose
speed, you carry on. That is what makes the endless course and the twenty
tracks bearable to practise on. Damage is a second punishment on top, and a
player who never asked for it should never meet it - so it is a setting, it
starts off, and a game opened for the first time drives exactly the way it
drives today.

### The rule

A hit costs condition in proportion to how hard it was. The hit the game
already measures is the right one to charge against: `Car._hit_obstacle` (the
block around [scripts/car.gd:860](scripts/car.gd:860)) already works out
`head_on`, how square the hit was, from the contact normal and where the car
was going, and already uses it to scale how much speed the hit costs. Damage
uses the same two numbers and nothing new:

```
damage = full_hit * head_on * (speed_into_it / max_speed)
```

- A square hit at the car's top speed costs `full_hit`.
- A square hit at half speed costs half of that.
- A glancing hit at any speed costs almost nothing, which is right: a scrape
  down the side of a barrier is not a crash.

Set `full_hit` so that **three full-speed square hits break the car**. With
condition kept as 100, `full_hit` is 34: three of them is 102, and the third
one finishes it. Every softer hit is a fraction of that, so a run can carry
five or six clumsy moments or three bad ones, which is the feel being aimed
at.

### What counts as a hit

Only bodies in the `obstacle` group, which is the same line the speed cost
already draws ([scripts/car.gd:15](scripts/car.gd:15)). That means:

- **Barriers damage.** They are the hazard.
- **Traps damage** (see below), because a trap is a barrier that moves.
- **The rails at the edge of the road do not.** A car scraping down a rail is
  already being pushed back where it belongs and is already losing the time
  that costs. Charging condition as well is punishing the same mistake twice
  while the player is in the middle of recovering from it - which is the exact
  reason the rails do not cost speed today, and the reason holds here.
- **Grass does not.** Being off the road is slow and that is what it is.
- **Landing from a jump does not, by default.** See the acrobatic section: if
  hard landings are ever to cost condition it should be a separate, later
  decision, because the same landing that is fine on track twelve is the whole
  point of an acrobatic track.
- **The other car** - open question, see the end.

`obstacle_recovery` (0.4 s) already stops a car held against a barrier being
charged every frame, and damage sits behind the same gate: one hit, one
charge, however many frames the car spends touching the face. Without that a
single mistake takes a car from full condition to broken in under a second,
which reads as the game breaking rather than the car.

### Breaking

When condition reaches zero the car is out. What that means depends on which
mode is being driven, and the two are genuinely different:

**Solo** (`scripts/solo.gd`): the run is over. Not a reset to the last
checkpoint - the whole point of damage is that it is a thing checkpoints do
not fix. The finish panel is replaced by a broken panel: the time the car got
to, how far it got, and Enter to run again. `_restart()` already puts the car
back on the line and runs the countdown without rebuilding the track
([scripts/solo.gd:252](scripts/solo.gd:252)), so the retry costs nothing and
is the same instant retry the mode already has.

**Two players** (`scripts/main.gd`): the broken car is out and the other one
wins the course, announced the same way a finish is announced through
`_finish_course`. A race where both players break within the pause between
them is a draw, not a crash - handle it.

**A broken car sets no time.** It never finished, so there is nothing to
record and nothing to send to a board.

### Showing it

The player has to be able to see this coming or it is not a mechanic, it is a
surprise. A bar per player in the HUD, beside the clock, in the car's own
paint - so on a split screen each player reads their own condition where they
are already reading their own time. It should be readable without being
counted: full is a full bar, and the last third goes red and pulses, which is
the only warning a player driving at 30 m/s has time to take in.

The stock HUD labels live at [scripts/main.gd:33](scripts/main.gd:33) as
`_counts`, `_clocks`, `_places`, `_tallies`; the condition bar is one more of
those arrays and one more node per half of the split.

The car should show it too, not only the HUD. Three states is enough: clean,
knocked about, and nearly finished. The cheapest honest version is smoke - a
`GPUParticles3D` off the bonnet that starts thin at two thirds gone and
thickens - because it works on a car the player did not model and the game
has never seen. Anything that dents panels only works on the stock car, and
the whole point of `CarShell` is that the game does not know what model it is
dressing ([scripts/car_shell.gd:1](scripts/car_shell.gd:1)).

### Where the setting lives

`GameSettings`, beside `chaos` and `solo`
([scripts/game_settings.gd:56](scripts/game_settings.gd:56)):

```gdscript
## Whether cars can be broken. Off until a player asks for it: the game has
## one punishment for a mistake and it is time, and a player who never chose
## this should never meet it.
var damage := false:
	set(value):
		if value == damage:
			return
		damage = value
		changed.emit()
```

Saved under `[race] damage` in `save_settings`/`load_settings`, read back with
the same `bool(...)` guard the other two use, and shown as a toggle on the
settings screen ([scripts/settings_menu.gd](scripts/settings_menu.gd)) under
the sky row. It needs a line of text under it saying what it does, because
"Damage" alone does not tell anyone that it ends runs.

### Numbers to start from

| Name | Value | What it is |
| --- | --- | --- |
| `max_condition` | 100.0 | Full health, in the units below |
| `full_hit` | 34.0 | What a square hit at top speed costs |
| `damage_recovery` | 0.4 s | Reuses `obstacle_recovery`; no second gate |
| `warning_at` | 0.33 | Fraction left when the bar goes red and smoke starts |

These are a starting point and are meant to be driven and changed. The check
below is what makes changing them safe.

### The check

`tools/checks/damage.gd`:

```
Godot --path . --headless --fixed-fps 60 --script tools/checks/damage.gd
```

It should show, from a car it drives itself:

1. A square hit at top speed costs `full_hit`, within a small tolerance.
2. A square hit at half speed costs about half of it.
3. A glancing hit costs nearly nothing.
4. A car held into a face at full throttle for two seconds is charged once
   per `obstacle_recovery`, not once per frame - and say how many times, the
   way `barrier_recovery.gd` reports its hit count.
5. Three full-speed square hits break the car and a third-of-a-hit does not.
6. Scraping a rail costs nothing.
7. **With the setting off, nothing above happens at all** - the same shape as
   `chaos_colour.gd`, which checks the things that are meant to move and then
   checks that none of it happens in a race that is not chaotic.

### Things that will go wrong

- **Damage must not change how the car drives.** Not its grip, not its top
  speed, not its steering. The moment condition affects handling, a time set
  with damage on is a time set in a different car, and `TrackTimes.GEOMETRY`
  ([scripts/track_times.gd:29](scripts/track_times.gd:29)) has to be bumped -
  which throws away every time every player has ever set. Keep damage to
  ending runs and nothing else, and every existing record still stands.
- A car that breaks mid-jump, in the air, with nothing under it. It is still
  broken; freeze it where it is, do not drop it through the hole.
- Chaos rerolls the car's top speed. `full_hit` is scaled by
  `speed / max_speed`, so it follows the roll on its own - but a chaos car at
  1.7× speed hits things much harder than a tuned one. Check what that feels
  like before deciding whether damage and chaos should be allowed together.
- Being reset to a checkpoint does not repair the car. If it did, damage would
  be a thing you undo by pressing R.

---

## 2. Traps

> **Done, 2026-09-16.** Built to the spec below, with these changes, all
> written up under Traps in the README:
>
> - Traps went onto existing tracks - Switchback, The Hook, Relentless,
>   Grinder, The Wringer and Last Light - and those six lost their times.
>   No `GEOMETRY` bump was needed: a time is kept against a fingerprint of its
>   own track file, so editing a track only ever costs that track.
> - Traps are on chaos courses too, not laid-out tracks only. Chaos turns them
>   on and rolls how many rows are traps; every chaos course that has room
>   for one gets at least one. The endless course without chaos is unchanged.
> - `trap(from, to, width := 0.6, dwell := 1.6, travel := 1.0)`: `from` and
>   `to` are where the middle of the row stands, and `width` is how much road
>   it covers.
> - Checking every *phase* was not enough. A row sliding across the road is
>   usually narrowest halfway, so the checker follows each trap through every
>   place it passes, 5 cm at a time.
> - A trap closing on the kerb with a car in the way lifted the car onto the
>   rail. Cars in a closing lane are now shoved along the road out of the row.
>
> Not done: the medal targets on the six tracks were not re-measured with
> `tools/lap_times.gd`, and their overhead thumbnails were not redrawn.

### What it is

Obstacles that move: barriers that switch which part of the road they block,
on a loop, so a way past that was open when the car came over the rise is shut
by the time it gets there. Not random, not reactive - a timed cycle a player
can learn.

### Why timed and not random

Because the game has to stay fair to drive, and the only way a moving hazard
is fair is if it is the same every lap. A trap that rolls a die as the car
approaches is a trap that sometimes cannot be avoided, and a track where the
gold time depends on which way the dice fell is a track with no gold time.
Timed from the start of the run means a player who has driven it twice knows
the rhythm, and driving the rhythm is the skill the feature is for.

### How a trap works

A trap is a row of barriers with two or more **phases**. Each phase says which
part of the road the row blocks - exactly the `lateral` and `half_span` a
barrier already has ([scripts/track_features.gd:29](scripts/track_features.gd:29)).
It holds a phase for `dwell` seconds, moves to the next over `travel` seconds,
and loops. The clock it moves on is the race clock, started at GO, so both
players on a split screen see the same trap in the same place - which matters,
because a two-player race where each car meets a different trap is not a race.

Written in a track file, next to the corners, the way everything else is:

```gdscript
straight(60.0)
trap(-0.7, 0.7)              # slides left edge to right edge and back
straight(40.0)
trap(-0.6, 0.6, 2.0, 1.2)    # same, holding 2 s and taking 1.2 s to cross
```

### The rule that cannot be broken

**There is always a way past, in every phase, and the way past one trap can be
reached from the way past whatever came before it.**

Those are already the two rules barriers live under
([README.md, Barriers](README.md)), and `TrackFeatures.faults()` already checks
them - but it checks one arrangement, and a trap has several. The validator has
to check every phase of every trap, and every combination of a trap's phase
with the phase of the trap next to it, or a pair of traps that are each
passable alone becomes a dead end at the one moment they are both across the
same side.

That is the single hardest part of this feature, and it is worth being blunt
about it: a trap that closes the road is not a hard trap, it is a broken track,
and nobody can tell the difference from inside the car. It has to be caught
before it ships.

Practically:

- A trap's phases each get the same `clear_lane` (3.4 m) minimum the static
  rows get, narrowed to fit rather than dropped.
- The reachability spacing `√(4·dodge_radius·shift)·dodge_margin` is computed
  against the **worst** pair of phases, not the resting one.
- A trap near another trap or a static row is spaced for the worst case of
  both.
- If the worst case cannot be made to fit, the trap is cut back or the track
  file is told it does not fit. Not silently dropped.

### What to build

- [x] `TrackFeatures.TRAP` - a new kind beside `BOOST_PAD`, `OBSTACLE`, `FORK`
      ([scripts/track_features.gd:19](scripts/track_features.gd:19)).
- [x] Phases on `Placement`: an array of `{lateral, half_span}`, plus `dwell`
      and `travel`. Static barriers are the one-phase case and change nothing.
- [x] `TrackDefinition.trap(from, to, dwell := 1.6, travel := 1.0)`
      ([scripts/track_definition.gd:132](scripts/track_definition.gd:132)), as
      a sibling of `barrier()`.
- [x] `TrackFurniture` builds it as a moving body, not a static one: the same
      striped panels `_build_barrier` already makes
      ([scripts/track_furniture.gd:157](scripts/track_furniture.gd:157)), on
      an `AnimatableBody3D` so `move_and_slide` pushes the car properly instead
      of letting it through. It stays in the `obstacle` group, so it costs the
      speed a barrier costs and the condition damage mode charges - no new
      collision code at all.
- [x] Drive it off the race clock, not `delta` accumulated per node, so a trap
      reset with the race is where the race says it is.
- [x] Extend `TrackFeatures.faults()` to the all-phases rule above.
- [x] `traps_enabled`, a sibling of `obstacles_enabled`, off for the endless
      course. *Changed: chaos turns it on, so rolled chaos courses have traps
      as well as the laid-out tracks - see the note at the top of this
      section.*

### The check

`tools/checks/trap_layout.gd`, modelled on `barrier_layout.gd`:

- Every phase of every trap on the twenty tracks leaves at least `clear_lane`.
- Every phase pair of neighbouring traps is reachable.
- The validator is handed two deliberately broken plans and rejects both - a
  validator that has never rejected anything is not obviously working.
- A car is driven through a trap at the moment it is open, and into it at the
  moment it is shut, and both do what they should.

### Cost

Moving traps make a track a different road to drive, so putting the first trap
into an existing track means **bumping `TrackTimes.GEOMETRY`** and losing every
time set on that track. Better: put traps only on new tracks, or accept the
loss once and do all of it in one go.

---

## 3. Acrobatic tracks

### What it is

Tracks built around being in the air rather than around corners: runs of
jumps, big drops, landings that come at you fast, climbs that launch. A
different kind of track rather than a different mode - they sit in the same
grid as the other twenty, with their own medal times.

### What already exists

Most of it. `jump()` gives a ramp, a hole and a landing run; `climb()` gives
road that gains or loses height, eased so it meets the level road without a
crease ([scripts/track_definition.gd:89](scripts/track_definition.gd:89)). The
car already keeps its speed in the air, steers less there, pitches to the road,
and squashes on landing.

### What is missing

**Every jump in the game is the same jump.** `ramp_length`, `jump_gap` and
`landing_length` are set by `Track` before `describe()` is called and a track
file never names them, deliberately: a player who has cleared one jump knows
what the next one asks
([scripts/track_definition.gd:51](scripts/track_definition.gd:51)).

That is exactly right for the twenty tracks and exactly wrong for an acrobatic
one, where the whole point is jumps of different sizes. So this feature is
really one decision:

> Do acrobatic tracks get to size their own jumps?

The answer should be yes, but narrowly. Add an optional argument rather than
opening the three fields up:

```gdscript
func jump(scale := 1.0) -> void:
	_add(TrackLayout.JUMP, (ramp_length + jump_gap + landing_length) * scale)
```

with `scale` clamped to something like 0.7 to 1.6 and the gap scaled by it.
A track can then ask for a small one or a big one, the shape of every jump is
still the game's, and a player still reads a ramp and knows roughly what it
means. Anything more than that and jumps stop being a language.

`Chaos.jump_gap_scale(speed, gravity)`
([scripts/chaos.gd:203](scripts/chaos.gd:203)) already scales a gap against
what the car can actually clear; the same idea guards a hand-set scale, so a
track cannot ask for a gap no car can cross.

### What to build

- [x] The way in: TRACKS slides NORMAL and ACROBATIC down from under itself.
	  NORMAL opens the grid there is now; ACROBATIC is greyed until there are
	  acrobatic tracks for it to open (2026-09-17).
- [x] **Rings** (2026-09-17). On an acrobatic track the checkpoints are rings a
	  car has to fly through. `ring_jump(lane)` and `ring(lane, height)` in a
	  track file; `tools/checks/rings.gd`. What they do is under Rings in the
	  README.
- [ ] `jump(scale)` above, with the clamp and the clearability guard. A ring
	  over a scaled jump needs its height scaled with it - the height was
	  measured for the standard jump only, so measure again rather than
	  multiplying.
- [ ] A check that every jump on every track can be cleared by the tuned car at
	  the speed the road before it allows - `tools/checks/jump_flight.gd`
	  exists and is the place to extend.
- [x] The acrobatic grid: ACROBATIC opens ten slots of its own, slots 20-29
	  in `TrackRoster` (2026-09-17).
- [x] **Moving rings and platforms** (2026-09-17). `moving_ring_jump()` and
	  `platform_jump()`; `tools/checks/platforms.gd`.
- [x] Ten acrobatic tracks (2026-09-18), challenging, using the old mechanics -
	  pads, barriers, traps - alongside the new ones. The first three were
	  rebuilt after they turned out plain rings on empty road was boring. All
	  ten have targets scaled from the check driver's lap, to be replaced by
	  the best times a player drives:
	  1. **Lift Off** (2026-09-17) - boost, barrier into a ring, a trap into a
		 moving platform, a moving ring, barriers, a boost into a ring.
	  2. **Sky Stairs** (2026-09-17) - a moving platform onto floating road,
		 climbing jump by jump to 9.5 m over its own start, and back down.
	  3. **Island Hopper** (2026-09-17) - floating islands with a moving
		 platform in every gap, in chains of two and three.
	  4. **Tightrope** (2026-09-17) - half-width floating road climbing to
		 11.5 m, with barriers, narrow traps and off-centre rings.
	  5. **Elevator** (2026-09-17) - two lifts to nearly 20 m, a sliding
		 platform and a moving ring back down.
	  6. **High Road, Low Road** (2026-09-17) - two splits: a high road with a
		 platform, and one with a lift, over low roads with barriers and traps.
	  7. **Freefall** (2026-09-17) - up to 26.5 m by grades and a lift, then
		 three falls through moving rings onto trap-swept road.
	  8. **Pinball** (2026-09-18) - barriers and traps the whole way round, four
		 rings, and a pad that skips a platform.
	  9. **Knot** (2026-09-18) - three 270 degree climbing turns, each crossing
		 back over its own road with a ring after it.
	  10. **Last Leap** (2026-09-18) - fast platforms, two moving rings back to
		 back, a lift to twenty metres, and a 28 m drop through a ring.
- [x] **High roads** (2026-09-17). `high_road()` and `high_road_end()`,
	  kickers, `BranchDefinition`; `tools/checks/high_road.gd`.
- [x] **Lifts** (2026-09-17). `lift_jump()`; `tools/checks/lifts.gd`.
- [x] **Floating road and climbing jumps** (2026-09-17). `floating()`, a `rise`
	  on every jump, overpasses; `tools/checks/floating.gd`.

### The ten tracks

What each is for, in the order they are driven. Built ones are marked. Where
one needs something the game does not have yet, it says what.

1. **Lift Off** - *built.* One of everything, low down: a barrier into a ring,
   a trap into a slow moving platform, a moving ring, a boost into the last
   ring.
2. **Sky Stairs** - *built.* Off a moving platform onto floating road, and up:
   ring jumps landing higher each time to 9.5 m, curling back over its own
   start, then a faster platform and a drop to the ground.
3. **Island Hopper** - *built.* A chain of floating islands, each a short slab
   of road with its own ramp, and a moving platform in every gap between them,
   sliding the other way from the last. No ground after the first ring.
4. **Tightrope** - *built.* High, narrow floating road, half the usual width, with traps
   sweeping it and barriers leaving a car-and-a-half gap, and rings off to the
   side. The rail is right there the whole way.
5. **Elevator** - *built.* Platforms that move up and down rather than across.
   Land on one while it is low and it lifts the car to a floating road it could
   never have jumped to; miss the moment and it is at the wrong height.
6. **High Road, Low Road** - *built.* The road splits: a high route of climbing ring
   jumps and platforms that is shorter and faster, and a ground route round the
   outside that is safe and slow, meeting again before the finish.
   Built as a kicker in one lane onto a straight floating road that drops back
   onto the course where the low road comes back underneath it.
7. **Freefall** - *built.* Starts by climbing floating road to the highest point in the
   game, then comes down in a string of big drop jumps, each through a moving
   ring, each landing on a trap-swept floating road lower than the last.
8. **Pinball** - *built.* Dense: floating road packed with barriers and traps
   between quick ring jumps, boost pads placed as bait in front of platforms,
   and the only safe lines through them narrow.
9. **Knot** - *built.* A figure of eight in the sky that crosses over itself three times
   at three heights, with a ring over each crossing so the road below is always
   in view.
10. **Last Leap** - *built.* The finale: fast platforms that barely stop, two moving
	rings back to back, a climb to the top, and one long drop through a ring
	onto the finish straight.
- [ ] Medal times for each, driven rather than guessed: `tools/lap_times.gd`
	  points the crude driver at every track and times it, and the ladder is
	  set from that one ratio ([README.md, Where the numbers come from](README.md)).
	  The crude driver will be worse than usual here - it aims fourteen metres
	  ahead on the centreline and an acrobatic track is mostly not on the
	  centreline - so expect to drive these by hand as well.
- [ ] Decide whether a hard landing costs condition under damage mode. Default
	  no. If yes, acrobatic tracks need their own exemption or they are
	  unplayable with the setting on, and an exemption that only some tracks
	  have is a rule players cannot learn.

### Ground rules

Settled 2026-09-17, while building the rings:

- **Ten acrobatic tracks** for now, on their own grid behind ACROBATIC, not
  mixed into the twenty.
- **Rings are the checkpoints.** An acrobatic track has rings and no painted
  checkpoints; a track never has both. Every ring is needed to finish.
- **A ring banks by going through it** - forwards, the middle of the car inside
  the hole. Not by landing past it, not by driving under it.
- **The game sets the ring's height, the track sets its lane.** A ring over a
  jump stands where a car taking that jump flies. A track makes a ring hard by
  where across the road it puts it, never by hanging it where nobody can reach.
- **The rim is solid but not an obstacle.** Clipping it knocks the car off its
  line and costs no damage and no speed penalty.
- **A reset after a ring puts the car past the hole,** on the landing.
- **Acrobatic tracks use everything.** Pads, barriers and traps stay; moving
  rings and platforms are added. Empty road between jumps is boring.
- **A platform is always visible from the run up** - it carries a gate that
  shows over the lip - because a jump nobody can see cannot be timed.
- **A boosted car clears a platform** and lands on the road past it, so a pad
  before one skips its timing rather than punishing it. A ring still catches a
  boosted car.
- **Medals come from a player's best time** where the test driver cannot finish
  a track; where it can, its lap sets them until a player's time replaces them.

### Where they go on the grid

Not mixed in with the twenty. They are a different thing to drive and the
select screen should say so - a second labelled section, or a row with a
heading. A player looking for a normal track should not find track 22 is six
jumps in a row.

---

## 4. The bot, and the medal gate

### What it is

Two features that only make sense together:

- Every tenth track is not a time trial but a race against a computer-driven
  car that is hard to beat. Winning it opens the next ten.
- You cannot start that race on having merely finished the ten before it. You
  need **five gold medals** among them.

### Why the gate

Finishing ten tracks is not the same as being able to drive them. A player who
scraped a bronze on all ten and walks into a race against a fast bot loses,
repeatedly, with no idea what to change. Five golds out of ten is a
qualification: it says you have driven half of these properly, and the bot is
now a fair thing to be asked to beat. It also gives the medals somewhere to go
- at the moment a gold is a colour on a bar, and nothing in the game ever asks
for one.

Five of ten, not ten of ten, on purpose. A player may simply hate track seven.

### The bot

There is already a driver. `tools/checks/solo_run.gd` drives a whole run from
the line to the flag: flat out where the road ahead is straight, backing off as
it bends, aimed through whatever `TrackFeatures.gaps_at()` says is open rather
than down the middle ([README.md, Solo](README.md)). That is the skeleton. It
lives in `tools/` because nothing shipped needed it; the bot needs it promoted
to `scripts/bot_driver.gd` and made better:

- [ ] Move the driving logic out of the check and into a real script, so the
	  check drives the same code the game does. Two copies of a driver drift.
- [ ] Give it a **difficulty**, as one number: how far ahead it looks, how much
	  it backs off for a bend, how hard it aims at a gap. One number rather
	  than a table, so it can be tuned by feel.
- [ ] Make it use what a player uses - pads, the fork, slipstream - rather than
	  driving a clean line past all of it. A bot that ignores boost pads is a
	  bot you beat by taking them, once, forever.
- [ ] Decide what "hard to beat" is, in numbers: the bot should come in around
	  the track's **gold** time. That is a target already tuned to be a little
	  under the best the road allows, it already exists per track, and it means
	  the gate and the race ask the same thing of the player. A player with five
	  golds can beat it; a player with five bronzes cannot, which is the gate
	  working.
- [ ] The bot must not cheat. No extra speed, no rubber band, no ignoring
	  barriers. It drives the same car with the same tuning, and if it is too
	  easy it gets a better line rather than a bigger engine. A bot that
	  teleports when you get ahead is the fastest way there is to make a player
	  stop trusting a game.

### The race itself

A bot race is `main.tscn`'s shape - two cars, two viewports, a leader, a winner
- with one difference: the second car takes its input from `BotDriver` rather
than from `p2_*`. Rather than a third scene, give `Car` a driver it asks for
input instead of reading the input map directly (the actions are already
indirected through `_accelerate`, `_brake` and friends at
[scripts/car.gd:354](scripts/car.gd:354), so this is a small change), and let
`Main` hand car two a bot instead of a keyboard.

But the bot race is a **one-player** thing, and `main.tscn` splits the screen
for two. Options, in order of preference:

1. `Solo` with a second car and no split - one full-width view, the bot's car
   on the road with you, the rival arrow already built to point at it
   ([scripts/rival_arrow.gd](scripts/rival_arrow.gd)). This is the least new
   code and reads best.
2. `Main` with the split collapsed to one view. More plumbing, more branches on
   a scene that is already about there being two of everything.

Go with 1.

### Unlocking

Nothing in the game is locked today: `TrackRoster` knows tracks that exist and
tracks that do not, and the select screen draws an empty frame for a slot with
nothing in it ([scripts/menu.gd:326](scripts/menu.gd:326)). Locked is a third
state and has to look different from both - a built track you may not drive yet
is not the same as a track that does not exist, and showing them the same way
tells a player the game is unfinished when actually they are.

- [ ] `scripts/progress.gd`, an autoload beside `TrackTimes`: which bot races
	  have been won, and therefore which blocks of ten are open. Saved to
	  `user://progress.cfg`.
- [ ] Medals are not stored and should stay that way. The gate counts them at
	  the moment it is asked, from `TrackTimes.best()` and
	  `TrackRoster.targets()` through `Medal.earned()` - so moving a target
	  moves the gate with it, which is what you want while tracks are being
	  tuned ([scripts/medal.gd:1](scripts/medal.gd:1)).
- [ ] Three states on a cell: **open**, **locked** (built, greyed, with a small
	  lock and a tooltip saying exactly what is needed - "5 GOLD IN 1-10, you
	  have 3"), **not built yet** (the existing empty frame).
- [ ] The bot race as its own cell at the end of each block of ten, marked out
	  as different - it is not a track with a time, it is a door.
- [ ] A player who has the golds but has not won the bot race sees the bot cell
	  open and the next ten locked. A player who wins it sees the next ten open
	  immediately, without a restart.

### The check

`tools/checks/progress.gd`: the gate opens on exactly five golds and not four;
a gold lost to a retuned target closes it again; winning a bot race opens the
next block and nothing else; a fresh profile has block one open and the rest
shut. Plus `tools/checks/bot_race.gd`, which runs the bot over all twenty
tracks headless and reports its time against each gold target - that is the one
number that says whether "hard to beat" is true, and it will need rerunning
every time the car is retuned.

---

## 5. Coins

### What it is

Coins scattered along the road, picked up by driving through them, spent in the
shop. Between **5 and 15** on a course, rolled per course.

### Where they go

A coin is furniture, so it is planned by the thing that plans furniture -
`TrackFeatures` - and built by the thing that builds it - `TrackFurniture`. It
is closest to a boost pad: an `Area3D` that fires once when a car enters it
(`_build_trigger` / `_on_pad_entered`,
[scripts/track_furniture.gd:296](scripts/track_furniture.gd:296)), just
without the speed.

- [ ] `TrackFeatures.COIN`, a fourth kind.
- [ ] A `_place_coins` pass, after pads and obstacles so it knows what is
	  already there. Count rolled in `[5, 15]`.
- [ ] Coins obey the same `keep_out` the pads do - not on the start line, not
	  on the finish, not on a checkpoint
	  ([scripts/track_features.gd:88](scripts/track_features.gd:88)). A free
	  coin for being reset is not a coin anyone earned.
- [ ] Never inside a barrier, never in the hole of a jump, never on a trap's
	  path in any phase.
- [ ] Put them where they are worth something. A coin in the middle of an empty
	  straight is not a decision; a coin in the fast lane of the fork, or on the
	  outside line of a corner, or just past a barrier, is. Weight the placement
	  towards the interesting half of the road rather than rolling a lateral
	  uniformly - that is the difference between a collectable and a pickup.

### Picking one up

- [ ] Fires once per car per course. A coin taken by player one is gone, for
	  both - it is one coin.
- [ ] Both players' coins go to the same purse. The shop is the game's, not a
	  player's, and two people on one keyboard share a machine.
- [ ] Taking one shows something: the coin lifting and fading, a small number,
	  the purse in the corner ticking up. A pickup with no feedback reads as a
	  bug.
- [ ] **A coin taken on a run that is abandoned still counts.** Keeping a run's
	  coins in escrow until the flag punishes exactly the players who are
	  struggling, and the purse is not a score.

### The purse

- [ ] `scripts/purse.gd`, an autoload, saved to `user://purse.cfg`: how many
	  coins, and what has been bought. Kept apart from `GameSettings` for the
	  same reason `TrackTimes` is - a coin is a thing that happened, not a
	  preference.
- [ ] Shown on the title screen, small, near the Shop button.
- [ ] This is a single-player local game with no server behind the economy, so
	  there is nothing to protect against: a player who wants to edit
	  `purse.cfg` has bought the thing already. Do not build anti-cheat for
	  it. (Unlike times, which go to a shared board and are constrained in the
	  database - see [backend/schema.sql](backend/schema.sql).)

### Chaos

Chaos rerolls the course, so it rerolls where the coins are. It should not
reroll how many are worth: a chaos run should not be the efficient way to
farm. Keep the 5-15 roll the same under chaos.

### The check

`tools/checks/coins.gd`: a hundred courses, every one carrying between 5 and
15; none on a keep-out; none unreachable; none inside anything; a car driven
through one banks exactly one coin and a car driven through it twice still
banks one.

---

## 6. The shop

### What it is

A button on the title screen, beside Garage and Settings, opening a screen
where coins buy things.

### What it sells

- **Cars.** The game already has a garage that holds any number of models and
  dresses a car from an id ([scripts/garage.gd:1](scripts/garage.gd:1)), and
  `GameSettings.car_id` already picks per player. A bought car is a model in
  the build that the garage lists once it has been paid for. This needs a few
  models that do not exist yet - that is the real cost of this item, not the
  code.
- **The customisation slot**, at 50 coins - see the next section.
- **Paints**, maybe. Twelve colours exist and are free
  ([scripts/paints.gd:20](scripts/paints.gd:20)). Selling more is easy and
  selling the existing twelve would be taking something away.
- Not: speed, grip, acceleration, or anything else that changes how a car
  drives. Every time on every board was set in the same car, and the leaderboard
  means what it means because of that. A shop that sells a faster car ends the
  leaderboard.

That last point is worth stating in the README when this is built, because it
is the sort of thing that looks like an obvious next feature to whoever picks
this up later.

### What to build

- [ ] `scenes/shop.tscn` and `scripts/shop_menu.gd`, following
	  `garage_menu.gd`: it lays over the title rather than replacing it, the
	  backdrop keeps turning, `closed` is emitted so the caller takes focus
	  back ([scripts/menu.gd:649](scripts/menu.gd:649) is the pattern for all
	  four of these).
- [ ] A Shop button on the title, stacked with the others. Note the stack is
	  positioned from 60% down so that all of them clear the bottom of a
	  720-tall window with Account showing - a fifth button needs that
	  recalculated or the bottom one falls off the screen.
- [ ] Prices in one table in one file, so balancing is one edit.
- [ ] Buying is: enough coins, take them, write it to the purse, show it owned.
	  Owned things never un-own.
- [ ] An empty purse should be able to look at everything and see the prices.
	  A shop that hides its stock until you can afford it gives a player no
	  reason to collect.

---

## 7. Car customisation

### What it is

For 50 coins, a slot that lets a car be decorated as well as painted: stripes,
pre-made stickers, and words the player writes by hand.

### The three kinds

**Stripes.** A small set of shapes - a centre stripe, twin stripes, a side
flash, a bonnet band - each in a colour the player picks from the existing
twelve. Chosen from a list, not drawn. Stripes want to sit on the car's shape
and the game does not know the car's shape, so they are laid on in the car's
own space and clip where they clip.

**Stickers.** A set the game ships: numbers, a flame, a star, an arrow, a
chequer. Each placed on the car, rotated, sized. Placement is the bit that
takes real UI work - see below.

**Hand-written words.** The player draws, with the mouse, in a box, and what
they draw goes on the car. Drawn rather than typed, on purpose: a typed name
in the game's font is the game's writing, and a scrawl is theirs.

### How they are actually drawn on the car

This is the hard part and it needs deciding before any UI is built.

The car's paint is one material by name - `PAINT_MATERIAL`, every surface using
it recoloured ([scripts/car_shell.gd:31](scripts/car_shell.gd:31)) - and that
works on a model the game has never seen. Decoration cannot rely on the model
having sensible UVs, because a player's model might have none worth using.

Two routes:

1. **A decal texture composited at runtime and used as the paint material's
   albedo.** All three kinds - stripe shapes, sticker images, the drawn
   scrawl - are drawn into one `Image` on top of the flat paint colour, made
   into an `ImageTexture`, and handed to the material. Cheap, one texture, one
   material, works with the existing paint path. **Depends entirely on the
   model having usable UVs.** On the stock car this is fine. On a car someone
   exported out of Blender without unwrapping, decoration lands as noise.
2. **Projected decal nodes** (`Decal` in Godot 4), floated over the car in its
   own space. No UVs needed at all, works on any model, projects onto whatever
   is under it - which is the whole problem this feature has. More nodes, more
   fiddling to place, and they project onto the road too if they are not
   clipped to the car's layers.

**Start with 2 for stickers and writing, and 1 for stripes**, because stripes
are the one kind that has to follow the body's shape to look right, and the
stock car - the car nearly everyone will decorate - has UVs. Write down which
route each kind took; the next person will ask.

### Where it is stored

A decoration belongs to a car, not to a player, so it is keyed by garage id.
Note the stock car's id is the empty string and it has no folder
([scripts/garage.gd:25](scripts/garage.gd:25)), so decorations cannot simply
live in the car's folder - they need their own store:

- [ ] `user://decals.cfg`, a section per car id, `stock` for the empty id -
	  the garage already uses that exact word for where the stock car's
	  portrait goes, so reuse it rather than inventing a second name.
- [ ] Hand-drawn strokes stored as points, not as a picture: it scales, it
	  stays small, and it can be redrawn at whatever size the car needs.
- [ ] A car deleted from the garage takes its decoration with it.
- [ ] Two players in the same model both see that model's decoration. That is
	  correct - it is one car - but it means the paint is the only thing
	  telling them apart, so **the split-screen readability rule still holds**:
	  the paint menu already refuses to let both players take one colour
	  ([scripts/paint_menu.gd:17](scripts/paint_menu.gd:17)) and decoration
	  must not undermine that. A sticker that covers most of the body is a
	  sticker that makes a split screen unreadable; cap how much of the car
	  can be covered.

### The drawing screen

- [ ] `scenes/customise.tscn` / `scripts/customise_menu.gd`, opened from the
	  garage on a car that has the slot paid for.
- [ ] A live view of the car being decorated, turning, the way the garage
	  already shows a car ([scripts/car_portrait.gd](scripts/car_portrait.gd)).
	  Applied as it is chosen, not on the way out - the paint screen made that
	  choice for exactly the right reason and this is the same situation.
- [ ] A drawing box for the handwriting: click and drag to draw, a colour from
	  the twelve, undo, clear. Undo is not optional - a player drawing with a
	  mouse will make a mess on the first stroke.
- [ ] Sticker placement: pick one, then drag it around a flat view of the car's
	  side with a size and rotation control. Do not try to make the player
	  place a sticker on a rotating 3D model with a mouse.
- [ ] Both players get to decorate their own car, which means the screen asks
	  whose car first when two are playing.

### In chaos

The requirement, and it is a good one: **the stripes, stickers and writing stay
exactly as they were drawn, and their colour changes constantly.**

That is a different thing from what chaos does to the cars today. Chaos repaints
the bodies once at the line and holds them there, deliberately - the two cars
get hues on opposite sides of the wheel and do not shift while anyone is
driving, because telling your car from the other one is the one thing about a
chaotic race not allowed to be chaotic
([scripts/chaos.gd:153](scripts/chaos.gd:153)).

So the decoration is the part that cycles, and the body is not. What it should
look like is the trees: each kind turns from its own place in the cycle, so the
field shimmers instead of pulsing as one ([README.md, What chaos looks like](README.md)).
Apply the same idea - each decal starts at its own place in the hue cycle and
turns continuously.

- [ ] The cycle runs on the decal material only. The body keeps its rolled
	  colour.
- [ ] Each decal gets its own phase, so a car with three stickers shimmers.
- [ ] Like everything else chaotic, this is **told to the car by whatever built
	  the race**, not read from `GameSettings.chaos` - because the title screen
	  backdrop is a race scene too, and a strobing sticker behind the menu is
	  not what the menu is for. `chaos_colour.gd` already checks exactly this
	  distinction and should be extended to cover decals.
- [ ] The readability rule again: a decal cycling through hues must never land
	  close enough to the other player's body colour to confuse a glance across
	  a split screen. Keep decal value and saturation away from the body's.

### The check

Extend `tools/checks/chaos_colour.gd`: decals cycle in a chaotic race, hold
still in an ordinary one, hold still on the title screen, and each starts from
its own phase. Add `tools/checks/decals.gd`: a decoration saved and loaded is
the same decoration; a deleted car's decoration goes; the stock car's
decoration survives; a decoration never covers more than the cap.

---

## What all of this touches

### `TrackTimes.GEOMETRY` - read this before changing anything

[scripts/track_times.gd:29](scripts/track_times.gd:29) is a single number that
means "the car and the road are as they were". Bumping it throws away **every
local time every player has set**, and changes the signature times are posted
to the leaderboard under, so old and new times stop sharing a board
([backend/schema.sql](backend/schema.sql)).

Of the features here:

- **Damage** did not need a bump: it only ends runs, and `damage.gd` checks
  that a hit drives the same with it on and off. *(done)*
- **Traps** needed none. A time is kept against a fingerprint of its own track
  file, so adding a trap to a track loses that track's times and nobody
  else's. *(done)*
- **Acrobatic tracks** need nothing - a new track has no old times.
- **The bot** needs nothing - it is another car on the road, not a change to
  the road.
- **Coins** need nothing *provided* picking one up does not affect the car. A
  coin that gave speed would be a change to what a lap is worth. Do not make
  coins give speed.
- **Customisation** needs nothing - it is paint.

If more than one bump is unavoidable, do them in one release. Players forgive
losing their times once.

### Saved files, after all of this

```
user://settings.cfg    GameSettings - volume, sky, solo, chaos, damage, paint, cars
user://times.cfg       TrackTimes - a best per track, with its fingerprint
user://progress.cfg    Progress - bot races won, blocks open          (new)
user://purse.cfg       Purse - coins, and what has been bought        (new)
user://decals.cfg      Decoration, a section per car id               (new)
user://cars/<id>/      Garage - a folder per car the player added
```

Four stores rather than one, and on purpose: settings are things a player chose
and can change back, and the rest are things that happened. `Sandbox.path()`
must be used for every new one ([scripts/sandbox.gd](scripts/sandbox.gd)), or a
headless check will write into a real player's purse.

### The settings screen

Gains a Damage toggle. It is getting full - volume, sky, damage, controls,
close - and if anything else is added it wants sections.

### The title screen

Gains a Shop button, making six: Play, Garage, Shop, Settings, Account, and the
mode row. The stack is positioned from 60% down for five
([README.md, Menu](README.md)); recheck it fits a 720-tall window.

### README

Every feature here needs its own section, in the same voice as the rest: what
it does, what the numbers are, why they are those numbers, what was tried and
did not work, and the command that checks it. The README is the design document
for this project and a feature that is not in it is a feature the next person
will re-decide from scratch.

### Build order

1. ~~Damage - self-contained, nothing depends on it.~~ Done.
2. Coins and the purse - the shop cannot exist without them.
3. The shop - needs the purse.
4. Customisation - needs the shop to be bought from, and chaos work.
5. ~~Traps - needs the validator work, which is the riskiest part here.~~ Done.
6. Acrobatic tracks - needs the jump scale, and wants traps to exist first.
7. The bot driver - the biggest single piece of new code.
8. Progress and the medal gate - needs the bot to be the thing it gates.

---

## Questions worth settling first

These change what gets built, so they are worth answering before starting
rather than discovering halfway through.

1. **Does hitting the other car cost condition?** There is a whole contact
   system already ([scripts/car_contact.gd](scripts/car_contact.gd)) - bumps,
   shoves, landing on a roof. If ramming damages, damage mode becomes a
   two-player weapon and that is a real game, but a different one. Suggested
   default: no, at first. **Settled: no.**
2. **Can damage mode and chaos be on together?** Chaos rolls the car's top
   speed up to 1.7×, so hits land much harder. Either allow it and accept that
   chaos-with-damage is brutal, or grey one out while the other is on.
   **Settled: allowed, scaled by each car's own top speed, so a chaos car hits
   no harder at its top speed than a tuned one.**
3. **Does a broken car in solo lose the time it had?** Suggested: yes, it never
   finished. But a player who breaks on the last corner of a gold lap will
   disagree loudly. **Settled: yes, no time.**
4. **Where do acrobatic tracks sit** - tracks 21-24 in the same grid, or their
   own section on the select screen? This changes `TrackRoster` and the grid
   layout.
5. **What does the bot race actually award** besides opening the next ten? A
   medal? Coins? Nothing?
6. **Is there a penalty for losing to the bot,** or is it retry until you win?
   Suggested: retry, always. A gate you can fail permanently is a gate that
   ends someone's game.
7. **How many cars does the shop need at launch** to be worth opening? One is
   not a shop. Three or four is, and each is a model that has to be made.
8. **Do the two players share a purse?** Suggested yes - one machine, one
   keyboard, one purse - but it means one player can spend what the other
   collected.
9. **Do coins appear on laid-out tracks, or only the endless course?** Coins
   on a timed track pull the player off the racing line, which is either an
   interesting trade or a corruption of the time trial depending on taste. If
   they appear on tracks, they must not move the racing line enough to change
   what a lap is worth.
10. **Does decoration apply to the stock car,** which every player starts in
	and shares? It should, but it means two players in the stock car see the
	same decoration, and that has to not break the split screen.
