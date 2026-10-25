extends Screen
## Writing or editing a prompt: title, the text (with live detection of
## {{blanks}}), its wing, the model it's for, tags and notes.

var _id := ""
var _title: LineEdit
var _body: TextEdit
var _notes: TextEdit
var _tag_field: LineEdit
var _vars_row: HFlowContainer
var _vars_hint: Label
var _wing_row: HBoxContainer
var _model_row: HFlowContainer
var _tag_row: HFlowContainer
var _collection := ""
var _model := "Any"
var _tags: Array = []
var _favorite := false
var _start := ""


func build() -> void:
	_id = args.get("id", "")
	var p := Store.get_prompt(_id)
	var is_new := p.is_empty()
	if is_new:
		_collection = args.get("collection", "")
	else:
		_collection = p.collection
		_model = p.model
		_tags = p.tags.duplicate()
		_favorite = p.favorite
	var save := UI.chip("Save", true, UI.ACCENT, _save)
	save.custom_minimum_size = Vector2(84, 42)
	top_bar("New prompt" if is_new else "Edit prompt", [save])

	body.add_child(_caption("Title"))
	_title = UI.line_edit("Give it a name you'll recognise", p.get("title", ""))
	_title.add_theme_font_override("font", UI.font(700))
	_title.add_theme_font_size_override("font_size", 18)
	body.add_child(_title)

	var ph := UI.hbox(8)
	var cap := _caption("Prompt")
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ph.add_child(cap)
	ph.add_child(UI.chip("{ } Add blank", false, UI.ACCENT_2, _insert_blank))
	body.add_child(ph)
	_body = UI.text_edit("Write the prompt. Wrap words in {{double braces}} to make blanks you fill in each time you use it.", p.get("body", ""), 260)
	_body.text_changed.connect(_scan_vars)
	body.add_child(_body)
	_vars_hint = UI.wrap("", 13, UI.FAINT, 600)
	body.add_child(_vars_hint)
	_vars_row = HFlowContainer.new()
	_vars_row.add_theme_constant_override("h_separation", 6)
	_vars_row.add_theme_constant_override("v_separation", 6)
	body.add_child(_vars_row)

	body.add_child(_caption("Wing"))
	var ws := UI.hscroll()
	_wing_row = UI.hbox(8)
	ws.add_child(_wing_row)
	body.add_child(ws)

	body.add_child(_caption("Made for"))
	_model_row = HFlowContainer.new()
	_model_row.add_theme_constant_override("h_separation", 8)
	_model_row.add_theme_constant_override("v_separation", 8)
	body.add_child(_model_row)

	body.add_child(_caption("Tags"))
	_tag_field = UI.line_edit("Type a tag and press Enter")
	_tag_field.text_submitted.connect(_add_tag)
	_tag_field.text_changed.connect(func(t: String):
		if t.ends_with(",") or t.ends_with(" "):
			_add_tag(t))
	body.add_child(_tag_field)
	_tag_row = HFlowContainer.new()
	_tag_row.add_theme_constant_override("h_separation", 8)
	_tag_row.add_theme_constant_override("v_separation", 8)
	body.add_child(_tag_row)

	body.add_child(_caption("Curator's notes"))
	_notes = UI.text_edit("Where it works best, what to tweak, results you got…", p.get("notes", ""), 120)
	body.add_child(_notes)

	var go := UI.primary("Save to the museum" if is_new else "Save changes", _save)
	body.add_child(UI.spacer(4))
	body.add_child(go)
	if not is_new:
		body.add_child(UI.danger("Delete prompt", _delete))

	_draw_wings()
	_draw_models()
	_draw_tags()
	_scan_vars()
	_start = _snapshot()
	if is_new:
		_title.grab_focus.call_deferred()


func _caption(t: String) -> Label:
	return UI.label(t.to_upper(), 12, UI.SOFT, 800)


func _snapshot() -> String:
	return JSON.stringify([_title.text, _body.text, _notes.text, _collection, _model, _tags])


func on_back() -> bool:
	if _snapshot() == _start:
		return false
	app.confirm("Discard changes?", "You have edits that haven't been saved.", "Discard", func():
		_start = _snapshot()
		app.pop())
	return true


func _draw_wings() -> void:
	for c in _wing_row.get_children():
		c.queue_free()
	_wing_row.add_child(UI.chip("Unfiled", _collection == "", UI.SOFT, _pick_wing.bind("")))
	for c in Store.collections:
		_wing_row.add_child(UI.chip(c.name, _collection == c.id, Color(c.color), _pick_wing.bind(c.id)))
	_wing_row.add_child(UI.chip("+ New wing", false, UI.ACCENT, func():
		app.edit_collection("", func(id: String):
			_collection = id
			_draw_wings())))


func _pick_wing(id: String) -> void:
	_collection = id
	Fx.haptic(8)
	_draw_wings()


func _draw_models() -> void:
	for c in _model_row.get_children():
		c.queue_free()
	for m in Store.MODELS:
		_model_row.add_child(UI.chip(m, _model == m, UI.ACCENT, func():
			_model = m
			Fx.haptic(8)
			_draw_models()))


func _add_tag(t: String) -> void:
	for part in t.replace("#", "").split(",", false):
		var s := part.strip_edges().to_lower()
		if s != "" and not _tags.has(s):
			_tags.append(s)
	_tag_field.text = ""
	_draw_tags()


func _draw_tags() -> void:
	for c in _tag_row.get_children():
		c.queue_free()
	for t in _tags:
		_tag_row.add_child(UI.chip("#%s  ×" % t, true, UI.ACCENT_2, func():
			_tags.erase(t)
			_draw_tags()))
	# suggest tags already used elsewhere
	var shown := 0
	for t in Store.all_tags():
		if shown >= 6:
			break
		if not _tags.has(t):
			_tag_row.add_child(UI.chip("+ " + t, false, UI.ACCENT_2, func():
				_tags.append(t)
				_draw_tags()))
			shown += 1


func _scan_vars() -> void:
	for c in _vars_row.get_children():
		c.queue_free()
	var vars := Store.variables(_body.text)
	if vars.is_empty():
		_vars_hint.text = "Tip: {{topic}} becomes a blank you fill in when you copy."
		return
	_vars_hint.text = "%s detected" % UI.plural(vars.size(), "blank")
	for v in vars:
		_vars_row.add_child(UI.pill("{{%s}}" % v, UI.ACCENT_2, Color(UI.ACCENT_2, 0.12)))


func _insert_blank() -> void:
	_body.grab_focus()
	_body.insert_text_at_caret("{{name}}")
	# select "name" so typing replaces it
	var line := _body.get_caret_line()
	var col := _body.get_caret_column()
	_body.select(line, col - 6, line, col - 2)
	_scan_vars()


func _save() -> void:
	if _tag_field.text.strip_edges() != "":
		_add_tag(_tag_field.text)
	var body_text := _body.text.strip_edges()
	if body_text == "":
		app.toast("Write the prompt first", "info")
		Fx.pop(_body, 1.02)
		_body.grab_focus()
		return
	var title := _title.text.strip_edges()
	if title == "":
		title = W.preview(body_text, 40)
	var p := Store.get_prompt(_id).duplicate(true)
	p.merge({"id": _id if _id != "" else Store.new_id(), "title": title, "body": body_text, "collection": _collection,
		"tags": _tags, "model": _model, "notes": _notes.text.strip_edges(), "favorite": _favorite}, true)
	var saved := Store.put_prompt(p)
	Fx.haptic(16)
	_start = _snapshot()
	var was_new := _id == ""
	app.pop()
	if was_new:
		app.open_prompt(saved.id)
		app.toast("Saved to the museum", "check")
	else:
		app.toast("Changes saved", "check")


func _delete() -> void:
	app.confirm("Delete this prompt?", "It leaves the museum for good (you can undo right after).", "Delete", func():
		var gone := Store.delete_prompt(_id)
		_start = _snapshot()
		app.pop_to_root()
		app.toast("Prompt deleted", "trash", "Undo", func(): Store.restore_prompt(gone)))
