# To do

Five things to add to the game, written out properly: what each one is, why it
is worth having, the rules it has to obey, and the files it lands in. Damage
mode and traps are built (2026-09-16), the acrobatic tracks with them
(2026-09-18), the bot and the medal gate after those (2026-09-22), and the
coins, the shop and car customisation after those (2026-09-23). **All of it is
built.**

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
user://decals.cfg      Decals - decoration, a section per car id
user://liveries.cfg    Liveries - designs saved on their own
user://cars/<id>/      Garage - a folder per car the player added
```

Four stores rather than one, and on purpose: settings are things a player chose
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

-
