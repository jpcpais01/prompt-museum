extends Screen
## One wing of the museum: its painting as a banner, then every prompt in it.

var _id := ""


func build() -> void:
	live = true
	_id = args.get("id", "")
	var c := Store.get_collection(_id)
	if c.is_empty():
		top_bar("Wing")
		body.add_child(W.empty("folder", "This wing is gone", "It may have been deleted."))
		return
	top_bar("", [
		UI.icon_button("edit", func(): app.edit_collection(_id), 46.0),
		UI.icon_button("plus", func(): app.edit_prompt("", _id), 46.0, Color.WHITE, Color(c.color).darkened(0.1)),
	])
	body.add_child(_banner(c))
	var list := Store.sorted(Store.in_collection(_id), Store.settings.get("sort", "recent"))
	if list.is_empty():
		body.add_child(W.empty(c.glyph, "An empty gallery", "Prompts you add to %s hang here." % c.name, "Add a prompt", func(): app.edit_prompt("", _id)))
	if not list.is_empty():
		body.add_child(cards(list))


func _banner(c: Dictionary) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 190)
	var art := Panel.new()
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := UI.box(Color.WHITE, 28)
	sb.shadow_color = Color(Color(c.color), 0.25)
	sb.shadow_size = 28
	sb.shadow_offset = Vector2(0, 12)
	art.add_theme_stylebox_override("panel", sb)
	var mat := ShaderMaterial.new()
	mat.shader = W.ART
	mat.set_shader_parameter("tint", Color(c.color))
	mat.set_shader_parameter("seed", float(hash(c.id) % 1000) / 97.0)
	mat.set_shader_parameter("ratio", Vector2(2.6, 1.0))
	mat.set_shader_parameter("focus", 0.8)
	art.material = mat
	holder.add_child(art)
	var rim := Panel.new()
	rim.set_anchors_preset(Control.PRESET_FULL_RECT)
	rim.add_theme_stylebox_override("panel", UI.box(Color(0, 0, 0, 0), 28, Color(1, 1, 1, 0.16)))
	holder.add_child(rim)
	var v := UI.vbox(4)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 24
	v.offset_right = -24
	v.offset_top = 22
	v.offset_bottom = -22
	holder.add_child(v)
	var glass := W.badge(c.glyph, Color.WHITE, 48)
	glass.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(glass)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(fill)
	v.add_child(UI.label(c.name, 32, Color.WHITE, 800))
	var n := Store.count_in(c.id)
	var used := 0
	for p in Store.in_collection(c.id):
		used += p.uses
	v.add_child(UI.label("%s  ·  used %s" % [UI.plural(n, "prompt"), UI.plural(used, "time")], 14, Color(1, 1, 1, 0.78), 700))
	for ch in [holder, art, rim, v]:
		ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return holder


func current_collection() -> String:
	return _id
