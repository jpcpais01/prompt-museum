extends Screen
## Every prompt in one place, filtered by wing, favourites or tag, and sorted
## by recent edits, name or how often it's been used.

const SORTS := [["recent", "Recent"], ["az", "A–Z"], ["used", "Most used"]]

var filter := "all"
var tag := ""


func build() -> void:
	live = true
	if args.has("filter"):
		filter = args.filter
		args.erase("filter")
	var head := UI.hbox(10)
	var t := UI.vbox(2)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_child(UI.label("THE COLLECTION", 12, UI.ACCENT_2, 800))
	t.add_child(UI.label("Library", 34, UI.INK, 800))
	head.add_child(t)
	var sort: String = Store.settings.get("sort", "recent")
	var sort_name := "Recent"
	for s in SORTS:
		if s[0] == sort:
			sort_name = s[1]
	var sb := UI.chip(sort_name, false, UI.ACCENT, _cycle_sort)
	sb.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(sb)
	body.add_child(head)

	# wing filter chips
	var cr := chip_row()
	var hs: Control = cr[0]
	var chips: Container = cr[1]
	chips.add_child(UI.chip("All  %d" % Store.prompts.size(), filter == "all", UI.ACCENT, _set_filter.bind("all")))
	chips.add_child(UI.chip("★ Favourites", filter == "fav", UI.GOLD, _set_filter.bind("fav")))
	for c in Store.collections:
		chips.add_child(UI.chip(c.name, filter == c.id, Color(c.color), _set_filter.bind(c.id)))
	var unfiled := Store.count_in("")
	if unfiled > 0:
		chips.add_child(UI.chip("Unfiled", filter == "none", UI.SOFT, _set_filter.bind("none")))
	chips.add_child(UI.chip("+ Wing", false, UI.ACCENT, func(): app.edit_collection("")))
	body.add_child(hs)

	var tags := Store.all_tags()
	if not tags.is_empty():
		var tr := chip_row(6)
		var th: Control = tr[0]
		var trow: Container = tr[1]
		for tg in tags.slice(0, 24):
			trow.add_child(UI.chip("#" + tg, tag == tg, UI.ACCENT_2, _set_tag.bind(tg)))
		body.add_child(th)

	var list := _list()
	var info := UI.label(UI.plural(list.size(), "prompt") + ("  ·  #" + tag if tag != "" else ""), 13, UI.FAINT, 700)
	body.add_child(info)
	if list.is_empty():
		if Store.prompts.is_empty():
			body.add_child(W.empty("library", "Nothing on the walls yet", "Save the prompts you keep retyping, and they'll be one tap away.", "Add a prompt", func(): app.edit_prompt()))
		else:
			body.add_child(W.empty("filter", "Nothing matches", "Try another wing or tag.", "Show everything", func():
				filter = "all"
				tag = ""
				refresh()))
	if not list.is_empty():
		body.add_child(cards(list))


func _list() -> Array:
	var out: Array
	match filter:
		"all":
			out = Store.prompts
		"fav":
			out = Store.favorites()
		"none":
			out = Store.in_collection("")
		_:
			out = Store.in_collection(filter)
	if tag != "":
		out = out.filter(func(p): return p.tags.has(tag))
	return Store.sorted(out, Store.settings.get("sort", "recent"))


func _set_filter(f: String) -> void:
	filter = f
	Fx.haptic(8)
	refresh()


func _set_tag(t: String) -> void:
	tag = "" if tag == t else t
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


func current_collection() -> String:
	return filter if Store.get_collection(filter).size() > 0 else ""
