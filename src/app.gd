class_name App
extends Control
## The museum's shell: the living backdrop, the screen stack with its
## transitions, the floating tab bar, bottom sheets and toasts. Screens ask the
## App to navigate; the App owns everything that outlives a single screen.

const AURORA := preload("res://shaders/aurora.gdshader")
const HOME := preload("res://src/screens/home.gd")
const LIBRARY := preload("res://src/screens/library.gd")
const SEARCH := preload("res://src/screens/search.gd")
const SETTINGS := preload("res://src/screens/settings.gd")
const COLLECTION := preload("res://src/screens/collection.gd")
const PROMPT := preload("res://src/screens/prompt.gd")
const EDITOR := preload("res://src/screens/editor.gd")
const FILL := preload("res://src/screens/fill_sheet.gd")
const WING := preload("res://src/screens/wing_sheet.gd")

const TABS := [["home", "home", "Lobby"], ["library", "library", "Library"], ["", "plus", ""], ["search", "search", "Search"], ["settings", "gear", "Settings"]]
const MAX_W := 760.0
const NAV_H := 68.0
## Wider than this (in UI units) and the museum switches to its desktop form:
## a side rail instead of the tab bar, multi-column walls and centred dialogs.
const DESKTOP_W := 900.0
const MAX_W_DESK := 1240.0
const RAIL_W := 228.0
const RAIL_GAP := 14.0

## "phone" or "desktop"; screens rebuild when it flips
signal form_changed(form: String)

static var i: App

var bg: ColorRect
var host: Control
var safe_top := 0.0
var safe_bottom := 0.0
## the on-screen keyboard's height in UI units (0 when it's down)
var keyboard := 0.0

var _stack: Array = []
var _tab := "home"
var _nav: PanelContainer
var _nav_items := {}
var _nav_glow: Panel
var _nav_shown := true
var _form := ""
var _rail: PanelContainer
var _rail_items := {}
var _rail_glow: Panel
var _rail_update: Control
var _sheet_layer: Control
var _sheet: PanelContainer
var _sheet_dim: ColorRect
var _toast_layer: Control
var _toast: Control
var _press_at := Vector2.ZERO
var _store_dirty := false


func _ready() -> void:
	i = self
	set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().quit_on_go_back = false
	bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var m := ShaderMaterial.new()
	m.shader = AURORA
	bg.material = m
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	host = Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(host)
	_build_nav()
	_build_rail()
	_sheet_layer = Control.new()
	_sheet_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sheet_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sheet_layer)
	_toast_layer = Control.new()
	_toast_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_toast_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast_layer)
	get_viewport().size_changed.connect(_on_resize)
	Store.changed.connect(func(): _store_dirty = true)
	_on_resize()
	go_tab("home", false)


func _process(_delta: float) -> void:
	if _store_dirty:
		_store_dirty = false
		for s in _stack:
			s.stale = true
		var top := current()
		if top and top.live:
			top.refresh()
	var kb := 0.0
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		var px := DisplayServer.virtual_keyboard_get_height()
		if px > 0:
			kb = px * get_viewport_rect().size.y / float(DisplayServer.window_get_size().y)
	if absf(kb - keyboard) > 1.0:
		keyboard = kb
		_layout_sheet()
		var top := current()
		if top:
			top.keyboard_changed(kb)


## Tells taps from scrolls for every button (see UI.dragging).
func _input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
		_press_at = e.position
		UI.dragging = false
	elif e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		if e.position.distance_to(_press_at) > 14.0:
			UI.dragging = true


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		back()
		get_viewport().set_input_as_handled()
		return
	# F11 or Alt+Enter flips fullscreen on desktop
	if e is InputEventKey and e.pressed and not e.echo and (e.keycode == KEY_F11 or (e.keycode == KEY_ENTER and e.alt_pressed)):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()
		return
	# desktop keyboard shortcuts: Ctrl+N new, Ctrl+F search, Ctrl+1–4 tabs
	if e is InputEventKey and e.pressed and not e.echo and e.is_command_or_control_pressed() and _sheet == null:
		var tabs := {KEY_1: "home", KEY_2: "library", KEY_3: "search", KEY_4: "settings"}
		if e.keycode == KEY_N:
			new_prompt()
		elif e.keycode == KEY_F:
			go_tab("search", true, {"focus": true})
		elif tabs.has(e.keycode):
			go_tab(tabs[e.keycode])
		else:
			return
		get_viewport().set_input_as_handled()


func toggle_fullscreen() -> void:
	var w := get_window()
	w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN or w.mode == Window.MODE_EXCLUSIVE_FULLSCREEN else Window.MODE_FULLSCREEN


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		back()


## Android back / Escape: close what's on top, step back, then head home.
func back() -> void:
	if Updater.overlay_open():
		Updater.close_overlay()
		return
	if _sheet:
		close_sheet()
		return
	var top := current()
	if top and top.on_back():
		return
	if _stack.size() > 1:
		pop()
		return
	if _tab != "home":
		go_tab("home")
		return
	get_tree().quit()


func _on_resize() -> void:
	var vp := get_viewport_rect().size
	var win := Vector2(DisplayServer.window_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	safe_top = 0.0
	safe_bottom = 0.0
	if OS.get_name() == "Android" and win.y > 0:
		var k := vp.y / win.y
		safe_top = maxf(0.0, safe.position.y * k)
		safe_bottom = maxf(0.0, (win.y - safe.end.y) * k)
	bg.material.set_shader_parameter("aspect", Vector2(vp.x / maxf(vp.y, 1.0), 1.0))
	var form := "desktop" if vp.x >= DESKTOP_W else "phone"
	var flipped := _form != "" and form != _form
	_form = form
	host.offset_left = RAIL_W + RAIL_GAP if desktop() else 0.0
	_layout_nav()
	_layout_rail()
	_layout_sheet()
	for s in _stack:
		s.layout()
	if flipped:
		for s in _stack:
			s.form_changed()
		form_changed.emit(form)


## True when the window is wide enough for the desktop layout.
func desktop() -> bool:
	return _form == "desktop"


## Width of the area screens live in (the window minus the rail).
func content_width() -> float:
	return size.x - host.offset_left


## Side margin that keeps content in a comfortable column on wide windows.
func gutter() -> float:
	if desktop():
		return maxf(32.0, (content_width() - MAX_W_DESK) / 2.0)
	return maxf(20.0, (size.x - MAX_W) / 2.0)


## Margin for full-window pages (the update screen) that stay a single column.
func page_gutter() -> float:
	return maxf(20.0, (size.x - MAX_W) / 2.0)


## How many prompt cards fit side by side.
func columns() -> int:
	if not desktop():
		return 1
	return 3 if content_width() - gutter() * 2.0 >= 1120.0 else 2


# ------------------------------------------------------------------ navigation

func current() -> Node:
	return _stack.back() if not _stack.is_empty() else null


func tab() -> String:
	return _tab


func _make_tab(t: String) -> Node:
	match t:
		"library":
			return LIBRARY.new()
		"search":
			return SEARCH.new()
		"settings":
			return SETTINGS.new()
	return HOME.new()


func go_tab(t: String, animate := true, args := {}) -> void:
	if t == _tab and _stack.size() == 1 and current() and args.is_empty():
		current().scroll_to_top()
		return
	var old := _stack.duplicate()
	_stack.clear()
	var scr := _make_tab(t)
	scr.app = self
	scr.args = args
	_tab = t
	_stack.append(scr)
	host.add_child(scr)
	for o in old:
		_retire(o, Vector2.ZERO)
	if animate:
		scr.modulate.a = 0.0
		var tw := scr.create_tween()
		tw.tween_property(scr, "modulate:a", 1.0, 0.22)
	_set_nav(t)
	show_nav(true)


func push(scr: Node, args := {}) -> void:
	scr.app = self
	scr.args = args
	var prev := current()
	_stack.append(scr)
	host.add_child(scr)
	scr.position.x = size.x * 0.18
	scr.modulate.a = 0.0
	var tw := scr.create_tween().set_parallel()
	tw.tween_property(scr, "position:x", 0.0, 0.42).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(scr, "modulate:a", 1.0, 0.25)
	if prev:
		var tp := prev.create_tween().set_parallel()
		tp.tween_property(prev, "position:x", -size.x * 0.08, 0.42).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tp.tween_property(prev, "modulate:a", 0.0, 0.3)
		tp.chain().tween_callback(func(): prev.visible = false)
	show_nav(false)


func pop() -> void:
	if _stack.size() <= 1:
		return
	var top: Node = _stack.pop_back()
	_retire(top, Vector2(size.x * 0.2, 0))
	var under := current()
	under.visible = true
	if under.stale:
		under.refresh()
	var tw := under.create_tween().set_parallel()
	tw.tween_property(under, "position:x", 0.0, 0.42).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(under, "modulate:a", 1.0, 0.3)
	under.shown_again()
	show_nav(_stack.size() == 1)


## Pops back to the screen below this one, then replaces nothing (used when
## something the screen showed is gone, like a deleted prompt).
func pop_to_root() -> void:
	while _stack.size() > 1:
		var s: Node = _stack.pop_back()
		s.queue_free()
	var root := current()
	root.visible = true
	root.position.x = 0
	root.modulate.a = 1.0
	root.refresh()
	show_nav(true)


func _retire(scr: Node, slide: Vector2) -> void:
	scr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scr.set_process_input(false)
	var tw := scr.create_tween().set_parallel()
	tw.tween_property(scr, "modulate:a", 0.0, 0.2)
	if slide != Vector2.ZERO:
		tw.tween_property(scr, "position", scr.position + slide, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(scr.queue_free)


func open_prompt(id: String) -> void:
	push(PROMPT.new(), {"id": id})


func open_collection(id: String) -> void:
	push(COLLECTION.new(), {"id": id})


func edit_prompt(id := "", collection := "") -> void:
	push(EDITOR.new(), {"id": id, "collection": collection})


## Takes a wing down (its prompts stay, unfiled) and leaves its room if open.
func delete_wing(id: String) -> void:
	Store.delete_collection(id)
	var top := current()
	if top and top.has_method("current_collection") and top.current_collection() == id:
		pop()
	toast("Wing deleted", "trash")


func edit_collection(id := "", on_saved: Callable = Callable()) -> void:
	var s := WING.new()
	s.app = self
	s.id = id
	s.on_saved = on_saved
	sheet("Edit wing" if id != "" else "New wing", s)


## Copies a prompt; one with blanks opens the fill-in sheet first.
func copy_prompt(id: String, force_raw := false) -> void:
	var p := Store.get_prompt(id)
	if p.is_empty():
		return
	if not force_raw and not Store.variables(p.body).is_empty():
		var s := FILL.new()
		s.app = self
		s.prompt_id = id
		sheet("Fill the blanks", s)
		return
	copy_text(p.body)
	Store.mark_used(id)


func copy_text(text: String, msg := "Copied to clipboard") -> void:
	DisplayServer.clipboard_set(text)
	Fx.haptic(18)
	toast(msg, "check")


# ------------------------------------------------------------------ tab bar

func _build_nav() -> void:
	_nav = PanelContainer.new()
	var sb := UI.box(Color(0.075, 0.08, 0.125, 0.94), 30, Color(1, 1, 1, 0.1))
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 26
	sb.shadow_offset = Vector2(0, 10)
	sb.set_content_margin_all(6)
	_nav.add_theme_stylebox_override("panel", sb)
	add_child(_nav)
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nav.add_child(layer)
	_nav_glow = Panel.new()
	var gsb := UI.box(Color(UI.ACCENT, 0.2), 24, Color(UI.ACCENT, 0.4))
	_nav_glow.add_theme_stylebox_override("panel", gsb)
	_nav_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_nav_glow)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(row)
	for t in TABS:
		var item := Control.new()
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.custom_minimum_size = Vector2(0, NAV_H - 12)
		row.add_child(item)
		if t[0] == "":
			# the centre button: a glowing gradient orb that adds a prompt
			var orb := Panel.new()
			var osb := UI.box(UI.ACCENT, 999)
			osb.shadow_color = Color(UI.ACCENT, 0.55)
			osb.shadow_size = 16
			osb.border_color = Color(1, 1, 1, 0.25)
			osb.set_border_width_all(1)
			orb.add_theme_stylebox_override("panel", osb)
			orb.custom_minimum_size = Vector2(50, 50)
			orb.size = Vector2(50, 50)
			orb.anchor_left = 0.5
			orb.anchor_right = 0.5
			orb.anchor_top = 0.5
			orb.anchor_bottom = 0.5
			orb.offset_left = -25
			orb.offset_right = 25
			orb.offset_top = -25
			orb.offset_bottom = 25
			orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			item.add_child(orb)
			var plus := Icon.make("plus", Color.WHITE, 24)
			plus.stroke = 2.6
			Icon.center(plus)
			orb.add_child(plus)
			UI.tap(item, func():
				Fx.haptic()
				new_prompt(), 0.9)
			continue
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 3)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(v)
		var ic := Icon.make(t[1], UI.SOFT, 22)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		var l := UI.label(t[2], 11, UI.SOFT, 700)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		_nav_items[t[0]] = {"item": item, "icon": ic, "label": l}
		var key: String = t[0]
		UI.tap(item, func():
			Fx.haptic(8)
			go_tab(key), 0.92)


## A new prompt, filed in whichever wing is on screen.
func new_prompt() -> void:
	var col := ""
	var top := current()
	if top and top.has_method("current_collection"):
		col = top.current_collection()
	edit_prompt("", col)


func _layout_nav() -> void:
	_nav.visible = not desktop()
	var w := minf(460.0, size.x - 24.0)
	_nav.size = Vector2(w, NAV_H)
	_nav.position = Vector2((size.x - w) / 2.0, size.y - safe_bottom - 14.0 - NAV_H + (0.0 if _nav_shown else NAV_H + 40.0))
	_place_glow(false)


func _set_nav(t: String) -> void:
	for k in _nav_items:
		var on: bool = k == t
		var it: Dictionary = _nav_items[k]
		it.icon.color = UI.INK if on else UI.SOFT
		it.label.add_theme_color_override("font_color", UI.INK if on else UI.FAINT)
		if on:
			Fx.pop(it.icon, 1.18)
	for k in _rail_items:
		var on: bool = k == t
		var it: Dictionary = _rail_items[k]
		it.icon.color = UI.INK if on else UI.SOFT
		it.label.add_theme_color_override("font_color", UI.INK if on else UI.SOFT)
	_place_glow.call_deferred(true)
	_place_rail_glow.call_deferred(true)


func _place_glow(animate: bool) -> void:
	if not _nav_items.has(_tab):
		_nav_glow.visible = false
		return
	_nav_glow.visible = true
	var item: Control = _nav_items[_tab].item
	var r := Rect2(item.position + Vector2(4, 0), item.size - Vector2(8, 0))
	if animate:
		var tw := _nav_glow.create_tween().set_parallel()
		tw.tween_property(_nav_glow, "position", r.position, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_nav_glow, "size", r.size, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_nav_glow.position = r.position
		_nav_glow.size = r.size


func show_nav(on: bool) -> void:
	if on == _nav_shown:
		return
	_nav_shown = on
	var y := size.y - safe_bottom - 14.0 - NAV_H + (0.0 if on else NAV_H + 40.0)
	var tw := _nav.create_tween()
	tw.tween_property(_nav, "position:y", y, 0.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


## How much room screens leave at the bottom for the tab bar.
func bottom_room() -> float:
	if desktop():
		return safe_bottom + 32.0
	return safe_bottom + NAV_H + 34.0


# ------------------------------------------------------------------ side rail

## The desktop navigation: a tall glass panel down the left edge with the
## brand, a New prompt button, the tabs and a few keyboard hints.
func _build_rail() -> void:
	_rail = PanelContainer.new()
	var sb := UI.box(Color(0.075, 0.08, 0.125, 0.9), 28, Color(1, 1, 1, 0.09))
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 30
	sb.shadow_offset = Vector2(0, 10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 20
	sb.content_margin_bottom = 16
	_rail.add_theme_stylebox_override("panel", sb)
	add_child(_rail)
	var v := UI.vbox(6)
	_rail.add_child(v)

	var brand := UI.hbox(10)
	brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mark := TextureRect.new()
	mark.texture = load("res://icon.png")
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.custom_minimum_size = Vector2(36, 36)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brand.add_child(mark)
	var names := UI.vbox(0)
	names.add_child(UI.label("Prompt", 15, UI.INK, 800))
	names.add_child(UI.label("MUSEUM", 11, UI.ACCENT_2, 800))
	brand.add_child(names)
	v.add_child(UI.margin(brand, 6, 0, 6, 0))
	v.add_child(UI.spacer(16))

	var add := UI.primary("New prompt", func(): new_prompt())
	add.add_theme_constant_override("h_separation", 10)
	add.custom_minimum_size.y = 48
	add.tooltip_text = "Ctrl+N"
	var plus := Icon.make("plus", Color.WHITE, 18)
	plus.stroke = 2.6
	plus.position = Vector2(18, 15)
	add.add_child(plus)
	add.alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(add)
	v.add_child(UI.spacer(14))
	v.add_child(UI.margin(UI.label("GALLERY", 11, UI.FAINT, 800), 12, 0, 0, 4))

	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var list := UI.vbox(4)
	list.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rail_glow = Panel.new()
	_rail_glow.add_theme_stylebox_override("panel", UI.box(Color(UI.ACCENT, 0.2), 16, Color(UI.ACCENT, 0.4)))
	_rail_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_rail_glow)
	layer.add_child(list)
	var n := 0
	for t in TABS:
		if t[0] == "":
			continue
		n += 1
		var item := PanelContainer.new()
		item.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		item.custom_minimum_size = Vector2(0, 46)
		item.tooltip_text = "Ctrl+%d" % n
		var row := UI.hbox(14)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic := Icon.make(t[1], UI.SOFT, 20)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)
		var l := UI.label(t[2], 15, UI.SOFT, 700)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)
		item.add_child(UI.margin(row, 14, 0, 10, 0))
		list.add_child(item)
		_rail_items[t[0]] = {"item": item, "icon": ic, "label": l}
		var key: String = t[0]
		UI.tap(item, func(): go_tab(key), 0.97)
		W.hover(item)
	layer.custom_minimum_size.y = n * 50
	v.add_child(layer)

	var fill := UI.spacer()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(fill)
	_rail_update = UI.vbox(0)
	v.add_child(_rail_update)
	var keys := UI.wrap("Ctrl+F search  ·  Esc back", 12, UI.FAINT, 600)
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(keys)
	Updater.checked.connect(func(_s, _v): _fill_rail_update())
	Updater.found.connect(func(_v): _fill_rail_update())
	_fill_rail_update()


func _fill_rail_update() -> void:
	for c in _rail_update.get_children():
		c.queue_free()
	if Updater.has_update():
		var chip := UI.chip("Update  " + Updater.latest, true, UI.ACCENT_2, func(): Updater.open_overlay())
		_rail_update.add_child(chip)
		_rail_update.add_child(UI.spacer(10))


func _layout_rail() -> void:
	_rail.visible = desktop()
	if not desktop():
		return
	_rail.position = Vector2(RAIL_GAP, safe_top + RAIL_GAP)
	_rail.size = Vector2(RAIL_W - RAIL_GAP, size.y - safe_top - safe_bottom - RAIL_GAP * 2.0)
	_place_rail_glow.call_deferred(false)


func _place_rail_glow(animate: bool) -> void:
	if _rail_glow == null or not _rail_items.has(_tab):
		if _rail_glow:
			_rail_glow.visible = false
		return
	_rail_glow.visible = true
	var item: Control = _rail_items[_tab].item
	var r := Rect2(item.position, item.size)
	if animate and _rail.visible:
		var tw := _rail_glow.create_tween().set_parallel()
		tw.tween_property(_rail_glow, "position", r.position, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_rail_glow, "size", r.size, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_rail_glow.position = r.position
		_rail_glow.size = r.size


# ------------------------------------------------------------------ sheets

## Slides a panel up from the bottom over a dimmed screen.
func sheet(title: String, content: Control) -> void:
	if _sheet:
		_drop_sheet(false)
	_sheet_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_sheet_dim = ColorRect.new()
	_sheet_dim.color = Color(0.01, 0.01, 0.03, 0.0)
	_sheet_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sheet_dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			close_sheet())
	_sheet_layer.add_child(_sheet_dim)
	_sheet = PanelContainer.new()
	var sb := UI.box(Color(0.085, 0.09, 0.14, 0.985), 30, Color(1, 1, 1, 0.1))
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 40
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 12
	sb.content_margin_bottom = 22
	_sheet.add_theme_stylebox_override("panel", sb)
	_sheet_layer.add_child(_sheet)
	var v := UI.vbox(14)
	_sheet.add_child(v)
	var grab := Panel.new()
	grab.custom_minimum_size = Vector2(42, 5)
	grab.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grab.add_theme_stylebox_override("panel", UI.box(Color(1, 1, 1, 0.2), 3))
	# a dialog on desktop has no grab handle to pull
	grab.visible = not desktop()
	v.add_child(grab)
	var head := UI.hbox(8)
	var t := UI.label(title, 22, UI.INK, 800)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UI.icon_button("close", close_sheet, 40.0, UI.SOFT))
	v.add_child(head)
	var sc := UI.scroll()
	sc.name = "Scroll"
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(content)
	_sheet.set_meta("content", content)
	# let wrapped text settle at its real width for two frames (off screen),
	# so the sheet opens at exactly the height its content needs
	var s := _sheet
	s.position.y = size.y + 20
	var dim_tw := _sheet_dim.create_tween()
	dim_tw.tween_property(_sheet_dim, "color:a", 0.62, 0.3)
	_layout_sheet()
	s.position.y = size.y + 20
	await get_tree().process_frame
	await get_tree().process_frame
	if s != _sheet:
		return
	_layout_sheet()
	var target := s.position.y
	if desktop():
		# desktop: the dialog fades in and settles into the centre
		s.position.y = target + 36
		s.modulate.a = 0.0
		var dt := s.create_tween().set_parallel()
		dt.tween_property(s, "position:y", target, 0.42).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		dt.tween_property(s, "modulate:a", 1.0, 0.22)
		return
	s.position.y = size.y + 20
	var tw := s.create_tween()
	tw.tween_property(s, "position:y", target, 0.48).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _layout_sheet() -> void:
	if _sheet == null:
		return
	var content: Control = _sheet.get_meta("content")
	var want := content.get_combined_minimum_size().y + 130.0
	if desktop():
		# a centred dialog over the whole window
		var dw := minf(600.0, size.x - 80.0)
		var dh := clampf(want - 14.0, 200.0, size.y - safe_top - safe_bottom - 80.0)
		_sheet.custom_minimum_size = Vector2(dw, dh)
		_sheet.size = _sheet.custom_minimum_size
		_sheet.position = ((size - _sheet.size) / 2.0).round()
		return
	var w := minf(620.0, size.x)
	var wide := size.x > 640.0
	var room := size.y - keyboard - safe_top - 40.0
	var h := clampf(want, 220.0, room)
	_sheet.custom_minimum_size = Vector2(w - (32.0 if wide else 0.0), h)
	_sheet.size = _sheet.custom_minimum_size
	var bottom := (24.0 if wide else -30.0) + maxf(keyboard, safe_bottom)
	_sheet.position = Vector2((size.x - _sheet.size.x) / 2.0, size.y - h - bottom + (0.0 if wide else 30.0))
	if not wide:
		# the sheet's bottom corners tuck below the screen edge
		_sheet.size.y += 30.0


## Called by a sheet whose content grew (new rows, an error line).
func sheet_resized() -> void:
	_layout_sheet.call_deferred()


func close_sheet() -> void:
	_drop_sheet(true)


func _drop_sheet(animate: bool) -> void:
	if _sheet == null:
		return
	var s := _sheet
	var d := _sheet_dim
	_sheet = null
	_sheet_dim = null
	_sheet_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().gui_release_focus()
	if not animate:
		s.queue_free()
		d.queue_free()
		return
	var tw := s.create_tween().set_parallel()
	if desktop():
		tw.tween_property(s, "position:y", s.position.y + 24, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(s, "modulate:a", 0.0, 0.18)
	else:
		tw.tween_property(s, "position:y", size.y + 20, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(d, "color:a", 0.0, 0.25)
	tw.chain().tween_callback(func():
		s.queue_free()
		d.queue_free())


## A yes/no question; `cb` runs only on yes. This opens a sheet, which
## frees whatever sheet was open, so `cb` must not be bound to that sheet.
func confirm(title: String, message: String, yes: String, cb: Callable, destructive := true) -> void:
	var v := UI.vbox(16)
	v.add_child(UI.wrap(message, 16, UI.SOFT))
	var row := UI.hbox(10)
	var no_b := UI.secondary("Cancel", close_sheet)
	no_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(no_b)
	var go := func():
		close_sheet()
		if not cb.is_valid():
			push_error("confirm: the yes callback's owner was freed before it ran")
			return
		cb.call()
	var yes_b := UI.danger(yes, go) if destructive else UI.primary(yes, go)
	yes_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(yes_b)
	v.add_child(row)
	sheet(title, v)


# ------------------------------------------------------------------ toasts

func toast(text: String, icon := "check", action := "", cb: Callable = Callable()) -> void:
	if _toast:
		var old := _toast
		var tw0 := old.create_tween()
		tw0.tween_property(old, "modulate:a", 0.0, 0.12)
		tw0.tween_callback(old.queue_free)
	var p := PanelContainer.new()
	var sb := UI.box(Color(0.14, 0.145, 0.21, 0.98), 999, Color(1, 1, 1, 0.12))
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 20
	sb.content_margin_left = 16
	sb.content_margin_right = 10 if action != "" else 20
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	var row := UI.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(row)
	var dot := PanelContainer.new()
	dot.add_theme_stylebox_override("panel", UI.box(Color(UI.ACCENT_2, 0.2), 999))
	dot.custom_minimum_size = Vector2(28, 28)
	var dh := Control.new()
	dh.custom_minimum_size = Vector2(28, 28)
	var ic := Icon.make(icon, UI.ACCENT_2, 16)
	ic.stroke = 2.6
	Icon.center(ic)
	dh.add_child(ic)
	dot.add_child(dh)
	row.add_child(dot)
	row.add_child(UI.label(text, 15, UI.INK, 700))
	if action != "":
		var b := UI.chip(action, true, UI.ACCENT_2, func():
			cb.call()
			_hide_toast(p))
		row.add_child(b)
	p.custom_minimum_size = Vector2(0, 46)
	_toast_layer.add_child(p)
	_toast = p
	p.reset_size()
	var y := size.y - (bottom_room() if _nav_shown else safe_bottom + 40.0) - p.size.y - 6.0 - keyboard
	p.position = Vector2(host.offset_left + (content_width() - p.size.x) / 2.0, y + 30)
	p.modulate.a = 0.0
	var tw := p.create_tween().set_parallel()
	tw.tween_property(p, "position:y", y, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	Fx.pop(dot, 1.25)
	var ref: WeakRef = weakref(p)
	get_tree().create_timer(4.5 if action != "" else 2.4).timeout.connect(func():
		if ref.get_ref():
			_hide_toast(ref.get_ref()))


func _hide_toast(p: Control) -> void:
	if not is_instance_valid(p) or p.get_meta("leaving", false):
		return
	p.set_meta("leaving", true)
	var tw := p.create_tween().set_parallel()
	tw.tween_property(p, "position:y", p.position.y + 20, 0.25)
	tw.tween_property(p, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(p.queue_free)
	if _toast == p:
		_toast = null
