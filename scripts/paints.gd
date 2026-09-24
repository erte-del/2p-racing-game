class_name Paints
extends RefCounted

## The colours a car can be painted, and the two it is painted by default.
##
## A fixed set rather than a colour wheel. Picking a paint is a thing done in
## the middle of a race, on a keyboard, by someone who wants to get back to
## driving - a grid of buttons is one glance and one press, and a wheel is a
## small precision task standing between a player and the road. It also means
## every car in the game is a colour that was chosen to read against tarmac,
## grass and a night sky, rather than whatever the mouse happened to be over.
##
## Kept here rather than in the screen that shows them because three other
## things need the same list: the setting that remembers a choice needs to
## start on one of these, a screen that marks the chosen swatch has to be
## comparing against the same numbers the car was painted with, and the shop
## needs to know which of them it is selling.
##
## The list is in two halves. The first twelve came with the game and always
## will: they are free, and selling something that was free would be taking it
## away rather than adding anything. The six after them are bought in the shop,
## and are deliberately not more of the same - the twelve are the wheel, and
## the six are the shades off it that no amount of picking round a wheel gets
## to. See `Shop`.

## Every paint there is, in the order they are shown: six across, three rows.
## The first two rows are ordered round the wheel so neighbouring swatches are
## neighbouring colours and the grid reads as a spectrum rather than as a bag
## of paint. The third row is the six the shop sells.
##
## The sold six are appended rather than mixed in, so that a colour keeps the
## slot it has always had. A settings file remembers a paint as a colour and
## not as a number, but `DEFAULTS` below is a number, and so is everything a
## check writes down.
const COLOURS: Array[Color] = [
	Color(0.906, 0.145, 0.145),
	Color(0.949, 0.451, 0.078),
	Color(0.949, 0.820, 0.149),
	Color(0.451, 0.800, 0.200),
	Color(0.098, 0.600, 0.322),
	Color(0.098, 0.651, 0.651),
	Color(0.098, 0.420, 0.898),
	Color(0.129, 0.200, 0.549),
	Color(0.522, 0.251, 0.800),
	Color(0.918, 0.349, 0.651),
	Color(0.878, 0.898, 0.929),
	Color(0.078, 0.086, 0.110),
	Color(0.851, 0.769, 0.561),
	Color(0.639, 0.275, 0.149),
	Color(0.420, 0.459, 0.180),
	Color(0.361, 0.420, 0.502),
	Color(0.400, 0.149, 0.349),
	Color(0.639, 0.859, 0.937),
]

## What each is called, for anyone who goes looking. Same order.
##
## A sold paint's name is also how the purse writes it down, so renaming one
## gives it back to the shop: a player who owned SAND and finds it called
## SANDSTONE owns nothing. Rename a paint and the name it had belongs to the
## old name for ever.
const NAMES: Array[String] = [
	"RED", "ORANGE", "YELLOW", "LIME", "GREEN", "TEAL",
	"BLUE", "NAVY", "PURPLE", "PINK", "WHITE", "BLACK",
	"SAND", "RUST", "OLIVE", "SLATE", "PLUM", "ICE",
]

## How many of them are free: everything before this slot, and nothing after
## it. One number rather than a flag per colour, because the two halves are
## two halves of a list and not a property a colour happens to have.
const FREE := 12

## Which paint each player starts on. Red and blue, which is what the two cars
## have always been, and far enough apart to tell at a glance across a split
## screen in the dark.
const DEFAULTS := [0, 6]


## The paint at a slot, or the first one for a slot that is not there.
static func colour(index: int) -> Color:
	if index < 0 or index >= COLOURS.size():
		return COLOURS[0]
	return COLOURS[index]


## What a paint is called.
static func name_of(index: int) -> String:
	if index < 0 or index >= NAMES.size():
		return NAMES[0]
	return NAMES[index]


## What a player's car is painted before anyone has changed it.
static func default_for(player: int) -> Color:
	if player < 0 or player >= DEFAULTS.size():
		return COLOURS[DEFAULTS[0]]
	return COLOURS[DEFAULTS[player]]


## A paint as a colour to write words in. A car can be painted black, and a
## heading in it would be a heading nobody can read, so anything too dark to
## sit on a panel is lifted until it can be.
static func legible(paint: Color) -> Color:
	if paint.v < 0.55:
		paint.v = 0.55
	return paint


## Whether a paint came with the game. A colour that is not one of these at
## all - what chaos paints a car - is free in the only sense that matters: it
## was never sold and nothing stops a car wearing it.
static func is_free(index: int) -> bool:
	return index < FREE


## What the purse calls a sold paint, and an empty string for a free one.
##
## The name rather than the slot, so `purse.cfg` says `bought_paint_sand` and a
## player who opens it can see what they paid for. It is a file with nothing
## worth protecting in it (see `Purse`), so it may as well be a file that reads.
static func item_for(index: int) -> String:
	if index < FREE or index >= NAMES.size():
		return ""
	return "paint_%s" % NAMES[index].to_lower()


## Which slot a colour sits in, or -1 for a colour that is not one of these -
## which is what a car repainted by chaos is wearing.
##
## Compared loosely, because a colour that has been through a file and back is
## not always the same float it went in as, and a swatch that would not mark
## itself as chosen after a restart is worse than one that is a shade out.
static func index_of(colour_wanted: Color) -> int:
	for i in COLOURS.size():
		if COLOURS[i].is_equal_approx(colour_wanted):
			return i
	return -1
