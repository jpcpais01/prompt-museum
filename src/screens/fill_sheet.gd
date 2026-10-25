extends VBoxContainer
## Filling a prompt's blanks before copying: one field per {{blank}}, a live
## preview with the answers lit in, and your last answers remembered.

var app: App
var prompt_id := ""

var _fields := {}
var _preview: RichTextLabel
var _body := ""


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var p := Store.get_prompt(prompt_id)
	_body = p.get("body", "")
	var remembered: Dictionary = Store.settings.get("fills", {}).get(prompt_id, {})
	var first: Control = null
	for v in Store.variables(_body):
		add_child(UI.caption(v, "variable", UI.ACCENT_2))
		var long := _is_long(v)
		var f: Control
		if long:
			var te := UI.text_edit("Paste or type %s" % v, str(remembered.get(v, "")), 110)
			te.text_changed.connect(_update)
			f = te
		else:
			var le := UI.line_edit("Type %s" % v, str(remembered.get(v, "")))
			le.text_changed.connect(func(_t): _update())
			f = le
		_fields[v] = f
		add_child(f)
		if first == null:
			first = f
	add_child(UI.spacer(2))
	add_child(UI.caption("Preview", "search"))
	var box := UI.panel(16, Color(0.06, 0.065, 0.1, 0.9))
	_preview = RichTextLabel.new()
	_preview.bbcode_enabled = true
	_preview.fit_content = true
	_preview.scroll_active = false
	_preview.mouse_filter = Control.MOUSE_FILTER_PASS
	_preview.add_theme_font_override("normal_font", UI.font(500))
	_preview.add_theme_font_override("bold_font", UI.font(800))
	_preview.add_theme_font_size_override("normal_font_size", 15)
	_preview.add_theme_font_size_override("bold_font_size", 15)
	_preview.add_theme_color_override("default_color", UI.SOFT)
	box.add_child(_preview)
	add_child(box)
	add_child(UI.primary("Copy filled prompt", _copy))
	_update()
	if first and OS.get_name() != "Android":
		first.grab_focus.call_deferred()


func _is_long(v: String) -> bool:
	var l := v.to_lower()
	for k in ["text", "code", "content", "error", "paste", "article", "notes", "context", "plan", "draft"]:
		if l.contains(k):
			return true
	return false


func _values() -> Dictionary:
	var out := {}
	for k in _fields:
		out[k] = _fields[k].text
	return out


func _update() -> void:
	_preview.text = W.highlight(_body, _values())


func _copy() -> void:
	var vals := _values()
	var fills: Dictionary = Store.settings.get("fills", {})
	fills[prompt_id] = vals
	Store.settings.fills = fills
	app.close_sheet()
	app.copy_text(Store.fill(_body, vals), "Filled & copied")
	Store.mark_used(prompt_id)
