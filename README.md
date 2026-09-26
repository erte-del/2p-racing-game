# 2P Racing Game

A split-screen two-player racing game, built in Godot 4.7 (GDScript).

## Requirements

- Godot 4.7.2 (standard build, not .NET)
- Blender 5.2 LTS — only needed to re-export the game's own models, and on a
  player's machine only to add a car that is still a `.blend`
- A Supabase project — only needed for accounts and leaderboards, and only
  if you want them. Without one the game runs exactly as it did before any of
  that existed: `backend/README.md` is the setup, and the whole of the server
  side is `backend/schema.sql`.

## Layout

```
assets/models/    imported .glb models
scenes/           main.tscn and per-entity scenes
scripts/          GDScript
tracks/           the laid-out tracks, one file each: twenty, then the
                  acrobatic ten and the bot roads in folders of their own
tools/            Blender export scripts and the checks (not shipped)
backend/          the server side: the schema, the setup, the emails
```

`backend/` holds no code that runs in the game. It is the SQL that builds the
two tables the leaderboards live in, the notes for standing a project up, and
the two pages a confirmation email needs. The game's half of that is three
scripts in `scripts/` like any other.

What the game keeps between runs is a handful of autoloads in `scripts/`, one
file in `user://` each: `GameSettings`, `TrackTimes`, `Progress`, `Stats`,
`Purse`, `Decals` and `Liveries`, and `Garage` with a folder of its own.

Nothing a player brings into the game is in the repo. Cars they add live in
`user://cars/`, a folder per car, beside the settings and the times - see
[Custom cars](#custom-cars). Anything under `tools/` that runs the game keeps
its files in `user://sandbox/` instead, so a check can never touch a real
garage.

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

Under Play sit Garage, Shop, Settings and Account, and Account is there only
when there is a server to talk to. A build with no `backend.cfg` in it does not
grow a button that cannot do anything - the same reason the Leaderboard button
on the track page is not always there either. Statistics is not a sixth button
in this column, which would be a layout change rather than a button; it is in
the settings, beside Controls, and on the track page beside Leaderboard.

The five are stacked from **54%** of the way down, not from 60% as the four
were. A button is 52 pixels and the gap under it is ten, so the shop cost the
column 62 pixels it did not have: at 60% the bottom of Account would land at
777 in a page 750 tall, which is the shortest there is - 1600x900 laid out at
the largest interface size a player can pick. Moving the anchor up six points buys
back 45 of those and leaves Account at 732 of 750. That is the whole of the
calculation, and it is the sort of thing that goes wrong silently, so
`tools/checks/screen_fit.gd` now measures the column as well as the panels and
prints how far down the lowest button landed. It measures Account even in a
build that hides it, because a build with no server is exactly where this would
otherwise go unnoticed until somebody with a server ran it.

Garage opens the same garage the pause menu does, lying over the title. The
title is the best place there is to look at a car: the two on the grid are
dressed from the same setting a race reads, and the camera is already turning
slowly round them, so picking a car changes the one being circled.

Shop sits under Garage, in the order a player does the two things: a car is
picked, and then it is spent on. It is on the title rather than inside the
garage because what it sells is not only cars - see [The shop](#the-shop).

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

Played alone, every key in both columns works: WASD or the arrows to drive, R
or M to go back to the last checkpoint, C or L to change the view - whichever
hand the player would rather use. Solo reads its own `solo_*` actions, which
carry both players' keys, rather than `p1_*`; in the two-player race each car
keeps to its own half of the keyboard, because there a key answering to both
cars would be one player driving the other's. Where solo names a key on screen
it names the first one bound, so it still says R and C.

Both players use the same `scenes/car/car.tscn`. A car reads its actions from an
`input_prefix` export (`p1` / `p2`) and takes its paint from a `body_color`
export, so adding a third player would mean one more instance and one more set
of `p3_*` actions.

## Car model


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

### The shell

Everything about a car that is looked at rather than driven on - the model, its
paint, its wheels, its headlights and the point the driver's eye sits at - lives
in `scripts/car_shell.gd`, on the `Body` node under the car. What is left in
`car.gd` is the speed, the steering and the box the car actually collides with.

The split is there so that a player can one day bring their own model.
`Car.set_model()` swaps what is in the shell and touches nothing else: the
collision box is a *sibling* of the shell rather than a child of it, so a car
wearing somebody else's model has exactly the same corners in exactly the same
places and drives on exactly the same tuning. That is not an argument, it is a
check - `tools/checks/car_shell.gd` swaps a bare box onto a car in the middle of
a race and then measures the box, the tuning and the metres it covers
afterwards.

The shell expects nothing of a model. One with no wheels simply has no wheels
turning. One with no `Paint` material has its biggest panel painted instead, the
colour multiplying whatever texture it arrived with, so a textured model keeps
its texture and wears the player's colour over it. One with no materials at all
is given one, because two cars nobody can tell apart is not a split screen
anybody can read. And its headlights are placed off the shape itself - out to
29% of its width, 47% up its height, on its front face - rather than off the
numbers measured from the JDM model.

The wheels roll at the speed the car is actually covering the road, taken from
how far it moved, rather than the speed it is trying to go - so a car held
against a barrier or the other car with the throttle down has its wheels stood
still instead of spinning flat out. In the air there is nothing to turn them,
so they keep the speed they left the road with and run down at
`air_wheel_fade` (4 m/s every second) until they land.

## Custom cars

A player can bring their own car into the game and drive it. It changes what
the car looks like and nothing else, which is the shell split above doing the
job it was built for - and `tools/checks/garage.gd` is what keeps that true.

Every model comes in through one door, `CarImport`, whether it was picked off
the player's own disk or downloaded from a stranger. There is no second way in
that skips the checks, so there is no second way in for a bad file to find.
It reads the file at run time with `GLTFDocument` - a shipped game has no
import step, because the editor that turns a .glb into a resource is not on
the player's machine - and turns away, in a sentence rather than a crash,
anything that:

- is not a glTF at all, or is bigger than 8 MB;
- keeps its geometry or its textures in files beside it. A car has to be one
  self-contained file, so it is still the same car when it is handed to
  someone else. The glTF's description is read and judged before the model is,
  and the reader is given no base path, so even a file that slipped past could
  not go and find anything beside it;
- has more than 250,000 vertices or 96 surfaces, counted per instance rather
  than per mesh, because a wheel used four times is drawn four times;
- has nothing in it to see.

What is left is stripped down to its meshes. A camera in a model would fight
the split-screen cameras for the view, a light would be a second sun bolted to
the bumper, an animation player would run the thing about, and a physics body
would be worst of all: a box of somebody else's size hung off the car and
colliding with the road, which is the one thing a model must never change. What
is kept is a short list rather than what is thrown out, because the list of
things to throw out is whatever the next exporter thinks of. A node of a kind
that is not kept is swapped for a plain one in the same place rather than
thrown away with everything under it, since exporters hang wheels off whatever
they like, and it keeps its name so a skin still finds its skeleton.

### Fitting

`CarImport.fit` works out the transform that puts a model on the car, and the
first rule of it is one scale for all three axes, never three. A motorbike
squashed out to the width of a car and a rubber duck stretched to its length
are not those things any more, and a player who brought one wanted to drive
that.

The model's length is matched to the 4.87 m collision box, and its width and
height are held under the box's with a 15% allowance - a car with mirrors or a
spoiler is a little bigger than the box it drives in, and one a great deal
bigger would be seen scraping through gaps it is not touching. Whichever of the
three runs out first is the one that decides. A lorry is brought down by its
height. A lamp post comes out as a short lamp post rather than a thin one the
length of a car. A marble is scaled up until it is as tall as the allowance
lets it be, which for anything round is well short of 4.87 m long.

Before any of that, the longer way across the ground is guessed to be the
length and turned to lie down the road. Most things are longer than they are
wide, so the guess is usually right, and the player turns it from there a
quarter at a time. The turn is applied before anything is measured: a quarter
turn puts the length across the road, and the fit on the far side of that turn
is a different fit - the width runs out instead of the length - so it is worked
out there rather than turned afterwards. The turns themselves are written out
exactly rather than worked out from an angle, so four of them is the car that
started. Last, the model is centred across the road and along it and stood on
the ground.

A car brought in has no interior, so it has no first person view. And a camera
already sitting in the stock car's cabin when its player swaps to something
solid steps back out on its own, in `ChaseCamera`, rather than every screen
that changes a car having to remember the camera.

Nothing about a lap changes with the car. The box, the tuning and the road are
the same in every model, so a time set in a lorry is a time set in the stock
car, and the leaderboards take no notice of which one it was.

### The garage

`Garage` is an autoload over a folder per car in `user://cars/`. Each holds
the model exactly as it arrived, `car.glb`, which is never rewritten, a
`car.cfg` saying what it is called and how far it has been turned, and
`thumb.png`, its portrait. A car's id is the first sixteen hex characters of the
sha256 of its model, so the same file added twice is one car, and a car has the
same id on every machine it is ever copied to. None of it needs an account, a
network or a `backend.cfg`; this is the truth the game is played against, the
same way `TrackTimes` is for the times.

Which car each player drives is a setting like their paint, in
`GameSettings.car_ids` and saved as `[cars] model_1` and `model_2`. It is an id
rather than a place in the garage's list: that list changes as cars come and
go, and "the third one" silently becomes a different car the moment anything
ahead of it is removed. Nothing checks the ids against the garage when they are
loaded, and nothing has to. `Garage.dress` drives an id it does not know - a car
since deleted, or a settings file copied from another machine - as the stock
car, so a player never ends up with nothing to drive.

Picking a car takes exactly the path paint does. The screen writes the setting
and never touches a car; the race and the solo run are listening, and dress
their cars from it. They listen to the garage too, because turning or deleting
a car changes what a player is driving without changing which car they picked -
a car turned while the race is paused is turned on the road before the pause
screen is closed. Dressing a car in what it already has costs nothing, and it
takes the id and the turns together to know that, since a turned car has the
same id and a different model. Only the stock car is handed over as stock,
which is what gives it back its cockpit. Chaos leaves all of this alone: it
rolls how a car handles and what colour it is, never what it is.

The garage screen opens from the pause menu, as GARAGE between PAINT and
SETTINGS, and from the title, as GARAGE under PLAY. Unlike PAINT it is not
refused under chaos, for the same reason chaos leaves the model alone.

It has **two tabs**. CARS is everything described below; DECORATION is what is
drawn on the car a player is already in, and is its own section -
[Car customisation](#car-customisation). It is a tab rather than a screen of
its own because both halves are about the same car.

Like the paint screen a tile puts the player in its car the moment it is pressed,
because the car is right there on the road behind the panel and seeing it is
the only way to know it is the one you wanted. The car each player is in is
held down, with the same thick pale border the paint screen puts round a
chosen paint.

Each player has a row - player one above, player two below, and one row when
driving alone - and each row is in three halves. Two of them are cars, split by
where the car came from; the third is that player's saved liveries, and is
described under [Liveries](#liveries). OFFICIAL, on the left, is the cars the
game came with: one column wide, centred under its
heading, and built from a single `_official_listing()`, so a second shipped car
is a second line there and nothing else changes. UNOFFICIAL, on the right, is
every car anybody has added, whether it was picked off this disk or downloaded
from someone else. The line is drawn where it can be trusted: what ships is in
the build and everything else is in `user://`, and nothing a stranger shares
can put a car on the official side. An unofficial half with nothing in it says
nothing has been added yet, rather than sitting empty like a half that failed
to draw.

Two rows of tiles, the tab row, the buttons and BACK all have to fit a 750-tall
page - the laid-out space at the largest interface size a player can pick - and
that is the whole budget the page is laid out to. The heading's two notes are
one line, each half's heading and what it means are one line, and the tiles are
134 tall. The tab row cost about forty of those pixels when it arrived, which
came back out of the space around the tiles: the scrolls went from 148 to 142
and the panel's own gaps from 8 to 6.

The width has a budget too, and the liveries spent it. A car tile was 236
across while a row held two halves, because narrower tiles then left a third of
the window dark on either side, on a screen whose whole job is showing pictures
of cars. A row holds three halves now and that space is the liveries, so the
tiles gave some of it back: **200 across**, with the gaps between the halves
down from 24 to 14. The liveries' own heading is the bare word, because a half
is as wide as its heading and `LIVERIES · designs you saved` was wider than the
column under it.

`tools/checks/screen_fit.gd` measures **both** tabs, because only one of them
is up when the screen opens and the other is the taller of the two to build.

The width was never the problem, and at first it went unspent: tiles 200 wide,
two across, made a panel 750 wide on a screen 1280 across, with a third of it
dark on either side of a page whose whole job is showing pictures of cars. The
unofficial half is three across now, in a 738 by 148 scroll, with tiles 236 wide
and the official half beside it at 216 by 148. Three added cars sit on each
player's row without a scroll bar - six on the screen at once across two
players, where it used to be four and a scroll. The height is deliberately the
same as it was, because the height was already all used.

ADD A CAR, TURN and REMOVE all act on whichever tile the cursor or the keyboard
is on. There is exactly one car being talked about on the screen at a time, so
no button has to ask which car it means. TURN and REMOVE are refused on the
stock car. Removing a car puts anyone sitting in it back in the stock car
before its file goes. One line at the bottom says what happened, or what was
wrong with the file, and the choices are written to disk when the screen
closes rather than on every press.

Portraits are drawn once, the first time a car is seen, and kept beside the
model. `CarPortrait` puts the model in a `World3D` of its own inside a viewport
that lasts as long as the picture does - the course and the sky are in the
game's world, and a portrait taken there would be a picture of wherever the car
was parked. Opening the screen costs nothing for a car that has been drawn
before, and TURN throws its car's picture away and draws it again the right way
round.

Every file the garage writes goes through `Sandbox`, and the folder itself
through `Sandbox.folder`, so a harness under `tools/` has a garage of its own.
The sandbox catches harnesses that are scripts as well as ones that are scenes,
which matters here: every check below is a `--script`.

`tools/checks/garage.gd` builds its test models in code, as boxes of a given
size written out as .glb, and checks the fit on the numbers - a car-sized box,
a lorry, a lamp post, a plank on end, a marble, and a quarter turn swapping the
length limit for the width one. It feeds the door garbage, a text file and a
.gltf with its buffer beside it, and sees that nothing is left behind. Then it
dresses a car in a real race in a model carrying a camera, a light and a
physics body twenty metres across, and measures what the car collides with by
firing rays at it, because what the fit says it did is not the same thing as
what the physics world sees. It will not run outside the sandbox.

```
Godot --path . --headless --fixed-fps 60 --script tools/checks/garage.gd
Godot --path . --script tools/checks/garage_shot.gd -- /tmp/shots
```

### Blender

A car can also be added as a `.blend`, which is the file most people making a
car actually have. Godot only reads a `.blend` in the editor, and even there it
does not read it itself: it hands the file to the Blender on the machine and
imports the glTF that comes back. A shipped game has no editor, so it does what
the editor does. `Blender` finds Blender, hands it the file, and takes the .glb
it makes through `CarImport` like any other.

Finding it starts with a Blender the player went and found, remembered in
`user://blender.cfg`, because the one they pointed at is the one they meant.
After that it looks where Blender usually is: `/Applications` and
`~/Applications` on a Mac, `/usr/bin`, `/usr/local/bin`, snap and flatpak on
Linux, and every version folder under `Blender Foundation` on Windows, newest
first. A player whose Blender is anywhere else gets a FIND BLENDER button,
which is only there when nothing was found. What they pick is judged by its
name before it is remembered - a program called blender something, not a
`.blend` - and it is never run to find out what it is, because running an
arbitrary file to see what it does would be the whole of the problem. Picking
`Blender.app` on a Mac is picking the right thing, and the program inside it is
what is remembered.

Blender is run as

```
Blender -b --factory-startup --disable-autoexec <file> --python-exit-code 1 --python <converter> -- <out>
```

and every switch there is doing something. `--factory-startup` keeps the
player's own add-ons and preferences from changing what comes out.
`--disable-autoexec` matters most: a `.blend` can carry Python that runs the
moment it is opened, and this one may have come from a stranger. Nothing in the
file is ever run, only Blender's own exporter, told what to do by a converter
this game wrote. `--python-exit-code` makes a converter that fails part way say
so rather than exit as though it had finished. The file is only ever handed
over as a full path, since Blender takes anything starting with a dash as one
of its own switches.

The converter is a string in `blender.gd`, written out to
`user://blend_to_glb.py` before each use, rather than a file in `tools/` - which
does not ship, and a converter the shipped game cannot find converts nothing.
It deletes the cameras and lights, exits with 2 if nothing is left that could be
a car, and exports a GLB with modifiers applied and Y up.

What is kept in the garage is the .glb, never the .blend. So a car's id is the
hash of its model rather than of the file it was made from, and a car arrives
under the same id however it got here.

Blender runs as a separate program and the game goes on drawing while it
works. How long it has been going is measured on the clock rather than by
adding up frames: a headless run does thousands of frames a second, and a
three-minute timeout counted in frame time kills Blender before it has opened.
Past three minutes it is stopped, and each way it can go wrong - not found,
would not start, took too long, made nothing - is its own sentence on the
screen. The screen says it is handing the file to Blender before the wait
rather than after it, and refuses every button while it waits: a second file
would mean two Blenders writing over each other's output. The garage refuses a
second conversion too, whoever asks for it.

A player without Blender who picks a `.blend` is told so, and told to export a
`.glb` instead. And the line under the heading says the one thing about a car
they add that they cannot see from its tile: it has no first person view.

`tools/checks/blend_import.gd` has Blender build a box the rough shape of a car,
with a camera and a light beside it, save it as a real `.blend`, and then adds
that to the garage exactly as a player would - checking the fit, the name, that
what was kept is a .glb whose hash is its id, and the car it makes on the road.
On a machine with no Blender it says so and passes, since what it covers does
not exist there.

```
Godot --path . --headless --fixed-fps 60 --script tools/checks/blend_import.gd
```

### Sharing

Where there is a server, a car can be shared and other people's cars brought
down. `CarLibrary` sits over `Backend` the way `Leaderboard` sits over
`TrackTimes`: `Garage` is what is on this machine and stays the truth the game
is played against, and all this does is send a car up and bring one down. With
no `backend.cfg` there is no SHARE button and no BROWSE button at all, rather
than two buttons that can only ever say there is no server.

Sharing is something a player does to one car, on purpose. The server has a
`cars` table and a private `cars` storage bucket, and there is no "shared"
column anywhere: being in the table is being shared, so a car nobody shared has
no row, no model on the server and no presence there at all. SHARE is on the
tile under the cursor like everything else on the page, refused on the stock
car, and still there but refused with "Sign in to share" when signed out - a
button that only appears after signing in is one nobody knew to go and look
for. On a car the player has shared it reads UNSHARE. Browsing needs no
account, so somebody can see what there is before deciding to make one.

The order of the requests is the whole of what makes it safe. Sharing sends the
model first and the row second. Nobody can read a model until a row points at
it, so a share that falls over halfway is a private file in the player's own
folder, not a car on the list with nothing behind it - and a row the server
refuses has its model taken straight back down. Unsharing goes the other way:
the row first, so the car stops being shared on the very first request, and
then the model, without waiting on the answer to decide anything. A model with
no row is unreadable to everyone else. The name a car is shared under is read
from the garage rather than handed in, so there is only ever one name.

A 409 on the row means the car is already shared. Two players who added the
same file hold the same car, and the table is keyed on the car, so a 409 cannot
say which of them put it up - the game says it is already shared and does not
guess. A 409 on the upload is different: something is already at the path, and
it can only be this same model, because the path is the hash in the player's
own folder. It is what an unfinished share leaves. So the server is asked -
not the list in hand, which can be a minute old - whether any row points at the
car. If one does, the model is left exactly where it is, since somebody may be
downloading it; if the row is the player's own, the page learns that and says
UNSHARE from then on. If none does, the old model is erased and the upload goes
again.

A downloaded car is a stranger's file and is treated as one. Its bytes are
hashed before they are so much as parsed, and must come out as the id that was
asked for: a server handing back different bytes is handing back a different
car, however it came to be doing that. Then they go through `Garage.adopt`, and
so through `CarImport` - the same door as a file off the player's own disk,
with the same limits, the same stripping and the same fit. A download is also
cut off at 8 MB rather than read to the end, since whatever is at the other end
decides how much it sends. Rows off the server are checked before anything is
built out of them: an id that is not sixteen hex characters, or an owner that
is not a uuid, is dropped rather than put into a path. A model the server says
is not there is "not on the server. Only whoever shared it can put that right."

The storage policies have one trap that fails silently, and it is in
`backend/README.md` with the rest of what the schema builds: the read policy
has to say `storage.objects.name` in full, because a bare `name` inside its
subquery means the car's display name, every read is denied, and Storage
reports a denied read as "Object not found". Storage also puts the status that
means something in the body of its responses, as a string, and a blunter one on
the response itself - a missing object is a 400 whose body says 404 - so
`Backend._code_in` reads the one in the body, and that is what everything above
it decides on.

Files go through `Backend.upload`, `download` and `erase`, over their own
`_send_bytes` rather than `rest`: raw bytes out and raw bytes back, because a
model sent through something that turns its body into JSON is a model mangled
on the way. Every request, of either kind, is set to keep running while the
game is paused. The garage is opened over a paused race, an `HTTPRequest` polls
in `_process`, and a paused tree stops `_process` - so without that, a car sent
from the pause screen would set off and never arrive.

SHARE asks what the car is called before anything goes anywhere. A car's name
is whatever its file happened to be saved as on somebody's desktop, and it is
about to be the name everyone else sees it under. WHAT IS IT CALLED? opens on
the name it has now, all of it selected, so typing replaces it and Enter keeps
it - the two things a player at that box most likely wants are one key each.
SHARE IT is refused while the box holds nothing but spaces. Confirming renames
the car in the garage if the name changed and then shares it, so the name on
the server and the name on the tile are the same name, read from the one place.
CANCEL changes nothing. UNSHARE asks nothing at all: the player has already
decided, and a question in the way of taking something down is a question in
the way of changing your mind.

BROWSE opens SHARED CARS - "what other people have put up" - over the garage:
the newest sixty, each line the car's name, who shared it and GET, or IN YOUR
GARAGE for one already here. An empty page says which kind of empty it is,
because each asks the player to do something different: there is no server;
the server did not answer, and every car in the garage is still here; or
nobody has shared a car yet. The list is kept for a minute, so opening and
closing the page is not a request each time.

The page can be searched, by a car's name or by who shared it, and the search
opens with the cursor in it. It filters the rows already in hand, without
asking the server anything per keystroke - the list is capped at sixty, so
everything it could find is already here. Beside it a count says how many cars
there are, or "60+" when the page is full, because a full page is the newest
sixty of a number the game does not know and it does not pretend to. While a
search is on it says "3 of 6", so a list getting shorter reads as a search
narrowing rather than cars vanishing off the server, and a search that finds
nothing says "Nothing matches that." - which is not the same sentence as nobody
having shared anything, and must not be. Every line is exactly 760 pixels wide,
with a long name cut off in an ellipsis, so the page does not change shape
under the player's hands as a search narrows onto one.

`tools/checks/sharing.gd` runs with no server, because a check must never touch
a live one. It checks that every call with nothing to talk to comes back as a
sentence, and then checks for real everything that does not need a server:
`adopt` refusing noise and a file over 8 MB, fitting a good one and keeping its
name, the same bytes twice being one car, the id being stable and changing
when one bit of the model does, rows shaped wrong being dropped, and
`_code_in` reading a 400 that says 409 as 409, one that says 404 as 404, a 403
with no JSON as 403, and an empty 500 as 500.

It drives the real screens too, made without `open`, which would set portraits
drawing with nothing headless to draw them. The name box opens on the car's
name, selected; emptying it refuses SHARE IT; a typed name lands in the garage;
cancelling changes nothing. The search narrows six cars to three and counts
"3 of 6", says "Nothing matches that." for nothing, counts a full page as
"60+", and a long name does not widen its line.

```
Godot --path . --headless --fixed-fps 60 --script tools/checks/sharing.gd
```

## Views

Each player can switch between the chase camera and the driver's eye - C for
player one, L for player two. The first person camera is bolted rigidly to the
car rather than smoothed: lagging a first person view behind the steering reads
as the whole world sliding about. The model's own steering wheel turns with the
front wheels, three times as far, about the column its disc sits on.

It is set from the car on every physics step, and with physics interpolation on
(see Smooth motion) it is drawn between steps along with the car, so it is
exactly as steady as the car it is bolted to. Where the body rolls through a
corner the eye goes with the body but keeps only `eye_roll` of its roll, which
is none: the cabin leans round the driver while the horizon holds still, because
a horizon that tips at every corner is the quickest way there is to make
somebody feel sick.

A car brought in from outside has no interior, so it does not get the first
person view at all: the camera would be sitting in the middle of a solid shell
looking at the back of it. `ChaseCamera.set_inside` refuses it, rather than the
key being disabled where it is read - the race and the solo run press the same
button, and neither should have to remember.

## Split screen

The cars live in `main.tscn` so they share one `World3D` and can collide. Each
half of the screen is a `SubViewport` that inherits that same world and adds
only its own `ChaseCamera`, which the level wires to a car in `main.gd`. The
cameras are deliberately *not* children of the cars: two cameras in one viewport
would fight over which is current.

## Screen sizes

The whole interface is laid out once, in a 1600x900 space, and Godot scales
that to whatever window the game is in - `display/window/stretch/mode` is
`canvas_items` and `stretch/aspect` is `expand`. A button therefore covers the
same share of the screen on a laptop as it does on a big desktop monitor, and
the layout can never be measured against a window it was not written for. It
is the one setting that decides this: with the stretch left off, every size in
the game is a raw pixel count, so the menu is nearly full-bleed on a 1366-wide
laptop and a postage stamp on a 4K monitor, and a page opened while the window
was a different size can end up centred on a rectangle that is no longer
there.

The reference is also the only place the size of the interface is decided.
Nothing reads the resolution of the display and picks a font from it: the
stretch already makes every size proportional to the screen, so reading the
resolution as well would either do the same job twice or undo it. What the
reference sets is the *proportion* - how much of the screen the interface
takes - and that is one number for the whole game. It was 1280x720, which made
everything on every screen a fifth bigger than it is now; the numbers written
into the pages did not change when it moved, and neither did the code.

`window/size/window_width_override` keeps the window itself opening at
1280x720. The reference is what the game measures in, not the size it starts
at, and a window that opened at 1600x900 would not fit a 1366-wide laptop.

`expand` rather than `keep` means no black bars: a screen that is not 16:9
gets the extra room as extra space rather than as borders, so a 4:3 monitor
lays out as 1600x1200 and an ultra-wide as 2133x900. The laid-out space is
therefore never *smaller* than the reference but may be larger in one
direction, which is why nothing may be positioned from the bottom or right
edge by a fixed number: the pages are centred and the title stack is placed by
fraction.

### The player's own size

One setting rides on top of the stretch: `GameSettings.ui_scale`, between 0.75
and 1.2, set from the slider on the settings page and applied as the window's
`content_scale_factor`. It divides the laid-out space, so at 1.2 a page has
1333x750 to fit in and at 0.75 it has 2133x1200. Being a scale on the space
itself means no screen has to know about it - no font is recalculated and no
page is rebuilt - and dragging the slider resizes the page the slider is on,
which is the point: a player sees the size they are choosing as they choose
it.

The ceiling is what the guarantee is written against. Every page is checked at
1.2 rather than at 1.0, because that is the tightest the screen ever gets and
any smaller setting only hands a page more room. There is deliberately no
setting that goes back to where 1280x720 had it; that size was the complaint.

`tools/checks/screen_fit.gd` opens every page - modes, tracks, settings,
account, garage, boards - at five window shapes and fails if any of them runs
off the edge of the laid-out space:

```
Godot --path . --headless --script tools/checks/screen_fit.gd
```

That is what caught the boards being 771 high in what was then a 720-high
space, with the
heading and the way out both over the edge. The list of times there is the one
thing on a page that can be any height, so it takes whatever is left once the
rest of the page has had its share and scrolls the remainder
([scripts/leaderboard_menu.gd](scripts/leaderboard_menu.gd), `_fit_the_list`).

Scaling the interface would ordinarily take the race down with it: a
`SubViewport` is sized by whatever holds it, and that is measured in the
laid-out space, so each half of the split would be rendered 1600x448 and blown
up soft on any screen bigger than that. So the halves are not
`SubViewportContainer`s but plain `TextureRect`s running
[scripts/sharp_view.gd](scripts/sharp_view.gd), which gives each viewport the
size its half of the screen really covers in the display's own pixels and sets
`size_2d_override` to the laid-out size. The road is drawn at the full
resolution of the monitor; the speed lines over it still measure the frame the
way the layout does, so they come out the same weight everywhere.

The one thing left at a fixed size is the garage's car portraits, which are
rendered once at 208x136 and kept beside the model (see Custom cars). They are
drawn into a box that size in the laid-out space, so on a screen bigger than
1600 wide they are scaled up with everything else.

### Exported builds

`editor/export/convert_text_resources_to_binary` is off, so the scenes go
into the release exactly as they are in the project. With it on, which is
Godot's default, the conversion to binary rewrote the root of every page that
is a scene of its own - settings, garage, shop, account, boards, statistics,
and the pause screen's pages - from the full-rect anchor preset to the
top-left one, and wrote that onto each place the menu instances them. Each
page came out as a 0x0 box in the corner of the window with its panel centred
on the corner, so a downloaded game opened with the pages hanging off the top
left and the title screen covered. Running from the editor never converts
anything, which is why it only showed in a download. The cost is a slightly
larger pack and slightly slower scene loads, neither of which this game
notices.

The tracks go into a release twice: compiled, like every other script, and as
the text they were written in, under `<track>.gd.source`. An export ships a
script's compiled tokens rather than its text, and a track's time is kept
against a hash of that text (see Track times) - so without the copy a release
had nothing to hash, no signature for any track, and quietly posted no times
and read no boards, while the same game run from the editor worked perfectly.
`addons/track_sources` adds the copies. It is an editor plugin, and it has to
stay switched on in the project settings: an export made without it builds and
runs and looks fine, and has no leaderboards.

Whether the copies went in can only be seen from inside an export, and an
exported game will not run a `--script`. `tools/signature_probe.gd` goes in as
an autoload instead, through an `override.cfg` beside the binary (on macOS,
`Contents/MacOS` inside the app):

```
[autoload]

SignatureProbe="*res://tools/signature_probe.gd"
```

```
"<exported binary>" --headless -- --sandbox
Godot --path . --headless --script tools/checks/track_sources.gd
```

The two lists of signatures have to match line for line. `--sandbox` is not
optional: an export keeps its files in the same `user://` as the editor, the
probe is not on the command line for `Sandbox` to notice, and a build that
cannot read its tracks drops every time in the real record as soon as the
title screen asks about one. Take the `override.cfg` out again afterwards.

## Smooth motion

The cars, the cameras and the arrows all move on the physics step, sixty times a
second, and a frame that does not land exactly on a step - which on a screen
faster than sixty, or on any screen when a frame runs late, is most of them -
would otherwise show things standing still and then jumping. Physics
interpolation (`physics/common/physics_interpolation`) is on, so Godot draws
everything that moved on a physics step between where it was on the last step
and where it is on this one.

That only works for what moves on the physics step, so two kinds of thing are
handled apart.

Anything *put* somewhere rather than moved there calls
`reset_physics_interpolation()` straight afterwards: a car onto the grid, back
to a checkpoint or onto the line for another solo run, a camera snapped behind
its car, and an arrow snapped round a car that has just been put somewhere.
Without that the frame after it draws the thing part of the way across the
world between the two places.

Anything moved on the frame instead has interpolation turned off, because
Godot's own guidance is that a node moved between physics steps while it is
being interpolated between them jitters. That is the whole title screen - the
title rocks, the pages slide and the camera turns round the parked cars - the
pause screen and everything it opens, the medal as it drops onto the finish
panel, and the sun, which swings round with the day. Godot interpolates a
`Control` the same as anything else once this is on, which is why the menus
have to be told. The title camera also reads where the cars are drawn,
`get_global_transform_interpolated()`, rather than where physics last left
them, since it asks between steps.

The physics jitter fix is left at its default: Godot recommends turning it off
for an interpolation solution of your own, and this one is Godot's. None of it
changes what any check measures, since interpolation is only in what is drawn.

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

With no road under it the car keeps only `air_steer` (0.25) of its steering.
Held hard over through the whole of a tuned jump it turns 32 degrees rather than
the 134 it used to, which is enough to straighten up for the landing it is
already heading at and not enough to pick a different one - a car that turned
as well in the air as on the ground would take a jump as just another corner.
What that turning moves is the nose; where the car is flying is settled the
moment it leaves the lip, and the two are put back together on the landing (see
Grip).

The steering is eased rather than set. A key is either down or up, and a car
that snapped to full lock the instant one went down twitched rather than turned
in, so the car keeps one steering value that goes out to full lock over
`steer_rise` (0.12 s) and back to straight over the quicker `steer_fall`
(0.06 s) - quicker, because a car slow to straighten feels as though it is
still turning on its own. Crossing from one lock to the other goes back through
straight at the quicker rate and then out the other side, and a stick held part
of the way over is eased to rather than jumped to. Both times shrink with speed
and are nothing at a standstill, so a hairpin or a three-point turn at a crawl
answers the keys at once, the way it always did. That one value turns the car
and turns the wheels; the wheels used to ease on their own, a second steering
state lagging behind the first.

`tools/checks/steer_trace.gd` steps the easing by hand, the way boost_trace
steps the throttle:

```
Godot --path . --headless --script tools/checks/steer_trace.gd
```

Flat out, full lock takes 0.133 s and straightening 0.067 s - the tuned times,
rounded up to the physics step - lock to lock takes 0.183 s, and a stick held
half over is reached in 0.067 s. At 3 m/s full lock takes a single step,
0.017 s. The bot drivers turn the car directly rather than through the keys, so
none of their laps moved. What the easing costs a dodge between barriers is
under Barriers.

## Grip

A car does not go quite where it is pointing. Steering turns the nose at once,
the way it always did; what the car is *doing* is the direction it was already
going, dragged round after it. The gap between the two is the slip angle, and
`grip` (12 per second) is how fast it closes. That is the whole of the model:
the car's velocity is its heading turned back by however far the travel is
still lagging it.

A car holding a corner settles at its turn rate divided by grip. At top speed
through the 16 m circle that is 1.875 / 12, or **9 degrees of slide**, about
half a second after the key goes down. Set grip high enough and the gap closes
inside a single step, which is the car exactly as it drove before any of this
existed - that is a test the check runs, not a figure of speech.

The step is written out as the exact answer to *the nose turned this far and
grip is pulling the travel after it* over the whole step, rather than as a turn
added and a decay applied one after the other. Done the second way the settled
slide comes out at 8.1 degrees instead of 9.0, and would move again if the
physics rate ever did; the settled slide is meant to be one number.

**The corner is still the same corner.** Once the slide has settled the nose
and the travel turn at the same rate, so the circle a car actually holds is
still `turn_radius_at()` - 16.09 m measured, against the 16.00 m the track
planner lays its corners out to. Nothing about the planner, the fork or the
barrier radii had to move for this. What grip costs is the entry and the exit,
where the car is still gathering the angle up or giving it back, and that is
counted under Barriers.

**In the air there is none.** Grip is the tyres biting and a car in the air has
nothing under its, so whatever angle it left the ground at it keeps until it
lands: it flies where it was thrown. Air steering still turns the nose, and all
that decides is which way the car will be pointing when the grip catches it on
the landing. Off a tuned ramp the nose comes round 31.3 degrees over 74 steps
of flight while the way the car is flying does not move at all, and the slide
it lands with is worked off 0.30 s later. The flight is a straight line either
way, so every number under Jumps is the number it was.

**Only steering slides a car.** The angle is taken from the turn the steering
applied rather than from the yaw the body ended the step at, so everything else
that turns a car - one put on the grid, one put back on the course at a
checkpoint, a bot driver aiming its own body - is picking the car up and
pointing it somewhere else, not sliding it. That is also why no bot lap moved:
like the steering easing, the drivers never see it.

`max_drift` (45 degrees) is where the model stops rather than something to
tune. Past it a car is not sliding, it is spinning, and a single signed speed
along the car's own heading stops describing anything. Ordinary driving never
comes near it; the most a tuned car holds is about 9 degrees.

Chaos does not roll grip. It already rolls the turning circle, and a car rolled
both loose *and* wide would be one no corner on the course could be taken in.

`tools/checks/grip_trace.gd` reads all of it - the settled slide, the corner
that slide is held through, a very high grip against the car as it was, what a
dodge costs, and then a real ramp for the half a car with no floor cannot be
asked:

```
Godot --path . --headless --script tools/checks/grip_trace.gd
```

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
centreline - a car lost out in the scenery projects onto the nearest point of
the course, which can be the finish - and only on the road, with every
checkpoint banked (see Checkpoints and Off the road).

## Checkpoints

Four checkpoints are spread evenly between the start and the finish, painted as
yellow bands. They are there to be reset to, and to be driven over. A player
who falls off, gets stuck or ends up facing the wrong way presses their reset
key and is put back on the centreline at the checkpoint they banked last,
stopped and facing down the course. Before the first one is banked that is the
grid itself.

A checkpoint banks when a car on the road passes it, within `checkpoint_window`
(30 m) past the line. Every one of them has to be banked to finish, in any
order: a player put back somewhere odd, or who went the wrong way round, still
only has to have driven over each of them. What does not count is coming back
onto the road further on - a checkpoint left behind stays unbanked - and nothing
counts from off the road at all. The tally at the top of each half counts them,
0/4 up to 4/4.

`tools/checks/checkpoint_rules.gd` drives a car over the lines of a real race:

```
Godot --path . --headless --fixed-fps 60 --script tools/checks/checkpoint_rules.gd
```

Over the finish on the road with nothing banked, the race goes on. Put back on
the road 35 m past the first checkpoint and driven on, the tally stays at 0/4.
Driven over the four checkpoints last to first, the tally goes from 1/4 to 4/4
and a reset follows each one in turn; over the finish after that, the race
ends.

## Rings

An acrobatic track has no painted checkpoints. It has rings: gold hoops
standing up over the road, square to it, that a car banks by flying through.
Everything else about a checkpoint holds - every ring is needed to finish, in
any order, the tally counts them, and a reset goes to the one banked last.

`ring_jump(lane)` puts a jump down with a ring over the middle of its hole.
The track picks which lane the ring is in and nothing else: the height is the
game's, the same way the jump is. It was measured rather than chosen - driven
flat out at the standard jump, a car's body passes the middle of the hole
between 6.2 m up at 18 m/s and 7.4 m up at 39 m/s, and `jump_ring_height`
(6.8 m) is the middle of that. With a 3.5 m hole (`ring_radius`) a car taking
the ramp at any speed the game can roll flies through, as long as it is lined
up. So what a ring asks is the one thing the jump did not already ask: be in
the right place before the lip, because nothing steers in the air.

`ring(lane, height)` stands one over the road where it has got to, for
anywhere else a car leaves the ground, where the track has to say how high the
car will be. `TrackFeatures.faults()` refuses one whose rim is in the road or
whose middle is off it.

A ring banks when the middle of the car - not its origin, which is down at the
wheels - crosses the plane of the ring going forwards, inside the hole.
Backwards does not count, from outside the hole does not count, and neither
does being put on the far side of one: a step longer than `ring_longest_step`
(5 m) is a car being moved, not a car flying. It does not have to be on the
road, by the nature of the thing.

The rim is solid, and not an obstacle. Clipping it costs what the physics
costs - on a jump that is usually the hole - and no speed penalty or damage on
top of that, because missing the ring is already the price. A reset after a
ring over a jump puts the car on the landing, `ring_landing_room` (8 m) past
the hole: it made the jump, and sending it back up the ramp would charge it for
one it already cleared.

Alone, a banked ring goes dark, so the ones still owed are the ones still lit.
Two players share one set of rings, so in a race they stay lit: one going dark
would tell each player about the other's run.

### Acrobatic tracks

Acrobatic tracks are the ones built from rings. They live in
`tracks/acrobatic/`, are listed in `TrackRoster.ACROBATIC_FILES`, and have
their own grid of ten slots behind ACROBATIC on the track page. Every track has
one slot number across both lists - the twenty normal tracks are 0 to 19 and
the acrobatic ones start at 20 - so the leaderboard and the saved times need
nothing new. Their files start with an `a` because a time is kept and sent
under its file's name, and `a01_lift_off` can never be mistaken for
`01_first_light`. NEXT after a gold moves on within the grid a track was
picked from, never across.

### Moving rings and platforms

`moving_ring_jump(from, to, dwell, travel)` is a ring over a jump that slides
from one lane to the other and back on the race clock, holding each end for
`dwell` seconds and taking `travel` to cross, the way a trap does. The ring to
line up with is where it will be when the car gets there.

`platform_jump(from, to, width, dwell, travel)` is a jump with a much longer
hole - 57 m instead of 17 - and a slab of road floating in it, sliding across
the road the same way. A car has to come down on the platform, ride it to the
far end and drop off onto the landing. Where it stands is the game's, measured
off real flights: its top is 4 m up and it runs from 18 to 48 m past the lip,
which catches a car off the ramp at anything from about 23 to 37 m/s. A car on
a boost is still 5 m up at 50 m: it clears the platform altogether and comes
down past the far end, on the road beyond. That cuts both ways - a pad in the
run up to a platform is a way to skip its timing, for a car that arrives flat
out and straight, and a platform is not something a boosted car can be made to
land on. A platform is in the road group, so a car on it is on the road.

A platform sits lower than the lip of its ramp, so from the run up it is hidden
behind the ramp, and a platform that cannot be seen cannot be timed. Each one
carries a lit violet gate at its near end - a post up each side and a bar
across the top, 6 m tall, exactly as wide as the platform - that shows over the
lip and moves with it. The gate is paint and has no collision.

Both move on the same clock as the traps, set by the race every step, so two
players see them in the same place and a restart puts them back where they were
at GO.

`tools/checks/platforms.gd` drives at them with the clock set both ways. The
still platform is landed on and crossed at 24, 30 and 36 m/s, and on a boost the
car clears it and comes down on the road past it; the moving one is landed on and crossed when the clock puts it under the
car and fallen through when it does not; the moving ring banks when timed and
does not when not; and a platform that slides past the kerbs is caught:

```
Godot --path . --headless --fixed-fps 60 --script tools/checks/platforms.gd
```

`tools/checks/platform_shot.gd` looks at the first platform on a track from the
run up, in the air and on it.

### Floating road, and jumps that climb

`floating()` in a track file makes the road from there on stand in the air on
nothing, until `floating(false)`. Raised road is otherwise drawn on an
embankment down to the ground; floating road is drawn as a slab
`floating_depth` (1.2 m) deep with sides and an underside, so from the ground it
reads as a thing up there rather than a ribbon that vanishes when looked at from
below. The rail is all that keeps a car on it, and a car that goes over it falls
to the grass.

Every jump takes a `rise`: `jump(rise)`, `ring_jump(lane, rise)`,
`moving_ring_jump(..., rise)` and `platform_jump(..., rise)` land that many
metres above - or below - the road they were taken from, so a track climbs into
the air a jump at a time. Up is limited, down is not. A jump may climb 3.5 m and
a platform jump 3 m, and `TrackLayout.problems()` refuses more: the lip is 5 m
up, and a car taking it at 23 m/s still has its wheels 5 m up 17 m on, but a
landing much higher than that is a wall the slowest cars fly into. A ring over a
climbing jump stands where it always does, since the car flies the same way
whatever the landing does.

Every jump also takes a `landing`: how much road there is past the hole before
whatever comes next, when a track wants less than the usual 90 m. A jump needs
at least 55 m, since a car on a boost comes down 48 m past the hole; a platform
jump needs 35, since off the end of a platform a car comes down within 17 m of
the drop. That is short enough that one platform jump lands straight into the
ramp of the next - an island - and `floating.gd` drives two back to back with
35 m between them at 24, 30 and 36 m/s.

Distances along a course are the layout's - a cross-section every
`sample_step` metres, measured across the ground - and everything on a course
is placed in them. The curve the game finds a car on measures its own length
through the air instead, so every ramp and drop made it a little longer than
the layout: about a metre and a half per jump on the normal tracks, and more
than ten metres by the end of a course that climbs and falls. `Track.offset_of`
and `Track.centre_at` now turn the curve's distances into the layout's, so a
car, a reset and a finish line all agree about where on the course they are.

A course may now pass over itself. Two parts of the road closer than
`clearance` across the ground are still refused, unless one is at least
`overpass_clearance` (9 m) above the other.

`tools/checks/floating.gd` takes every climbing jump on a test course - 3.5 m up
onto floating road, a platform 3 m higher, a ring 3.5 m higher again - at 23,
30, 37 and 46 m/s (the platform not on a boost), and each has to put the car on
the road above; then a 10 m drop and the 28 m one Last Leap ends with have to leave it on the
road and driving; two platform jumps back to back with 35 m of island between
them have to be crossed at 24, 30 and 36 m/s; and a jump 5 m up, or a platform
jump with 20 m to land on, has to be refused:

```
Godot --path . --headless --fixed-fps 60 --script tools/checks/floating.gd
```

### Lifts

`lift_jump(lane, lift, width, dwell, travel, landing)` is a jump with a lift in
its hole: a platform 50 m long, `lane` across the road, that rises `lift` metres
and comes back down on the race clock - holding the bottom for `dwell`, rising
over `travel`, holding the top, and down. The landing on the far side is 0.6 m
below the top of the lift, and 3 m past its end. The lift's bottom is where a
platform's top always is, 4 m up, so a car off the ramp comes down on it only
while it is low; the landing is only reached off the lift while it is high. A
lift may rise 7 m, for a landing up to 11 m above the ramp's road - which no jump
could reach, and `TrackLayout.problems()` refuses more.

It is long so a car that comes down on it early can brake to a stop and wait,
and the step off the top is short so a car pulling away from a standstill still
makes it. A car on a rising lift carries the climb, the way it carries a ramp's,
so driving off one still rising throws it up a little.

`tools/checks/lifts.gd` sends a car at a lift that rises 6 m from every quarter
second of its seven-second cycle, two ways. Flat out the whole way over, it gets
across from 7 of the 28; landing, braking to a stop, waiting for the top and
pulling away with the keys, from 12. It has to get across from some and not all
of them both ways, since a lift nobody can cross is a wall and one everybody
crosses is a floor:

```
Godot --path . --headless --fixed-fps 60 --script tools/checks/lifts.gd
```

`acrobatic_drive.gd` waits for lifts: it stops 50 m before the ramp until
setting off will bring it down on the lift while the lift is low - working out
how long that takes from how far it is, flat out from a standstill - and once on
it, stops and waits for the top, and once it has pulled away from the top it
keeps going even if the lift starts back down under it. A car waiting is not a
car stuck. A lift wants a level run up to wait on, and a hold at the top long
enough to pull away in: Freefall's first lift had its run up ending on a grade
and held the top 1.4 s, and a car waiting on the slope reached the lift late and
one pulling off the top was still on it when it went back down.

### High roads

`high_road(lane, rise)` splits the road. It puts a kicker - a ramp in one lane
rather than across the road, rising 5 m over 15 m on the curve the course's
ramps use - on 15 m of straight, and hands back a `BranchDefinition`: a second
road, floating, that starts `kicker_gap` (26 m) straight ahead of the kicker's
lip, `lane` across and `rise` up. The track file builds the high road the way it
builds the course - straights, climbs, jumps, platforms, lifts, pads, traps - and
then builds the course on as the low road, the long way round, until it comes
back to the line it left along, heading the same way, and calls
`high_road_end()`. The high road is stretched with straight road to reach that
point and ends there in the air; a car on it drops off the end onto the course.

The high road runs straight, with no corners, because a straight line is the
one shape that can be checked to meet the course where the course comes back.
It has no rings, because a checkpoint on one road of a split can never be banked
from the other; the rings go on the road both routes share. So the race - its
checkpoints, its finish, where a reset goes - knows nothing about high roads: a
car on one is a car in the air over its own course, and a car that falls off one
is put back at the last ring before it. Each high road is a `Track` of its own,
a child of the course's, with no start, finish, checkpoints or rail ends, and
the course passes the race clock on to it.

A kicker's foot is sunk 8 cm into the road rather than resting on it: the car
is one long flat box, and at 2 cm proud it caught its front edge on the kicker
and stopped dead.

`Track.branch_problems()`, which `track_check.gd` prints, refuses a high road
the course does not come back under - more than 1.5 m to the side or 3 degrees
off - one longer than the way round, one that ends less than 9 m above the
course, one that drops onto anything but 60 m of straight, one with a ring on
it, and one that passes closer to the course than two roads side by side, kerb
to kerb, anywhere but where it leaves and lands.

`tools/checks/high_road.gd` drives a test course straight off the kicker at
25.5, 30 and 36 m/s - each goes over the high road, 12 to 13 m up, and back down
onto the course - and down the middle lane past the kicker, which leaves the car
on the course. Given a track, it drives that track's high roads instead, from
every quarter second of the cycle of whatever moves on them, and each has to be
crossed from one of those at least:

```
Godot --path . --headless --fixed-fps 60 --script tools/checks/high_road.gd
Godot --path . --headless --fixed-fps 60 --script tools/checks/high_road.gd -- res://tracks/acrobatic/a06_high_road_low_road.gd
```

`tools/checks/high_road_shot.gd` looks at the first high road on a track from the
run up, the lip, on it, and at the drop.

### The acrobatic tracks

The first is **Lift Off**: a boost off the line, a barrier that pushes the car
to the side its ring is on, a trap sweeping the run up to a platform that slides
slowly from side to side, a moving ring, two barriers to thread, and a boost pad
dead ahead of the last ring - a ring catches a boosted car, where a platform
does not. The hard parts each come just after a ring, so a fall costs a corner
rather than a lap.

The second is **Sky Stairs**: a barrier and a ring on the ground, a trap into a
moving platform, and off the platform the road floats, 3 m up. A ring jump
climbs to 6.5 m, a moving ring to 9.5 m, with corners, a pad and a trap between;
four right handers curl the climb back over the ground it started from; a
second, faster platform starts the way down, and a last ring drops the car to
the ground for the run home.

The third is **Island Hopper**: a ring on the grass, then no more ground. A chain
of two floating islands with a moving platform in each gap, each platform
sliding the other way from the last; an island with a corner and a trap; a ring
climbing to 5.5 m; a chain of three faster, narrower hops; a last island with a
pad, and a moving ring that drops the car to the grass. Each island is 40 or 50 m
- enough to land, settle and go, or to brake and wait for a platform on the
wrong side.

The fourth is **Tightrope**: it climbs off the grass onto floating road and the
road narrows to half its width - 8 m of asphalt, a rail either side, nothing
past it - until the last jump. Two barriers leave one lane each; a ring a little
right climbs to 7 m; a trap sweeps the rope; a platform as wide as the road
climbs to 9 m; a second trap, and a moving ring to 11.5 m; a slalom of three
barriers along the top; and an 11.5 m drop through the last ring to the grass.
The traps are narrow rows, 1.8 m across, because anything wider closes the
rope as it passes the middle.

The fifth is **Elevator**: a barrier and a ring on the ground, then a lift in the
middle of the road rising 6 m, holding each end two seconds, to floating road
9 m up; a trap and a ring to 11 m; a second lift off to the right, narrower,
rising 5 m and waiting less, to nearly 20 m; a pad and a sliding platform that
takes the first step down; and a moving ring that drops the car the whole way
to the grass.

The sixth is **High Road, Low Road**: two splits. The first kicks off the right
onto a high road with a platform sliding wide across it, a pad and a climbing
jump, 9 m up at its end, while the low road goes out to the left along a
straight with two barriers and a trap. The two meet over a moving ring both
share. The second kicks off the left onto a high road with a lift, rising 5 m,
while the low road goes out to the right past a trap. Straight off each kicker
at tuned speed, `high_road.gd` crosses the first high road from 3 of 17 moments
in its platform's cycle and the second from 7 of 21; a player who steers for the
platform does better.

The seventh is **Freefall**: a ring on the grass, then up - a floating grade to
6 m, a barrier, a grade to 12, a lift off to the right to 21.5 with a level run
up to wait on, and a last grade to 26.5 m, the highest road in the game. Then
three falls, each a jump landing 8 or 10.5 m lower, each through a moving ring,
the first two onto floating road with a trap sweeping it straight after the
landing, and the last all the way to the grass.

The eighth is **Pinball**: barriers and traps the whole way round, with only the
run up to each ramp clear. Rows that sit close together are on the same side,
since rows that swap sides need most of a straight between them for a car to
cross. Four rings, a platform, and two pads late on: the one before the platform
is worth 43.8 m/s at the lip against 30 without, which clears the platform and
its timing altogether, and the one before the last ring is free speed, since a
ring catches a boosted car.

The ninth is **Knot**: three turns of 270 degrees that each come back over the
road they left on. `corner()` takes a rise now, so a corner can climb across its
arc the way a climb does, and these climb twelve metres, twelve more, and then
fall fourteen - the road stacking at 8 m, 20 and 32 before it comes down. Each
crossing has a ring on the road just after it, so what a player is lined up for
has their own road underneath it. `track_check.gd` prints where a course passes
over itself: three crossings here, 12.4, 12.4 and 13.1 m apart in height. The
last turn needed a long straight out of the knot first - tied where it was, it
came down through the first turn with 8.7 m between them, and two roads need 9.

The tenth and last is **Last Leap**: two platforms that hold each side four
tenths of a second and cross in nine, with a trap on the island between them;
two moving rings back to back, sliding opposite ways, with only a landing
between them; a lift to twenty metres; a trap and a ring above that; a grade to
twenty-eight, the top of the track; a pad on the last of the road; and then a
moving ring hanging in the air with the whole twenty-eight metres under it. The
drop is the longest in the game, and `floating.gd` holds it to the rule every
drop is held to: on the road and still driving at the bottom.

Their targets are for now scaled from `tools/checks/acrobatic_drive.gd`, which
laps Lift Off with the keys in 50.67 s, Sky Stairs in 1:04.42, Island Hopper in
1:02.23, Tightrope in 52.33, Elevator in 1:14.10, High Road, Low Road in 1:15.13
- always the long way round, since it never takes a kicker - Freefall in 1:10.95,
Pinball in 1:06.83, Knot in 1:19.80 and Last Leap in 1:16.92. On Elevator it waits,
stopped, at both ends of both lifts, so a player who takes one flat out at the
right moment beats its targets by a long way. The medals on an acrobatic track are set from
the best time a player drives on it where they can be; where the check cannot
finish a track at all, the targets are set from a player's time and nothing
else.

`tools/checks/acrobatic_drive.gd` is the check that every acrobatic track can
be driven. It presses the input actions a keyboard does, through all of the
car's grip, threads the gaps the barriers leave, and lines up with the next ring
or platform where it will be when the car arrives. A row of barriers in the way
comes before a ring or platform beyond it, and it lines up with a row's gap
35 m out, with a trap where it will be when the car gets there. It counts the
times a car falls, strands itself on the grass or gets no further in three
seconds, and is put back, and fails a track where one ring takes more than four
tries or the lap never finishes:

```
Godot --path . --headless --fixed-fps 60 --script tools/checks/acrobatic_drive.gd
```

What it cannot say is how hard a track is. It steers with analogue precision
and no reaction time: while building the first tracks nothing made it fall, not
even an 18 m run up after a 100 degree corner to a ring more than halfway to
the kerb. A track it clears is a track that can be cleared; how hard it feels is
found by driving it.

`lap_times.gd` and `track_thumbnails.gd` both take track files after `--`, to
time or draw one track rather than all of them.

`tools/checks/rings.gd` flies a car at the rings on a test course
(`tools/checks/ring_course.gd`): lined up at the slowest chaos roll, tuned, on a
boost and at the fastest roll, all of which bank; well to one side, into the
rim, and under a ring standing over level road, none of which do; and lined up
with a ring off the middle of the road, which does. It checks the rule itself
without a car, that a reset after a ring lands on road, that a ring with its
rim in the asphalt is caught, and that the two-player race banks for one car
and leaves the ring lit:

```
Godot --path . --headless --fixed-fps 60 --script tools/checks/rings.gd
```

`tools/checks/ring_shot.gd` takes the view from the run up, the lip, through
the ring and past it, for any ring on any track, timing a moving one to be in
the middle of the road when the car gets there:

```
Godot --path . --fixed-fps 60 --script tools/checks/ring_shot.gd -- /tmp/shots [track file] [ring]
```

## Off the road

The ground is one flat box, the embankment under a raised road carries no
collision, and the road itself is only solid from above. A car that falls into
the hole in a jump comes down on grass, and it used to be at full speed there
with nothing in the race asking how it had got anywhere: a checkpoint banked
for any car within `finish_corridor` of the centreline, and so did the finish,
which did not ask for the checkpoints at all. On 14 of the 20 laid-out tracks a
car dropped into the first jump hole could drive straight across the grass to
the flag and finish - on Long Haul, 250 m of grass in place of 1358 m of road.

Now a car only counts on the road. Whatever it last stood on decides it: the
road and its rails are in `Car.ROAD_GROUP`, and anything else, which is mostly
the grass, is off the road. A car in mid air over a crest has not left the road
it took off from, and one sitting on the other car's roof has not left it
either. Off the road a checkpoint does not bank and the finish does not count,
and the car keeps only `off_road_speed` (0.6) of its top speed. That is mild on
purpose: the grass is a mistake that costs time rather than a trap, and it is
the checkpoints and the finish, not the grass being slow, that stop it being a
way round the course. A car that falls in still has the reset key.

A car on the grass can go under road that stands higher than the car does -
30% of the road on the laid-out tracks and 54% on rolled courses - but not
through road any lower, where the rails and the edge of the road stop it.

`tools/checks/off_road.gd` puts cars on the grass and drives them:

```
Godot --path . --headless --fixed-fps 60 --script tools/checks/off_road.gd
```

Driven along the grass beside a real race, 15 m from the centreline, a car no
longer banks the first checkpoint and no longer ends the race at the finish.
Driven straight across the road from the grass, it is stopped by road level with
the grass and by road at bumper height, and goes straight under road 5 m up.
Held flat out on the grass from 30 m/s, it is down to 18.0 m/s within three
seconds. And on none of the laid-out tracks does a car dropped into the first
jump hole finish across the grass any more: where it reaches the flag at all,
the race does not count it.

## Saying so

A car that has come off the road can still be driven, and that is the problem.
The grass is only slower, nothing out there stops it, and the course is right
where it can be seen - so a player heads back towards it, and the lap they are
driving is already over, because off the road no checkpoint banks and the
finish does not count. The way out is the reset key, which they were shown
once, on the controls sheet, before the race.

So it is said again at the moment it is worth knowing. `scripts/lost_prompt.gd`
puts a line across the top of that player's own half of the screen:

```
OFF THE ROAD      PRESS  R  TO GET BACK ON
```

It names the key that is bound now, not the one that was bound when this was
written. `scripts/controls.gd` reads it out of the input map, and the controls
sheet on the settings screen reads the same function, so a key that moves moves
in both places at once or in neither. Player one is told about R and player two
about M, each in their own half, because the two resets are different keys on
the one keyboard. An action with nothing bound to it says `OFF THE ROAD` and
stops there.

It waits `patience` (1.2 s) first. Clipping the verge through a corner is not
being lost, and a line that flashed up every time a wheel touched grass is one
players would learn not to read. It fades in over a quarter of a second, and
goes as soon as the car is back on the road or has been put back at a
checkpoint - the count goes with it, so nobody is told twice for one mistake.

Two things count as off the road. Standing on anything that is not in
`Car.ROAD_GROUP` answers itself. Falling does not: a car the physics has not
reported touching anything keeps whatever it last stood on, which is the right
answer over a jump and the wrong one over the edge of a floating road, so a car
that had run out of road would believe it was still on it the whole way down
and only be told once it landed. What tells the two apart is where the course
is. Across a jump the road runs straight from the lip to the landing and a car
in flight follows a curve that falls away from it, which puts it above that line
the whole way over; come up short and it is under it, by as much as it is going
to miss by. So being `drop` (5 m) under the course with nothing at all beneath
the wheels is a car on its way down. The wheels are part of the rule because a
car riding a lift down is under the course as well - measured at 3.7 m under on
the lift course - and it is standing on the thing carrying it.

`tools/checks/lost_prompt.gd` drives cars off real roads and reads the label
back:

```
Godot --path . --headless --fixed-fps 60 --script tools/checks/lost_prompt.gd
```

Five seconds down the middle of the road says nothing. Out on the grass beside
it the line comes up 1.3 s after the car leaves the road, naming R; with the
reset moved to K it names K. A car put back at the checkpoint is not still
being told a second later. Off the side of the floating road on each of the
seven acrobatic tracks that have one, it comes up 1.3 s after the car goes over
- while it is still falling, rather than after it lands. Four seconds parked on
a lift says nothing. And on a split screen, with player two on the grass and
player one on the road, the bottom half names M and the top half says nothing at
all.

Whether it can be read from the driving seat is the one part measuring does not
settle, so `tools/checks/lost_shot.gd` puts a car on the grass in each mode and
takes a picture:

```
Godot --path . --script tools/checks/lost_shot.gd -- /tmp/shots
```

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

On the tuned numbers the boosted car peaks at 46.5 m/s, spends 4.1 s above its
own top speed, and finishes 34.4 m up the road - about seven car lengths, on a
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

A hit also throws the car back off the face. For `obstacle_bounce_time` (0.4 s)
after one, whatever of the car's own speed is still carrying it into the face
is taken out of where it goes, and it is thrown back at `obstacle_bounce`
(6 m/s on a square hit, less on a glancing one), fading away. None of that
touches its speed - the hit has already cost what a hit costs - so a square hit
still takes 30 m/s to 8.4. Without it, a car held into a barrier on the
throttle stayed pressed against the face, was hit again every time
`obstacle_recovery` ran out, and was scrubbed down towards a crawl, where it
turns slowly.

`tools/checks/barrier_recovery.gd` runs a car square into a lone row with the
throttle held, keeps it held into the face for 1.5 s, then steers towards the
way past - once without the bounce and once with it:

```
Godot --path . --headless --fixed-fps 60 --script tools/checks/barrier_recovery.gd
```

Without the bounce the car stays on the face, is going 5.1 m/s after the
1.5 s, takes 1.08 s to turn 45 degrees away and hits the barrier 7 times in
all. With it the car comes 1.15 m back off the face, is still going the 8.4 m/s
the hit left it, turns away in 0.90 s at 6.7 m/s and hits it 5 times. How long
turning away takes is mostly the turning circle at that speed, which the bounce
does not change: at 8.4 m/s, 45 degrees is about 0.7 s away even for a car that
never touched the face again.

`tools/checks/barrier_layout.gd` lays out a hundred courses and checks every
barrier on them, then hands the validator two plans that break the rules on
purpose - a validator that has never rejected anything is not obviously
working - and finally runs a car at a barrier and through the gap beside it:

```
Godot --path . --headless --script tools/checks/barrier_layout.gd
```

On the tuned numbers that is 5.7 barriers a course, none with fewer than one,
no way past narrower than the 3.4 m rule, and no faults. Driving square into
one takes 30 m/s to 8.4 and wipes the boost; taking the gap beside it costs
nothing at all.

The spacing assumes the car goes to full lock the instant a key goes down, and
it no longer does: the steering eases out over `steer_rise` and back over
`steer_fall` (see Steering). A dodge stepped through the car's own steering,
with the switch across and the letting go timed to finish square, takes about
speed × (steer_rise + steer_fall) / 2 more road than instant lock does: 2.9 to
3.1 m at the tuned 30 m/s. At rows' closest spacing that still leaves 1.3 m of
the margin for seeing and deciding across a 2 m shift, 3.8 m across 4 m and
7.4 m across 8 m; on a boost at 46.5 m/s a 2 m shift is 1.0 m short.

Sideways grip (see Grip) takes a little more again, and for the same kind of
reason: the car has to gather an angle up before the path starts moving, and
give it back before the path stops. Stepped through the car's own steering
against the same car with the slide taken out of it, a dodge that ends with the
car *travelling* square - not merely pointing square, which a sliding car does
while still crossing the road - costs 2.6 to 3.5 m more at the tuned 30 m/s,
3.5 to 5.9 m at a chaos-fast 51 m/s, and 5.6 to 7.8 m at 79 m/s. Neither cost
has been designed out, and the spacing has not been changed for either; the
numbers are here so that a course that stops being driveable is a known figure
rather than a surprise.

At the fast end of what chaos rolls it does not fit, and did not fit well
before either. `dodge_radius` stays at the tuned car's 16 m while a chaos-fast
car turns no tighter than 21.6 m, or 23.8 m on its widest roll, so at 51 m/s an
instant dodge across 2 m already took 13.6 to 14.0 m of the 15.8 m the rows are
given. Easing adds another 4.8 to 5.4 m, which puts 2 m and 4 m shifts 1.3 to
3.5 m short; on a boost at chaos speed, 79 m/s, it adds 7.7 to 8.6 m, and every
shift is 2.3 to 7.1 m short. The spacing has not been changed for it.

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

## Traps

A trap is a row of barriers that moves. It holds one place across the road,
slides to the next, holds that, and goes back, for as long as the race runs:

```gdscript
trap(-0.7, 0.7)                  # kerb to kerb and back
trap(-0.6, 0.6, 0.8, 2.0, 1.2)   # wider, holding 2 s, crossing in 1.2
```

`from` and `to` are where the middle of the row stands at either end, in the
same lane units as everything else; `width` (0.6) is how much of the road it
covers, so the default reaches the kerb from either end of `trap(-0.7, 0.7)`.
It holds each end for `dwell` seconds (1.6) and takes `travel` seconds (1.0)
to cross, eased so it sets off and arrives rather than starting and stopping
dead. At GO it is at `from`.

It is timed, not random, and not reactive. The only way a moving hazard is
fair is if it is the same every lap: a trap that rolled a die as the car came
over the rise would sometimes be one nobody could avoid, and a track whose
gold depended on how the dice fell would have no gold time. Timed from GO, a
player who has driven it twice knows the rhythm, and driving the rhythm is
the skill.

### The clock

Where a trap is is `Placement.lateral_at(seconds)` - a function of the race
clock and nothing else. The race scenes hand `Track.set_race_time()` their own
clock every step they are running, before the cars move, and zero when they
count down. So a trap waits at GO through the countdown, and what a player
reads off the course while it counts is what they will meet; it stops when
the race stops; a restart puts it back where it started; and both players on
a split screen meet the same trap in the same place, because a race where each
car meets a different trap is not a race.

### Every place, not every phase

Everything a barrier has to obey a trap obeys - a way past at least
`clear_lane` wide, reachable from the way past the row before - and it has to
obey it everywhere it goes, not only where it rests. That is not the same
thing. A row sliding from one kerb to the other leaves the road open in one
piece at either end and in two pieces on the way across, and halfway is
usually its narrowest moment. A row covering 1.4 of the road's 2.0 leaves
4.8 m open at either end of its sweep on a 16 m road; halfway it leaves 2.4 m
either side of it, and a car fits through neither.

So `TrackFeatures.faults()` follows each trap across the road in steps no
further apart than `sweep_step` (5 cm) and asks for a way past at every one.
Reachability is asked for every place of one row against every place of the
next, and the furthest apart the ways past can be is what the road between
them is held to - in steps of `dodge_step` (25 cm), because that is every
place of one against every place of the other and costs the square of it.
That is the worst case rather than whatever the clock actually lines up, on
purpose: a player slower or faster than the course expects meets a different
pair of places, and a road that is only driveable at the right speed is a road
some players cannot get down. The same goes for a sweeper whose ways past only
line up where the two rest; a pair that is fine at GO can be 1.6 m apart with
5 m to cross in once one of them has moved, and that one needs 22.9 m.

Two traps may not stand beside each other along the road, because the checks
follow one trap at a time with everything else where it stands at GO. A trap
with no travel time is refused too: it is a barrier appearing on top of
whoever was in its gap.

### Building one

`TrackFurniture` builds the same striped row a barrier is, around its own
middle rather than drawn onto the road, on an `AnimatableBody3D` that is moved
from there. It is in the `obstacle` group, so hitting one costs exactly what
hitting a barrier costs - 30 m/s to 8.4 on a square hit, the boost gone, and
condition in damage mode - with no new collision code.

The body is an `AnimatableBody3D` rather than a static one moved by hand so the
physics knows it is moving and pushes a car it sweeps into instead of finding
it inside. Pushed towards open road that is all it takes. Pushed against the
kerb it is not: the rail is on the other side, and a car squeezed between two
walls was sorted out by the physics lifting it over the lower of them - it came
down 0.97 m up, on top of the trap and the rail, and drove away along the top
of the rail. So a car in the lane a trap is closing is shoved along the road
out of the row instead, at `trap_shove` (10 m/s), towards whichever end of the
row it is already heading for. That starts once the trap's leading edge is
`trap_shove_reach` (3 m) from the car or `trap_shove_lead` (0.45 s) from
reaching it, whichever comes first: the distance leaves a car threading the gap
alone until it plainly is not going to make it, and the time gives a fast trap's
shove long enough to clear the car before it arrives. A car parked in the row
ends about 7 m back from it, still on the road, at the tuned crossing and at a
0.5 s crossing faster than chaos ever rolls.

### On the tracks

Six tracks carry them, arriving gradually: Switchback has the first, slow and
alone on its straight; The Hook moves the second of a pair of rows; Relentless
turns a pair into two traps in step and opposite, so the way past both is
always a crossing of the road; Grinder puts a quick one on the exit of an esse;
The Wringer and Last Light each put one in a ramp's landing, and Last Light
moves the middle row of its last slalom.

Adding them cost those six tracks their times, and only those six. A time is
kept against a fingerprint of its own track file, and the leaderboard posts it
under a signature of the same file (see Track times), so editing a track
throws away what was set on the old one without touching `TrackTimes.GEOMETRY`
or any other track. The medal targets were not moved, and have not been
re-measured with `tools/lap_times.gd` since the traps went in: a trap always
leaves a way past, so a lap that reads it right should be no slower for it, but
that is an argument rather than a number.

### In chaos

A rolled course gets traps only under chaos, which sets `Track.traps_enabled`
and rolls `trap_chance` - how many of the rows are traps - between 0.2 and 0.6
with the rest of the course. Without chaos the endless course is the course it
was: the roll that decides whether a row is a trap is not made at all, so the
same seed draws the same numbers and builds the same road, and
`barrier_layout.gd` still reads 5.7 barriers a course.

A rolled trap sweeps kerb to kerb, and is fitted to its halfway point: it takes
no more of the road than leaves a clear lane either side of it there. Rows
around it are spaced against its worst place the way they are against each
other. And every course that asks for traps gets one, the way every course is
promised a fork: chaos courses are short in the straight, and half of them
rolled no loose rows at all, or only the fork's. So if the rolls left none, a
row is turned into a trap wherever that still passes every rule, and failing
that one is stood in the middle of the longest straight with room to see it
coming. Rows in a fork's fast lane are left alone - a lane is too narrow for
anything to cross it and leave a clear lane either side.

`tools/checks/trap_layout.gd` checks the clock, every trap on every track and
on a hundred chaos courses, hands the validator three plans that are fine
wherever their traps rest and wrong in between, drives into a trap and past it
while it holds each side, sweeps one into a car parked in the middle, parked
against the kerb, rolling into the row and half in it, and runs both race
scenes to see the traps held through the countdown, following the clock, and
back at GO after a restart:

```
Godot --path . --headless --fixed-fps 60 --script tools/checks/trap_layout.gd
```

On the tuned numbers that is 8 traps on the tracks with never less than 5.28 m
past any of them anywhere they go, and 109 traps among 306 rows on a hundred
chaos courses, 6 with none - those have no straight long enough to hold one
clear of the respawns - and never less than 4.44 m past. With the shove turned
off the same check reports cars lifted onto the rail.

`tools/checks/trap_shot.gd` looks at the first trap in the game from both cars,
one either side of the road, holding its start, halfway across, and holding its
end - so which half of the picture has the way past swaps between the first
shot and the last:

```
Godot --path . --script tools/checks/trap_shot.gd -- /tmp/shots
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
comes up out of the road as a curve (`ramp_curve`), so it has no edge at the
foot to catch on.

**And it cannot be too steep at the lip either,** which is the same fault at
the other end of the ramp and took much longer to find. The road is sampled
every 2.5 m and the car's collision box is level - it never pitches to follow
what it is standing on - so climbing a ramp is a flat-bottomed box being pushed
up a staircase of facets. Its bottom rests on one facet while its front face is
buried in the next, and above about 22 degrees on a facet that burial is deep
enough that pushing the box out of it cancels the whole of the step's forward
motion. The car stops dead: on the floor, one contact, velocity zero, still
reading full speed and still at full throttle.

At `ramp_curve` 1.5 the top facet was 25.6 degrees and the one below it 23.4,
and both were over the line. It did not show up everywhere because most cars
skip into the air at the foot of a ramp and are gone before the steep part -
but a car that arrives glued to the road stays on the surface the whole way up
and meets it. The Wringer's first jump is at the lowest point of that course,
reached flat and fast off a descent, and the bot jammed 8.4 m up it every
single lap: 1:33.82 against a 1:12 gold, one reset to get round at all, and
+30.3% where the rest of the field was +3%. Long Haul had begun to meet the
same thing at its jump at 1450 m, after a change seven hundred metres earlier
altered how the car arrived.

`ramp_curve` is **1.2**, where no facet is over 21.3 degrees. Both tracks are
clean, The Wringer comes home in 1:15.05 (+4.2%) with no reset, and the bot
needs putting back nowhere on any of the twenty. The foot still curves out of
the road, which is what dropping to a straight 1.0 would have given up. The
margin is thin and it is worth knowing why it is thin: the staircase is the
same on every jump on every track, so it does not vary by track, but it is
`ramp_rise / ramp_length` that sets it and changing either wants the facet
slopes worked out again.

A fourth was found later, by reading the car rather than by driving it.
Nothing wore the climb away while a car was in the air, so it came down still
holding what the ramp had given it - 10.6 m/s of it at tuned speed - and only
lost that at `climb_memory` once it was back on the road. Anything that ran it
out of floor in the next second or two threw it straight back up: the other
car's roof, the end of the landing, a crest just past touchdown. The climb is
now spent on the step it throws the car, so a car always lands holding none.

Floor snapping is on, at 0.6 m, and it is not what would stop a jump. Godot
only snaps a body that began the step on the floor and is not moving upwards,
and only as far down as the snap reaches. A car rolling off a lip has a hole
metres deep under it and nothing within reach, so it leaves the floor, and
from the next step on it is rising and snapping is not tried at all. What
snapping does do is keep a car on a falling road. A car on the ground has no
vertical speed of its own, so going downhill it runs flat off the surface and
has to drop back onto it; without snapping, a car driven flat out down a 4.7 m
descent spent three fifths of the run off the floor, in hops of up to nine
steps. Up a climb and over its crest it makes no difference at all.

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
it is taken at. The same ramp puts a car down 19.5 m past the lip on the
slowest, heaviest roll the game makes and 95.2 m past it on the fastest,
lightest one, and the road has to reach the far end of that.

Nothing else is built on a jump. The pads and barriers keep off the stretch a
jump covers, plus `jump_keep_out` (12 m) either side, and a checkpoint that
would land on one is moved to whichever end of it is nearer - a car put back on
the road at a ramp would go over the edge with no run up, and one put back in
the hole would drop straight through. Falling in is recovered the way falling
off has always been recovered: the reset that puts a car back at its last
checkpoint.

In the air a car has nothing to push against and nothing to brake on. Throttle,
brake and engine braking all stop the moment it leaves the road, so it flies at
the speed it left with, and its steering drops to `air_steer` (see Steering).
Before that a car could brake a jump away in mid air, or coast and come down
short. Flying the tuned jump off the lip at 28.9 m/s with nothing held, a car
used to land at 21.5 m/s, 31.0 m on; it now lands at the 28.9 it left with,
35.6 m on, whether the throttle, the brake or nothing at all is held. Held on
the brake it used to come down 17.1 m on and rolling backwards - short of a
17.5 m hole. Chaos leaves `air_steer` alone.

It has nothing to grip with either, so the way it is flying is whatever it was
doing as it left the lip and does not move again until it is down (see Grip).
That is what keeps every flight here a straight line, and every distance on
this page the distance it always was, with the steering held over or not.

`tools/checks/jump_flight.gd` drives a car off a real ramp at every corner of
what chaos can roll - speed from 0.78 to 1.7 of tuned, gravity from 0.65 to
1.4, and both at once - and asks the world what it came down on rather than
working it out from the curve. Each roll is given the hole that roll would
actually be built, since testing every one of them against the tuned hole would
be testing a course the game never lays down:

```
Godot --path . --headless --script tools/checks/jump_flight.gd
```

At tuned speed and gravity that is a 17.5 m hole cleared by 19.5 m; at the
slowest, heaviest roll chaos can produce it is a 10 m hole cleared by 9.5 m.
The longest flight is 95.2 m against 107.5 m of road to come down on, and no
roll crosses without leaving the ground. It then asks the opposite question,
because a jump every car clears whatever it does is scenery rather than a risk:
a car crawling at 10.5 m/s at the 17.5 m hole flies 7.3 m, comes down 10.2 m
short and ends up on the grass.

Each run lets the car down onto the run up 30 m before the ramp, leaves it to
settle at a standstill, and only then holds it flat out, stopping the run as
soon as it lands from the jump. It used to be dropped onto the run up 18 m out
already at speed, and a fast roll was still falling when it reached the ramp. A
car that meets a ramp in the air can catch its nose on it and stop dead - when
air control moved one run by a fraction of a metre, the 51 m/s car did exactly
that, 5.6 m up the ramp - and that is not a jump any player driving up a level
straight takes. Arriving on the ground, no speed from 20 to 80 m/s stopped on
the ramp; dropped onto it the old way, 78 m/s did.

That longest flight is what sets the ceiling on the cars' top speed. The
landing is 90 m of road and the ramp puts the fastest car chaos rolls, under
its lightest gravity, 95 m past the lip; there is 107.5 m to come down on, so
a further retune upwards lands the fastest roll on the grass rather than the
road.

`tools/checks/landing_climb.gd` flies a car off a real jump, then flies it
again with a flat-topped ledge built where it came down: 1.2 m high, which is
taller than the snap and so has to be left rather than held onto, and short
enough that the car runs off the end of it 0.55 s after landing. A flat ledge
has nothing to climb, so whatever the car goes up with off the end came from
somewhere else:

```
Godot --path . --headless --fixed-fps 60 --script tools/checks/landing_climb.gd
```

Before the climb was spent, the car landed holding +10.6 m/s and went up off
the end of the ledge at +7.4 m/s, rising 1.09 m. Now it lands holding
-0.1 m/s, which is nothing less one step's fade, and leaves the ledge at
+0.0 m/s. None of the jump or tilt numbers above moved.

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

Tipping the shell turned out to be only half of standing it on a ramp. The box
does not tip, so on any slope it rests on one bottom edge - the nose going up a
ramp, the tail coming down one - and the point the shell turns about, the
middle of that bottom face, is held clear of the road by however far the slope
has fallen away underneath it. At the lip of a tuned ramp that is **1.17 m**: a
car crossing it hung in the air with its wheels well off the surface it was
plainly driving on, on every ramp, in every race the game has ever run.

So the shell is sunk back down onto the road by as much as the box has lifted
it. Sinking the shell rather than lowering the box keeps the rule the pitch
already follows - the box is what the car drives on, and nothing about the way
the car looks is allowed to move it.

How far is measured straight down from the middle of the car rather than worked
out from the slope, because the slope is only right where the road is flat
under the whole car. A ramp that steepens the whole way up is already not, and a
crest with the car astride it is the case that would bury the shell: the road
under the middle is right there under the wheels while the surface the box is
resting on still reads as a slope. The slope is used for one thing only -
knowing what to believe. A box this long cannot hold its middle further off the
road than tipping it to `max_pitch` would, so anything past 1.5 m is not the
road but the ray having gone over an edge and found the ground below.

Unlike the pitch, the sink is not eased on the way down. The pitch is eased
because what a car is standing on changes in steps - one triangle's normal to
the next, and all at once on landing - but the height of the road under the
middle of the car does not: it is one surface and the car is driving along it.
Easing it only ever put the shell where the road was a moment ago, which on the
way up a ramp is a shell still hanging off it. Coming back up *is* eased, at
`pitch_ease`, so a car that leaves a lip with its shell down on the ramp does
not pop up off it as it goes.

`tools/checks/tilt_trace.gd` drives a car over a jump, which has every case in
it in order - level road, a ramp, the nose coming up off the lip, the nose
dropping through the top of the flight, and the road again on landing - and
then over a plain climb:

```
Godot --path . --headless --script tools/checks/tilt_trace.gd
```

Level road reads 0.0 degrees, the ramp +24.1, the fall -27.9, and a 2.9 degree
climb reads +3.4.

It also reads what is left of the lift, off the shell's own node rather than
off anything the car worked out. Over a whole run at the jump the box lifted
the shell by up to 1.17 m, and what was left of that was 0.00 m of daylight and
0.02 m of road, across the 83 steps that had road under the middle of the car.
The other 5 are the car out over the hole with its box resting on the lip
behind it, where there is no road under the shell to be off: the shell holds
where it was until the car is either back over road or off the ground, which at
a lip is the next thing that happens anyway.

And it reads the four wheels apart from the body, each against the road under
that wheel, because they are posed apart from it (see Body motion). Over the
same run the worst any wheel managed was 0.24 m of daylight and 0.18 m of road
- at the lip, where the front pair are out over the hole and the shell is
holding where it was. The body is read at the middle of the car, which is where
a rigid shell on a curving ramp is closest to right, and the wheels at the ends
of it, where a ramp that is still steepening leaves one axle slightly proud, so
the wheels are allowed 0.3 m against the body's 0.1. Leave the sink out of
where the wheels are put and the same run reads 1.19 m of daylight, which is
the whole lift and was what the wheels did.

The step the car lands on is left out of the wheel reading. The shell comes
down still carrying the pitch of the flight and eases out of it over the next
few steps, which at 24 degrees on a car this long puts the nose in the road and
the tail in the air. That is the pitch easing doing what it is meant to, and it
moves the body and the wheels alike.

Metres say the sums are right and not what a player sees, so
`tools/checks/ramp_shot.gd` stands a car four fifths of the way up a ramp - the
steep end, where the lift is worst - and photographs it twice from the side:

```
Godot --path . --script tools/checks/ramp_shot.gd -- /tmp/shots
```

Both pictures are the same car on the same step in the same place, posed by
hand with the same pitch and the same lean, and the only thing that differs is
whether the shell was put down on the road. Standing there the box holds it
1.11 m clear at 25.2 degrees, which is most of a car's height: in the first
picture it hangs over the ramp with its shadow well below it, and in the second
its wheels are on the road.

What it reads is the road pitch the car works out, `Car._pitch`, not the angle
the shell ends up at. The shell also leans on its springs now (see Body motion),
and that is the driver rather than the road.

## Body motion

On top of the road pitch, the shell leans with what the car is doing: it rolls
out of a corner, dips its nose under braking and sits back under throttle, and
is knocked down onto its springs when it lands. Like the pitch, none of it
touches the collision box; and none of it is mixed into the road pitch either -
the lean is laid over it, so tilt_trace still reads the road.

Every pull is worked out from how the car actually moved - its real speed along
its heading, and how fast that heading is turning - rather than from what the
player asked of it. A car held against a barrier with the throttle down does not
squat as though it were pulling away, and the bot drivers, which turn the body
directly instead of steering, still lean into their corners.

- Roll is `roll_per_accel` (0.12 degrees for every m/s² of sideways pull, which
  is speed times how fast the heading turns), up to `max_roll` (5 degrees). In
  the air there is nothing to lean against, and the body swings back to square.
- Pitch is `dive_per_accel` (0.1 degrees for every m/s² the car speeds up or
  slows down), up to `max_dive` (3 degrees).
- A landing knocks the body down at `landing_give` (0.08) of the speed the car
  came down with, and it may sink no further than `max_squash` (0.15 m).

All three hang on the same damped spring, `body_spring` (60 per second squared)
and `body_damping` (9 per second), damped well short of what would stop it
overshooting, so a lean settles with a small swing back rather than arriving
dead.

The wheels do not lean. They are on the road rather than on the springs, so each
one is put where the body sitting square would carry it, and a car rolling
through a corner keeps all four on the road instead of lifting one and burying
another.

Square there means square *on the road*, which is the one thing the sink above
is not allowed to be left out of. The sink is not the body moving over its
wheels, it is the whole car being lowered onto a road the collision box is
propped up off, so the wheels come down with it. They used not to: the shell was
posed with the sink folded into the spring's drop, the wheels were held at the
un-sunk height, and on a ramp - where the sink is over a metre, most of a car's
height - the body dropped onto the road and left its wheels standing in the air
above the roof. The car now hands the shell the sink and the drop separately,
and the wheels follow the one and not the other.

The driver's eye goes where the body takes it but keeps only `eye_roll` of its
roll, which is none, for the reason Views gives.

Traced on the tuned numbers: taking a corner at 25.9 m/s rolls the body 3.2
degrees; braking at the full 24 m/s² puts the nose down 2.6 degrees, one small
swing past the 2.4 it settles at; pulling away at 12 m/s² brings it up 1.3; and
a flat landing at 18.5 m/s sinks the body 0.086 m, deepest eight steps after
touchdown, and has it back up and settled about half a second after that.

`tools/checks/body_shot.gd` takes a picture of each - a car mid-corner and a car
just after landing - with the chase view above and a camera stood off the car
below, in front of it for the corner and beside it for the landing:

```
Godot --path . --fixed-fps 60 --script tools/checks/body_shot.gd -- /tmp/shots
```

The landing picture also shows something the lean does not touch. The road
pitch is still easing out of the dive the flight put the nose into - it reads
-24.1 degrees at touchdown and -9.8 six steps later - so for the first tenth of
a second on the ground the nose, front wheels and all, is dug into the road.
Landings have always looked like that; the wheels follow the road pitch, as the
whole shell did before.

## Landing on the other car

Coming down on the other car's roof throws a car back up; coming down on
anything else - the road, the grass, a barrier, a ledge - puts it down and
keeps it there. Nothing about racing needs it. It is there because a car that
lands on its rival ought to know about it.

`Car.roof_bounce` (0.6) is how much of the speed a car comes down with it goes
back up with, so every bounce is lower than the one before and a car always
settles, and nothing slower than `roof_bounce_min` (2 m/s) bounces at all, so
a car sitting on a roof rests there instead of juddering. The bounce is capped
at `max_launch`, the same ceiling a lip has. Only a floor counts: a car that
comes down across the other car's flank, or clips a corner of it on the way
past, has hit a wall, and a wall throws nothing back.

The bounce is handed over a step late, on purpose. The step that lands a car
is also what tells the next step it is on the floor, and a car on the floor has
its vertical speed taken away before it moves, so a bounce set on the landing
step would be gone before it did anything. A car leaving a roof on a bounce is
not a car running out of road either, so it is not handed its climb on the way
up as well. Solo has no other car, so nothing there ever bounces.

Chaos leaves the bounce alone. It already rolls gravity, which is what decides
how high a bounce goes and how long it hangs, and rolling how much comes back
on top of that would make the one silly thing in the game unpredictable in two
ways at once.

`tools/checks/roof_bounce.gd` drops a car 3 m onto the other car's roof, and
then the same 3 m onto the road beside it:

```
Godot --path . --headless --fixed-fps 60 --script tools/checks/roof_bounce.gd
```

Onto the roof it comes down at 11.6 m/s, goes back up at 7.2 m/s and 1.14 m,
bounces four times and comes to rest on the roof 1.93 s after it was let go.
Onto the road it comes down at the same 11.6 m/s and never leaves it again.

## Car-to-car contact

The two cars are both `CharacterBody3D`, so to each other they are walls:
`move_and_slide` stops one going through the other and does nothing else. A car
nosed into the other's bumper sat there at full throttle reading as fast while
going nowhere - the same thing `_take_the_hits` stops a barrier doing - and a
car leant on from the side was not moved at all. `CarContact` adds the bump.

From behind, the car doing the hitting loses `bump_take` (0.75) of the speed the
two were closing at, and the car it hits is handed `bump_give` (0.25), never past
its own top speed. The give is always held under the take, so running into a
car costs more than it hands over and ramming never pays; and the two are tuned
to come to one, so after a square hit from behind neither car is still closing
on the other. Both are scaled by how square the hit was - how straight the
hitter was pointed into the other car - and the car hit only turns what it is
handed into speed as far as it is pushed along its own heading, so a car hit
from in front is slowed and one hit side on is not sped up at all.

From the side, both cars are pushed apart at `side_push` (4 m/s), as much of it
as the contact is across each car, fading away over `push_fade` (0.3 s). The
push is not speed. It is added to where the car is going inside `_drive`, so
`move_and_slide` and the rails still decide where it ends up, and a car pinned
between the other car and a rail slides down the rail rather than through it.
`bump_recovery` (0.4 s) is how long before another contact counts, for the
reason `obstacle_recovery` gives.

Contact does not end a boost, for either car. The other car is not the hazard a
pad was offered against, and a boost a rival could end just by getting in the
way would make blocking pay.

It is settled in one place rather than by each car. The cars take their physics
steps one after the other, so a car that knocked the other in its own step would
hand it a changed speed before it had moved, and how every contact came out
would depend on which car was first in the scene. `CarContact` runs ahead of
both cars, reads what each ran into on its last move, works the contact out once
from both cars' speeds as they stood at the start of the step, and hands both
their knocks over together. Only the two-player race builds one; solo has one
car and nothing for it to run into. Chaos leaves all of it alone.

`tools/checks/car_contact.gd` runs a car at 30 m/s into the back of one at
20 m/s in the same lane, once each way round, and squeezes two cars side by
side into a rail:

```
Godot --path . --headless --fixed-fps 60 --script tools/checks/car_contact.gd
```

From behind, both cars come away at 22.5 m/s - the rear car losing 7.5 and the
front car gaining 2.5 - in a single contact, the same whichever car is behind,
with the boxes never inside each other. Side by side, with the outer car turned
8 degrees into the rail at 20 m/s for two seconds, the cars are pushed apart
three times and are never more than 0.022 m into each other. The pinned car's
side ends up 0.02 m past the rail's face as it is worked out from the course,
well inside the 0.28 m the rail is thick, and both cars are still on the road
at the end.

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

## Choosing a mode

Play opens one page that asks two things in order, without ever becoming a
second page.

How many are playing comes first, as two buttons side by side, because it is
the one choice that changes what every other choice means: the same endless
course is a race against someone in co-op and a run against the clock alone,
and the same laid-out track is a time to beat alone and a road to race down
together. It is also the only choice that decides which scene the race runs in
- everything after it is a setting that scene reads once it is up, so the
routing is one line.

Answering rolls the modes out from underneath, from the middle of the page
rather than from under whichever of the two was pressed: what opened is the
rest of the page, not a drawer belonging to one button. The two stay where they
are with the answer held down on them, so a player can change their mind
without going back anywhere, and the page goes on saying which way this race is
being played while the rest of it is decided. It opens on whichever way they
played last, which is remembered between runs.

The chaos button never settles on a colour. Everything else on the page says
what it is in words; this one also says it by refusing to sit still, which is
the only thing on the screen that behaves the way the mode does. It turns
through the colours over `chaos_cycle_seconds` (7) - slow, because the point is
a button that is never quite the colour it was rather than one that flashes -
and `chaos_tint` (0.5) is held well under full because this tints the whole
button, its face, its border and the word on it, and a strong tint takes the
word with it.

It is a `modulate` rather than a stylebox, so one line covers the button in
every state it has. Overriding its face would leave it plain the moment it was
hovered or focused, which is most of the time it is on the screen.

Inside that, Infinite does not start a race either: it opens out in turn,
sliding the choice between a normal race and a chaotic one down from under
itself, and it is that click that starts the game. A slide inside a slide costs
nothing because the outer one is held to the height of its own contents rather
than to a height measured when it opened - the inner grows as its buttons roll
down, and the outer grows with it instead of clipping them.

Both slides are the same code. The slot is what the layout sees, so growing its
minimum height is what moves the rest of the page; the contents ride up inside
it and are clipped, which is what makes them slide rather than simply appear.
The height is asked of the contents rather than written down, so it stays right
if the wording or the font ever changes.

Each mode has a line under it saying what it is, and those lines are not part
of what slides. The line under Infinite stays where it is and is pushed down by
the flavour buttons, the same as everything below it: it describes the mode
rather than the choice, so it is as true before the buttons are there as after,
and a page where half the words appear on a click reads as a page that was
hiding something.

Both lines are also pulled back up towards what they describe. The page is one
column with one spacing between everything in it, which is right between a
button and the next button and far too much between a button and its own
description - a line that far under a button reads as a separate thing rather
than as part of it. They ride in margins with a negative top, which closes that
one gap without touching any of the others.

Tracks is a door the same way. It slides NORMAL and ACROBATIC down from under
itself, and NORMAL is what opens the grid. Acrobatic tracks are a different
thing to drive and get their own grid rather than a place in this one; until
there are any, ACROBATIC is there but greyed and cannot be pressed, for the
same reason the grid shows slots for tracks still to come.

Backing out walks the way in, in reverse: the track grid, the flavours or the
kinds of track, the modes, then the page.

`tools/checks/mode_routing.gd` walks in and sees which scene comes out the far
end. Two questions before a race and two scenes to run it in is four ways in
and four chances for one of them to land somewhere it should not:

```
Godot --path . --headless --fixed-fps 60 --script tools/checks/mode_routing.gd
```

## Choosing a track

Play opens the mode page, and Tracks now opens out of it into a grid of
twenty. Each cell is the track's name over an overhead shot of the road it is.

All twenty are there now. The grid was built before they were, and a slot with
nothing in it was still shown - framed and unpressable - because nineteen doors
that did not open yet said what the game was going to be, where a short grid
that grew every few weeks would have said nothing at all. That behaviour is
still in `TrackRoster.exists()` and still worth keeping: it is what a
twenty-first track would be added into. An empty slot gets its own dark
outlined face rather than the theme's disabled grey, which fades a button into
the page until it reads as a hole rather than as a track to come.

The cells are built in code from `TrackRoster` rather than written into the
scene: twenty of them is a great deal of scene, and every one would have to be
edited again the day a track was added. A track's name is read off the track
itself by building its description, which costs a few array appends and no
geometry - a name written down in two places drifts, and the one on the button
would be the one nobody notices is wrong.

A name is held to the width of its picture, and one too long for that is set
smaller until it fits, down to `track_name_smallest_font_size`. It keeps the
height of a name at the usual size, with the smaller text centred in it, or its
picture would rise a few pixels out of line with the rest of the row. Not
wrapped, which would push its picture down out of line the other way, and not
given a wider column, which would widen all five for the sake of one name. A
name cut off at both ends reads as a different name - LONG WAY ROUND came out
as .ONG WAY ROUNI before it was shrunk.

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

Pressing a track opens a page of its own rather than starting a race: its
name, a wide overhead shot, its board and the player's time and place on it,
and under them a row of the ways it can be driven, with PLAY to drive the one
held down. See [Track variants](#track-variants) for the ways, and for what
the page does with the one held down.

Under the grid, above Back, is Leaderboard. It opens on whichever track the
cursor is sitting on, worked out from what currently holds focus rather than
remembered, so it cannot go stale. That is one page with the track picked
inside it rather than a board hung off each of the twenty cells: a player
looking at one board is nearly always about to look at the next, and a page
they have to back out of and come back into twenty times is a page they look
at once. Every way of driving a track has a board of its own, so the page has
the track page's row of ways under its picker, and the way held stays held
from one track to the next - somebody reading the Hard boards reads them one
after another. It opens on the track as written, except on the track the
player has just come back from, where it opens on the way they drove it.

Beside it, in the same row, is Statistics - see [Statistics](#statistics). It
is there whether or not the build has a server, since everything on it is kept
on this machine, so in a build without one it has the row to itself.

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
has to divert from a seed to a file. It also measures every name in the font
it is drawn in, and counts one wider than its column as a fault, since a cut-off
name is still a name to a check that only asks whether there is one.

```
Godot --path . --headless --script tools/checks/track_select.gd
```

## Track variants

A laid-out track can be driven more than one way, and none of the other ways is
written by hand. A variant is the track's own file put through a transform in
`TrackVariant`, applied by `Track.lay_out()` straight after `describe()` and
before anything is built. Everything downstream of that - the road, the rails,
the checkpoints, the furniture, the checks - is handed an ordinary definition
and never has to ask where it came from.

The ways are named constants, `NORMAL`, `MIRROR`, `REVERSE`, `HARD` and
`TRACK_CHAOS`, rather than strings typed out where they are used, so a misspelt
one is a compile error rather than a quiet extra board nobody can find.
`NORMAL` is the track as written, and all four of the others are built.

**Mirror** swaps left and right. Every corner turns the other way, and
everything on the road - pads, rows, traps, the fork, rings, platforms, lifts,
kickers and the high roads off them - stands on the other side. Climbs, jumps
and lengths are untouched. The car is the same on both sides, so a mirrored lap
is the same lap turned round, and it is worth the same medals as the track's
own. The bot's laps back that up: on every normal track its mirrored lap is
within 0.6% of its lap of the track as written, and on every acrobatic track
it finishes cleanly both ways, within 0.7%. `tools/lap_times.gd -- mirror`
asks again, and names any track more than 1% out, which would need targets of
its own.

**Reverse** drives the track the other way: the grid is on the old finish
straight and the flag where the grid was. Every corner, climb and hazard is met
in the opposite order and from the other side, so corners turn the other way,
climbs fall, and everything on the road changes sides. A fork's pad is put back
the same few metres in from the lane's new entry, since at the far end of the
lane it would reward a choice already made.

Jumps are the hard part, and every normal track has at least one. Read
backwards, a jump is a long run, a hole, and fifteen metres of road where the
ramp was, with no ramp facing the car. So each is built again from the road
around it. The old landing, less a ramp's length, becomes level road, and its
last fifteen metres become the new ramp. The hole stays where it was. The old
ramp and the level straight that was its run-up become the new landing. The
pieces are counted in samples rather than metres, so the course comes out
exactly as long as it went in, and every placement lands back on the stretch
of road it stood on.

That last part is where a track can refuse. Nothing may stand on a jump's
landing, and nothing held a run-up to that. A pad sixty metres before a ramp
is a pad on the approach, and reversed it is sixty metres past the hole. So a
reversed landing stops short of the first thing standing past the hole, with a
jump's keep-out to spare, though never shorter than the 55 m a landing has to
be. Where even that would reach something, the track does not offer Reverse,
and the reason is written down beside it in `TrackVariant.WHY_NOT` for the page
to show. Whiplash and Last Light are the two: each has a pad or a row within
sixty metres of a ramp. Every normal jump is level, so no reversed jump has to
climb.

The acrobatic tracks offer Mirror and nothing else, and their page does not
show the rest. Rings, platforms, lifts and high roads are all aimed at where a
ramp throws a car, and none of them has a reverse that is the same kind of
thing.

Reverse's medals are its own, because backwards is a different road to drive:
a climb that was taken slowly is now a descent, and a hairpin met out of a
straight is now met out of a corner. The bot drives each track both ways, and
the ratio of its two laps stretches the track's own gold, silver and bronze,
rounded to the second. Cold Start is 4% quicker backwards and asks for 36/40/46
rather than 38/42/48. Leap of Faith is 3% slower and asks for 53/59/65 rather
than 51/57/63. The targets are the `TARGETS` table in `TrackVariant`, for the
reason the list of ways is kept there rather than in the track files, and
`tools/lap_times.gd -- reverse` prints that table to paste in.

**Hard** is the same road with more on it: half as many rows of barriers
again, and some of them moving. It never touches the car and never changes the
road: the road is the track, and the hazards are the variant. It is fixed, not
rolled. It is seeded off the track's name, with a generator of its own, so a
Hard track has the same rows in the same places on every run and every
machine, which is what makes a Hard time worth writing down.

The rows are put down by `TrackFeatures.harden`, using the planner a rolled
course is built with: `_row_at` rolls a row on a straight and cuts it back to
leave the clear lane. A row is kept only if the whole plan still passes every
rule `faults()` holds a course to. Then some rows are turned into traps on the
same terms: at least one per track, and about a third as many as were added.
A row that would break a rule is never put down, so a Hard track is harder to
read and never one that cannot be finished.

Where a row goes matters as much as whether a car can get past it, so Hard's
rows keep further off than the rules ask. They keep off every jump's run-up,
which the tracks all leave long, level and empty, since lining up with the
ramp is all a run-up asks of a car. They keep 35 m clear of the end of every
corner, where a row would not be seen until it was too late to avoid
(`hard_sight`). And they keep clear of the fork and its approach. The first
Hard tracks had rows in both of the first two places. The bot came off a ramp
crooked on Last Light, and circled a row straight out of a hairpin on Grinder,
and neither broke a rule.

A row Hard adds is also held to a stricter reading of the dodge rule than the
tracks' own rows are. `faults()` measures the move from one row's gap to the
next as the distance between the gaps themselves, so two gaps that only touch
count as no move at all, though no car fits through a point.
`hard_row_holds` measures the move for something a clear lane wide, which has
to get all of itself from one gap into the next. The tracks' own rows were
written against the looser rule, and five of them have slaloms that would fail
the strict one by a metre or two, so tightening it for everyone is a question
of its own.

How much harder Hard is comes down to two numbers in `TrackVariant`:
`HARD_MORE_ROWS` (1.5) and `HARD_TRAP_SHARE` (0.3). Every Hard fingerprint is
taken over the plan they make, so moving either drops every Hard time.
Rattlesnake takes 31 rows where it asked for 33, which is all the room it has.
Hard is offered on all twenty normal tracks and none of the acrobatic ones,
where most of the course is in the air and a barrier on a landing is a meaner
thing than one on a straight.

Hard has no medals yet. Its targets would be measured the way Reverse's are,
but the bot sees every row a long way off and dodges it without lifting, so its
Hard lap is within a few per cent of its lap of the track as written. Measured
that way, Hard's gold would be the track's gold, which says the rows cost
nothing. They cost a person reading them a great deal more than that, so the
targets wait on a person driving it.

A Hard plan depends on where the grid, the flag, the respawns and the jumps
fall, which only a `Track` knows. So it is planned in `Track.plan_course`, the
half of `lay_out` that works out the plan without building anything. To
fingerprint a Hard time, `TrackVariant.described` asks a `Track` that is never
put in the world for the same plan. So the fingerprint covers exactly what the
race is run on, worked out by the same code rather than by a second copy of
it.

**Track chaos is not chaos mode.** They share the word CHAOS on their buttons
and nothing else. Chaos mode belongs to the endless course, and re-rolls the
car, the sky and the road itself. Track chaos is a way of driving a laid-out
track: the road is the track as written and the car is the tuned car, and only
the hazards change - rolled again on every run, including an instant retry.
The code and the notes always say *track chaos* for this one
(`TrackVariant.TRACK_CHAOS`, kept under `<track>-track_chaos`), so the two are
never mistaken for each other. Its button on the track page says CHAOS and
turns through the colours the way chaos mode's does, and that is the one place
they look alike.

What track chaos keeps of a track is the road, the fork - its divider, its pad
and the slalom in its fast lane - and every pad. `TrackFeatures.strip_loose_rows`
takes up the rest of the rows and traps, and `roll_track_chaos` rolls new ones
with `_place_obstacles`, the pass that lays rows on a rolled course. Traps come
at a chance drawn from chaos mode's own range (`Chaos.TRAP_CHANCE`). The new
rows keep off what Hard's keep off and are held to what Hard's are held to, so
a roll is as fair as a Hard track, and a row that fails is taken back up. The
coins roll again with the rows. The same seed always makes the same roll: two
players on a split screen share one track, so they meet one roll, and a check
can deal a roll again.

A retry does not rebuild the road, because the road is the same road. So
`Track.reroll_track_chaos` throws away and rebuilds only what stands on the
road: the rows, the traps and the coins. It takes 6-26 ms, a frame or two, so
retry stays instant. In two-player races every new race builds the track anyway,
and each is a new roll.

Track chaos has a best time and a board, like every other way, because that
was asked for. What that costs is worth saying: two players' times on it were
set against different rows, so the board ranks luck as well as driving. Its
fingerprint cannot be taken over the rows, since they are different every run
and every best time would be dropped the moment it was set. So it is taken over
what is kept - the track with its loose rows taken up and none rolled - which
is `TrackVariant.described` with no roll. It has no medals: a target measured
on one roll of the hazards is only a target for that roll. It counts in
Statistics as a completed race like any other time trial, and like every
variant it does nothing for the medal gate.

Which ways a track offers is a table in `TrackVariant` keyed by file name, and
not a line in the track file. A time's fingerprint is taken over the whole of
its track's file, so adding a line to all thirty would throw away every best
time on every track for a change that did not move a single corner. Bot roads
are not in the table and offer nothing: the gate is one race against one road.
A race asked to drive a way its track does not offer drives it as written.

The way a race is driven travels in `GameSettings.track_variant`, next to
`track_file`, and is not written to disk for the same reason. Both race scenes
hand it to their `Track`, so two players on a mirrored road is a mirrored race.
A high road is laid out as a `Track` of its own and is handed everything its
course has except the file and the variant: the course's `lay_out()` has
already mirrored it, and a second pass would mirror it back.

A way is picked on the track's own page, by holding its button down, and PLAY
drives the way held down. The row of ways is `WaysRow`, one control that the
track page and the leaderboard both put up. Two copies of five buttons,
each with its own look, would drift apart, and a player who has learnt the
row on one page should meet the same row on the other. It is what writes HARD
in red and MIRROR mirrored, and CHAOS is handed its colour by the menu each
frame, so every CHAOS on the screen is the colour chaos mode's button is at
that moment. A way the track does not offer is faded rather than
hidden: the row of buttons stays the same from one track to the next, and a
faded way's board is still worth reading. Holding one down turns PLAY off and
puts a line over it saying why - `TrackVariant.why_not()`, so every page that
refuses a way gives the same reason. With MIRROR held, the overhead shot is
turned round. That is the same picture flipped rather than a second one drawn
and checked in, because a mirrored road is exactly that. Coming back from a
race opens the page with the way it was driven held down again, since the same
way again is what a player is most likely to press PLAY for. "Next track" on
the finish screen keeps the way too, where the next track offers it.

In a race the road is named with the way beside it - `FIRST LIGHT · MIRROR`,
from `TrackVariant.title()` - in the corner under the best time, over the time
on the finish screen, under the result of a two-player race and at the top of
the pause screen. A mirrored road looks like a road, and a time read off a
screenshot has to say which road it was set on. The track as written is
named plainly, `FIRST LIGHT`, and the endless course is not named at all.
`tools/checks/solo_shot.gd` draws a mirrored countdown and finish to look at.

A variant is a different road, so it keeps its own time, its own board and its
own coins - see [Track times](#track-times) for how its time is kept apart. Its
coins are seeded off the track's name with the variant on the end, so they are
still the same on every run but are not the base track's coins moved across.

`tools/checks/variants.gd` is the only thing that has ever looked at a variant,
since nobody laid one out. It builds every way every track offers, the way a
race does, and holds each to the rules a hand-made track is held to; a way that
would build clean but is not offered is reported too, so no track quietly
misses out. A mirror has to be its own inverse to the millimetre - mirrored
twice is the track as written, which is the quickest way to catch a sign
flipped twice or not at all - and the check is shown a mirror with one lane
left unturned, to prove it can say no. A reverse has to be its own inverse too,
compared as the road that gets built, sample by sample, rather than piece by
piece. Reversing twice can move where a jump's piece ends and the straight
after it begins without moving any road. Hard has to be the same road as its
track, with more rows or traps on it, and the same plan every time it is made.
Everything the track put down has to still be where it was, or be a row turned
into a trap in the same place. And a Hard row squeezed in two metres behind
another, covering exactly the gap that row leaves, has to be refused. Track
chaos is rolled 25 times on every normal track (`-- 100` for a hundred), and
every roll has to pass every rule and keep Hard's. What is kept has to be the
same under every roll, the rolls cannot all be the same, one seed has to make
the same roll twice, and a roll made in place on a built track, the way a
retry makes it, has to equal one built from nothing. Every
hole in a reversed track has to
be where a hole was, and the check is shown a jump that would have to climb
five metres reversed and a run-up too short to land on, and has to refuse
both. It also works out every base track's
fingerprint and signature the old way, by hand, and fails if either has moved:
every best time anybody has set is held against them.

```
Godot --path . --headless --script tools/checks/variants.gd
```

`tools/checks/variant_drive.gd` is what turns "builds clean" into "can be
driven". The bot drives every way every normal track offers, from the grid to
the flag in `Solo`, beside the track as written, and prints each lap against
the original. `tools/checks/acrobatic_drive.gd -- mirror` drives the mirrored
acrobatic tracks with that check's own driver, which lines up with rings and
waits for lifts.

```
Godot --path . --headless --fixed-fps 60 --script tools/checks/variant_drive.gd
```

The other pages that read times read them per way. Statistics has a column
for each - see [Statistics](#statistics) - and the leaderboard the row of ways
above. The medal gate reads none of them: it counts golds on the tracks as
written, since a mirror gold on a track already golded is the same driving
counted twice. `tools/checks/variant_pages.gd` sets times on a few ways of a
few tracks and reads both pages back: each time under its own way, worth what
it is that way, and the leaderboard holding the right way as the track
changes under it. `tools/checks/leaderboard_shot.gd` photographs the row.

```
Godot --path . --headless --script tools/checks/variant_pages.gd
Godot --path . --script tools/checks/leaderboard_shot.gd -- /tmp/shots
```

`tools/checks/track_select.gd` holds MIRROR down on First Light's page, presses
PLAY and checks that the race it lands in is on the mirrored road. It also
holds each way down in turn, checking that PLAY, the faded buttons, the line
under PLAY and the picture all agree with what the track offers, and comes
back from a mirrored race and from one it cannot offer.
`tools/checks/mode_routing.gd` carries a mirrored track down both routes, solo
and two-player, and then an infinite race, which has to have forgotten it.

## Solo

Solo is its own scene, and it runs either a laid-out track for a time or the
endless course for its own sake. Which one it is comes down to whether a track
was picked on the way in; nothing else about the scene changes.

The endless course alone has no time to beat and nothing to write down - the
next road is a different road - so there is no medal, no best in the corner and
no record kept. What the clock is for there is the run you are on. Asking for
another go rolls another road rather than replaying the same one, which is the
difference between the endless course and a track: the same road is the whole
point of one and beside the point of the other. A finished course holds for a
moment and then rolls the next by itself, so the endless course keeps going
without being asked to.

It is its own scene rather than the two-player race with a seat empty. Almost everything in `Main` is
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

On a laid-out track, finishing measures the run against the best so far, which
is kept in `TrackTimes` and survives the game being closed.

Which of the two a race runs in is decided entirely by how many are playing.

`tools/checks/solo_run.gd` drives a whole run, from the line to the flag:

```
Godot --path . --headless --fixed-fps 60 --script tools/checks/solo_run.gd
```

The car is driven by the bot ([The bot](#the-bot)), the same driver the bot
race puts in the other car, through the pedals and the wheel. It used to have
a driver of its own that turned the car by rotating its body and set its speed
outright; that drove nothing like the car a player has, and two copies of a
driver drift apart, so it went when the bot arrived.

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
same reason when something outside the track files changes what a lap of them
is worth - the sampling step, the size of a jump, what a pad is worth, how the
car handles, or what it takes to finish.

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

`TrackTimes` also knows a track by a second name. `fingerprint()` is the
engine's own hash and is what decides whether this machine's record still
stands; `signature()` is sha256 over the same material and is what a shared
board is keyed on. The difference matters only when a time leaves the machine
it was set on: a board has to agree across a Mac, a Windows box and next
year's Godot, and an engine hash promises none of that.

Both are taken over `source()`, which is the track file where there is one and
the copy of it an export carries where there is not (see Exported builds). A
time written down with a fingerprint of 0 was set by a release from before the
copy existed, which could read no track at all; it is kept and given the
track's fingerprint as it is now, rather than every tester's times being thrown
away for a fault that was not theirs.

A [variant](#track-variants) is kept under the track's key with a hyphen and
the variant on the end - `01_first_light-mirror` - so it has a section, a time
and a board of its own. A hyphen, because every track file is named with
underscores and the two halves can never be confused. A time on the track as
written has exactly the key, fingerprint and signature it had before variants
existed. A variant's fingerprint covers more than the file: it covers the road
the variant makes of the file too, written out to the millimetre. A variant's
author is `TrackVariant` as much as the track file, and a change there moves
every mirrored road with no track file changing - a time set on the old one is
a time on a road that is no longer there. That road is worked out once a
session, since it means describing the track, and neither the file nor
`TrackVariant` can change while the game is running.

`adopt()` is `record()` without the announcement. It takes a time that was set
somewhere else - the same player, on their other machine - and keeps it if it
is better. It is deliberately not `record()`: what comes back off a server is
not a run that just happened here, and treating it as one would declare a new
best in the middle of the menu and send it straight back where it came from.

`tools/checks/track_times.gd` sets times, closes the game and sees what is
still there, then edits a track and sees that the time on the old one has gone.
It does the same for every way of driving a track. It edits a copy of First
Light with a comment that moves no road, and the time on every way has to go,
since every way is driven on that file. Then it moves one of First Light's
Hard rows a metre, with the file untouched, and only the Hard time may go.
It writes to a scratch file, and edits a copy in the sandbox rather than a real
track, so running it does not touch anyone's own record:

```
Godot --path . --headless --script tools/checks/track_times.gd
```

## Statistics

A page of lifetime totals - how far the cars have been driven and for how
long, how many races were finished and how many won, how many tracks have a
time, how many coins were picked up, how many cars were wrecked, how many
resets were asked for - and under them the best time and medal on every
track, each way it is driven. It opens from two places: Statistics beside Controls in the settings,
which is where a player looking for it by name tries first and which works over
a paused race as well as on the title, and Statistics beside Leaderboard on the
track page, where half of the page - the table of times - is already the
question being asked. The settings carry their own copy of the page inside
`scenes/settings.tscn`, so it goes wherever the settings go.

The totals are `Stats`, an autoload over `user://stats.cfg`, in
`scripts/stats.gd`. It is kept apart from `GameSettings` because a total is
something that happened rather than something chosen, and apart from
`TrackTimes` because a total is never beaten, only added to. One section,
`[totals]`, not a section per thing as `TrackTimes` and `Progress` do it:
those grow a section per track or block, and this is a fixed handful of
counters that grows by nothing. No fingerprint either - a lap time stops
meaning anything when its track is edited, and a distance does not.

The times are not copied in. The table reads `TrackTimes.best()` and
`Medal.earned()` every time the page is drawn, the way the medal gate does, so
there is no second copy of a best time to disagree with the first. A time on a
track that has since been edited comes back as no time, silently, from the same
call, and shows as a dash - which is right, because it was set on a road that
no longer exists. Locked tracks keep their row and their name, so the table
does not change shape as a player unlocks things, and the acrobatic tracks are
grouped under their own heading as they are on the select screen.

Every way of driving a track has a column: NORMAL, HARD, CHAOS, MIRROR and
REVERSE, in the order the track page has them. All five at once rather than a
row of ways to pick one from, because this page is there to be read at a
glance and five columns fit, at the largest interface size too. A way a track
is not driven is left blank, which is not a dash: a dash is a time still to
set. Each group's heading names only the columns it fills, so the acrobatic
tracks' says NORMAL and MIRROR. Every time sits over a thin bar in the colour
of its medal, worked out against that way's own targets. It is a bar rather
than only a coloured time, for the reason the grid has one: against a dark
panel a silver time and a time worth nothing are two shades of pale.

TRACKS WITH A TIME counts the tracks as written and no other way. With every
way counted it could reach over a hundred, and a number that big hides the
one it is there to say: whether the tracks themselves have all been driven.

### What a number means

Each of these was settled before anything counted, because a question left
until then gets answered by whichever branch was easiest to reach.

- **A race is completed when a result is announced.** A finish, a win, a
  loss, a breakdown, a draw. A run quit from the pause screen or restarted
  announced nothing and completes nothing.
- **A breakdown is completed, and a wreck.** It ended in a result, just a bad
  one. A count that only moves when the player succeeds cannot tell "I have
  played a lot" from "I am good".
- **A win is beating somebody**: the bot, or the other car on a two-player
  course - including by being the car that did not break down. A solo time
  trial has nobody to beat and is never a win; what it earns is a medal, and
  that is counted as a medal. The win rate is taken over the races that could
  have been won, never over every race finished, or a player who mostly races
  the clock would read as someone who mostly loses. It is worked out on the
  page and never stored, and with none of those races yet it is a dash.
- **A two-player course is one race and at most one win**, whichever half of
  the screen took it. There is one record on this machine, for the reason
  there is one purse.
- **A wreck is a car worn to nothing**, and only a car a person drove: the
  bot's car breaking is the player's win. Both cars breaking on a split screen
  is two wrecks. Contact that took condition off is not a wreck, and is not
  counted at all yet - one long scrape along a barrier would need a rule of its
  own. Resets are counted beside wrecks rather than inside them, and only when
  somebody pressed the key: the bot asking to be put back goes down the same
  path in the race, and is not counted.
- **With damage off nothing is ever wrecked.** Damage is off by default, so the
  row is greyed with a line saying why, rather than a zero with no reason.
- **Distance is distance raced**, and only while the race clock runs - not on
  the line before GO, and not on a finished course, where a player idling
  could otherwise farm kilometres. It is the player's distance and never the
  bot's; on a split screen it is both cars', since both were driven, so it is
  never "how far player one has gone". Time driven is counted once per race,
  however many cars were in it.
- **An abandoned run keeps its distance and nothing else**, for the reason a
  coin picked up on it stays in the purse: it was driven.
- **The endless course counts.** Every course crossed is a completed race, so
  that count climbs steadily there, and nothing on it is ever a win.
- **Chaos counts.** A chaos race is still driving.
- **Coins earned is coins ever picked up**, counted beside the purse at the
  moment one is driven through. It is not what is in the purse: the two part
  company the first time anything is bought, and the purse is the shop's number.
- **The title screen counts nothing.** Its moving backdrop is the two-player
  scene in attract mode, and every call into `Stats` there is gated on that
  mode, not on its cars happening to be parked. Coins are the exception: like
  the purse, they are kept off the title only by its cars being parked, and
  the check below watches that too.
- **Nothing goes to the server.** A time means the same thing on every
  machine; a lifetime total does not, and syncing one would need a rule for
  merging every counter.

Distances are metres under a kilometre and kilometres to one decimal after.
There are no miles, because the game has no units setting to follow.

### Writing it down

Every call saves what it changed, except distance, which moves every physics
step. Sixty writes a second would grind the disk for nothing, so distance and
time driven are held in memory and flushed when a result is announced, when
the pause screen opens, when a run is quit or restarted, from the race scene's
`_exit_tree()`, when the window is asked to close, and after every five
seconds of driving whatever else happens. A hard kill loses at most those five
seconds. A damaged file loads as zeros wherever it makes no sense - a missing
key, a word, a negative, a nan - and never as more wins than races, so nothing
a file says can put `-nan KM` on the page.

### Checking it

`tools/checks/stats.gd` is the store on its own: a fresh profile is all zeros,
each call moves what it names and nothing else, the totals survive being read
back, `forget()` clears them, damaged files load as zeros, and held distance is
on the disk after each flush the store owns.

```
Godot --path . --headless --script tools/checks/stats.gd
```

`tools/checks/stats_race.gd` drives real races and says what each one should
have moved: a time trial to the flag, one broken down, the reset key against
the bot's reset, a run restarted and one left halfway, a bot race won, lost and
broken down all three ways, two-player courses won, broken and drawn - and the
title screen's backdrop, left alone for four seconds and then let go with the
throttles held, counting nothing either time.

```
Godot --path . --headless --fixed-fps 60 --script tools/checks/stats_race.gd
```

`tools/checks/stats_shot.gd` walks to the page from the track screen and
photographs it empty, full, and with damage on, then backs out with Escape and
checks the keyboard landed back on the button - then does the same from the
settings on the title, where Escape has to step back to the settings first and
only close them on the second press. `screen_fit.gd` opens the page
both empty and full, since the full one is the taller.

```
Godot --path . --script tools/checks/stats_shot.gd -- /tmp/shots
```

## Accounts

`Backend` is the game's one door out to the internet, and the only script in it
that touches HTTP. Everything above it is written as though the server always
answers, because this is where that is made true: every call can be awaited,
every call comes back with something even when the request failed, and no
screen waits on one before it will draw.

Nothing here may stop the game. A player with no account drives every track,
keeps every time and earns every medal; a player on a plane drives the same
game as a player at home and simply does it without a board on the wall. That
is not politeness, it is the reason `TrackTimes` stays the truth the game is
played against and all of this sits above it rather than underneath.

Passwords pass through and are never kept. They go to the server over HTTPS in
the one request that checks them, and what comes back - a token that expires
and can be revoked - is what gets written down, in `user://session.cfg`, so
signing in is something a player does once rather than every time they open the
game. A token about to expire is swapped for a new one before the request that
needed it goes out, because a call that sets off valid and arrives expired
fails for no reason a player could understand. A refresh the server refuses
signs this machine out; a refresh that merely could not be sent leaves the
session alone, because nobody should be thrown out of their account by a
dropped wifi connection.

Which server, and its public key, live in `backend.cfg`, which is not committed
- it is yours rather than the game's, and `backend.example.cfg` says what goes
in it. The key is meant to ship: it identifies the project rather than the
player, and what stops one player writing over another's time is the row level
security on the tables, not this key being secret.

The account screen is two pages wearing one frame - signing in and signing up
differ by one field and one button - so it is built in code rather than written
into the scene, the same way the track grid and the controls sheet are.

## Leaderboards

`Leaderboard` sends what was driven up and brings back what was driven
elsewhere. It listens for `TrackTimes.beaten`, so a finished run posts itself
without the race scene knowing anything about a network, and the result screen
never waits on the answer.

A board is only ever the times set on this exact version of a track, by cars
tuned the way these ones are - that is what the signature settles. Change a
corner on track seven and its board empties rather than mixing two different
roads, which is the same rule the local record already lived by, applied to
everybody at once.

Every finish is sent as an upsert, because the game does not know and should
not have to know whether this player has been here before. Whether it is an
improvement is the server's business: it is the one holding the record, and it
is the only one whose answer cannot be edited by whoever is holding the
keyboard. A trigger returns the old row when the new time is not faster, so a
slower lap is accepted and quietly changes nothing.

A time that could not be sent is not lost. It goes to an outbox in `user://`
and is tried again the next time the game finds a network and an account, which
is what makes a week of driving on a train arrive all at once rather than not
at all. The outbox is drained before anything is read back, so nothing is
pulled down that is about to be beaten by something already waiting to go up.

Signing in pulls everything the player has on the server into the local record,
and pushes up anything better that was set here before the account existed.
That is the backup half: reinstall the game, or open it on another machine, and
twenty best laps are where they were left.

Every way of driving a track has a board of its own, kept under the track's key
with the way on the end, exactly as its time is (see [Track times](#track-times)).
Pulling a player's times down on sign-in splits the key back into the track
and the way, so a mirrored time comes back as a mirrored time.

Reading a board works signed out, deliberately. Somebody deciding whether an
account is worth making should be able to see what they would be joining, and a
board that demands a sign-in before it will show you anything is a board with
nobody on it.

The whole server side is `backend/schema.sql`: two tables, a trigger, the
policies and the grants. Both gates matter and it is easy to open only one - a
policy says which rows a role may touch, a grant says whether it may touch the
table at all, and careful policies with no grants is a table nobody can read.
`anon` may read; `authenticated` may read and write its own rows; nobody may
delete, which is the missing delete policy and the withheld privilege agreeing
with each other.

What none of it can do is tell whether a time was actually driven. The game
runs on the player's machine, so a determined person can send whatever number
they like under their own name, and there is a floor here only against the
absurd. Proving a lap happened means sending the inputs and replaying them on
the server, which is a much larger piece of work than this and is not what this
is. For a board among people who know each other that is usually fine.

## Medals

Every track sets what a lap of it is worth - gold, silver and bronze in
seconds - in its own file, next to its corners. What counts as a good lap is a
fact about the road rather than a number that could be worked out from one: a
wide open kilometre and a kilometre of hairpins are not the same thirty-three
seconds. First Light asks for 33, 38 and 42.

```gdscript
medals(33.0, 38.0, 42.0)
```

A target is a time to get under, not a time to match. 32.99 is gold and 33.00
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

A way of driving a track that is a different road has targets of its own,
measured rather than guessed - see [Where the numbers come
from](#where-the-numbers-come-from). A mirrored lap is worth what the track's
is, since it is the same lap turned round, so Mirror shares the track's.
Reverse's are in `TrackVariant.TARGETS`, and a way with no row there, like Hard
and track chaos for now, has a time and a board and no medals.

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

### Where the numbers come from

A target has to be a fact about the road, which means driving it.
`tools/lap_times.gd` points the same crude driver `solo_run` uses at all twenty
tracks in turn and times each one:

```
Godot --path . --headless --fixed-fps 60 --script tools/lap_times.gd
```

The lap it drives is a bad one - flat out, aimed fourteen metres ahead on the
centreline, giving back speed wherever that point is not straight in front of
it - and on the harder tracks it does not finish at all, because driving the
centreline into a slalom is driving into a barrier. What makes it useful is
that it is the same bad lap everywhere: on First Light it comes home in 34.85,
against the 33 the track asks for gold. Gold is a little under the best the
road allows, silver and bronze are spaced further apart the harder the track
gets, and the whole ladder is set from that one ratio.

A way of driving a track that is a different road has targets of its own, and
those are measured against the track rather than from nothing. Given a
variant, the tool drives each normal track that offers it twice, as written and
then that way, and stretches the track's ladder by the ratio of the two laps:

```
Godot --path . --headless --fixed-fps 60 --script tools/lap_times.gd -- reverse
```

Those two laps are the game's own bot's rather than the crude driver's, which
does not finish half the tracks, and a ratio needs both laps. A lap the bot
was put back during is left out, since it would be measuring the put-back as
much as the road. See *Track variants* for what each way's targets are.

## The bot

`BotDriver` ([scripts/bot_driver.gd](scripts/bot_driver.gd)) drives a car the
way a player does: it asks for throttle, brake and so much lock, and nothing
else. A car is handed one as its `driver`, and asks it every step for what the
keys would otherwise have said. Everything the car does with that - the easing
on the wheel, the grip, the ceiling on its speed - is the same sums a keyboard
goes through, which is the whole of what stops the bot being quicker than the
car it is in. It cannot set its speed or turn its body. A bot that is too slow
has to find a better line, not a bigger engine, and one that is too quick for
a player cannot have been given one either.

It drives in three stages, all worked out from the road and the car when it is
made, so nothing is written down anywhere to go stale when a track or the car
is retuned.

**The line.** The road is sampled every 2.5 m. Every barrier that stands still
narrows it to the gap the bot means to take - held for as long as a car
alongside it would be alongside it, half a car length either side - and every
pad worth taking narrows it to the pad. A fork's lane is held from where the
blocking starts to the end of it, since a car that changed its mind halfway
down a seventy-metre divider would choose the divider. The line is then relaxed
inside those limits until it bends as little as it can, which is what a racing
line is: wide in, clip the inside, wide out. Traps move, so they are left out of
the line and dodged on the day, from where the race clock says they will be when
the car gets there.

**Which lane of a fork** is not chosen, it is driven. A fork is the one place on
a road where the line has a choice rather than a best - a fast lane with a pad
in it and a row or two of barriers to thread, against a clear lane with neither
- and which of them is quicker is not something to read off the shape of them.
The pad is worth more than the barriers cost on a wide road and less on a narrow
one; it is worth more into a long straight than into a corner the car was going
to brake for anyway; and what the barriers cost depends on whether this car can
thread them at the speed it arrives, which is a question about the car rather
than about the road.

So each lane is planned and timed in turn: the road narrowed to that lane, the
line relaxed into it over the fork and its run in, and a copy of the car driven
from forty metres before the split to two hundred after it - far enough after
that a pad taken in the fast lane has faded before the clock stops, because a
boost carried out of a fork is most of what a fast lane is for. The quicker of
the two is the one the plan keeps, with the room and the line it was driven on
rather than planned again from the start.

A lane is mended between goes the way a practice lap is: where the copy could
not hold the line it is given room there, and where room has already been tried
the stretch before it is taken slower, up to six times. Without that the two
lanes are not being compared at all - the clear one needs no mending and the one
with the barriers in it does, so the fast lane was being charged for a line the
practice laps were going to mend anyway, and it lost every fork on every course
in the game. A lane that still cannot be held after all six is charged the car's
own `obstacle_scrub` for each time it could not, because what the copy has just
done is drive into a barrier; and between a lane that comes out clean and one
that does not, the clean one wins whatever the clock said.

Across the twenty tracks and the two bot roads that comes out fifteen forks
taken down the pad's lane and eleven down the clear one, which is the choice
actually being made rather than the pad always winning it. It is worth about
half a percent of the bot's time against gold, and much more than that in
places: The Wringer and Last Light are three and a half seconds quicker for it,
First Light a second and a quarter.

**The speeds.** What each bend allows is the car's own answer turned round:
`Car.turn_radius_at()` says what circle a speed can hold, so a bend of radius r
allows the speed that comes out at r. Past `fast_turn_radius` a bend is no limit
at all - the car's circle stops growing at top speed, boosted or not - so a pad
carried into a gentle bend is kept. The limits are then walked back from every
bend at the car's braking, so it slows before the corner rather than in it.

**Practice.** A line that bends no tighter than the car can hold is not yet a
line the car can follow. The lock takes a moment to come on and the grip a
moment more to take the travel round with it, so a line that swings across the
road past a row of barriers asks for a car that has already turned. That cost
cannot be read off the shape of the line, so the bot finds it out the way a
player does: it drives a lap on a copy of the car, through `Car.rehearse()`,
which is the car's own steering and throttle and nothing of the world. Where
the copy's box - its real length and width, at its real angle - would overlap a
barrier, or its middle would leave the road, the line is given more room on
that side there; where that has already been tried, the stretch before it is
taken a little slower too. It stops at a clean lap, or after eight. A lap of
practice costs a tenth of a second, because the copy is never in the physics
world, and most tracks are clean in two to four.

Moving the line comes first on purpose. A line that crosses a gap at an angle
clips the barrier with the corner of the car at any speed, and when slowing was
the only answer practice took First Light's fork down to half speed and still
hit the barrier.

**Driving it.** The line is followed rather than chased. The first driver
aimed at a point further down the line, which is the obvious thing to do, and
cuts every bend by about as far ahead as it looks - through a gap a hand's
width wider than the car that is a barrier. So the bot steers for the line's
own bend where the car is, and on top of that turns back towards the line at an
angle that closes how far off it is in under half a second. It steers from where
the car will be a sixth of a second from now, turning as hard as the wheel has
actually got to, because a driver steering for where the car is now is steering
a car that has already moved on. The throttle holds the car under what the line
allows over the next fifth of a second; over it, it brakes.

If the car goes nowhere for three seconds, or sits off the road for two, the
bot says it would press the reset key, and whatever is running the race does
what it does for the key. It is not the bot's to put itself anywhere.

**The other car,** where there is one, is three things at once: something to be
towed by, something to go round, and something not to drive into. All three are
decided from where the bot's car actually is rather than from where its line
says it should be - a bot sitting in somebody's tow is by definition off its own
line, and one that asked the line would work out that the car ahead was three
metres away and steer straight through it.

*The tow.* From difficulty 0.5, on a straight, between four and twenty-two
metres back, the bot sits on the other car's line to be towed down it. It asks
for more than a straight before it does: no barrier may hem the line in
anywhere over the next thirty metres, and the other car's line has to be inside
the room the plan left itself all the way down. Those two were what was missing.
A bot that only asked whether the road was straight tucked in behind a car
heading for a gap it had not chosen, and arrived at the barrier row off its own
line with no time left to cross back - which on The Gate lost it the race rather
than won it one.

*Going round.* Within about eleven metres the bot moves off its line to come
alongside. The line is moved, not replaced: it keeps its own line wherever that
is already clear of the other car, and is pushed off it only by as far as two
cars side by side need. How far that is grows with how much each car is turned,
because a car is twice as long as it is wide and one at an angle reaches further
across the road than its width - the same thing the practice laps know about
barriers. A side once taken is held until the bot is a car and a half past the
other one's tail, because the room either side changes as it moves into one of
them; and only a side the bot can reach without going through the other car
counts, which from alongside is the side it is already on.

*Not driving into it.* When there is nowhere to go round - a fork, a row of
barriers, a corner the road pinches - the bot holds back instead. The speed that
leaves is the same sum the line's own limits are walked back with, what the car
can brake off in the road it has, against the other car's speed instead of a
corner's. It settles about three metres of clear air behind, which is near
enough for nearly the whole tow. The decision to give way is sticky: two cars
level with each other where only one fits will otherwise each wait for the other
to yield, and the one that changes its mind every step is the one that does not.
Which of them yields is settled by which of them is behind, so this asks nothing
of the car in front and the driver in front asks nothing of this one.

None of this is on the plan. The practice laps are driven with the other car
unseen, because where it happens to be standing during the countdown is not a
thing the line round the track should have been bent for.

**When it is worked out.** All of the above is about half a second of work on a
short road and a second and a half on Last Light - and nearly all of that is the
two relaxings, which are over a thousand sweeps of the whole line between them.
The practice laps are the rest: about 40 ms a lap on the longest road, up to
eight of them.

That is far too much for one frame, so it is not done on one. `start_planning()`
says where to begin and `plan_a_little(budget)` carries it on for about that many
milliseconds, returning whether there is more to do; `is_planned()` says when the
driver will drive, and a driver still working its line out asks for nothing and
leaves its car coasting. The budget is honoured between units of work rather than
inside them, so a call overshoots by at most the one unit it was in the middle
of - and the units are small on purpose: one relaxing sweep is under a
millisecond on the longest road in the game, and one practice step is a few
microseconds. Measured across all twenty tracks at a 4 ms budget, the worst
single call is about 5 ms, and 7.3 ms on a noisy run - a frame at 60 Hz is
16.7 ms.

A check or a tool has a frame to spare and wants none of this, so
`finish_planning()` does whatever is left on the spot, and `plan(car)` is
`start_planning()` and then that. There is one implementation underneath both, so
the spread-out plan and the all-at-once plan cannot drift apart: the same line
comes out either way, sweep for sweep and lap for lap, which `tools/checks/`
numbers confirm by being unchanged.

Everything the plan takes off the world rather than off the road - where the car
is standing, what its top speed is - is read in `start_planning()`, on that one
frame, and not as each stage reaches for it. The stages run across however many
frames the budget spreads them over, and a plan whose practice laps set off from
wherever the car had drifted to by the time the practice stage came round would
be a different plan on a different machine. A car retuned or moved part way
through a plan wants `start_planning()` called again; it is not picked up half
way.

**Difficulty** is one number from 0 to 1. It sets how near the kerb the line
runs, how much of what a bend allows it asks for, how late it brakes, and from
0.25 up whether it goes out of its way for a pad, from 0.5 whether it tucks in
behind the other car on a straight. Going round the other car and not driving
into it are not on the dial: a bot that shoves at low difficulty is not an
easier bot, it is a worse-behaved one. One number rather than a table, so it can
be turned by feel.

`tools/checks/bot_race.gd` lets the bot drive every normal track and sets its
time against the gold, which is the number that says whether "hard to beat" is
true:

```
Godot --path . --headless --fixed-fps 60 --script tools/checks/bot_race.gd
Godot --path . --headless --fixed-fps 60 --script tools/checks/bot_race.gd -- 0.5
Godot --path . --headless --fixed-fps 60 --script tools/checks/bot_race.gd -- 1.0 res://tracks/07_pinch.gd
```

It fails a track the bot does not finish, or needs putting back on more than
twice. It wants running again every time the car is retuned: the bot drives the
car as it is, and the golds do not move with it.

It plans the way a race plans, 4 ms at a time, and prints both halves of what
that costs: `plan` is the whole of it with the number of frames it took, which is
how much of a countdown a road needs, and `worst` is the longest any single one
of those calls ran. Worst is the one that decides whether a player sees a hitch,
so it is a fault over 12 ms: not the budget plus a little, because wall-clock
time on a machine doing other things wanders by two or three milliseconds, but
the point at which planning alone is in danger of costing a 16.7 ms frame. The
printed number is the signal - a regression shows up there long before it trips
the fault.

`tools/checks/bot_duel.gd` is the rest of the driver: the three decisions a lap
time on an empty road cannot see.

```
Godot --path . --headless --fixed-fps 60 --script tools/checks/bot_duel.gd
Godot --path . --headless --fixed-fps 60 --script tools/checks/bot_duel.gd -- res://tracks/bot/b2_the_toll.gd
```

Two bots rather than a bot and a scripted player, because a check has no hands.
The player's car is driven by a second `BotDriver` through the same `Car.driver`
hook the keyboard goes through, so a pass made there is a pass a player could
have been on the wrong end of.

- **The tow** is measured by driving the same car over the same stretch from the
  same place twice: once with another car ahead of it, once with the road empty
  and the other car held frozen out of the way. Two cars at once, or one car
  against a lap driven on another line, would be comparing two different drives.
  What it reports is the best the tow was ever worth against what the car says a
  slipstream is worth, and it faults under half of it. The best rather than the
  average, because a car queued behind a slower one is slower than it was alone
  whatever the tow is doing for it - that is the queue, not the tow. On The Gate
  it collects 4.8 m/s of the 6.6 the car offers.
- **The pass** is the same run read the other way: where it got by, how many
  times the two cars touched, and what it did to the car it passed. Going
  through somebody is not overtaking them, so it faults on putting the other car
  into a barrier or off the road at all, and on more than eight contacts.
- **The level race** is what a bot road actually starts: both cars at difficulty
  1, side by side on the grid. With clear road the two grid slots are worth the
  same, so the margin at the flag is what having to share the road costs the car
  that gives way. With the two drivers blind to each other the cars grind
  against one another for the whole race - eighty contacts - and finish level,
  which is not racing, it is two cars stuck together.
- **The fork** plans every road in the game and prints the time the driver
  measured for each lane and the one it kept. The thing it is really watching
  for is a timing that always comes out the same way: every fork in the game
  going down the same side is not a choice being made, it is a choice being got
  wrong the same way twenty times, which is exactly what happened the first time
  the timing was written.

## The bot race

A bot road is a race against one computer-driven car, and the door out of a
block of ten tracks. It is not a track: no time is written down on it and no
medal is earned, because the only thing it measures is which car crossed the
line first.

It is `Solo` ([scripts/solo.gd](scripts/solo.gd)) with a second car rather than
`Main` with the split collapsed. A bot race is a one-player thing, and almost
everything in `Main` is about there being two of everything - two viewports, two
cameras, two clocks, two keyboards - so collapsing it would mean a branch on
every one of those lines. What it takes in `Solo` is one more car, one arrow and
one place readout; the road, the chase camera and the HUD are the ones already
there.

**Which roads.** `TrackRoster.BOT_FILES` names them, and
`TrackRoster.is_bot_road()` is what `Solo` asks on the way in. There are two, one
at the end of each block of ten: [tracks/bot/b1_the_gate.gd](tracks/bot/b1_the_gate.gd),
The Gate, and [tracks/bot/b2_the_toll.gd](tracks/bot/b2_the_toll.gd), The Toll.
A bot race is on its own road rather than on the tenth track again, because the
tenth track is a thing the player has already learned and a door should ask for
all ten rather than one of them.

`BOT` is a third kind beside `NORMAL` and `ACROBATIC`, and the two roads hold
slots 30 and 31 - the normal tracks are 0 to 19 and the acrobatic ones 20 to 29
- so no road in the game shares a number with another. They are in no grid:
neither `NORMAL` nor `ACROBATIC` reaches them, and the leaderboard picker steps
over them for the same reason it steps over an empty slot, since no time is ever
written down on one for a board to show. They have a slot at all because
everything that looks a road up by its file goes through one, `index_of()` into
`targets()` most of all.

**Their medal targets are never shown to anyone.** A bot road keeps no time and
hands out no disc, and `Solo` leaves its targets at zero rather than reading
them. They are set the way the other twenty were, with `tools/lap_times.gd`, and
they exist for `tools/checks/bot_race.gd`: the check measures the bot against the
gold of the road it is on, and a road with no targets gives it nothing to say. A
bot road also has no thumbnail, because the select screen gives the bot cell its
own face rather than an overhead shot - `tools/track_thumbnails.gd` sweeps the
two grids rather than every road there is.

**The second car** is built in code in `_ready()` and only on a bot road. It is
not in `solo.tscn`, because the nineteen time trials and the endless course
would then all carry a car they never use - and the arrow has its physics step
turned off on those roads for the same reason. It comes off
`res://scenes/car/car.tscn`, the same scene the player's car does, and is handed
a `BotDriver` at difficulty 1. Nothing else in the scene touches it.

**It is the player's car, driven through the player's sums.** The bot sets a
throttle and a steering angle through `Car.driver` and that is the whole of what
it can do - the same two numbers a keyboard produces, going into the same
`_accelerate`, `_brake` and `_steer` the keyboard's go into. It has no speed of
its own, no grip of its own and no rubber band: `max_speed`, `gravity` and the
turn radius are read off the car it was given, and there is nowhere in
`BotDriver` that could write to them. If the bot is too easy it gets a better
line, never a bigger engine.

That is a rule about trust rather than about fairness. A bot that quietly gains
speed when the player gets ahead is the fastest way there is to make somebody
stop believing what the game shows them, and it cannot be argued with
afterwards, because the player cannot see the number that moved. The difficulty
is one number - how far ahead it looks, how much it backs off for a bend, how
hard it aims at a gap - and every one of those is a decision about where to put
the car, not about what the car is. It is undone the way it was made, in
`_exit_tree()`, driver first: the car holds the driver and the driver holds the
car, and the two cars hold each other.

**What difficulty 1 is worth,** measured rather than asserted.
`tools/checks/bot_race.gd` drives the bot over all twenty time trials and
reports each lap against that track's gold:

```
Godot --path . --headless --fixed-fps 60 --script tools/checks/bot_race.gd
Godot --path . --headless --fixed-fps 60 --script tools/checks/bot_race.gd -- 0.5
```

It comes in **+1.3% against gold on average**, from **-2.1% on The Weave** to
**+7.6% on The Gauntlet**, and it is at or under gold on nine of the twenty. It
finishes all twenty without being put back on the road once. That is the shape
a door wants: a player who can drive these roads properly is holding a time the
bot is somewhere near, so the race asks the same thing of them that the gate
just did, and neither the gate nor the race is the hard half.

Difficulty is the one dial. 0.5 is about +7%, 0 about +20%, and the race is at
1 because a door that a player scrapes past on their first try was not a door.

The two tracks the bot is furthest over on - The Gauntlet at +7.6% and First
Light at +4.0% - are the two with the most slalom in them, and that is a fact
about the targets rather than about the driver: see **Where the numbers come
from**, because the driver those golds were set with turns the car's body at a
flat rate no real car can manage, which buys it most exactly where the road
changes direction most.

**The Wringer used to be the outlier at +30.3%,** and it was not the bot. The
car was jamming partway up the track's first ramp - on the floor, reading full
speed, going nowhere - and needed putting back on the road to get round at all.
The cause was the ramp's own profile and it is written up under **Jumps**; with
it fixed The Wringer comes in at +4.2% and Long Haul, which had begun to meet
the same thing, at -1.1%. The average was +3.0% with that one track in it.

**The driver comes after the grid,** not with the car. A plan's practice laps set
off from wherever the car is standing when the plan begins, so the car has to be
on the line first or the bot spends its practice driving from wherever a freshly
built car happened to land. It used to be built with the car, and the bot was
half a second a lap slower on The Gate for it.

**The line is worked out across the countdown.** Working it out is about half a
second on The Gate, which on one frame is a visible hitch at the exact moment the
player is watching a countdown - so `_process` carries it on `plan_budget_ms`
(4 ms) at a time, and the countdown is what it is spent in. The countdown is
three seconds of nothing else happening, and The Gate's line is finished in two
of them.

Over a thread, which would have been quicker: the practice laps drive a duplicate
of the car, and duplicating and freeing a node belongs to the main thread; the
plan is also read off a `Curve3D` whose baked cache is built the first time it is
asked for. A thread would mean either proving all of that safe or taking the copy
out of practice, and it would buy nothing a player could see, because the
countdown is dead time either way. The frame budget uses time that was already
being thrown away.

A road whose line takes longer than its countdown **holds the count** rather than
dropping a frame: `_start_after_countdown()` will not say GO until
`is_planned()`, and `_process` goes on planning a few milliseconds a frame while
it waits. That is the safety net, not the plan - at 4 ms a frame the countdown
covers a line up to about 700 ms of work, and a bot road wanting much more than
that is a bot road to shorten. `tools/checks/bot_race.gd` prints what each road
costs, so an author can see it before a player feels it.

**The bot is told the time** every physics step, before the cars move, the same
way the track is. The traps run on the race clock, and a bot that does not know
the clock drives into them.

**Being put back** is the bot's to ask for and the race's to do, exactly as it is
for the player: `BotDriver.wants_reset()` goes down the same
`_back_to_checkpoint()` the reset key does, and `reset_progress()` tells the
driver afterwards, or it goes on driving as though it were still where it was.
The bot has its own respawn point and its own banked checkpoints, because two
cars on one road are two runs and a checkpoint one of them drove over is not one
the other did. The rings, where a road has them, are put out only for the
player: both cars are looking at the same rings, and one going dark because the
bot flew through it would be reading out the wrong run.

**The paint is fixed** at one amber, not `GameSettings.car_colour(1)`. The bot is
not player two - it is the same rival on every bot road, and one wearing whatever
colour the second keyboard last chose would be a different car each time. Amber
because it holds up against every sky the game has: nowhere near the grass or the
tarmac, it does not sink into a sunset the way navy does, and it does not wash
out at noon the way white does. It is in the stock car for the same reason, so
the rival is not whatever model the player last imported.

**The rest is the race's own machinery, reused.** `CarContact` settles the two
cars shoving each other rather than passing through. `car.rival` is wired both
ways, or the slipstream works for neither of them. One `RivalArrow` points from
the player's car at the bot, on the world's own visual layer: there is one camera
here, so none of `Main`'s per-player culling is wanted. The 1st/2nd readout runs
on `Places` ([scripts/places.gd](scripts/places.gd)), which is the rule the
two-player race uses as well - a lead has to be earned by `lead_margin` and only
a clear return to inside `level_margin` gives it up, so it cannot strobe wheel to
wheel, and one rule in one place cannot show the same two cars different places
in different modes.

**Winning and losing.** The race ends when either car crosses the line, and the
panel a time trial hangs a medal on carries the verdict instead: the time, who
won, and by how much. By how much is a distance and not a time, because the clock
stopped when the first car crossed - the other one has not finished, and how long
it would have taken is not something the race knows. The road it still had is the
one true measure of the gap at that moment. No medal is hung: there is no time
kept on a bot road for one to be worth. With damage on, a broken car ends the
race and the other one wins without driving the rest of the road, and both
breaking on one step is a draw. The two ways out are RACE AGAIN and BACK TO
TRACKS; there is no next track from a door.

`tools/checks/bot_road.gd` drives the race:

```
Godot --path . --headless --fixed-fps 60 --script tools/checks/bot_road.gd
```

It checks that a time trial builds no second car, that the two start side by
side knowing about each other, that either crossing the line ends it and says
so, that a broken car ends it the other way round, that putting the bot back
moves nothing but the bot, and that nothing about any of it reaches
`TrackTimes`. It also checks that the bot's line is genuinely spread - still
unfinished on the frame the scene opens, and finished before the cars are let go.

On The Gate at difficulty 1 the two grid slots are level with clear road, 42.43 s
and 42.42 s, and in a race the player wins by about 50 m: the bot gets squeezed
onto the barrier row at the exit of the first corner, which is what a row on the
outside of a corner exit is for, and is the first time `BotDriver`'s
going-round-the-other-car has been driven rather than only written.

## The medal gate

The twenty tracks are two blocks of ten, and a block is shut until the race at
the end of the block before it has been won. Standing in front of that race is
the gate: **five golds among the ten in front of it**, or it will not start.

**Five of ten, not ten of ten.** Finishing ten tracks is not the same as being
able to drive them. A player who scraped a bronze on all ten and walks into a
race against a fast bot loses, repeatedly, with no idea what to change - so the
gate asks for something that means "you have driven half of these properly"
rather than something that means "you have been here". Ten of ten would be a
different thing: it would ask a player to like every one of the ten, and a
player may simply hate track seven. Five is where a run of golds stops being
luck and has not yet become a completion list. It is one named constant,
`Progress.GOLDS_NEEDED`, because it is a tuning number and it will be argued
about; an argument about it should be an argument about that line.

**The golds buy the race, not the ten behind it.** They are two separate
things in the way, and they come in order: the medals earn the right to start
the race, and winning the race opens the next ten. A player who has five golds
and has not driven the race sees the door open and the block behind it still
shut, and the tooltip on a shut cell says which of the two is missing rather
than saying "locked" at them.

**Nothing about a medal is stored, and that is the point.** `Progress` writes
down which races have been won and nothing else - `user://progress.cfg` is a
section per block with `won=true` in it. `golds_in()` counts the block's ten
afresh every time it is asked, out of `TrackTimes.best()` and
`TrackRoster.targets()` through `Medal.earned()`, the same three calls the
select screen uses to colour a cell. So moving a gold target moves every gate
that leaned on it at once, in the same run, with nothing to invalidate and
nothing to migrate: pull a target in under a standing lap and the gate is shut
again the next time anything asks. A remembered count would be a second copy of
a number that already exists, and the two would disagree the first time
anybody tuned a track. It costs a few file reads on a screen that is being
drawn anyway.

**Only the tracks as written count.** `golds_in()` asks `TrackTimes.best()`
with no way named, which is the track as written. A gold mirrored, reversed or
on Hard is its own gold on its own road, and shows as one, but it opens
nothing. The gate asks whether a player has driven half of these properly, and
a mirror gold on a track already golded is the same driving counted twice.
`tools/checks/progress.gd` sets golds on other ways and checks the gate stays
shut.

**Acrobatic tracks are not gated.** They are a different thing to drive, in
their own grid, and a player who cannot find five golds among the first ten
should still be free to go and fly through some rings. `golds_in()` skips
anything that is not a `NORMAL` slot, which matters because the acrobatic slots
carry on from the same numbering - a block that ran into them would be asking a
player for golds on roads no gate has ever mentioned.

### Three states on a cell

Locked is a third state, and it has to look different from both of the others.
A built track a player may not drive yet and a track that does not exist are
not the same thing, and showing them alike tells a player the game is
unfinished when in fact they are.

- **Open** - the name, the overhead shot, the medal bar and the time.
- **Shut** - the same cell with its picture dimmed to a quarter and a padlock
  drawn over it, framed in the gate's amber rather than the pale outline of an
  empty slot. The name stays white: the name is the one part of the track that
  is not being withheld, and a grey name is how this page says "not built". The
  tooltip says exactly what to go and do - `5 GOLD IN 1-10, you have 3` - and
  never the word "locked" on its own, because a door that says only that it is
  shut tells a player to give up, where the same door saying how far off they
  are tells them where to go.
- **Not built yet** - the existing dark outlined frame, with the slot's number
  over it and no time under it. Unchanged.

The padlock is drawn with `draw_arc` and `draw_rect` rather than set in a font
or shipped as a picture. A glyph is a lock only if the font on the machine has
one, and a font that does not draws a hollow box - which over a greyed picture
reads as something broken rather than as something shut, which is the exact
wrong thing for that cell to say.

### The door

The bot race gets a cell of its own at the end of each block: a strip the full
width of the page, not a sixth cell in a row of five. It is not a track - no
overhead shot, no medal bar, no time - and standing it in the grid would make
it read as one. The grid of twenty is therefore two grids of ten with a door
between and after them, which is also what keeps every track cell in the
five-column alignment it always had; ten to a block at five across is exactly
two rows.

It says which of the three it is in words, because a strip that wide has room
for the sentence: `THE GATE   5 GOLD IN 1-10, you have 3` in grey when it is
shut, `THE GATE   RACE THE BOT` in the bot's own amber when it can be driven,
and `THE GATE   WON` in green once it has been. It wears the amber the bot's
car is painted, because the thing that opens all of this is beating that car.

Focus across the seams is wired by hand. Godot works out where the keyboard
goes next from where things are on the screen, which is right inside a grid and
no use at a seam: a door sits in a container of its own, and the search walked
straight past it and off the page - down off the last row of the first ten
landed on the title screen behind it.

Pressing a door sets `GameSettings.track_file` to that block's bot road and
changes scene the way pressing a track does. `_scene_for_the_players()` sends a
bot road to `Solo` whatever the question at the top of the page was answered
with: a bot race is one player against one computer, and the second car on that
road is the thing being raced, so there is no seat in it for a second player.

Nothing listens to `Progress.changed` on the select screen, and the difference
from `Leaderboard.times_changed` next to it is worth writing down. A time can
move while the screen is up, because the sync runs underneath it. A race cannot
be won while it is up: a race is a scene of its own, and coming back from one
builds this screen again from nothing. A player who wins and comes back finds
the next ten open because the grid was built afresh, not because anything told
it.

### The checks

`tools/checks/progress.gd` pushes on the gate itself:

```
Godot --path . --headless --script tools/checks/progress.gd
```

It walks the golds from none to one past what the gate asks for and reports
which count it opened on, so an off-by-one names itself; it wins a race and
checks that exactly one block opened and the acrobatic tracks did not; it
closes the game and opens it again; and it checks that a time on another road,
or one set on a road that has been redrawn since, never counted. The case that
matters most is the one that moves a gold target in memory, asks the same
question on either side of the move, and puts it back: that is what would fail
the day anything started remembering a count instead of working it out. Every
boundary is written against `GOLDS_NEEDED` and `BLOCK` rather than the five and
the ten they happen to be, so retuning the gate moves the check with it instead
of leaving it testing the wrong edge and passing anyway.

`tools/checks/track_select.gd` is where the three states are checked on the
screen, counting the cells across the blocks rather than off one grid.

```
Godot --path . --headless --script tools/checks/track_select.gd
```

## Coins

Gold discs standing a metre above the road, taken by driving through them and
spent in [the shop](#the-shop). Every course carries between **5 and 15**, rolled per
course.

A coin is furniture, so it is planned by the thing that plans furniture and
built by the thing that builds it: `TrackFeatures.COIN` is a fourth kind of
placement beside the pads, the barriers and the traps, and `TrackFurniture`
turns it into an `Area3D` with a disc inside it. It is closest to a boost pad -
something that fires once when a car drives into it - without the speed.

It is also the only piece of furniture that has no opinion about how the course
drives. Nothing is blocked by one, nothing is landed on one, and none of the
rules about whether a barrier can be got past look at one. That is what lets
the coins go down last, over whatever road the rest of the plan left, in a pass
of their own.

### Where they go

`scatter_coins` runs after everything else, seeded separately from the course.
Separately on purpose: rolling the coins out of the course's own generator
would move every roll after it, and every course in the game would have come
out different the day coins were turned on.

Coins obey the same `keep_out` the pads do - `pad_keep_out` (20 m) from the
grid, the finish and every respawn - because a coin picked up for being put
back on the road is not a coin anybody earned. They are never in the hole of a
jump, never over the kerb, never inside a barrier, a kicker or a platform, and
never anywhere a trap passes through in any phase, which is checked against the
whole sweep rather than against the places it rests.

Two rules are about the car rather than the plan. A coin has to sit inside one
of the ways past whatever stands at its own offset, or it is money behind a
wall. And it has to sit inside the way past every row standing within
`coin_run_up` (14 m) ahead of it, because a coin lined up with a barrier a few
metres past it is not an offer, it is bait: a car that went for it has already
committed to the line it is about to hit.

Where they go inside all of that is a weighted draw rather than a uniform one.
A coin in the middle of an empty straight is not a decision - it is a pickup on
the line the car was already on. So the course is walked every `coin_step`
(4 m), each offset offers at most one place, and the interesting ones are drawn
from far more often:

| Where | Weight |
| --- | --- |
| The fast lane of the fork | 5.0 |
| The gap just past a row of barriers, 5-16 m on | 4.0 |
| The outside line of a corner | 2.5 |
| Open road, anywhere across it | 0.6 |

Only the fast lane of a fork, never the clear side: a coin over there would pay
a player for giving the fork's choice a miss, which is the one thing that set
piece exists to make cost something. And only rows that stand still count as
"just past a barrier" - the way past a trap is somewhere else a second later,
so a coin left in one is a coin in the middle of the road.

Over a hundred courses that comes out at about 15% in a fork, 10% just past a
row, 42% on a corner and 33% on open road.

The coins are packed closer rather than left off if a course cannot hold them
`min_coin_spacing` (18 m) apart - a short course, or one that is mostly jump
and checkpoint, still owes the player five. A course with four coins on it
would be a shop that is quietly slower to reach and nobody would ever know why.

Laid-out tracks get the same pass. What a track file says is on the road is
what is on it, and that is what `TrackFeatures.adopt` is for - but a coin is
not part of what a track file describes. It is not a corner to be driven or a
barrier to be got past, it is loose change on somebody else's road. An authored
track's coins are seeded off its own name, so a track always has them in the
same places: a player who drove it yesterday and knows where they are is
remembering the road, which is the whole point of a road worth learning. High
roads get none - one there would be change the course's own count knows nothing
about, and a player who took the kicker would be paid twice for it.

### Taking one

Driving through a coin banks it, once, for both players. It is one coin:
whoever reaches it first has it, and what the other one sees is an empty piece
of road, which is exactly what it is.

It is banked in the furniture, at the moment the car drives into it, rather
than handed to whichever scene is running the race. Two scenes run races today
and there will be more, and a coin that paid in one of them and quietly did not
in another is the kind of bug nobody reports because nobody can see it. It also
settles what happens to a run that is given up halfway: **a coin taken on an
abandoned run still counts**, because the coins were already in the purse and
there was never anywhere else for them to be. Keeping a run's coins in escrow
until the flag would punish exactly the players who are struggling, and the
purse is not a score.

Three things happen when one is taken, because a pickup with no feedback reads
as a bug - a thing that was there is suddenly not there. The coin lifts
`coin_take_rise` (1.7 m) and fades out over `coin_take_seconds` (0.5 s); a small
`+1` goes up beside it, off to one side rather than through the middle of it;
and the tally in the corner ticks.

### What it looks like

The disc faces the way a car arrives from rather than lying flat on the road,
because a thing to be driven through has to be seen from the run up, and it
turns slowly about the upright so that it flashes from a full face to an edge
and back. It is gold and lit hard, like the pads and the rings, because half of
every race is at night.

It also **leans** `coin_lean` (26 degrees) out of upright, so the axis it turns
about is a cone rather than the upright itself. Without that, a coin a quarter
turn from facing the driver is edge on, and edge on it is a line 14 cm wide -
invisible, for about a third of a second, which at thirty metres a second is
ten metres of road. Leaned over, the worst it ever shows is an ellipse that far
off the full face.

The coins turn on the race clock, the same one the traps sweep on: two players
on a split screen should be looking at the same coin at the same angle, and a
race put back on the line should put them back where they were. Each one starts
at its own angle, taken from where it sits on the course, so a course does not
flash all over at once like a row of indicators.

### The purse

`Purse` is an autoload, saved to `user://purse.cfg`: how many coins there are
and what has been bought - the count in one section, and a section per item
bought, so that what an item has to its name can grow without moving what is
already written down. It is kept apart from `GameSettings` for the reason
`TrackTimes` is - a setting is something a player chose and can change back,
and a coin is something that happened - and apart from `TrackTimes` as well,
because a time belongs to a track and a coin belongs to nobody in particular.

One purse for the whole game rather than one each. Two people on a split screen
are sharing a keyboard and a machine, and the shop they are saving for is the
machine's. Splitting it would turn every race into a squabble about who got to
the coin first, which is not the game this is. On a split screen both halves
show the same number, which is not a mistake: they are saving up together.

There is no server behind any of this and nothing here is worth protecting. A
player who wants to open `purse.cfg` and write a bigger number in it has
already bought the thing, so there is no checksum, no obfuscation and no second
copy of the count to disagree with the first. That is the opposite of times,
which go to a shared board and are constrained in the database - see
`backend/schema.sql`.

`PurseTally` draws the total: one gold disc and one number, small, in the
corner of a race and over the buttons on the title screen. Drawn rather than
written, because the thing it is counting is a gold disc and a player should
not have to read a word to know that. It swells and settles when a coin goes in
- without that, a pickup on the road and a number in the corner are two things
a player has to connect for themselves - and it does not tick for spending,
which is something they did deliberately on a screen of its own. On the title
it sits against the column of buttons rather than off in a corner, because the
shop that spends it belongs in that column.

Both `TrackFurniture` and `PurseTally` find the purse off the tree rather than
naming it. `Purse` is an autoload and those two are `class_name` scripts, and
the two do not mix: every check under `tools/` is a `--script` run, which
compiles those files and everything they depend on before the autoloads exist,
and a bare `Purse` in either fails to compile every one of them.

### Under chaos

Chaos rerolls where the coins are, because it rerolls the road they are on. It
does not reroll how many there are: the 5-15 roll is the same with chaos on and
off. A chaos run that also paid better would be the efficient way to farm
rather than a different race, and the shop would end up priced against a mode
instead of against a game.

### Checking it

`tools/checks/coins.gd` is the whole of it. It exercises the purse on its own -
what goes in comes out, what is spent is gone, nothing is bought twice, and it
all survives being written down and read back. It lays out a hundred courses
and holds every coin on them to every rule above, counting where they landed so
that the weighting failing quietly shows up as a number. It builds every
laid-out track, checks the count on each, checks that laying the same track out
twice puts the coins in the same places, and checks that no high road carries
any. Then it drives a car into a real coin: through it once for one coin,
leaves it sitting there to see that a coin does not pay for as long as a car is
inside it, drives away and back through the same coin for still one coin, parks
alongside for none, and generates a fresh course to see that the new coins pay.
Last it rolls a run of chaos worlds and counts those.

It cannot touch the player's own purse: every check under `tools/` is
sandboxed, so what it banks goes to a purse of its own. See `Sandbox`.

```
Godot --path . --headless --fixed-fps 60 --script tools/checks/coins.gd
```

`tools/checks/coin_shot.gd` looks at a coin from the car's own view, by day and
at night, caught at the worst angle it ever turns to, and again a moment after
it has been taken:

```
Godot --path . --script tools/checks/coin_shot.gd -- /tmp/shots
```

## The shop

`scenes/shop.tscn` over the title, reached from the Shop button under Garage.
Every price is in one table in one file - `scripts/shop.gd` - so balancing the
game is editing the numbers at the top of that and nothing else. The screen
shows the table and `Purse` takes the coins; neither of them holds a price of
its own.

`Shop` is deliberately not an autoload. It is a table, it never changes while
the game is running, and a check that wants to read a price should not have to
stand half the game up first. `Purse` is an autoload because it is state; this
is the opposite of state, which is also what lets `tools/checks/shop.gd` name
it in a `--script` run where no autoload exists yet.

### What it sells, and what it must never sell

**Nothing that changes how a car drives.** Not speed, not grip, not
acceleration, not damage. Every time on every board was set in the same car,
and that is the only reason the leaderboard means anything - a shop that sold a
faster car would end it. This is written down here and again at the top of
`scripts/shop.gd` because selling an upgrade is the obvious next feature to
whoever picks this up, and it is the one thing this shop must never do.

What it sells today is **paint**: six colours at **20 coins** each, `SAND`,
`RUST`, `OLIVE`, `SLATE`, `PLUM` and `ICE`.

Twenty is priced against the customisation slot at 50 (see
[Car customisation](#car-customisation)): a paint is a smaller thing than the
whole slot, so it sits well under it. A course carries 5 to 15 coins, so
twenty is two or three courses of picking them up - long enough that the first
one is something a player saved for, short enough that it arrives on the first
evening rather than the third.

The six are appended to `Paints.COLOURS` after the free twelve, with `FREE`
marking where the halves meet. They are appended rather than mixed in so that
every colour keeps the slot it has always had - `Paints.DEFAULTS` is a slot
number, and so is everything a check writes down.

**The twelve that came with the game stay free.** Selling those would be taking
something away rather than adding anything. And the six are deliberately not
more of the same: the twelve are the wheel, picked to read against tarmac,
grass and a night sky, and the six are the muted shades off it that no amount
of going round a wheel arrives at. A player who buys one gets a colour the game
did not have, not a thirteenth angle on one it did.

A sold paint is written into the purse under its **name** - `bought_paint_sand`
- rather than under its slot. `purse.cfg` has nothing in it worth protecting
(see [The purse](#the-purse)), so it may as well be a file that reads. The cost
is that renaming a paint gives it back to the shop: a player who owned SAND and
finds it called SANDSTONE owns nothing. Rename a paint and the old name belongs
to the old name for ever.

It also sells **the customisation slot** at 50 coins, which is the anchor the
paint price was set against and which opens the garage's decoration tab - see
[Car customisation](#car-customisation). It sits first in the table, because a
player reading down a price list should meet the thing that changes what the
game lets them do before they meet the sixth shade of grey.

One kind of stock is designed and not built. **Cars** need models that do not
exist yet - that is the real cost of that item, not the code. It is a row added
to `Shop.stock()`, and the screen, the purse and the check need no changes to
carry it.

### Reading it from an empty purse

Everything is on the page, price and all, whether or not there are coins for
it. A shop that hid its stock until a player could afford it would give them no
reason to pick a coin up - **the price is the reason**, and it has to be
readable from an empty purse. So nothing is hidden, nothing is greyed out of
legibility, and the only thing the purse changes is whether pressing BUY works.

BUY is pressable even with nothing in the purse. A disabled button in Godot
cannot take keyboard focus, and both players are on one keyboard with nobody
asked to find the mouse - disabling what cannot be afforded would leave a
player with an empty purse unable to put the cursor on a single row. Pressing
it says `SAND COSTS 20. THERE ARE 0 IN THE PURSE.`, which is the answer they
were after anyway. What is already owned *is* disabled, because there the
button genuinely has nothing left to do.

The page is a fixed width, the way the garage's list of shared cars is. The
status line says different lengths of thing, and a panel that grew to fit
whatever it had just been told would resize under the player's hands every time
they pressed BUY. The widest thing on it is the line under the heading, which
never changes, and everything said below is said inside that. That line is also
where "a paint goes on from the pause screen" lives, rather than in what is
said after a purchase: it is worth knowing before spending twenty coins rather
than after, which is what a permanent line does and a message that scrolls past
cannot.

Whatever the status line last said is cleared the moment the purse moves.
`THERE ARE 0` is only true of the purse it was said about, and left standing
over a tally that now reads 20 it is a page arguing with itself. The purse is
watched rather than remembered, because a coin can be banked by the race
running behind the title while the shop is open.

### On the paint screen

The paint screen grew a third row: the six that are sold. One that has not been
bought is on the page anyway, faded, **with its price written across it in the
coin's own gold** - for the same reason the shop shows a price to an empty
purse. A locked swatch hidden until it was paid for would be a thing a player
only discovers after spending on it, and the whole point of a price is that it
is read first. Bought, the price comes off and it is a swatch like any other.

The garage has the same eighteen in a row under the car, dressed the same way -
see [The car's own paint](#the-cars-own-paint). Whether one may be worn is
`Purse.owns_paint` for both of them, so there is one answer and not two.

Locked and taken get the same faded face, and that is on purpose: the square
can only say one thing in a colour, which is that this is not a paint you can
have right now. Which of the two it is, is in the price written across it and
in what it says when pointed at. Taken wins when a swatch is both - telling a
player to go and buy a colour their rival is already sitting in would be
sending them to spend coins on something that still would not be pickable.

### Checking it

`tools/checks/shop.gd` is the whole of it, and it is headless. Three things
about a shop go wrong quietly: a price that is not what the purse charges,
which is a shop that lies; something on sale that cannot be reached, or
reachable that was never put on sale - a colour added to `Paints` and forgotten
is free to everybody, and one sold under a name nothing hands out can never be
bought at all; and an item that un-owns itself, which takes coins a player will
not get back.

A fourth thing goes wrong quietly now that a car is painted in two places: a
second door to a sold paint. So the check drives the garage's row as well as
the paint screen.

So it holds the table to `Paints` in both directions, checks that every item
name is something a config section can actually hold, and that both players
start in a paint nobody has to buy. It buys through a real `Purse`: refused on
empty, refused one coin short, bought with exactly enough, refused a second
time, and still owned after a save and a load and after something else is
bought. It opens the real screen with an empty purse and reads every name and
every price off it, checks the keyboard landed on something, and presses BUY to
see that the button charges the price beside it. Then it opens the paint screen
to see a sold colour refused until bought and worn after.

```
Godot --path . --headless --script tools/checks/shop.gd
```

`tools/checks/shop_shot.gd` walks it with a camera for the half no assertion
sees - whether a price is legible against the panel, whether a locked swatch
reads as locked rather than as broken. The walk is deliberately the poor one:
it opens the shop with nothing in the purse, presses BUY, earns exactly one
paint, buys it, and goes to the pause screen to wear it.

```
Godot --path . --script tools/checks/shop_shot.gd -- /tmp/shots
```

## Car customisation

For **50 coins** in the shop, a slot that lets a car be decorated as well as
painted: stripes, stickers the game ships, and a word the player writes by
hand. It is a **tab inside the garage** - `scripts/decoration_page.gd`, built
in code and put in the garage's panel beside the cars - rather than a screen of
its own. Decorating a car is a thing done to a car, and the car it is done to
is the one the player picked on the other tab; putting it behind a button
somewhere else would mean choosing a car in one place and drawing on it in
another, with nothing on either page saying they were about the same thing.

Everything is applied as it is chosen. The car on the left of the page is
already wearing whatever has just been pressed, which is the same choice the
paint screen made for the same reason: a decoration confirmed two presses after
it was picked is a guess. `scripts/car_stage.gd` is that car - a bare
`CarShell` in a world of its own, lit the way `CarPortrait` lights a tile, so
the car in the tab and the car on the tile match.

The slot is bought once for the whole game rather than once per car. A player
who paid fifty to decorate one car and then brought in a second model would
otherwise be asked for fifty more to draw on it, and what they bought was the
ability to draw.

### The car's own paint

The eighteen paints are in a row under the car, and pressing one paints it on
the spot. **It is not decoration and it costs nothing** - the fifty coins buy
the drawing, not the painting - but it is the same question asked about the
same car, and until now the only place in the game to ask it was the paint
screen over a paused race. A player looking at their car in the garage and
wanting it green should not have to start a race to say so. The tab is called
PAINT AND DECORATION for the same reason: a player looking for paint has to be
able to find it.

It is under the car rather than over in the tools with the rest, because it is
about the car and not about what is going on the car, and because a colour is
chosen by looking at the thing wearing it. The tools column's own palette says
`THE COLOUR IT ALL GOES ON IN`, which is the other half of keeping the two
apart. The row costs the page no height: the car takes whatever is left over
once the swatches have had theirs.

The three rules are the paint screen's, unchanged, because they are rules about
painting a car and not about a screen:

- **the free twelve always, the six the shop sells once they are bought**, and
  a locked swatch is faded with its price written across it in the coin's own
  gold;
- **the two players cannot both be one colour.** A split screen where the arrow
  pointing at your rival is your own paint is a race nobody can read;
- **taken beats locked** when a swatch is both, since sending a player to buy a
  colour their rival is sitting in would be sending them to spend coins on
  something that still would not be pickable.

One thing differs, and it is the page it is on rather than the rule: these
swatches are **not disabled**. Everything on this tab can be pressed and says
why nothing happened, for the reason the shop keeps BUY pressable over an empty
purse - a disabled button in Godot cannot take keyboard focus, and both players
are on one keyboard. The faces are the same as the paint screen's either way,
so the two rows still look alike; it is only that this one answers out loud.

Whether a paint may be worn is `Purse.owns_paint`, one function, because there
are two doors to it now and a paint that one of them would wear without it
having been bought is a paint nobody buys. `tools/checks/shop.gd` drives the
garage row as well as the paint screen, and drives it rather than reading it:
these swatches are pressable, so the only way to find out whether one was
refused is to press it and look at the car afterwards.

### The car is the page

Everything a player places is placed on the model. There used to be a flat
drawing of the side of a car on this tab - a silhouette, with the stickers
dragged about on it - and the model turned slowly on a plinth beside it,
showing the result. Two pictures of one car, and the one being worked on was
the one that was not real.

That cost more than it looked. A silhouette has one side, so three quarters of
a car could not be decorated at all: no roof, no bonnet, no nose, no tail. And
nothing placed on it was quite where it had been put, because a drawing of a
car is not the shape of anybody's car, least of all a model a player brought in
themselves.

The objection that put the silhouette there was a fair one, and it is answered
rather than dropped: **do not ask anybody to hit a small moving target with a
mouse.** So the car does not move any more unless it is moved. It is turned by
dragging it and zoomed with the wheel, and it stays exactly where it was left.

| | |
| --- | --- |
| Drag with the left button | turns the car, unless the press landed on something already on it |
| Drag with the right button | always turns the car, even with the pen out |
| The wheel, or a pinch on a trackpad | closer, or further off |
| Press something on the car | picks it up; dragging then moves it anywhere on the body |
| Arrow keys | turn the car, or move whatever is selected - see below |
| `+` `-` `Home` | closer, further off, and back to the view the page opens on |

**Two cameras**, picked with two boxes in the top left corner of the car -
AUTOMATIC CAMERA and MANUAL CAMERA, one group, so ticking one unticks the other.
The page opens on the automatic one, which is everything in this section: it
looks at the middle of the car, fits all of it, and will not go under the sills
or nearer than half a metre outside the bodywork. The manual one is the
player's own:

| | |
| --- | --- |
| The wheel, or a pinch | towards whatever is under the cursor, which stays under it - to a hand's width (12 cm) off the paint, or out to three times the distance the whole car fits at |
| Drag with the middle button, or with Shift down | slides the car across the view |
| `Shift` and the arrows | the same, from the keyboard, with nothing selected |
| Dragging to turn it | turns about whatever it has been slid to, not about the middle of the car, and nearly straight down or straight up |
| `Home` | back to the view the page opens on, still manual |

It starts exactly where the automatic camera was, so ticking it moves nothing
until the camera is moved, and ticking AUTOMATIC CAMERA again keeps the angle
and fits the whole car from it. What it turns about is kept within half a car of
the car, so the car cannot be slid off into the dark and lost. Everything else
on the page is the same with either: a press is still a ray from wherever the
camera is, so a sticker lands on the door handle a player has zoomed in to.

The camera and the car in this view are **never smoothed between physics
steps**. The camera moves when the mouse does, and a camera drawn a step behind
where it was put is a camera asked where a press landed a step behind too - the
manual camera's wheel, holding what is under the cursor still, showed it at
once. The title screen and the pause menu turn smoothing off already, but that
does not reach in through the view's own viewport, so the view says it for
itself. `tools/checks/decals.gd` ticks the two boxes, zooms towards a point on
the car and slides it, and holds that point under the cursor and the view back
where it was.

What the arrows do depends on whether anything is selected, and that is the
whole of the rule: with a sticker in hand they move the sticker, and with
nothing in hand they turn the car. A second set of keys for the second job
would be a page that already shares one keyboard with two players asking for
more of it.

The camera orbits and the model stands still, rather than the other way about.
That is what makes a press cheap to answer: a click is a ray in the world, the
world is the shell's own space, and the shell can say where it meets the
bodywork without anything having to be undone first.

How far back the camera stands is worked out from the car and not written down,
because it has to frame a model the game has never seen - a fixed number of
metres is a wall in front of one car and a speck of another. Every corner of
the box is asked how far away the camera would have to be for that corner to
sit on the edge of the view, and the furthest answer wins. It is worked out for
the angle the car is currently being looked at from, so a car in a view three
times as wide as it is tall fills it instead of sitting in the middle of it
with room all round for the one angle that needed it. The cost is that the
camera steps back a little as the car is tipped up to show its roof, which is
the right way round.

### On the body

A mark goes on **the bodywork, where it is put.** A press on the car is a ray,
and the ray is asked of the model's own triangles - gathered from its meshes
the first time the garage asks, since the model has no collision of its own
and a model somebody brought in has none either. Where it meets them is where
a sticker goes and where a stroke of the pen is drawn, and the way the body
faces there is the way the decal is thrown back at it.

Marks used to go on one of four faces of the box the model measures - the
sides, the top, the nose, the tail - on the grounds that the box is the one
thing every model has. It is, and it was the wrong thing to aim at. A bonnet is
neither the top of the box nor the front of it, and it sits well under the
roofline: a decal thrown down from the top of the box reached a quarter of the
way into the car and stopped short of it, so a bonnet could not be drawn on at
all, and a cursor near the top of a door was over the roof more often than it
looked. Projecting still needs nothing from the model but its shape, so a car
the game has never seen still wears a sticker; what changed is only which way,
and from where.

A mark on the body keeps where it is as a **spot** - fractions of the box, so it
names the same place on a car of any size - and which way the body faces there,
its **aim**. The decal is centred on the bodywork, as deep as the mark is wide
to follow the curve under it, and never deeper than half the car, so a word on
one door cannot come out backwards on the other. A sticker is aimed along the
body the width of the sticker round the cursor rather than at the single
triangle under it: a car is triangles, and one aimed square at each in turn
would tip from facet to facet as it was dragged across a curve.

**A mark on a door is on both doors**, the way a racing number is: two decals,
mirror images in the world and the same picture to look at, so a word reads the
right way round from whichever side you are standing. That is decided by which
of the old faces a mark's aim is nearest - out of the side of the car, and it
is worn on both - so it is the same rule it always was. Everything else is one
decal, because a car has one bonnet.

**MIRROR** turns that off. It is a box beside the colours, ticked to start with,
so nothing is different until a player unticks it; unticked, what goes on a door
next stays on that door. A mark keeps it - `"mirror": false`, written only when
it is off, so every mark from before the box is the mark it was - and keeps it
wherever it is dragged, because it is about the mark and not the panel: a
sticker put on the bonnet with the box unticked and dragged onto a door is on
that door alone. Ticking or unticking with a mark in hand changes that mark, the
way a colour does, and picking a mark up ticks the box to match it, the way the
sliders move to its size. A mark unticked by the copy on the far door stays on
the far door, the one that was taken hold of. A mark still on one of the old
faces is put on the body first, because a face is both doors or neither. The underside is still not somewhere to
draw: a mark facing down is on whichever of the others it faces most.

A sticker pressed off the tools lands on the body **in the middle of the view**,
turned to stand the way up the car is being looked at, and selected, so the
next thing a player does is drag it. Dragged, it follows the body anywhere -
round from a door onto the bonnet and down the nose - facing whichever way the
body faces under it and keeping the way up it had on the screen, so a number
dragged over the edge of the bonnet does not spin round when it reaches the
wing. The arrow keys move it across the screen the same way.

The faces are still in `scripts/car_faces.gd`, for three things. A mark saved
before this is on one and stays exactly where it was until it is moved, when it
is put on the body. A design drawn flat, on a livery's tile, is drawn in faces.
And every mark on the body also carries the face its aim is nearest and the
place on that face it would be, so a copy of the game from before the body puts
it near enough where it belongs instead of losing it (see
[Liveries](#liveries)). A view zoomed in past the roofline, with nothing of the
car in the middle of it, puts a pressed sticker in the middle of the face being
looked at, the way every sticker used to go on.

One thing is drawn over the car rather than in it: a ring round whichever mark
is selected - the square the decal actually projects, turned the way it is
turned, round the copy of it being looked at, so the ring is round the thing
rather than near it.

### The pen

A word is written straight onto the paintwork. DRAW ON IT takes the pen out,
and from then on the left button draws on the car and the right button still
turns it; **every stroke is on the car the moment it is finished**, in the
colour it will stay, at the size and the angle it was drawn. UNDO takes the
last one back off, and DONE puts the pen down. Between them, while the pen is
out, are four widths to draw in, each shown as the line it draws.

That replaces a box of graph paper that opened over the garage: write the word
in the square, press PUT IT ON, then drag it to where it was wanted. Two steps
and a guess in between, and the guess was the problem - a word written big in a
square box is a word that comes out somewhere else entirely on a door.

A word is one mark, so the whole of it is put on again each time a stroke is
finished rather than the stroke being added to what is there: the box is drawn
round everything in it, so every stroke moves and resizes when a new one joins
them. That is also the only way the cap can refuse a stroke, which it does by
refusing the word the stroke would be part of - and then the stroke is dropped
and the word is left exactly as it was.

The box is worked out in **metres on the car** rather than in fractions of the
panel, because a panel is not square: a door is three times as long as it is
tall, and a word normalised against one would come out three times as wide as
it was written. It is grown by the width of the nib as well, since the pen
draws about the line it was dragged along and half of it would otherwise be
shaved off at the edges.

**A stroke comes out as thick as it was drawn.** The width is picked as a share
of the car's length - 1%, 1.8%, 2.8% or 4% - because that is what a player is
choosing: a line as thick on the door as the one they are watching. The word
keeps it as a share of its own box, worked out from the box it ended up in,
because that is the only width the decal's picture knows; and so a word made
bigger with SIZE afterwards gets fatter lines with it, the way a sticker does.
The pen used to be a fixed share of the box, which made the stroke in hand and
the finished word two different widths: a short word came out much thinner
than the line the player had just drawn, and a long one fatter. A word is one
mark with one pen, the way it has one colour, so picking a width halfway
through a word draws the whole of it again in that width - refused, as a
stroke would be, if the fatter line takes the car over the cap.

The pen draws on the body too. The first stroke of a word starts wherever it
touches the car, and every point of every stroke after it is wherever the pen
meets the body - a bonnet, a wing, a boot lid, whatever slope it is. A word is
still one mark, so it is laid flat against the way the body faces under the
whole of it, added up over every point the pen touched, and thrown back onto
the car from there, along the screen's right as it was when the word was
started, so it comes out the way up it was written. A letter that runs off the
edge of the car, or onto a part of it facing well away from the word, carries
on in the flat plane the word started on rather than stopping dead or jumping
down onto the bumper. What that costs is a word written round a sharp corner -
from the bonnet down the nose - which comes out stretched on the side it was not
facing. Write one on each.

### The three kinds, and how each is actually drawn

The car's paint is one material by name, and that works on a model the game has
never seen ([The shell](#the-shell)). Decoration cannot lean on the model
having sensible UVs, because a player's model might have none worth using. So
the two routes were split by what each kind needs, and this is the record of
which took which:

**Stripes - CENTRE, TWIN, FLASH, BONNET - are worn in the model's own texture
space.** One mask per shape, hung on the paint material as an **extra pass**
(`Material.next_pass`), with the shape in its alpha and the colour in the
pass's own `albedo_color`. A stripe has to follow the body's curve to look like
paint rather than like a sticker, and the only thing that knows where that
curve is, is the model's own unwrap. The cost is that a model unwrapped by
nobody gets a stripe somewhere arbitrary - it clips where it clips. That is a
bargain taken knowingly: the stock car is the car nearly everyone will
decorate, and its unwrap is fine.

A pass rather than a texture written into the paint material, and that is the
whole trick. The body keeps whatever albedo it had - a flat colour on the stock
car, somebody's own texture on a model they brought - so a stripe never eats a
model's paintwork. It also makes the chaos cycle free: the colour is a property
to set, not a picture to draw again.

**Stickers and hand-written words are projected**, as `Decal` nodes floated
beside the car in its own space, aimed back at [the body](#on-the-body) where
they were put. No unwrap needed at all, so they land where they were put on any
model whatever. A mark on a door is **two** decals, one per side: a decal
throws its picture one way only, and a number on a door is on both doors. They
are mirror images in the world and the same picture to look at - image right is
the car's tail on the left flank and its nose on the right - so a word reads
the right way round from whichever side you are standing, which is how a name
on a door works. Anything else is one decal.

Where a mark is - which way it is thrown, which way up its picture goes and how
deep its box may be - is `CarFaces.placements`, once. The shell puts decals
where it says, the garage draws the ring round a selected mark from it, and a
press works out whether it landed on a mark against it, so what a player
pointed at and what the car wears cannot drift apart. `tools/checks/decals.gd`
drags a sticker onto the bonnet and writes a word there the way the mouse
would, and holds both to lying on the bonnet itself, because a mark landing
somewhere other than where it was put is something nothing else in the game
would say.

**A decal must never reach the road.** This is the failure the feature was
always most likely to ship with: a decal projects onto every surface whose
visual layer its cull mask lets through, and the cars share layer one with the
tarmac, the trees and everything else. So **each shell claims a visual layer of
its own** - layers 4 to 11, since 1 is the world and 2 and 3 are the players'
private arrows - puts its model on that as well as on the world's, and points
its decals at nothing else. A layer each rather than one for all cars, because
two cars touching is an ordinary part of a race and one car's sticker landing
on the other's door is not. Eight is four more than there has ever been a car
on a course at once; a ninth borrows the last rather than going bare.

The boxes are centred on the bodywork and as deep as the mark is wide, and
never deeper than half the car across whichever way the mark faces most - far
enough to follow the curve of a door, never far enough to come out of the far
side backwards - and `normal_fade` keeps them off the faces turned away. A mark
saved on one of the old faces keeps the box it always had, centred on the face
of the box round the car.

### The shapes

Eleven fixed pictures and one drawn per word, all in `scripts/decal_art.gd`,
all **white with the shape in the alpha** and coloured somewhere else. That is
what makes the chaos cycle a property being set rather than an image being
rasterised sixty times a second.

The three numbers are drawn as seven segments rather than set in the game's
font, on purpose: a racing number is a shape, and the menu font is the game
talking. The rest - a flame, a star, an arrow, a chequer - are polygons and
grids. Everything that can be is drawn as whole rows at a time, because a band,
a bar and a circle all come down to a left and a right edge per row; only the
three polygons are asked a pixel at a time, and each of those is drawn once
ever and kept.

**A hand-written word is kept as the points the pen went through, not as a
picture.** It is a few hundred numbers instead of a file, it can be drawn again
at whatever size the car wants it, and a decoration saved on one machine means
the same thing on another. A few hundred because the points are **thinned**
as the word is made (`DecalArt.thinned`): the pen is read every time the mouse
moves, and a word kept at every one of those is thousands of points a hair
apart, far too long to be written down as a livery. Thinned to a pixel of the
picture it is drawn into, a curve keeps the points that bend it and a straight
line keeps its two ends. A car loaded from a build before that is thinned on
the way in. Drawn rather than typed, on purpose: a name set in
the game's font is the game's writing, and a scrawl is theirs. Undo is not
optional - a player drawing with a mouse will make a mess of the first stroke,
and a pen whose only way back is starting the word again is a pen nobody
finishes a word with.

Words are rasterised on demand and **kept**, up to 24 of them. That is not only
to save the work: an `ImageTexture` built inside a `_draw` and handed straight
to `draw_texture_rect` is a texture nothing holds a reference to, and it is
freed before the frame it was drawn into reaches the screen. What arrives is a
flat rectangle of the modulate colour, which is exactly what the board drew
until the cache was put in.

### Where it is kept

`user://decals.cfg`, a section per car id, `stock` for the stock car - which is
the word the garage already uses for where that car's portrait goes. A store of
its own rather than the car's folder, because **the stock car has no folder**:
its id is the empty string and it is part of the build.

A mark is its kind, its shape, its colour, where on the body it is and which
way the body faces there, how big it is and how far round it is turned - and,
for a word, the path the pen took and the width of the pen. A mark saved before
there was a body to put things on has a panel and a place on the panel instead,
and is drawn there until it is moved. A file written before there were panels
to choose has no panel in it either, and everything in one is read back onto
the flanks, which is where it was.

A decoration belongs to a car, not to a player. Two people driving the same
model see the same stripes on both cars. That is correct - it is one car - and
it is why the split-screen rule matters more here rather than less, since the
paint is then the only thing telling the two apart.

So **a car may be no more than 34% covered**, all three kinds added together,
and carry no more than **8** things. The paint menu already refuses to let both
players take one colour, and decoration must not undo that from the other side;
a third leaves two thirds of every car still wearing the colour that says whose
it is. The count is the second limit because the cap is about readability and
eight is about not building four hundred decals for four hundred tiny stickers.

The three kinds are measured in spaces that are not the same space - a stripe
covers a fraction of the model's unwrap and a sticker a fraction of its flank -
and they are added anyway. The number is a **budget rather than a measurement**:
what it is for is stopping a car disappearing, and both fractions grow when
that is happening. Pretending it was an area would be pretending the game knows
the shape of a model it has never seen. A word is measured by how far the pen
travelled, which over-counts a stroke drawn back over itself - the right way to
be wrong, since a cap that guesses high refuses a decoration that would have
been allowed and one that guesses low lets a car vanish.

Going over is **refused whole, never trimmed**. A player who has just drawn one
sticker too many should be told the car is full, not handed back a car with
something else quietly missing off it.

**A car removed from the garage takes its decoration with it.** A section left
behind would be handed straight to whoever next added the same file, and that
is not their drawing. Only free paints may be used, too: a stripe in one of the
six the shop sells would be a way of wearing a bought colour without buying it.

### Reading the tab from an empty purse

Nothing on the page is hidden or disabled by the fifty coins. Every button is
there and every button can be pressed. The line above BACK carries the price -
`CUSTOMISING IS 50 COINS IN THE SHOP · until it is bought, nothing here goes on
a car` - and pressing anything says the part that changes: `THAT NEEDS THE
CUSTOMISING SLOT. THERE ARE 0 COINS IN THE PURSE.` The price is in one of them
and not both, because two lines one over the other saying the same sentence is
a page arguing with itself. That is the
shop's own rule about an empty purse ([Reading it from an empty
purse](#reading-it-from-an-empty-purse)) applied on this side of the counter -
the price is the reason to pick a coin up, and a page that hid itself until it
was paid for would give nobody that reason. It is also the practical answer: a
disabled button in Godot cannot take keyboard focus, and both players are on
one keyboard.

Stripes are toggles and stickers are placed, because they are not the same kind
of choice. There are four stripes, each on or off, worn in texture space where
there is nothing to place. Everything else is put on the car itself - see [The
car is the page](#the-car-is-the-page).

### In chaos

The requirement, and it is a good one: **the stripes, stickers and writing stay
exactly as they were drawn, and their colour changes constantly.**

That is the opposite of what chaos does to the bodies. Chaos repaints those
once at the line and holds them there, deliberately, because telling your car
from the other one is the one thing about a chaotic race not allowed to be
chaotic ([What chaos looks like](#what-chaos-looks-like)). So the decoration is
the part that cycles and the body is not.

Each mark turns from **its own place in the cycle**, the way each kind of leaf
does, so a car with three things on it shimmers instead of pulsing as one. The
whole turn takes 7 seconds.

The readability rule again, from the other direction: the cycle runs at **0.36
saturation and full value**, and chaos paints a body somewhere from 0.6 to 1.0
saturation. Pale on a strong colour reads as decoration at a glance across a
split screen even when the hue happens to come round to the body's own.

Like everything else chaotic, this is **told to the car by whatever built the
race** rather than read from `GameSettings.chaos` - the title screen backdrop is
a race scene too, and a strobing sticker behind the menu is not what the menu
is for.

### Liveries

A design saved on its own, with no car under it: the same stripes, stickers and
handwriting, kept as a thing in its own right so it can go on any car, sit
beside the cars in the garage, and be handed to somebody else. SAVE AS A LIVERY
on the decoration tab asks what it is called and keeps it; after that the
button says `SAVED AS <name>` instead, because a design that is already a
livery is not a question worth asking again.

`Liveries` is the store, `user://liveries.cfg`, and it is to `LiveryLibrary`
what `Garage` is to `CarLibrary`: the truth a livery is played against, saved,
renamed, applied and thrown away with the network unplugged. One file rather
than a folder each - a car has to keep its model exactly as it arrived and its
portrait beside it, and a livery is a line of text.

**The id is the design, hashed**, the same sixteen hex characters a car's id
is. So the same design saved twice is one livery, a design has the same id on
every machine it is copied to, and a livery from a stranger can be checked
against the id it was asked for before anything is done with it. Saving a
design you already saved keeps the first name: you have not made a second
design, and renaming the one you had would lose the name you chose.

That last promise is why the hash is spelled out in `scripts/livery.gd` rather
than handed to `var_to_str`. Two machines have to agree on the string down to
the last digit, and a float printed one way on one and another way on another
is two machines that disagree about which livery they are holding. Every number
goes in at **four decimals**, finer than any of them is read at - a mark's place
on the car is a fraction of a car's length, and a ten thousandth of that is a
tenth of a millimetre. A difference finer than that is not a difference.

```
stripe|1|10|0.5|0.5|1.0|0.0;sticker|4|2|0.4|0.45|0.2|0.0
```

That line is the whole livery: what is hashed, what is written into the file,
and what goes to the server. Fields are split on `|` and marks on `;`, and
nothing in a design can hold either character - every field is a number or one
of four fixed words - so it comes apart exactly where it was joined.

**The panel a mark is on is written only when it is not the flanks**, and the
flanks are what everything drawn before there were panels to choose is on. So
every design that already existed hashes to exactly the id it already had - the
one in the file here, the one somebody else is holding, and the one a copy of
this game from before the panels would work out. The two fields that can follow
the seven are told apart by what they look like rather than by where they sit:
a word's strokes are points and a point has a comma in it, and a panel is a
lone digit. **A word's pen is written the same way**, only when it is not the
width every word had before there was a choice, and it is the one field with a
decimal point and no comma. It goes before the panel, so a copy of this game
from before the pen reads it as a panel, gets nought - the flanks - and has the
real panel written straight after it put that right: the word lands where it
was put and only comes out at the old width. **A mark on the body** is written
as it would be on the face it is nearest, followed by where it really is - the
spot and the aim, six numbers run together with `:`, the one field with a colon
in it. It goes before the panel for the pen's reason, so a copy of the game from
before the body draws it on its nearest face, near enough where it was put. **A
mark on one door only** has the word `single` straight after its body, and
nothing when it is on both, which is every mark there was before MIRROR could be
unticked. A copy of the game from before that reads the word as a panel, gets
nought, and has the real panel after it put that right, so it puts the mark in
the right place and only wears it on both doors. The
face and the place on it are worked out from the spot and the aim as they are
written, rounded, not as they were: worked out from the unrounded ones, they
could round one way the first time and another every time after, and the
design would change id on its way to somebody else. `tools/checks/liveries.gd` holds a flank-only design to its written
line and its id in full, because that is the one promise in the game that
reaches other people's machines and older copies of this one. The file
keeps that form rather than the dictionaries the game draws from, so a livery
that reads back wrong is wrong in one place; and a section edited by hand stops
being that livery rather than quietly becoming a different one under its old
id.

**A livery is copied onto a car, never pointed at.** The car holds its own
marks in `Decals`. So a livery put on and then tweaked is that car's design
from the moment it is tweaked, and throwing the livery away leaves every car
that ever wore it exactly as it is. That is the whole reason the two stores are
separate.

In the garage they get the third half of each player's row, beside the
unofficial cars: a small picture of the design and its name. A **row** rather
than a tile, which is the one thing that made a third half fit - a tile big
enough to read is a tile two of which do not fit the 142 a half is tall, and a
column showing one and a half designs is a column nobody can look through. The
picture is `DecalArt.draw_side`: a schematic of a design rather than a picture
of a car wearing one - the silhouette with the marks laid over it, and the
three panels a flat side does not have drawn at the edge of the silhouette they
belong to. It is the only drawing of a design that is not the car itself, and
all it has to do is say which design this is. It is drawn **in that player's
own paint**, because that is the car it would go on - the same design in the other
row is the same design on a different colour, which is worth seeing before it
is pressed.

Pressing one puts it on that player's car at once, like everything else on this
page, and the tile is held down while the car is wearing it. Which livery that
is, is a lookup and not a search: the id is the design hashed, so the car's own
marks say which one it is, and a car decorated by hand into exactly some saved
design is wearing that design. It costs the same fifty coins the decoration tab
does, and says so the same way when it has not been paid for.

REMOVE throws a livery away when the cursor is on one, rather than taking a car
out of the garage. TURN is refused: a livery has no model to turn.

### Sharing a livery

SHARE and BROWSE do liveries as well as cars, through `LiveryLibrary` over the
same `Backend`, and the browse page grew a `CARS | LIVERIES` pair at the top.
One list at a time and not one mixed list: a car and a design are not
alternatives to each other, and a player looking for one is not half-interested
in the other. The search is cleared when the list changes, because a search is
about the list it was typed over.

**There is no bucket.** `CarLibrary` puts a model in storage and the row points
at it, and nearly all of that file - the two-request order, the path
constraint, the 409 handling, the cleaning up after a share that fell over - is
there because a row and a file can disagree. A livery is a column. Sharing is
one insert, unsharing is one delete, and a livery cannot exist on the server
with its design missing.

One good thing falls out of that: **the request that lists what has been shared
also carries every design**, so the browse page draws all of them. A page of
shared cars can only show names, because showing a car would mean downloading
every model on the list.

A design that comes down is a stranger's and is treated as one. It is read mark
by mark through `DecalArt.tidy`, hashed, and must come out as the id it was
asked for; then it goes in through `Liveries.adopt`, the same door as one drawn
here. A mark this build has no shape for is dropped and the rest arrives - a
livery missing a sticker is something a player can see, where nothing at all is
something they cannot work out the reason for - and a paint out of the six the
shop sells is pulled back into the free twelve, so a shared design can never be
a way of wearing a colour without buying it.

The server side is the `liveries` table in `backend/schema.sql`. **A project set
up before liveries existed needs that file running again**; until it has been,
sharing a livery fails and the LIVERIES half of the browse page is empty, and
nothing else changes.

### Checking a livery

`tools/checks/liveries.gd` is the headless half. A livery is the one thing in
the game that is *meant* to travel as something this game wrote, rather than as
bytes it can hash and hand on untouched - so the writing and the reading are
code, and code that disagrees with itself is a design that arrives as a
different design.

It holds a design through writing, reading and hashing again; checks that the
same design reached twice is one id and that moving a sticker is a different
one, while a millionth of a car's length is not; holds a design worn on the
flanks to the exact line and the exact id it had before there were panels to
choose, and the same sticker on the roof to a different one; drives a real
save, a real reload and a real save-the-same-thing-twice; brings a design in from outside
with an unknown mark and a bought colour in it to see what survives; checks
that throwing a livery away leaves the car wearing it alone; and opens the real
garage to see a livery sitting beside the cars, going on when it is pressed,
held down while it is worn, and refused until the slot is paid for.

```
Godot --path . --headless --script tools/checks/liveries.gd
```

`tools/checks/livery_shot.gd` walks it with a camera, for the half no assertion
sees - whether a design is recognisable from the small picture on its row,
whether two designs tell themselves apart at that size, and whether the same
livery in the other player's row plainly reads as the same design on another
colour.

```
Godot --path . --script tools/checks/livery_shot.gd -- /tmp/shots
```

### Checking it

`tools/checks/decals.gd` is the headless half. Six things about decoration go
wrong quietly and none of them shows up by looking at a car: a decoration that
comes back different from the one that was saved, which is somebody's own
handwriting lost; one that outlives its car; the stock car losing its own,
being the one car with no folder to keep anything in; a car covered past the
cap; a mark that lands somewhere other than where it was aimed; and a car that
never hears the press at all.

So it drives a real `Decals` through a real file, removes a real car out of a
real garage, and opens the real tab to see the fifty coins gate it. It also
counts what a decorated car actually carries - one pass per stripe, two decals
for a mark on the flanks and one for a mark on any other panel, and exactly one
of them aimed downwards - and checks that **no decal's cull mask names the
world's layer**, which is the sticker-on-the-tarmac failure written as a number
instead of left to a screenshot.

The last two are what the tab now rests on, and they are checked as the two
halves they are. **The arithmetic**: every panel is aimed at from several
angles and the answer picked up again, and where a mark was put has to be where
a ray finds it, or a sticker lands somewhere other than where a player put it
and nothing else in the game says so. **The wiring**: a real mouse press is
pushed at the window over a sticker on the car, and the page has to have picked
that sticker up - because a view that never sees a press is a page where
nothing happens at all, and no number anywhere would say why.

```
Godot --path . --headless --script tools/checks/decals.gd
```

`tools/checks/chaos_colour.gd` covers the cycle: the decoration moves in a
chaotic race, holds still in an ordinary one, holds still on the title screen,
each mark turns from its own phase, and the body underneath holds the colour it
was rolled.

`tools/checks/decorate_shot.gd` walks it with a camera, for the half no
assertion sees - whether a stripe lands on the body rather than washing it,
whether a sticker is the right way up on each of the panels, whether somebody's
handwriting is still legible once it has been thrown at a curved door, whether
the car is framed and the ring is round the thing rather than near it, and
whether the road under the car is clean. It writes a word on the car with the
pen, turns it up to its roof for one sticker and round behind it for another,
and then goes out onto the road with the lot.

```
Godot --path . --script tools/checks/decorate_shot.gd -- /tmp/shots
```

## Adding a track

Everything a track needs is in place, so adding a twenty-first is four steps
and no code:

1. Write `tracks/NN_name.gd` extending `TrackDefinition`, set its `medals()`,
   and check it with `tools/checks/track_check.gd` and
   `tools/checks/track_map.gd`.
2. Add its path to `TrackRoster.FILES`, in the order it should appear.
3. Run `tools/track_thumbnails.gd` to draw its overhead shot.
4. Give it a row in `TrackVariant.OFFERED`, the ways it can be driven.
   `tools/checks/variants.gd` says which those are: it reports every way that
   would build clean and is not listed. If it offers Reverse, give that a row
   in `TrackVariant.TARGETS` too, from `tools/lap_times.gd -- reverse`, since
   the check refuses a track driven backwards with no targets.

The name on the button, the slot in the grid, the times, the solo race, the
track page and the checks all follow from those.

## What chaos looks like

Chaos already rerolled how a race drives. It also rerolls how it looks.

**The cars are repainted for every course**, bright enough to be picked out of
a hedge, and set once at the line rather than shifting while anyone is driving.
The two are given hues on opposite sides of the wheel, so however the colours
land the players can always tell which car is theirs - that is the one thing
about a chaotic race not allowed to be chaotic. The rival arrows are recoloured
with them: the arrow is the only thing telling one player which car is the
other one, and a car that changed colour under an arrow that did not would be
worse than no arrow.

**The speed lines are not white.** They turn through the colours, each streak
from a slightly different place in them, so a boost comes out as a shifting
spread rather than one tinted sheet. A whole turn's worth of spread would put
every colour on screen at once and read as noise; a quarter reads as a colour
that happens to be several colours.

**The leaves never settle.** Each kind of tree turns from its own place in the
cycle, so the field shimmers instead of the whole horizon pulsing as one.

**Whatever is drawn on a car never settles either**, while the body under it
holds perfectly still. The stripes, stickers and handwriting stay exactly as
they were drawn and only their colour moves, each mark from its own place in
the turn - see [In chaos](#in-chaos) under car customisation for why that is
the way round it is, and how the cycle is kept clear of the body colours.

Which surfaces of a tree are its leaves is asked of the colour rather than the
name: the model calls its materials Material.001 through Material.007 and
nothing in that says which is bark and which is a canopy. Every green surface
in the pack is foliage and nothing else in it is green, so green is the
question. The meshes are duplicated before anything is done to them, since they
come from an imported model the whole game shares - and a MultiMesh has no
per-surface override to reach for instead, only one material for the whole
thing, which would paint the trunks as well.

None of this reads `GameSettings.chaos`. Each is told by whatever built the
race, because the title screen backdrop is a race scene too, and a rainbow wood
behind the menu is not what the menu is for.

`tools/checks/chaos_colour.gd` checks the three that are meant to move and the
two that are meant to hold still, and then that none of it happens in a race
that is not chaotic or on the title screen:

```
Godot --path . --headless --fixed-fps 60 --script tools/checks/chaos_colour.gd
```

## Damage

A setting, off until a player turns it on, that gives each car a condition as
well as a speed. Hitting barriers wears the car down, and a car worn down to
nothing is finished.

Off by default is the important half of that. The game has one punishment for a
mistake and it is time: a car that hits a barrier loses speed and carries on,
and that is what makes the endless course and the twenty tracks bearable to
practise on. Damage is a second punishment on top, and a player who never chose
it should never meet it. It lives in `GameSettings.damage`, saved under
`[race] damage`, and is switched on from the settings screen, with a line under
it saying what it does - "Damage" alone does not tell anyone that it ends runs.

**What a hit costs** is worked out from the two numbers the speed a hit costs
already uses, and nothing new:

```
cost = full_hit * head_on * (speed / max_speed)
```

`full_hit` (34) is a square hit at the car's own top speed, out of
`max_condition` (100). Three of those is 102, so the third one breaks the car,
and every softer hit is a fraction of one: half the speed is half the cost, and
a scrape along a face costs next to nothing, because it is not a crash. A run
can carry five or six clumsy moments or three bad ones.

It is against the car's own `max_speed`, so a chaos car rolled fast hits no
harder at its top speed than a tuned car does at its own - three flat-out hits
break any car. A car on a pad is over its top speed, though, and pays for it: a
boosted square hit costs about 53. Carrying a pad into a barrier was already the
risk the pad is offered against, and this is that risk counted twice on
purpose.

**What counts** is what already costs speed: bodies in the `obstacle` group,
and nothing else. The rails do not, for the reason they cost no speed - a car
scraping down one is already being put back where it belongs. The grass does
not, landings do not, and running into the other car does not: if ramming did
damage, two players with the setting on would be playing a different game. The
charge sits behind `obstacle_recovery`, so a car held against a face is charged
once per 0.4 s rather than once a step, which would take a single mistake from
full to broken inside a second.

**A checkpoint does not mend a car.** If it did, damage would be something a
player undoes by pressing R. Condition is kept out of `reset_motion` for that
reason, and only `repair` puts it back - which only happens when the car is put
back on the line, for a restart or a new course.

**Breaking** stops the car where it is, in the air if that is where it was:
dropping a car that broke over a jump into the hole under it would be a second
thing happening that the player did nothing to earn.

- **Solo**: the run is over, and sets no time, because the car never finished.
  The panel says BROKEN, the clock where it stopped and how much of the way to
  the flag the car got, and Enter runs again as instantly as it does after a
  finish. The endless course does not roll on by itself afterwards the way it
  does after a finish - a player whose run just ended should see that it did.
- **Two players**: the broken car is out and the other one wins the course
  without having to drive the rest of it. Breaks are settled at the top of the
  step after the cars move, before the finish, so two cars that broke on the
  same step are a draw rather than a win for whichever the physics moved
  first, and a car that broke on the step it reached the line did not finish.

**Nothing about how the car drives changes.** Not its grip, not its top speed,
not its steering, however worn it is. The moment condition touched handling, a
time set with damage on would be a time set in a different car, and
`TrackTimes.GEOMETRY` would have to be bumped - throwing away every time
anyone has set. The check drives the same hit with damage on and off and
compares where the car is on every step.

**Seeing it coming.** A bar under each player's clock, in their own paint, so
on a split screen each reads their own where they already read their time. It
is readable without being counted: once a car is down to `warning_at` (a third)
the bar goes red and flashes white - white as well as red, because a red car's
bar is already red - which is the only warning anyone at 30 m/s has time to
take in, and smoke starts coming off the bonnet, thin at first and thicker the
closer the car is to breaking. Smoke rather than dents, because it works on
a model the game has never seen; `CarShell` places it off the model's own
bounds. With the setting off the bar is not there at all.

Like chaos, none of this reads the setting from the car. The race tells each
car whether it can be hurt, because the title screen backdrop is a race scene
too and nothing behind the menu is being driven.

`tools/checks/damage.gd` drives a car into a wall and a rail built for the
purpose - so every hit is exactly as square and as fast as it says - and then
breaks cars in both race scenes:

```
Godot --path . --headless --fixed-fps 60 --script tools/checks/damage.gd
```

Headless, it ends with one leaked dummy shader at exit. That is the smoke's
material in the dummy renderer, and it is one however many cars have smoked -
a cache not freed on the way out, not a car's worth of anything per race.
