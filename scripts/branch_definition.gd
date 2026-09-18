class_name BranchDefinition
extends TrackDefinition

## The high road of a split: a second road, floating, that leaves the course off
## a kicker in one lane and drops back onto it further on.
##
## A track file gets one from `high_road()` and builds it the way it builds the
## course - straights, climbs, jumps, platforms, lifts, pads and traps - while
## the course itself goes the long way round underneath. It runs in a straight
## line: it cuts across the long way round rather than following it, and a
## straight line is the one shape that can be checked to meet the course again
## where the course comes back. So it has no corners, and no rings - rings are
## checkpoints, and a checkpoint on one road of a split is one the other road
## can never bank.

## Where across the course the kicker is, and so where across it the high road
## runs and drops back down.
var lane := 0.5
## How far above the course the high road starts.
var rise := 2.0
## Where the kicker's lip is on the course, and where the course has come back
## to the line the high road runs along. Both in the course's own distances.
var lip_offset := 0.0
var rejoin_offset := -1.0


## Everything is built by the track file that asked for it, not described here.
func describe() -> void:
	pass


func corner(_degrees: float, _radius: float, _rise := 0.0) -> void:
	push_error("BranchDefinition: the high road runs straight; it has no corners")
