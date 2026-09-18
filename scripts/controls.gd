class_name Controls
extends RefCounted

## What a key is called on the keyboard in front of the player.
##
## Two screens need to say this and they must not disagree: the controls sheet
## lists every binding before a race, and the line that comes up when a car is
## off the road names one of them in the middle of it. Written out twice, the
## two would drift the first time anything moved - so it is written once, here,
## and read off the input map rather than typed anywhere.
##
## The bindings are physical, which is what keeps WASD a square on a keyboard
## that is not laid out like this one. That means the physical code has to be
## turned back into whatever this particular keyboard actually calls that key,
## which is why this cannot simply be a table.


## The key currently bound to an action, or an empty string when the action
## has nothing on it. Empty rather than a dash, so each caller can say "not
## bound" in its own words.
static func key_for(action: String) -> String:
	if not InputMap.has_action(action):
		return ""
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key == null:
			continue
		var code := key.keycode
		if key.physical_keycode != 0:
			code = _on_this_keyboard(key.physical_keycode)
		return OS.get_keycode_string(code)
	return ""


## Which key on this keyboard sits where a physical binding points.
##
## Only the display server knows how the keyboard in front of the player is
## laid out, so only it can answer - except on a headless run, where there is
## no keyboard and no display server to ask. Asking anyway is an error a check
## has to read past, so it is not asked, and the physical code names itself.
static func _on_this_keyboard(physical: int) -> int:
	if DisplayServer.get_name() == "headless":
		return physical
	return DisplayServer.keyboard_get_keycode_from_physical(physical)
