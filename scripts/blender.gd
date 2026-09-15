class_name Blender
extends RefCounted

## Turning a .blend into a car, by asking Blender to do it.
##
## Godot reads .blend files only in the editor, and even there it does not
## read them itself: it hands the file to the Blender on the machine, asks for
## a glTF back, and imports that. A shipped game has no editor, so the game
## does what the editor does - finds Blender, hands it the file, and takes the
## .glb that comes back through the same door as any other.
##
## A .blend is a program as much as a file. It can carry Python that runs the
## moment it is opened, and this one came from a stranger, so Blender is
## started with that switched off and with none of the player's own add-ons or
## preferences either. Nothing in the file is ever run - only Blender's own
## exporter, told what to do by a script this game wrote.

## Where a Blender the player went and found is remembered. It wins over every
## usual place, because it is the one the player actually pointed at.
const CONFIG_PATH := "user://blender.cfg"
## Where the converter is written before Blender is asked to run it. It is kept
## here as a string rather than as a file in `tools/`, because `tools/` does not
## ship and a converter the shipped game cannot find converts nothing.
const SCRIPT_PATH := "user://blend_to_glb.py"
## How long Blender gets, in seconds. Minutes, because a first run of Blender
## on a slow machine can spend most of one just starting.
const TIMEOUT := 180.0
## What the converter exits with when there is nothing in the file to export.
const NOTHING_TO_EXPORT := 2

const CONVERTER := """# Written by the game, and run by Blender to turn one .blend into one .glb.
import sys
import bpy

out = sys.argv[sys.argv.index("--") + 1]

# A camera or a light would only be stripped out again on the way in.
for thing in list(bpy.data.objects):
    if thing.type in {"CAMERA", "LIGHT"}:
        bpy.data.objects.remove(thing, do_unlink=True)

if not any(thing.type in {"MESH", "CURVE", "SURFACE"} for thing in bpy.data.objects):
    sys.exit(2)

bpy.ops.export_scene.gltf(
    filepath=out,
    export_format="GLB",
    export_apply=True,
    export_yup=True,
)
"""


## The Blender to use, or an empty string when there is none to be found.
static func found() -> String:
	var remembered := _remembered()
	if not remembered.is_empty() and FileAccess.file_exists(remembered):
		return remembered
	for place in _usual_places():
		if FileAccess.file_exists(place):
			return place
	return ""


## Whether there is a Blender to hand a .blend to.
static func here() -> bool:
	return not found().is_empty()


## Whether a file is plausibly Blender, judged by its name alone.
##
## By name before it is ever run, because running an arbitrary file to find
## out what it is would be the whole of the problem. A program called blender
## something with no extension, `.exe` or `.app` passes; a .blend - the thing
## the player was probably looking at a moment ago - does not, and nor does a
## script that merely has blender in its name.
##
## A version number after a dot counts as no extension at all. `blender-5.2`
## is how a great many Linux machines name it, and what the file name calls
## its extension there is a 2.
static func looks_right(path: String) -> bool:
	var name := path.get_file().to_lower()
	if not name.begins_with("blender"):
		return false
	var extension := path.get_extension().to_lower()
	return extension in ["", "exe", "app"] or extension.is_valid_int()


## Remember a Blender the player pointed at. False, and nothing remembered, if
## it does not look like Blender or is not there.
static func remember(path: String) -> bool:
	var program := _inside_the_bundle(path)
	if not looks_right(program) or not FileAccess.file_exists(program):
		return false
	var file := ConfigFile.new()
	file.set_value("blender", "path", program)
	return file.save(Sandbox.path(CONFIG_PATH)) == OK


## Have Blender turn `blend` into a .glb at `out`.
##
## Awaited: Blender runs as a separate program and the game keeps drawing while
## it does. How long it has been going is measured on the clock rather than by
## adding up frames, because a headless run does thousands of frames a second
## and a timeout counted in frame time would kill Blender before it started.
##
## Answers `{ok, error}`. The .glb it leaves is not trusted for having come
## from Blender - it goes through `CarImport` like everything else.
static func convert(host: Node, blend: String, out: String) -> Dictionary:
	var blender := found()
	if blender.is_empty():
		return _problem("Blender is not on this machine, so a .blend cannot be "
			+ "turned into a car. Export it from Blender as a .glb and add that.")
	var source := ProjectSettings.globalize_path(blend)
	# Blender reads anything starting with a dash as one of its own switches,
	# so only a full path is ever handed over as the file.
	if not source.is_absolute_path() or not FileAccess.file_exists(source):
		return _problem("That .blend is not there any more.")

	var script := Sandbox.path(SCRIPT_PATH)
	var writing := FileAccess.open(script, FileAccess.WRITE)
	if writing == null:
		return _problem("The converter for Blender could not be written.")
	writing.store_string(CONVERTER)
	writing.close()

	var target := ProjectSettings.globalize_path(out)
	# Whatever an earlier conversion left there is not this file's car.
	DirAccess.remove_absolute(target)

	var arguments := PackedStringArray([
		"-b",
		# None of the player's own add-ons or preferences, which could change
		# what comes out - and none of anything they might have installed.
		"--factory-startup",
		# The file came from somebody else, and a .blend can carry Python that
		# runs as it opens. Not in this game.
		"--disable-autoexec",
		source,
		# A converter that fails part way reports it rather than exiting as
		# though it had finished.
		"--python-exit-code", "1",
		"--python", ProjectSettings.globalize_path(script),
		"--", target,
	])
	var pid := OS.create_process(blender, arguments)
	if pid <= 0:
		return _problem("Blender would not start.")

	var started := Time.get_ticks_msec()
	while OS.is_process_running(pid):
		if Time.get_ticks_msec() - started > TIMEOUT * 1000.0:
			OS.kill(pid)
			return _problem("Blender took too long over that file, and was stopped.")
		await host.get_tree().process_frame

	var code := OS.get_process_exit_code(pid)
	if code == NOTHING_TO_EXPORT:
		return _problem("There is nothing in that .blend that could be a car.")
	if not FileAccess.file_exists(target):
		return _problem("Blender did not make a model out of that file.")
	return {"ok": true, "error": ""}


## Where Blender usually is, newest first where there is more than one.
static func _usual_places() -> PackedStringArray:
	var places := PackedStringArray()
	var home := OS.get_environment("HOME")
	match OS.get_name():
		"macOS":
			places.append("/Applications/Blender.app/Contents/MacOS/Blender")
			places.append(home + "/Applications/Blender.app/Contents/MacOS/Blender")
		"Windows":
			for root in ["C:/Program Files/Blender Foundation",
					"C:/Program Files (x86)/Blender Foundation"]:
				var versions := Array(DirAccess.get_directories_at(root))
				versions.sort()
				versions.reverse()
				for version: String in versions:
					places.append("%s/%s/blender.exe" % [root, version])
		_:
			places.append("/usr/bin/blender")
			places.append("/usr/local/bin/blender")
			places.append("/snap/bin/blender")
			places.append("/var/lib/flatpak/exports/bin/org.blender.Blender")
			places.append(home + "/.local/share/flatpak/exports/bin/org.blender.Blender")
	return places


static func _remembered() -> String:
	var file := ConfigFile.new()
	if file.load(Sandbox.path(CONFIG_PATH)) != OK:
		return ""
	return str(file.get_value("blender", "path", ""))


## On a Mac, Blender is a folder that looks like a file. A player who picks
## Blender.app has picked the right thing, and the program is inside it.
static func _inside_the_bundle(path: String) -> String:
	if path.get_extension().to_lower() == "app":
		return path.path_join("Contents/MacOS/Blender")
	return path


static func _problem(why: String) -> Dictionary:
	return {"ok": false, "error": why}
