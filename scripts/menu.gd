class_name Menu
extends Control

## The title screen: the name of the game, a button to start it and a button
## to change the settings, over the game itself.
##
## Play does not drop straight into a race. It opens one page that asks two
## things in order, without ever becoming a second page.
##
## How many are playing comes first, as two buttons side by side, because it
## is the one choice that changes what every other choice means: the same
## endless course is a race against someone in co-op and a run against the
## clock alone, and the same laid-out track is a time to beat alone and a road
## to race down together. It is also the only choice that decides which scene
## the race runs in; everything after it is a setting that scene reads.
##
## Answering it rolls the modes out from underneath, from the middle of the
## page rather than from under whichever of the two was pressed - what opened
## is the rest of the page, not a drawer belonging to one button. The two stay
## where they are with the answer showing on them, so a player can change
## their mind without going back anywhere.
##
## Coming back from a track opens on the grid of tracks rather than on the
## title. A player who has just driven one is nearly always about to drive
## another, or the same one again, and making them walk back in through two
## pages to do it is asking them to say something they have already said.
##
## Inside that, Infinite does not start a race either: it opens out in turn,
## sliding the choice between a normal race and a chaotic one down from under
## itself, and it is that click that starts the game. Asking one question at a
## time keeps the page down to what is actually being decided at that moment,
## and a slide inside a slide costs nothing because the outer one is told to
## follow its own contents rather than a height written down when it opened.
##
## What rolls out is the two buttons and nothing else. The line under Infinite
## stays where it is and is pushed down by them, the same as everything below
## it: it describes the mode rather than the choice, so it is as true before
## the buttons are there as after, and a page where half the words appear on a
## click reads as a page that was hiding something.
##
## Each of those lines is pulled back up towards what it describes. The page is
## one column with one spacing between everything in it, which is right between
## a button and the next button and far too much between a button and its own
## description - a line that far under a button reads as a separate thing
## rather than as part of it. They ride in margins with a negative top instead,
## which closes that one gap without touching any of the others.
##
## What chaos actually does lives in `Chaos`; all that is settled here is
## which of the two the players picked.
##
## The backdrop is a real instance of the race scene in attract mode - the same
## generated course, scenery and day/night cycle the players are about to
## drive, with two cars parked on the grid - turning slowly under the title.
## Being the real thing rather than a picture means it can never go stale.
##
## The title never sits perfectly still either. It rocks and bobs gently, which
## is what keeps a screen that is doing nothing from looking frozen.

## The scene the endless course runs in, and the one a laid-out track does.
## A track is driven alone against the clock, which is a different scene from
## two players racing each other rather than that scene with a seat empty.
@export_file("*.tscn") var race_scene := "res://scenes/main.tscn"
@export_file("*.tscn") var solo_scene := "res://scenes/solo.tscn"

@export_group("Backdrop")
## How fast the view turns about the cars, in degrees per second. A full
## circuit at 4 deg/s takes a minute and a half, which reads as drifting rather
## than as a turntable.
@export var orbit_speed := 4.0
## How far out and how high the camera sits, in metres.
@export var orbit_radius := 16.0
@export var orbit_height := 5.0
## Where the camera aims, above the point it is turning about.
@export var look_height := 1.4
## Where it starts, in degrees, so the cars open side on rather than tail on.
@export var orbit_start := 55.0

@export_group("Idle motion")
## How far the title rocks either side of upright, in degrees.
@export var tilt_degrees := 2.5
## How long one rock across and back takes, in seconds.
@export var tilt_period := 2.6
## How far it bobs, in pixels.
@export var bounce_pixels := 7.0
## Deliberately not a multiple of the rock: two motions on the same beat read
## as one mechanical wobble, while two that drift apart read as idling.
@export var bounce_period := 1.7

@export_group("Track choice")
## How big the overhead shot on a track button is, in pixels. Five of them
## across is what decides how wide the page comes out.
@export var track_button_size := 152.0

@export_group("Chaos")
## The chaos button never settles on a colour. Everything else on the page
## says what it is in words; this one also says it by refusing to sit still,
## which is the only thing on the screen that behaves the way the mode does.
##
## How long one turn through the colours takes. Slow: the point is a button
## that is never quite the colour it was, not one that flashes.
@export var chaos_cycle_seconds := 7.0
## How far the colour is pushed. Held well under full, because this tints the
## whole button - its dark face, its border and the word on it - and a strong
## tint takes the word with it.
@export_range(0.0, 1.0) var chaos_tint := 0.5

@export_group("Mode choice")
## How long the flavour buttons take to roll out from under infinite. Long
## enough to read as movement, short enough that a player who knows what they
## want is not waiting on it.
@export var slide_seconds := 0.22

@onready var _title: Label = $TitleSlot/Title
@onready var _play: Button = $Play
@onready var _settings_button: Button = $Settings
@onready var _settings_screen: SettingsMenu = $SettingsScreen
@onready var _account_button: Button = $Account
@onready var _account_screen: AccountMenu = $AccountScreen
@onready var _boards_button: Button = $TrackChoice/Page/Panel/Margin/Box/Boards
@onready var _boards_screen: LeaderboardMenu = $LeaderboardScreen
@onready var _mode_choice: Control = $ModeChoice
@onready var _alone_button: Button = $ModeChoice/Page/Panel/Margin/Box/Players/Alone
@onready var _together_button: Button = $ModeChoice/Page/Panel/Margin/Box/Players/Together
@onready var _mode_slot: Control = $ModeChoice/Page/Panel/Margin/Box/ModeSlot
@onready var _mode_inner: Control = $ModeChoice/Page/Panel/Margin/Box/ModeSlot/Inner
@onready var _infinite_button: Button = $ModeChoice/Page/Panel/Margin/Box/ModeSlot/Inner/Infinite
@onready var _mode_back: Button = $ModeChoice/Page/Panel/Margin/Box/Back
@onready var _flavour_slot: Control = $ModeChoice/Page/Panel/Margin/Box/ModeSlot/Inner/FlavourSlot
@onready var _flavour_inner: Control = $ModeChoice/Page/Panel/Margin/Box/ModeSlot/Inner/FlavourSlot/Inner
@onready var _normal_button: Button = $ModeChoice/Page/Panel/Margin/Box/ModeSlot/Inner/FlavourSlot/Inner/Row/Normal
@onready var _chaos_button: Button = $ModeChoice/Page/Panel/Margin/Box/ModeSlot/Inner/FlavourSlot/Inner/Row/Chaos
@onready var _tracks_button: Button = $ModeChoice/Page/Panel/Margin/Box/ModeSlot/Inner/Tracks
@onready var _track_choice: Control = $TrackChoice
@onready var _track_grid: GridContainer = $TrackChoice/Page/Panel/Margin/Box/Scroll/Grid
@onready var _track_back: Button = $TrackChoice/Page/Panel/Margin/Box/Back
@onready var _world: Node3D = $World
@onready var _orbit: Camera3D = $Orbit

var _elapsed := 0.0
var _flavour_tween: Tween
var _mode_tween: Tween
## True once one of the two has been picked and the modes have rolled out.
## While that is so, the slot is held to the height of its own contents, which
## is what lets the flavour buttons slide inside it and push it open further.
var _modes_open := false


func _ready() -> void:
	_play.pressed.connect(_on_play_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_settings_screen.closed.connect(_on_settings_closed)
	_alone_button.pressed.connect(_choose_players.bind(true))
	_together_button.pressed.connect(_choose_players.bind(false))
	_infinite_button.pressed.connect(_on_infinite_pressed)
	_mode_back.pressed.connect(_close_mode_choice)
	_normal_button.pressed.connect(_start_infinite.bind(false))
	_chaos_button.pressed.connect(_start_infinite.bind(true))
	_tracks_button.pressed.connect(_on_tracks_pressed)
	_track_back.pressed.connect(_close_track_choice)
	_account_button.pressed.connect(_on_account_pressed)
	_account_screen.closed.connect(_on_account_closed)
	_boards_button.pressed.connect(_on_boards_pressed)
	_boards_screen.closed.connect(_on_boards_closed)
	# A time pulled down off the server is a time this screen is showing the
	# old version of, so the grid is rebuilt when the sync moves one.
	Leaderboard.times_changed.connect(_on_times_changed)
	# A build with no server in it should not grow a button that cannot do
	# anything, or a board that is always empty.
	_account_button.visible = Leaderboard.available()
	_boards_button.visible = Leaderboard.available()
	_fill_the_track_grid()
	# The slots are plain Controls, so nothing lays their contents out but this.
	_flavour_slot.resized.connect(_fit_flavour)
	_mode_slot.resized.connect(_fit_modes)
	# So the keyboard alone can start the game - both players are on one
	# keyboard, and neither has been asked to find the mouse yet.
	_play.grab_focus()
	_open_where_they_left_off()


## A track is still picked if the player came here from one, since nothing
## clears that but starting an infinite race. So it is also how this screen
## knows to open on the grid, and which track to put the cursor back on.
func _open_where_they_left_off() -> void:
	if GameSettings.track_file.is_empty():
		return
	# The page it came in through is opened behind it, already answered, so
	# backing out of the grid walks the same way out that a player walked in.
	_open_mode_choice()
	_choose_players(GameSettings.solo)
	_on_tracks_pressed()
	_focus_track(TrackRoster.index_of(GameSettings.track_file))


func _process(delta: float) -> void:
	_elapsed += delta
	_turn_the_backdrop()
	# The pivot has to be re-centred every frame: the label's size is not known
	# until it has been laid out, and it changes with the window.
	_title.pivot_offset = _title.size * 0.5
	_title.rotation = deg_to_rad(
		tilt_degrees * sin(TAU * _elapsed / tilt_period))
	# The label rides inside a slot that the layout positions, so its own
	# resting position is always zero. Bobbing it from a captured position
	# would drift, and would be wrong again the moment the window resized.
	_title.position = Vector2(
		0.0, bounce_pixels * sin(TAU * _elapsed / bounce_period))
	# Modulate rather than a stylebox, so one line covers the button in every
	# state it has. Overriding its face would leave it plain the moment it was
	# hovered or focused, which is most of the time it is on the screen.
	_chaos_button.modulate = Color.from_hsv(
		fmod(_elapsed / chaos_cycle_seconds, 1.0), chaos_tint, 1.0)
	# While the modes are out, the slot holding them is exactly as tall as
	# they are. That is what lets the flavour buttons slide out inside it: the
	# inner grows as they roll down, and the slot grows with it, instead of
	# clipping them against a height that was measured before they existed.
	if _modes_open and (_mode_tween == null or not _mode_tween.is_running()):
		_mode_slot.custom_minimum_size.y = _mode_inner.get_combined_minimum_size().y


## Swing the camera round the parked cars. The centre is asked for every frame
## rather than taken once: the backdrop generates its own course, and the grid
## is wherever that course happens to start.
func _turn_the_backdrop() -> void:
	var centre: Vector3 = _world.grid_centre()
	var angle := deg_to_rad(orbit_start + orbit_speed * _elapsed)
	_orbit.global_position = centre + Vector3(
		sin(angle) * orbit_radius, orbit_height, cos(angle) * orbit_radius)
	_orbit.look_at(centre + Vector3.UP * look_height, Vector3.UP)


## Play opens the mode choice over the title rather than starting a race, so
## the backdrop keeps turning behind it the way the settings do.
func _on_play_pressed() -> void:
	_open_mode_choice()


## The page as it opens: the two of them side by side, neither answered, and
## the modes rolled away underneath. Always opens closed, however it was left
## last time, because the question at the top is being asked again.
func _open_mode_choice() -> void:
	_shut_flavour()
	_shut_modes()
	_alone_button.button_pressed = false
	_together_button.button_pressed = false
	_mode_choice.show()
	# On whichever way they played last, so a player who always plays alone
	# presses the same key twice every time.
	if GameSettings.solo:
		_alone_button.grab_focus()
	else:
		_together_button.grab_focus()


## How many are playing. Answering rolls the modes out; answering again with
## the other one leaves them out and simply changes the answer, since nothing
## below depends on which of the two it was.
func _choose_players(solo: bool) -> void:
	GameSettings.solo = solo
	GameSettings.save_settings()
	# Held down rather than merely pressed, so the page goes on saying which
	# way this race is being played while the rest of it is decided.
	_alone_button.button_pressed = solo
	_together_button.button_pressed = not solo
	if not _modes_open:
		_slide_modes(true)
		_infinite_button.grab_focus()


## Infinite is a door rather than a start: it opens out into the choice
## between a normal race and a chaotic one, and closes again if pressed a
## second time.
func _on_infinite_pressed() -> void:
	if _flavour_slot.visible:
		_slide_flavour(false)
		_infinite_button.grab_focus()
	else:
		_slide_flavour(true)
		_normal_button.grab_focus()


func _start_infinite(chaos: bool) -> void:
	# Cleared, or an infinite race started after a track had been played would
	# run that track over and over.
	GameSettings.track_file = ""
	GameSettings.chaos = chaos
	# Settled at the start of the race rather than on every press, so opening
	# and closing the choice is not a file write per click.
	GameSettings.save_settings()
	get_tree().change_scene_to_file(_scene_for_the_players())


# --- choosing a track ---------------------------------------------------

## One cell per track the game intends to have, not per track it has.
##
## A slot with nothing in it is still shown, greyed and unpressable, because
## nineteen doors that do not open yet say what the game is going to be. A
## short grid that grew every few weeks would say nothing at all.
##
## Built here rather than in the scene: twenty cells is a great deal of scene
## to write down, and every one of them would have to be edited again the day
## a track was added.
func _fill_the_track_grid() -> void:
	for index in TrackRoster.COUNT:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 4)

		var label := Label.new()
		label.text = TrackRoster.track_name(index).to_upper()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# Clipped rather than allowed to set the width of its column: one long
		# name would otherwise stretch the whole grid out around it.
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.clip_text = true
		label.custom_minimum_size.x = track_button_size
		label.add_theme_font_size_override("font_size", 18)
		if not TrackRoster.exists(index):
			label.add_theme_color_override("font_color", Color(0.55, 0.58, 0.66))
		cell.add_child(label)

		var button := Button.new()
		button.custom_minimum_size = Vector2(track_button_size, track_button_size)
		button.expand_icon = true
		button.icon = TrackRoster.thumbnail(index)
		button.disabled = not TrackRoster.exists(index)
		if button.disabled:
			# The theme greys a disabled button until it disappears into the
			# page, which reads as a hole rather than as a track still to
			# come. An empty slot gets its own frame instead: dark, outlined,
			# and plainly a place where something goes.
			button.add_theme_stylebox_override("disabled", _empty_slot())
		button.tooltip_text = _what_it_asks(index)
		if not button.disabled:
			button.pressed.connect(_start_track.bind(TrackRoster.file(index)))
		cell.add_child(button)

		# A bar of the medal's colour directly under the picture. Colouring
		# the time alone was not enough: against a dark panel a silver time
		# and a time worth nothing are two shades of pale, and a medal that
		# has to be compared with its neighbours to be seen is not one.
		var medal := Medal.NONE
		if TrackRoster.exists(index):
			var standing := TrackTimes.best(TrackRoster.file(index))
			medal = Medal.earned(standing, TrackRoster.targets(index))
		var rule := ColorRect.new()
		rule.custom_minimum_size = Vector2(track_button_size, 5)
		rule.color = Medal.colour(medal)
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rule.visible = medal != Medal.NONE
		cell.add_child(rule)

		# The time under the picture, because it is the thing that changes.
		# A track with no time to its name says so rather than showing a dash:
		# there is a difference between a road nobody has finished and one
		# that is not built.
		var time := Label.new()
		time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		time.custom_minimum_size.x = track_button_size
		time.clip_text = true
		time.add_theme_font_size_override("font_size", 20)
		var best := TrackTimes.best(TrackRoster.file(index)) if TrackRoster.exists(index) else -1.0
		if best >= 0.0:
			# Coloured to match the bar rather than spelled out. A cell this
			# size has room for a number or for a word, and the number is the
			# one a player is trying to change.
			time.text = _format_time(best)
			time.add_theme_color_override("font_color", Medal.colour(medal))
		elif TrackRoster.exists(index):
			time.text = "NO TIME"
			time.add_theme_color_override("font_color", Color(0.55, 0.58, 0.66))
		cell.add_child(time)

		_track_grid.add_child(cell)


## What a track is and what it wants, for anyone who goes looking.
func _what_it_asks(index: int) -> String:
	if not TrackRoster.exists(index):
		return "Not built yet."
	var targets := TrackRoster.targets(index)
	if targets == Vector3.ZERO:
		return TrackRoster.track_name(index)
	return "%s\nGOLD %s     SILVER %s     BRONZE %s" % [
		TrackRoster.track_name(index), _format_time(targets.x),
		_format_time(targets.y), _format_time(targets.z)]


## The same clock the race keeps, so a time on the button and the time that
## was driven read as the same number.
func _format_time(seconds: float) -> String:
	var minutes := int(seconds) / 60
	var rest := fmod(seconds, 60.0)
	if minutes > 0:
		return "%d:%05.2f" % [minutes, rest]
	return "%.2f" % rest


## The face of a track that does not exist yet.
func _empty_slot() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.075, 0.098, 0.157, 0.9)
	box.border_color = Color(0.898, 0.929, 1.0, 0.16)
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	return box


## Rebuilt each time the page opens rather than once at startup: a player
## comes back to this screen straight from having beaten something, and a
## grid built before the race would still be showing the old time.
func _refresh_the_track_grid() -> void:
	for cell in _track_grid.get_children():
		cell.queue_free()
	# Freed nodes are still children until the frame ends, and a grid with two
	# sets of cells in it lays out both.
	for cell in _track_grid.get_children():
		_track_grid.remove_child(cell)
	_fill_the_track_grid()


func _on_tracks_pressed() -> void:
	# The mode page steps aside rather than lying underneath. Both are full
	# panels, and one showing through the other reads as a bug however faint
	# it is - unlike the settings, which lie over a title screen with nothing
	# on it but a name.
	_mode_choice.hide()
	_refresh_the_track_grid()
	_track_choice.show()
	_focus_track()


## Put the cursor on a track, or on the first one that can be pressed. With
## one track made that is the only one; with twenty it is still where a player
## wants to start.
func _focus_track(index := -1) -> void:
	var cells := _track_grid.get_children()
	if index >= 0 and index < cells.size():
		var wanted := _button_in(cells[index])
		if wanted != null and not wanted.disabled:
			wanted.grab_focus()
			return
	for cell in cells:
		var button := _button_in(cell)
		if button != null and not button.disabled:
			button.grab_focus()
			return
	_track_back.grab_focus()


func _button_in(cell: Node) -> Button:
	for child in cell.get_children():
		if child is Button:
			return child
	return null


func _start_track(path: String) -> void:
	GameSettings.track_file = path
	# A track is a road to learn and a time to beat, so it is always run under
	# the same rules. Chaos rerolls the cars for every race, and a time set by
	# a car nobody will be given again is not a time.
	GameSettings.chaos = false
	GameSettings.save_settings()
	get_tree().change_scene_to_file(_scene_for_the_players())


func _close_track_choice() -> void:
	_track_choice.hide()
	_mode_choice.show()
	_tracks_button.grab_focus()


## Which scene a race runs in. Everything else about a race - the endless
## course or a laid-out track, chaos or not - is a setting the scene reads;
## how many are playing is the one thing that decides which scene it is.
func _scene_for_the_players() -> String:
	return solo_scene if GameSettings.solo else race_scene


## Hold each slot's contents to the width of the page.
##
## They hang inside plain Controls rather than containers, because a container
## would insist on being tall enough for them and so could never collapse. The
## cost of that is having to set their width here: left to its own anchors a
## row sizes itself to nothing in particular, spreads its buttons across that,
## and hangs them out over both edges of the panel.
func _fit_flavour() -> void:
	_flavour_inner.size.x = _flavour_slot.size.x


func _fit_modes() -> void:
	_mode_inner.size.x = _mode_slot.size.x


## Roll a slot's contents out from under whatever is above it, or back under,
## pushing everything below down as they come.
##
## The slot is what the layout sees, so growing its minimum height is what
## moves the rest of the page; the contents ride up inside it and are clipped,
## which is what makes them slide rather than simply appear. The height is
## asked of the contents rather than written down here, so it stays right if
## the wording or the font ever changes.
func _slide(slot: Control, inner: Control, open: bool, tween: Tween) -> Tween:
	if tween:
		tween.kill()
	inner.size.x = slot.size.x
	var height: float = inner.get_combined_minimum_size().y
	if open:
		slot.show()
		slot.custom_minimum_size.y = 0.0
		inner.position.y = -height
		slot.modulate.a = 0.0

	var rolling := create_tween()
	rolling.set_parallel(true)
	rolling.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	rolling.tween_property(slot, "custom_minimum_size:y",
		height if open else 0.0, slide_seconds)
	rolling.tween_property(inner, "position:y", 0.0 if open else -height,
		slide_seconds)
	rolling.tween_property(slot, "modulate:a", 1.0 if open else 0.0,
		slide_seconds)
	if not open:
		# Hidden rather than merely flat, or the gap the layout leaves either
		# side of the slot stays behind as a hole in the page.
		rolling.chain().tween_callback(slot.hide)
	return rolling


func _slide_flavour(open: bool) -> void:
	_flavour_tween = _slide(_flavour_slot, _flavour_inner, open, _flavour_tween)


## The modes, rolling out from under the two buttons at the top of the page.
## They come from the middle rather than from under whichever button was
## pressed, because what is opening is the rest of the page and not a drawer
## belonging to one of them.
func _slide_modes(open: bool) -> void:
	if open == _modes_open:
		return
	_modes_open = open
	if not open:
		_shut_flavour()
	_mode_tween = _slide(_mode_slot, _mode_inner, open, _mode_tween)


## Shut a slot with no animation, for opening the page on it rather than
## closing it in front of the players.
func _shut(slot: Control, tween: Tween) -> void:
	if tween:
		tween.kill()
	slot.hide()
	slot.custom_minimum_size.y = 0.0
	slot.modulate.a = 0.0


func _shut_flavour() -> void:
	_shut(_flavour_slot, _flavour_tween)


func _shut_modes() -> void:
	_modes_open = false
	_shut(_mode_slot, _mode_tween)


func _close_mode_choice() -> void:
	_mode_choice.hide()
	_shut_flavour()
	_shut_modes()
	_play.grab_focus()


## Escape backs out of whichever page is open. The screens that lie over these
## handle their own, so they get first refusal on the key.
func _input(event: InputEvent) -> void:
	if _settings_screen.visible or _account_screen.visible:
		return
	if _boards_screen.visible:
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	# One thing at a time, innermost first: off the track grid, then off the
	# flavour choice, then off the modes, then off the page.
	if _track_choice.visible:
		get_viewport().set_input_as_handled()
		_close_track_choice()
	elif _flavour_slot.visible:
		get_viewport().set_input_as_handled()
		_slide_flavour(false)
		_infinite_button.grab_focus()
	elif _modes_open:
		get_viewport().set_input_as_handled()
		_slide_modes(false)
		if GameSettings.solo:
			_alone_button.grab_focus()
		else:
			_together_button.grab_focus()
	elif _mode_choice.visible:
		get_viewport().set_input_as_handled()
		_close_mode_choice()


## The settings lie over the title screen rather than replacing it, so the
## backdrop keeps turning and the title keeps rocking behind them.
func _on_settings_pressed() -> void:
	_settings_screen.open()


func _on_settings_closed() -> void:
	# Coming back to a screen with nothing focused would leave the keyboard
	# dead, so the button that opened the settings takes focus again.
	_settings_button.grab_focus()


## The account screen lies over the title the same way the settings do.
func _on_account_pressed() -> void:
	_account_screen.open()


func _on_account_closed() -> void:
	_account_button.grab_focus()


## The boards open on whichever track the cursor is sitting on, because that
## is the one the player is asking about.
func _on_boards_pressed() -> void:
	_boards_screen.open(_track_under_the_cursor())


func _on_boards_closed() -> void:
	# The sync the boards set going may have pulled a better time down, and
	# the grid behind them would still be showing the old one.
	_refresh_the_track_grid()
	_boards_button.grab_focus()


## A sync moved a record. Only the track grid shows times, and only when it is
## open, so there is nothing to do the rest of the time.
func _on_times_changed() -> void:
	if _track_choice.visible:
		_refresh_the_track_grid()


## The track the cursor is on, or an empty string if it is not on one. Worked
## out from focus rather than remembered, so it cannot go stale.
func _track_under_the_cursor() -> String:
	var focused := get_viewport().gui_get_focus_owner()
	var cells := _track_grid.get_children()
	for index in cells.size():
		if _button_in(cells[index]) == focused:
			return TrackRoster.file(index)
	return GameSettings.track_file
