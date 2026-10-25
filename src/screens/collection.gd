extends Screen
## One wing of the museum: its painting as a banner, then every prompt in it,
## sortable and filterable by tag. Also shows the museum-wide views (all
## prompts, favourites, unfiled), which hang the same way.

const SORTS := [["recent", "Recent"], ["az", "A–Z"], ["used", "Most used"]]

var _id := ""
var _tag := ""


func build() -> void:
	live = true
	_id = args.get("id", "")
	var c := _wing()
	if c.is_empty():
		top_bar("Wing")
		body.add_child(W.empty("folder", "This wing is gone", "It may have been deleted."))
		return
	var tint := Color(c.color)
	var sort: String = Store.settings.get("sort", "recent")
	var sort_name := "Recent"
	for s in SORTS:
		if s[0] == sort:
			sort_name = s[1]
	var sb := UI.icon_chip("sort", sort_name, _cycle_sort)
	sb.tooltip_text = "Change the order"
	sb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var actions: Array = [sb]
	if not _id.begins_with("@"):
		actions.append(UI.icon_button("edit", func(): app.edit_collection(_id), 46.0))
	actions.append(UI.icon_button("plus", func(): app.edit_prompt("", current_collection()), 46.0, Color.WHITE, tint.darkened(0.1)))
	top_bar("", actions)
	var all := _prompts()
	body.add_child(_banner(c, all))

	var tags := {}
	for p in all:
		for t in p.tags:
			tags[t] = true
	var ordered := Store.all_tags().filter(func(t): return tags.has(t))
	if not tags.has(_tag):
		_tag = ""
	if ordered.size() > 1:
		var tr := chip_row(6)
		for tg in ordered.slice(0, 24):
			tr[1].add_child(UI.chip("#" + tg, _tag == tg, UI.ACCENT_2, _set_tag.bind(tg)))
		body.add_child(tr[0])

	var list := all
	if _tag != "":
		list = list.filter(func(p): return p.tags.has(_tag))
	list = Store.sorted(list, sort)
	if list.is_empty():
		match _id:
			Store.FAVS:
				body.add_child(W.empty("star", "No favourites yet", "Tap the star on any prompt to hang it here."))
			Store.UNFILED:
				body.add_child(W.empty("folder", "Everything is filed", "Prompts without a wing hang here."))
			_:
				body.add_child(W.empty(c.glyph, "An empty gallery", "Prompts you add to %s hang here." % c.name, "Add a prompt", func(): app.edit_prompt("", current_collection())))
	if not list.is_empty():
		body.add_child(cards(list))


## The wing on show, or a stand-in for one of the museum-wide views.
func _wing() -> Dictionary:
	match _id:
		Store.ALL:
			return {"id": _id, "name": "All prompts", "color": UI.ACCENT, "glyph": "library"}
		Store.FAVS:
			return {"id": _id, "name": "Favourites", "color": UI.GOLD, "glyph": "star_on"}
		Store.UNFILED:
			return {"id": _id, "name": "Unfiled", "color": Color("8a8fa8"), "glyph": "folder"}
	return Store.get_collection(_id)


func _prompts() -> Array:
	match _id:
		Store.ALL:
			return Store.prompts
		Store.FAVS:
			return Store.favorites()
		Store.UNFILED:
			return Store.in_collection("")
	return Store.in_collection(_id)


func _set_tag(t: String) -> void:
	_tag = "" if _tag == t else t
	Fx.haptic(8)
	refresh()


func _cycle_sort() -> void:
	var cur: String = Store.settings.get("sort", "recent")
	var k := 0
	for n in SORTS.size():
		if SORTS[n][0] == cur:
			k = n
	Store.settings.sort = SORTS[(k + 1) % SORTS.size()][0]
	Store.save_soon()


func _banner(c: Dictionary, list: Array) -> Control:
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
	var n := list.size()
	var used := 0
	for p in list:
		used += p.uses
	v.add_child(UI.label("%s  ·  used %s" % [UI.plural(n, "prompt"), UI.plural(used, "time")], 14, Color(1, 1, 1, 0.78), 700))
	for ch in [holder, art, rim, v]:
		ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return holder


## New prompts made here are filed in this wing (none for the museum-wide views).
func current_collection() -> String:
	return "" if _id.begins_with("@") else _id
