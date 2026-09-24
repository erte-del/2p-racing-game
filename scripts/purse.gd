extends Node

## The coins picked up on the road, and what they have been spent on.
##
## One purse for the whole game rather than one each. Two people on a split
## screen are sharing a keyboard and a machine, and the shop they are saving
## for is the machine's: a coin picked up by whoever is in the top half is a
## coin the pair of them have. Splitting it would turn every race into a
## squabble about who got to the coin first, which is not the game this is.
##
## Kept apart from GameSettings for the reason `TrackTimes` is kept apart from
## it: a setting is something a player chose and can change back, and a coin is
## something that happened. Kept apart from `TrackTimes` as well, because a
## time belongs to a track and a coin belongs to nobody in particular.
##
## A coin is banked the moment it is driven through, and nothing takes it back.
## Holding a run's coins in escrow until the flag would punish exactly the
## players who are struggling - the ones who spin, give up and restart - and
## the purse is not a score. It is what somebody picked up on the way.
##
## There is no server behind any of this and nothing here is worth protecting:
## a player who wants to open `purse.cfg` and write a bigger number in it has
## already bought the thing. So there is no checksum, no obfuscation and no
## second copy of the count to disagree with the first. (Unlike times, which go
## to a shared board and are constrained in the database - see
## `backend/schema.sql`.)

const SAVE_PATH := "user://purse.cfg"

## The one section the count lives in. What has been bought gets a section of
## its own per item, for the reason `TrackTimes` gives a track one: what an
## item has to its name can grow - when it was bought, what it cost - without
## moving what is already written down.
const PURSE := "purse"
const BOUGHT := "bought_"

## Emitted whenever the count moves, so a tally in the corner of a race or on
## the title screen can follow it without polling.
signal changed(coins: int)

## Not a const, so a check can point at somewhere that is not the player's own
## purse.
var save_path := Sandbox.path(SAVE_PATH)

var _coins := 0
## Item name -> true, for the things that have been bought. An item that is not
## in here has not been bought; there is no false written anywhere.
var _bought := {}


func _ready() -> void:
	load_purse()


## How many coins there are to spend.
func coins() -> int:
	return _coins


## Put coins in. Called the instant a car drives through one, from the
## furniture that owns it.
func bank(count := 1) -> void:
	if count <= 0:
		return
	_coins += count
	save_purse()
	changed.emit(_coins)


## Whether there is enough for something.
func can_afford(cost: int) -> bool:
	return _coins >= cost


## Take coins out, and say whether there were enough. Nothing is part-paid: a
## purse that cannot cover a price is left exactly as it was.
func spend(cost: int) -> bool:
	if cost < 0 or not can_afford(cost):
		return false
	_coins -= cost
	save_purse()
	changed.emit(_coins)
	return true


## Whether something has been bought already.
func owns(item: String) -> bool:
	return _bought.has(item)


## Whether a car may be painted a colour: everything the game came with, and
## whatever has been bought since.
##
## Here rather than on `Paints`, which is a table and names no autoload, and
## here rather than in a screen, because two screens now ask it - the paint
## screen over a paused race, and the garage - and a paint that one of them
## would wear without it having been bought is a paint nobody needs to buy.
func owns_paint(index: int) -> bool:
	return Paints.is_free(index) or owns(Paints.item_for(index))


## Buy something, once. Buying what is already owned is not a purchase and
## costs nothing: the purse is what stops an item being paid for twice, because
## it is the only thing that knows what is already in it.
func buy(item: String, cost: int) -> bool:
	if item.is_empty() or owns(item):
		return false
	if not spend(cost):
		return false
	_bought[item] = true
	save_purse()
	return true


## Everything bought, for a shop that wants to show it.
func bought() -> PackedStringArray:
	var out := PackedStringArray()
	for item in _bought:
		out.append(item)
	out.sort()
	return out


## Empty the purse and give back everything in it. Nothing in the game calls
## this yet; it is here for the day a screen offers to start again, and for a
## check that wants to begin from a purse nobody has put anything in.
func forget() -> void:
	if _coins == 0 and _bought.is_empty():
		return
	_coins = 0
	_bought.clear()
	save_purse()
	changed.emit(_coins)


func save_purse() -> void:
	var file := ConfigFile.new()
	file.set_value(PURSE, "coins", _coins)
	for item in _bought:
		file.set_value(BOUGHT + item, "bought", true)
	file.save(save_path)


func load_purse() -> void:
	_coins = 0
	_bought.clear()
	var file := ConfigFile.new()
	if file.load(save_path) != OK:
		return
	_coins = maxi(int(file.get_value(PURSE, "coins", 0)), 0)
	for section in file.get_sections():
		# Anything that is not an item of ours is left alone rather than read
		# as one with an empty name.
		if not section.begins_with(BOUGHT):
			continue
		if not bool(file.get_value(section, "bought", false)):
			continue
		_bought[section.trim_prefix(BOUGHT)] = true
