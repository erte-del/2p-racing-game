class_name Blender
extends RefCounted

## Turning a .blend into something the game can read.
##
## Godot imports a .blend by handing it to Blender, and only in the editor. A
## game somebody is playing has no editor, so it does the same thing the editor
## does: finds Blender, runs it headless on the file with a script, and reads
## the .glb that comes out. Everything after that is the path a .glb already
## took, so a car that arrives this way is fitted, painted and checked exactly
## like one somebody exported themselves.
##
## Blender is not shipped with the game and cannot be. It is a separate
## program, and a player who has not got it is told so and pointed at the .glb
## the rest of the game reads perfectly well. This is a convenience, not a
## dependency: nothing else here stops working without it.

## Where a player-chosen Blender is remembered, so it is found once rather
## than every time. A test run keeps its own; see `Sandbox`.
const REMEMBERED := "user://blender.cfg"

## Where the converter is written before it is run. It has to be a real file on
## disk for Blender to open, and `res://` is inside the game in a shipped build.
const SCRIPT_AT := "user://blend_to_glb.py"

## How long a conversion may take before it is given up on, in seconds.
## Generous, because Blender starting up on a cold machine is most of it, and
## nobody watching this is watching anything else.
const TIMEOUT := 180.0

## Where Blender usually is, per platform. Tried in order, and only the ones
## that are actually there are ever run.
const LIKELY := {
	"macOS": [
		"/Applications/Blender.app/Contents/MacOS/Blender",
		"~/Applications/Blender.app/Contents/MacOS/Blender",
	],
	"Linux": [
		"/usr/bin/blender", "/usr/local/bin/blender", "/snap/bin/blender",
		"/var/lib/flatpak/exports/bin/org.blender.Blender",
	],
}

## Windows installs one folder per version, so the folder is listed rather than
## guessed at.
const WINDOWS_FOLDERS := [
	"C:/Program Files/Blender Foundation",
	"C:/Program Files (x86)/Blender Foundation",
]

## The converter, kept here rather than in `tools/` beside the other Blender
## scripts. Those are run by hand on this machine and are deliberately not
## shipped; this one has to be there on the machine of somebody playing the
## game, and the surest way to ship a file is not to have one.
##
## It is not `tools/export_car.py`. That one knows the car it is exporting -
## what its root is called, which way it faces, what its wheels are named -
## because it had one job and one model. This one is handed something nobody
## has seen and has exactly one job: get the meshes out, in one file, at
## whatever size and angle they were modelled at. Making that drivable is the
## game's half, and it already does it for a .glb that arrived any other way.
const CONVERTER := """import sys

import bpy


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    out = argv[0]

    # The same two things the game's own reader throws out: a camera in the
    # file would fight the two the split screen already has, and a light would
    # be a second sun bolted to somebody's bumper.
    for ob in list(bpy.data.objects):
        if ob.type in {"CAMERA", "LIGHT"}:
            bpy.data.objects.remove(ob, do_unlink=True)

    meshes = [o for o in bpy.data.objects
              if o.type in {"MESH", "CURVE", "SURFACE"}]
    if not meshes:
        print("[blend] nothing in this file to look at")
        sys.exit(2)

    # export_apply bakes the modifiers, so what comes out is what was on the
    # screen rather than the cage it was built from. export_yup is what turns
    # Blender's Z-up into the Y-up glTF and Godot both expect.
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB",
                              export_apply=True, export_yup=True)
    print("[blend] wrote %s from %d objects" % (out, len(meshes)))


main()
"""


## Whether there is a Blender on this machine to hand a .blend to.
static func here() -> bool:
	return not found().is_empty()


## Where Blender is, or empty. The one a player pointed at wins: if they went
## and found it, it is the one they meant, even on a machine that has three.
static func found() -> String:
	var chosen := _remembered()
	if not chosen.is_empty() and FileAccess.file_exists(chosen):
		return chosen
	for likely: String in _likely():
		if FileAccess.file_exists(likely):
			return likely
	return ""


## Write down a Blender a player went and found.
static func remember(where: String) -> void:
	var file := ConfigFile.new()
	file.set_value("blender", "path", where)
	file.save(Sandbox.path(REMEMBERED))


## Whether a file a player picked is plausibly Blender, before it is ever run.
##
## Only the name, because that is all that can be known without running it, and
## running an arbitrary file a player pointed at to find out what it is would
## be the whole problem.
static func looks_right(where: String) -> bool:
	var name := where.get_file().to_lower()
	return name.begins_with("blender") and not name.ends_with(".blend")


## Hand a .blend to Blender and wait for the .glb.
##
## Answers {ok, error}. Awaits, so the screen that called it can say what is
## happening rather than freezing while a second program starts up.
static func convert(host: Node, blend: String, out: String) -> Dictionary:
	var exe := found()
	if exe.is_empty():
		return {"ok": false, "error": "Blender was not found on this machine. "
			+ "Point the game at it, or export your model as a .glb instead."}
	if not _write_the_converter():
		return {"ok": false, "error": "The converter could not be written."}
	DirAccess.remove_absolute(ProjectSettings.globalize_path(out))

	# --factory-startup so a player's own preferences and add-ons cannot
	# change what comes out, and --disable-autoexec because a .blend can carry
	# Python that runs when it is opened. This is a file that may have come
	# from a stranger, and none of it is ours to run.
	var pid := OS.create_process(exe, [
		"--factory-startup", "--disable-autoexec",
		"-b", ProjectSettings.globalize_path(blend),
		"--python", ProjectSettings.globalize_path(Sandbox.path(SCRIPT_AT)),
		"--", ProjectSettings.globalize_path(out),
	])
	if pid < 0:
		return {"ok": false, "error": "Blender would not start."}

	# Timed against the clock rather than by adding up frame deltas. A
	# frame delta is what the game thinks a frame took, which is not the
	# same thing at all when the frames are not being paced - a headless
	# run gets through thousands of them a second, and a timeout counted
	# that way kills Blender before it has finished starting up.
	var started := Time.get_ticks_msec()
	while OS.is_process_running(pid):
		await host.get_tree().process_frame
		if Time.get_ticks_msec() - started > int(TIMEOUT * 1000.0):
			OS.kill(pid)
			return {"ok": false, "error": "Blender took more than %d seconds "
				% int(TIMEOUT) + "on that file, so it was given up on."}

	if not FileAccess.file_exists(out):
		return {"ok": false, "error": "Blender opened that file and got no "
			+ "model out of it. Check there is something in the scene."}
	return {"ok": true, "error": ""}


static func _remembered() -> String:
	var file := ConfigFile.new()
	if file.load(Sandbox.path(REMEMBERED)) != OK:
		return ""
	return str(file.get_value("blender", "path", ""))


static func _likely() -> Array:
	var here := OS.get_name()
	if here == "Windows":
		return _windows_installs()
	var home := OS.get_environment("HOME")
	var found: Array = []
	for likely: String in LIKELY.get(here, []):
		found.append(likely.replace("~", home))
	return found


## Windows keeps one folder per version, so they are listed and tried newest
## name first rather than guessed at by number.
static func _windows_installs() -> Array:
	var found: Array = []
	for folder: String in WINDOWS_FOLDERS:
		var versions := DirAccess.get_directories_at(folder)
		versions.reverse()
		for version: String in versions:
			found.append("%s/%s/blender.exe" % [folder, version])
	return found


static func _write_the_converter() -> bool:
	var file := FileAccess.open(Sandbox.path(SCRIPT_AT), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(CONVERTER)
	file.close()
	return true
