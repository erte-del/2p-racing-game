class_name Paints
extends RefCounted

## The colours a car can be painted, and the two it is painted by default.
##
## A fixed set rather than a colour wheel. Picking a paint is a thing done in
## the middle of a race, on a keyboard, by someone who wants to get back to
## driving - twelve buttons is one glance and one press, and a wheel is a
## small precision task standing between a player and the road. It also means
## every car in the game is a colour that was chosen to read against tarmac,
## grass and a night sky, rather than whatever the mouse happened to be over.
##
## Kept here rather than in the screen that shows them because two other
## things need the same list: the setting that remembers a choice needs to
## start on one of these, and a screen that marks the chosen swatch has to be
## comparing against the same numbers the car was painted with.

## The twelve, in the order they are shown: six across, two rows. Ordered
## round the wheel so neighbouring swatches are neighbouring colours and the
## grid reads as a spectrum rather than as a bag of paint.
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
]

## What each is called, for anyone who goes looking. Same order.
const NAMES: Array[String] = [
	"RED", "ORANGE", "YELLOW", "LIME", "GREEN", "TEAL",
	"BLUE", "NAVY", "PURPLE", "PINK", "WHITE", "BLACK",
]

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
