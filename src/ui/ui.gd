class_name UI
extends RefCounted
## The design kit: colours, type and the handful of building blocks every
## screen is made from, so the whole museum shares one look.

const BG := Color("0a0b13")
const SURFACE := Color(0.11, 0.115, 0.17, 0.82)
const SURFACE_HI := Color(0.15, 0.155, 0.22, 0.92)
const LINE := Color(1, 1, 1, 0.08)
const LINE_HI := Color(1, 1, 1, 0.18)
const INK := Color("f4f5fb")
const SOFT := Color(0.86, 0.88, 0.96, 0.62)
const FAINT := Color(0.86, 0.88, 0.96, 0.36)
const ACCENT := Color("8b6cff")
const ACCENT_2 := Color("3dd6f5")
const DANGER := Color("ff5d73")
const GOLD := Color("ffc857")

const R_CARD := 22
const R_PILL := 999

static var _fonts := {}
## True while the finger has moved far enough that this touch is a scroll,
## not a tap (the App watches every touch); buttons ignore that release.
static var dragging := false


static func guard(cb: Callable) -> Callable:
	return func():
		if not dragging:
			cb.call()


## Manrope at a given weight (200–800), cached.
static func font(weight := 500) -> Font:
	if _fonts.has(weight):
		return _fonts[weight]
	var f := FontVariation.new()
	f.base_font = load("res://assets/fonts/Manrope.ttf")
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	_fonts[weight] = f
	return f


static func label(text: String, size := 16, color := INK, weight := 500) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func wrap(text: String, size := 15, color := SOFT, weight := 500) -> Label:
	var l := label(text, size, color, weight)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func box(bg: Color, radius := R_CARD, border := Color(0, 0, 0, 0), pad := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.corner_detail = 8
	s.anti_aliasing = true
	if border.a > 0.0:
		s.border_color = border
		s.set_border_width_all(1)
		s.border_blend = false
	s.set_content_margin_all(pad)
	return s


static func card_box(pad := 18, bg := SURFACE) -> StyleBoxFlat:
	var s := box(bg, R_CARD, LINE, pad)
	s.shadow_color = Color(0, 0, 0, 0.28)
	s.shadow_size = 18
	s.shadow_offset = Vector2(0, 8)
	return s


static func panel(pad := 18, bg := SURFACE) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", card_box(pad, bg))
	return p


static func vbox(sep := 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func margin(child: Control, l := 20, t := 0, r := 20, b := 0) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	m.add_child(child)
	return m


static func spacer(h := 0.0, w := 0.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func expand() -> Control:
	var c := spacer()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func _flat_button(b: Button, bg: Color, fg: Color, radius: int, border := Color(0, 0, 0, 0)) -> void:
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# a see-through button still answers the pointer with a faint wash
	var ghost := bg.a < 0.02
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		var c := bg
		if s == "hover":
			c = Color(1, 1, 1, 0.07) if ghost else bg.lightened(0.08)
		elif s == "pressed":
			c = Color(1, 1, 1, 0.11) if ghost else bg.darkened(0.12)
		elif s == "disabled":
			c = Color(bg, bg.a * 0.4)
		var sb := box(c, radius, border if s != "focus" else LINE_HI, 0)
		if s == "focus":
			sb.bg_color = bg if ghost else bg.lightened(0.06)
		sb.content_margin_left = 18
		sb.content_margin_right = 18
		b.add_theme_stylebox_override(s, sb)
	for s in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(s, fg)
	b.add_theme_color_override("font_disabled_color", Color(fg, 0.4))
	b.add_theme_color_override("icon_normal_color", fg)
	b.add_theme_color_override("icon_hover_color", fg)
	b.add_theme_color_override("icon_pressed_color", fg)
	b.add_theme_color_override("icon_focus_color", fg)


## The big gradient-feel call to action.
static func primary(text: String, cb: Callable = Callable()) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 52)
	b.add_theme_font_override("font", font(800))
	b.add_theme_font_size_override("font_size", 16)
	_flat_button(b, ACCENT, Color.WHITE, 18, Color(1, 1, 1, 0.16))
	# a soft violet glow under the main action, so it reads as the way forward
	for s in ["normal", "hover", "pressed"]:
		var sb: StyleBoxFlat = b.get_theme_stylebox(s)
		sb.shadow_color = Color(ACCENT, 0.34 if s != "pressed" else 0.18)
		sb.shadow_size = 14 if s != "pressed" else 6
		sb.shadow_offset = Vector2(0, 4)
	b.focus_mode = Control.FOCUS_NONE
	if cb.is_valid():
		b.pressed.connect(guard(cb))
	Fx.press_feedback(b)
	return b


static func secondary(text: String, cb: Callable = Callable()) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 52)
	b.add_theme_font_override("font", font(700))
	b.add_theme_font_size_override("font_size", 16)
	_flat_button(b, Color(1, 1, 1, 0.07), INK, 18, LINE)
	b.focus_mode = Control.FOCUS_NONE
	if cb.is_valid():
		b.pressed.connect(guard(cb))
	Fx.press_feedback(b)
	return b


static func danger(text: String, cb: Callable = Callable()) -> Button:
	var b := secondary(text, cb)
	_flat_button(b, Color(DANGER, 0.14), DANGER, 18, Color(DANGER, 0.3))
	return b


## A round button with a drawn icon in it.
static func icon_button(icon: String, cb: Callable = Callable(), size := 46.0, tint := INK, bg := Color(1, 1, 1, 0.07)) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(size, size)
	b.focus_mode = Control.FOCUS_NONE
	_flat_button(b, bg, tint, int(size / 2.0), LINE if bg.a > 0.0 else Color(0, 0, 0, 0))
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb: StyleBoxFlat = b.get_theme_stylebox(s)
		sb.content_margin_left = 0
		sb.content_margin_right = 0
	var ic := Icon.make(icon, tint, size * 0.46)
	Icon.center(ic)
	b.add_child(ic)
	b.set_meta("icon", ic)
	if cb.is_valid():
		b.pressed.connect(guard(cb))
	Fx.press_feedback(b)
	return b


## A small rounded tag; `on` paints it in the accent.
static func chip(text: String, on := false, color := ACCENT, cb: Callable = Callable()) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = false
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 36)
	b.add_theme_font_override("font", font(700))
	b.add_theme_font_size_override("font_size", 14)
	var bg := Color(color, 0.22) if on else Color(1, 1, 1, 0.06)
	_flat_button(b, bg, INK if on else SOFT, R_PILL, Color(color, 0.55) if on else LINE)
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb: StyleBoxFlat = b.get_theme_stylebox(s)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
	if cb.is_valid():
		b.pressed.connect(guard(cb))
	Fx.press_feedback(b)
	return b


## A non-interactive pill (model, tag) for cards.
static func pill(text: String, color := SOFT, bg := Color(1, 1, 1, 0.06)) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := box(bg, R_PILL)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(label(text, 12, color, 700))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func _field_style(f: Control) -> void:
	var n := box(Color(1, 1, 1, 0.05), 16, LINE, 14)
	var fo := box(Color(1, 1, 1, 0.075), 16, Color(ACCENT, 0.8), 14)
	f.add_theme_stylebox_override("normal", n)
	f.add_theme_stylebox_override("focus", fo)
	f.add_theme_stylebox_override("read_only", n)
	f.add_theme_font_override("font", font(500))
	f.add_theme_font_size_override("font_size", 16)
	f.add_theme_color_override("font_color", INK)
	f.add_theme_color_override("font_placeholder_color", FAINT)
	f.add_theme_color_override("caret_color", ACCENT_2)
	f.add_theme_color_override("selection_color", Color(ACCENT, 0.45))


static func line_edit(placeholder := "", text := "") -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.text = text
	e.custom_minimum_size = Vector2(0, 52)
	e.caret_blink = true
	e.clear_button_enabled = false
	_field_style(e)
	return e


static func text_edit(placeholder := "", text := "", height := 220.0) -> TextEdit:
	var e := TextEdit.new()
	e.placeholder_text = placeholder
	e.text = text
	e.custom_minimum_size = Vector2(0, height)
	e.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	e.caret_blink = true
	e.scroll_fit_content_height = false
	_field_style(e)
	e.add_theme_constant_override("line_spacing", 6)
	e.add_theme_color_override("background_color", Color(0, 0, 0, 0))
	return e


## A section heading with an optional count and an action on the right
## ("See all ›").
static func section(title: String, action := "", cb: Callable = Callable(), count := -1) -> HBoxContainer:
	var h := hbox(10)
	var l := label(title, 19, INK, 800)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	if count >= 0:
		var n := pill(str(count), SOFT, Color(1, 1, 1, 0.07))
		n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(n)
	h.add_child(expand())
	if action != "":
		h.add_child(link(action, cb))
	return h


## A quiet text action in the second accent, with a chevron.
static func link(text: String, cb: Callable = Callable()) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font(700))
	b.add_theme_font_size_override("font_size", 14)
	for s in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(s, ACCENT_2)
	for s in ["normal", "hover", "pressed", "focus"]:
		var sb := box(Color(ACCENT_2, 0.1) if s == "hover" else Color(0, 0, 0, 0), R_PILL)
		sb.content_margin_left = 12
		sb.content_margin_right = 28
		b.add_theme_stylebox_override(s, sb)
	b.custom_minimum_size.y = 32
	var ic := Icon.make("chevron", ACCENT_2, 14)
	ic.stroke = 2.4
	ic.anchor_left = 1.0
	ic.anchor_right = 1.0
	ic.anchor_top = 0.5
	ic.anchor_bottom = 0.5
	ic.offset_left = -24
	ic.offset_right = -10
	ic.offset_top = -7
	ic.offset_bottom = 7
	b.add_child(ic)
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if cb.is_valid():
		b.pressed.connect(guard(cb))
	return b


## A small caption over a group of fields, with an optional icon.
static func caption(text: String, icon := "", color := SOFT) -> HBoxContainer:
	var h := hbox(8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon != "":
		var ic := Icon.make(icon, color, 15)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
	var l := label(text.to_upper(), 12, color, 800)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	return h


## A chip with a drawn icon before its text (sort, filters).
static func icon_chip(icon: String, text: String, cb: Callable = Callable(), on := false, color := ACCENT) -> Button:
	var b := chip(text, on, color, cb)
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb: StyleBoxFlat = b.get_theme_stylebox(s)
		sb.content_margin_left = 38
	var ic := Icon.make(icon, INK if on else SOFT, 16)
	ic.anchor_top = 0.5
	ic.anchor_bottom = 0.5
	ic.offset_left = 14
	ic.offset_right = 30
	ic.offset_top = -8
	ic.offset_bottom = 8
	b.add_child(ic)
	return b


## A keyboard key, for shortcut hints on desktop.
static func kbd(text: String) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := box(Color(1, 1, 1, 0.06), 7, Color(1, 1, 1, 0.14))
	sb.border_width_bottom = 2
	sb.content_margin_left = 7
	sb.content_margin_right = 7
	sb.content_margin_top = 1
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(label(text, 11, SOFT, 700))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


## A row in a list of actions: icon badge, a title with an optional line
## under it, and a chevron. `tone` is the badge colour; danger rows go red.
static func action_row(icon: String, title: String, sub := "", cb: Callable = Callable(), tone := ACCENT, is_danger := false) -> PanelContainer:
	var p := PanelContainer.new()
	var col := DANGER if is_danger else tone
	var n := box(Color(1, 1, 1, 0.035), 18, LINE, 0)
	var hv := box(Color(col, 0.1), 18, Color(col, 0.3), 0)
	for sb in [n, hv]:
		sb.content_margin_left = 12
		sb.content_margin_right = 14
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", n)
	p.custom_minimum_size.y = 62
	var row := hbox(14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	row.add_child(W.badge(icon, col, 40))
	var text := vbox(1)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(label(title, 16, DANGER if is_danger else INK, 700))
	if sub != "":
		text.add_child(UI.wrap(sub, 13, FAINT, 600))
	row.add_child(text)
	var ch := Icon.make("chevron", FAINT, 16)
	ch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ch)
	p.mouse_entered.connect(func(): p.add_theme_stylebox_override("panel", hv))
	p.mouse_exited.connect(func(): p.add_theme_stylebox_override("panel", n))
	tap(p, cb, 0.985)
	return p


## A search box: the field with a magnifier set into its left edge.
static func search_field(placeholder := "", text := "") -> LineEdit:
	var e := line_edit(placeholder, text)
	e.custom_minimum_size.y = 58
	e.add_theme_font_size_override("font_size", 17)
	for s in ["normal", "focus", "read_only"]:
		var sb: StyleBoxFlat = e.get_theme_stylebox(s)
		sb.set_corner_radius_all(R_PILL)
		sb.content_margin_left = 50
		sb.content_margin_right = 18
	var ic := Icon.make("search", SOFT, 20)
	ic.anchor_top = 0.5
	ic.anchor_bottom = 0.5
	ic.offset_left = 20
	ic.offset_right = 40
	ic.offset_top = -10
	ic.offset_bottom = 10
	e.add_child(ic)
	e.focus_entered.connect(func(): ic.color = ACCENT_2)
	e.focus_exited.connect(func(): ic.color = SOFT)
	return e


static func scroll() -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.scroll_deadzone = 8
	var bar := s.get_v_scroll_bar()
	bar.add_theme_stylebox_override("scroll", StyleBoxEmpty.new())
	bar.add_theme_stylebox_override("grabber", box(Color(1, 1, 1, 0.14), 3))
	bar.add_theme_stylebox_override("grabber_highlight", box(Color(1, 1, 1, 0.24), 3))
	bar.add_theme_stylebox_override("grabber_pressed", box(Color(1, 1, 1, 0.3), 3))
	bar.custom_minimum_size.x = 5
	return s


static func hscroll() -> ScrollContainer:
	var s := ScrollContainer.new()
	s.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.scroll_deadzone = 8
	return s


## "3 min ago", "Yesterday", "12 Mar".
static func ago(t: int) -> String:
	if t <= 0:
		return "Never"
	var d := Time.get_unix_time_from_system() - t
	if d < 60:
		return "Just now"
	if d < 3600:
		return "%d min ago" % int(d / 60)
	if d < 86400:
		return "%d h ago" % int(d / 3600)
	if d < 172800:
		return "Yesterday"
	if d < 604800:
		return "%d days ago" % int(d / 86400)
	var dt := Time.get_datetime_dict_from_unix_time(t)
	const M := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%d %s" % [dt.day, M[dt.month - 1]]


static func greeting() -> String:
	var h: int = Time.get_datetime_dict_from_system().hour
	if h < 5:
		return "Good night"
	if h < 12:
		return "Good morning"
	if h < 18:
		return "Good afternoon"
	return "Good evening"


static func plural(n: int, word: String) -> String:
	return "%d %s%s" % [n, word, "" if n == 1 else "s"]


## True when `local` (a point in `c`'s own space) lands on a visible button
## inside `c`. Buttons let presses pass through so drags still scroll, so a
## tappable card has to step aside for them itself.
static func over_button(c: Control, local: Vector2) -> bool:
	var at := c.get_global_transform() * local
	var stack: Array[Node] = c.get_children()
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var ctl := n as Control
		if ctl == null or not ctl.is_visible_in_tree():
			continue
		if ctl is BaseButton and not (ctl as BaseButton).disabled and ctl.mouse_filter != Control.MOUSE_FILTER_IGNORE and ctl.get_global_rect().has_point(at):
			return true
		stack.append_array(ctl.get_children())
	return false


## Makes any control tappable without stealing the drag from its scroll:
## presses pass through, and a release only counts if the finger stayed put.
static func tap(c: Control, cb: Callable, depth := 0.975) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	c.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				# a press on a button inside the card (star, copy…) is that button's alone
				if over_button(c, e.position):
					return
				c.set_meta("down", true)
				c.pivot_offset = c.size / 2.0
				var tw := c.create_tween()
				tw.tween_property(c, "scale", Vector2(depth, depth), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			elif c.get_meta("down", false):
				c.set_meta("down", false)
				var tw := c.create_tween()
				tw.tween_property(c, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
				if not dragging and Rect2(Vector2.ZERO, c.size).has_point(e.position):
					cb.call()
		elif e is InputEventMouseMotion and c.get_meta("down", false) and dragging:
			c.set_meta("down", false)
			var tw := c.create_tween()
			tw.tween_property(c, "scale", Vector2.ONE, 0.25))
	c.mouse_exited.connect(func():
		if c.get_meta("down", false) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			c.set_meta("down", false)
			c.scale = Vector2.ONE)
