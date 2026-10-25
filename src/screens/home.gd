extends Screen
## The lobby: a greeting, the stats, the collections as a row of living
## paintings, an exhibit of the day, favourites and what you used last.

func build() -> void:
	live = true
	var wide := app.desktop()
	# brand row (on desktop the rail carries the brand and the update chip)
	if not wide:
		body.add_child(_brand_row())

	var who: String = str(Store.settings.get("name", "")).strip_edges()
	var hello := UI.vbox(4)
	hello.add_child(UI.label(UI.greeting() + ("," if who != "" else ""), 30, UI.INK, 800))
	if who != "":
		var n := UI.label(who, 30, UI.ACCENT_2, 800)
		hello.add_child(n)
	var count := Store.prompts.size()
	var sub := "Your museum holds %s across %s." % [UI.plural(count, "prompt"), UI.plural(Store.collections.size(), "wing")] if count > 0 else "Your museum is empty. Add your first prompt."
	hello.add_child(UI.wrap(sub, 15, UI.SOFT))
	var stats := UI.hbox(10)
	stats.add_child(W.stat(count, "Prompts", "library", UI.ACCENT))
	stats.add_child(W.stat(Store.favorites().size(), "Favourites", "star_on", UI.GOLD))
	stats.add_child(W.stat(Store.total_uses(), "Copies", "copy", UI.ACCENT_2))
	if wide:
		# desktop: the greeting and the stats share the hero row
		var hero := UI.hbox(28)
		hello.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hello.size_flags_vertical = Control.SIZE_SHRINK_END
		hello.add_child(UI.spacer(10))
		hero.add_child(hello)
		stats.custom_minimum_size.x = 470
		hero.add_child(stats)
		body.add_child(UI.spacer(6))
		body.add_child(hero)
	else:
		body.add_child(hello)

	# the search pill opens the library's search with the keyboard up
	var search := PanelContainer.new()
	search.add_theme_stylebox_override("panel", UI.box(Color(1, 1, 1, 0.06), 999, UI.LINE, 0))
	search.custom_minimum_size = Vector2(0, 54)
	var sr := UI.hbox(12)
	sr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	search.add_child(UI.margin(sr, 18, 0, 18, 0))
	var si := Icon.make("search", UI.SOFT, 20)
	si.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sr.add_child(si)
	var sl := UI.label("Search titles, text and #tags", 15, UI.FAINT, 600)
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sr.add_child(sl)
	if wide:
		sr.add_child(UI.kbd("Ctrl F"))
	UI.tap(search, func(): app.find(), 0.985)
	W.hover(search)
	body.add_child(search)
	if not wide:
		body.add_child(stats)

	body.add_child(UI.spacer(2))
	body.add_child(UI.section("Wings", "See all", func(): app.go_tab("library"), Store.collections.size()))
	var row: Container
	var wall: Control
	if wide:
		# desktop: every wing hangs at once, wrapping onto new lines
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 18)
		flow.add_theme_constant_override("v_separation", 6)
		row = flow
		wall = UI.margin(flow, 0, 0, 0, 12)
	else:
		var hs := UI.hscroll()
		hs.custom_minimum_size.y = 236 + 40
		row = UI.hbox(14)
		hs.add_child(UI.margin(row, 0, 4, 20, 20))
		wall = hs
	var first := true
	for c in Store.collections:
		var tile := W.collection_tile(c, app)
		row.add_child(tile)
		if first:
			# the first wall is lit, like the selected tile on a console home
			first = false
			tile.get_meta("lift").call_deferred(true)
	row.add_child(W.new_tile(app))
	body.add_child(wall)

	var pick := _exhibit()
	if not pick.is_empty():
		body.add_child(UI.section("Exhibit of the day"))
		body.add_child(_exhibit_card(pick))

	# favourites and recents: stacked on a phone, side by side on desktop
	var cols := split(0.0)
	if wide:
		cols[1].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var favs := Store.favorites()
	if not favs.is_empty():
		cols[0].add_child(UI.spacer(2))
		cols[0].add_child(UI.section("Favourites", "See all", func(): app.open_collection(Store.FAVS), favs.size()))
		cols[0].add_child(cards(Store.sorted(favs, "used").slice(0, 3), 1))

	var rec := Store.recent(5 if not wide else 3)
	if not rec.is_empty():
		cols[1].add_child(UI.spacer(2))
		cols[1].add_child(UI.section("Recently used"))
		cols[1].add_child(cards(rec, 1))
	if count == 0:
		body.add_child(W.empty("spark", "A museum with empty walls", "Prompts you save show up here, sorted into wings.", "Add a prompt", func(): app.edit_prompt()))


func _brand_row() -> Control:
	var top := UI.hbox(10)
	var mark := TextureRect.new()
	mark.texture = load("res://icon.png")
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.custom_minimum_size = Vector2(34, 34)
	top.add_child(mark)
	var brand := UI.label("Prompt Museum", 16, UI.INK, 800)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(brand)
	if Updater.has_update():
		var upd := UI.chip("Update  " + Updater.latest, true, UI.ACCENT_2, func(): Updater.open_overlay())
		top.add_child(upd)
	top.add_child(UI.icon_button("gear", func(): app.go_tab("settings"), 42.0, UI.SOFT))
	return top


## The same prompt all day: a gentle way to rediscover old ones.
func _exhibit() -> Dictionary:
	if Store.prompts.is_empty():
		return {}
	var d := Time.get_date_dict_from_system()
	var k: int = (d.year * 372 + d.month * 31 + d.day) % Store.prompts.size()
	return Store.prompts[k]


func _exhibit_card(p: Dictionary) -> Control:
	var col := W.wing_color(p.collection)
	if Store.get_collection(p.collection).is_empty():
		col = UI.ACCENT
	var card := PanelContainer.new()
	var sb := UI.card_box(0, Color(0, 0, 0, 0))
	card.add_theme_stylebox_override("panel", sb)
	var stack := Control.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(stack)
	var art := Panel.new()
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.add_theme_stylebox_override("panel", UI.box(Color.WHITE, UI.R_CARD))
	var mat := ShaderMaterial.new()
	mat.shader = W.ART
	mat.set_shader_parameter("tint", col.darkened(0.25))
	mat.set_shader_parameter("seed", float(hash(p.id) % 997) / 31.0)
	mat.set_shader_parameter("ratio", Vector2(2.2, 1.0))
	mat.set_shader_parameter("focus", 0.15)
	art.material = mat
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(art)
	var scrim := Panel.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.add_theme_stylebox_override("panel", UI.box(Color(0.03, 0.03, 0.07, 0.42), UI.R_CARD, Color(1, 1, 1, 0.12)))
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(scrim)
	var v := UI.vbox(10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inner := UI.margin(v, 22, 20, 22, 20)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inner)
	v.add_child(UI.label("“", 54, Color(1, 1, 1, 0.5), 800))
	var q := UI.wrap(W.preview(p.body, 170), 17, Color.WHITE, 600)
	v.add_child(q)
	var foot := UI.hbox(10)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := UI.label(p.title, 15, Color(1, 1, 1, 0.8), 800)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.clip_text = true
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(t)
	var cp := UI.chip("Use it", true, Color.WHITE, func(): app.copy_prompt(p.id))
	foot.add_child(cp)
	v.add_child(foot)
	UI.tap(card, func(): app.open_prompt(p.id), 0.985)
	return card
