@tool
extends EditorPlugin

## Puts a copy of every track's text into an exported game.
##
## A track is known across machines by a hash of its file (see
## `TrackTimes.signature`), and a leaderboard is keyed on that hash. An export
## does not ship a script as it is written: it ships the compiled tokens, under
## another name, and the file the hash is taken over is simply not in the pack.
## Without this a release has no text to hash, no signature, and so nothing it
## can post or read a board by - while the editor, which reads the file as
## written, works perfectly. The copy goes in beside the compiled track, and
## `TrackTimes` reads it wherever the track itself cannot be read.

var _export: EditorExportPlugin


func _enter_tree() -> void:
	_export = TrackSourceExport.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null


class TrackSourceExport extends EditorExportPlugin:
	## Kept as one string in `TrackTimes`, which is the thing that reads it back.
	const TrackTimes := preload("res://scripts/track_times.gd")

	func _get_name() -> String:
		return "TrackSources"

	## Done once at the start rather than file by file as each track goes past.
	## Godot's own script exporter comes first, takes every `.gd` out of the
	## export to put the compiled one in, and a file taken out is not shown to
	## any exporter after it - so a hook on each file never sees a track.
	func _export_begin(_features: PackedStringArray, _is_debug: bool,
			_path: String, _flags: int) -> void:
		for file: String in TrackRoster.all_files():
			# The track still goes in compiled, the way every other script
			# does. This only adds its text alongside.
			add_file(file + TrackTimes.SHIPPED_SOURCE,
				FileAccess.get_file_as_bytes(file), false)
