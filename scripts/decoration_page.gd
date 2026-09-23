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
## Everything here is applied as it is chosen, never on the way out. The car is
## turning on the left of the page wearing whatever has just been pressed,
## which is the same choice the paint screen made for the same reason: a
## decoration confirmed two presses after it was picked is a guess.
##
## The three kinds are not offered the same way, because they are not the same
## kind of choice. **Stripes** are toggles - there are four of them, each is on
## or off, and they are worn in the model's own texture space where there is
## nothing to place. **Stickers** and **hand-written words** are put on the
## flat side of the car and dragged about, because they are placed, and
## because asking somebody to put a sticker on a turning model with a mouse is
## asking them to do a small precision task on a moving target.
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

## How big the car turning on the left is, and the flat side of it beside.
const STAGE_SIZE := Vector2(300.0, 248.0)
const BOARD_SIZE := Vector2(430.0, 248.0)
const TOOLS_WIDTH := 384.0
## How big the box a word is drawn in is. Square, and big enough that a word
## written with a mouse is a word rather than a scribble.
const DRAW_BOX := Vector2(420.0, 300.0)

## How big a sticker starts out, as a fraction of the car's length. A quarter:
## plainly a sticker on a door rather than a wrap, and big enough to see what
## it is without being dragged bigger first.
const START_SIZE := 0.26

var _players := 1
## Which player's car is being drawn on. Both get to decorate their own.
var _player := 0
## The colour the next thing goes on in, and the one a swatch puts on whatever
## is selected.
var _colour := 0
## Which mark on the board is selected, as a slot in the car's own list, or -1.
var _chosen := -1
## True while the page is putting its own values into its own sliders, so a
## slider being set does not read as a player moving it.
var _settling := false
## Where a mark was grabbed, relative to its middle, so a sticker does not jump
## under the cursor when it is picked up by its edge.
var _grab := Vector2.ZERO
var _dragging := false

var _whose: HBoxContainer
var _whose_buttons: Array[Button] = []
var _stage: CarStage
var _board: Control
var _stripe_buttons: Array[Button] = []
var _swatches: Array[Button] = []
var _draw_button: Button
var _keep_button: Button
var _size_slider: HSlider
var _turn_slider: HSlider
var _off_button: Button
var _all_off_button: Button
var _cover: Label

## The panel that asks what a design should be called, which lies over the
## whole garage the way the drawing box does.
var _naming: Control
var _name_edit: LineEdit
var _keep_it_button: Button

## The panel a word is drawn in, which lies over the whole garage.
var _drawing: Control
var _pad: Control
var _strokes: Array = []
var _stroke: PackedVector2Array = PackedVector2Array()
var _undo_button: Button
var _put_it_on: Button


## Build the page, and hang the drawing panel off the screen that owns the tab.
##
## The panel has to lie over the whole garage rather than inside the tab, the
## way the garage's own naming panel and its list of shared cars do, so it is
## given to the host rather than added here.
func setup(host: Control) -> void:
	add_theme_constant_override("separation", 8)
	_build_the_players()
	_build_the_body()
	_build_the_cover_line()
	_build_the_drawing_panel(host)
	_build_the_naming_panel(host)
	Decals.changed.connect(_on_decals_changed)
	Liveries.changed.connect(_on_liveries_changed)
	Purse.changed.connect(_on_purse_changed)


## Show the tab, with a row of players if there are two.
func opened(players: int) -> void:
	_players = clampi(players, 1, 2)
	_whose.visible = _players > 1
	_player = clampi(_player, 0, _players - 1)
	_chosen = -1
	_drawing.hide()
	_naming.hide()
	refresh()


## Put the keyboard somewhere on the page. The first stripe, because it is the
## first thing on it that does anything, and because both players are on one
## keyboard and neither has been asked to find the mouse.
func first_focus() -> void:
	if not _stripe_buttons.is_empty():
		_stripe_buttons[0].grab_focus()


## Whether the page took the Escape itself. The drawing panel lies over the
## garage, so it is backed out of before the garage is.
func backed_out() -> bool:
	if _naming.visible:
		_close_the_naming()
		return true
	if not _drawing.visible:
		return false
	_close_the_drawing()
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

	_stage = CarStage.new()
	_stage.custom_minimum_size = STAGE_SIZE
	body.add_child(_stage)

	_board = Control.new()
	_board.custom_minimum_size = BOARD_SIZE
	_board.mouse_filter = Control.MOUSE_FILTER_STOP
	_board.tooltip_text = ("the side of the car - drag a sticker or a word "
		+ "about, and the car beside follows")
	_board.draw.connect(_draw_the_board)
	_board.gui_input.connect(_board_input)
	body.add_child(_board)

	body.add_child(_build_the_tools())


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

	tools.add_child(_small("STICKERS"))
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
	_draw_button = Button.new()
	_draw_button.text = "DRAW ONE"
	_draw_button.add_theme_font_size_override("font_size", 18)
	_draw_button.pressed.connect(_open_the_drawing)
	tools.add_child(_draw_button)

	tools.add_child(_small("COLOUR"))
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


# --- the flat side of the car -------------------------------------------

## The board: the flat side of the car, with whatever is on it.
##
## The silhouette and the marks are drawn by `DecalArt.draw_side`, which is
## also what puts a saved livery on its tile in the garage - so the design a
## player is dragging about and the picture of it they pick out of a row later
## are the same picture, drawn once.
##
## What is added here is only what belongs to *editing* one: the bed it sits
## on, which end is the front, and a ring round whichever mark is selected.
func _draw_the_board() -> void:
	var span := _board.size
	var bed := StyleBoxFlat.new()
	bed.bg_color = CarPortrait.BACKGROUND
	bed.set_corner_radius_all(8)
	bed.border_color = Color(0.898, 0.929, 1.0, 0.22)
	bed.set_border_width_all(2)
	bed.draw(_board.get_canvas_item(), Rect2(Vector2.ZERO, span))

	DecalArt.draw_side(_board, span, GameSettings.car_colour(_player), _marks())

	# Which end is which. The silhouette alone is symmetrical enough at a
	# glance that a player would otherwise put a number on the boot.
	_board.draw_string(ThemeDB.fallback_font, Vector2(10.0, span.y - 10.0),
		"FRONT", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, QUIET)

	var marks := _marks()
	if _chosen < 0 or _chosen >= marks.size():
		return
	var mark: Dictionary = marks[_chosen]
	if str(mark.get("kind", "")) == DecalArt.STRIPE:
		return
	# An outline rather than a tint: the mark is already a colour, and a colour
	# laid over a colour says nothing about which one is selected.
	var wide := _mark_span(mark, span)
	_board.draw_set_transform((mark.get("at", Vector2(0.5, 0.5)) as Vector2) * span,
		float(mark.get("turn", 0.0)), Vector2.ONE)
	_board.draw_rect(Rect2(-Vector2(wide, wide) * 0.5, Vector2(wide, wide)),
		Color(0.98, 0.99, 1.0), false, 2.0)
	_board.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _mark_span(mark: Dictionary, span: Vector2) -> float:
	return DecalArt.mark_span(mark, span)


## Pick a mark up, put it down, or drag it about.
##
## The topmost one wins, which is the last one put on: two stickers on the same
## spot are picked apart by moving the one on top out of the way, which is what
## anybody would try first.
func _board_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if not button.pressed:
			_dragging = false
			return
		if not _bought():
			_say_it_is_locked()
			return
		_grab_at(button.position)
		return
	var moved := event as InputEventMouseMotion
	if moved != null and _dragging:
		_drag_to(moved.position)


func _grab_at(where: Vector2) -> void:
	var marks := _marks()
	var span := _board.size
	for i in range(marks.size() - 1, -1, -1):
		var mark: Dictionary = marks[i]
		if str(mark.get("kind", "")) == DecalArt.STRIPE:
			continue
		var at: Vector2 = mark.get("at", Vector2(0.5, 0.5)) * span
		var wide := _mark_span(mark, span)
		# Measured in the mark's own space, so a turned sticker is grabbed by
		# where it looks like it is rather than by an upright box round it.
		var inside := (where - at).rotated(-float(mark.get("turn", 0.0)))
		if absf(inside.x) <= wide * 0.5 and absf(inside.y) <= wide * 0.5:
			_chosen = i
			_grab = where - at
			_dragging = true
			_settle_the_sliders(mark)
			_board.queue_redraw()
			said.emit("%s. DRAG IT, OR PICK A COLOUR." % _what_it_is(mark), QUIET)
			return
	_chosen = -1
	_dragging = false
	_settle_the_sliders({})
	_board.queue_redraw()


func _drag_to(where: Vector2) -> void:
	var marks := _marks()
	if _chosen < 0 or _chosen >= marks.size():
		return
	var span := _board.size
	var at := (where - _grab) / span
	var mark: Dictionary = marks[_chosen]
	mark["at"] = Vector2(clampf(at.x, 0.0, 1.0), clampf(at.y, 0.0, 1.0))
	Decals.change_mark(_car_id(), _chosen, mark)


# --- the things on the page ---------------------------------------------

func _choose_player(player: int) -> void:
	_player = clampi(player, 0, 1)
	_chosen = -1
	refresh()


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
		"at": Vector2(0.5, 0.5), "size": 1.0, "turn": 0.0,
	}
	_put_on(wanted, DecalArt.stripe_name(shape))


func _add_sticker(shape: int) -> void:
	if not _bought():
		_say_it_is_locked()
		return
	var wanted := {
		"kind": DecalArt.STICKER, "shape": shape, "colour": _colour,
		"at": Vector2(0.5, 0.42), "size": START_SIZE, "turn": 0.0,
	}
	if _put_on(wanted, DecalArt.sticker_name(shape)):
		# Selected as it lands, so the sliders and the next colour pressed are
		# about the thing that was just put on.
		_chosen = _marks().size() - 1
		_settle_the_sliders(wanted)
		_board.queue_redraw()


## Put one more thing on the car, or say why it did not go on.
##
## The two refusals say different things because they send a player somewhere
## different: a full car wants something taken off, and a covered car wants
## something made smaller.
func _put_on(mark: Dictionary, called: String) -> bool:
	var id := _car_id()
	if _marks().size() >= Decals.MARKS_LIMIT:
		said.emit("THIS CAR IS CARRYING %d THINGS ALREADY. TAKE ONE OFF."
			% Decals.MARKS_LIMIT, WRONG)
		return false
	if not Decals.add_mark(id, mark):
		said.emit("THAT WOULD COVER TOO MUCH OF THE CAR. MAKE SOMETHING SMALLER.",
			WRONG)
		return false
	said.emit("%s ON %s." % [called, Garage.name_of(id)], RIGHT)
	return true


func _on_size_changed(to: float) -> void:
	if _settling:
		return
	_change_the_chosen("size", to)


func _on_turn_changed(to: float) -> void:
	if _settling:
		return
	_change_the_chosen("turn", to)


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
		said.emit("PRESS A STICKER ON THE SIDE OF THE CAR FIRST.", QUIET)
		return
	var called := _what_it_is(marks[_chosen])
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

## A box to draw in, over the garage.
##
## Drawn rather than typed, on purpose: a name set in the game's font is the
## game's writing, and a scrawl is the player's. Undo is not optional - a
## player drawing with a mouse will make a mess of the first stroke, and a box
## whose only way back is CLEAR is a box that gets cleared every time.
func _build_the_drawing_panel(host: Control) -> void:
	_drawing = Control.new()
	_drawing.set_anchors_preset(Control.PRESET_FULL_RECT)
	_drawing.hide()
	host.add_child(_drawing)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.5)
	_drawing.add_child(dim)

	var page := CenterContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	_drawing.add_child(page)
	var panel := PanelContainer.new()
	page.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 34)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var heading := Label.new()
	heading.text = "WRITE IT"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 38)
	box.add_child(heading)
	var subline := Label.new()
	subline.text = "hold the button down and draw · it goes on the car as you drew it"
	subline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subline.add_theme_font_size_override("font_size", 17)
	subline.add_theme_color_override("font_color", QUIET)
	box.add_child(subline)

	_pad = Control.new()
	_pad.custom_minimum_size = DRAW_BOX
	_pad.mouse_filter = Control.MOUSE_FILTER_STOP
	_pad.draw.connect(_draw_the_pad)
	_pad.gui_input.connect(_pad_input)
	box.add_child(_pad)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	_undo_button = Button.new()
	_undo_button.text = "UNDO"
	_undo_button.pressed.connect(_undo_a_stroke)
	row.add_child(_undo_button)
	var clear := Button.new()
	clear.text = "CLEAR"
	clear.pressed.connect(_clear_the_pad)
	row.add_child(clear)
	_put_it_on = Button.new()
	_put_it_on.text = "PUT IT ON"
	_put_it_on.pressed.connect(_keep_the_writing)
	row.add_child(_put_it_on)
	var cancel := Button.new()
	cancel.text = "CANCEL"
	cancel.pressed.connect(_close_the_drawing)
	row.add_child(cancel)


func _open_the_drawing() -> void:
	if not _bought():
		_say_it_is_locked()
		return
	_strokes = []
	_stroke = PackedVector2Array()
	_drawing.show()
	_pad.queue_redraw()
	_show_the_drawing_buttons()
	_undo_button.grab_focus()


func _close_the_drawing() -> void:
	_drawing.hide()
	_draw_button.grab_focus()


func _draw_the_pad() -> void:
	var span := _pad.size
	var bed := StyleBoxFlat.new()
	bed.bg_color = Color(0.08, 0.09, 0.13)
	bed.set_corner_radius_all(8)
	bed.border_color = Color(0.898, 0.929, 1.0, 0.25)
	bed.set_border_width_all(2)
	bed.draw(_pad.get_canvas_item(), Rect2(Vector2.ZERO, span))

	var ink := Paints.colour(_colour)
	var thick := DecalArt.PEN * span.x
	for stroke in _all_strokes():
		var points: PackedVector2Array = stroke
		if points.size() == 1:
			_pad.draw_circle(points[0] * span, thick * 0.5, ink)
			continue
		var line := PackedVector2Array()
		for point in points:
			line.append(point * span)
		_pad.draw_polyline(line, ink, thick, true)


## Every stroke there is, finished and in progress. The one being drawn has to
## be on the page while it is being drawn, and it is not one of the kept ones
## until the button comes up.
func _all_strokes() -> Array:
	var all := _strokes.duplicate()
	if not _stroke.is_empty():
		all.append(_stroke)
	return all


func _pad_input(event: InputEvent) -> void:
	var span := _pad.size
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_stroke = PackedVector2Array([button.position / span])
		elif not _stroke.is_empty():
			_strokes.append(_stroke)
			_stroke = PackedVector2Array()
		_pad.queue_redraw()
		_show_the_drawing_buttons()
		return
	var moved := event as InputEventMouseMotion
	if moved == null or _stroke.is_empty():
		return
	if (moved.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
		return
	var at := moved.position / span
	_stroke.append(Vector2(clampf(at.x, 0.0, 1.0), clampf(at.y, 0.0, 1.0)))
	_pad.queue_redraw()


func _undo_a_stroke() -> void:
	if not _stroke.is_empty():
		_stroke = PackedVector2Array()
	elif not _strokes.is_empty():
		_strokes.pop_back()
	_pad.queue_redraw()
	_show_the_drawing_buttons()


func _clear_the_pad() -> void:
	_strokes = []
	_stroke = PackedVector2Array()
	_pad.queue_redraw()
	_show_the_drawing_buttons()


func _keep_the_writing() -> void:
	var strokes := _all_strokes()
	if strokes.is_empty():
		said.emit("THERE IS NOTHING IN THE BOX YET.", QUIET)
		return
	var wanted := {
		"kind": DecalArt.SCRAWL, "shape": 0, "colour": _colour,
		"at": Vector2(0.5, 0.42), "size": 0.34, "turn": 0.0,
		"strokes": strokes,
	}
	if not _put_on(wanted, "YOUR OWN WRITING"):
		return
	_chosen = _marks().size() - 1
	_settle_the_sliders(wanted)
	_close_the_drawing()


func _show_the_drawing_buttons() -> void:
	var anything := not _all_strokes().is_empty()
	_undo_button.disabled = not anything
	_put_it_on.disabled = not anything


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
	_show_the_stripes()
	_show_the_colours()
	_show_the_sliders(marks)
	_show_the_keep_button(marks)
	_show_the_cover(id, marks)
	_board.queue_redraw()


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
