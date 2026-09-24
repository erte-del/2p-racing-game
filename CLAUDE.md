# Working on this project

`README.md` is the design document: what the game does and why it is built the
way it is. This file is the other half - where the tools are on this machine
and how to run them. Anything about the game itself belongs in the README.

## Godot

Godot 4.7.2 is installed on the Desktop rather than in `/Applications`, so it
is not on `PATH` and `which godot` finds nothing:

```
/Users/erselinankul/Desktop/Godot.app/Contents/MacOS/Godot
```

The README writes every command as `Godot --path . ...`. Either put that binary
on `PATH` first, or spell the path out in full:

```bash
/Users/erselinankul/Desktop/Godot.app/Contents/MacOS/Godot --path . --headless --script tools/checks/screen_fit.gd
```

Export templates for 4.7.2 are already installed, under
`~/Library/Application Support/Godot/export_templates/4.7.2.stable/`.

## Running the checks

Everything under `tools/checks/` is a `SceneTree` script run with `--script`.
The README gives the command for each one beside the thing it checks. Three
things are worth knowing before writing or running any of them.

**Headless or not.** A check that only looks at numbers takes `--headless`. A
check that takes a screenshot must not: it needs a real renderer. The ones that
save images take the output directory as a user argument, after a bare `--`:

```bash
/Users/erselinankul/Desktop/Godot.app/Contents/MacOS/Godot --path . --script tools/checks/settings_shot.gd -- /tmp/shots
```

**Autoloads are not identifiers in a `--script` file.** Replacing the main loop
compiles that one script before the autoloads are registered, so naming
`GameSettings`, `Garage`, `Purse` or any other autoload directly is a compile
error - *in the check script only*. Every other script in the project is loaded
afterwards and may say them as usual.

Do not reach for `preload` to get around it. Having an autoload's script loaded
before the autoloads are set up leaves `GameSettings` and `Garage` as bare
`Node`s with no script on them, and then the pages that lean on them fail to
*open* rather than failing to fit - which a check that only measures what is on
the screen will happily call a pass. Use `load()` at run time, after the first
`await process_frame`, or go at the property directly:
`root.content_scale_factor` rather than `GameSettings.ui_scale`. The comment on
`SETTINGS_PATH` in `tools/checks/screen_fit.gd` is the worked example.

**Checks never touch a real garage.** Anything under `tools/` that runs the
game keeps its files in `user://sandbox/` - see `Sandbox` - so settings, times
and added cars from a check cannot reach the ones a player has.

## Sizes and the screen

Every size in the interface is a number in a 1600x900 space that Godot stretches
to fill the window, plus the player's own `GameSettings.ui_scale` on top. Nothing
reads the resolution of the display to pick a size, and nothing should: the
stretch already makes every size proportional to the screen. To make the whole
interface bigger or smaller, move the reference in `project.godot` - not the
numbers in the pages. `## Screen sizes` in the README is the full account.

After changing anything about a menu's size or layout, run:

```bash
/Users/erselinankul/Desktop/Godot.app/Contents/MacOS/Godot --path . --headless --script tools/checks/screen_fit.gd
```

It opens every page at five window shapes and fails if one runs off the edge.
It checks at the largest interface size a player can pick, because that is the
tightest the screen ever gets. Watch for `SCRIPT ERROR` in its output as well
as the fault count: a page that failed to open still prints no fault.

## Prose

The README and the doc comments carry the reasoning, in plain sentences, and
say why a thing is the way it is rather than restating what the code does. When
a number or a behaviour changes, the sentence describing it changes in the same
pass - a stale explanation is worse than none. Check for old numbers left
behind elsewhere:

```bash
grep -rn "1280\|720" README.md scripts/ tools/
```
