class_name DecorationPage
extends VBoxContainer

## The garage's second tab: what a car is decorated with.
##
## A tab rather than a screen of its own. Decorating a car is a thing done to
## a car, and the car it is done to is the one the player picked on the other
## tab - putting it behind a third button somewhere else would mean choosing a
## car in one place and drawing on it in another, with nothing on either page
## saying they were about the same thing.
##
## Everything here is applied as it is chosen, never on the way out. The car
## stands on the left of the page wearing whatever has just been pressed, which
## is the same choice the paint screen made for the same reason: a decoration
## confirmed two presses after it was picked is a guess.
##
## **Everything is put on the car itself.** There used to be a flat drawing of
## the side of a car on this page, and stickers were dragged about on that
## while the model turned on a plinth beside it looking pleased with itself.
## Two pictures of one car, and the one being worked on was the one that was
## not real: a silhouette has no roof, no nose and no tail, so three quarters
## of a car could not be drawn on at all, and nothing a player placed was ever
## quite where they had put it. So the model is the page now. It is turned and
## zoomed with the mouse, a sticker lands on the bodywork where it is put, and a
## word is written straight onto the paintwork with the pen - on whatever part
## of the car the pen is over, bonnet and all.
##
## The objection that put the silhouette there in the first place was a fair
## one - a small precision task on a moving target is not something to ask of
## anybody - and it is answered rather than ignored: the car does not move any
## more unless it is moved. See [scripts/car_stage.gd](car_stage.gd).
##
## **The car's own paint is here as well**, in a row under the car. It is not
## decoration and it costs nothing - the fifty coins buy the drawing, not the
## painting - but it is the same question asked of the same car, and the only
## other place in the game to ask it was the paint screen over a paused race.
## A player looking at their car in the garage and wanting it green should not
## have to start a race to say so. It is under the car rather than over in the
## tools with the rest, because it is about the car and not about what is going
## on the car, and because a colour is chosen by looking at the thing wearing
## it.
##
## The three kinds are still not offered the same way, because they are still
## not the same kind of choice. **Stripes** are toggles - there are four of
## them, each is on or off, and they are worn in the model's own texture space
## where there is nothing to place. **Stickers** and **hand-written words** are
## placed, and now they are placed where the hand is.
##
## Nothing here is hidden behind the fifty coins the slot costs. Every button
## is on the page and every button can be pressed; pressing one without the
## slot says what it costs and where it is sold. That is the shop's own rule
## about an empty purse ([scripts/shop_menu.gd](shop_menu.gd)) applied on this
## side of the counter: the price is the reason to pick a coin up, and a page
## that hid itself until it was paid for would give nobody that reason.

## Said to whoever is showing the page, for their status line. The garage
## already has one at the bottom of the panel, and a second one inside the tab
## would be two lines arguing about which of them is the current one.
signal said(what: String, colour: Color)

const QUIET := Color(0.72, 0.76, 0.86)
const WRONG := Color(0.98, 0.55, 0.5)
const RIGHT := Color(0.6, 0.9, 0.68)
## The coin's own gold, the same as in the shop and on a locked swatch.
const PRICE_COLOUR := Color(1.0, 0.82, 0.24)

## How big the car standing on the left is, and how wide the tools beside it
## are. The car has the room the silhouette used to have as well as its own:
## it is the page now, and a panel on a car at this size is a panel somebody
## can aim at.
const STAGE_SIZE := Vector2(742.0, 248.0)
const TOOLS_WIDTH := 384.0

## How big a sticker starts out, as a fraction of the car's length. A quarter:
## plainly a sticker on a door rather than a wrap, and big enough to see what
## it is without being dragged bigger first.
const START_SIZE := 0.26

## The least a hand-written word may be, as a fraction of the car's length. A
## word is as big as it was drawn, and a full stop drawn with one tap of the
## mouse would otherwise be a mark too small to find again.
const LEAST_WORD := 0.10

## How far off the plane a word was started on the pen may still land on the
## body, as a fraction of the car's length: about a hand's width on the stock
## car. See `_pen_at`.
const PEN_REACH := 0.05

## How thick the pen can draw, as fractions of the car's length, thinnest
## first. Offered beside DONE while the pen is out.
##
## A fraction of the car and not of the word, because that is what a player is
## choosing: a line as thick on the door as the one they are drawing. The pen
## used to draw a fixed fraction of the word's own box instead, so a short word
## came out in a thinner line than the one that had just been drawn and a long
## one in a fatter - the stroke changed width the moment it was let go of.
## Now the word works out, from the box it ended up in, the share of that box
## the chosen width is (`_word_from`), and it is drawn at exactly that.
const NIBS: Array[float] = [0.010, 0.018, 0.028, 0.040]
const NIB_NAMES: Array[String] = ["FINE", "MEDIUM", "BOLD", "FAT"]

## How tall a paint swatch in the row under the car is. Short and wide, because
## eighteen of them go across the width of the car: this is a strip of paint to
## pick out of, not the grid of squares the paint screen lays out when the
## paints are the only thing on the page.
const PAINT_HEIGHT := 26.0

var _players := 1
## Which player's car is being drawn on. Both get to decorate their own.
var _player := 0
## The colour the next thing goes on in, and the one a swatch puts on whatever
## is selected.
var _colour := 0
## Which mark on the car is selected, as a slot in the car's own list, or -1.
var _chosen := -1
## True while the page is putting its own values into its own sliders, so a
## slider being set does not read as a player moving it.
var _settling := false

## Where a mark was grabbed, as the gap on the screen between the cursor and
## the mark's middle, so a sticker does not jump under the cursor when it is
## picked up by its edge. And which of the decals it is worn as was grabbed,
## so a mark on the doors is dragged about the door it was taken hold of rather
## than the one on the far side of the car.
var _grab := Vector2.ZERO
var _grab_copy := 0
var _dragging := false
## True while the car is being turned by a drag, whichever button started it.
var _turning := false
## True while the manual camera is being slid across the view by a drag.
var _panning := false

## True while the pen is out, which is what DRAW ON IT toggles.
var _writing := false
## Where the word being written was started, as `{point, normal, right}` on
## the car: the first point the pen touched, the way the body faced there, and
## which way was right on the screen. Empty when there is no word on the go.
var _pen_where := {}
## The strokes of it that are finished, and the one in the player's hand, as
## points on the car. And, a stroke at a time, the way the body faced under
## each - added up, which is what the word is laid flat against.
var _written: Array = []
var _stroke := PackedVector3Array()
var _written_aims: Array[Vector3] = []
var _stroke_aim := Vector3.ZERO
## Where the word is in the car's list of marks, or -1 before the first stroke
## of it has landed.
var _writing_at := -1
## Which of `NIBS` the pen draws with. Kept while the page is open, so a player
## writing a second word gets the width they wrote the first one in.
var _nib := 1
## Whether what goes on a door next goes on the other door as well: MIRROR,
## ticked to start with, because a number on one door is on both - which is
## how every mark was worn before there was a choice. Kept while the page is
## open, the way the pen's width is.
var _mirror := true

var _whose: HBoxContainer
var _whose_buttons: Array[Button] = []
var _stage: CarStage
var _automatic_box: CheckBox
var _manual_box: CheckBox
var _stripe_buttons: Array[Button] = []
var _swatches: Array[Button] = []
var _paints: Array[Button] = []
var _draw_button: Button
var _undo_button: Button
var _nib_buttons: Array[Button] = []
var _keep_button: Button
var _mirror_box: CheckBox
var _size_slider: HSlider
var _turn_slider: HSlider
var _off_button: Button
var _all_off_button: Button
var _cover: Label

## The panel that asks what a design should be called, which lies over the
## whole garage.
var _naming: Control
var _name_edit: LineEdit
var _keep_it_button: Button


## Build the page, and hang the naming panel off the screen that owns the tab.
##
## The panel has to lie over the whole garage rather than inside the tab, the
## way the garage's own naming panel and its list of shared cars do, so it is
## given to the host rather than added here.
func setup(host: Control) -> void:
	add_theme_constant_override("separation", 8)
	_build_the_players()
	_build_the_body()
	_build_the_cover_line()
	_build_the_naming_panel(host)
	Decals.changed.connect(_on_decals_changed)
	Liveries.changed.connect(_on_liveries_changed)
	Purse.changed.connect(_on_purse_changed)
	# The paint is written to the settings and read back off them, the way the
	# paint screen does it, so the car on this page repaints from the setting
	# rather than from the press - one way in, and the car cannot end up
	# wearing a colour the saved setting does not agree with.
	GameSettings.changed.connect(_on_settings_changed)


## Show the tab, with a row of players if there are two.
func opened(players: int) -> void:
	_players = clampi(players, 1, 2)
	_whose.visible = _players > 1
	_player = clampi(_player, 0, _players - 1)
	_chosen = -1
	_stop_writing()
	_naming.hide()
	# Opened on the same view every time. A car left nose-on and zoomed into
	# its own boot lid from last time is a page that opens looking broken.
	_stage.reset_view()
	refresh()
	_say_how_the_camera_goes()


## Put the keyboard somewhere on the page. The first stripe, because it is the
## first thing on it that does anything, and because both players are on one
## keyboard and neither has been asked to find the mouse. The car itself takes
## the keyboard too, one Tab back from here, and the arrows turn it once it
## has.
func first_focus() -> void:
	if not _stripe_buttons.is_empty():
		_stripe_buttons[0].grab_focus()


## Whether the page took the Escape itself. The pen is put down before the
## garage is left, because a player with it in their hand means that first.
func backed_out() -> bool:
	if _naming.visible:
		_close_the_naming()
		return true
	if not _writing:
		return false
	_stop_writing()
	_show_the_draw_buttons()
	said.emit("THE PEN IS DOWN.", QUIET)
	return true


# --- what is being drawn on ---------------------------------------------

## The car being decorated: the one this player is actually driving, not the
## one the cursor happens to be over on the other tab. Decoration goes on a
## car, and the car a player means is the one they are in.
func _car_id() -> String:
	var id := GameSettings.car_id(_player)
	return id if Garage.known(id) else Garage.STOCK


func _marks() -> Array:
	return Decals.marks_on(_car_id())


## Whether the slot has been paid for. Nothing is hidden or disabled by this -
## it is only what every action asks before it does anything.
func _bought() -> bool:
	return Purse.owns(Shop.SLOT_ITEM)


## Said when something is pressed without the slot: why nothing happened, and
## how far off the player is.
##
## The price is not in here, because the line above the BACK button is already
## carrying it and two lines one over the other saying the same sentence is a
## page arguing with itself. This one says the part that changes - what is in
## the purse - and that one says the part that does not.
func _say_it_is_locked() -> void:
	said.emit("THAT NEEDS THE CUSTOMISING SLOT. THERE ARE %d COINS IN THE PURSE."
		% Purse.coins(), PRICE_COLOUR)


# --- the page -----------------------------------------------------------

func _build_the_players() -> void:
	_whose = HBoxContainer.new()
	_whose.alignment = BoxContainer.ALIGNMENT_CENTER
	_whose.add_theme_constant_override("separation", 10)
	add_child(_whose)
	var label := Label.new()
	label.text = "WHOSE CAR"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", QUIET)
	_whose.add_child(label)
	for player in 2:
		var button := Button.new()
		button.text = "PLAYER %d" % (player + 1)
		button.toggle_mode = true
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(_choose_player.bind(player))
		_whose.add_child(button)
		_whose_buttons.append(button)


func _build_the_body() -> void:
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(body)

	# The car and the paint it is wearing, in one column: the swatches are
	# under the thing they paint, and the car takes whatever height is left
	# over once they have had theirs, so the page is no taller for them.
	var showing := VBoxContainer.new()
	showing.add_theme_constant_override("separation", 6)
	showing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(showing)

	_stage = CarStage.new()
	_stage.custom_minimum_size = STAGE_SIZE
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.tooltip_text = ("drag to turn the car, the wheel to look closer · "
		+ "press a sticker on it to pick it up, drag it anywhere on the body · "
		+ "with the manual camera, Shift or the middle button and a drag slides it")
	_stage.gui_input.connect(_stage_input)
	showing.add_child(_stage)
	_stage.add_child(_build_the_camera_choice())
	showing.add_child(_build_the_paint_row())

	body.add_child(_build_the_tools())


## AUTOMATIC CAMERA or MANUAL CAMERA, in the top left corner of the car.
##
## Two boxes in one group, so ticking one unticks the other and one of them is
## always ticked: a camera is one or the other, never both and never neither.
## Over the car rather than among the tools, because it is about how the car is
## looked at and that is where a player is looking when they want it - and it
## costs the page no height. Automatic to start with, which is the camera there
## always was. See [scripts/car_stage.gd](car_stage.gd) for what each one does.
func _build_the_camera_choice() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = Vector2(8.0, 8.0)
	# The gaps in it are still the car, for a press or a drag that starts there.
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.05, 0.06, 0.1, 0.72)
	back.set_corner_radius_all(4)
	back.content_margin_left = 8.0
	back.content_margin_right = 10.0
	back.content_margin_top = 3.0
	back.content_margin_bottom = 3.0
	panel.add_theme_stylebox_override("panel", back)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	var group := ButtonGroup.new()
	_automatic_box = _camera_box(group, "AUTOMATIC CAMERA",
		"The camera looks at the middle of the car and always fits all of it.")
	_automatic_box.button_pressed = true
	_automatic_box.toggled.connect(_on_camera_ticked.bind(false))
	column.add_child(_automatic_box)
	_manual_box = _camera_box(group, "MANUAL CAMERA",
		"The camera is yours: the wheel goes towards whatever is under the cursor, "
		+ "and the middle button or Shift and a drag slides it.")
	_manual_box.toggled.connect(_on_camera_ticked.bind(true))
	column.add_child(_manual_box)
	return panel


func _camera_box(group: ButtonGroup, what: String, tip: String) -> CheckBox:
	var box := CheckBox.new()
	box.text = what
	box.button_group = group
	box.tooltip_text = tip
	box.add_theme_font_size_override("font_size", 14)
	_flatten(box)
	return box


## A tick box with no button drawn round it: the tick and the words, and the
## theme's own line round it only while it has the keyboard. A box drawn round
## every tick box is a page of buttons that do not look like choices.
##
## And an empty box that can be seen. The theme's is a dark grey square, or
## circle, on what is here a dark blue page, and a choice whose other half
## cannot be seen does not look like a choice at all.
func _flatten(box: CheckBox) -> void:
	for state in ["normal", "pressed", "hover", "hover_pressed", "disabled"]:
		var flat := StyleBoxEmpty.new()
		flat.content_margin_left = 4.0
		flat.content_margin_right = 4.0
		box.add_theme_stylebox_override(state, flat)
	box.add_theme_icon_override("unchecked", _empty_box(false))
	box.add_theme_icon_override("radio_unchecked", _empty_box(true))


## An empty tick box drawn as an outline, round for one of a group.
func _empty_box(round: bool) -> ImageTexture:
	var theirs := get_theme_icon("radio_unchecked" if round else "unchecked",
		"CheckBox")
	var side := maxi(theirs.get_width() if theirs != null else 16, 12)
	var image := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var ink := Color(0.78, 0.82, 0.92)
	var middle := (side - 1) * 0.5
	var outer := side * 0.5 - 1.5
	for y in side:
		for x in side:
			var gap := Vector2(x - middle, y - middle)
			var far := gap.length() if round else maxf(absf(gap.x), absf(gap.y))
			# About a pixel and a half of line, softened at both edges.
			var on := clampf(1.0 - absf(far - (outer - 0.75)) + 0.25, 0.0, 1.0)
			if on > 0.0:
				image.set_pixel(x, y, Color(ink, on))
	return ImageTexture.create_from_image(image)


## Called for both boxes, the one being ticked and the one the group unticks
## for it; only the ticking says anything.
func _on_camera_ticked(on: bool, manual: bool) -> void:
	if on:
		_choose_camera(manual)


func _choose_camera(manual: bool) -> void:
	_panning = false
	_stage.set_manual(manual)
	_say_how_the_camera_goes()


func _say_how_the_camera_goes() -> void:
	if _stage.is_manual():
		# No longer than the line for the automatic one: the status line is as
		# wide as the garage, and a longer one widens the garage.
		said.emit("MANUAL CAMERA · THE WHEEL GOES TOWARDS THE CURSOR · "
			+ "SHIFT AND DRAG SLIDES IT", QUIET)
		return
	said.emit("DRAG THE CAR TO TURN IT · THE WHEEL LOOKS CLOSER · "
		+ "PUT THINGS ANYWHERE ON THE BODY", QUIET)


## The eighteen paints, in a row under the car.
##
## The same eighteen the paint screen shows and dressed the same way, because
## it is the same choice about the same car: the free twelve, then the six the
## shop sells, faded with their price written across them until they are
## bought. A player who has met one of those here and one of them there has met
## one thing.
##
## They are not disabled, which is the one way this differs from that screen.
## Everything on this page can be pressed and says why nothing happened, for
## the reason the shop keeps BUY pressable over an empty purse: a disabled
## button in Godot cannot take keyboard focus, and both players are on one
## keyboard. The face is the same either way, so the two rows still look alike;
## it is only that this one answers.
func _build_the_paint_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	var label := _small("PAINT")
	label.custom_minimum_size.x = 52.0
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	for index in Paints.COLOURS.size():
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(0.0, PAINT_HEIGHT)
		swatch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		swatch.clip_text = true
		swatch.add_theme_font_size_override("font_size", 13)
		swatch.add_theme_color_override("font_color", PRICE_COLOUR)
		swatch.add_theme_color_override("font_hover_color", PRICE_COLOUR)
		swatch.add_theme_color_override("font_pressed_color", PRICE_COLOUR)
		swatch.add_theme_color_override("font_focus_color", PRICE_COLOUR)
		swatch.pressed.connect(_choose_paint.bind(index))
		row.add_child(swatch)
		_paints.append(swatch)
	return row


func _build_the_tools() -> VBoxContainer:
	var tools := VBoxContainer.new()
	tools.custom_minimum_size.x = TOOLS_WIDTH
	tools.add_theme_constant_override("separation", 4)

	tools.add_child(_small("STRIPES"))
	var stripes := HBoxContainer.new()
	stripes.add_theme_constant_override("separation", 4)
	tools.add_child(stripes)
	for shape in DecalArt.STRIPES.size():
		var button := Button.new()
		button.text = DecalArt.stripe_name(shape)
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 14)
		button.pressed.connect(_toggle_stripe.bind(shape))
		stripes.add_child(button)
		_stripe_buttons.append(button)

	tools.add_child(_small("STICKERS · THEY LAND WHERE YOU ARE LOOKING, THEN DRAG THEM"))
	var stickers := HBoxContainer.new()
	stickers.add_theme_constant_override("separation", 4)
	tools.add_child(stickers)
	for shape in DecalArt.STICKERS.size():
		var button := Button.new()
		button.icon = DecalArt.sticker_stamp(shape)
		button.expand_icon = true
		button.custom_minimum_size = Vector2(0.0, 40.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = DecalArt.sticker_name(shape)
		button.pressed.connect(_add_sticker.bind(shape))
		stickers.add_child(button)

	tools.add_child(_small("A WORD IN YOUR OWN HAND"))
	var pen := HBoxContainer.new()
	pen.add_theme_constant_override("separation", 6)
	tools.add_child(pen)
	_draw_button = Button.new()
	_draw_button.text = "DRAW ON IT"
	_draw_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_draw_button.add_theme_font_size_override("font_size", 18)
	_draw_button.tooltip_text = ("Take the pen out, and write on the car with "
		+ "it. Every stroke goes on the paintwork as you finish it.")
	_draw_button.pressed.connect(_press_the_pen)
	pen.add_child(_draw_button)
	# In the row the pen is already in rather than a row of their own, so the
	# page is no taller with the pen out than with it away.
	for nib in NIBS.size():
		var button := Button.new()
		button.toggle_mode = true
		button.custom_minimum_size.x = 34.0
		button.tooltip_text = "A %s PEN" % NIB_NAMES[nib]
		button.pressed.connect(_choose_nib.bind(nib))
		button.draw.connect(_draw_a_nib.bind(button, nib))
		pen.add_child(button)
		_nib_buttons.append(button)
	_undo_button = Button.new()
	_undo_button.text = "UNDO"
	_undo_button.custom_minimum_size.x = 96.0
	_undo_button.add_theme_font_size_override("font_size", 18)
	_undo_button.tooltip_text = "Take the last stroke back off the car."
	_undo_button.pressed.connect(_undo_a_stroke)
	pen.add_child(_undo_button)

	# On the colour's row, because both are how the next thing goes on rather
	# than anything about what is on already - and because a row of its own
	# is a row the page does not have to spare at the largest interface size.
	var how := HBoxContainer.new()
	tools.add_child(how)
	var colour_label := _small("THE COLOUR IT ALL GOES ON IN")
	colour_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	how.add_child(colour_label)
	_mirror_box = CheckBox.new()
	_mirror_box.text = "MIRROR"
	_mirror_box.button_pressed = _mirror
	_mirror_box.add_theme_font_size_override("font_size", 15)
	# No margin above or below the box, so the row is no taller than the words
	# beside it.
	_flatten(_mirror_box)
	_mirror_box.tooltip_text = ("Ticked, what goes on one door goes on the other "
		+ "door too.\nUnticked, it stays on the door it was put on.")
	_mirror_box.toggled.connect(_toggle_the_mirror)
	how.add_child(_mirror_box)
	var palette := GridContainer.new()
	palette.columns = 12
	palette.add_theme_constant_override("h_separation", 3)
	tools.add_child(palette)
	# The free twelve only. The six the shop sells are paint, and a stripe in
	# one would be a way of wearing a bought colour without buying it.
	for index in Paints.FREE:
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(0.0, 26.0)
		swatch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		swatch.tooltip_text = Paints.name_of(index)
		swatch.pressed.connect(_choose_colour.bind(index))
		palette.add_child(swatch)
		_swatches.append(swatch)

	_size_slider = _slider(tools, "SIZE", 0.10, 0.62, 0.01)
	_size_slider.value_changed.connect(_on_size_changed)
	_turn_slider = _slider(tools, "TURN", -PI, PI, 0.04)
	_turn_slider.value_changed.connect(_on_turn_changed)

	_keep_button = Button.new()
	_keep_button.text = "SAVE AS A LIVERY"
	_keep_button.add_theme_font_size_override("font_size", 16)
	_keep_button.pressed.connect(_ask_what_to_call_it)
	tools.add_child(_keep_button)

	var off := HBoxContainer.new()
	off.add_theme_constant_override("separation", 6)
	tools.add_child(off)
	_off_button = Button.new()
	_off_button.text = "TAKE IT OFF"
	_off_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_off_button.add_theme_font_size_override("font_size", 16)
	_off_button.pressed.connect(_take_it_off)
	off.add_child(_off_button)
	_all_off_button = Button.new()
	_all_off_button.text = "TAKE IT ALL OFF"
	_all_off_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_all_off_button.add_theme_font_size_override("font_size", 16)
	_all_off_button.pressed.connect(_take_it_all_off)
	off.add_child(_all_off_button)
	return tools


func _slider(into: VBoxContainer, what: String, least: float, most: float,
		step: float) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	into.add_child(row)
	var label := _small(what)
	label.custom_minimum_size.x = 52.0
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = least
	slider.max_value = most
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	return slider


func _small(what: String) -> Label:
	var label := Label.new()
	label.text = what
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", QUIET)
	return label


func _build_the_cover_line() -> void:
	_cover = Label.new()
	_cover.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cover.add_theme_font_size_override("font_size", 16)
	_cover.add_theme_color_override("font_color", QUIET)
	add_child(_cover)


# --- the car, and what the mouse does to it -----------------------------

## Everything the mouse does on the car, which is everything this page does.
##
## The rule is that the left button is for the car's paintwork and the right
## button is for the camera, with one exception: the left button on a part of
## the view that is not a mark turns the car as well. That exception is what
## makes it possible to turn a car with a mouse that has one button, and it
## costs nothing, because a press that did not land on anything was not a press
## that meant to do something to the car.
func _stage_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null:
		_stage_button(button)
		return
	var moved := event as InputEventMouseMotion
	if moved != null:
		_stage_motion(moved)
		return
	var key := event as InputEventKey
	if key != null and key.pressed:
		_stage_key(key)
		return
	# A pinch on a trackpad is the wheel for somebody who has no wheel.
	var pinch := event as InputEventMagnifyGesture
	if pinch != null:
		_stage.zoom_by((pinch.factor - 1.0) * 6.0, pinch.position)
		_stage.accept_event()


func _stage_button(button: InputEventMouseButton) -> void:
	match button.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if button.pressed:
				_stage.zoom_by(1.0, button.position)
			return
		MOUSE_BUTTON_WHEEL_DOWN:
			if button.pressed:
				_stage.zoom_by(-1.0, button.position)
			return
		MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
			# The manual camera slides with the middle button, or with either
			# of the others while Shift is down, for a mouse with no middle
			# button and a trackpad with no buttons at all.
			var slide := _stage.is_manual() and (
				button.button_index == MOUSE_BUTTON_MIDDLE or button.shift_pressed)
			_panning = button.pressed and slide
			_turning = button.pressed and not slide
			return
		MOUSE_BUTTON_LEFT:
			pass
		_:
			return
	_stage.grab_focus()
	if not button.pressed:
		_let_go()
		return
	if not _bought():
		_say_it_is_locked()
		return
	if _writing:
		_start_a_stroke(button.position)
		return
	if _take_hold(button.position):
		return
	if _stage.is_manual() and button.shift_pressed:
		_panning = true
		return
	_turning = true


func _stage_motion(moved: InputEventMouseMotion) -> void:
	if _panning:
		_stage.pan_by(moved.relative)
		return
	if _turning:
		# What is being taken hold of is the car and not the camera it is being
		# looked at with, so the part of it under the cursor goes where the
		# cursor goes: dragged left the nose comes round to the left, and
		# dragged down the roof comes up into view. The camera goes the other
		# way to do it, which is the arithmetic's business and nobody else's.
		_stage.turn_by(moved.relative.x * CarStage.DRAG_TO_TURN,
			moved.relative.y * CarStage.DRAG_TO_TURN)
		return
	if _writing and not _stroke.is_empty():
		_draw_to(moved.position)
		return
	if _dragging:
		_drag_to(moved.position + _grab)


## The arrows and the wheel, for the keyboard half of the same thing.
##
## What the arrows do depends on whether anything is selected, and that is the
## whole of the rule: with a sticker in hand they move the sticker, and with
## nothing in hand they turn the car. Anything else would need a second set of
## keys for a page that is already sharing one keyboard with two players.
func _stage_key(key: InputEventKey) -> void:
	var step := Vector2.ZERO
	match key.keycode:
		KEY_LEFT:
			step = Vector2(-1.0, 0.0)
		KEY_RIGHT:
			step = Vector2(1.0, 0.0)
		KEY_UP:
			step = Vector2(0.0, -1.0)
		KEY_DOWN:
			step = Vector2(0.0, 1.0)
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			_stage.zoom_by(1.0)
			_stage.accept_event()
			return
		KEY_MINUS, KEY_KP_SUBTRACT:
			_stage.zoom_by(-1.0)
			_stage.accept_event()
			return
		KEY_HOME:
			_stage.reset_view()
			_stage.accept_event()
			return
		_:
			return
	_stage.accept_event()
	var marks := _marks()
	if _chosen < 0 or _chosen >= marks.size():
		# Shift and the arrows slide the manual camera, the keyboard's half of
		# dragging it with Shift down: a fortieth of the view a press.
		if _stage.is_manual() and key.shift_pressed:
			_stage.pan_by(step * _stage.size.x / 40.0)
			return
		_stage.turn_by(step.x * CarStage.KEY_TURN, step.y * CarStage.KEY_TURN)
		return
	if not _bought():
		_say_it_is_locked()
		return
	# Moved across the screen, the way the mouse would move it, and put back
	# down on whatever part of the body that is: a fortieth of the view a
	# press, fine enough to line a number up on a door and coarse enough to
	# cross the door before anybody gets bored.
	var middle := _middle_on_the_screen(marks[_chosen])
	if middle.is_empty():
		return
	_grab_copy = int(middle.copy)
	_drag_to((middle.at as Vector2) + step * _stage.size.x / 40.0)


## Where the middle of a mark is on the screen, for the copy of it being looked
## at, as `{at, copy}`. Nothing when no copy of it can be seen.
func _middle_on_the_screen(mark: Dictionary) -> Dictionary:
	var placements := CarFaces.placements(_stage.bounds(), mark)
	for copy in placements.size():
		var placement: Dictionary = placements[copy]
		if not _stage.sees(placement.point, placement.out):
			continue
		var flat := _stage.flat(placement.point)
		if not flat.is_empty():
			return {"at": flat.at, "copy": copy}
	return {}


func _let_go() -> void:
	_turning = false
	_panning = false
	_dragging = false
	if _writing and not _stroke.is_empty():
		_finish_a_stroke()


## Pick up whatever is under the cursor, if anything is. True if something was.
##
## The topmost one wins, which is the last one put on: two stickers on the same
## spot are picked apart by moving the one on top out of the way, which is what
## anybody would try first. A stripe is never under the cursor - it is worn in
## the model's texture space and has no place on the car to be pressed.
func _take_hold(where: Vector2) -> bool:
	var hit := _stage.surface_at(where)
	if hit.is_empty():
		_choose_nothing()
		return false
	var box := _stage.bounds()
	var marks := _marks()
	for i in range(marks.size() - 1, -1, -1):
		var mark: Dictionary = marks[i]
		if str(mark.get("kind", "")) == DecalArt.STRIPE:
			continue
		var placements := CarFaces.placements(box, mark)
		for copy in placements.size():
			var placement: Dictionary = placements[copy]
			if not CarFaces.holds(placement, hit.point):
				continue
			var middle := _stage.flat(placement.point)
			_chosen = i
			_grab = ((middle.at as Vector2) - where) if not middle.is_empty() \
				else Vector2.ZERO
			_grab_copy = copy
			_dragging = true
			_settle_the_sliders(mark)
			_stage.show_ring(marks, _chosen)
			said.emit("%s ON %s. DRAG IT, OR PICK A COLOUR."
				% [_what_it_is(mark), CarFaces.name_of(int(mark.face))], QUIET)
			return true
	_choose_nothing()
	return false


func _choose_nothing() -> void:
	_chosen = -1
	_grab_copy = 0
	_dragging = false
	_settle_the_sliders({})
	_stage.show_ring(_marks(), -1)


## Drag a mark to the point on the body under `where`, a point on the screen.
##
## Anywhere on the body. A mark follows the car round from a door onto the
## bonnet and down the nose, facing whichever way the body faces under it, and
## keeps the way up it was on the screen as it goes - so a number dragged
## over the edge of the bonnet does not spin round when it reaches the wing. A
## mark still saved against one of the old panels is put on the body the moment
## it is moved. A point off the car leaves it where it was.
func _drag_to(where: Vector2) -> void:
	var marks := _marks()
	if _chosen < 0 or _chosen >= marks.size():
		return
	var mark: Dictionary = marks[_chosen]
	var box := _stage.bounds()
	var placements := CarFaces.placements(box, mark)
	var was: Dictionary = placements[clampi(_grab_copy, 0, placements.size() - 1)]
	var found := _stage.surface_at(where, _stage.pixels_across(was.point,
		float(was.half)) * 0.6)
	if found.is_empty():
		return
	var aim: Vector3 = found.normal
	mark["spot"] = CarFaces.spot_of(box, found.point)
	mark["aim"] = aim
	mark["turn"] = CarFaces.turn_for(aim, was.right as Vector3)
	# Wherever it was grabbed, it is now where it was dragged to, and that is
	# the one it is kept as.
	_grab_copy = 0
	Decals.change_mark(_car_id(), _chosen, mark)


# --- the things on the page ---------------------------------------------

func _choose_player(player: int) -> void:
	_player = clampi(player, 0, 1)
	_chosen = -1
	_stop_writing()
	refresh()


## Paint the car. The car is standing right there, so it is wearing the colour
## on the frame the swatch goes down - the same choice the paint screen makes,
## and for the same reason.
##
## Nothing here asks about the customising slot. The fifty coins buy the right
## to draw on a car, not the right to paint one, and a page that refused a
## colour because a player had not bought stickers would be selling them
## something they already had.
func _choose_paint(index: int) -> void:
	if not Purse.owns_paint(index):
		said.emit("%s IS %d COINS IN THE SHOP." % [Paints.name_of(index),
			Shop.cost_of(Paints.item_for(index))], PRICE_COLOUR)
		return
	if _taken(index):
		# The one rule the paint screen exists to hold, held here as well. Two
		# cars in one colour is a split screen where the arrow pointing at your
		# rival is your own paint.
		said.emit("PLAYER %d IS IN %s. THE TWO CARS CANNOT BE ONE COLOUR."
			% [2 - _player, Paints.name_of(index)], WRONG)
		return
	GameSettings.set_car_colour(_player, Paints.colour(index))
	said.emit("%s IS %s NOW."
		% [Garage.name_of(_car_id()), Paints.name_of(index)], RIGHT)


## Whether the other player is already in this paint. Nobody is, when there is
## only one car on the road.
func _taken(index: int) -> bool:
	if _players < 2:
		return false
	return GameSettings.car_colour(1 - _player).is_equal_approx(
		Paints.colour(index))


func _choose_colour(index: int) -> void:
	_colour = clampi(index, 0, Paints.FREE - 1)
	if not _bought():
		_say_it_is_locked()
		_show_the_colours()
		return
	var marks := _marks()
	if _chosen >= 0 and _chosen < marks.size():
		var mark: Dictionary = marks[_chosen]
		mark["colour"] = _colour
		Decals.change_mark(_car_id(), _chosen, mark)
		return
	_show_the_colours()
	said.emit("THE NEXT ONE GOES ON IN %s." % Paints.name_of(_colour), QUIET)


## A stripe is on or off, and there is one of each. Pressing a stripe that is
## already on in a different colour recolours it rather than refusing it: a
## player pressing a stripe they can already see is asking for the colour they
## have just picked, not asking a question.
func _toggle_stripe(shape: int) -> void:
	if not _bought():
		_say_it_is_locked()
		_show_the_stripes()
		return
	var id := _car_id()
	var marks := _marks()
	for i in marks.size():
		var mark: Dictionary = marks[i]
		if str(mark.get("kind", "")) != DecalArt.STRIPE \
				or int(mark.get("shape", 0)) != shape:
			continue
		if int(mark.get("colour", 0)) != _colour:
			mark["colour"] = _colour
			Decals.change_mark(id, i, mark)
			said.emit("%s IS %s NOW."
				% [DecalArt.stripe_name(shape), Paints.name_of(_colour)], QUIET)
			return
		Decals.remove_mark(id, i)
		said.emit("%s IS OFF." % DecalArt.stripe_name(shape), QUIET)
		return
	var wanted := {
		"kind": DecalArt.STRIPE, "shape": shape, "colour": _colour,
		"face": CarFaces.FLANKS, "at": Vector2(0.5, 0.5), "size": 1.0,
		"turn": 0.0,
	}
	_put_on(wanted, DecalArt.stripe_name(shape))


## A sticker goes on the body in the middle of the view, the way up the car is
## being looked at.
##
## Where the player is looking rather than anywhere fixed, because a player who
## has turned the car round to see the boot lid has said where they mean as
## plainly as they could. It lands selected, so the next thing they do - drag
## it, resize it, recolour it - is about the sticker they just put on. A view
## whose middle is not on the car at all - zoomed right in past the roofline -
## gets it in the middle of the panel it is looking at instead.
func _add_sticker(shape: int) -> void:
	if not _bought():
		_say_it_is_locked()
		return
	var wanted := {
		"kind": DecalArt.STICKER, "shape": shape, "colour": _colour,
		"size": START_SIZE, "turn": 0.0,
	}
	var box := _stage.bounds()
	var middle := _stage.size * 0.5
	var near := _stage.surface_at(middle)
	if near.is_empty():
		var where := _stage.facing()
		wanted["face"] = int(where.face)
		wanted["at"] = Vector2(0.5, 0.5)
		if not _mirror:
			# A face is both doors or neither, so a sticker for one door is put
			# on the body where the door being looked at is.
			wanted = CarFaces.as_copy(box, wanted,
				CarFaces.sides(int(where.face)).find(int(where.side)))
	else:
		var found := _stage.surface_at(middle, _stage.pixels_across(near.point,
			CarFaces.span_of(box, START_SIZE) * 0.5) * 0.6)
		wanted["spot"] = CarFaces.spot_of(box, found.point)
		wanted["aim"] = found.normal
		wanted["turn"] = CarFaces.turn_for(found.normal, _stage.screen_right())
	wanted["mirror"] = _mirror
	wanted = DecalArt.tidy(wanted)
	if _put_on(wanted, DecalArt.sticker_name(shape),
			CarFaces.name_of(int(wanted.face))):
		_chosen = _marks().size() - 1
		_grab_copy = 0
		_settle_the_sliders(wanted)
		_stage.show_ring(_marks(), _chosen)


## Put one more thing on the car, or say why it did not go on.
##
## The two refusals say different things because they send a player somewhere
## different: a full car wants something taken off, and a covered car wants
## something made smaller.
func _put_on(mark: Dictionary, called: String, where := "") -> bool:
	var id := _car_id()
	if _marks().size() >= Decals.MARKS_LIMIT:
		said.emit("THIS CAR IS CARRYING %d THINGS ALREADY. TAKE ONE OFF."
			% Decals.MARKS_LIMIT, WRONG)
		return false
	if not Decals.add_mark(id, mark):
		said.emit("THAT WOULD COVER TOO MUCH OF THE CAR. MAKE SOMETHING SMALLER.",
			WRONG)
		return false
	# Which part of the car it went on, for the things that go on one. A
	# sticker is put where the car is turned to, and a player who has just
	# turned it is owed the game saying out loud which part that was.
	if where.is_empty():
		said.emit("%s ON %s." % [called, Garage.name_of(id)], RIGHT)
	else:
		said.emit("%s ON %s OF %s." % [called, where, Garage.name_of(id)], RIGHT)
	return true


func _on_size_changed(to: float) -> void:
	if _settling:
		return
	_change_the_chosen("size", to)


func _on_turn_changed(to: float) -> void:
	if _settling:
		return
	_change_the_chosen("turn", to)


## MIRROR, ticked or not: how whatever goes on next is worn, and how the mark
## in hand is worn now, the way a colour picked with a mark in hand recolours
## it. Nothing here asks about the slot, because the box on its own puts
## nothing on the car and there is no mark in hand to change without it.
func _toggle_the_mirror(on: bool) -> void:
	_mirror = on
	var marks := _marks()
	if _chosen < 0 or _chosen >= marks.size() \
			or str(marks[_chosen].get("kind", "")) == DecalArt.STRIPE:
		said.emit("MIRROR IS ON. WHAT GOES ON ONE DOOR GOES ON BOTH." if on
			else "MIRROR IS OFF. WHAT GOES ON A DOOR STAYS ON THAT DOOR.", QUIET)
		return
	# Kept on the door that was taken hold of, not the one round the far side.
	var mark := CarFaces.as_copy(_stage.bounds(), marks[_chosen],
		_grab_copy)
	mark["mirror"] = on
	_grab_copy = 0
	Decals.change_mark(_car_id(), _chosen, mark)
	said.emit(("%s IS MIRRORED." if on else "%s IS NOT MIRRORED.")
		% _what_it_is(mark), QUIET)


func _change_the_chosen(what: String, to: float) -> void:
	var marks := _marks()
	if _chosen < 0 or _chosen >= marks.size():
		return
	var mark: Dictionary = marks[_chosen]
	var was: float = float(mark.get(what, 0.0))
	mark[what] = to
	if Decals.change_mark(_car_id(), _chosen, mark):
		return
	# Only growing can be refused, and only by the cap. Put back where it was
	# rather than left showing a size the car is not wearing.
	_settling = true
	_size_slider.value = was
	_settling = false
	said.emit("THAT WOULD COVER TOO MUCH OF THE CAR.", WRONG)


func _take_it_off() -> void:
	if not _bought():
		_say_it_is_locked()
		return
	var marks := _marks()
	if _chosen < 0 or _chosen >= marks.size():
		said.emit("PRESS SOMETHING ON THE CAR FIRST.", QUIET)
		return
	var called := _what_it_is(marks[_chosen])
	if _writing and _chosen == _writing_at:
		_stop_writing()
	Decals.remove_mark(_car_id(), _chosen)
	_chosen = -1
	said.emit("%s IS OFF." % called, QUIET)


func _take_it_all_off() -> void:
	if not _bought():
		_say_it_is_locked()
		return
	var id := _car_id()
	if _marks().is_empty():
		said.emit("THERE IS NOTHING ON %s." % Garage.name_of(id), QUIET)
		return
	_stop_writing()
	Decals.clear(id)
	_chosen = -1
	said.emit("%s IS BACK TO ITS PAINT." % Garage.name_of(id), QUIET)


func _what_it_is(mark: Dictionary) -> String:
	match str(mark.get("kind", "")):
		DecalArt.STRIPE:
			return DecalArt.stripe_name(int(mark.get("shape", 0)))
		DecalArt.SCRAWL:
			return "YOUR OWN WRITING"
	return DecalArt.sticker_name(int(mark.get("shape", 0)))


# --- a word in the player's own hand ------------------------------------

## The pen, which is drawn with on the car itself.
##
## It used to be a box that opened over the garage: a square of graph paper to
## write in, and then the word was put on the car and dragged to where it was
## wanted. Two steps and a guess in between - a word written big in a square
## box is a word that comes out somewhere else entirely on a door. Now the
## paintwork is the paper. A stroke is on the car the moment it is finished,
## in the colour it will stay, at the size and the angle it was drawn.
##
## The pen draws on the body, not on a panel of the box round it, so a word can
## go on a bonnet, which slopes and is neither the top of the car nor its nose.
## A word is still one mark, laid flat against the way the body faces under the
## whole of it and thrown back onto the car from there - so a word written
## round a sharp corner, from the bonnet down onto the nose, comes out
## stretched on the side it was not facing. Write a word on each.
func _press_the_pen() -> void:
	if not _bought():
		_say_it_is_locked()
		return
	if _writing:
		var written := _writing_at >= 0
		_stop_writing()
		said.emit("THE PEN IS DOWN." if written
			else "THE PEN IS DOWN. NOTHING WAS WRITTEN.", QUIET)
		_show_the_draw_buttons()
		return
	_writing = true
	_writing_at = -1
	_written = []
	_written_aims = []
	_stroke = PackedVector3Array()
	_pen_where = {}
	_choose_nothing()
	_show_the_draw_buttons()
	said.emit("DRAW ON THE CAR. EVERY STROKE GOES ON AS YOU FINISH IT · "
		+ "THE RIGHT BUTTON STILL TURNS IT", QUIET)


## Put the pen away, leaving whatever has been written on the car. Called for
## Escape, for a player pressing DONE, and for anything that changes which car
## the page is about.
func _stop_writing() -> void:
	_writing = false
	_writing_at = -1
	_written = []
	_written_aims = []
	_stroke = PackedVector3Array()
	_pen_where = {}
	if _stage != null:
		_stage.show_pen([], Color.WHITE)


func _start_a_stroke(where: Vector2) -> void:
	if _pen_where.is_empty():
		# The way the body faces over a small patch under the pen rather than
		# at the one triangle it lands on, since the whole word is laid out
		# against it until more of the word is down.
		var hit := _stage.surface_at(where, 8.0)
		if hit.is_empty():
			# A press on the empty air beside the car turns it, the way it
			# does with the pen away. It cannot be the start of a word - a word
			# starts on the car - so there is nothing else for it to be.
			_turning = true
			return
		_pen_where = {"point": hit.point, "normal": hit.normal,
			"right": _stage.screen_right()}
		_stroke = PackedVector3Array([hit.point])
		_stroke_aim = hit.normal
		_show_the_pen()
		return
	var found := _pen_at(where)
	if found.is_empty():
		return
	_stroke = PackedVector3Array([found.point])
	_stroke_aim = found.normal
	_show_the_pen()


func _draw_to(where: Vector2) -> void:
	if _pen_where.is_empty():
		return
	var found := _pen_at(where)
	if found.is_empty():
		return
	_stroke.append(found.point)
	_stroke_aim += found.normal as Vector3
	_show_the_pen()


## Where the pen is, once a word has started: on the body under it if that part
## of the body is the part the word is on, and carrying on in the air past the
## edge of it if not. See `CarStage.surface_or_plane`. The part the word is on
## is anything facing roughly its way within `PEN_REACH` of the car's length of
## where it started, which a door, a bonnet and the curve of a wing all are.
func _pen_at(where: Vector2) -> Dictionary:
	return _stage.surface_or_plane(where, _pen_where.point, _pen_where.normal,
		CarFaces.span_of(_stage.bounds(), PEN_REACH))


## A stroke is finished, so it goes on the car.
##
## The whole word is put on again rather than the stroke being added to what is
## there, because a word is one mark: its box is drawn round everything in it,
## so every stroke of it moves and resizes when a new one is added. That is
## also the only way the cap can refuse a stroke, which it does by refusing the
## word it would be part of - and then the stroke is dropped and the word is
## left exactly as it was before it.
func _finish_a_stroke() -> void:
	var drawn := _stroke
	_stroke = PackedVector3Array()
	_stage.show_pen([], Color.WHITE)
	if drawn.size() < 1:
		return
	_written.append(drawn)
	_written_aims.append(_stroke_aim)
	if _keep_the_writing():
		return
	_written.pop_back()
	_written_aims.pop_back()
	# A first stroke can be refused because the car is already carrying eight
	# things, and that has been said already by whoever counted them. Anything
	# else that refuses a stroke is the cap.
	if _writing_at < 0 and _marks().size() >= Decals.MARKS_LIMIT:
		return
	said.emit("THAT WOULD COVER TOO MUCH OF THE CAR. "
		+ "THE STROKE IS NOT ON IT.", WRONG)


## Take the last stroke back off. A player writing with a mouse will make a
## mess of one, and a pen whose only way back is starting again is a pen
## nobody finishes a word with.
func _undo_a_stroke() -> void:
	if not _bought():
		_say_it_is_locked()
		return
	if not _writing or _written.is_empty():
		said.emit("THERE IS NOTHING TO TAKE BACK.", QUIET)
		return
	_written.pop_back()
	_written_aims.pop_back()
	if not _written.is_empty():
		_keep_the_writing()
		said.emit("THE LAST STROKE IS OFF.", QUIET)
		_show_the_draw_buttons()
		return
	# The last stroke of a word is the word. Taking it off leaves a mark with
	# nothing in it, which is a slot out of the eight spent on a decal that
	# draws nothing.
	if _writing_at >= 0:
		Decals.remove_mark(_car_id(), _writing_at)
	_writing_at = -1
	_pen_where = {}
	_choose_nothing()
	said.emit("THE WORD IS OFF. START IT AGAIN WHEREVER YOU LIKE.", QUIET)
	_show_the_draw_buttons()


## Put what has been written so far on the car, as one mark. False if the cap
## refused it.
func _keep_the_writing() -> bool:
	var word := _word_from(_written)
	if word.is_empty():
		return false
	var id := _car_id()
	if _writing_at >= 0 and _writing_at < _marks().size():
		if not Decals.change_mark(id, _writing_at, word):
			return false
	else:
		if _marks().size() >= Decals.MARKS_LIMIT:
			said.emit("THIS CAR IS CARRYING %d THINGS ALREADY. TAKE ONE OFF."
				% Decals.MARKS_LIMIT, WRONG)
			return false
		if not Decals.add_mark(id, word):
			return false
		_writing_at = _marks().size() - 1
	_chosen = _writing_at
	_settle_the_sliders(_marks()[_writing_at])
	_stage.show_ring(_marks(), _chosen)
	return true


## Strokes drawn on the car, as a mark: a square box drawn round the whole
## word, and the strokes as fractions of that box.
##
## The word is laid flat against the way the body faces under the whole of it
## - every point the pen touched, added up - and the box is drawn in metres on
## that plane, along the screen's right as it was when the word was started. So
## a word comes out the way up it was written, on a bonnet as on a door, and as
## wide as it was written: a box worked out in fractions of something that is
## not square would come out stretched. Square because a mark is square: it is
## thrown at the car by a decal, and the decal's box is a `size` across in
## both directions.
##
## The box is grown by the width of the nib as well, since the pen draws about
## the line it was dragged along and half of it would otherwise be shaved off
## at the edges. The nib is chosen in metres on the car (`NIBS`) and kept as a
## share of that box, which is the only width a decal's picture knows.
func _word_from(strokes: Array) -> Dictionary:
	if strokes.is_empty() or _pen_where.is_empty():
		return {}
	var box := _stage.bounds()
	var aim := Vector3.ZERO
	for each in _written_aims:
		aim += each
	aim = aim.normalized() if aim.length_squared() > 0.000001 \
		else (_pen_where.normal as Vector3)
	var right: Vector3 = _pen_where.right
	right = (right - aim * right.dot(aim))
	right = right.normalized() if right.length_squared() > 0.000001 \
		else CarFaces.reference_right(aim)
	var down := right.cross(aim)
	var origin: Vector3 = _pen_where.point

	# Every point, as how far right and how far down the picture it is, in
	# metres, and how far out of the body - for sitting the middle of the
	# decal at the depth the word was actually written at.
	var flat: Array = []
	var least := Vector2(INF, INF)
	var most := Vector2(-INF, -INF)
	var outward := 0.0
	var count := 0
	for stroke in strokes:
		var line := PackedVector2Array()
		for at: Vector3 in stroke:
			var gap := at - origin
			var point := Vector2(gap.dot(right), gap.dot(down))
			least = Vector2(minf(least.x, point.x), minf(least.y, point.y))
			most = Vector2(maxf(most.x, point.x), maxf(most.y, point.y))
			outward += gap.dot(aim)
			count += 1
			line.append(point)
		flat.append(line)

	var middle := (least + most) * 0.5
	var widest := maxf(most.x - least.x, most.y - least.y)
	var nib := NIBS[_nib] * maxf(box.size.z, 1.0)
	var span := maxf(widest + nib, CarFaces.span_of(box, LEAST_WORD))
	var kept := []
	for line: PackedVector2Array in flat:
		var points := PackedVector2Array()
		for point in line:
			points.append((point - middle) / span + Vector2(0.5, 0.5))
		kept.append(points)
	var centre := origin + right * middle.x + down * middle.y \
		+ aim * (outward / maxf(float(count), 1.0))
	# Thinned, because the pen is read every time the mouse moves and a word
	# kept at that is too long to save as a livery. See `DecalArt.thinned`.
	return DecalArt.thinned_word(DecalArt.tidy({
		"kind": DecalArt.SCRAWL, "shape": 0, "colour": _colour,
		"spot": CarFaces.spot_of(box, centre), "aim": aim,
		"size": clampf(span / maxf(box.size.z, 1.0), 0.08, 1.0),
		# Drawn where it was drawn. A word written at an angle is already at
		# that angle, because the strokes are.
		"turn": CarFaces.turn_for(aim, right),
		"strokes": kept,
		"pen": nib / span,
		"mirror": _mirror,
	}))


## The stroke in the player's hand, on the car under it.
func _show_the_pen() -> void:
	_stage.show_pen([_stroke], Paints.colour(_colour), NIBS[_nib])


## Pick how thick the pen draws.
##
## A word is one mark with one pen, the way it has one colour, so a word on the
## go is drawn again at the new width, every stroke of it - what is on the car
## is always what the pen would draw. Refused, and left as it was, if the
## fatter line would take the car over the cap.
func _choose_nib(nib: int) -> void:
	var was := _nib
	_nib = clampi(nib, 0, NIBS.size() - 1)
	if _writing and not _written.is_empty() and not _keep_the_writing():
		_nib = was
		said.emit("THAT WOULD COVER TOO MUCH OF THE CAR. "
			+ "THE PEN IS AS IT WAS.", WRONG)
	else:
		said.emit("A %s PEN." % NIB_NAMES[_nib], QUIET)
	_show_the_draw_buttons()


## A pen's button, as the line it draws rather than a name for it: "thin"
## means nothing until it is beside the other three. Drawn straight onto the
## button, not set as its icon, because a button this narrow has no room left
## for an icon inside the theme's margins.
func _draw_a_nib(button: Button, nib: int) -> void:
	var thick := maxf(NIBS[nib] / NIBS[NIBS.size() - 1] * 11.0, 2.0)
	var middle := button.size * 0.5
	var half := minf(button.size.x * 0.28, 12.0)
	button.draw_line(middle - Vector2(half, 0.0), middle + Vector2(half, 0.0),
		Color(0.94, 0.95, 1.0), thick, true)


func _show_the_draw_buttons() -> void:
	_draw_button.text = "DONE" if _writing else "DRAW ON IT"
	_undo_button.visible = _writing
	for nib in _nib_buttons.size():
		_nib_buttons[nib].visible = _writing
		_nib_buttons[nib].set_pressed_no_signal(nib == _nib)


# --- keeping a design ----------------------------------------------------

## Ask what a design should be called, and keep it.
##
## The name is asked for the same way the garage asks what a car being shared
## should be called, and on the same panel shape, because it is the same
## question: this is about to be a thing in a row with a name under it, and
## possibly a thing other people see.
func _build_the_naming_panel(host: Control) -> void:
	_naming = Control.new()
	_naming.set_anchors_preset(Control.PRESET_FULL_RECT)
	_naming.hide()
	host.add_child(_naming)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.5)
	_naming.add_child(dim)

	var page := CenterContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	_naming.add_child(page)
	var panel := PanelContainer.new()
	page.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	var heading := Label.new()
	heading.text = "WHAT IS THIS LIVERY CALLED?"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 38)
	box.add_child(heading)
	var subline := Label.new()
	subline.text = ("it goes in the garage beside the cars, and keeps this name "
		+ "if you ever share it")
	subline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subline.add_theme_font_size_override("font_size", 17)
	subline.add_theme_color_override("font_color", QUIET)
	box.add_child(subline)

	_name_edit = LineEdit.new()
	_name_edit.max_length = Livery.NAME_LIMIT
	_name_edit.custom_minimum_size = Vector2(460.0, 52.0)
	_name_edit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.add_theme_font_size_override("font_size", 24)
	_name_edit.text_changed.connect(_on_name_changed)
	_name_edit.text_submitted.connect(func(_text: String) -> void: _keep_it())
	box.add_child(_name_edit)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	_keep_it_button = Button.new()
	_keep_it_button.text = "KEEP IT"
	_keep_it_button.pressed.connect(_keep_it)
	row.add_child(_keep_it_button)
	var cancel := Button.new()
	cancel.text = "CANCEL"
	cancel.pressed.connect(_close_the_naming)
	row.add_child(cancel)


## A design already saved is not asked about again: it is already a livery, and
## asking what to call something that has a name is asking a question with a
## right answer the game already knows.
func _ask_what_to_call_it() -> void:
	if not _bought():
		_say_it_is_locked()
		return
	var marks := _marks()
	if marks.is_empty():
		said.emit("THERE IS NOTHING ON THIS CAR TO SAVE.", QUIET)
		return
	var already := Liveries.which(marks)
	if not already.is_empty():
		said.emit("THIS IS ALREADY SAVED, AS %s." % Liveries.name_of(already), QUIET)
		return
	# Opened on what the car is called, because a first livery is very often
	# "the one I made for this car" and that is one keystroke away from being
	# right rather than a blank box.
	_name_edit.text = Garage.name_of(_car_id())
	_on_name_changed(_name_edit.text)
	_naming.show()
	_name_edit.grab_focus()
	_name_edit.select_all()


func _on_name_changed(text: String) -> void:
	_keep_it_button.disabled = Liveries.clean_name(text).is_empty()


func _keep_it() -> void:
	if _keep_it_button.disabled:
		return
	var wanted := _name_edit.text
	_close_the_naming()
	var kept := Liveries.keep(_marks(), wanted)
	if not kept.ok:
		said.emit(str(kept.error).to_upper(), WRONG)
		return
	said.emit("SAVED AS %s. IT IS IN THE GARAGE WITH THE CARS." % kept.name, RIGHT)
	refresh()


func _close_the_naming() -> void:
	_naming.hide()
	_keep_button.grab_focus()


# --- saying what is on ---------------------------------------------------

## Dress the whole page for the car it is about. Called for anything that
## changes what is on the car, wherever it came from - a button here, a coin
## banked by the race behind the title, a car picked on the other tab.
func refresh() -> void:
	var id := _car_id()
	var marks := _marks()
	if _chosen >= marks.size():
		_chosen = -1
	for player in _whose_buttons.size():
		_whose_buttons[player].set_pressed_no_signal(player == _player)
	_stage.show_car(id, GameSettings.car_colour(_player), marks)
	_stage.show_ring(marks, _chosen)
	_show_the_stripes()
	_show_the_paint()
	_show_the_colours()
	_show_the_sliders(marks)
	_show_the_draw_buttons()
	_show_the_keep_button(marks)
	_show_the_cover(id, marks)


func _show_the_stripes() -> void:
	var worn := {}
	for mark: Dictionary in _marks():
		if str(mark.get("kind", "")) == DecalArt.STRIPE:
			worn[int(mark.get("shape", 0))] = int(mark.get("colour", 0))
	for shape in _stripe_buttons.size():
		var button := _stripe_buttons[shape]
		button.set_pressed_no_signal(worn.has(shape))
		var face := Paints.legible(Paints.colour(worn[shape])) if worn.has(shape) \
			else Color(0.898, 0.929, 1.0)
		button.add_theme_color_override("font_pressed_color", face)
		button.add_theme_color_override("font_hover_pressed_color", face)


## The paint row, dressed for what each swatch currently is: the colour this
## car is wearing, one it could be, one the other player has taken, or one that
## has not been bought.
##
## Taken beats locked when a swatch is both, the way it does on the paint
## screen: sending a player to buy a colour their rival is already sitting in
## would be sending them to spend coins on something that still would not be
## pickable afterwards.
func _show_the_paint() -> void:
	var mine := GameSettings.car_colour(_player)
	for index in _paints.size():
		var swatch := _paints[index]
		var colour := Paints.colour(index)
		var locked := not Purse.owns_paint(index)
		var taken := _taken(index)
		# The price written across a locked swatch and nothing across any
		# other, so the row is paint with a couple of numbers on it rather than
		# a row of numbers with paint behind them.
		swatch.text = "" if not locked else str(
			Shop.cost_of(Paints.item_for(index)))
		swatch.tooltip_text = _what_paint_it_is(index, taken, locked)
		var shown := colour
		if taken or locked:
			# Faded rather than crossed out. It is still legibly that colour,
			# so a player can see where their rival is sitting and what a paint
			# they have not bought would actually look like.
			shown = colour.lerp(Color(0.09, 0.11, 0.16), 0.62)
		var chosen := colour.is_equal_approx(mine)
		for state in ["normal", "hover", "pressed", "focus"]:
			var lift := 0.16 if state == "hover" or state == "focus" else 0.0
			if state == "pressed":
				lift = -0.12
			swatch.add_theme_stylebox_override(state,
				_face(shown, chosen and not (taken or locked), lift))


func _what_paint_it_is(index: int, taken: bool, locked: bool) -> String:
	if taken:
		return "%s - the other player is in it" % Paints.name_of(index)
	if locked:
		return "%s - %d coins in the shop" % [Paints.name_of(index),
			Shop.cost_of(Paints.item_for(index))]
	return "%s - the car's own paint" % Paints.name_of(index)


## The swatches, dressed the way the paint screen dresses its own - the colour
## is the control, so every state is overridden or a swatch would go back to
## the theme's grey the moment it was pointed at.
func _show_the_colours() -> void:
	for index in _swatches.size():
		var swatch := _swatches[index]
		var colour := Paints.colour(index)
		var chosen := index == _colour
		for state in ["normal", "hover", "pressed", "focus"]:
			var lift := 0.16 if state == "hover" or state == "focus" else 0.0
			if state == "pressed":
				lift = -0.12
			swatch.add_theme_stylebox_override(state, _face(colour, chosen, lift))


func _face(colour: Color, chosen: bool, lift: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = colour.lightened(lift) if lift > 0.0 else colour.darkened(-lift)
	box.set_corner_radius_all(4)
	box.border_color = (Color(0.98, 0.99, 1.0) if chosen
		else Color(0.898, 0.929, 1.0, 0.22))
	box.set_border_width_all(3 if chosen else 1)
	return box


func _show_the_sliders(marks: Array) -> void:
	if _chosen >= 0 and _chosen < marks.size():
		_settle_the_sliders(marks[_chosen])
	else:
		_settle_the_sliders({})


## A slider with nothing selected is still readable and still takes the
## keyboard; it simply has nothing to move. Its own value is left where it was,
## because the next thing selected sets it anyway.
func _settle_the_sliders(mark: Dictionary) -> void:
	_settling = true
	if not mark.is_empty() and str(mark.get("kind", "")) != DecalArt.STRIPE:
		_size_slider.value = float(mark.get("size", START_SIZE))
		_turn_slider.value = float(mark.get("turn", 0.0))
		# The box says what the mark in hand is, the way the sliders do, and
		# the next thing put on goes on the way the last one touched did.
		_mirror = CarFaces.mirrored(mark)
		_mirror_box.set_pressed_no_signal(_mirror)
	_settling = false


## How much of the car is covered, against how much it may be.
##
## On the page rather than only in a refusal, because a player who has been
## told "that would cover too much" needs to know how much is too much before
## they can do anything about it.
func _show_the_cover(id: String, marks: Array) -> void:
	if not _bought():
		_cover.text = ("CUSTOMISING IS %d COINS IN THE SHOP · until it is bought, "
			+ "nothing here goes on a car") % Shop.SLOT_COST
		_cover.add_theme_color_override("font_color", PRICE_COLOUR)
		return
	_cover.add_theme_color_override("font_color", QUIET)
	_cover.text = "%s · %d things on it, covering %d%% of the %d%% a car may wear" % [
		Garage.name_of(id), marks.size(),
		roundi(DecalArt.cover_of_all(marks) * 100.0),
		roundi(Decals.COVER_CAP * 100.0),
	]


## The button says which of the two things it is for: keeping a design that is
## not kept, or the fact that this one already is. Pressable either way, for
## the reason everything else on this page is.
func _show_the_keep_button(marks: Array) -> void:
	var already := Liveries.which(marks)
	if already.is_empty():
		_keep_button.text = "SAVE AS A LIVERY"
		_keep_button.tooltip_text = ("Keep what is on this car as a livery, to "
			+ "put on another car or share.")
		return
	_keep_button.text = "SAVED AS %s" % Liveries.name_of(already)
	_keep_button.tooltip_text = ("This design is already a livery. It is in the "
		+ "garage with the cars.")


func _on_liveries_changed() -> void:
	if is_visible_in_tree():
		_show_the_keep_button(_marks())


func _on_decals_changed(id: String) -> void:
	if is_visible_in_tree() and id == _car_id():
		refresh()


func _on_purse_changed(_coins: int) -> void:
	if is_visible_in_tree():
		refresh()


func _on_settings_changed() -> void:
	if is_visible_in_tree():
		refresh()
