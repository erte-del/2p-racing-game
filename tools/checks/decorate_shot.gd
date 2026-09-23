extends SceneTree

# Decorate a car and then go and look at it on the road.
#   Godot --path . --script tools/checks/decorate_shot.gd -- <out_dir>
#
# `tools/checks/decals.gd` is what holds the store, the cap and the gate to
# their rules. This is here for the half of decoration that no amount of
# asserting sees, and there is more of it here than anywhere else in the game,
# because the whole feature is a picture:
#
#   - whether a stripe actually lands on the body, in its own colour, rather
#     than washing the whole car in it or z-fighting with the paint under it;
#   - whether a sticker lands on the flank the right way up and the right way
#     round, and whether the word a player drew is still legible once it has
#     been thrown at a curved door;
#   - whether either of them leaks onto the road. A decal projects onto
#     whatever its cull mask lets it, and the cars share the world with the
#     tarmac - so a sticker printed on the ground under the car is the failure
#     this feature was always most likely to ship with, and it is invisible to
#     every number in the game.
#
# The walk is: buy the slot, put one of each kind on in the garage, look at the
# tab, then start a race and look at the car from behind and from the side.
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

	# One of each kind, put on the way a player puts them on: through the
	# buttons, not by writing marks into the store behind the page's back.
	page.call("_choose_colour", 10)
	page.call("_toggle_stripe", 1)
	await _settle()
	page.call("_choose_colour", 2)
	page.call("_add_sticker", 4)
	await _settle()
	_place(page, Vector2(0.62, 0.40), 0.20)
	await _settle()
	_shot(out, "decoration_stripe_and_sticker")

	# And a word, drawn the way a mouse draws one.
	page.call("_choose_colour", 3)
	page.call("_open_the_drawing")
	await _settle()
	page.set("_strokes", _handwriting())
	page.get("_pad").queue_redraw()
	page.call("_show_the_drawing_buttons")
	await _settle()
	_shot(out, "drawing_a_word")
	page.call("_keep_the_writing")
	await _settle()
	_place(page, Vector2(0.35, 0.46), 0.26)
	await _settle()
	print("on the car: ", _worn(decals, settings))
	print("covered: ", garage.get_node(PAGE + "Status").text)
	_shot(out, "decoration_all_three")

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
func _place(page: Node, at: Vector2, size: float) -> void:
	var marks: Array = page.call("_marks")
	var chosen: int = page.get("_chosen")
	if chosen < 0 or chosen >= marks.size():
		return
	var mark: Dictionary = marks[chosen]
	mark["at"] = at
	mark["size"] = size
	var decals: Node = Engine.get_main_loop().root.get_node(^"/root/Decals")
	decals.change_mark(page.call("_car_id"), chosen, mark)


## A few strokes, the way a mouse drags them out. Deliberately scrawled rather
## than neat: the question a picture of this answers is whether somebody's
## actual handwriting survives being thrown at a door, and a tidy polygon would
## not be asking it.
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
