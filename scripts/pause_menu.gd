class_name PauseMenu
extends Control

## The pause screen, over a race that has been stopped where it stands.
##
## It lays over the race rather than replacing it, the same way the settings
## lie over the title screen: the course, the cars and the sky are all still
## there behind the panel, held still, so coming back is a matter of letting
## them go again rather than building anything.
##
## The whole tree is paused while this is up, and this node is the one part of
## it that carries on running - which is what `PROCESS_MODE_WHEN_PAUSED` on
## the root of the scene says. That has a second effect worth knowing about:
## while the game is running this node processes nothing at all, so it cannot
## see the key that opens it. The race scene watches for that key and calls
## `open()`; this screen only has to know how to close itself again.
##
## What it offers is the three things a player who has just stopped wants:
## carry on, start the thing over, or leave. The settings sit behind a fourth
## button because they are the reason people pause a game that is not theirs
## to lose - a volume that is too loud is a thing you fix in the middle of a
## race, not one you quit a race to go and fix.
##
## Nothing here decides what any of that means. Resuming, restarting and
## leaving are all announced as signals, because a restart is a different act
## in a race against someone than in a run against the clock, and this screen
## has no business knowing which of the two it is sitting on top of.

## Carry on with the race that is underneath.
signal resumed
## Start it again. What "again" is - the same road or the next one - belongs
## to whoever opened this.
signal restart_requested
## Leave, back to wherever the player came in from.
signal quit_requested

@onready var _page: Control = $Page
@onready var _where: Label = $Page/Panel/Margin/Box/Title/Where
@onready var _resume_button: Button = $Page/Panel/Margin/Box/Resume
@onready var _restart_button: Button = $Page/Panel/Margin/Box/Restart
@onready var _paint_button: Button = $Page/Panel/Margin/Box/Paint
@onready var _settings_button: Button = $Page/Panel/Margin/Box/Settings
@onready var _quit_button: Button = $Page/Panel/Margin/Box/Quit
@onready var _settings_screen: SettingsMenu = $SettingsScreen
@onready var _paint_screen: PaintMenu = $PaintScreen


func _ready() -> void:
	_resume_button.pressed.connect(close)
	_restart_button.pressed.connect(_on_restart_pressed)
	_paint_button.pressed.connect(_on_paint_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_settings_screen.closed.connect(_on_settings_closed)
	_paint_screen.closed.connect(_on_paint_closed)
	hide()


## Stop the game and put this over it.
##
## `where` is the line under the heading: which track, or which mode, so a
## player who walked away mid-race and came back knows what they walked away
## from. `restart_text` is what the second button says, because starting over
## means one thing on a road you are learning and another on an endless one
## that is different every time it is rolled.
##
## `quit_text` names where leaving goes, for the same reason: a player who
## came in through the track grid is going back to the track grid, and a
## button that says so is one they do not have to press to find out.
func open(where: String, restart_text: String, quit_text := "QUIT TO MENU") -> void:
	_where.text = where
	_where.visible = not where.is_empty()
	_restart_button.text = restart_text
	_quit_button.text = quit_text
	# Always opens on the pause page itself, however it was left last time.
	_settings_screen.hide()
	_paint_screen.hide()
	# Chaos repaints both cars for every race, so a paint chosen under it
	# would be gone by the next course. The button stays where it is and says
	# why rather than disappearing: a row that changes shape between modes is
	# one a player has to read every time instead of pressing.
	_paint_button.disabled = GameSettings.chaos
	_paint_button.tooltip_text = ("Chaos repaints the cars for every race."
			if GameSettings.chaos else "")
	_page.show()
	show()
	# The tree is stopped last, so nothing above has to think about being laid
	# out while it is paused.
	get_tree().paused = true
	# Both players share one keyboard and neither has been asked to find the
	# mouse, so something on the page always holds focus.
	_resume_button.grab_focus()


## Get out of the way and let the tree run again. Every way off this screen
## goes through here, including leaving: the scene about to replace this one
## would come up stopped if it did not.
func _step_aside() -> void:
	hide()
	get_tree().paused = false


## Carry on with the race underneath.
func close() -> void:
	_step_aside()
	resumed.emit()


## Escape backs out one step: off the settings, or off the pause screen. The
## settings sheet handles its own key and lies over this, so it gets first
## refusal - this only sees the ones it did not want.
func _input(event: InputEvent) -> void:
	if not visible or _settings_screen.visible or _paint_screen.visible:
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	close()


func _on_restart_pressed() -> void:
	_step_aside()
	restart_requested.emit()


## Whoever handles this does the leaving, so this screen stays ignorant of
## where "back" is - which is the only reason the same panel can sit over a
## race and over a run against the clock.
func _on_quit_pressed() -> void:
	_step_aside()
	quit_requested.emit()


## The paint screen shows one column of swatches per car, so it has to be
## told how many cars there are - which is the same question the title screen
## asked on the way in.
func _on_paint_pressed() -> void:
	_paint_screen.open(1 if GameSettings.solo else 2)


func _on_paint_closed() -> void:
	_paint_button.grab_focus()


## The settings lie over the pause screen the same way the pause screen lies
## over the race - the panel behind stays where it is, so backing out of them
## is coming back to a page that never went anywhere.
func _on_settings_pressed() -> void:
	_settings_screen.open()


func _on_settings_closed() -> void:
	# Coming back to a page with nothing focused would leave the keyboard
	# dead, so the button that opened the settings takes focus again.
	_settings_button.grab_focus()
