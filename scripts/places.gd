class_name Places
extends RefCounted

## Who is ahead in a race between two cars.
##
## One rule, in one place, because two scenes ask it: the two-player race and
## the bot race. A rule about when a lead counts as a lead written down twice
## would sooner or later show the same two cars in different places depending
## on which mode they were in, and the one thing a place readout has to be is
## the same answer every time.
##
## Nobody leads off the grid, where both cars are the same distance along, so
## it starts at nobody rather than picking one arbitrarily. The two margins are
## what hold it still: a lead has to be earned by `lead_margin`, and only a
## clear return to inside `level_margin` gives it up, so the readout cannot
## strobe while the cars run wheel to wheel. In between it stands where it was.


## Who leads, given how far the first car is ahead of the second along the
## course in metres, and who was leading a moment ago. 0 or 1, or -1 for level.
static func leader(gap: float, was: int, level_margin: float, lead_margin: float) -> int:
	if absf(gap) < level_margin:
		return -1
	if absf(gap) > lead_margin:
		return 0 if gap > 0.0 else 1
	return was
