extends SceneTree

# Decorate a car and then go and look at it on the road.
#   Godot --path . --script tools/checks/decorate_shot.gd -- <out_dir>
#
# `tools/checks/decals.gd` is what holds the store, the cap and the gate to
# their rules. This is here for the half of decoration that no amount of
# asserting sees, and there is more of it here than anywhere else in the game,
# because the whole feature is a picture:
#
#   - whether the paint row under the car reads as the car's own colour rather
#     than as a second set of sticker colours, and whether the six the shop
#     sells are legibly both that colour and out of reach;
#   - whether a stripe actually lands on the body, in its own colour, rather
#     than washing the whole car in it or z-fighting with the paint under it;
#   - whether a sticker lands the right way up and the right way round on each
#     of the panels a car has, and whether the word a player wrote straight
#     onto the paintwork is still legible once it has been thrown at a curved
#     door;
#   - whether the car is framed, whether the ring round what is selected is
#     round the thing and not near it, and whether either of them stays inside
#     the view when the car is zoomed right into;
#   - whether either of them leaks onto the road. A decal projects onto
#     whatever its cull mask lets it, and the cars share the world with the
#     tarmac - so a sticker printed on the ground under the car is the failure
#     this feature was always most likely to ship with, and it is invisible to
#     every number in the game.
#
# The walk is: buy the slot, put one of each kind on in the garage, write a
# word on the car with the pen, turn it to its roof and then to its tail and
# put something on each, then start a race and look at the car from behind and
# from the side.
#
# Not headless: it takes pictures, so it needs a real renderer. Sandboxed like
# everything under `tools/`, so the purse it fills and the car it draws on are
# its own.

const PAGE := "Page/Panel/Margin/Box/"


func _init() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	var out: String = OS.get_cmdline_user_args()[0]
	var purse: Node = root.get_node_or_null(^"/root/Purse")
	var decals: Node = root.get_node_or_null(^"/root/Decals")
	var settings: Node = root.get_node_or_null(^"/root/GameSettings")
	if purse == null or decals == null or settings == null:
		print("the autoloads are missing, so there is nothing to draw on")
		quit(1)
		return
	purse.forget()
	decals.clear(settings.car_id(0))
	decals.clear(settings.car_id(1))
	# Not a chaotic race: this is about where the shapes land, and a decoration
	# that was turning colour would give a different picture every run.
	settings.chaos = false

	change_scene_to_file("res://scenes/menu.tscn")
	await _settle()
	var menu: Control = current_scene
	var garage: Control = menu.get_node("GarageScreen")

	garage.call("open", 2)
	await _settle()
	_shot(out, "garage_cars")

	# The tab, before it has been paid for. Everything on it is pressable and
	# says the price, which is the state every player meets it in.
	garage.call("_show_tab", 1)
	await _settle()
	var page: Node = garage.get("_decoration")
	page.call("_toggle_stripe", 0)
	await _settle()
	print("locked: ", garage.get_node(PAGE + "Status").text)
	_shot(out, "decoration_locked")

	purse.bank(Shop.SLOT_COST)
	purse.buy(Shop.SLOT_ITEM, Shop.SLOT_COST)
	await _settle()

	# The car's own paint, which is on this page as well and is not decoration
	# at all: the row under the car, pressed, and the car wearing it before the
	# next frame. Player one starts in red; this is the picture that says the
	# row is not a second set of sticker colours.
	page.call("_choose_paint", 8)
	await _settle()
	print("painted: ", garage.get_node(PAGE + "Status").text)
	_shot(out, "painting_the_car")

	# One of each kind, put on the way a player puts them on: through the
	# buttons, not by writing marks into the store behind the page's back.
	page.call("_choose_colour", 10)
	page.call("_toggle_stripe", 1)
	await _settle()
	page.call("_choose_colour", 2)
	page.call("_add_sticker", 4)
	await _settle()
	_place(page, Vector2(0.60, 0.46), 0.20)
	await _settle()
	_shot(out, "decoration_stripe_and_sticker")

	# And a word, written on the car with the pen the way a mouse writes one:
	# pressed on the view, dragged, let go, a stroke at a time - each one going
	# onto the car as it is let go of, which is the whole of what this is. On
	# the door nearest the camera, found by asking the car where its door is.
	var stage: Control = page.get("_stage")
	var shell: Node3D = stage.get("_shell")
	var box: AABB = stage.call("bounds")
	page.call("_choose_colour", 3)
	page.call("_press_the_pen")
	var door: Dictionary = shell.call("surface", Vector3(box.end.x + 1.0,
		box.position.y + box.size.y * 0.45, box.get_center().z), Vector3.LEFT)
	var on_the_door: Vector2 = (stage.call("flat", door.point) as Dictionary).at
	var word := _handwriting()
	for i in 3:
		_stroke(page, on_the_door, 56.0, word[i])
		page.call("_finish_a_stroke")
	await _settle()
	# Three of it on the paintwork and the fourth still in hand, which is the
	# state a player spends the whole of a word in.
	_stroke(page, on_the_door, 56.0, word[3])
	await _settle()
	_shot(out, "writing_on_the_car")
	page.call("_finish_a_stroke")
	_stroke(page, on_the_door, 56.0, word[4])
	page.call("_finish_a_stroke")
	page.call("_press_the_pen")
	await _settle()
	print("on the car: ", _worn(decals, settings))
	# The cover line rather than the status line: the status line is carrying
	# whatever the pen said last, which is the pen being put down.
	print("covered: ", (page.get("_cover") as Label).text)
	_shot(out, "decoration_all_three")

	# The bonnet, which is why things go on the body rather than on the box
	# round it: it slopes, and it sits well under the roofline, and nothing
	# thrown at the top of the box ever reached it. Looked at from in front
	# and above, and written on where the car says the bonnet is.
	stage.call("turn_by", -float(stage.get("_yaw")), 0.70 - float(stage.get("_pitch")))
	await _settle()
	var bonnet: Dictionary = shell.call("surface", Vector3(box.get_center().x,
		box.end.y + 1.0, box.position.z + box.size.z * 0.18), Vector3.DOWN)
	var on_the_bonnet: Vector2 = (stage.call("flat", bonnet.point) as Dictionary).at
	# Nothing selected first, or the colour would be the door's word's new one.
	page.call("_choose_nothing")
	page.call("_choose_colour", 11)
	page.call("_press_the_pen")
	for stroke in word:
		_stroke(page, on_the_bonnet, 150.0, stroke)
		page.call("_finish_a_stroke")
	page.call("_press_the_pen")
	await _settle()
	print("on the bonnet: ", _worn(decals, settings))
	_shot(out, "writing_on_the_bonnet")
	page.call("_take_it_off")
	stage.call("reset_view")
	await _settle()

	# The three sides the flat drawing of a car never had. Turned to the roof,
	# a sticker put on it, and then round to the tail for another - which is
	# the whole of what this page is for now, and the half of it no number
	# checks.
	stage.call("turn_by", 0.9, 0.85)
	await _settle()
	page.call("_choose_colour", 6)
	page.call("_add_sticker", 6)
	await _settle()
	_shot(out, "on_the_roof")
	# Squared up to the tail, which is what a player does to put something on
	# it: a boot lid is a quarter of the size of a flank, and it is the panel
	# in front of you only when you are actually standing behind the car.
	# Turned from wherever the view opens to nearly square at the tail, rather
	# than by a written-down amount. `CarStage` is not an identifier in a
	# `--script` run - it names `Garage`, which is an autoload - so how far
	# round it already is, is asked of the thing itself.
	stage.call("reset_view")
	stage.call("turn_by", PI + 0.10 - float(stage.get("_yaw")), -0.20)
	stage.call("zoom_by", 2.0)
	await _settle()
	page.call("_choose_colour", 4)
	page.call("_add_sticker", 5)
	await _settle()
	print("with the tail done: ", _worn(decals, settings))
	_shot(out, "on_the_tail_up_close")
	# Taken off again, so the car that goes out onto the road is the one the
	# rest of this walk is about.
	page.call("_take_it_off")
	stage.call("reset_view")
	await _settle()

	# The manual camera, ticked the way a player ticks it and taken right in
	# to the front wheel off the front corner - further in than the automatic
	# camera may go, and towards what is under the cursor rather than the
	# middle of the view. Whether the boxes read as a choice over the car, and
	# whether a view that close is still a car, are things only a picture says.
	var manual: CheckBox = page.get("_manual_box")
	manual.button_pressed = true
	await _settle()
	var wheel: Dictionary = shell.call("surface", Vector3(box.end.x + 1.0,
		box.position.y + box.size.y * 0.3, box.position.z + box.size.z * 0.2),
		Vector3.LEFT)
	var at_the_wheel: Vector2 = (stage.call("flat", wheel.point) as Dictionary).at \
		if not wheel.is_empty() else (stage as Control).size * 0.5
	stage.call("zoom_by", 9.0, at_the_wheel)
	await _settle()
	_shot(out, "manual_camera_close")
	(page.get("_automatic_box") as CheckBox).button_pressed = true
	stage.call("reset_view")
	await _settle()

	garage.call("close")
	await _settle()

	# The point of the whole walk: the same car, on the road, with the road
	# under it.
	await _on_the_road(out)
	purse.forget()
	quit()


## Start a race and look at the decorated car from the seat behind it and from
## beside it.
##
## The side view is the one that matters. It is where a sticker is, and it is
## where the ground is close enough to the car to show a decal that has leaked
## onto it.
func _on_the_road(out: String) -> void:
	var menu: Control = current_scene
	var page := "ModeChoice/Page/Panel/Margin/Box/"
	for button in ["Play", page + "Players/Together", page + "ModeSlot/Inner/Infinite",
			page + "ModeSlot/Inner/FlavourSlot/Inner/Row/Normal"]:
		menu.get_node(button).emit_signal("pressed")
		for i in 30:
			await process_frame
	var race: Node = current_scene
	for i in 40:
		await physics_frame
	_shot(out, "road_from_behind")

	# Round to the side of the car, close, with the tarmac in frame.
	var car: Node3D = race.get_node("Car1")
	var camera: Camera3D = race.get_node("Split/TopView/SubViewport/Camera")
	# Stopped rather than stripped of its script: the chase camera would put
	# itself back behind the car on the next frame, and taking a script off a
	# node that is already in the tree upsets more than it fixes.
	camera.set_process(false)
	camera.set_physics_process(false)
	var eye := car.global_position + Vector3(5.0, 1.4, 0.4)
	camera.global_transform = Transform3D(
		Basis.looking_at(car.global_position + Vector3(0.0, 0.7, 0.0) - eye,
			Vector3.UP), eye)
	for i in 6:
		await process_frame
	_shot(out, "road_from_the_side")

	# And from underneath the waistline, which is where a decal that reached
	# through the car and came out of the far door would show.
	var low := car.global_position + Vector3(4.2, 0.35, -2.6)
	camera.global_transform = Transform3D(
		Basis.looking_at(car.global_position + Vector3(0.0, 0.5, 0.0) - low,
			Vector3.UP), low)
	for i in 6:
		await process_frame
	_shot(out, "road_from_low")


## Put whatever is selected where the picture wants it.
## Drag the selected mark to a point on the car's view, given as fractions of
## the view, and make it a size - the way a player's mouse would.
func _place(page: Node, at: Vector2, size: float) -> void:
	var stage: Control = page.get("_stage")
	page.set("_grab_copy", 0)
	page.call("_drag_to", stage.size * at)
	var marks: Array = page.call("_marks")
	var chosen: int = page.get("_chosen")
	if chosen < 0 or chosen >= marks.size():
		return
	var mark: Dictionary = marks[chosen]
	mark["size"] = size
	var decals: Node = Engine.get_main_loop().root.get_node(^"/root/Decals")
	decals.change_mark(page.call("_car_id"), chosen, mark)


## A few strokes, the way a mouse drags them. Deliberately scrawled rather than
## neat: the question a picture of this answers is whether somebody's actual
## handwriting survives being thrown at a curved body, and a tidy polygon would
## not be asking it. As fractions of a square the word is written in.
func _handwriting() -> Array:
	return [
		PackedVector2Array([Vector2(0.10, 0.62), Vector2(0.16, 0.30),
			Vector2(0.23, 0.62), Vector2(0.20, 0.48), Vector2(0.14, 0.48)]),
		PackedVector2Array([Vector2(0.32, 0.30), Vector2(0.32, 0.64),
			Vector2(0.44, 0.64)]),
		PackedVector2Array([Vector2(0.54, 0.34), Vector2(0.62, 0.32),
			Vector2(0.56, 0.46), Vector2(0.64, 0.48), Vector2(0.54, 0.64)]),
		PackedVector2Array([Vector2(0.76, 0.30), Vector2(0.76, 0.66)]),
		PackedVector2Array([Vector2(0.72, 0.30), Vector2(0.86, 0.30)]),
	]


## One stroke of it with the pen, down and dragged but not yet let go, in a
## square `wide` pixels across round a point on the car's view.
func _stroke(page: Node, around: Vector2, wide: float,
		stroke: PackedVector2Array) -> void:
	var points := []
	for point in stroke:
		points.append(around + (point - Vector2(0.5, 0.5)) * wide)
	page.call("_start_a_stroke", points[0])
	for i in range(1, points.size()):
		page.call("_draw_to", points[i])


func _worn(decals: Node, settings: Node) -> String:
	var line := PackedStringArray()
	for mark: Dictionary in decals.marks_on(settings.car_id(0)):
		var what := "writing"
		if str(mark.kind) == DecalArt.STRIPE:
			what = DecalArt.stripe_name(int(mark.shape))
		elif str(mark.kind) == DecalArt.STICKER:
			what = DecalArt.sticker_name(int(mark.shape))
		line.append("%s in %s" % [what, Paints.name_of(int(mark.colour))])
	return ", ".join(line)


func _settle() -> void:
	for i in 8:
		await process_frame


func _shot(out: String, name: String) -> void:
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
