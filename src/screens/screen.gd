class_name Screen
extends Control
## A page of the museum. Most screens are a scrolling column (`body`) inside a
## gutter that keeps it readable on wide windows; pushed screens also get a
## fixed top bar with a back button and an optional fixed footer.

var app: App
var args := {}
## true when the archive changed while this screen sat under another one
var stale := false
## rebuild as soon as the archive changes (lists), rather than on return
var live := false

var body: VBoxContainer
var _scroll: SmoothScroll
var _pad: MarginContainer
var _frame: VBoxContainer
var _header: MarginContainer
var _footer: MarginContainer
var _kb_spacer: Control
var _bottom_spacer: Control


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_frame = UI.vbox(0)
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_frame)
	_header = MarginContainer.new()
	_frame.add_child(_header)
	_scroll = UI.scroll()
	_frame.add_child(_scroll)
	_pad = MarginContainer.new()
	_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_pad)
	body = UI.vbox(16)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pad.add_child(body)
	_footer = MarginContainer.new()
	_footer.visible = false
	_frame.add_child(_footer)
	_kb_spacer = UI.spacer()
	_frame.add_child(_kb_spacer)
	layout()
	build()
	_finish_body()
	opened()


## Fills `body` (and maybe the header/footer). Called again on refresh.
func build() -> void:
	pass


## Runs once after the first build, for entrance animations.
func opened() -> void:
	Fx.stagger(body, 0.04)


## Called when the screen on top of this one goes away.
func shown_again() -> void:
	pass


## Return true to keep Back from leaving (e.g. to confirm discarding edits).
func on_back() -> bool:
	return false


## True for screens read as one narrow column on wide windows (a prompt,
## the editor) rather than spread across the full width.
func reading() -> bool:
	return false


## The window crossed between the phone and desktop layouts: rebuild in the
## new shape. Screens holding unsaved input override this to keep it.
func form_changed() -> void:
	refresh()


func keyboard_changed(h: float) -> void:
	_kb_spacer.custom_minimum_size.y = maxf(0.0, h - (app.safe_bottom if app else 0.0))


func refresh() -> void:
	stale = false
	if body == null:
		return
	var at := _scroll.scroll_vertical
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()
	for c in _header.get_children():
		_header.remove_child(c)
		c.queue_free()
	for c in _footer.get_children():
		_footer.remove_child(c)
		c.queue_free()
	_footer.visible = false
	build()
	_finish_body()
	await get_tree().process_frame
	_scroll.scroll_vertical = at


func _finish_body() -> void:
	_bottom_spacer = UI.spacer(app.bottom_room() if is_root() and _footer.get_child_count() == 0 else 28.0)
	body.add_child(_bottom_spacer)


func scroll_to_top() -> void:
	_scroll.scroll_to(0.0)


func is_root() -> bool:
	return app and not app._stack.is_empty() and app._stack[0] == self


func layout() -> void:
	if app == null or _pad == null:
		return
	var g := app.gutter(reading())
	var top := app.safe_top
	for m in [_pad]:
		m.add_theme_constant_override("margin_left", int(g))
		m.add_theme_constant_override("margin_right", int(g))
	_pad.add_theme_constant_override("margin_top", int(top + 18) if _header.get_child_count() == 0 else 6)
	for m in [_header, _footer]:
		m.add_theme_constant_override("margin_left", int(g - 6))
		m.add_theme_constant_override("margin_right", int(g - 6))
	_header.add_theme_constant_override("margin_top", int(top + 10))
	_header.add_theme_constant_override("margin_bottom", 4)
	_footer.add_theme_constant_override("margin_top", 10)
	_footer.add_theme_constant_override("margin_bottom", int(app.safe_bottom + 16))
	_footer.add_theme_constant_override("margin_left", int(g))
	_footer.add_theme_constant_override("margin_right", int(g))


## The fixed bar of a pushed screen: back, a title, and action buttons.
func top_bar(title := "", actions: Array = []) -> HBoxContainer:
	var h := UI.hbox(8)
	h.add_child(UI.icon_button("back", func(): app.back(), 46.0))
	var t := UI.label(title, 18, UI.INK, 800)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.clip_text = true
	h.add_child(t)
	for a in actions:
		h.add_child(a)
	_header.add_child(h)
	layout()
	return h


## Pins a control to the bottom of the screen, above the scroll.
func footer(c: Control) -> void:
	_footer.add_child(c)
	_footer.visible = true
	layout()


## A wall of prompt cards: one column on a phone, a grid on desktop.
func cards(list: Array, cols := -1) -> Control:
	var n := app.columns() if cols < 0 else cols
	if n <= 1:
		var v := UI.vbox(16)
		for p in list:
			v.add_child(W.prompt_card(p, app))
		return v
	var g := GridContainer.new()
	g.columns = n
	g.add_theme_constant_override("h_separation", 16)
	g.add_theme_constant_override("v_separation", 16)
	for p in list:
		var c := W.prompt_card(p, app)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(c)
	return g


## A row of chips: a sideways swipe on a phone, wrapping lines on desktop
## (where a mouse can't drag a strip). Returns [the node to add, its row].
func chip_row(sep := 8) -> Array:
	if app.desktop():
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", sep)
		flow.add_theme_constant_override("v_separation", sep)
		return [flow, flow]
	var hs := UI.hscroll()
	var row := UI.hbox(sep)
	hs.add_child(row)
	return [hs, row]


## Two equal columns side by side on desktop; on a phone both are just
## `body`. Returns [left, right].
func split(sep := 28) -> Array:
	if not app.desktop():
		return [body, body]
	var h := UI.hbox(sep)
	var cols := []
	for n in 2:
		var v := UI.vbox(16)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		cols.append(v)
	body.add_child(h)
	return cols


## The big title that opens a tab screen.
func hero_title(kicker: String, title: String) -> void:
	var v := UI.vbox(2)
	v.add_child(UI.label(kicker.to_upper(), 12, UI.ACCENT_2, 800))
	v.add_child(UI.label(title, 34, UI.INK, 800))
	body.add_child(v)
