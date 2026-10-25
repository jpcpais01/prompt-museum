extends Screen
## An exhibit: the prompt in full with its blanks lit, its wing, model, tags
## and notes, and a big Copy that fills the blanks first when it has any.

var _id := ""
var _star: Button


func build() -> void:
	live = true
	_id = args.get("id", "")
	var p := Store.get_prompt(_id)
	if p.is_empty():
		top_bar("Prompt")
		body.add_child(W.empty("library", "This prompt is gone", "It may have been deleted."))
		return
	var wing := Store.get_collection(p.collection)
	var col := Color(wing.color) if not wing.is_empty() else UI.ACCENT
	_star = UI.icon_button("star_on" if p.favorite else "star", _toggle_star, 46.0, UI.GOLD if p.favorite else UI.INK)
	top_bar("", [
		_star,
		UI.icon_button("edit", func(): app.edit_prompt(_id), 46.0),
		UI.icon_button("more", _more, 46.0),
	])

	# where it hangs
	var crumb := UI.hbox(8)
	if not wing.is_empty():
		var w := UI.chip(wing.name, true, col, func(): app.open_collection(wing.id))
		crumb.add_child(w)
	else:
		crumb.add_child(UI.pill("Unfiled"))
	if p.model != "Any":
		crumb.add_child(UI.pill(p.model, UI.INK, Color(col, 0.18)))
	body.add_child(crumb)

	var title := UI.wrap(p.title if p.title != "" else "Untitled prompt", 30, UI.INK, 800)
	body.add_child(title)
	var facts := "Used %s  ·  edited %s" % [UI.plural(p.uses, "time"), UI.ago(p.updated).to_lower()]
	if p.last_used > 0:
		facts += "  ·  last used %s" % UI.ago(p.last_used).to_lower()
	body.add_child(UI.wrap(facts, 13, UI.FAINT, 700))

	# the text itself, on a lit plinth
	var plinth := PanelContainer.new()
	var psb := UI.card_box(20, Color(0.075, 0.08, 0.125, 0.92))
	psb.border_color = Color(col, 0.35)
	plinth.add_theme_stylebox_override("panel", psb)
	var pv := UI.vbox(12)
	plinth.add_child(pv)
	var ph := UI.hbox(8)
	var pl := UI.label("PROMPT", 12, Color(col.lightened(0.3), 0.9), 800)
	pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ph.add_child(pl)
	ph.add_child(UI.label(UI.plural(p.body.split(" ", false).size(), "word"), 12, UI.FAINT, 700))
	pv.add_child(ph)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.selection_enabled = OS.get_name() != "Android"
	text.context_menu_enabled = true
	text.mouse_filter = Control.MOUSE_FILTER_PASS
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_override("normal_font", UI.font(500))
	text.add_theme_font_override("bold_font", UI.font(800))
	text.add_theme_font_size_override("normal_font_size", 17)
	text.add_theme_font_size_override("bold_font_size", 16)
	text.add_theme_color_override("default_color", Color(0.93, 0.94, 0.99))
	text.add_theme_constant_override("line_separation", 6)
	text.text = W.highlight(p.body)
	pv.add_child(text)
	body.add_child(plinth)

	var vars := Store.variables(p.body)
	if not vars.is_empty():
		var vh := UI.hbox(8)
		var vi := Icon.make("variable", UI.ACCENT_2, 18)
		vi.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		vh.add_child(vi)
		vh.add_child(UI.wrap("%s to fill in when you copy it" % UI.plural(vars.size(), "blank"), 14, UI.SOFT, 600))
		body.add_child(vh)

	if not p.tags.is_empty():
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		for t in p.tags:
			flow.add_child(UI.chip("#" + t, false, UI.ACCENT_2, func(): app.go_tab("search", true, {"query": t})))
		body.add_child(flow)

	if p.notes.strip_edges() != "":
		var notes := UI.panel(18)
		var nv := UI.vbox(8)
		nv.add_child(UI.label("CURATOR'S NOTES", 12, UI.GOLD, 800))
		nv.add_child(UI.wrap(p.notes, 15, UI.SOFT, 500))
		notes.add_child(nv)
		body.add_child(notes)

	# the fixed action bar
	var bar := UI.hbox(10)
	if not vars.is_empty():
		var raw := UI.icon_button("copy", func(): app.copy_prompt(_id, true), 52.0)
		bar.add_child(raw)
		var fill := UI.primary("Fill blanks & copy", func(): app.copy_prompt(_id))
		fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.add_child(fill)
	else:
		var cp := UI.primary("Copy prompt", func(): app.copy_prompt(_id))
		cp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.add_child(cp)
	footer(bar)


func _toggle_star() -> void:
	var on := Store.toggle_favorite(_id)
	Fx.haptic()
	app.toast("Added to favourites" if on else "Removed from favourites", "star_on" if on else "star")


func _more() -> void:
	var v := UI.vbox(10)
	var dup := UI.secondary("Duplicate", func():
		app.close_sheet()
		var c := Store.duplicate_prompt(_id)
		if not c.is_empty():
			app.toast("Duplicated")
			app.edit_prompt(c.id))
	v.add_child(dup)
	var raw := UI.secondary("Copy without filling blanks", func():
		app.close_sheet()
		app.copy_prompt(_id, true))
	v.add_child(raw)
	var del := UI.danger("Delete prompt", func():
		app.close_sheet()
		var gone := Store.delete_prompt(_id)
		app.pop()
		app.toast("Prompt deleted", "trash", "Undo", func(): Store.restore_prompt(gone)))
	v.add_child(del)
	app.sheet("Prompt", v)
