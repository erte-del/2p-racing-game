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
tracks/           the twenty laid-out tracks, one file each
tools/            Blender export scripts and the checks (not shipped)
backend/          the server side: the schema, the setup, the emails
```

`backend/` holds no code that runs in the game. It is the SQL that builds the
two tables the leaderboards live in, the notes for standing a project up, and
the two pages a confirmation email needs. The game's half of that is three
scripts in `scripts/` like any other.

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

Under Play sit Garage, Settings and Account, and Account is there only when
there is a server to talk to. A build with no `backend.cfg` in it does not grow
a button that cannot do anything - the same reason the Leaderboard button on
the track page is not always there either. The four are stacked from 60% of the
way down, so all of them are above the bottom edge of a 720-tall window when
Account is showing.

Garage opens the same garage the pause menu does, lying over the title. The
title is the best place there is to look at a car: the two on the grid are
dressed from the same setting a race reads, and the camera is already turning
slowly round them, so picking a car changes the one being circled.

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
refused under chaos, for the same reason chaos leaves the model alone. Like the
paint screen a tile puts the player in its car the moment it is pressed,
because the car is right there on the road behind the panel and seeing it is
the only way to know it is the one you wanted. The car each player is in is
held down, with the same thick pale border the paint screen puts round a
chosen paint.

Each player has a row - player one above, player two below, and one row when
driving alone - and each row is split by where a car came from. OFFICIAL, on
the left, is the cars the game came with: one column wide, centred under its
heading, and built from a single `_official_listing()`, so a second shipped car
is a second line there and nothing else changes. UNOFFICIAL, on the right, is
every car anybody has added, whether it was picked off this disk or downloaded
from someone else. The line is drawn where it can be trusted: what ships is in
the build and everything else is in `user://`, and nothing a stranger shares
can put a car on the official side. An unofficial half with nothing in it says
nothing has been added yet, rather than sitting empty like a half that failed
to draw.

Two rows of tiles, the buttons and BACK all have to fit a 720-tall window, and
that is the whole budget the page is laid out to. The heading's two notes are
one line, each half's heading and what it means are one line, and the tiles are
134 tall.

The width was never the problem, and at first it went unspent: tiles 200 wide,
two across, made a panel 750 wide on a 1280 screen, with a third of the window
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

`tools/checks/tilt_trace.gd` drives a car over a jump, which has every case in
it in order - level road, a ramp, the nose coming up off the lip, the nose
dropping through the top of the flight, and the road again on landing - and
then over a plain climb:

```
Godot --path . --headless --script tools/checks/tilt_trace.gd
```

Level road reads 0.0 degrees, the ramp +24.1, the fall -27.9, and a 2.9 degree
climb reads +3.4.

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
another. The driver's eye goes where the body takes it but keeps only `eye_roll`
of its roll, which is none, for the reason Views gives.

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

Backing out walks the way in, in reverse: the track grid, the flavours, the
modes, then the page.

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

Under the grid, above Back, is Leaderboard. It opens on whichever track the
cursor is sitting on, worked out from what currently holds focus rather than
remembered, so it cannot go stale. That is one page with the track picked
inside it rather than a board hung off each of the twenty cells: a player
looking at one board is nearly always about to look at the next, and a page
they have to back out of and come back into twenty times is a page they look
at once.

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

`TrackTimes` also knows a track by a second name. `fingerprint()` is the
engine's own hash and is what decides whether this machine's record still
stands; `signature()` is sha256 over the same material and is what a shared
board is keyed on. The difference matters only when a time leaves the machine
it was set on: a board has to agree across a Mac, a Windows box and next
year's Godot, and an engine hash promises none of that.

`adopt()` is `record()` without the announcement. It takes a time that was set
somewhere else - the same player, on their other machine - and keeps it if it
is better. It is deliberately not `record()`: what comes back off a server is
not a run that just happened here, and treating it as one would declare a new
best in the middle of the menu and send it straight back where it came from.

`tools/checks/track_times.gd` sets times, closes the game and sees what is
still there, then edits a track and sees that the time on the old one has gone.
It writes to a scratch file, so running it does not touch anyone's own record:

```
Godot --path . --headless --script tools/checks/track_times.gd
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
that it is the same bad lap everywhere: on First Light it comes home in 34.62,
against the 33 the track asks for gold. Gold is a little under the best the
road allows, silver and bronze are spaced further apart the harder the track
gets, and the whole ladder is set from that one ratio.

## Adding a track

Everything a track needs is in place, so adding a twenty-first is three steps
and no code:

1. Write `tracks/NN_name.gd` extending `TrackDefinition`, set its `medals()`,
   and check it with `tools/checks/track_check.gd` and
   `tools/checks/track_map.gd`.
2. Add its path to `TrackRoster.FILES`, in the order it should appear.
3. Run `tools/track_thumbnails.gd` to draw its overhead shot.

The name on the button, the slot in the grid, the times, the solo race and the
checks all follow from those.

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
one that is meant to hold still, and then that none of it happens in a race
that is not chaotic:

```
Godot --path . --headless --fixed-fps 60 --script tools/checks/chaos_colour.gd
```
