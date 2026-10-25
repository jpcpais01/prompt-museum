class_name W
extends RefCounted
## The museum's furniture: prompt cards, collection tiles, stat tiles and the
## other pieces the screens are assembled from.

const ART := preload("res://shaders/art.gdshader")


static func wing_color(collection_id: String) -> Color:
	var c := Store.get_collection(collection_id)
	return Color(c.color) if not c.is_empty() else UI.SOFT


## A rounded badge holding a collection's glyph, lit in its colour.
static func badge(glyph: String, color: Color, px := 44.0) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UI.box(Color(color, 0.18), int(px * 0.34), Color(color, 0.35))
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(px, px)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(px, px)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := Icon.make(glyph, color.lightened(0.25), px * 0.5)
	Icon.center(ic)
	holder.add_child(ic)
	p.add_child(holder)
	return p


## A short single-paragraph preview of a prompt's text.
static func preview(body: String, chars := 140) -> String:
	var flat := body.replace("\n", " ").replace("  ", " ").strip_edges()
	return flat if flat.length() <= chars else flat.substr(0, chars).strip_edges() + "…"


## One prompt in a list: its wing badge, title, a preview, the model and how
## often it's been used, with quick favourite and copy buttons.
static func prompt_card(p: Dictionary, app: Node) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.card_box(16))
	var col := W.wing_color(p.collection)
	var wing := Store.get_collection(p.collection)
	var row := UI.hbox(14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	var b := badge(wing.get("glyph", "spark"), col if not wing.is_empty() else UI.ACCENT, 44)
	b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(b)
	var text := UI.vbox(4)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var title := UI.label(p.title if p.title != "" else "Untitled prompt", 17, UI.INK, 800)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(title)
	var prev := UI.wrap(preview(p.body, 96), 14, UI.SOFT, 500)
	text.add_child(prev)
	var meta := UI.hbox(6)
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if p.model != "Any":
		meta.add_child(UI.pill(p.model, UI.INK, Color(col if not wing.is_empty() else UI.ACCENT, 0.2)))
	var vars := Store.variables(p.body).size()
	if vars > 0:
		meta.add_child(UI.pill("%d blank%s" % [vars, "" if vars == 1 else "s"], UI.ACCENT_2, Color(UI.ACCENT_2, 0.1)))
	for t in p.tags.slice(0, 2):
		meta.add_child(UI.pill("#" + t))
	if p.uses > 0:
		meta.add_child(UI.pill("%d×" % p.uses, UI.FAINT, Color(0, 0, 0, 0)))
	text.add_child(UI.spacer(2))
	text.add_child(meta)
	var side := UI.vbox(6)
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(side)
	var ref := []
	var star := UI.icon_button("star_on" if p.favorite else "star", func():
		var btn: Button = ref[0]
		var on := Store.toggle_favorite(p.id)
		var ic: Icon = btn.get_meta("icon")
		ic.set_glyph("star_on" if on else "star")
		ic.color = UI.GOLD if on else UI.SOFT
		Fx.pop(btn, 1.3)
		Fx.haptic(), 40.0, UI.GOLD if p.favorite else UI.SOFT, Color(0, 0, 0, 0))
	ref.append(star)
	side.add_child(star)
	var copy := UI.icon_button("copy", func(): app.copy_prompt(p.id), 40.0, UI.SOFT, Color(0, 0, 0, 0))
	side.add_child(copy)
	UI.tap(card, func(): app.open_prompt(p.id))
	hover(card)
	return card


## Desktop hover: the card lifts its border and brightens.
static func hover(c: Control) -> void:
	c.mouse_entered.connect(func():
		var tw := c.create_tween()
		tw.tween_property(c, "modulate", Color(1.08, 1.08, 1.12), 0.15))
	c.mouse_exited.connect(func():
		var tw := c.create_tween()
		tw.tween_property(c, "modulate", Color.WHITE, 0.2))


## A collection as a gallery wall: its living painting, glyph, name and count.
## Hovering (or being the featured one) brightens it and runs a sheen.
static func collection_tile(c: Dictionary, app: Node, w := 188.0, h := 236.0) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(w, h + 16)
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	var tile := Panel.new()
	tile.position = Vector2(0, 8)
	tile.size = Vector2(w, h)
	var sb := UI.box(Color.WHITE, 26)
	sb.shadow_color = Color(Color(c.color), 0.22)
	sb.shadow_size = 22
	sb.shadow_offset = Vector2(0, 10)
	tile.add_theme_stylebox_override("panel", sb)
	var mat := ShaderMaterial.new()
	mat.shader = ART
	mat.set_shader_parameter("tint", Color(c.color))
	mat.set_shader_parameter("seed", float(hash(c.id) % 1000) / 97.0)
	mat.set_shader_parameter("ratio", Vector2(w / h, 1.0))
	mat.set_shader_parameter("focus", 0.0)
	tile.material = mat
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(tile)
	# a fine inner rim so the painting sits in a frame
	var rim := Panel.new()
	rim.set_anchors_preset(Control.PRESET_FULL_RECT)
	rim.add_theme_stylebox_override("panel", UI.box(Color(0, 0, 0, 0), 26, Color(1, 1, 1, 0.16)))
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(rim)
	var inner := UI.vbox(2)
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 18
	inner.offset_right = -18
	inner.offset_top = 18
	inner.offset_bottom = -18
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(inner)
	var glass := PanelContainer.new()
	glass.add_theme_stylebox_override("panel", UI.box(Color(1, 1, 1, 0.16), 14, Color(1, 1, 1, 0.22)))
	glass.custom_minimum_size = Vector2(42, 42)
	glass.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gh := Control.new()
	gh.custom_minimum_size = Vector2(42, 42)
	gh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gi := Icon.make(c.glyph, Color.WHITE, 22)
	Icon.center(gi)
	gh.add_child(gi)
	glass.add_child(gh)
	inner.add_child(glass)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(fill)
	var name := UI.label(c.name, 21, Color.WHITE, 800)
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.clip_text = true
	inner.add_child(name)
	inner.add_child(UI.label(UI.plural(Store.count_in(c.id), "prompt"), 14, Color(1, 1, 1, 0.75), 600))
	var lift := func(on: bool):
		tile.pivot_offset = tile.size / 2.0
		var tw := tile.create_tween().set_parallel()
		tw.tween_property(tile, "scale", Vector2.ONE * (1.04 if on else 1.0), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_method(func(v: float): mat.set_shader_parameter("focus", v), mat.get_shader_parameter("focus"), 1.0 if on else 0.0, 0.3)
	holder.mouse_entered.connect(lift.bind(true))
	holder.mouse_exited.connect(lift.bind(false))
	holder.set_meta("lift", lift)
	UI.tap(holder, func(): app.open_collection(c.id), 0.96)
	return holder


## The last wall in the row: an empty frame inviting a new collection.
static func new_tile(app: Node, w := 150.0, h := 236.0) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(w, h + 16)
	var tile := Panel.new()
	tile.position = Vector2(0, 8)
	tile.size = Vector2(w, h)
	tile.add_theme_stylebox_override("panel", UI.box(Color(1, 1, 1, 0.035), 26, Color(1, 1, 1, 0.14)))
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(tile)
	var v := UI.vbox(10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(v)
	var ring := PanelContainer.new()
	ring.add_theme_stylebox_override("panel", UI.box(Color(UI.ACCENT, 0.16), 26, Color(UI.ACCENT, 0.5)))
	ring.custom_minimum_size = Vector2(52, 52)
	ring.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rh := Control.new()
	rh.custom_minimum_size = Vector2(52, 52)
	rh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := Icon.make("plus", UI.INK, 24)
	Icon.center(ic)
	rh.add_child(ic)
	ring.add_child(rh)
	v.add_child(ring)
	var l := UI.label("New wing", 15, UI.SOFT, 700)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	UI.tap(holder, func(): app.edit_collection(""), 0.96)
	hover(holder)
	return holder


## A number with a caption, for the lobby's stats row: the icon sits in a
## lit badge, and the card carries a faint wash of its colour.
static func stat(value: int, caption: String, icon: String, color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UI.card_box(14, UI.SURFACE.lerp(Color(color.darkened(0.35), UI.SURFACE.a), 0.12))
	sb.border_color = Color(color, 0.2)
	sb.content_margin_left = 16
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var top := UI.hbox(8)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n := UI.label("0", 28, UI.INK, 800)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(n)
	var b := badge(icon, color, 30)
	b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(b)
	v.add_child(top)
	v.add_child(UI.label(caption, 13, UI.SOFT, 700))
	# count up from zero as the lobby opens
	var tw := n.create_tween()
	tw.tween_method(func(x: float): n.text = str(roundi(x)), 0.0, float(value), 0.9).set_delay(0.15).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	return p


## A friendly placeholder for an empty list.
static func empty(icon: String, title: String, sub: String, action := "", cb: Callable = Callable()) -> Control:
	var v := UI.vbox(10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(UI.spacer(30))
	var b := badge(icon, UI.ACCENT, 72)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(b)
	v.add_child(UI.spacer(6))
	var t := UI.label(title, 20, UI.INK, 800)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := UI.wrap(sub, 15, UI.SOFT)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	if action != "":
		v.add_child(UI.spacer(8))
		var btn := UI.primary(action, cb)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.custom_minimum_size.x = 200
		v.add_child(btn)
	return v


## The prompt text as BBCode, with {{blanks}} lit up like gallery labels.
static func highlight(body: String, values := {}) -> String:
	var re := RegEx.create_from_string("\\{\\{\\s*([^{}\\s][^{}]*?)\\s*\\}\\}")
	var out := ""
	var at := 0
	var esc := func(s: String) -> String: return s.replace("[", "[lb]")
	for m in re.search_all(body):
		out += esc.call(body.substr(at, m.get_start() - at))
		var key := m.get_string(1)
		var v := str(values.get(key, ""))
		if v != "":
			out += "[color=#%s][b]%s[/b][/color]" % [UI.ACCENT_2.to_html(false), esc.call(v)]
		else:
			out += "[bgcolor=#8b6cff38][color=#c9bbff][b] %s [/b][/color][/bgcolor]" % esc.call(key)
		at = m.get_end()
	return out + esc.call(body.substr(at))
