extends SceneTree

# The price list, the buying, and the screen that does it.
#   Godot --path . --headless --script tools/checks/shop.gd
#
# Three things about a shop can go wrong quietly, and none of them shows up by
# looking at it:
#
#   - a price that is not what the purse charges, which is a shop that lies;
#   - something on sale that cannot be reached, or something reachable that
#     was never put on sale - a colour added to `Paints` and forgotten is free
#     to everybody, and one sold under a name nothing hands out can never be
#     bought at all;
#   - an item that un-owns itself, which takes coins a player will not get
#     back.
#
# So this holds the table to `Paints`, drives a real purchase through a real
# `Purse`, and opens the real screen to see that an empty purse can still read
# every price. It cannot touch the player's own purse: every check under
# `tools/` is sandboxed, so what it banks and spends goes to a purse of its
# own. See `Sandbox`.
#
# `Purse` is reached off the tree rather than named. A `--script` run is
# compiled before the autoloads are registered, so `Purse` is not an
# identifier here - see the comment on `SETTINGS_PATH` in `screen_fit.gd`.
# `Shop` and `Paints` are named freely: they are plain tables that name no
# autoload, which is most of why they are tables.

var _faults := 0


func _init() -> void:
	await process_frame
	var purse := root.get_node_or_null(^"/root/Purse")
	if purse == null:
		_fault("there is no purse: the autoload is missing")
		print("%d faults" % _faults)
		quit(1)
		return

	_check_the_table()
	_check_against_the_paints()
	_check_buying(purse)
	await _check_the_screen(purse)
	await _check_the_paint_screen(purse)
	purse.forget()

	print("%d faults" % _faults)
	quit(1 if _faults > 0 else 0)


## The table on its own terms, before anything is bought out of it.
func _check_the_table() -> void:
	var stock := Shop.stock()
	if stock.is_empty():
		_fault("the shop has nothing in it")
		return
	var seen := {}
	for sold: Dictionary in stock:
		var item := String(sold.item)
		if item.is_empty():
			_fault("something is for sale under no name at all")
			continue
		if seen.has(item):
			_fault("%s is in the table twice" % item)
		seen[item] = true
		if String(sold.name).is_empty():
			_fault("%s has nothing to call itself on the page" % item)
		if int(sold.cost) <= 0:
			_fault("%s costs %d, which is not a price" % [item, int(sold.cost)])
		# The name goes into `purse.cfg` as a section - `bought_<item>` - so a
		# name with a bracket or a newline in it is a purse that cannot be read
		# back, and one with a space in it is a purse that reads back as
		# something else.
		for character in item:
			if not (character in "abcdefghijklmnopqrstuvwxyz0123456789_"):
				_fault("%s has a %s in its name, which a config section cannot hold"
					% [item, character])
				break
		# `entry` and `cost_of` are what everything else asks, so they have to
		# agree with the list they are reading.
		if Shop.entry(item) != sold:
			_fault("%s is not what the table hands back when it is asked for" % item)
		if Shop.cost_of(item) != int(sold.cost):
			_fault("%s costs %d in the list and %d when asked"
				% [item, int(sold.cost), Shop.cost_of(item)])

	# Something that is not sold is not free. A caller that could not tell the
	# two apart would give away whatever it failed to find.
	if not Shop.entry("nothing at all").is_empty():
		_fault("the shop sells something it does not have")
	if Shop.cost_of("nothing at all") != -1:
		_fault("something not for sale priced at %d" % Shop.cost_of("nothing at all"))
	print("%d things for sale, %d coins the lot" % [stock.size(), _total()])


## The table and the paints, held to each other. This is the one that catches a
## colour added to the list and forgotten about.
func _check_against_the_paints() -> void:
	var sold_paints := {}
	for sold: Dictionary in Shop.stock():
		if sold.kind != Shop.PAINT:
			continue
		var index := int(sold.paint)
		if index < Paints.FREE or index >= Paints.COLOURS.size():
			_fault("%s is sold as paint %d, which is not a paint that is sold"
				% [sold.item, index])
			continue
		if sold.item != Paints.item_for(index):
			_fault("paint %d is sold as %s and the paints call it %s"
				% [index, sold.item, Paints.item_for(index)])
		if sold.name != Paints.name_of(index):
			_fault("paint %d is called %s in the shop and %s in the paints"
				% [index, sold.name, Paints.name_of(index)])
		sold_paints[index] = true

	for index in Paints.COLOURS.size():
		var free := Paints.is_free(index)
		if free and sold_paints.has(index):
			_fault("%s came with the game and is being sold" % Paints.name_of(index))
		if not free and not sold_paints.has(index):
			_fault("%s is not free and is not in the shop, so nobody can ever have it"
				% Paints.name_of(index))
		# A free paint has no name in the purse, because there is nothing to
		# write down about it.
		if free and not Paints.item_for(index).is_empty():
			_fault("%s is free and the purse has a name for it" % Paints.name_of(index))

	# Both players have to have something to start in, whatever is in the purse.
	for player in Paints.DEFAULTS.size():
		if not Paints.is_free(Paints.DEFAULTS[player]):
			_fault("player %d starts in a paint that has to be bought" % (player + 1))

	# Two paints the same colour would be one paint a player can pay for twice,
	# and `Paints.index_of` would answer with whichever came first.
	for i in Paints.COLOURS.size():
		for j in range(i + 1, Paints.COLOURS.size()):
			if Paints.COLOURS[i].is_equal_approx(Paints.COLOURS[j]):
				_fault("%s and %s are the same colour"
					% [Paints.name_of(i), Paints.name_of(j)])
		if Paints.index_of(Paints.COLOURS[i]) != i:
			_fault("%s is not found in its own slot" % Paints.name_of(i))
	print("%d paints, %d of them free, %d of them sold"
		% [Paints.COLOURS.size(), Paints.FREE, Paints.COLOURS.size() - Paints.FREE])


## Buying, through the purse the game actually uses.
func _check_buying(purse: Node) -> void:
	var sold: Dictionary = Shop.stock()[0]
	var item := String(sold.item)
	var cost := int(sold.cost)

	purse.forget()
	if purse.owns(item):
		_fault("an empty purse already owns %s" % item)
	if purse.can_afford(cost):
		_fault("an empty purse can afford %d" % cost)
	if purse.buy(item, cost):
		_fault("%s was bought out of an empty purse" % item)

	# A coin short, which is the case a shop gets wrong by rounding.
	purse.bank(cost - 1)
	if purse.buy(item, cost):
		_fault("%s cost %d and was bought with %d" % [item, cost, cost - 1])
	if purse.coins() != cost - 1:
		_fault("a purse that could not pay came out at %d" % purse.coins())

	purse.bank(1)
	if not purse.buy(item, cost):
		_fault("%s cost %d and was refused with exactly %d" % [item, cost, cost])
	if purse.coins() != 0:
		_fault("buying %s for %d left %d behind" % [item, cost, purse.coins()])
	if not purse.owns(item):
		_fault("%s was paid for and is not owned" % item)

	# Bought twice is the one that costs a player real coins.
	purse.bank(cost)
	if purse.buy(item, cost):
		_fault("%s was bought a second time" % item)
	if purse.coins() != cost:
		_fault("being refused a second %s cost %d" % [item, cost - purse.coins()])

	# And owned things never un-own, through a save, a load, or buying
	# something else afterwards.
	purse.save_purse()
	purse.load_purse()
	if not purse.owns(item):
		_fault("%s was not owned any more after a save and a load" % item)
	if Shop.stock().size() > 1:
		var other := String(Shop.stock()[1].item)
		purse.bank(Shop.cost_of(other))
		purse.buy(other, Shop.cost_of(other))
		if not purse.owns(item):
			_fault("buying %s took %s away" % [other, item])
	print("a thing costs what it says, is paid for once, and stays bought")


## The screen itself, from an empty purse: every price on it, nothing hidden,
## and something on it the keyboard can reach.
func _check_the_screen(purse: Node) -> void:
	purse.forget()
	var shop: Control = (load("res://scenes/shop.tscn") as PackedScene).instantiate()
	root.add_child(shop)
	await process_frame
	shop.call("open")
	for i in 5:
		await process_frame

	var words := _words_on(shop)
	for sold: Dictionary in Shop.stock():
		# The thing an empty purse must be able to read: what it is, and what
		# it would cost. A shop that only showed what could be afforded would
		# give a player no reason to pick a coin up.
		if not words.has(String(sold.name)):
			_fault("%s is not named on the page" % sold.item)
		if not words.has(str(int(sold.cost))):
			_fault("%s does not show its price to an empty purse" % sold.item)

	# Both players are on one keyboard and neither has been asked to find the
	# mouse, so there has to be something on the page the cursor can sit on.
	# A disabled button in Godot cannot take focus, which is why nothing the
	# purse cannot afford is disabled.
	var focused := shop.get_viewport().gui_get_focus_owner()
	if focused == null or not shop.is_ancestor_of(focused):
		_fault("an empty shop opened with the keyboard on nothing")

	# Buy one through the page rather than through the purse, which is the only
	# way to find out that the button is wired to the price beside it.
	var sold: Dictionary = Shop.stock()[0]
	purse.bank(int(sold.cost))
	shop.call("_buy", String(sold.item))
	for i in 5:
		await process_frame
	if not purse.owns(String(sold.item)):
		_fault("pressing BUY on %s did not buy it" % sold.item)
	if purse.coins() != 0:
		_fault("pressing BUY on %s took %d of %d coins"
			% [sold.item, int(sold.cost) - purse.coins(), int(sold.cost)])
	if not _words_on(shop).has("YOURS"):
		_fault("%s was bought and the page does not say so" % sold.item)

	shop.call("close")
	for i in 2:
		await process_frame
	shop.queue_free()
	print("an empty purse can read every price, and BUY charges the one beside it")


## And the other end of it: a paint that has been bought can be worn, and one
## that has not cannot - but is on the page with its price on it either way.
func _check_the_paint_screen(purse: Node) -> void:
	purse.forget()
	var paint: Control = (load("res://scenes/paint.tscn") as PackedScene).instantiate()
	root.add_child(paint)
	await process_frame
	# One car on the road, so that the screen's other reason for refusing a
	# swatch is not in the way. With two, whatever player two is wearing is
	# taken from player one, and a check looking for paints the shop has locked
	# would be reading a refusal the shop knows nothing about.
	paint.call("open", 1)
	for i in 5:
		await process_frame

	var swatches: Array = paint.get_node(
		"Page/Panel/Margin/Box/Columns/P1/Grid").get_children()
	if swatches.size() != Paints.COLOURS.size():
		_fault("the paint screen shows %d of %d paints"
			% [swatches.size(), Paints.COLOURS.size()])
		paint.queue_free()
		return

	var sold_index := Paints.FREE
	var item := Paints.item_for(sold_index)
	for index in swatches.size():
		var swatch: Button = swatches[index]
		if Paints.is_free(index):
			if swatch.disabled:
				_fault("%s came with the game and cannot be picked"
					% Paints.name_of(index))
		else:
			if not swatch.disabled:
				_fault("%s can be worn without being bought" % Paints.name_of(index))
			if swatch.text != str(Shop.cost_of(Paints.item_for(index))):
				_fault("%s does not have its price on it, it says '%s'"
					% [Paints.name_of(index), swatch.text])

	# Bought, and the same swatch is a paint like any other - with no price
	# written across it any more, because there is nothing left to pay.
	purse.bank(Shop.cost_of(item))
	purse.buy(item, Shop.cost_of(item))
	paint.call("_show_the_choices")
	for i in 2:
		await process_frame
	var bought: Button = swatches[sold_index]
	if bought.disabled:
		_fault("%s was bought and still cannot be picked" % Paints.name_of(sold_index))
	if not bought.text.is_empty():
		_fault("%s was bought and still has '%s' written on it"
			% [Paints.name_of(sold_index), bought.text])

	paint.call("close")
	for i in 2:
		await process_frame
	paint.queue_free()
	print("a sold paint is shown with its price, refused until bought, and worn after")


## Every word written anywhere on a page, as a set, so a check can ask whether
## something is on it without knowing which label it landed in.
func _words_on(page: Node) -> Dictionary:
	var found := {}
	for node in page.find_children("*", "Label", true, false):
		found[(node as Label).text] = true
	for node in page.find_children("*", "Button", true, false):
		found[(node as Button).text] = true
	return found


## What it would cost to buy the shop out, which is the number to look at when
## wondering whether any of this is worth driving for.
func _total() -> int:
	var sum := 0
	for sold: Dictionary in Shop.stock():
		sum += int(sold.cost)
	return sum


func _fault(why: String) -> void:
	print("  %s" % why)
	_faults += 1
