class_name ShopMenu
extends Control

## The shop: everything there is to buy, what it costs, and what has been
## bought already.
##
## It lies over the title rather than replacing it, the way the garage and the
## settings do, so the backdrop keeps turning behind it and `closed` is emitted
## on the way out for whoever opened it to take focus back.
##
## **Everything is always on the page, price and all, whether or not there are
## coins for it.** A shop that hid its stock until a player could afford it
## would be a shop that gave them no reason to pick a coin up - the price is
## the reason, and a player has to be able to read it from an empty purse. So
## nothing here is ever hidden, greyed out of legibility or held back; the only
## thing that changes with the purse is whether pressing BUY works.
##
## Where a paint is actually worn is on the line under the heading rather than
## in what is said after a purchase. A paint goes on from the paint screen,
## which is on the pause menu and not on this one, and that is worth knowing
## before spending twenty coins rather than after - which is what a permanent
## line says and a message that scrolls past cannot.
##
## And BUY is pressable even when there are not enough coins for it. A disabled
## button in Godot cannot take keyboard focus, and both players are on one
## keyboard with nobody asked to find the mouse: disabling what cannot be
## afforded would leave a player with an empty purse unable to put the cursor
## on a single row of the shop. Pressing it with too little says what it costs
## and what there is, which is the answer the player was after anyway. What is
## already owned is disabled, because there the button really has nothing left
## to do.
##
## Nothing here draws a price of its own. `Shop` is the table and `Purse` takes
## the coins; this screen is what shows them to somebody.
##
## The page is a fixed width, the way the garage's list of shared cars is. The
## status line at the bottom says different lengths of thing, and a panel that
## grew to fit whatever it had just been told would resize the whole page under
## the player's hands every time they pressed BUY. So the widest thing on it is
## the line under the heading, which never changes, and everything said below is
## said inside that.

## Emitted when the screen closes, so whoever opened it can take focus back.
signal closed

## How big a paint's swatch is drawn beside its name, in pixels. Wider than it
## is tall, so it reads as a sample of paint rather than as another button on a
## page that already has one per row.
const SWATCH_SIZE := Vector2(54.0, 30.0)

## The colour a price is written in: the coin's own gold, taken from the tally
## that draws the discs rather than picked again here.
const PRICE_COLOUR := Color(1.0, 0.82, 0.24)

const QUIET := Color(0.72, 0.76, 0.86)
const WRONG := Color(0.98, 0.55, 0.5)
const RIGHT := Color(0.6, 0.9, 0.68)

@onready var _stock: GridContainer = $Page/Panel/Margin/Box/Stock
@onready var _status: Label = $Page/Panel/Margin/Box/Status
@onready var _back_button: Button = $Page/Panel/Margin/Box/Back

## The BUY button on each row, by the name the purse knows the item by, so a
## row can be dressed again without the page being built again.
var _buttons := {}


func _ready() -> void:
	_back_button.pressed.connect(close)
	# Watched rather than remembered. Buying is the only thing on this page
	# that moves the purse, but a coin banked by a race going on behind the
	# title would move it too, and a shop showing a total from a minute ago is
	# a shop that refuses something a player can see they can afford.
	Purse.changed.connect(_on_purse_changed)
	_build()
	hide()


## Show the screen.
func open() -> void:
	_say("", QUIET)
	_show_the_stock()
	show()
	# The cursor starts on the first thing that can still be bought, because
	# that is what somebody opened a shop to do. A player who owns everything
	# gets BACK, which is then the only thing on the page with anything left
	# to say.
	_focus_something_to_buy()


func close() -> void:
	hide()
	closed.emit()


## Escape backs out of the screen. Nothing inside it opens anything, so there
## is only ever the one step.
func _input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	close()


## Lay out a row per thing for sale: what it looks like, what it is called,
## what it costs, and a button to buy it.
##
## Built here rather than in the scene because the stock is a table, and a
## price list written into a scene is a price list that has to be edited twice.
## Built once rather than rebuilt on every purchase: nothing is ever added to
## the shop or taken out of it while it is open, and only what the rows *say*
## changes - which is `_show_the_stock`.
func _build() -> void:
	_stock.add_child(_heading(""))
	_stock.add_child(_heading("WHAT"))
	_stock.add_child(_heading("COINS"))
	_stock.add_child(_heading(""))
	for sold: Dictionary in Shop.stock():
		_stock.add_child(_emblem(sold))
		_stock.add_child(_name_label(sold))
		_stock.add_child(_price_label(sold))
		var buy := Button.new()
		buy.custom_minimum_size = Vector2(150.0, 0.0)
		buy.pressed.connect(_buy.bind(String(sold.item)))
		_buttons[sold.item] = buy
		_stock.add_child(buy)


## One of the small words over a column. The row exists so that a bare `20` in
## the middle of the page is a number with a unit.
func _heading(what: String) -> Label:
	var label := Label.new()
	label.text = what
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", QUIET)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


## What a thing looks like, beside its name. A paint is the paint itself: the
## name of a colour is not a colour, and a player buying SLATE should be able
## to see what slate is before they pay for it.
func _emblem(sold: Dictionary) -> Control:
	var swatch := Panel.new()
	swatch.custom_minimum_size = SWATCH_SIZE
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = (Paints.colour(int(sold.paint)) if sold.kind == Shop.PAINT
		else Color(0.176, 0.235, 0.353))
	box.set_corner_radius_all(6)
	box.border_color = Color(0.898, 0.929, 1.0, 0.35)
	box.set_border_width_all(2)
	swatch.add_theme_stylebox_override("panel", box)
	return swatch


func _name_label(sold: Dictionary) -> Label:
	var label := Label.new()
	label.text = String(sold.name)
	label.add_theme_font_size_override("font_size", 24)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _price_label(sold: Dictionary) -> Label:
	var label := Label.new()
	label.text = str(int(sold.cost))
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", PRICE_COLOUR)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


## Say on every row what the purse makes of it now. The prices themselves are
## never touched: they are what the page is for.
func _show_the_stock() -> void:
	for sold: Dictionary in Shop.stock():
		var buy: Button = _buttons.get(sold.item)
		if buy == null:
			continue
		var owned: bool = Purse.owns(String(sold.item))
		buy.text = "YOURS" if owned else "BUY"
		buy.disabled = owned
		buy.tooltip_text = ("%s is already yours" % sold.name if owned
			else "%s for %d coins" % [sold.name, int(sold.cost)])


## Buy one thing, once.
##
## The purse is asked rather than told: `Purse.buy` checks the price and what
## is already owned itself, because it is the only thing that knows what is in
## it. This adds nothing to that but the words a player reads.
func _buy(item: String) -> void:
	var sold := Shop.entry(item)
	if sold.is_empty():
		# Only reachable if a row outlived the table it was built from, which
		# it cannot - but a shop that charged for something it could not name
		# is the one failure here worth being loud about.
		_say("THAT IS NOT FOR SALE.", WRONG)
		return
	var cost := int(sold.cost)
	if Purse.owns(item):
		_say("%s IS ALREADY YOURS." % sold.name, QUIET)
		_show_the_stock()
		return
	if not Purse.can_afford(cost):
		_say("%s COSTS %d. THERE ARE %d IN THE PURSE." % [sold.name, cost, Purse.coins()],
			WRONG)
		return
	if not Purse.buy(item, cost):
		_say("%s COULD NOT BE BOUGHT." % sold.name, WRONG)
		return
	_say("%s IS YOURS." % sold.name, RIGHT)
	_show_the_stock()
	# The row that was just bought cannot be pressed any more, so the cursor
	# would be sitting on a dead button. Moved to the next thing worth buying
	# rather than left there.
	_focus_something_to_buy()


## Put the cursor on the first thing still worth pressing, or on BACK when
## there is nothing left to buy.
func _focus_something_to_buy() -> void:
	for sold: Dictionary in Shop.stock():
		var buy: Button = _buttons.get(sold.item)
		if buy != null and not buy.disabled:
			buy.grab_focus()
			return
	_back_button.grab_focus()


## A coin banked while the shop is open is a shop showing the wrong total and
## possibly refusing something it should not.
##
## Whatever was last said goes with it. "THAT COSTS 20 AND THERE ARE 0" is only
## true of the purse it was said about, and left standing over a tally that now
## reads 20 it is a page arguing with itself. Cleared here rather than by
## whoever moved the purse, because the message is this page's and the coin
## could have come from anywhere - including a race going on behind the title.
## `_buy` says its piece after the purse has already moved, so a purchase is
## not clearing its own answer.
func _on_purse_changed(_coins: int) -> void:
	if not visible:
		return
	_say("", QUIET)
	_show_the_stock()


func _say(what: String, colour: Color) -> void:
	# A space rather than nothing, so the line keeps its height and the buttons
	# under it do not jump every time something is said.
	_status.text = what if not what.is_empty() else " "
	_status.add_theme_color_override("font_color", colour)
