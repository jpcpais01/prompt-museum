extends Screen
## The museum's floor plan: a search bar over every prompt, then a wall of
## wing cards. Tapping a wing walks into it; typing searches the whole museum.

var _field: LineEdit
var _results: VBoxContainer
var _query := ""
var _wing_cols := 0


func build() -> void:
	live = true
	if args.has("query"):
		_query = str(args.query)
		args.erase("query")
	var head := UI.vbox(2)
	head.add_child(UI.label("THE COLLECTION", 12, UI.ACCENT_2, 800))
	head.add_child(UI.label("Library", 34, UI.INK, 800))
	body.add_child(head)

	_field = UI.search_field("Search every prompt, #tag or model", _query)
	_field.clear_button_enabled = true
	_field.right_icon = null
	_field.text_changed.connect(func(t: String):
		_query = t
		_fill())
	body.add_child(_field)
	_results = UI.vbox(16)
	body.add_child(_results)
	_fill()
	if args.get("focus", false):
		args.erase("focus")
		focus_search()


func focus_search() -> void:
	if _field:
		_field.grab_focus.call_deferred()
		_field.caret_column = _field.text.length()


func _fill() -> void:
	for c in _results.get_children():
		_results.remove_child(c)
		c.queue_free()
	var q := _query.strip_edges()
	if q == "":
		_browse()
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


## No query: shortcuts to whole-museum views, the wing wall, and recents.
func _browse() -> void:
	var cr := chip_row()
	var chips: Container = cr[1]
	chips.add_child(UI.chip("All  %d" % Store.prompts.size(), false, UI.ACCENT, func(): app.open_collection(Store.ALL)))
	var favs := Store.favorites().size()
	if favs > 0:
		chips.add_child(UI.chip("★ Favourites  %d" % favs, false, UI.GOLD, func(): app.open_collection(Store.FAVS)))
	var unfiled := Store.count_in("")
	if unfiled > 0:
		chips.add_child(UI.chip("Unfiled  %d" % unfiled, false, UI.SOFT, func(): app.open_collection(Store.UNFILED)))
	for tg in Store.all_tags().slice(0, 16):
		chips.add_child(UI.chip("#" + tg, false, UI.ACCENT_2, _set_query.bind("#" + tg)))
	_results.add_child(cr[0])

	_results.add_child(UI.section("Wings", "", Callable(), Store.collections.size()))
	_results.add_child(_wing_wall())

	if Store.prompts.is_empty():
		_results.add_child(W.empty("library", "Nothing on the walls yet", "Save the prompts you keep retyping, and they'll be one tap away.", "Add a prompt", func(): app.edit_prompt()))
		return
	var rec := Store.recent(app.columns() if app.columns() > 1 else 3)
	_results.add_child(UI.section("Jump back in"))
	_results.add_child(cards(rec))


## Every wing as a card, in a grid that fills the column, ending with an
## empty frame for a new one.
func _wing_wall() -> Control:
	var gap := 14.0 if not app.desktop() else 18.0
	var avail := app.content_width() - app.gutter() * 2.0
	var cols := _wing_columns()
	var w := floorf((avail - gap * (cols - 1)) / cols)
	var h := clampf(w * 1.18, 180.0, 250.0)
	_wing_cols = cols
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", int(gap))
	g.add_theme_constant_override("v_separation", int(gap) - 16)
	for c in Store.collections:
		g.add_child(W.collection_tile(c, app, w, h))
	g.add_child(W.new_tile(app, w, h))
	return g


func _wing_columns() -> int:
	var gap := 14.0 if not app.desktop() else 18.0
	return maxi(2, int((app.content_width() - app.gutter() * 2.0 + gap) / (210.0 + gap)))


## A resized window rehangs the wing wall when a column comes or goes.
func layout() -> void:
	super()
	if _results and _wing_cols > 0 and _query.strip_edges() == "" and _wing_columns() != _wing_cols:
		_wing_cols = 0
		_fill.call_deferred()


func _set_query(q: String) -> void:
	_query = q
	_field.text = q
	_field.caret_column = q.length()
	Fx.haptic(8)
	_fill()


## Back clears a search before it leaves the library.
func on_back() -> bool:
	if _query.strip_edges() != "":
		_set_query("")
		return true
	return false


func shown_again() -> void:
	_fill()
