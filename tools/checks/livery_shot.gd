extends SceneTree

# Design a livery, save it, and find it in the garage.
#   Godot --path . --script tools/checks/livery_shot.gd -- <out_dir>
#
# `tools/checks/liveries.gd` holds the writing, the id and the rules. This is
# the walk a player actually takes, for the half of it no assertion sees:
# whether a saved design is recognisable from the small picture on its row,
# whether two designs tell themselves apart at that size, and whether the same
# livery in the other player's row plainly reads as the same design on a
# different colour.
#
# Not headless: it takes pictures. Sandboxed like everything under `tools/`,
# so the liveries it saves and throws away are its own.

const PAGE := "Page/Panel/Margin/Box/"


func _init() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	var out: String = OS.get_cmdline_user_args()[0]
	var purse: Node = root.get_node_or_null(^"/root/Purse")
	var decals: Node = root.get_node_or_null(^"/root/Decals")
	var liveries: Node = root.get_node_or_null(^"/root/Liveries")
	var settings: Node = root.get_node_or_null(^"/root/GameSettings")
	if purse == null or liveries == null:
		print("the autoloads are missing")
		quit(1)
		return
	purse.forget()
	purse.bank(Shop.SLOT_COST)
	purse.buy(Shop.SLOT_ITEM, Shop.SLOT_COST)
	settings.chaos = false
	for player in 2:
		decals.clear(settings.car_id(player))
	for one: Dictionary in liveries.all():
		liveries.remove(one.id)

	change_scene_to_file("res://scenes/menu.tscn")
	await _settle()
	var menu: Control = current_scene
	var garage: Control = menu.get_node("GarageScreen")
	garage.call("open", 2)
	await _settle()

	# Draw one on the decoration tab, the way a player does.
	garage.call("_show_tab", 1)
	await _settle()
	var page: Node = garage.get("_decoration")
	page.call("_choose_colour", 10)
	page.call("_toggle_stripe", 1)
	page.call("_choose_colour", 11)
	page.call("_add_sticker", 2)
	await _settle()
	_place(page, Vector2(0.44, 0.44), 0.19)
	await _settle()
	_shot(out, "livery_designed")

	# Save it. The panel that asks what it is called is the picture worth
	# taking: it is the only place a player is asked anything about a livery.
	page.call("_ask_what_to_call_it")
	await _settle()
	(page.get("_name_edit") as LineEdit).text = "RACE NUMBER"
	page.call("_on_name_changed", "RACE NUMBER")
	await _settle()
	_shot(out, "livery_naming")
	page.call("_keep_it")
	await _settle()
	print("saved: ", garage.get_node(PAGE + "Status").text)
	print("the button now says: ", (page.get("_keep_button") as Button).text)
	_shot(out, "livery_saved")

	# A second design, so the row has something to tell apart.
	page.call("_take_it_all_off")
	page.call("_choose_colour", 1)
	page.call("_toggle_stripe", 2)
	page.call("_choose_colour", 2)
	page.call("_add_sticker", 3)
	await _settle()
	_place(page, Vector2(0.66, 0.42), 0.22)
	await _settle()
	page.call("_ask_what_to_call_it")
	await _settle()
	(page.get("_name_edit") as LineEdit).text = "FLAMES"
	page.call("_on_name_changed", "FLAMES")
	page.call("_keep_it")
	await _settle()

	# And there they both are, beside the cars.
	garage.call("_show_tab", 0)
	await _settle()
	print("in the garage: ", _named(liveries))
	_shot(out, "livery_in_the_garage")

	# Put the first one on player two's car, which is a different colour.
	var tiles: Array = (garage.get("_livery_grids")[1] as Node).get_children()
	(tiles[0] as Button).emit_signal("pressed")
	await _settle()
	print("worn: ", garage.get_node(PAGE + "Status").text)
	_shot(out, "livery_worn_by_player_two")

	for one: Dictionary in liveries.all():
		liveries.remove(one.id)
	decals.clear(settings.car_id(0))
	decals.clear(settings.car_id(1))
	purse.forget()
	quit()


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


func _named(liveries: Node) -> String:
	var line := PackedStringArray()
	for one: Dictionary in liveries.all():
		line.append(str(one.name))
	return ", ".join(line)


func _settle() -> void:
	for i in 10:
		await process_frame


func _shot(out: String, name: String) -> void:
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
