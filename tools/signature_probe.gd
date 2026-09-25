extends Node

## Prints every track's signature from inside an exported game, then quits.
##
## An exported game will not run a `--script`, so this goes in as an autoload
## instead, through an `override.cfg` beside the binary (see Exported builds in
## the README). What it prints has to match what
## `tools/checks/track_sources.gd` prints in the editor, line for line.
##
## Run it with `-- --sandbox`. Added this way it is not on the command line for
## `Sandbox` to notice, and an export shares its `user://` with the editor: a
## build that cannot read its tracks, left unsandboxed, drops every time in the
## real record the moment the title screen asks about one.


func _ready() -> void:
	await get_tree().process_frame
	var times: Node = get_node(^"/root/TrackTimes")
	for file: String in TrackRoster.all_files():
		print("%s %s" % [file.get_file().get_basename(), times.signature(file)])
	get_tree().quit()
