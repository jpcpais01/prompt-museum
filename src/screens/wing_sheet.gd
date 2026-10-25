extends VBoxContainer
## Creating or editing a wing: its name, colour and glyph, previewed live as
## the painting it will hang as.

var app: App
var id := ""
var on_saved: Callable

var _name: LineEdit
var _color := ""
var _glyph := ""
var _preview: Control
var _swatches: HFlowContainer
var _glyphs: HFlowContainer
var _preview_holder: CenterContainer


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	var c := Store.get_collection(id)
	_color = c.get("color", Store.PALETTE[Store.collections.size() % Store.PALETTE.size()])
	_glyph = c.get("glyph", Store.GLYPHS[Store.collections.size() % Store.GLYPHS.size()])
	_preview_holder = CenterContainer.new()
	add_child(_preview_holder)
	add_child(UI.label("NAME", 12, UI.SOFT, 800))
	_name = UI.line_edit("e.g. Marketing, Midjourney, Study", c.get("name", ""))
	_name.text_changed.connect(func(_t): _draw_preview())
	_name.text_submitted.connect(func(_t): _save())
	add_child(_name)
	add_child(UI.label("COLOUR", 12, UI.SOFT, 800))
	_swatches = HFlowContainer.new()
	_swatches.add_theme_constant_override("h_separation", 10)
	_swatches.add_theme_constant_override("v_separation", 10)
	add_child(_swatches)
	add_child(UI.label("GLYPH", 12, UI.SOFT, 800))
	_glyphs = HFlowContainer.new()
	_glyphs.add_theme_constant_override("h_separation", 8)
	_glyphs.add_theme_constant_override("v_separation", 8)
	add_child(_glyphs)
	add_child(UI.spacer(2))
	add_child(UI.primary("Create wing" if c.is_empty() else "Save wing", _save))
	if not c.is_empty():
		add_child(UI.danger("Delete wing", _delete))
	_draw_swatches()
	_draw_glyphs()
	_draw_preview()
	if c.is_empty():
		_name.grab_focus.call_deferred()


func _draw_preview() -> void:
	for ch in _preview_holder.get_children():
		ch.queue_free()
	var fake := {"id": id if id != "" else "preview", "name": _name.text if _name.text.strip_edges() != "" else "New wing", "color": _color, "glyph": _glyph}
	_preview = W.collection_tile(fake, app, 170, 150)
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_holder.add_child(_preview)
	_preview.get_meta("lift").call_deferred(true)


func _draw_swatches() -> void:
	for ch in _swatches.get_children():
		ch.queue_free()
	for hex in Store.PALETTE:
		var b := Button.new()
		b.custom_minimum_size = Vector2(40, 40)
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		var on: bool = hex == _color
		for s in ["normal", "hover", "pressed", "focus"]:
			var sb := UI.box(Color(hex), 999, Color.WHITE if on else Color(1, 1, 1, 0.15))
			if on:
				sb.set_border_width_all(3)
			b.add_theme_stylebox_override(s, sb)
		b.pressed.connect(UI.guard(func():
			_color = hex
			Fx.haptic(8)
			_draw_swatches()
			_draw_preview()))
		Fx.press_feedback(b, 0.9)
		_swatches.add_child(b)


func _draw_glyphs() -> void:
	for ch in _glyphs.get_children():
		ch.queue_free()
	for g in Store.GLYPHS:
		var on: bool = g == _glyph
		var b := UI.icon_button(g, func():
			_glyph = g
			Fx.haptic(8)
			_draw_glyphs()
			_draw_preview(), 46.0, UI.INK if on else UI.SOFT, Color(Color(_color), 0.3) if on else Color(1, 1, 1, 0.05))
		_glyphs.add_child(b)


func _save() -> void:
	var n := _name.text.strip_edges()
	if n == "":
		Fx.pop(_name, 1.03)
		_name.grab_focus()
		return
	var saved := Store.put_collection({"id": id if id != "" else Store.new_id(), "name": n, "color": _color, "glyph": _glyph})
	app.close_sheet()
	Fx.haptic(16)
	app.toast("Wing saved" if id != "" else "New wing opened", "check")
	if on_saved.is_valid():
		on_saved.call(saved.id)


func _delete() -> void:
	var c := Store.get_collection(id)
	var n := Store.count_in(id)
	# the confirm dialog replaces (and frees) this sheet, so the "yes" must
	# live on the app, not on a lambda bound to this node
	app.confirm("Delete %s?" % c.name, "The wing comes down, but its %s stay in the museum, unfiled." % UI.plural(n, "prompt"), "Delete wing", app.delete_wing.bind(id))
