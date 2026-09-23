extends SceneTree

# Walk the shop: open it broke, try to buy, earn the coins, buy, and go and
# wear it.
#   Godot --path . --script tools/checks/shop_shot.gd -- <out_dir>
#
# `tools/checks/shop.gd` is what holds the prices and the buying to their
# rules; this is here for the half of a shop that no amount of asserting sees.
# Whether a price is legible against the panel, whether a locked swatch reads
# as locked rather than as broken, and whether a player refused a purchase is
# told anything useful - those are looked at.
#
# The walk is deliberately the poor one: the shop is opened with nothing in the
# purse, because that is the state every player is in the first time they open
# it and the state a shop is most likely to be built without ever seeing.
#
# Not headless: it takes pictures, so it needs a real renderer. Sandboxed like
# everything under `tools/`, so the purse it fills and empties is its own.

const PAGE := "Page/Panel/Margin/Box/"


func _init() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	var out: String = OS.get_cmdline_user_args()[0]
	var purse := root.get_node_or_null(^"/root/Purse")
	if purse == null:
		print("there is no purse: the autoload is missing")
		quit(1)
		return
	purse.forget()

	change_scene_to_file("res://scenes/menu.tscn")
	await _settle()
	var menu: Control = current_scene
	var shop: Control = menu.get_node("ShopScreen")

	# The title with the shop on it, and a purse with nothing in it, which is
	# also the check that the fifth button is on the screen at all.
	_shot(out, "title")

	menu.get_node("Shop").emit_signal("pressed")
	await _settle()
	print("shop open: ", shop.visible, "  coins: ", purse.coins())
	print("on the page: ", _rows(shop))
	_shot(out, "shop_broke")

	# Pressing BUY with an empty purse. It is allowed to be pressed on purpose -
	# a disabled button cannot take the keyboard, and both players are on one -
	# so what matters is that it says something worth reading.
	var first: Dictionary = Shop.stock()[0]
	shop.call("_buy", String(first.item))
	await _settle()
	print("refused: ", shop.get_node(PAGE + "Status").text)
	_shot(out, "shop_refused")

	# Enough for one, which is the state a shop spends most of its life in:
	# something within reach and something not.
	purse.bank(int(first.cost))
	await _settle()
	_shot(out, "shop_one_affordable")

	shop.call("_buy", String(first.item))
	await _settle()
	print("bought: ", shop.get_node(PAGE + "Status").text)
	print("owns %s: %s  coins left: %d" % [first.item, purse.owns(String(first.item)),
		purse.coins()])
	_shot(out, "shop_bought")

	shop.get_node(PAGE + "Back").emit_signal("pressed")
	await _settle()
	print("closed: ", not shop.visible)

	# And the other end of it. The paint screen only opens over a paused race,
	# so that is where the bought colour is looked at - one row of swatches
	# still locked with prices on them, and one no longer.
	await _the_paint_screen(out)
	purse.forget()
	quit()


## Start a race, pause it, and open PAINT: the third row is the sold six, five
## of them still wearing their price and the one that was just bought wearing
## nothing.
func _the_paint_screen(out: String) -> void:
	var menu: Control = current_scene
	var page := "ModeChoice/Page/Panel/Margin/Box/"
	for button in ["Play", page + "Players/Together", page + "ModeSlot/Inner/Infinite",
			page + "ModeSlot/Inner/FlavourSlot/Inner/Row/Normal"]:
		menu.get_node(button).emit_signal("pressed")
		for i in 30:
			await process_frame
	var race: Node = current_scene
	var pause: Control = race.get_node("Pause")
	pause.call("open", "PAUSED", "ANOTHER GO")
	await _settle()
	var paint: Control = pause.get_node("PaintScreen")
	paint.call("open", 2)
	for i in 8:
		await process_frame
	var swatches: Array = paint.get_node(
		"Page/Panel/Margin/Box/Columns/P1/Grid").get_children()
	var locked := PackedStringArray()
	for index in swatches.size():
		if (swatches[index] as Button).disabled:
			locked.append("%s%s" % [Paints.name_of(index),
				"" if (swatches[index] as Button).text.is_empty()
				else " (%s)" % (swatches[index] as Button).text])
	print("refused on the paint screen: ", ", ".join(locked))
	_shot(out, "paint_with_shop_colours")


func _rows(shop: Control) -> String:
	var line := PackedStringArray()
	for sold: Dictionary in Shop.stock():
		line.append("%s %d" % [sold.name, int(sold.cost)])
	return ", ".join(line)


func _settle() -> void:
	for i in 6:
		await process_frame


func _shot(out: String, name: String) -> void:
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
