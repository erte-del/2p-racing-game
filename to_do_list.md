# To do

## Track variants

The twenty laid-out tracks can each be driven more than one way: mirrored,
backwards, with more hazards on them, and with their hazards moved somewhere
new on every run. None of these needs a road written by hand. Each is the
track file that already exists, put through a transform after `describe()` and
before anything is built from it. With twenty normal tracks and ten acrobatic
ones, that comes to about a hundred timed configurations, and none of them had
to be laid out.

Written up 2026-09-25. **Nothing below is built yet.** The previous contents
of this file (the shop, customisation, statistics) were all built and are in
the README. Git has the old text.

Everything here follows the same shape as the rest of the game:

- the transform in one place, `scripts/track_variant.gd`, and nowhere else
- rules that hold on every variant of every track, checked by a script in
  `tools/checks/`
- a README section saying what each variant does and why it is the way it is

A variant that is not checked is worse than no variant. Nobody authored it, so
nobody has ever looked at it. The check is the only thing that has.

## Contents

1. [What a variant is](#1-what-a-variant-is)
2. [Mirror](#2-mirror)
3. [Reverse](#3-reverse)
4. [Hard](#4-hard)
5. [Track chaos](#5-track-chaos)
6. [Medals on a variant](#6-medals-on-a-variant)
7. [Choosing one](#7-choosing-one)
8. [The checks](#8-the-checks)
9. [What all of this touches](#9-what-all-of-this-touches)
10. [Questions worth settling first](#10-questions-worth-settling-first)
11. [Build order](#11-build-order)

---

## 1. What a variant is

### A transform over a definition, not a new file

A track file builds a `TrackDefinition`: a chain of `Piece`s and a list of
`Placement`s ([scripts/track_definition.gd](scripts/track_definition.gd)).
Everything downstream of that, meaning `TrackLayout.adopt()`,
`TrackFeatures.adopt()`, the mesh, the rails, the checkpoints and the checks,
neither knows nor cares where the definition came from. A variant makes use of
that. It is a function from one definition to another, applied in
`Track.lay_out()` right after `definition.describe()`
([scripts/track.gd:423](scripts/track.gd:423)):

```gdscript
definition.describe()
TrackVariant.apply(definition, variant)   # new - BASE does nothing
_definition = definition
```

Mirror and Reverse are pure data transforms. They touch pieces and placements
and build nothing. Hard and track chaos need to know where the straights and
respawns are, so they run one step later, against the adopted `TrackLayout`,
and add placements through the planner that generated courses already use.
Both hooks go in `lay_out()`, one on each side of `TrackLayout.adopt()`.

- [ ] `scripts/track_variant.gd`, `class_name TrackVariant`: the constants
	  `BASE`, `MIRROR`, `REVERSE`, `HARD`, `TRACK_CHAOS`; `apply()`; `offered()`;
	  `suffix()`; `display_name()`. The variants are named constants rather
	  than strings, so a misspelt variant is a compile error and not a quiet
	  fifth kind of road.
- [ ] `@export var variant := TrackVariant.BASE` on `Track`, next to
	  `track_file`, and ignored when `track_file` is empty. The endless course
	  is rolled, so it has no variants: a mirrored random road is just another
	  random road.

### Which tracks offer which

A variant can be impossible on a given track. Reverse cannot turn a ring round,
and cannot turn a jump that drops six metres into one that climbs six. So each
track declares what it offers, and the check holds it to that:

- A declared variant must build with no `problems()`, no `faults()` and no
  `branch_problems()`, and the bot must be able to drive it to the flag.
- A variant that would pass but is not declared is reported by the check, so
  that a track does not quietly miss out on one.

**The declaration does not go in the track file.** A time's fingerprint is a
hash of the whole track file ([scripts/track_times.gd:91](scripts/track_times.gd:91)).
Adding a line to all twenty files would throw away every best time on every
track and empty every board, all for a change that did not move a single
corner. So the table lives in `TrackVariant`, keyed by file name, in the same
order as `TrackRoster.FILES`. It holds the offered variants for each track and
also the medal targets (see section 6).

- [ ] `TrackVariant.offered(track_file) -> Array`, read from that table. The
	  menu calls this for every cell, so it has to be a lookup and not a build.
- [ ] Bot roads offer nothing. The gate is one race against one road.
- [ ] Acrobatic tracks offer Mirror and nothing else. See each section for why.

### Identity: keys, fingerprints, signatures

A variant is a different road, so it gets its own time, its own board and its
own medal. Nothing set on it may leak into the base track, and nothing set on
the base track may leak into it.

- [ ] **The key** is the file name plus a suffix: `01_first_light`,
	  `01_first_light-mirror`, `01_first_light-reverse`,
	  `01_first_light-hard`. The suffix uses a hyphen because every track file
	  name uses underscores, so the split is unambiguous. It is also safe in
	  a PostgREST `eq.` filter and in a `ConfigFile` section name.
	  `backend/schema.sql` needs **no change**: `track` is free text, and it
	  is part of the primary key already.
- [ ] **The fingerprint covers the variant's plan as well as the file.**
	  The README says a fingerprint is taken over the file "rather than of the
	  course built from it", and the reason is that the file is what an author
	  edits. A variant's author is `TrackVariant` and the planner, and those
	  can change with no track file changing. If a planner tweak moves every
	  Hard barrier, every Hard time is now a time on a road that no longer
	  exists. So for anything other than `BASE`, the fingerprint and signature
	  are `GEOMETRY`, then the source text, then the suffix, then a
	  serialisation of the finished pieces and placements rounded to the
	  millimetre. The rounding matters because a signature has to agree
	  between a Mac and a Windows machine.
- [ ] **A base track's fingerprint does not move.** `BASE` hashes exactly what
	  it hashes today. That is the one number in this whole feature that must
	  not change, and the check pins it.
- [ ] Computing a Hard plan's fingerprint means building a `TrackLayout` (no
	  meshes, just samples). Measure what that costs across twenty cells
	  before the grid starts calling it. If it is noticeable, cache it for the
	  session by key. The source file cannot change while the game is running.

### Passing it around: an argument, not a string

The variant goes to the race in `GameSettings.track_variant`, next to
`GameSettings.track_file`, and is not written to disk, for the same reason
`track_file` is not.

`TrackTimes.best/record/adopt/forget/fingerprint/signature`,
`Leaderboard.board/submit` and `Stats`' table each gain a `variant` argument
that **defaults to `BASE`**, so every existing caller keeps meaning exactly
what it means today.

I also considered a composite id, `"res://tracks/01_first_light.gd#mirror"`,
passed around as `track_file`. It was rejected because 27 places load, look
up or hash `track_file` as a path (`load()`, `TrackRoster.index_of()`,
`is_bot_road()`, `TrackTimes.source()`, ...). Each of them would have to
learn to strip the suffix, and the one that forgot would load nothing, with
no error anywhere near the cause.

- [ ] `GameSettings.track_variant`, reset to `BASE` wherever `track_file` is
	  cleared (infinite mode).
- [ ] Both race scenes hand it to their `Track`. That is
	  [scripts/solo.gd](scripts/solo.gd) and [scripts/main.gd](scripts/main.gd).
	  Two players on a mirrored road is a mirrored race.
- [ ] `Leaderboard`'s pull-on-sign-in ([scripts/leaderboard.gd:172](scripts/leaderboard.gd:172))
	  maps each server row back to a file by its `track` column. It has to
	  split the suffix off and adopt the time into the right variant. Right now
	  it would find no file called `01_first_light-mirror` and drop the row
	  silently.
- [ ] Coins are seeded off `hash(track_name)`
	  ([scripts/track.gd:457](scripts/track.gd:457)). A variant seeds off
	  `hash(track_name + suffix)`, so its coins are its own and still the same
	  on every run. Track chaos rolls them fresh with its hazards.

---

## 2. Mirror

Left and right swap. The same road, the same length, the same jumps, the same
number of everything, except every corner turns the other way. This is the
cheapest of the four and the one to build first, because it exercises the
keys, the setting, the times, the board and the selector while the transform
itself stays trivial.

- [ ] Every `CORNER` piece: `turn = -turn`. Climbs and rises are untouched.
- [ ] Every placement: `lateral = -lateral`, and every value in `phases`
	  negated. That covers pads, rows, traps, the fork (divider, pad and
	  lane marker), rings, platforms, lifts and kickers.
- [ ] High roads: `BranchDefinition.lane = -lane`, and the branch's own
	  pieces and placements mirrored the same way. A high road's pieces
	  have no corners, so that part is only its placements.
- [ ] Offered on all twenty normal tracks and all ten acrobatic ones. Nothing
	  in a mirrored track can be undriveable if the base track is driveable,
	  because the car is symmetric. The check still builds every one of them:
	  "cannot be" is an argument, and the check produces a number.
- [ ] One thing mirroring can change is where the road runs over the ground.
	  A course that stays on the ground swinging right can run off it swinging
	  left, if the ground is not symmetric about the start. `problems()` would
	  report that, and the check reads it.
- [ ] Thumbnail: the same overhead shot with `flip_h = true`. There is no new
	  picture to draw or check in.

Medals: the same as the base track's. See section 6.

---

## 3. Reverse

The grid goes where the finish was, and the track is driven back to where it
started. The road is the same shape. Every corner, climb and hazard is met in
the opposite order and from the opposite side.

### The transform

- [ ] Pieces in reverse order. A corner keeps its turn sign but flips
	  handedness because the car is travelling the other way, so `turn = -turn`.
	  A climb, or a corner with a rise, has `rise = -rise`. Each piece keeps
	  its own `half_width`, and the width blending already copes with seams in
	  either order.
- [ ] Placements: `offset = L - (offset + length)`, `lateral = -lateral`,
	  and `phases` negated. `L` is the old length.
- [ ] **The fork's pad has to be moved, not just flipped.** `fork()` puts
	  the pad `pad_at` (4 m) inside the lane from the entry, so that the split
	  and the reward arrive together (README, *The fork*). Reversed, it would
	  sit at the far end of the lane, where it is a reward for having already
	  made the choice. So a `BOOST_PAD` inside a `FORK` marker's span is put
	  back at `pad_at` from the new entry. The slalom rows in the lane stay
	  where they are and are held to `faults()` like every other row.
- [ ] Traps keep their `dwell` and `travel`. A reversed trap is reached at a
	  different moment after GO, so its rhythm on the reversed road is a new
	  rhythm. That is fine: the trap checks already test every phase against
	  every phase, not the phase the clock happens to line up.

### Jumps are the hard part

Every one of the twenty normal tracks has at least one jump (First Light has
one; The Wringer, Whiplash, Leap of Faith and Last Light have three each). So
Reverse is only possible at all if jumps can be turned round.

A `JUMP` piece is `ramp (15 m) + hole (17 m) + landing (90 m)`. Read
backwards, that is a long flat run, a hole, and then 15 m of road where the
ramp was, with no ramp facing the car. A reversed jump is therefore built from
different parts:

- [ ] The old landing, less `ramp_length`, becomes level road. Its last 15 m
	  becomes the new ramp.
- [ ] The hole is the same hole.
- [ ] The new landing is the old ramp's 15 m **plus the level straight that
	  came before the jump** (its run-up), merged into one `jump(landing=...)`.
	  `jump()` refuses a landing under 55 m, so the old run-up must be a
	  straight of at least 40 m. Tracks are written with a run-up of 45 m or
	  more, so this should hold, and the check confirms it.
- [ ] `rise = -rise`. A jump that landed high is now a jump that lands low,
	  which `jump()` allows "down as far as a track likes". A jump that
	  dropped more than 3.5 m would need to climb more than 3.5 m reversed,
	  which is more than a level jump can reach. **A track with a jump like
	  that does not offer Reverse.** That is a rule of the jump, not of the
	  variant.
- [ ] A jump landing lower than it took off flies further. The 55 m landing
	  rule was set for a level landing: "a car on a boost comes down 48 m past
	  the hole". The drive check runs a boosted car off every reversed jump
	  that drops, and `jump_flight.gd`'s measurements are extended to cover it.
- [ ] Anything that ends up on a new ramp or in a hole is a fault.
	  `TrackFeatures.adopt()` is already handed `jump_spans()` as `reserved`,
	  so the check reads that. The Wringer and Last Light both put a trap in a
	  ramp's landing, and reversed, that trap sits in the run-up to a ramp.
	  That is allowed as long as it stays off the ramp itself.

### Grid and flag

- [ ] The new grid is on the old finish straight, and the new flag is at the
	  old grid. Tracks start on a straight "long enough to reach it in a
	  straight line" and end on a run to the line, so both ends should be
	  long enough. `problems()` already says "not enough straight for the grid
	  or the flag" if they are not.

### Where it is not offered

- [ ] **Acrobatic tracks: never.** Rings are one-way by definition (a ring
	  "gone through backwards does not count"), platforms and lifts are timed
	  around where the ramp throws the car, and a high road drops off its end
	  onto the course. None of those has a reverse that is the same kind of
	  thing.
- [ ] A normal track whose reverse fails any of the above just does not offer
	  it. Its cell is greyed, and the tooltip says why in one line: *a jump on
	  this road drops too far to be climbed*.

Thumbnail: the same shot. The road is the same shape.

---

## 4. Hard

The same road with more to get past: more rows of barriers, and some of them
moving. Hard is fixed. It is seeded, so a Hard track has the same rows in the
same places on every run, on every machine. That is what makes a Hard time
something worth writing down.

### What is added

- [ ] **More loose rows.** They go on straights that are clear of the
	  existing rows, the respawns (`keep_out`), the jumps (`reserved`), the
	  grid, the flag and the fork. They are laid down by the same planner code
	  that places rows on a generated course
	  (`_row_at()`, [scripts/track_features.gd:627](scripts/track_features.gd:627)): each
	  row is placed, narrowed to leave `clear_lane`, and pushed downstream
	  until it is reachable from the row before it. The rules stay the same.
	  Only the density goes up.
- [ ] **Some static rows become traps.** This reuses the pass that chaos
	  mode (the endless course's, not track chaos) uses, which "turns a row into a trap wherever that still passes every rule"
	  (`_make_sure_of_a_trap()`, [scripts/track_features.gd:684](scripts/track_features.gd:684)). Two
	  traps may still not stand side by side, and rows in a fork's fast lane
	  stay as they are.
- [ ] Target: about half as many rows again as the base track, and at least
	  one trap. Put both numbers in named constants in `TrackVariant` so they
	  can be tuned in one place. Tune them against lap times rather than by
	  eye.
- [ ] Seeded from `hash(track_name + "-hard")`, with its own
	  `RandomNumberGenerator`. It must not draw from anything else's stream,
	  for the reason coins are seeded apart: a shared stream would move every
	  roll after it.
- [ ] Planned in a new `TrackFeatures.harden(layout, seed, tuning)`, called
	  in `Track.lay_out()` after the base placements are adopted. It returns
	  the finished list, and `faults()` runs over all of it.

### What Hard does not do

- It never touches the car. Speed, grip and braking are what every board
  assumes, and the shop refuses to sell them for the same reason.
- It never narrows a way past below `clear_lane` or spaces rows tighter than
  the dodge rule allows. A Hard course is harder to read, not impossible.
  "Hard" that means "sometimes cannot be finished" is just broken.
- It does not add jumps or change the road. The road is the track and the
  hazards are the variant.

### Where it is offered

- [ ] All twenty normal tracks, wherever the planner finds room. A track
	  already dense with rows (Rattlesnake has 22, Last Light 20) may take only
	  a few more. It is still offered as long as the result has more rows or
	  traps than the base. If the planner cannot add anything, it is not
	  offered, because a Hard track identical to the base track is a lie on the
	  selector.
- [ ] **Acrobatic tracks: not offered.** Their checkpoints are rings, most
	  of the course is in the air, and a barrier on a landing is a different
	  and much meaner thing than a barrier on a straight.

Thumbnail: the same shot. The overhead shots are about the shape of the road.

---

## 5. Track chaos

**Track chaos is not chaos mode.** They share the word CHAOS on their buttons
and nothing else, and everything here, in the code and in the README, says
*track chaos* for this one so the two are never confused:

- **Chaos mode** is the one that already exists. It belongs to the endless
  course, and re-rolls the car's speed, gravity, grip and paint, the time of
  day and the shape of the course (README, *Choosing a mode*, *What chaos
  looks like*). It is `GameSettings.chaos` and [scripts/chaos.gd](scripts/chaos.gd),
  and a laid-out track always turns it off.
- **Track chaos** is one of the four ways of driving a laid-out track. The
  road is the track as written and the car is the tuned car; only the hazards
  change, rolled again on **every run**, including an instant retry with
  Enter. In code it is `TrackVariant.TRACK_CHAOS`, and its times are kept
  under `<track>-track_chaos`.

Its button on the track page says CHAOS and turns through the colours the way
chaos mode's button does. That was asked for, and it is the one place the two
look alike.

### It has a leaderboard

*Changed 2026-09-26.* This section used to say track chaos records nothing,
from the README's rule that a trap is "timed, not random". It has a best time
and a board of its own, like the other three ways, because that was asked for.
What that costs is worth writing down: two players' times on it were set
against different barriers, so the board ranks luck as well as driving.

- [x] Its own key, fingerprint and board, `TrackVariant.TRACK_CHAOS`, kept
	  apart from NORMAL's (built with the page, see section 7).
- [ ] No medal until question 2 is answered. A target measured against one
	  roll of the dice is a target for that roll.
- [ ] It counts in `Stats` as a completed race, with distance driven and
	  coins picked up.
- [ ] It does not count toward the medal gate.

### The transform

- [ ] Take the base definition. Remove every loose `OBSTACLE` row and every
	  `TRAP`. Keep the fork's divider, pad and marker, and the rows inside the
	  fork's fast lane. Keep pads.
- [ ] Re-plan rows and traps with the planner, using the `TRAP_CHANCE` range
	  chaos mode already rolls traps at ([scripts/chaos.gd](scripts/chaos.gd)), from a seed
	  rolled at the start of the run. The fork lane's slalom stays as written
	  in the first version. Re-rolling it is a later improvement.
- [ ] Coins roll again with it.
- [ ] Both players on a split screen get the same roll. A race where each
	  car meets different barriers is not a race.

### Every run, including a retry

Solo's retry does not rebuild the track: "it is the same track, and
rebuilding it would cost a second of watching a road appear"
([scripts/solo.gd:545](scripts/solo.gd:545)). Track chaos needs the hazards to
change without the road being rebuilt.

- [ ] `Track.reroll_track_chaos(seed)`: throw away and rebuild the furniture only, not
	  the road mesh, rails or embankment. `_furniture.build()` already takes
	  the features plan on its own. Measure how long it takes on the densest
	  track. If it is under a frame or two, retry stays instant.
- [ ] `solo.gd` and `main.gd` call it from `_restart()` when the variant is
	  track chaos, before the countdown.

### Where it is offered

- [ ] All twenty normal tracks. Acrobatic tracks: no, for the reason Hard is
	  not offered there.

---

## 6. Medals on a variant

In the README a medal target is "a fact about the road", measured by driving
it with `tools/lap_times.gd`. A variant is a different road, so its targets
have to be measured, not assumed. The one exception is argued below.

- [ ] **Mirror uses the base targets.** The car is symmetric, the road is the
	  same length with the same corners in the other direction, and a lap of
	  one is a lap of the other. `lap_times.gd` runs both and reports the
	  difference. If any track's mirror comes out more than about 1% off the
	  base lap, that argument is wrong for that track, and it gets targets of
	  its own.
- [ ] **Reverse and Hard get their own targets**, in the `TrackVariant` table
	  and not in the track file, because the track file's text is the base
	  track's fingerprint (section 1). They are set by the same rule the base
	  targets were: gold a little under the best the road allows, with silver
	  and bronze spaced further apart on harder roads, all from the one
	  measured ratio.
- [ ] Until a variant's row exists, it has **no medals**. It still has a
	  time and a board. That is already how a track with no `medals()` line
	  behaves ([scripts/medal.gd](scripts/medal.gd)), so the variants can ship
	  before every target is measured, and nothing ever shows a gold that was
	  guessed.
- [ ] `tools/lap_times.gd` takes the variant as an argument after `--`
	  (`-- mirror`, `-- reverse`, `-- hard`) and prints a line per track in
	  the form the table wants, so filling it in is a paste.
- [ ] **The medal gate counts base tracks only.** `Progress.golds_in()`
	  reads `TrackTimes.best()` with no variant, which means `BASE`, so this
	  needs no change. It does need a sentence in the README and a case in
	  `tools/checks/progress.gd`, because the day somebody passes a variant
	  through, five mirror golds would open a block. Whether that is actually
	  wrong is question 4.

---

## 7. Choosing one

### The track's own page

*Built for First Light, 2026-09-26.* The design first had a selector row over
the track grid. What was built instead is a page of the track's own, opened by
pressing its cell: the track's name and blurb, a wide overhead shot, and under
it the four ways of driving it, held down one at a time:

```
NORMAL   HARD   CHAOS   MIRROR
```

HARD is written in red. CHAOS is track chaos, and turns through the colours
the way chaos mode's button does. MIRROR is written mirrored. Beside the
picture is the board for the way held down, and beside that the player's time
and place on it, with PLAY under them and BACK across the bottom.

- [x] The page, `TrackDetail` in `scenes/menu.tscn`, opened from First Light
	  only while it is being designed. Checked by `screen_fit.gd`,
	  `track_select.gd` and `track_select_shot.gd`.
- [x] A board per way of driving, and the player's time and place on it.
- [ ] The other nineteen tracks, and the acrobatic ones with only NORMAL and
	  MIRROR.
- [ ] PLAY drives the way held down. It drives NORMAL whatever is held until
	  the variants are built.
- [ ] REVERSE. It is in the plan and not on the page.
- [ ] A way a track does not offer is dimmed, with one line saying why.
- [ ] `GameSettings.track_variant` is set by PLAY, next to `track_file`, and
	  coming back from a race opens the page with the same way held down.
- [ ] Shut blocks stay shut in every way. A variant is a way of driving a
	  track the player has already opened, not a way around the gate.

### The other pages

- [ ] **Leaderboard** opens on the track *and variant* the grid is showing,
	  worked out from focus and the selector, the same way the track is
	  worked out today. It gets the same selector, because a player reading
	  one board is nearly always about to read the next.
- [ ] **Statistics'** table of best times gets a column per timed variant
	  (STANDARD, MIRROR, REVERSE, HARD) if that fits at the largest interface
	  size, with a medal colour on each time. If it does not fit, it gets the
	  selector. `screen_fit.gd` decides here too.
- [ ] Statistics' "tracks with a time" stays a count of the twenty base
	  tracks. A number that can reach a hundred hides whether the twenty have
	  been driven.
- [ ] The finish screen and the corner name the variant beside the track
	  name, `FIRST LIGHT · MIRROR`, so that a time read off a screenshot says
	  which road it was set on.

---

## 8. The checks

These follow the shape everything under `tools/checks/` already has: a
`SceneTree` script with its command line in its header, autoloads fetched
from `/root` by name, `save_path` pointed at scratch, a fault count and a
non-zero exit.

- [ ] **`tools/checks/variants.gd`**, headless. This is the one that matters.
	  For every track and every variant:
	- declared variants build with no `problems()`, `faults()` or
	  `branch_problems()`, and undeclared variants that would pass are
	  reported
	- mirror of mirror equals the base, and reverse of reverse equals the
	  base, piece for piece and placement for placement, to the millimetre.
	  An involution that is not one is the quickest way to catch a sign that
	  was flipped twice or not at all.
	- mirror and reverse are the same length as the base
	- Hard has more rows or traps than the base, the same plan when built
	  twice, and a way past every row at every phase
	- a hundred track chaos seeds are all fault-free and are not all the same
	- every variant key, fingerprint and signature differs from every other
	- **every base fingerprint is exactly what it was before this feature**.
	  The check computes it by the old route, with no variant argument, and
	  compares.
	- nothing lands on a ramp or in a hole
- [ ] It also hands the validator plans that are **wrong on purpose**, in the
	  habit of `barrier_layout.gd` and `trap_layout.gd`: a reversed jump that
	  would need to climb 5 m, a reversed run-up of 30 m, and a Hard row pushed
	  inside the dodge distance. A validator that has never rejected anything
	  has not been shown to work.
- [ ] **`tools/checks/variant_drive.gd`**, headless, `--fixed-fps 60`. The bot
	  drives every declared timed variant from the grid to the flag in `Solo`,
	  and a boosted car goes off every reversed jump that drops. Then there is
	  one two-player run on a mirrored track in `Main`, to prove the variant
	  reaches the second scene. This is what turns "declared" into "driven".
- [ ] `tools/checks/track_times.gd`: a time on Mirror does not touch the base
	  time. Editing the base file drops the variant's times as well. A Hard
	  plan that changes drops the Hard time and leaves the others alone.
- [ ] `tools/checks/track_select.gd`: the selector redraws the cells, a cell
	  that does not offer the variant cannot be pressed, the variant arrives in
	  the race's `Track`, and coming back lands on the same track and variant.
- [ ] `tools/checks/mode_routing.gd`: a variant survives both routes, solo
	  and two-player.
- [ ] `tools/checks/progress.gd`: golds on variants do not open a gate.
- [ ] `tools/checks/stats_race.gd`: a track chaos run adds a completed race.
- [ ] `tools/checks/screen_fit.gd` opens the track page with the selector in
	  place and the Statistics page with its new columns, at every window
	  shape and the largest interface size.
- [ ] `tools/checks/track_select_shot.gd`, not headless: one shot of the grid
	  per variant, so a flipped thumbnail and the "not offered" cell can be
	  looked at.

---

## 9. What all of this touches

| File | What changes |
| --- | --- |
| `scripts/track_variant.gd` | **new**: the constants, `apply()`, the offered/targets table, keys |
| `scripts/track.gd` | `variant` export, the two hooks in `lay_out()`, `reroll_track_chaos()`, coin seed |
| `scripts/track_features.gd` | `harden()`, and the planner's row and trap passes callable on an authored layout |
| `scripts/track_times.gd` | `variant` argument, keyed suffix, fingerprint over the plan |
| `scripts/leaderboard.gd` | `variant` argument, and splitting the suffix on pull |
| `scripts/game_settings.gd` | `track_variant`, unsaved, cleared with `track_file` |
| `scripts/solo.gd`, `scripts/main.gd` | hand the variant to `Track`, reroll track chaos on retry, name it on screen |
| `scripts/menu.gd` | the selector, the fourth cell look, focus seams |
| `scripts/leaderboard_menu.gd`, `scripts/stats_menu.gd` | the variant on each page |
| `tools/lap_times.gd` | the variant as an argument |
| `tools/checks/…` | `variants.gd` and `variant_drive.gd` are new; six others extended (section 8) |

**Nothing new in `user://`.** Variant times are more sections in
`user://times.cfg`, keyed with a suffix. **Nothing changes on the server.**
**No `GEOMETRY` bump**, and that is the point: no player loses a base time to
this.

### README

- [ ] A `## Track variants` section after `## Choosing a track`, with a
	  subsection per variant: what the transform is, why each variant is or is
	  not offered where it is, what Reverse does to a jump, why Hard is seeded
	  and track chaos is not, how track chaos differs from chaos mode, and the
	  command for each check.
- [ ] `## Track times`: the key suffix, and why a variant's fingerprint covers
	  its plan when a base track's covers only its file.
- [ ] `## Medals`: Mirror shares the base targets and the argument for it;
	  the others come from the table.
- [ ] `## The medal gate`: base golds only.
- [ ] `## Choosing a track`: the selector and the fourth cell look.
- [ ] `## Adding a track`: a new track gets its variants from the check, and
	  one line in the `TrackVariant` table. That makes it four steps, not
	  three.
- [ ] `## Layout`: `scripts/track_variant.gd`.

---

## 10. Questions worth settling first

1. ~~**What is the "Chaos" variant called?**~~ Settled: **track chaos**,
   always, in the notes and the code, so it is never mistaken for chaos mode.
   Its button says CHAOS.
2. **Does track chaos get medals?** It has a time and a board (section 5). A
   medal would need a target, and a target measured on one roll of the
   hazards is only a target for that roll. Recommended: no medals.
3. **Can variants stack?** Mirror stacks cleanly with everything, since it
   works on laterals and turns and nothing else looks at those. Mirror +
   Reverse, Mirror + Hard and Reverse + Hard would add about 60 more timed
   configurations. Recommended: ship single variants first and add stacking
   later as a second selector toggle, because each stack is one more column
   of medal targets to measure.
4. **Do variant golds count toward the medal gate?** Recommended: no. The
   gate asks whether "you have driven half of these properly", and a mirror
   gold on a track already golded is the same skill counted twice.
5. **Are variants open as soon as their base track is?** Recommended: yes.
   An alternative is Reverse and Hard opening after any medal on the base,
   which gives the medals another use but adds a fifth state to a cell that
   already has four.
6. **Hard's density.** "Half as many again, at least one trap" is a starting
   guess. Settle it by driving three tracks at 1.3×, 1.5× and 2× before
   measuring targets on all twenty, because the targets have to be measured
   again whenever it moves.

---

## 11. Build order

1. **`TrackVariant` with only `BASE` and `MIRROR`**, the `variant`
   plumbing, keys and fingerprints, and `variants.gd` checking the mirror
   involution and the unchanged base fingerprints. Nothing to look at yet,
   and all of it can be tested.
2. **The selector** on the track page, with `screen_fit.gd` deciding row vs.
   cycling button, and `track_select.gd` / `mode_routing.gd` extended.
   Mirror is playable end to end at this point: time, board and flipped
   thumbnail.
3. **Reverse**, starting with the jump rebuild, then `variant_drive.gd`.
   Expect the check to find a few tracks whose reverse does not work. That is
   the check doing its job, not the feature failing.
4. **Hard**: `harden()`, settling the density (question 6), then the drive
   check.
5. **Track chaos**: `reroll_track_chaos()`, timed against the densest
   track, and its count in `Stats`.
6. **Targets**: `lap_times.gd` per variant, filling the table. Mirror's
   argument is confirmed or dropped here.
7. **The other pages** (Leaderboard, Statistics), then the README.

Each step can ship without the steps after it. A variant with no targets has
no medals and still works, and a variant the table does not offer does not
appear.
