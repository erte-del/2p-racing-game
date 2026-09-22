class_name SharpView
extends TextureRect

## One half of the split screen, drawn at the resolution of the display.
##
## The interface is laid out in a fixed 1280x720 space and Godot scales that
## up to fill whatever window the game is in, so a button covers the same
## share of the screen on every machine. A SubViewport takes its size from
## whatever holds it, and that is measured in the laid-out space - so a
## SubViewportContainer would have each half of the race rendered at 1280x358
## and blown up soft on any screen bigger than the one it was designed for.
##
## Hence a texture rather than a container. The viewport is given the size its
## half of the screen really covers in the display's own pixels, and told to
## go on addressing itself in the laid-out size. The road is drawn at the full
## resolution of the screen; the speed lines over it still measure the frame
## the way the layout does, so they come out the same weight everywhere.


func _ready() -> void:
	# The texture is whatever the viewport last drew, stretched over this
	# half of the screen however many pixels that turns out to be.
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var view := _view()
	if view != null:
		texture = view.get_texture()
	resized.connect(_fit)
	get_window().size_changed.connect(_fit)
	_fit()


func _view() -> SubViewport:
	for child in get_children():
		var view := child as SubViewport
		if view != null:
			return view
	return null


## Match the viewport to the screen. Called again whenever either the layout
## or the window changes, since the two can move independently: a window can
## grow without the split being laid out any differently.
func _fit() -> void:
	var view := _view()
	if view == null or size.x < 1.0 or size.y < 1.0:
		return
	var window := get_window()
	var laid_out := window.get_visible_rect().size
	if laid_out.x < 1.0:
		return
	# One number does for both directions: the stretch is uniform.
	var scale := float(window.size.x) / laid_out.x
	var in_pixels := Vector2i((size * scale).round())
	var in_layout := Vector2i(size.round())
	if view.size == in_pixels and view.size_2d_override == in_layout:
		return
	view.size_2d_override_stretch = true
	view.size_2d_override = in_layout
	view.size = in_pixels
