# To do

Five things to add to the game, written out properly: what each one is, why it
is worth having, the rules it has to obey, and the files it lands in. Damage
mode and traps are built (2026-09-16), the acrobatic tracks with them
(2026-09-18), the bot and the medal gate after those (2026-09-22), and the
coins, the shop and car customisation after those (2026-09-23). **All of it is
built.** Statistics, section 10, came after all of that, and was written up and
built on 2026-09-24.

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
6. [The shop](#6-the-shop)
7. [Car customisation](#7-car-customisation)
8. [What all of this touches](#what-all-of-this-touches)
9. [Questions worth settling first](#questions-worth-settling-first)
10. [Statistics](#10-statistics)

## 6. The shop

**Built 2026-09-23.** See [The shop](README.md) in the README for what landed
and why. The screen, the button, the price table and the buying are all there,
and the stock it opened with is paint - the other two kinds below are blocked
on something other than this screen, and are noted as such where they are
described.

### What it is

A button on the title screen, beside Garage and Settings, opening a screen
where coins buy things.

### What it sells

- **Cars.** *Not built.* The game already has a garage that holds any number of
  models and dresses a car from an id
  ([scripts/garage.gd:1](scripts/garage.gd:1)), and `GameSettings.car_id`
  already picks per player. A bought car is a model in the build that the
  garage lists once it has been paid for. This needs a few models that do not
  exist yet - that is the real cost of this item, not the code, and it is why
  this was not the stock the shop opened with. A row in `Shop.stock()` is all
  the screen, the purse and the check need to carry one.
- **The customisation slot**, at 50 coins - see the next section. *Built.*
  First in `Shop.stock()`, because a player reading down a price list should
  meet the thing that changes what the game lets them do before they meet the
  sixth shade of grey. It is the anchor the paint price was set against.
- **Paints.** *Built.* Six at 20 coins - SAND, RUST, OLIVE, SLATE, PLUM, ICE -
  appended after the free twelve in
  ([scripts/paints.gd:20](scripts/paints.gd:20)) with `Paints.FREE` marking
  where the halves meet. The twelve stay free, because selling those would be
  taking something away. The six are deliberately not more of the same wheel
  but the muted shades off it.
- Not: speed, grip, acceleration, or anything else that changes how a car
  drives. Every time on every board was set in the same car, and the leaderboard
  means what it means because of that. A shop that sells a faster car ends the
  leaderboard.

That last point is stated in the README and again at the top of
`scripts/shop.gd`, because it is the sort of thing that looks like an obvious
next feature to whoever picks this up later.

### What to build

- [x] `scenes/shop.tscn` and `scripts/shop_menu.gd`, following
	  `garage_menu.gd`: it lays over the title rather than replacing it, the
	  backdrop keeps turning, `closed` is emitted so the caller takes focus
	  back.
- [x] A Shop button on the title, stacked with the others. The stack moved from
	  60% down to **54%**, which is what a fifth button costs; `screen_fit.gd`
	  now measures the column itself, and Account lands at 732 of the 750 there
	  is, so this can no longer go wrong quietly.
- [x] Prices in one table in one file, so balancing is one edit -
	  `scripts/shop.gd`, and the paints are read off `Paints` rather than
	  written down a second time.
- [x] Buying is: enough coins, take them, write it to the purse, show it owned.
	  Owned things never un-own. `Purse.buy` already did all of this; the
	  screen adds only the words a player reads.
- [x] An empty purse can look at everything and see the prices. BUY stays
	  pressable when it cannot be afforded, because a disabled button cannot
	  take the keyboard and an empty purse would otherwise be a page the
	  cursor cannot land on.
- [x] `tools/checks/shop.gd` and `tools/checks/shop_shot.gd`, because a
	  feature without its check is half a feature.

---

## 7. Car customisation

**Built 2026-09-23.** See [Car customisation](README.md) in the README for what
landed and why. Two decisions came out differently from the design below and
are recorded there: it is **a tab inside the garage** rather than
`scenes/customise.tscn`, because both halves of that screen are about the same
car; and a stripe is worn as an **extra material pass** rather than as a
texture composited into the paint, which keeps a brought-in model's own
paintwork and makes the chaos cycle a property to set rather than a picture to
draw again.

**The tab was rebuilt on 2026-09-24**, and the part of the design below about
placing things on a flat drawing of the side of a car is no longer what the
game does. Everything is put on the model itself now: the car is turned and
zoomed with the mouse, a sticker lands on whichever of its four panels is being
looked at, and a word is written straight onto the paintwork a stroke at a
time. See [The car is the page](README.md), [The four panels](README.md) and
[The pen](README.md). The silhouette survives as the small picture on a livery's
row, which is the job it was always better at. The tab also grew the car's own
paint, in a row under the car - free, and nothing to do with the slot, but the
same question about the same car, and until then the only place to ask it was
the paint screen over a paused race. See [The car's own paint](README.md).

**Liveries came after it, the same day**, and were not in this design at all: a
decoration saved as a design in its own right, kept beside the cars in the
garage, put on any car, and shared the way a car is. See
[Liveries](README.md) and [Sharing a livery](README.md). The one thing worth
knowing before reading either: a livery is a line of text rather than a file,
so it needs no storage bucket - the row on the server *is* the livery - and
`backend/schema.sql` has to be run again on a project set up before it
existed.

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

*That is what was built, with one change to route 1: the stripe is not
composited into the albedo but hung on the paint material as an extra
transparent pass, one per stripe. The shape is in the mask's alpha and the
colour is the pass's own `albedo_color`. So the body keeps whatever albedo it
had - including a texture a model arrived with, which compositing would have
eaten - and the chaos cycle costs a property set rather than an image redrawn.
Written up under [Car customisation](README.md).*

### Where it is stored

A decoration belongs to a car, not to a player, so it is keyed by garage id.
Note the stock car's id is the empty string and it has no folder
([scripts/garage.gd:25](scripts/garage.gd:25)), so decorations cannot simply
live in the car's folder - they need their own store:

- [x] `user://decals.cfg`, a section per car id, `stock` for the empty id -
	  the garage already uses that exact word for where the stock car's
	  portrait goes, so reuse it rather than inventing a second name.
- [x] Hand-drawn strokes stored as points, not as a picture: it scales, it
	  stays small, and it can be redrawn at whatever size the car needs.
- [x] A car deleted from the garage takes its decoration with it.
- [x] Two players in the same model both see that model's decoration. That is
	  correct - it is one car - but it means the paint is the only thing
	  telling them apart, so **the split-screen readability rule still holds**:
	  the paint menu already refuses to let both players take one colour
	  ([scripts/paint_menu.gd:17](scripts/paint_menu.gd:17)) and decoration
	  must not undermine that. A sticker that covers most of the body is a
	  sticker that makes a split screen unreadable; cap how much of the car
	  can be covered.

### The drawing screen

*Built as a tab in the garage rather than a screen of its own - see the note at
the top of this section.*

- [x] ~~`scenes/customise.tscn` / `scripts/customise_menu.gd`, opened from the
	  garage on a car that has the slot paid for.~~ `scripts/decoration_page.gd`,
	  the garage's second tab, with `scripts/car_stage.gd` for the live car.
- [x] A live view of the car being decorated, turning, the way the garage
	  already shows a car ([scripts/car_portrait.gd](scripts/car_portrait.gd)).
	  Applied as it is chosen, not on the way out - the paint screen made that
	  choice for exactly the right reason and this is the same situation.
- [x] A drawing box for the handwriting: click and drag to draw, a colour from
	  the twelve, undo, clear. Undo is not optional - a player drawing with a
	  mouse will make a mess on the first stroke.
- [x] Sticker placement: pick one, then drag it around a flat view of the car's
	  side with a size and rotation control. Do not try to make the player
	  place a sticker on a rotating 3D model with a mouse.
- [x] Both players get to decorate their own car, which means the screen asks
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

- [x] The cycle runs on the decal material only. The body keeps its rolled
	  colour.
- [x] Each decal gets its own phase, so a car with three stickers shimmers.
- [x] Like everything else chaotic, this is **told to the car by whatever built
	  the race**, not read from `GameSettings.chaos` - because the title screen
	  backdrop is a race scene too, and a strobing sticker behind the menu is
	  not what the menu is for. `chaos_colour.gd` already checks exactly this
	  distinction and should be extended to cover decals.
- [x] The readability rule again: a decal cycling through hues must never land
	  close enough to the other player's body colour to confuse a glance across
	  a split screen. Keep decal value and saturation away from the body's.

### The check

Extend `tools/checks/chaos_colour.gd`: decals cycle in a chaotic race, hold
still in an ordinary one, hold still on the title screen, and each starts from
its own phase. Add `tools/checks/decals.gd`: a decoration saved and loaded is
the same decoration; a deleted car's decoration goes; the stock car's
decoration survives; a decoration never covers more than the cap.

---


- **Customisation** needs nothing - it is paint.

If more than one bump is unavoidable, do them in one release. Players forgive
losing their times once.

### Saved files, after all of this

```
user://settings.cfg    GameSettings - volume, sky, solo, chaos, damage, paint, cars
user://times.cfg       TrackTimes - a best per track, with its fingerprint
user://progress.cfg    Progress - bot races won, blocks open
user://purse.cfg       Purse - coins, and what has been bought
user://stats.cfg       Stats - lifetime totals, one section of counters
user://decals.cfg      Decals - decoration, a section per car id
user://liveries.cfg    Liveries - designs saved on their own
user://cars/<id>/      Garage - a folder per car the player added
```

A store per kind of thing rather than one, and on purpose: settings are things a player chose
and can change back, and the rest are things that happened. `Sandbox.path()`
must be used for every new one ([scripts/sandbox.gd](scripts/sandbox.gd)), or a
headless check will write into a real player's purse.


### The title screen

~~Gains a Shop button, making six: Play, Garage, Shop, Settings, Account, and
the mode row.~~ Done. The stack moved from 60% to 54% to pay for it, and
`tools/checks/screen_fit.gd` now measures the column as well as the panels, so
the next button added to it fails a check rather than falling off a screen.

### README

Every feature here needs its own section, in the same voice as the rest: what
it does, what the numbers are, why they are those numbers, what was tried and
did not work, and the command that checks it. The README is the design document
for this project and a feature that is not in it is a feature the next person
will re-decide from scratch.

### Build order

1. ~~Damage - self-contained, nothing depends on it.~~ Done.
2. ~~Coins and the purse - the shop cannot exist without them.~~ Done.
3. ~~The shop - needs the purse.~~ Done.
4. ~~Customisation - needs the shop to be bought from, and chaos work.~~ Done.
5. ~~Traps - needs the validator work, which is the riskiest part here.~~ Done.
6. Acrobatic tracks - needs the jump scale, and wants traps to exist first.
7. The bot driver - the biggest single piece of new code.
8. Progress and the medal gate - needs the bot to be the thing it gates.

---

## 10. Statistics

**Built 2026-09-24.** See [Statistics](README.md) in the README for what
landed and why. Two things differ from the plan below: distance is counted from
`absf(Car.speed())`, since the speed is signed and reversing is driving too;
and the "every few seconds" flush is five seconds of *driving* rather than a
wall-clock timer, which is the same thing for a count that only moves while
driving and needs no node to run it.

### What it is

A page of lifetime totals: how far the cars have been driven, how many races
were finished and how many won, how many cars were wrecked, how many coins
were picked up. Below them, a table of the best time and medal on every track.
All of it is kept on this machine and about this machine - one record, for the
reason there is one purse.

### What a number means

Every one of these is settled before any code is written, because a question
left until then gets answered by whichever branch was easiest to reach.

- **A race is completed when a result is announced**, whichever scene
  announces it. In `solo.gd` that is `_finish()`, `_break_down()`,
  `_won_the_race()`, `_lost_the_race()` and `_bot_broke_down()`; in `main.gd`
  it is `_finish_course()` and `_break_down()`. A run quit from the pause
  screen, or restarted, announced nothing and completes nothing.
- **A broken-down run is completed**, and is a wreck as well. It ended in a
  result, just a bad one. A count that only moves when the player succeeds
  cannot tell "I have played a lot" from "I am good".
- **A win is beating somebody**: the bot in a bot race, or the other car on a
  two-player course - including by being the car that did not break down. A
  solo time trial has nobody to beat and is never a win. What a solo run earns
  instead is a medal, and that is already counted, as a medal. Without this
  written down the number quietly turns into "runs finished".
- **A two-player course is one race and at most one win**, whichever half of
  the keyboard took it. There is one record on this machine, not two - the
  answer the purse already gave for coins ([scripts/purse.gd](scripts/purse.gd)).
- **A wreck is a car worn to nothing**, `Car.is_broken()`, and the row says
  **CARS WRECKED**, not crashes. Three numbers were candidates, and they are
  different features wearing one word: a car destroyed, any contact that took
  condition off, and any trip back to a checkpoint. Only the first is something
  the game already announces, so it is the only one the page can never
  disagree with the race about. Contact needs rules of its own before it can
  be counted - is one long scrape along a barrier one hit or forty? - and is
  left for later under its own key. Resets are cheap and have no such
  question, so they go in now, as `resets`, beside wrecks rather than inside
  them.
- **Only cars a person drove are wrecked.** The bot's car breaking is the
  player's win, not the player's wreck. On a split screen both cars had a
  person in them, so both breaking at once is two wrecks.
- **With damage off, nothing is ever wrecked.** Damage is off by default, so
  most players will look at a zero there for good. The row is greyed, with a
  line saying damage is off, rather than a zero with no reason given.
- **Distance is distance raced**: counted only while `_running` (solo) or
  `_racing` (two-player) is true. A car can be driven during the hold before
  the start and after the flag, and a player idling on a finished course must
  not be able to farm kilometres.
- **The player's distance, not the bot's.** Nobody drove the bot. On a split
  screen it is both cars', since both were driven, and the comment says so,
  so the number is never later read as "how far player one has driven".
- **Distance survives an abandoned run**, for the reason a coin does: it was
  driven. Holding it back until the flag would punish exactly the players who
  spin, give up and start again.
- **The endless course counts.** Its distance counts, and each course crossed
  is a completed race. Medals and wins do not apply. The completed count
  climbing steadily in infinite mode surprises nobody who has read this and
  everybody who has not, so the README says it.
- **Chaos counts.** A chaos race is still driving.
- **Checks never count**, and that is already answered: `Sandbox.path()` sends
  the file into `user://sandbox/`.
- **Coins earned is coins ever earned**, not what is in the purse. The two part
  company the first time anything is bought. What is in the purse is the
  shop's number and already lives in the shop's store; what was ever picked up
  is what a page of totals is for.
- **Nothing goes to the server.** Times go to
  [scripts/leaderboard.gd](scripts/leaderboard.gd) because a time means the
  same thing on every machine. A lifetime total does not, and syncing one
  would need a rule for merging every counter. The file's header says this was
  decided, not forgotten.

### Where it is stored

`user://stats.cfg`, through a new autoload, `Stats`, in `scripts/stats.gd`,
registered after `Progress` and before `Backend`.

Kept apart from `GameSettings` because a total is something that happened, not
something chosen. Kept apart from `TrackTimes` because a total is not a record:
it is never beaten, only added to. The best times are not copied in - they
live in `TrackTimes` already, and a second copy is a second thing to disagree
with the first.

One section, `[totals]`, rather than a section per thing the way `TrackTimes`
and `Progress` do it. Those grow a section per track or per block; this is a
fixed handful of counters that grows by nothing, so a section per key would be
noise. The comment says so, since it departs from both neighbours.

No fingerprint. A lap time stops meaning anything when the track under it is
edited; a distance does not. The kilometres driven on the old track seven were
still driven.

- [x] `const SAVE_PATH := "user://stats.cfg"` and
	  `var save_path := Sandbox.path(SAVE_PATH)` - a var, so a check can point
	  it at scratch, as `Progress` does.
- [x] The counters as named variables, not a free-form dictionary, so a
	  misspelt key is a compile error rather than a quiet second stat:
	  `distance_metres`, `time_driven_seconds`, `races_completed`,
	  `races_contested`, `races_won`, `cars_wrecked`, `resets`, `coins_earned`.
	  `races_contested` is the races that could have been won - bot races and
	  two-player courses - and it exists for the win rate below.
- [x] Not a counter: tracks finished. That is how many tracks have a best
	  time, and `TrackTimes` already knows it.
- [x] One signal, `changed`, as `Progress` has, so an open page can follow a
	  count that moves under it.
- [x] A narrow API, one call per thing that happens: `add_distance(metres,
	  seconds)`, `race_finished(contested, won)`, `wrecked()`, `reset_taken()`,
	  `coins_collected(count)`, and `forget()` for checks and for the day a
	  page offers to start again. Each saves what it changed - except distance.
- [x] Distance and time driven are not written every physics step, which would
	  be sixty writes a second. They are held in memory and flushed when a
	  result is announced, when the pause screen opens, when a run is quit or
	  restarted, from the race scene's `_exit_tree()`, on
	  `NOTIFICATION_WM_CLOSE_REQUEST`, and every few seconds on a timer. A hard
	  kill loses at most those few seconds, which is fine; grinding the disk is
	  not. The comment lists the flush points.
- [x] A defensive load: a missing key is zero, and so is a negative or
	  non-finite one. A damaged file must not be able to put `-nan KM` on the
	  page.

### Where the counts come from

**Solo and bot races**, [scripts/solo.gd](scripts/solo.gd):

- [x] Distance: in `_physics_process`, inside the `_running` branch, after the
	  car has moved - `_car.speed() * delta`. `Car.speed()` is the game's one
	  idea of speed; do not add a second.
- [x] `_finish()` on an ordinary course: one completed race, after
	  `TrackTimes.record()`, so the run is offered to the record before
	  anything else is said about it.
- [x] `_finish()` on the endless course: one completed race, before
	  `_and_on_to_the_next()`.
- [x] `_won_the_race()`: completed, contested, won. `_lost_the_race()`:
	  completed, contested. Not inside `_write_the_win_down()` - that is about
	  `Progress` opening a block, and a drawn bot race is a completed race that
	  is neither a win nor a `Progress` win.
- [x] `_break_down()`: completed, one wreck.
- [x] `_bot_broke_down()` has three outcomes and each needs its line. The bot
	  broke: completed, contested, won. The player broke: completed,
	  contested, one wreck. Both broke: completed, contested, one wreck (the
	  player's), no win. The draw is the one that gets forgotten.
- [x] Resets where the player presses `p1_reset` in `_physics_process`, not
	  inside `_back_to_checkpoint()`: the bot asking to be put back goes down
	  that same path, and the bot pressing the key is not the player.
- [x] `_on_pause_quit()` and `_restart()`: flush distance, count nothing else.
	  The comment says distance surviving an abandoned run is on purpose.
- [x] `_exit_tree()` flushes, so closing the window mid-race does not lose the
	  session's driving.

**Two-player races**, [scripts/main.gd](scripts/main.gd):

- [x] **Nothing in this scene touches `Stats` while `attract_mode` is set.**
	  The title screen's moving backdrop is this scene, instanced by
	  [scenes/menu.tscn](scenes/menu.tscn), and a player who leaves the game
	  on the title must not come back to a thousand kilometres. Today its cars
	  are frozen by `_dress_for_the_title_screen()`, which is what makes this
	  safe now - and exactly why it is the riskiest item in the section: the
	  next change to the backdrop can unfreeze them without anyone thinking of
	  statistics. So every call is gated on `attract_mode` rather than on the
	  cars happening to stand still, and a check drives the backdrop to prove
	  it.
- [x] Distance: in `_physics_process`, while `_racing`, both cars.
- [x] `_finish_course(winner)`: completed, contested, won.
- [x] `_break_down(broken)`: completed, contested, and one wreck per broken
	  car. One car broken is also a win, for the car still going. Both broken
	  is two wrecks and a draw.
- [x] Resets where each player's `_reset` key is read, before
	  `_reset_to_checkpoint()`.
- [x] `_on_pause_quit()` and `_restart()`: flush distance, count nothing else.
- [x] An `_exit_tree()` that flushes. This scene has none yet.

**Coins**, [scripts/track_furniture.gd](scripts/track_furniture.gd):

- [x] `coins_collected(1)` beside `purse.bank()` in `_on_coin_entered()`, the
	  one place a coin is banked for both scenes, fetched from `/root` the way
	  `_the_purse()` fetches the purse. That puts it on abandoned runs for
	  free, as the purse already is. Not hung off `Purse.changed`, which
	  fires when something is bought as well.
- [x] The coin pickup has no `attract_mode` gate of its own - the purse is
	  protected on the title only by the backdrop's cars being frozen. Stats
	  inherits that, and so the title-screen check below watches the coin
	  count as well as the distance.

### Best times, read and never stored

- [x] Per slot, `TrackTimes.best(TrackRoster.file(index))`, read the way
	  `Progress.golds_in()` reads it, with
	  `Medal.earned(best, TrackRoster.targets(index))` beside it, so the table
	  says how the player is doing and not only what the clock said.
- [x] Below zero means no time: a dash, never `-1.00`. A time dropped because
	  its track was edited also comes back below zero, silently, from the same
	  call. That is right, and the page's comment says so, so the next reader
	  does not "fix" it.
- [x] Acrobatic tracks in a group of their own, under their own heading.
	  `TrackRoster.kind_of()` tells them apart, `Progress.golds_in()` already
	  leaves them out, and the track picker already gives them a grid of their
	  own.
- [x] Locked tracks keep their row and their name. A best time on one is
	  impossible anyway, and a table that grows as the player unlocks things
	  keeps changing shape under them.

### The page

- [x] `scenes/stats.tscn` and `scripts/stats_menu.gd`, `class_name StatsMenu`,
	  in the shape of `LeaderboardMenu`: a `closed` signal, `open()` and
	  `close()`, `ui_cancel` in `_input`, hidden at the end of `_ready`.
	  Instanced into `scenes/menu.tscn` as `StatsScreen`, on the shared
	  `menu_theme.tres`.
- [x] **The button goes beside Boards on the track screen, not on the title.**
	  The title already stacks five - Play, Garage, Shop, Settings, Account -
	  and the fifth was paid for by moving the stack from 60% to 54%, with
	  Account landing at 732 of the 750 there is (section 6). A sixth there is
	  a layout change, not a button. Beside Boards is also where the question
	  is already being asked: half this page is a table of times and medals per
	  track. The cost, accepted: the lifetime totals are a level deeper than a
	  player looking for them by name will first try.
- [x] Wired in `scripts/menu.gd` the way Boards is: the reference, `pressed`
	  and `closed`, a branch in the `ui_cancel` handler in `_input()` so
	  Escape backs out of it like every other page, and focus back on the
	  Stats button on close, as `_on_boards_closed()` does. The keyboard is
	  never left on nothing.
- [x] `Stats.changed` connected, so an open page follows a change. It will
	  rarely fire while the page is up; it is one line, and it is what the
	  other pages do.
- [x] The totals in a block at the top and the table scrolling below it, with
	  `LeaderboardMenu._fit_the_list()` as the model - the same problem, a
	  fixed header over a list that has to give way on a short screen.
- [x] One formatting helper per unit. Distance in metres under a kilometre,
	  then kilometres to one decimal - no miles, because the game has no units
	  setting to follow, and the README says so. Times through
	  `RaceClock.format()`. Time driven in hours and minutes. Counts as plain
	  integers.
- [x] The win rate is `races_won / races_contested`, worked out on the page and
	  never stored. Not over `races_completed`, which includes solo runs that
	  can never be won - a player who mostly races the clock would read as
	  someone who mostly loses. No contested races yet shows a dash, not `nan%`.
- [x] A fresh profile is the first thing a new player sees, so it reads as a
	  page and not as a grid of zeros: something like NOTHING DRIVEN YET where
	  the totals will be.
- [x] CARS WRECKED greyed, with its note, while damage is off.
- [x] `tools/checks/screen_fit.gd` opens the page, at every window shape it
	  tries and the largest interface size - see
	  [Screen sizes](README.md) in the README.

### The checks

In the shape everything under `tools/checks/` already has: a `SceneTree`
script with its exact command line in its header, autoloads fetched out of
`/root` by name because they are not identifiers under `--script`,
`save_path` pointed at scratch, scratch deleted on the way out, a fault count
and a non-zero exit.

- [x] `tools/checks/stats.gd`, headless - the store on its own. A fresh
	  profile is all zeros. Each call raises the thing it names and nothing
	  else. Totals survive a save and a load. `forget()` clears everything. A
	  damaged or partial file loads as zeros, without throwing and without a
	  negative. Distance held in memory is on disk after each flush point.
- [x] `tools/checks/stats_race.gd`, headless - the counts from real runs,
	  after `solo_run.gd` and `bot_race.gd`. A finished solo run adds one
	  completed race and some distance, and no win. A broken-down run adds one
	  completed race and one wreck. A won bot race adds one win; a lost one
	  adds none. A drawn bot race adds a completed race, one wreck and no win.
	  A reset adds one reset, and a bot reset adds none. A quit run adds
	  distance and nothing else. **The title-screen backdrop, left running for
	  several seconds, adds nothing at all** - no distance, no coins, no race.
- [x] `tools/checks/stats_shot.gd`, not headless, after `settings_shot.gd`:
	  open the track screen, press Stats, shoot the page empty, seed some
	  totals, shoot it full, back out.

### README and the rest

- [x] A `## Statistics` section after `## Track times`, its nearest
	  neighbour: what is counted, what each number means, what is deliberately
	  not counted - the title screen, the bot, anything but distance on an
	  abandoned run - and where the file lives.
- [x] `## Menu` gains the Stats button beside Boards.
- [x] `## Layout` gains `scripts/stats.gd` and the autoload.
- [x] `user://stats.cfg` goes into *Saved files, after all of this*, above.

### Build order

1. The store and `tools/checks/stats.gd`. There is nothing to look at yet, and
   all of it can be tested.
2. The counts, the title-screen gate first, with `tools/checks/stats_race.gd`.
3. The page, reading its times straight from `TrackTimes`, with `screen_fit.gd`.
4. `tools/checks/stats_shot.gd`, and the README.

Coins are not waiting on anything: the purse was built on 2026-09-23 and the
call goes in with the rest of the counts.
