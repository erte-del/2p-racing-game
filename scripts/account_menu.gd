class_name AccountMenu
extends Control

## Making an account, signing into one, and getting back out.
##
## It lays over whatever opened it, the same as the settings screen, so the
## title screen carries on turning behind it.
##
## The page is built here rather than written down in the scene because it is
## two pages wearing the same frame - signing in and signing up differ by one
## field and one button - and a scene holding both would be two of everything
## with half of it hidden at any moment.
##
## Nothing on this screen is required to play the game. A player who never
## opens it drives every track, keeps every time and sees every medal; what an
## account adds is that their times survive the machine they were set on, and
## that they appear on the boards next to everyone else's.

## Emitted when the screen closes, so whoever opened it can take focus back.
signal closed

const DIM := Color(0, 0, 0, 0.62)
const QUIET := Color(0.78, 0.83, 0.93)
const WRONG := Color(0.98, 0.55, 0.5)
const RIGHT := Color(0.6, 0.9, 0.68)

var _heading: Label
var _email: LineEdit
var _password: LineEdit
var _name: LineEdit
var _email_row: Control
var _password_row: Control
var _name_row: Control
var _go: Button
var _swap: Button
var _sign_out: Button
var _status: Label
var _close: Button

## Whether the page is currently asking for a new account rather than an old
## one. Signing in is the default because after the first time it is what
## every player is here to do.
var _making := false
## True while a request is out, so the page cannot be sent twice by a player
## pressing the button again when nothing appears to have happened.
var _busy := false


func _ready() -> void:
	_build()
	Backend.signed_in.connect(_show_who)
	Backend.signed_out.connect(_show_who)
	hide()


## Show the screen, on whichever of its two faces fits where the player is.
func open() -> void:
	_status.text = ""
	_password.text = ""
	show()
	_show_who()


func close() -> void:
	hide()
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	close()


## Put the page together once. What changes afterwards is what is shown, not
## what exists.
func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = DIM
	add_child(dim)

	var page := CenterContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(page)

	var panel := PanelContainer.new()
	page.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size.x = 460.0
	margin.add_child(box)

	_heading = Label.new()
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_heading.add_theme_font_size_override("font_size", 40)
	box.add_child(_heading)

	_email = _field(box, "EMAIL")
	_email_row = _email.get_parent() as Control
	_password = _field(box, "PASSWORD")
	_password_row = _password.get_parent() as Control
	# The one field on the screen nobody else in the room should be able to
	# read over a shoulder - and both players are sitting at this keyboard.
	_password.secret = true

	_name = _field(box, "NAME ON THE BOARDS")
	_name.max_length = 16
	# The whole row goes, label and all, rather than the field alone: a
	# caption floating over nothing reads as something that failed to load.
	_name_row = _name.get_parent() as Control

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.y = 46.0
	_status.add_theme_font_size_override("font_size", 20)
	box.add_child(_status)

	_go = Button.new()
	_go.pressed.connect(_on_go)
	box.add_child(_go)

	_swap = Button.new()
	_swap.add_theme_font_size_override("font_size", 22)
	_swap.pressed.connect(_on_swap)
	box.add_child(_swap)

	_sign_out = Button.new()
	_sign_out.text = "SIGN OUT"
	_sign_out.pressed.connect(_on_sign_out)
	box.add_child(_sign_out)

	_close = Button.new()
	_close.text = "CLOSE"
	_close.add_theme_font_size_override("font_size", 22)
	_close.pressed.connect(close)
	box.add_child(_close)


## One captioned box to type in.
func _field(box: VBoxContainer, caption: String) -> LineEdit:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	box.add_child(row)

	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", QUIET)
	row.add_child(label)

	var edit := LineEdit.new()
	edit.custom_minimum_size.y = 44.0
	# Enter sends the page from whichever box the player is in, so the whole
	# thing can be filled in without reaching for the mouse.
	edit.text_submitted.connect(func(_text: String) -> void: _on_go())
	row.add_child(edit)
	# The row is what gets hidden, so the caller is handed the field and can
	# find the row from it.
	return edit


## Show the page as it stands: who is signed in, or the way to be.
func _show_who() -> void:
	if not visible:
		return
	var here := Backend.is_signed_in()
	_email_row.visible = not here
	_password_row.visible = not here
	_name_row.visible = not here and _making
	_go.visible = not here
	_swap.visible = not here
	_sign_out.visible = here

	if here:
		var who := Backend.signed_in_as()
		_heading.text = who.to_upper() if not who.is_empty() else "SIGNED IN"
		_say("Your times are backed up and on the boards.", RIGHT)
		_sign_out.grab_focus()
		return

	if not Backend.configured():
		# Nothing on this page can do anything, so nothing on it is shown but
		# the reason why. Boxes to type an email into that lead nowhere are
		# worse than no boxes at all.
		_heading.text = "ACCOUNT"
		_email_row.visible = false
		_password_row.visible = false
		_go.visible = false
		_swap.visible = false
		_say("This copy of the game has no server set up, so there are no "
			+ "accounts and no boards. Everything else works as it always "
			+ "did.", QUIET)
		_close.grab_focus()
		return

	_heading.text = "NEW ACCOUNT" if _making else "SIGN IN"
	_go.text = "CREATE ACCOUNT" if _making else "SIGN IN"
	_swap.text = ("I already have an account" if _making
		else "Make an account")
	_email.grab_focus()


func _on_swap() -> void:
	_making = not _making
	_status.text = ""
	_show_who()


func _on_go() -> void:
	if _busy or Backend.is_signed_in() or not Backend.configured():
		return

	var email := _email.text.strip_edges()
	var password := _password.text
	var name := _name.text.strip_edges()

	# Checked here only so the obvious mistakes come back instantly instead of
	# after a round trip. What actually decides whether any of this is
	# acceptable is the server; this is politeness, not validation.
	if email.is_empty() or not email.contains("@"):
		_say("That does not look like an email address.", WRONG)
		return
	if password.length() < 6:
		_say("Passwords need at least six characters.", WRONG)
		return
	if _making and name.length() < 2:
		_say("Pick a name for the boards, two characters or more.", WRONG)
		return

	_busy = true
	_go.disabled = true
	_say("Talking to the server…", QUIET)

	var answer: Dictionary = {}
	if _making:
		answer = await Backend.sign_up(email, password, name)
	else:
		answer = await Backend.sign_in(email, password)

	_busy = false
	_go.disabled = false
	# Not kept a moment longer than the request that needed it.
	_password.text = ""

	if not answer.ok:
		_say(str(answer.error), WRONG)
		return
	_show_who()


func _on_sign_out() -> void:
	Backend.sign_out()
	_making = false
	_show_who()
	_say("Signed out. Your times are still here, and still up there.", QUIET)


func _say(what: String, colour: Color) -> void:
	_status.text = what
	_status.add_theme_color_override("font_color", colour)
