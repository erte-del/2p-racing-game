class_name RaceClock
extends RefCounted

## How a time reads, wherever it is shown.
##
## The race, the run against the clock, the track grid and the boards all put
## times on the screen, and a time on a button has to read as the same number
## as the time that was driven. Written once here so they cannot drift apart.


## Minutes only once there are any, so a forty second run reads "42.16" rather
## than "0:42.16".
static func format(seconds: float) -> String:
	var minutes := int(seconds) / 60
	var rest := fmod(seconds, 60.0)
	if minutes > 0:
		return "%d:%05.2f" % [minutes, rest]
	return "%.2f" % rest
