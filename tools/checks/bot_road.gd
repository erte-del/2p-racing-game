extends SceneTree

# Drive the bot road: the player's car, one the computer drives, one winner.
#   Godot --path . --headless --fixed-fps 60 --script tools/checks/bot_road.gd
#
# tools/checks/bot_race.gd is about how fast the bot is, over every track. This
# is about the race it is in: that a second car appears on a bot road and on
# nothing else, that the two of them start side by side and know about each
# other, that either of them crossing the line ends it and says so, that a
# broken car ends it the other way round, and that nothing about any of it is
# written down. A bot road is a door, not a time trial.
#
# The player's car is driven by a BotDriver here too, because a check has no
# hands. That is the only cheat: the car it drives is the player's car, taking
# its pedals and wheel through the same hook, so a race won here is a race a
# player could have won.

const ROAD := "res://tracks/bot/b1_the_gate.gd"
const TRIAL := "res://tracks/01_first_light.gd"
const PATIENCE := 60 * 260
## The most the frame that builds the scene may spend, in milliseconds. Generous,
## because it builds a road and a car as well - the point is only that the bot's
## whole line is not in there.
const BUILD_CEILING_MS := 120.0

var _faults := 0
var _settings: Node
var _times: Node
var _garage: Node


func _init() -> void:
	await process_frame
	_settings = root.get_node_or_null(^"/root/GameSettings")
	_garage = root.get_node_or_null(^"/root/Garage")
	_settings.chaos = false
	_settings.damage = false
	_times = root.get_node_or_null(^"/root/TrackTimes")
	if _times != null:
		_times.save_path = "user://times_bot_road.cfg"
		_wipe_the_times()

	await _a_time_trial_carries_no_bot()
	await _the_line_is_worked_out_during_the_countdown()
	await _restarting_while_it_is_still_being_worked_out()
	await _the_grid()
	await _the_bot_wins()
	await _the_player_wins()
	await _a_broken_car()
	await _putting_the_bot_back()
	_the_places()

	_wipe_the_times()
	print("%d faults" % _faults)
	quit(1 if _faults > 0 else 0)


## Nineteen time trials and the endless course must pay nothing for a car they
## do not have, so the second car is not in solo.tscn and nothing on a normal
## road builds one.
func _a_time_trial_carries_no_bot() -> void:
	var solo := await _open(TRIAL)
	var bot: Car = solo.get("_bot")
	print("on a time trial: bot %s, arrow %s, place readout %s" % [
		"present" if bot != null else "absent",
		"shown" if (solo.get_node("Arrow") as Node3D).visible else "hidden",
		"shown" if _place(solo).visible else "hidden"])
	if bot != null:
		_fault("a time trial built a bot's car")
	if _place(solo).visible:
		_fault("a time trial showed the place readout")
	if solo.get_node("Car").rival != null:
		_fault("a time trial gave the player a rival")
	for child in solo.get_children():
		if child is CarContact:
			_fault("a time trial added a CarContact")
	_close(solo)


## The bot's line costs half a second to work out, which is a hitch if it happens
## on one frame. It is spread over the countdown instead: still going a moment
## after the scene opens, and finished before the cars are let go.
func _the_line_is_worked_out_during_the_countdown() -> void:
	_settings.track_file = ROAD
	var solo: Node = load("res://scenes/solo.tscn").instantiate()
	var opened := Time.get_ticks_usec()
	root.add_child(solo)
	var built := float(Time.get_ticks_usec() - opened) / 1000.0
	var driver: BotDriver = (solo.get("_bot") as Car).driver
	var begun := driver.is_planned()

	# Frame by frame to GO, watching for one that took much longer than the rest:
	# the point of a budget is that no single frame carries the plan.
	var longest := 0.0
	var frames := 0
	while not solo.get("_running") and frames < 1200:
		var at := Time.get_ticks_usec()
		await process_frame
		longest = maxf(longest, float(Time.get_ticks_usec() - at) / 1000.0)
		frames += 1
	print("the line is spread: %s when the scene opened (%.0f ms in _ready), %s at GO"
		% ["unfinished" if not begun else "ALREADY DONE",
			built, "done" if driver.is_planned() else "STILL GOING"])
	print("  %d frames to GO, longest %.1f ms" % [frames, longest])
	if begun:
		_fault("the whole line was worked out on the frame the scene opened")
	if built > BUILD_CEILING_MS:
		_fault("building the scene took %.0f ms, over the %.0f ms ceiling"
			% [built, BUILD_CEILING_MS])
	if not driver.is_planned():
		_fault("the cars were let go with the bot's line unfinished")
	_close(solo)


## The restart key works during the countdown, which lands on a plan that is not
## finished - and the practice laps run on the same progress the race does. The
## line that comes out has to be the line that would have come out anyway.
func _restarting_while_it_is_still_being_worked_out() -> void:
	var lines := []
	for restarts: int in [0, 3]:
		var solo: Node = load("res://scenes/solo.tscn").instantiate()
		_settings.track_file = ROAD
		root.add_child(solo)
		var driver: BotDriver = (solo.get("_bot") as Car).driver
		for r in restarts:
			# Part way into the practice laps, which is the stage that shares its
			# progress with the race.
			while driver.laps_practised() < 1:
				await process_frame
			solo.call("_restart")
			await process_frame
		var waited := 0
		while not driver.is_planned() and waited < 2000:
			await process_frame
			waited += 1
		lines.append(driver.line())
		_close(solo)
	print("restarted 3 times while the line was being worked out: line %s"
		% ["same" if lines[0] == lines[1] else "DIFFERENT"])
	if lines[0] != lines[1]:
		_fault("restarting during the countdown changed the bot's line")


## Two cars, either side of the middle of the road, each told about the other,
## each mended, and something settling what happens when they touch.
func _the_grid() -> void:
	var solo := await _open(ROAD)
	var car: Car = solo.get_node("Car")
	var bot: Car = solo.get("_bot")
	if bot == null:
		_fault("the bot road built no bot")
		_close(solo)
		return

	var contacts := 0
	for child in solo.get_children():
		if child is CarContact:
			contacts += 1
	var at: float = maxf(
		(solo.get_node("Track") as Track).start_offset() - float(solo.get("grid_setback")), 0.0)
	var middle := (solo.get_node("Track") as Track).centre_at(at)
	var apart := car.global_position.distance_to(bot.global_position)
	print("on the bot road: %.1f m apart, %.1f and %.1f m off the middle" % [
		apart, car.global_position.distance_to(middle),
		bot.global_position.distance_to(middle)])
	print("  bot paint %s, model %s, rivals %s, contacts %d, driver %s" % [
		bot.body_color, "stock" if bot.model_id == _garage.STOCK else bot.model_id,
		"both ways" if car.rival == bot and bot.rival == car else "wrong",
		contacts, "yes" if bot.driver is BotDriver else "no"])

	if not is_equal_approx(apart, float(solo.get("grid_spread")) * 2.0):
		_fault("the two cars are %.2f m apart, not %.2f"
			% [apart, float(solo.get("grid_spread")) * 2.0])
	# Read off the scene's script rather than named here, so this check does not
	# have to be compiled against a scene script that talks to the autoloads.
	var fixed: Color = (solo.get_script() as GDScript).get_script_constant_map()["BOT_COLOUR"]
	if not bot.body_color.is_equal_approx(fixed):
		_fault("the bot is not wearing the fixed colour")
	if bot.body_color.is_equal_approx(_settings.car_colour(1)):
		_fault("the bot is wearing player two's colour")
	if bot.model_id != _garage.STOCK:
		_fault("the bot is not in the stock car")
	if car.rival != bot or bot.rival != car:
		_fault("the rivals are not wired both ways, so the slipstream works for neither")
	if contacts != 1:
		_fault("%d CarContacts, wanted 1" % contacts)
	if not (bot.driver is BotDriver):
		_fault("the bot's car has no BotDriver")
	if bot.condition() < 1.0 or car.condition() < 1.0:
		_fault("a car came to the line already worn")
	if not _place(solo).visible:
		_fault("the place readout is hidden on a bot road")

	# One camera in this scene, so the arrow wants the world's own layer: none of
	# Main's per-player culling belongs here, and an arrow on a private layer
	# would be an arrow the one camera does not draw.
	var arrow := solo.get_node("Arrow") as RivalArrow
	print("  arrow: mesh %s, layers %d, colour %s" % [
		"built" if arrow.mesh != null else "none", arrow.layers,
		arrow.material_override.albedo_color if arrow.material_override != null else "none"])
	if arrow.mesh == null:
		_fault("the arrow was never set up")
	if arrow.layers != 1:
		_fault("the arrow is on layer mask %d, not the world's" % arrow.layers)
	_close(solo)


## Nobody driving the player's car, so the bot comes in first. The panel says so,
## says by how much, hangs no medal, and offers the two ways out of a door.
func _the_bot_wins() -> void:
	var solo := await _open(ROAD)
	await _race(solo, -1.0)
	print("the bot wins: %s / %s / %s, badge %s" % [
		_line(solo, "Time"), _line(solo, "Medal"), _line(solo, "Note"),
		"shown" if (solo.get_node("Hud/Result/Badge") as Control).visible else "hidden"])
	print("  buttons: %s and %s" % [
		(solo.get_node(
			"Hud/Result/Centre/Panel/Margin/Box/Choice/Row/Restart") as Button).text,
		(solo.get_node(
			"Hud/Result/Centre/Panel/Margin/Box/Choice/Row/Next") as Button).text])
	if solo.get("_running"):
		_fault("the race is still running after the bot crossed the line")
	if _line(solo, "Medal") != "THE BOT WINS":
		_fault("the bot won and the panel did not say so")
	if not _line(solo, "Note").ends_with(" m"):
		_fault("the panel does not say by how much")
	if (solo.get_node("Hud/Result/Badge") as Control).visible:
		_fault("a bot race hung a medal")
	if not (solo.get_node(
			"Hud/Result/Centre/Panel/Margin/Box/Choice") as Control).visible:
		_fault("the ways out of the race were not offered")
	if (solo.get_node(
			"Hud/Result/Centre/Panel/Margin/Box/Choice/Row/Next") as Button).disabled:
		_fault("the way back to the tracks is disabled")

	# A bot road is not a time trial. Nothing about it is kept.
	var kept: float = _times.best(ROAD) if _times != null else -1.0
	print("  written down: %s" % ("nothing" if kept < 0.0 else "%.2f s" % kept))
	if kept >= 0.0:
		_fault("a bot race wrote a time down")
	if float(solo.get("_best")) >= 0.0:
		_fault("a bot road read a best time back")
	_close(solo)


## The player's car driven properly against a bot turned down, which is the race
## the other way round.
func _the_player_wins() -> void:
	var solo := await _open(ROAD, 0.3)
	await _race(solo, 1.0)
	print("the player wins: %s / %s / %s" % [
		_line(solo, "Time"), _line(solo, "Medal"), _line(solo, "Note")])
	if _line(solo, "Medal") != "YOU WIN":
		_fault("the player got there first and the panel did not say so")
	if not _line(solo, "Note").ends_with(" m"):
		_fault("the panel does not say by how much")
	_close(solo)


## Damage on, and a car worn out. The other one wins without driving the rest of
## the road: there is nobody left to race. Both at once is a draw.
func _a_broken_car() -> void:
	_settings.damage = true
	for who in ["the bot", "the player", "both"]:
		var solo := await _open(ROAD)
		var car: Car = solo.get_node("Car")
		var bot: Car = solo.get("_bot")
		if who != "the player":
			bot._condition = 0.0
		if who != "the bot":
			car._condition = 0.0
		await physics_frame
		await physics_frame
		print("%s breaks: %s / %s" % [who, _line(solo, "Medal"), _line(solo, "Note")])
		if solo.get("_running"):
			_fault("a broken car did not end the race")
		if (solo.get_node("Hud/Result/Badge") as Control).visible:
			_fault("a broken car hung a medal")
		_close(solo)
	_settings.damage = false


## The bot asking to be put back goes down the same path the player's key does,
## and moves nothing but the bot.
func _putting_the_bot_back() -> void:
	var solo := await _open(ROAD)
	var track: Track = solo.get_node("Track")
	var car: Car = solo.get_node("Car")
	var bot: Car = solo.get("_bot")
	var driver: BotDriver = bot.driver
	solo.set("_bot_respawn", 400.0)
	var was := car.global_position
	# Somewhere it plainly is not, so being put back is something that happened.
	bot.global_position = track.centre_at(900.0) + Vector3.UP * 40.0
	solo.call("_back_to_checkpoint", bot)
	var landed := track.offset_of(bot.global_position)
	print("the bot is put back at %.0f m, asked for 400; the player moved %.2f m"
		% [landed, car.global_position.distance_to(was)])
	if absf(landed - 400.0) > 3.0:
		_fault("the bot was put back at %.0f m rather than its own checkpoint" % landed)
	if car.global_position.distance_to(was) > 0.01:
		_fault("putting the bot back moved the player's car")
	if absf(driver.progress()) > 0.01:
		_fault("the bot was not told it had been moved, so it still thinks it is at %.0f m"
			% driver.progress())
	_close(solo)


## The rule the place readout runs on, which is the two-player race's rule.
func _the_places() -> void:
	var level := 0.6
	var lead := 1.5
	var rows := [
		[0.0, -1, -1, "off the grid, nobody"],
		[1.0, -1, -1, "ahead but not by enough, still nobody"],
		[2.0, -1, 0, "clear of the margin, the player leads"],
		[1.0, 0, 0, "falling back inside it, the player still leads"],
		[0.3, 0, -1, "level again, nobody"],
		[-2.0, -1, 1, "the other way, the bot leads"],
	]
	for row: Array in rows:
		var got := Places.leader(float(row[0]), int(row[1]), level, lead)
		print("  %+.1f m with %s leading: %s - %s" % [
			row[0], _who(int(row[1])), _who(got), row[3]])
		if got != int(row[2]):
			_fault("a %+.1f m gap gave %s, wanted %s"
				% [row[0], _who(got), _who(int(row[2]))])


# --- driving it ----------------------------------------------------------

## Build the scene on a road, wait for it to settle, and hand it back.
func _open(file: String, difficulty := -1.0) -> Node:
	_settings.track_file = file
	var solo: Node = load("res://scenes/solo.tscn").instantiate()
	# Set before it enters the tree, because _ready is where the bot is built.
	if difficulty >= 0.0:
		solo.set("bot_difficulty", difficulty)
	root.add_child(solo)
	for i in 10:
		await physics_frame
	var waited := 0
	while not solo.get("_running") and waited < 600:
		await physics_frame
		waited += 1
	return solo


## Race until the panel goes up. `player` under zero leaves the player's car
## parked; otherwise it is driven at that difficulty.
func _race(solo: Node, player: float) -> void:
	var car: Car = solo.get_node("Car")
	var bot: Car = solo.get("_bot")
	var driving: BotDriver
	if player >= 0.0:
		driving = BotDriver.new(solo.get_node("Track"), car, player)
		# A check has a frame to spare; a race does not. See BotDriver.plan_a_little.
		driving.finish_planning()
		car.driver = driving
	for step in PATIENCE:
		if not solo.get("_running"):
			break
		if driving != null:
			driving.race_time = solo.get("_time")
		await physics_frame
		if driving != null and driving.wants_reset() and solo.get("_running"):
			solo.call("_back_to_checkpoint")
	if solo.get("_running"):
		_fault("neither car finished in %d steps" % PATIENCE)
	car.driver = null


func _close(solo: Node) -> void:
	solo.queue_free()
	await process_frame


func _place(solo: Node) -> Label:
	return solo.get_node("Hud/Corner/Box/Place") as Label


func _line(solo: Node, which: String) -> String:
	return (solo.get_node(
		"Hud/Result/Centre/Panel/Margin/Box/%s" % which) as Label).text


func _who(leader: int) -> String:
	if leader < 0:
		return "level"
	return "the player" if leader == 0 else "the bot"


func _wipe_the_times() -> void:
	if _times == null:
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_times.save_path))
	_times.load_times()


func _fault(what: String) -> void:
	print("  %s" % what)
	_faults += 1
