class_name CarContact
extends Node

## Settles the two cars running into each other, once a physics step, for both
## of them at once.
##
## The cars are both CharacterBody3D, so to each other they are walls:
## move_and_slide stops one going through the other and does nothing else. A
## car nosed into the other's bumper sat there at full throttle reading as fast
## while going nowhere, and a car leant on from the side was not moved at all.
## What this adds is the bump - speed passed from the car doing the hitting to
## the car being hit - and a shove apart.
##
## It is one node rather than something each car does to the other, because the
## cars take their physics steps one after the other. A car that knocked the
## other in its own step would hand it a changed speed before it had moved, and
## how every contact came out would depend on which car was first in the scene.
## This runs ahead of both, works each contact out from both cars' speeds as
## they stood at the start of the step, and hands both their knocks together.
##
## Only the two-player race builds one. Solo has one car and nothing for it to
## run into.

## The two cars, in no order that matters.
var _cars: Array[Car] = []
## Seconds left before another contact can knock anything.
var _recovery := 0.0


func _init(first: Car, second: Car) -> void:
	_cars = [first, second]
	name = "Contact"
	# Ahead of both cars, wherever the scene happens to have put them.
	process_physics_priority = -1


func _physics_process(delta: float) -> void:
	_recovery = maxf(_recovery - delta, 0.0)
	var a := _cars[0]
	var b := _cars[1]
	# Asked every step, so a car that has been held still does not come back
	# with news of what it touched before it was.
	var a_moved := a.take_moved()
	var b_moved := b.take_moved()
	if a.frozen or b.frozen or _recovery > 0.0:
		return

	# Whichever of the two ran into the other on the last step has it on
	# record; when both did, both records agree on the line between them. Each
	# normal points back at the car that recorded it, so b's is turned round.
	var normal := Vector3.ZERO
	if a_moved:
		normal += _touch(a, b)
	if b_moved:
		normal -= _touch(b, a)
	normal.y = 0.0
	if normal.length_squared() < 0.0001:
		return
	_settle(a, b, normal.normalized())
	_recovery = a.bump_recovery


## Where `car` ran into `other` on its last move, as the direction back at
## `car`, or nothing. Only the sides count: a car that came down on the other's
## roof has landed on it, which is the roof bounce's business.
func _touch(car: Car, other: Car) -> Vector3:
	var found := Vector3.ZERO
	for i in car.get_slide_collision_count():
		var collision := car.get_slide_collision(i)
		if collision.get_collider() != other:
			continue
		var normal := collision.get_normal()
		if absf(normal.y) < 0.7:
			found += normal
	return found


## One contact between the two cars, with `n` lying flat and pointing from `b`
## towards `a`.
func _settle(a: Car, b: Car, n: Vector3) -> void:
	var forward_a := _flat_heading(a)
	var forward_b := _flat_heading(b)
	# How fast each car is going at the other, along the line between them.
	var toward_a := a.speed() * forward_a.dot(-n)
	var toward_b := b.speed() * forward_b.dot(n)
	var closing := toward_a + toward_b

	var change_a := 0.0
	var change_b := 0.0
	if closing > 0.0:
		if absf(toward_a - toward_b) < 0.01:
			# Head on at the same speed, neither is the one doing the hitting,
			# so both pay half and neither is handed anything.
			change_a = -a.bump_take * closing * 0.5 * absf(forward_a.dot(n))
			change_b = -b.bump_take * closing * 0.5 * absf(forward_b.dot(n))
		elif toward_a > toward_b:
			var knocks := _hit(a, forward_a, forward_b, -n, closing)
			change_a = knocks.x
			change_b = knocks.y
		else:
			var knocks := _hit(b, forward_b, forward_a, n, closing)
			change_b = knocks.x
			change_a = knocks.y

	# Pushed apart by as much of the contact as is across each car. From
	# behind that is nothing; from the side it is all of it.
	a.knock(change_a, n * a.side_push * _across(forward_a, n))
	b.knock(change_b, -n * b.side_push * _across(forward_b, n))


## What one car running into the other costs it and hands over, as
## (hitter's change, hit car's change), in m/s along each car's own heading.
## `into` is the direction from the hitter to the car it hit.
func _hit(hitter: Car, forward: Vector3, hit_forward: Vector3, into: Vector3,
		closing: float) -> Vector2:
	# From behind, the line between the cars runs straight down the hitter's
	# heading and all of the hit counts; a car that clips the other at an angle
	# passes on only as much as it was pointed into it.
	var square := absf(forward.dot(into))
	var take := hitter.bump_take * closing * square
	var give := minf(hitter.bump_give, hitter.bump_take) * closing * square
	# The car hit is shoved along `into`, and only the part of that along its
	# own heading is speed: a car hit from behind is sped up, one hit from in
	# front is slowed, and one hit side on is pushed rather than either.
	return Vector2(-take, give * hit_forward.dot(into))


## A car's heading, flat on the ground.
func _flat_heading(car: Car) -> Vector3:
	var forward := -car.global_transform.basis.z
	forward.y = 0.0
	return forward.normalized()


## How much of a contact along `n` is across a car heading `forward`, from 0
## when it is straight down the car's length to 1 when it is square on its side.
func _across(forward: Vector3, n: Vector3) -> float:
	var along := forward.dot(n)
	return sqrt(maxf(1.0 - along * along, 0.0))
