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
## GARAGE sits under PLAY, and opens the same garage the pause menu does. The
## title is the best place there is to look at a car: the camera is already
## turning slowly round the two parked on the grid, and they are dressed from
## the same setting a race reads, so picking a car changes the one being
## circled. It is under PLAY rather than behind it because which car to drive
## is a choice made before a race, not one of the questions about it.
##
## SHOP sits under GARAGE, for the same reason and in the same order a player
## does the two things: a car is picked, and then it is spent on. It is on the
## title rather than inside the garage because what it sells is not only cars,
## and a shop reached through the garage would be a shop a player has to guess
## the location of.
##
## Over the buttons, small, sits what is in the purse: a disc and a number, and
## nothing else. It is there because a player who has been picking coins up on
## the road should be able to see what they have got without starting anything,
## and it is against the column of buttons rather than off in a corner because
## the shop that spends it is in that column. Above rather than below: the
## column runs to the bottom of the screen already, and a total under it would
## be a total nobody with a short window ever sees.
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
## The size a track's name is set in over its picture.
@export var track_name_font_size := 18
## The smallest a name too long for its column is shrunk to. Below this a
## name stops reading as a name from where a menu is looked at.
@export var track_name_smallest_font_size := 13
## How many tracks stand across the grid.
##
## Five across and ten to a block means a block is exactly two rows, which is
## what lets a door sit between one block and the next without any cell losing
## the column it is lined up in.
@export var track_columns := 5
## The gap between cells, and between a block and the door under it.
@export var track_spacing := 14
## How big the lock over a shut track is drawn, in pixels. Big enough to read
## as a lock at a glance over a picture, small enough that the road under it is
## still a road rather than a background.
@export var lock_size := 46.0
## How tall a door is, in pixels, and the size the words on it are set in.
## Plainly not a track: a track is a picture 152 across, a door is a strip the
## width of the page with nothing in it but words.
@export var door_height := 56.0
@export var door_font_size := 22

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

@export_group("Track page")
## How far a way of driving a track does not offer is faded. Faded rather than
## hidden, and still pressable: its board is still worth reading, and a row of
## buttons that changes length from track to track is a row a player has to
## read again every time.
@export_range(0.0, 1.0) var unoffered_alpha := 0.4

@export_group("Mode choice")
## How long the flavour buttons take to roll out from under infinite. Long
## enough to read as movement, short enough that a player who knows what they
## want is not waiting on it.
@export var slide_seconds := 0.22

## The colour of the gate wherever it shows: the frame round a shut track, the
## lock over it, and the door at the end of a block. The bot's own amber, taken
## from the car it paints rather than picked again here, because the one thing
## that opens any of it is beating that car.
const GATE_COLOUR := Solo.BOT_COLOUR

## The colour of a door that has been won. Green rather than a fourth shade of
## the gate's amber: a door that is behind a player is a different thing from
## one in front of them, and the grid is read at a glance.
const WON_COLOUR := Color(0.44, 0.85, 0.52)

@onready var _title: Label = $TitleSlot/Title
@onready var _play: Button = $Play
@onready var _garage_button: Button = $Garage
@onready var _garage_screen: GarageMenu = $GarageScreen
@onready var _shop_button: Button = $Shop
@onready var _shop_screen: ShopMenu = $ShopScreen
@onready var _settings_button: Button = $Settings
@onready var _settings_screen: SettingsMenu = $SettingsScreen
@onready var _account_button: Button = $Account
@onready var _account_screen: AccountMenu = $AccountScreen
@onready var _boards_button: Button = $TrackChoice/Page/Panel/Margin/Box/Pages/Boards
@onready var _boards_screen: LeaderboardMenu = $LeaderboardScreen
@onready var _stats_button: Button = $TrackChoice/Page/Panel/Margin/Box/Pages/Stats
@onready var _stats_screen: StatsMenu = $StatsScreen
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
@onready var _kind_slot: Control = $ModeChoice/Page/Panel/Margin/Box/ModeSlot/Inner/KindSlot
@onready var _kind_inner: Control = $ModeChoice/Page/Panel/Margin/Box/ModeSlot/Inner/KindSlot/Inner
@onready var _normal_tracks_button: Button = $ModeChoice/Page/Panel/Margin/Box/ModeSlot/Inner/KindSlot/Inner/Row/Normal
@onready var _acrobatic_button: Button = $ModeChoice/Page/Panel/Margin/Box/ModeSlot/Inner/KindSlot/Inner/Row/Acrobatic
@onready var _track_heading: Label = $TrackChoice/Page/Panel/Margin/Box/Heading
@onready var _track_choice: Control = $TrackChoice
@onready var _track_blocks: VBoxContainer = $TrackChoice/Page/Panel/Margin/Box/Scroll/Blocks
@onready var _track_back: Button = $TrackChoice/Page/Panel/Margin/Box/Back
@onready var _track_detail: Control = $TrackDetail
@onready var _detail_heading: Label = $TrackDetail/Page/Panel/Margin/Box/Heading
@onready var _detail_blurb: Label = $TrackDetail/Page/Panel/Margin/Box/Blurb
@onready var _detail_picture: TextureRect = $TrackDetail/Page/Panel/Margin/Box/Body/Left/Picture
@onready var _detail_normal: Button = $TrackDetail/Page/Panel/Margin/Box/Body/Left/Variants/Normal
## Track chaos, not chaos mode - see `TrackVariant.TRACK_CHAOS`.
@onready var _detail_track_chaos: Button = $TrackDetail/Page/Panel/Margin/Box/Body/Left/Variants/TrackChaos
@onready var _detail_hard: Button = $TrackDetail/Page/Panel/Margin/Box/Body/Left/Variants/Hard
@onready var _detail_mirror: Button = $TrackDetail/Page/Panel/Margin/Box/Body/Left/Variants/Mirror
@onready var _detail_play: Button = $TrackDetail/Page/Panel/Margin/Box/Body/You/Play
@onready var _detail_why: Label = $TrackDetail/Page/Panel/Margin/Box/Body/You/Why
@onready var _detail_back: Button = $TrackDetail/Page/Panel/Margin/Box/Back
@onready var _detail_board_heading: Label = $TrackDetail/Page/Panel/Margin/Box/Body/Board/Heading
@onready var _detail_rows: VBoxContainer = $TrackDetail/Page/Panel/Margin/Box/Body/Board/Scroll/Rows
@onready var _detail_note: Label = $TrackDetail/Page/Panel/Margin/Box/Body/Board/Note
@onready var _detail_time: Label = $TrackDetail/Page/Panel/Margin/Box/Body/You/Time
@onready var _detail_medal: ColorRect = $TrackDetail/Page/Panel/Margin/Box/Body/You/Medal
@onready var _detail_place: Label = $TrackDetail/Page/Panel/Margin/Box/Body/You/Place
@onready var _detail_place_note: Label = $TrackDetail/Page/Panel/Margin/Box/Body/You/PlaceNote
@onready var _world: Node3D = $World
@onready var _orbit: Camera3D = $Orbit

var _elapsed := 0.0
var _flavour_tween: Tween
var _kind_tween: Tween
## Which grid of tracks the page is showing, normal or acrobatic.
var _track_kind := TrackRoster.NORMAL
## The slot whose own page is open, or was last.
var _detail_index := 0
## Bumped every time the page asks for a board, so an answer for a track the
## player has already left is dropped rather than drawn under another name.
var _detail_asked := 0
## Which way of driving it is held down: whose board and whose time the page
## is showing.
var _detail_variant := TrackVariant.NORMAL
var _mode_tween: Tween
## True once one of the two has been picked and the modes have rolled out.
## While that is so, the slot is held to the height of its own contents, which
## is what lets the flavour buttons slide inside it and push it open further.
var _modes_open := false


func _ready() -> void:
	# Everything on the title screen moves on the frame rather than on the
	# physics step - the title rocks, the pages slide, the camera turns - and
	# Godot's own guidance is that a node moved outside the physics step while
	# it is being interpolated between steps jitters. The backdrop behind it
	# is parked, so it has nothing to gain from interpolation either.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_play.pressed.connect(_on_play_pressed)
	_garage_button.pressed.connect(_on_garage_pressed)
	_garage_screen.closed.connect(_on_garage_closed)
	_shop_button.pressed.connect(_on_shop_pressed)
	_shop_screen.closed.connect(_on_shop_closed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_settings_screen.closed.connect(_on_settings_closed)
	_alone_button.pressed.connect(_choose_players.bind(true))
	_together_button.pressed.connect(_choose_players.bind(false))
	_infinite_button.pressed.connect(_on_infinite_pressed)
	_mode_back.pressed.connect(_close_mode_choice)
	_normal_button.pressed.connect(_start_infinite.bind(false))
	_chaos_button.pressed.connect(_start_infinite.bind(true))
	_tracks_button.pressed.connect(_on_tracks_pressed)
	_normal_tracks_button.pressed.connect(_open_track_grid.bind(TrackRoster.NORMAL))
	_acrobatic_button.pressed.connect(_open_track_grid.bind(TrackRoster.ACROBATIC))
	_track_back.pressed.connect(_close_track_choice)
	# The four ways of driving it are a choice held down, one at a time, and
	# PLAY is what starts the race: picking how to drive a track and setting
	# off are two different presses, so a player can look at each before going.
	#
	# Holding one down puts that way's board up, and the player's time and
	# place on it: each way is a road of its own, with a board of its own.
	var ways := ButtonGroup.new()
	var buttons := _detail_normal.get_parent().get_children()
	for at in buttons.size():
		var way := buttons[at] as Button
		way.button_group = ways
		way.pressed.connect(_choose_detail_variant.bind(TrackVariant.ALL[at]))
	_detail_play.pressed.connect(_start_detail_track)
	_detail_back.pressed.connect(_close_track_detail)
	# MIRROR is written mirrored, flipped left to right about its own middle
	# so it reads the way the word would in a mirror. It is a label inside the
	# button rather than the button's own text, because the row a button sits
	# in puts its scale back to one every time it lays it out; nothing lays
	# out a label hung inside a button. The middle moves whenever the button
	# is resized, so it is re-centred then rather than set once.
	var word: Label = _detail_mirror.get_node("Word")
	word.add_theme_font_size_override("font_size",
		_detail_mirror.get_theme_font_size("font_size"))
	word.scale.x = -1.0
	word.resized.connect(func() -> void: word.pivot_offset = word.size * 0.5)
	_account_button.pressed.connect(_on_account_pressed)
	_account_screen.closed.connect(_on_account_closed)
	_boards_button.pressed.connect(_on_boards_pressed)
	_boards_screen.closed.connect(_on_boards_closed)
	_stats_button.pressed.connect(_stats_screen.open)
	_stats_screen.closed.connect(_on_stats_closed)
	# A time pulled down off the server is a time this screen is showing the
	# old version of, so the grid is rebuilt when the sync moves one.
	Leaderboard.times_changed.connect(_on_times_changed)
	# `Progress.changed` is deliberately not listened to here beside it, and the
	# difference is worth writing down. A time can move while this screen is up,
	# because the sync runs underneath it. A bot race cannot: it is a scene of
	# its own, and coming back from it builds this one again from nothing. A
	# player who wins one and comes back finds the next ten open because the
	# grid was built afresh, not because anything told it.
	# A build with no server in it should not grow a button that cannot do
	# anything, or a board that is always empty.
	_account_button.visible = Leaderboard.available()
	_boards_button.visible = Leaderboard.available()
	# Statistics stay either way: they are this machine's, and need no server.
	_fill_the_track_grid()
	# The slots are plain Controls, so nothing lays their contents out but this.
	_flavour_slot.resized.connect(_fit_flavour)
	_kind_slot.resized.connect(_fit_kinds)
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
	_slide_kinds(true)
	var index := TrackRoster.index_of(GameSettings.track_file)
	var kind := TrackRoster.kind_of(index)
	# A bot road is a door on the normal grid rather than a grid of its own, so
	# coming back off one opens the ten it stands at the end of, with the
	# cursor on the door itself - which is where a player who has just lost to
	# the bot is about to press again.
	if kind == TrackRoster.BOT:
		_open_track_grid(TrackRoster.NORMAL)
		_focus_door(index - TrackRoster.first(TrackRoster.BOT))
		return
	_open_track_grid(kind)
	_focus_track(index - TrackRoster.first(kind))
	# Back onto the track's own page if it has one, since that is where the
	# player pressed to drive it and where they are about to press again.
	if _has_a_page(index):
		_open_track_detail(index, GameSettings.track_variant)


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
	# The track page's CHAOS turns the same way. It is track chaos, a different
	# thing from the chaos mode the button above belongs to, but it is the one
	# way of driving a track that refuses to sit still, so it says so the same
	# way.
	# Its own alpha kept: that is what says whether the track offers it.
	_detail_track_chaos.modulate = Color(_chaos_button.modulate,
		_detail_track_chaos.modulate.a)
	# A label does not know it is inside a button, so it is told which of the
	# button's colours to wear: the same word a plain button would show.
	var word: Label = _detail_mirror.get_node("Word")
	var state := "font_color"
	if _detail_mirror.button_pressed:
		state = "font_pressed_color"
	elif _detail_mirror.has_focus():
		state = "font_focus_color"
	elif _detail_mirror.is_hovered():
		state = "font_hover_color"
	word.add_theme_color_override("font_color", _detail_mirror.get_theme_color(state))
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
	_shut_kinds()
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


## Tracks is a door the same way: it opens out into the choice between the
## normal tracks and the acrobatic ones, which are a different thing to drive
## and so are not mixed in with the rest. Both open the same page, showing
## one grid or the other.
func _on_tracks_pressed() -> void:
	if _kind_slot.visible:
		_slide_kinds(false)
		_tracks_button.grab_focus()
	else:
		_slide_kinds(true)
		_normal_tracks_button.grab_focus()


func _start_infinite(chaos: bool) -> void:
	# Cleared, or an infinite race started after a track had been played would
	# run that track over and over.
	GameSettings.track_file = ""
	GameSettings.track_variant = TrackVariant.NORMAL
	GameSettings.chaos = chaos
	# Settled at the start of the race rather than on every press, so opening
	# and closing the choice is not a file write per click.
	GameSettings.save_settings()
	get_tree().change_scene_to_file(_scene_for_the_players())


# --- choosing a track ---------------------------------------------------

## The grid of tracks: blocks of ten, each with the door that opens the next
## ten standing under it.
##
## One cell per track the game intends to have, not per track it has, and three
## states on a cell rather than two. A slot with nothing in it is still shown,
## greyed and unpressable, because nineteen doors that do not open yet say what
## the game is going to be; a short grid that grew every few weeks would say
## nothing at all. A built track a player has not opened yet is shown a third
## way, with its picture behind a lock, because a road that exists and is shut
## is not the same thing as a road that has not been drawn - showing the two
## alike tells a player the game is unfinished when in fact they are.
##
## A grid per block rather than one grid of twenty. Five across and ten to a
## block means a block is exactly two rows, so a door can sit in a strip of its
## own between one block and the next while every cell keeps the column it was
## always lined up in.
##
## Built here rather than in the scene: twenty cells is a great deal of scene to
## write down, and every one of them would have to be edited again the day a
## track was added.
func _fill_the_track_grid() -> void:
	_track_blocks.add_theme_constant_override("separation", track_spacing)
	var first := TrackRoster.first(_track_kind)
	var total := TrackRoster.count(_track_kind)
	var block := 0
	while block * Progress.BLOCK < total:
		var grid := _a_block_grid()
		_track_blocks.add_child(grid)
		for offset in range(block * Progress.BLOCK,
				mini((block + 1) * Progress.BLOCK, total)):
			var cell := _a_track_cell(first + offset)
			grid.add_child(cell)
			# Not until now: off the page, the name does not know which font
			# the theme will draw it in, and so can say neither how wide it
			# will be nor how tall the rest of its row is.
			_fit_the_name(cell.get_child(0) as Label)
		# Only the time trials are gated, so only they have doors. The
		# acrobatic tracks are one block of ten with nothing at the end of it:
		# they are a different thing to drive, in their own grid, and a player
		# who cannot find five golds among the first ten should still be free
		# to go and fly through some rings.
		if _track_kind == TrackRoster.NORMAL:
			_track_blocks.add_child(_a_door(block))
		block += 1
	_tie_the_blocks_together()


## Tie the blocks to the doors between them, for the keyboard.
##
## Godot works out where focus goes next from where things are on the screen,
## which is right inside a grid and no use at all at a seam: what lies below
## the bottom row of a block is a door in a container of its own, and the
## search walks straight past it and off the page altogether - pressing down
## off the last row of the first ten landed on the title screen behind it.
##
## So the seams are said outright. Down off the last row is the door, down off
## the door is the top row of the ten it opens, and back up again the same way.
## Only the seams: inside a block the geometry has always been right.
func _tie_the_blocks_together() -> void:
	# The last row built so far, and a door still waiting for the block under
	# it - the page is a grid, a door, a grid, a door, and each one is tied to
	# the one before as it goes by.
	var last_row: Array = []
	var waiting: Button = null
	for child in _track_blocks.get_children():
		var door := child as Button
		if door != null:
			for button in last_row:
				button.focus_neighbor_bottom = door.get_path()
			if not last_row.is_empty():
				door.focus_neighbor_top = last_row[0].get_path()
			last_row = []
			waiting = door
			continue
		var grid := child as GridContainer
		if grid == null:
			continue
		var buttons: Array = []
		for cell in grid.get_children():
			var button := _button_in(cell)
			if button != null:
				buttons.append(button)
		if buttons.is_empty():
			continue
		if waiting != null:
			var top := buttons.slice(0, mini(grid.columns, buttons.size()))
			for button in top:
				button.focus_neighbor_top = waiting.get_path()
			waiting.focus_neighbor_bottom = top[0].get_path()
			waiting = null
		last_row = buttons.slice(
			(buttons.size() - 1) / grid.columns * grid.columns)


## One block's worth of cells, five across.
func _a_block_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = track_columns
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", track_spacing)
	grid.add_theme_constant_override("v_separation", track_spacing)
	return grid


## One track: its name, its picture, what a lap of it was worth and what it is
## worth now - or, if it is still shut, a lock over the picture and the one
## thing to go and do about it.
func _a_track_cell(index: int) -> VBoxContainer:
	var exists := TrackRoster.exists(index)
	var shut := exists and not _open_to_the_player(index)
	# Each of these is asked once a cell. The name and the targets are
	# each a track file built and described, and the best time is checked
	# against the file on the disk every time it is asked for.
	var called := TrackRoster.track_name(index)
	var targets := TrackRoster.targets(index)
	var best := TrackTimes.best(TrackRoster.file(index)) if exists else -1.0

	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 4)

	var label := Label.new()
	label.text = called.to_upper()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Held to the width of the picture rather than allowed to set the width
	# of its column: one long name would otherwise stretch the whole grid
	# out around it. A name that does not fit is set smaller to fit it,
	# once the cell is on the grid; clipped only past the smallest size.
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.custom_minimum_size.x = track_button_size
	# Greyed for a slot with nothing in it, and only for that. A shut track
	# keeps its name in white: the name is the one part of it that is not
	# being withheld, and a grey name is how this page says "not built".
	if not exists:
		label.add_theme_color_override("font_color", Color(0.55, 0.58, 0.66))
	cell.add_child(label)

	var button := Button.new()
	button.custom_minimum_size = Vector2(track_button_size, track_button_size)
	button.expand_icon = true
	button.icon = TrackRoster.thumbnail(index)
	button.disabled = not exists or shut
	if not exists:
		# The theme greys a disabled button until it disappears into the
		# page, which reads as a hole rather than as a track still to
		# come. An empty slot gets its own frame instead: dark, outlined,
		# and plainly a place where something goes.
		button.add_theme_stylebox_override("disabled", _empty_slot())
	elif shut:
		# The picture stays, dimmed, with a lock over it. What is behind the
		# gate is a road somebody drew and a player is meant to want to get
		# to, and an empty frame in its place would hide the reason for
		# going and earning it.
		button.add_theme_stylebox_override("disabled", _shut_slot())
		button.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.26))
		button.add_child(_a_lock(lock_size, GATE_COLOUR))
	button.tooltip_text = _what_it_asks(index, called, targets)
	if not button.disabled:
		if _has_a_page(index):
			button.pressed.connect(_open_track_detail.bind(index))
		else:
			button.pressed.connect(_start_track.bind(TrackRoster.file(index)))
	cell.add_child(button)

	# A bar of the medal's colour directly under the picture. Colouring
	# the time alone was not enough: against a dark panel a silver time
	# and a time worth nothing are two shades of pale, and a medal that
	# has to be compared with its neighbours to be seen is not one.
	var medal := Medal.earned(best, targets)
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(track_button_size, 5)
	rule.color = Medal.colour(medal)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.visible = medal != Medal.NONE
	cell.add_child(rule)

	# The time under the picture, because it is the thing that changes.
	# A track with no time to its name says so rather than showing a dash:
	# there is a difference between a road nobody has finished and one
	# that is not built. A shut track says the same as any other road
	# nobody has driven, because that is what it is.
	var time := Label.new()
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time.custom_minimum_size.x = track_button_size
	time.clip_text = true
	time.add_theme_font_size_override("font_size", 20)
	if best >= 0.0:
		# Coloured to match the bar rather than spelled out. A cell this
		# size has room for a number or for a word, and the number is the
		# one a player is trying to change.
		time.text = RaceClock.format(best)
		time.add_theme_color_override("font_color", Medal.colour(medal))
	elif exists:
		time.text = "NO TIME"
		time.add_theme_color_override("font_color", Color(0.55, 0.58, 0.66))
	cell.add_child(time)
	# The name is not fitted here. It cannot be: a cell that is not on the page
	# yet has no theme to be measured in. `_fill_the_track_grid` does it once
	# the cell is on its grid.
	return cell


## Whether a slot's track may be driven at all.
##
## Only the normal tracks are gated. An acrobatic track is a different thing to
## drive, shown in its own grid, and nothing about the gate has ever mentioned
## one; do not fold them into a block as a kindness, because it would be a wall.
func _open_to_the_player(index: int) -> bool:
	if TrackRoster.kind_of(index) != TrackRoster.NORMAL:
		return true
	return Progress.open(index / Progress.BLOCK)


## The door at the end of a block of ten: the race against the computer that
## opens the next ten.
##
## A strip of its own rather than a cell on the grid. It is not a track - no
## overhead shot, no medal, no time under it, and nothing it does is written
## down on a leaderboard - and standing it in a row with five tracks would make
## it read as a sixth. Across the width of the page it reads as what it is: the
## end of these ten, and the way through to the next.
##
## Three things it can be, and the words on it say which: shut, with what it
## wants; open, with the race to go and drive; or won, and behind them.
func _a_door(block: int) -> Button:
	var door := Button.new()
	door.custom_minimum_size.y = door_height
	door.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	door.add_theme_font_size_override("font_size", door_font_size)
	door.clip_text = true
	var road := TrackRoster.bot_road(block)
	# The door lets a player into the block after this one, which is the block
	# whose golds it asks for - `Progress` counts the two the same way round.
	var wanted := _what_the_gate_wants(block + 1)
	if road.is_empty():
		# The same pale empty frame a slot with no track in it wears, for the
		# same reason: a door that has not been built is not a door that is
		# shut against the player.
		door.text = "THE RACE AT THE END OF %s IS NOT BUILT YET" % _block_range(block)
		door.tooltip_text = "Not built yet."
		door.disabled = true
		door.add_theme_stylebox_override(
			"disabled", _door_face(Color(0.898, 0.929, 1.0), 0.0, 0.16))
		return door

	var called := TrackRoster.track_name(TrackRoster.first(TrackRoster.BOT) + block)
	if not Progress.gate_open(block + 1):
		# Said on the face as well as in the tooltip. A cell has room for a
		# picture or a word; a strip this wide has room for the sentence, and
		# a player should not have to hover over the one thing on the page
		# that is telling them what to go and do.
		door.text = "%s     %s" % [called.to_upper(), wanted]
		door.tooltip_text = "%s\n%s" % [called, wanted]
		door.disabled = true
		door.add_theme_stylebox_override("disabled", _door_face(GATE_COLOUR, 0.04, 0.30))
		return door

	if Progress.won(block):
		door.text = "%s     WON" % called.to_upper()
		door.tooltip_text = "%s\nWon. Race it again whenever you like." % called
		_dress_the_door(door, WON_COLOUR)
	else:
		door.text = "%s     RACE THE BOT" % called.to_upper()
		door.tooltip_text = "%s\nBeat the bot to open %s." % [
			called, _block_range(block + 1)]
		_dress_the_door(door, GATE_COLOUR)
	door.pressed.connect(_start_track.bind(road))
	return door


## What a player has to go and do to open a block, in the words they would use
## to do it.
##
## Never the word "locked" on its own. A door that says only that it is shut
## tells a player to give up; the same door saying "5 GOLD IN 1-10, you have 3"
## tells them where to go and how far off they are.
##
## Two answers, because there are two things in the way and they come in order.
## The golds buy the right to start the race; the race opens the ten. A player
## who has the golds and has not driven it is told about the race, not asked
## again for medals they already have.
func _what_the_gate_wants(block: int) -> String:
	var before := block - 1
	if not Progress.gate_open(block):
		return "%d GOLD IN %s, you have %d" % [
			Progress.GOLDS_NEEDED, _block_range(before), Progress.golds_in(before)]
	return "WIN THE RACE AT THE END OF %s" % _block_range(before)


## A block of ten the way a player counts them, so the first block is 1-10.
func _block_range(block: int) -> String:
	return "%d-%d" % [block * Progress.BLOCK + 1, (block + 1) * Progress.BLOCK]


## A padlock, drawn rather than set in a font or shipped as a picture.
##
## Drawn because the only thing it has to do is be there. A glyph is a lock
## only if the font on the machine has one, and a font that does not draws a
## hollow box - which over a greyed picture reads as something broken rather
## than as something shut, which is the exact wrong thing for this cell to say.
##
## It lies over the whole of the button and draws itself in the middle, so it
## needs no layout of its own and cannot be knocked out of place by one.
func _a_lock(across: float, colour: Color) -> Control:
	var lock := Control.new()
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lock.draw.connect(_draw_a_lock.bind(lock, across, colour))
	return lock


## A shackle standing on a body, drawn in a box sixteen units square and scaled
## to whatever size was asked for.
func _draw_a_lock(on: Control, across: float, colour: Color) -> void:
	var unit := across / 16.0
	var middle := on.size * 0.5
	var shoulder := middle.y - unit
	on.draw_arc(Vector2(middle.x, shoulder), 3.5 * unit, PI, TAU, 24,
		colour, 1.8 * unit)
	on.draw_rect(Rect2(middle.x - 5.5 * unit, shoulder,
		11.0 * unit, 7.0 * unit), colour)


## What a track is and what it wants, for anyone who goes looking.
func _what_it_asks(index: int, called: String, targets: Vector3) -> String:
	if not TrackRoster.exists(index):
		return "Not built yet."
	if not _open_to_the_player(index):
		# The name first, so a shut cell still says which road it is, and then
		# the one thing to go and do about it.
		return "%s\n%s" % [called, _what_the_gate_wants(index / Progress.BLOCK)]
	if targets == Vector3.ZERO:
		return called
	return "%s\nGOLD %s     SILVER %s     BRONZE %s" % [
		called, RaceClock.format(targets.x),
		RaceClock.format(targets.y), RaceClock.format(targets.z)]


## The face of a track that does not exist yet.
func _empty_slot() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.075, 0.098, 0.157, 0.9)
	box.border_color = Color(0.898, 0.929, 1.0, 0.16)
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	return box


## The face of a track that is built but still shut.
##
## Plainly not the empty frame, and it has to be: the frame round it is the
## gate's own amber rather than the pale outline of a slot with nothing in it,
## and there is a road showing dimly behind the lock where an empty slot has
## nothing at all.
func _shut_slot() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.075, 0.098, 0.157, 0.9)
	box.border_color = Color(GATE_COLOUR, 0.45)
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	return box


## The face of a door, in whatever colour that door is. Built here rather than
## taken from the theme because a door left with the theme's own boxes is a
## wide button, and the one thing this cell must not read as is another button.
func _door_face(tint: Color, fill: float, border: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(tint, fill)
	box.border_color = Color(tint, border)
	box.set_border_width_all(3)
	box.set_corner_radius_all(8)
	box.content_margin_left = 18.0
	box.content_margin_right = 18.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	return box


## Dress a door that can be pressed: a face for each state a button has, and
## the words in the door's own colour.
func _dress_the_door(door: Button, tint: Color) -> void:
	door.add_theme_stylebox_override("normal", _door_face(tint, 0.10, 0.85))
	door.add_theme_stylebox_override("hover", _door_face(tint, 0.26, 1.0))
	door.add_theme_stylebox_override("pressed", _door_face(tint, 0.34, 1.0))
	# Drawn over whichever of the three is showing rather than instead of it,
	# so the focused door is a brighter edge and not a second face.
	door.add_theme_stylebox_override("focus", _door_face(tint, 0.0, 1.0))
	for named in ["font_color", "font_hover_color", "font_pressed_color",
			"font_focus_color", "font_hover_pressed_color"]:
		door.add_theme_color_override(named, tint)


## Set a track's name as small as it has to be to read whole over its picture.
##
## Smaller rather than wrapped, because a name on two lines pushes its picture
## down out of line with the rest of its row. Smaller rather than a wider
## grid, because all five columns would have to grow for the sake of one name.
## A name cut off at both ends reads as a different name: LONG WAY ROUND came
## out as .ONG WAY ROUNI. tools/checks/track_select.gd reports one that still
## does not fit at the smallest size.
func _fit_the_name(label: Label) -> void:
	# Held to the height of a name at the usual size, with a smaller one
	# centred in it. A shorter label lifts its picture a few pixels out of line
	# with the rest of the row, which is the thing wrapping was turned down for.
	label.add_theme_font_size_override("font_size", track_name_font_size)
	label.custom_minimum_size.y = label.get_combined_minimum_size().y
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var font := label.get_theme_font("font")
	var room := track_button_size - label.get_theme_stylebox("normal").get_minimum_size().x
	var points := track_name_font_size
	while points > track_name_smallest_font_size and font.get_string_size(
			label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, points).x > room:
		points -= 1
	label.add_theme_font_size_override("font_size", points)


## Rebuilt each time the page opens rather than once at startup: a player
## comes back to this screen straight from having beaten something, and a
## grid built before the race would still be showing the old time.
func _refresh_the_track_grid() -> void:
	for block in _track_blocks.get_children():
		# Taken out as well as freed: freed nodes are still children until the
		# frame ends, and a column with two sets of blocks in it lays out both.
		_track_blocks.remove_child(block)
		block.queue_free()
	_fill_the_track_grid()


## Every cell holding a track, in the order they are shown, across the blocks.
## What the page is made of is grids and doors; what a track index means is
## this list, so everything that counts tracks or looks one up asks here.
func _track_cells() -> Array:
	var cells := []
	for block in _track_blocks.get_children():
		if block is GridContainer:
			cells.append_array(block.get_children())
	return cells


## The doors, in the order they stand: one under each block of ten.
func _doors() -> Array:
	return _track_blocks.get_children().filter(
		func(node: Node) -> bool: return node is Button)


func _open_track_grid(kind := TrackRoster.NORMAL) -> void:
	_track_kind = kind
	_track_heading.text = "ACROBATIC TRACKS" if kind == TrackRoster.ACROBATIC else "CHOOSE A TRACK"
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
	var cells := _track_cells()
	if index >= 0 and index < cells.size():
		var wanted := _button_in(cells[index])
		if wanted != null and not wanted.disabled:
			wanted.grab_focus()
			return
	# Anything on the page that can be pressed, doors included, in the order
	# the page shows them. A player whose first ten are behind them should land
	# on the door they are about to drive rather than on the way out.
	for block in _track_blocks.get_children():
		var door := block as Button
		if door != null:
			if not door.disabled:
				door.grab_focus()
				return
			continue
		for cell in block.get_children():
			var button := _button_in(cell)
			if button != null and not button.disabled:
				button.grab_focus()
				return
	_track_back.grab_focus()


## Put the cursor on the door at the end of a block, for coming back off one.
func _focus_door(block: int) -> void:
	var doors := _doors()
	if block >= 0 and block < doors.size() and not doors[block].disabled:
		doors[block].grab_focus()
		return
	_focus_track()


func _button_in(cell: Node) -> Button:
	for child in cell.get_children():
		if child is Button:
			return child
	return null


func _start_track(path: String, variant := TrackVariant.NORMAL) -> void:
	GameSettings.track_file = path
	GameSettings.track_variant = variant
	# A track is a road to learn and a time to beat, so it is always run under
	# the same rules. Chaos rerolls the cars for every race, and a time set by
	# a car nobody will be given again is not a time.
	GameSettings.chaos = false
	GameSettings.save_settings()
	get_tree().change_scene_to_file(_scene_for_the_players())


## Whether pressing a track opens its own page rather than starting it.
##
## Every track in either grid has one. A bot road does not: it is a door, one
## race against one road, and has no ways of being driven to choose between.
func _has_a_page(index: int) -> bool:
	return TrackRoster.exists(index) and TrackRoster.kind_of(index) != TrackRoster.BOT


## A track's own page: its name, a wide shot of the road, and the ways it can
## be driven. The grid steps aside for it, as the mode page does for the grid.
##
## `variant` is the way held down to start with: NORMAL off the grid, and the
## way the player last drove it on the way back from a race, since the same
## way again is what they are most likely to press PLAY for.
func _open_track_detail(index: int, variant := TrackVariant.NORMAL) -> void:
	_detail_index = index
	_detail_heading.text = TrackRoster.track_name(index).to_upper()
	_detail_blurb.text = TrackRoster.blurb(index)
	_detail_blurb.visible = not _detail_blurb.text.is_empty()
	_detail_picture.texture = TrackRoster.wide_shot(index)
	# An acrobatic track is driven NORMAL or MIRROR and nothing else. HARD would
	# stand barriers on its landings, and track chaos would roll them there,
	# and a barrier on a landing is a much meaner thing than one on a straight.
	var acrobatic := TrackRoster.kind_of(index) == TrackRoster.ACROBATIC
	_detail_hard.visible = not acrobatic
	_detail_track_chaos.visible = not acrobatic
	_track_choice.hide()
	_track_detail.show()
	# The way asked for is held down to start with, and the cursor is on PLAY,
	# so Enter straight away drives it: the track as it is written, off the
	# grid.
	if variant not in TrackVariant.offered(TrackRoster.file(index)):
		variant = TrackVariant.NORMAL
	_detail_variant = variant
	(_detail_normal.get_parent().get_child(TrackVariant.ALL.find(variant)) as Button
		).button_pressed = true
	_show_the_way()
	_detail_play.grab_focus()
	_fetch_the_detail_board()


## Hold a way of driving down and put its board up.
func _choose_detail_variant(variant: String) -> void:
	if variant == _detail_variant:
		return
	_detail_variant = variant
	_show_the_way()
	_fetch_the_detail_board()


## What the page says about the way held down, apart from its board: the
## picture turned round for MIRROR, and PLAY only for a way the track offers,
## with the reason under it where it does not. Every way the track does not
## offer is faded, whichever is held.
func _show_the_way() -> void:
	var file := TrackRoster.file(_detail_index)
	var offered := TrackVariant.offered(file)
	# The same overhead shot flipped, rather than a second picture drawn and
	# checked in: a mirrored road is exactly that shot the other way round.
	_detail_picture.flip_h = _detail_variant == TrackVariant.MIRROR
	var ways := _detail_normal.get_parent().get_children()
	for at in ways.size():
		(ways[at] as Button).modulate.a = (1.0 if TrackVariant.ALL[at] in offered
			else unoffered_alpha)
	_detail_play.disabled = _detail_variant not in offered
	_detail_why.text = TrackVariant.why_not(file, _detail_variant)


## Put the track's board up beside its picture, and the player's own time and
## place beside that. The time is this machine's and is there at once; the
## board comes off the server and lands whenever it lands, so the page is never
## held still waiting for it.
func _fetch_the_detail_board() -> void:
	_detail_board_heading.text = "LEADERBOARD · %s" % TrackVariant.display_name(_detail_variant)
	_show_the_detail_board([])
	if not Leaderboard.available():
		_detail_note.text = "This copy of the game has no server, so there is no board."
		return
	_detail_note.text = "Loading…"
	_detail_asked += 1
	var asked := _detail_asked
	var rows: Array = await Leaderboard.board(
		TrackRoster.file(_detail_index), false, _detail_variant)
	if asked != _detail_asked or not _track_detail.visible:
		return
	_show_the_detail_board(rows)


## The board's rows, and where the player stands on it.
func _show_the_detail_board(rows: Array) -> void:
	for row in _detail_rows.get_children():
		_detail_rows.remove_child(row)
		row.queue_free()
	var mine_at := -1
	for place in rows.size():
		var row: Dictionary = rows[place]
		if bool(row.get("mine", false)):
			mine_at = place
		_detail_rows.add_child(LeaderboardMenu.line(place + 1, row, 18))
	_detail_note.text = "" if not rows.is_empty() else "Nobody has set a time here yet."

	# The time is this machine's record, coloured by what it is worth, with
	# the medal's bar under it the way a cell on the grid has one.
	var best := TrackTimes.best(TrackRoster.file(_detail_index), _detail_variant)
	var targets := TrackVariant.targets(TrackRoster.targets(_detail_index), _detail_variant)
	var medal := Medal.earned(best, targets)
	_detail_time.text = RaceClock.format(best) if best >= 0.0 else "NO TIME"
	_detail_time.add_theme_color_override("font_color",
		Medal.colour(medal) if best >= 0.0 else Color(0.55, 0.58, 0.66))
	_detail_medal.color = Medal.colour(medal)
	_detail_medal.modulate.a = 1.0 if medal != Medal.NONE else 0.0

	# The place is the row the server has for the player where there is one.
	# Where there is not, it is where their time would land among the rows
	# that are up, and the line under it says why it is not on the board.
	_detail_place_note.text = ""
	if mine_at >= 0:
		_detail_place.text = _ordinal(mine_at + 1)
	elif best < 0.0:
		_detail_place.text = "—"
		_detail_place_note.text = "Set a time to get a place."
	elif not Leaderboard.available():
		_detail_place.text = "—"
	else:
		var ahead := rows.filter(func(row: Dictionary) -> bool:
			return float(row.get("seconds", 0.0)) < best).size()
		if ahead >= Leaderboard.BOARD_SIZE:
			_detail_place.text = "—"
			_detail_place_note.text = "Outside the top %d." % Leaderboard.BOARD_SIZE
		else:
			_detail_place.text = _ordinal(ahead + 1)
			_detail_place_note.text = ("Sign in to put it on the board."
				if not Backend.is_signed_in() else "Not on the board yet.")


## 1st, 2nd, 3rd, 4th ... 11th, 12th, 13th ... 21st.
static func _ordinal(place: int) -> String:
	var suffix := "th"
	if place % 100 < 11 or place % 100 > 13:
		match place % 10:
			1: suffix = "st"
			2: suffix = "nd"
			3: suffix = "rd"
	return "%d%s" % [place, suffix]


func _close_track_detail() -> void:
	_track_detail.hide()
	_track_choice.show()
	_focus_track(_detail_index - TrackRoster.first(_track_kind))


## Drive the track the way held down. PLAY is disabled on a way the track does
## not offer, and this asks again rather than trusting that: a race on a way
## nobody checked is a time on a road nobody has looked at.
func _start_detail_track() -> void:
	var file := TrackRoster.file(_detail_index)
	if _detail_variant not in TrackVariant.offered(file):
		return
	_start_track(file, _detail_variant)


func _close_track_choice() -> void:
	_track_choice.hide()
	_mode_choice.show()
	if not _kind_slot.visible:
		_tracks_button.grab_focus()
	elif _track_kind == TrackRoster.ACROBATIC:
		_acrobatic_button.grab_focus()
	else:
		_normal_tracks_button.grab_focus()


## Which scene a race runs in. Everything else about a race - the endless
## course or a laid-out track, chaos or not - is a setting the scene reads;
## how many are playing is the one thing that decides which scene it is.
func _scene_for_the_players() -> String:
	# With one exception, and it is not a preference being overridden. A bot
	# race is one player against one computer: the second car on that road is
	# the thing being raced, and there is no seat in it for a second player
	# however the question at the top of the page was answered.
	if TrackRoster.is_bot_road(GameSettings.track_file):
		return solo_scene
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


func _fit_kinds() -> void:
	_kind_inner.size.x = _kind_slot.size.x


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


func _slide_kinds(open: bool) -> void:
	_kind_tween = _slide(_kind_slot, _kind_inner, open, _kind_tween)


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
		_shut_kinds()
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


func _shut_kinds() -> void:
	_shut(_kind_slot, _kind_tween)


func _shut_modes() -> void:
	_modes_open = false
	_shut(_mode_slot, _mode_tween)


func _close_mode_choice() -> void:
	_mode_choice.hide()
	_shut_flavour()
	_shut_kinds()
	_shut_modes()
	_play.grab_focus()


## Escape backs out of whichever page is open. The screens that lie over these
## handle their own, so they get first refusal on the key.
func _input(event: InputEvent) -> void:
	if _settings_screen.visible or _account_screen.visible or _garage_screen.visible:
		return
	if _shop_screen.visible:
		return
	if _boards_screen.visible or _stats_screen.visible:
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	# One thing at a time, innermost first: off a track's own page, then off
	# the track grid, then off the flavour choice or the kinds of track, then
	# off the modes, then off the page.
	if _track_detail.visible:
		get_viewport().set_input_as_handled()
		_close_track_detail()
	elif _track_choice.visible:
		get_viewport().set_input_as_handled()
		_close_track_choice()
	elif _flavour_slot.visible:
		get_viewport().set_input_as_handled()
		_slide_flavour(false)
		_infinite_button.grab_focus()
	elif _kind_slot.visible:
		get_viewport().set_input_as_handled()
		_slide_kinds(false)
		_tracks_button.grab_focus()
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


## The garage lies over the title the way it lies over a paused race, and asks
## the question the pause menu asks it: how many cars there are to put somebody
## in. On the title that is however the last race was played.
func _on_garage_pressed() -> void:
	_garage_screen.open(1 if GameSettings.solo else 2)


func _on_garage_closed() -> void:
	_garage_button.grab_focus()


## The shop lies over the title the way the garage does, and for the same
## reason: what it sells goes on the cars parked on the grid behind it.
func _on_shop_pressed() -> void:
	_shop_screen.open()


func _on_shop_closed() -> void:
	_shop_button.grab_focus()


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


func _on_stats_closed() -> void:
	_stats_button.grab_focus()


## A sync moved a record. Only the track grid shows times, and only when it is
## open, so there is nothing to do the rest of the time.
func _on_times_changed() -> void:
	if _track_choice.visible:
		_refresh_the_track_grid()
	if _track_detail.visible:
		_fetch_the_detail_board()


## The track the cursor is on, or an empty string if it is not on one. Worked
## out from focus rather than remembered, so it cannot go stale.
func _track_under_the_cursor() -> String:
	var focused := get_viewport().gui_get_focus_owner()
	var cells := _track_cells()
	for index in cells.size():
		if _button_in(cells[index]) == focused:
			return TrackRoster.file(TrackRoster.first(_track_kind) + index)
	# A bot road keeps nothing a board can show - no time, no medal, no place -
	# so a cursor sitting on a door falls back to the first of the ten it
	# stands at the end of rather than opening a board that can never have
	# anything on it. The same for a player who came back from one, whose
	# picked road is still that door.
	var doors := _doors()
	for block in doors.size():
		if doors[block] == focused:
			return TrackRoster.file(block * Progress.BLOCK)
	if TrackRoster.is_bot_road(GameSettings.track_file):
		return TrackRoster.file(
			TrackRoster.block_of_bot_road(GameSettings.track_file) * Progress.BLOCK)
	return GameSettings.track_file
