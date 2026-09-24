class_name Shop
extends RefCounted

## What the shop sells, and what it costs.
##
## One table in one file, so balancing the whole game is editing the numbers at
## the top of it rather than hunting a price through a screen, a purse and a
## check. Nothing here draws anything or spends anything: `ShopMenu` shows this
## list and `Purse` is what actually takes the coins, and neither of them knows
## a price of its own.
##
## Deliberately not an autoload. It is a table, it never changes while the game
## is running, and a check that wants to read a price should not have to stand
## up half the game first - `Purse` has to be an autoload because it is state,
## and this is the opposite of state.
##
## **Nothing sold here changes how a car drives.** Not speed, not grip, not
## acceleration, not damage. Every time on every board was set in the same car,
## and that is the only reason the leaderboard means anything; a shop that sold
## a faster car would end it. This is worth saying out loud because selling an
## upgrade is the obvious next feature to whoever picks this up, and it is the
## one thing this shop must never do.

## The kinds of thing there are to buy. Two today.
const PAINT := "paint"
const SLOT := "slot"

## What a paint costs.
##
## Priced against the customisation slot below: a paint is a smaller thing than
## the whole slot, so it sits well under it. A course carries 5 to 15 coins, so
## twenty is two or three courses of picking them up - long enough that the
## first one is something a player saved for, short enough that it arrives on
## the first evening rather than the third.
const PAINT_COST := 20

## The one slot that opens the decoration tab in the garage, and what the purse
## calls it.
##
## Fifty, which is the biggest thing the shop sells and is meant to be: it buys
## stripes, stickers and handwriting on every car in the garage at once and for
## good, where twenty buys one colour. Five or six courses of picking coins up,
## so it is the thing a player is saving for rather than the thing they buy on
## the way past.
##
## Bought once for the whole game rather than once per car. A player who paid
## fifty coins to decorate a car and then brought in a second model would
## otherwise be asked for fifty more to draw on it, and what they bought was
## the ability to draw.
const SLOT_ITEM := "customising"
const SLOT_NAME := "CUSTOMISING"
const SLOT_COST := 50


## Everything there is to buy, in the order the shop shows it.
##
## A function rather than a constant because the paints are read off `Paints`
## instead of being written down a second time here. A colour added to the sold
## half of that list is on sale the moment it is added, and cannot be added and
## quietly forgotten - `tools/checks/shop.gd` holds the two to each other.
##
## Each entry is `{item, kind, name, cost, paint}`. `item` is what the purse
## calls it and is never seen by a player; `paint` is the slot in
## `Paints.COLOURS`, or -1 for anything that is not a colour.
##
## The customisation slot is first because it is the biggest thing here and the
## one the paint prices were set against, and because a player reading down a
## price list should meet the thing that changes what the game lets them do
## before they meet the sixth shade of grey.
static func stock() -> Array:
	var list := [{
		"item": SLOT_ITEM,
		"kind": SLOT,
		"name": SLOT_NAME,
		"cost": SLOT_COST,
		"paint": -1,
	}]
	for index in range(Paints.FREE, Paints.COLOURS.size()):
		list.append({
			"item": Paints.item_for(index),
			"kind": PAINT,
			"name": Paints.name_of(index),
			"cost": PAINT_COST,
			"paint": index,
		})
	return list


## One entry by the name the purse knows it by, or an empty dictionary for
## something that is not for sale. Asked before anything is ever bought, so a
## stale item name in a purse from an older build can never be charged for.
static func entry(item: String) -> Dictionary:
	for sold: Dictionary in stock():
		if sold.item == item:
			return sold
	return {}


## What something costs, or -1 for something that is not sold. Never zero for a
## missing item: free and not-for-sale are different answers, and a caller that
## could not tell them apart would give away whatever it could not find.
static func cost_of(item: String) -> int:
	var sold := entry(item)
	return int(sold.cost) if not sold.is_empty() else -1
