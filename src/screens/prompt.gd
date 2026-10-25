extends Screen
## An exhibit: the prompt in full with its blanks lit, its wing, model, tags
## and notes, and a big Copy that fills the blanks first when it has any.

var _id := ""
var _star: Button


## one readable column on every window size
func reading() -> bool:
	return true


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

	var main := body
	var side := body
	var wide := app.desktop()

	# where it hangs
	var crumb := UI.hbox(8)
	if not wing.is_empty():
		var w := UI.chip(wing.name, true, col, func(): app.open_collection(wing.id))
		crumb.add_child(w)
	else:
		crumb.add_child(UI.pill("Unfiled"))
	if p.model != "Any":
		crumb.add_child(UI.pill(p.model, UI.INK, Color(col, 0.18)))
	main.add_child(crumb)

	var title := UI.wrap(p.title if p.title != "" else "Untitled prompt", 36 if wide else 30, UI.INK, 800)
	main.add_child(title)
	var facts := HFlowContainer.new()
	facts.add_theme_constant_override("h_separation", 18)
	facts.add_theme_constant_override("v_separation", 6)
	facts.add_child(_fact("copy", "Used " + UI.plural(p.uses, "time")))
	facts.add_child(_fact("edit", "Edited " + UI.ago(p.updated).to_lower()))
	if p.last_used > 0:
		facts.add_child(_fact("clock", "Last used " + UI.ago(p.last_used).to_lower()))
	main.add_child(facts)

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
	text.add_theme_font_size_override("normal_font_size", 18 if wide else 17)
	text.add_theme_font_size_override("bold_font_size", 16)
	text.add_theme_color_override("default_color", Color(0.93, 0.94, 0.99))
	text.add_theme_constant_override("line_separation", 6)
	text.text = W.highlight(p.body)
	pv.add_child(text)
	main.add_child(plinth)

	var vars := Store.variables(p.body)
	if not vars.is_empty():
		var vh := HFlowContainer.new()
		vh.add_theme_constant_override("h_separation", 6)
		vh.add_theme_constant_override("v_separation", 6)
		var vi := Icon.make("variable", UI.ACCENT_2, 18)
		vi.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		vh.add_child(vi)
		vh.add_child(UI.label("You'll fill in", 14, UI.SOFT, 600))
		for v in vars:
			vh.add_child(UI.pill(v, UI.ACCENT_2, Color(UI.ACCENT_2, 0.12)))
		main.add_child(vh)

	if not p.tags.is_empty():
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		for t in p.tags:
			flow.add_child(UI.chip("#" + t, false, UI.ACCENT_2, func(): app.find("#" + t)))
		side.add_child(UI.caption("Tags", "tag"))
		side.add_child(flow)

	if p.notes.strip_edges() != "":
		var notes := UI.panel(18)
		var nv := UI.vbox(8)
		nv.add_child(UI.caption("Curator's notes", "pen", UI.GOLD))
		nv.add_child(UI.wrap(p.notes, 15, UI.SOFT, 500))
		notes.add_child(nv)
		side.add_child(notes)

	# the action bar stays pinned to the bottom, on phone and desktop
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


func _fact(icon: String, text: String) -> HBoxContainer:
	var h := UI.hbox(6)
	var ic := Icon.make(icon, UI.FAINT, 14)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	h.add_child(UI.label(text, 13, UI.FAINT, 700))
	return h


func _more() -> void:
	var v := UI.vbox(10)
	v.add_child(UI.action_row("duplicate", "Duplicate", "Make an editable copy", func():
		app.close_sheet()
		var c := Store.duplicate_prompt(_id)
		if not c.is_empty():
			app.toast("Duplicated")
			app.edit_prompt(c.id)))
	if not Store.variables(Store.get_prompt(_id).get("body", "")).is_empty():
		v.add_child(UI.action_row("copy", "Copy as written", "Keep the {{blanks}} unfilled", func():
			app.close_sheet()
			app.copy_prompt(_id, true), UI.ACCENT_2))
	v.add_child(UI.action_row("trash", "Delete prompt", "You can undo right after", func():
		app.close_sheet()
		var gone := Store.delete_prompt(_id)
		app.pop()
		app.toast("Prompt deleted", "trash", "Undo", func(): Store.restore_prompt(gone)), UI.DANGER, true))
	app.sheet("Prompt", v)
