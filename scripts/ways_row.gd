class_name WaysRow
extends HBoxContainer

## The ways of driving a track, one button each, held down one at a time:
## NORMAL, HARD, CHAOS, MIRROR, REVERSE, in the order `TrackVariant.ALL` has
## them.
##
## One row for every page that picks a way, rather than one drawn on each. The
## track's own page and the leaderboard both have it, and a player reading
## one board is nearly always about to read the next - so the row has to look
## and behave the same on both, and two copies of it would drift apart.
##
## Each way says what it is before it is read. HARD is written in red. CHAOS
## turns through the colours the way chaos mode's button does, with whatever
## colour it is handed (`track_chaos_colour`), so that every CHAOS on the
## screen is the same colour at once. MIRROR is written mirrored.
##
## Holding a way down is a choice and not a start: `chosen` says which was
## pressed, and whatever the row is on decides what that means.

signal chosen(variant: String)

## How big the words are, and how tall the buttons: set before the row is in
## the tree, since that is when its buttons are made.
@export var font_size := 28
@export var button_height := 64.0
## How far a way the track does not offer is faded. Faded rather than hidden,
## and still pressable: its board is still worth reading, and a row of buttons
## that changes length from track to track is a row a player has to read again
## every time.
@export_range(0.0, 1.0) var unoffered_alpha := 0.4

const HARD_RED := Color(0.95, 0.3, 0.3)
const HARD_LIT := Color(1.0, 0.4, 0.4)

## What each button is called in the tree, so a check can find one by name.
const NAMES := {
	TrackVariant.NORMAL: "Normal",
	TrackVariant.HARD: "Hard",
	TrackVariant.TRACK_CHAOS: "TrackChaos",
	TrackVariant.MIRROR: "Mirror",
	TrackVariant.REVERSE: "Reverse",
}

## The colour CHAOS is wearing. Its own alpha is kept, since that is what says
## whether the track offers it.
var track_chaos_colour := Color.WHITE:
	set(value):
		track_chaos_colour = value
		var chaos := button(TrackVariant.TRACK_CHAOS)
		if chaos != null:
			chaos.modulate = Color(value, chaos.modulate.a)

var _held := TrackVariant.NORMAL


func _ready() -> void:
	add_theme_constant_override("separation", roundi(font_size * 0.5))
	var group := ButtonGroup.new()
	for variant: String in TrackVariant.ALL:
		var way := Button.new()
		way.name = NAMES[variant]
		way.toggle_mode = true
		way.button_group = group
		way.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		way.custom_minimum_size.y = button_height
		way.add_theme_font_size_override("font_size", font_size)
		way.pressed.connect(_on_pressed.bind(variant))
		add_child(way)
		if variant == TrackVariant.MIRROR:
			_write_mirrored(way)
		else:
			way.text = TrackVariant.display_name(variant)
		if variant == TrackVariant.HARD:
			way.add_theme_color_override("font_color", HARD_RED)
			for state in ["font_hover_color", "font_focus_color", "font_pressed_color",
					"font_hover_pressed_color"]:
				way.add_theme_color_override(state, HARD_LIT)
	button(_held).button_pressed = true


func _process(_delta: float) -> void:
	# A label does not know it is inside a button, so it is told which of the
	# button's colours to wear: the same word a plain button would show.
	var mirror := button(TrackVariant.MIRROR)
	var state := "font_color"
	if mirror.button_pressed:
		state = "font_pressed_color"
	elif mirror.has_focus():
		state = "font_focus_color"
	elif mirror.is_hovered():
		state = "font_hover_color"
	(mirror.get_node("Word") as Label).add_theme_color_override("font_color",
		mirror.get_theme_color(state))


## MIRROR written mirrored, flipped left to right about its own middle so it
## reads the way the word would in a mirror. It is a label inside the button
## rather than the button's own text, because the row a button sits in puts
## its scale back to one every time it lays it out; nothing lays out a label
## hung inside a button. The middle moves whenever the button is resized, so it
## is re-centred then rather than set once.
func _write_mirrored(way: Button) -> void:
	var word := Label.new()
	word.name = "Word"
	word.text = TrackVariant.display_name(TrackVariant.MIRROR)
	word.set_anchors_preset(Control.PRESET_FULL_RECT)
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	word.add_theme_font_size_override("font_size", font_size)
	word.scale.x = -1.0
	word.resized.connect(func() -> void: word.pivot_offset = word.size * 0.5)
	way.add_child(word)
	# And the button is held to the width the word needs, as a button with its
	# own text would be. A button with no text of its own asks for next to no
	# room, so in a row that is short of it this one was the one squeezed, with
	# its word spilling over the buttons either side.
	way.custom_minimum_size.x = (word.get_minimum_size().x
		+ way.get_theme_stylebox("normal").get_minimum_size().x)


func _on_pressed(variant: String) -> void:
	if variant == _held:
		return
	_held = variant
	chosen.emit(variant)


## The button for a way.
func button(variant: String) -> Button:
	return get_node_or_null(NAMES.get(variant, "")) as Button


## The way held down.
func held() -> String:
	return _held


## Hold a way down without saying so: the page asking for it already knows.
func hold(variant: String) -> void:
	_held = variant
	button(variant).button_pressed = true


## Set the row out for a track. An acrobatic track is driven NORMAL or MIRROR
## and nothing else, so the rest are not shown at all: HARD would stand
## barriers on its landings, and track chaos would roll them there, and a
## barrier on a landing is a much meaner thing than one on a straight. Rings,
## platforms, lifts and high roads are all aimed at where a ramp throws a car,
## so none of them has a reverse either. Every other way the track does not
## offer is faded.
func show_for(track_file: String) -> void:
	var acrobatic := (TrackRoster.kind_of(TrackRoster.index_of(track_file))
		== TrackRoster.ACROBATIC)
	var offered := TrackVariant.offered(track_file)
	for variant: String in TrackVariant.ALL:
		var way := button(variant)
		way.visible = not acrobatic or variant in [TrackVariant.NORMAL, TrackVariant.MIRROR]
		way.modulate.a = 1.0 if variant in offered else unoffered_alpha
