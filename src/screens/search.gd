extends Screen
## Live search across titles, text, notes, models and #tags; the best match
## first, results appearing as you type.

var _field: LineEdit
var _results: VBoxContainer
var _query := ""


func build() -> void:
	if args.has("query"):
		_query = str(args.query)
		args.erase("query")
	body.add_child(_title())
	_field = UI.search_field("Search titles, text, notes and #tags", _query)
	_field.clear_button_enabled = true
	_field.right_icon = null
	_field.text_changed.connect(func(t: String):
		_query = t
		_fill())
	body.add_child(_field)
	_results = UI.vbox(12)
	body.add_child(_results)
	_fill()
	if args.get("focus", false):
		args.erase("focus")
		_field.grab_focus.call_deferred()


func _title() -> Control:
	var v := UI.vbox(2)
	v.add_child(UI.label("FIND ANYTHING", 12, UI.ACCENT_2, 800))
	v.add_child(UI.label("Search", 34, UI.INK, 800))
	return v


func _fill() -> void:
	for c in _results.get_children():
		c.queue_free()
	var q := _query.strip_edges()
	if q == "":
		var tags := Store.all_tags()
		if not tags.is_empty():
			_results.add_child(UI.section("Popular tags"))
			var flow := HFlowContainer.new()
			flow.add_theme_constant_override("h_separation", 8)
			flow.add_theme_constant_override("v_separation", 8)
			for t in tags.slice(0, 18):
				flow.add_child(UI.chip("#" + t, false, UI.ACCENT_2, func(): _set_query(t)))
			_results.add_child(flow)
		_results.add_child(UI.section("Models"))
		var mflow := HFlowContainer.new()
		mflow.add_theme_constant_override("h_separation", 8)
		mflow.add_theme_constant_override("v_separation", 8)
		var seen := {}
		for p in Store.prompts:
			seen[p.model] = true
		for m in Store.MODELS:
			if seen.has(m) and m != "Any":
				mflow.add_child(UI.chip(m, false, UI.ACCENT, func(): _set_query(m)))
		if mflow.get_child_count() > 0:
			_results.add_child(mflow)
		else:
			_results.get_child(_results.get_child_count() - 1).queue_free()
		# pick up where you left off
		var rec := Store.recent(3)
		if not rec.is_empty():
			_results.add_child(UI.spacer(4))
			_results.add_child(UI.section("Jump back in"))
			_results.add_child(cards(rec))
		return
	var hits := Store.search(q)
	_results.add_child(UI.label("%s for “%s”" % [UI.plural(hits.size(), "result"), q], 13, UI.FAINT, 700))
	if hits.is_empty():
		_results.add_child(W.empty("search", "No exhibits found", "Nothing in the museum mentions that yet.", "Save it as a new prompt", func(): app.edit_prompt()))
		return
	var wall := cards(hits.slice(0, 60))
	_results.add_child(wall)
	var n := 0
	for card in wall.get_children():
		Fx.rise(card, mini(n, 8) * 0.03, 0.3)
		n += 1


func _set_query(q: String) -> void:
	_query = q
	_field.text = q
	_field.caret_column = q.length()
	_fill()


func shown_again() -> void:
	_fill()
