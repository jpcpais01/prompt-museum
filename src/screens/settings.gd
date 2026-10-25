extends Screen
## Settings: your name for the greeting, updates, backups and housekeeping.

var _update_line: Label
var _update_btn: Button


func build() -> void:
	hero_title("Make it yours", "Settings")
	# a phone stacks the panels; desktop lays them out two by two
	var wall: Container = body
	if app.desktop():
		var g := GridContainer.new()
		g.columns = 2
		g.add_theme_constant_override("h_separation", 18)
		g.add_theme_constant_override("v_separation", 18)
		body.add_child(g)
		wall = g

	# profile
	var prof := UI.panel(18)
	var pv := UI.vbox(10)
	prof.add_child(pv)
	pv.add_child(_head("chat", "Your name", UI.ACCENT, "The lobby greets you with it"))
	var name_field := UI.line_edit("Your name", str(Store.settings.get("name", "")))
	name_field.text_changed.connect(func(t: String):
		Store.settings.name = t.strip_edges()
		Store.save_soon())
	pv.add_child(name_field)
	prof.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wall.add_child(prof)

	# updates
	var up := UI.panel(18)
	var uv := UI.vbox(12)
	up.add_child(uv)
	uv.add_child(_head("download", "Updates", UI.ACCENT_2, "Version " + Updater.current))
	_update_line = UI.wrap("New versions show up here on their own. You can also check now.", 14, UI.SOFT)
	uv.add_child(_update_line)
	_update_btn = UI.secondary("Check for updates", _check)
	if Updater.has_update():
		_update_line.text = "Version %s is ready to install (you have %s)." % [Updater.latest, Updater.current]
		_update_btn = UI.primary("See what's new", func(): Updater.open_overlay())
	elif not Updater.supported():
		_update_line.text = "You have version %s. This build can't update itself; updates come with new releases on GitHub." % Updater.current
	uv.add_child(_update_btn)
	up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wall.add_child(up)

	# backup
	var bk := UI.panel(18)
	var bv := UI.vbox(12)
	bk.add_child(bv)
	bv.add_child(_head("upload", "Backup", UI.GOLD, "Keep your museum safe or move it"))
	bv.add_child(UI.action_row("copy", "Copy backup", "Your whole museum as text", func():
		app.copy_text(Store.export_text(), "Backup copied: %s" % UI.plural(Store.prompts.size(), "prompt")), UI.GOLD))
	bv.add_child(UI.action_row("download", "Import from clipboard", "Paste back a copied backup", _import, UI.GOLD))
	if OS.get_name() == "Windows":
		bv.add_child(UI.action_row("folder", "Save backup file", "Into your Documents folder", _save_file, UI.GOLD))
	bk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wall.add_child(bk)

	# housekeeping
	var hk := UI.panel(18)
	var hv := UI.vbox(12)
	hk.add_child(hv)
	hv.add_child(_head("wand", "Housekeeping", UI.ACCENT, "Samples and a fresh start"))
	hv.add_child(UI.action_row("spark", "Add the sample exhibition", "A few example prompts and wings", func():
		var keep_c := Store.collections.duplicate(true)
		var keep_p := Store.prompts.duplicate(true)
		Store.seed_samples()
		Store.collections = keep_c + Store.collections
		Store.prompts = Store.prompts + keep_p
		Store.save_soon()
		app.toast("Sample prompts added")))
	hv.add_child(UI.action_row("trash", "Erase everything", "Every prompt and wing on this device", func():
		app.confirm("Erase the whole museum?", "Every prompt and wing is deleted from this device. Copy a backup first if you might want them back.", "Erase all", func():
			Store.collections = []
			Store.prompts = []
			Store.save_soon()
			app.toast("The museum is empty", "trash")), UI.DANGER, true))
	hk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wall.add_child(hk)

	# the colophon: the mark, the version, and where your prompts live
	var about := UI.vbox(6)
	about.alignment = BoxContainer.ALIGNMENT_CENTER
	var mark := TextureRect.new()
	mark.texture = load("res://icon.png")
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.custom_minimum_size = Vector2(40, 40)
	mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mark.modulate.a = 0.85
	about.add_child(mark)
	var a1 := UI.label("Prompt Museum", 14, UI.SOFT, 800)
	a1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	about.add_child(a1)
	var lock := UI.hbox(6)
	lock.alignment = BoxContainer.ALIGNMENT_CENTER
	lock.add_child(UI.pill(Updater.current, UI.SOFT))
	lock.add_child(UI.label("Your prompts stay on this device", 12, UI.FAINT, 600))
	about.add_child(lock)
	body.add_child(UI.spacer(10))
	body.add_child(about)


func _head(icon: String, title: String, color: Color, sub := "") -> HBoxContainer:
	var h := UI.hbox(12)
	h.add_child(W.badge(icon, color, 42))
	var t := UI.vbox(0)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.add_child(UI.label(title, 17, UI.INK, 800))
	if sub != "":
		t.add_child(UI.label(sub, 13, UI.FAINT, 600))
	h.add_child(t)
	return h


func _check() -> void:
	_update_line.text = "Checking…"
	_update_btn.disabled = true
	if not Updater.checked.is_connected(_on_checked):
		Updater.checked.connect(_on_checked, CONNECT_ONE_SHOT)
	Updater.check_now()


func _on_checked(status: String, version: String) -> void:
	if not is_instance_valid(_update_line):
		return
	_update_btn.disabled = false
	match status:
		"newer":
			_update_line.text = "Version %s is available." % version
		"latest":
			_update_line.text = "You're on the latest version (%s)." % version
		"pending":
			_update_line.text = "Version %s is being published. Try again in a few minutes." % version
		"unsupported":
			_update_line.text = "This build can't update itself (version %s)." % version
		_:
			_update_line.text = "Couldn't reach GitHub. Check your connection and try again."


func _import() -> void:
	var text := DisplayServer.clipboard_get()
	var n := Store.import_text(text)
	if n < 0:
		app.toast("Copy a Prompt Museum backup first", "info")
		return
	app.toast("Imported %s" % UI.plural(n, "prompt"), "download")


func _save_file() -> void:
	var dir := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	var d := Time.get_date_dict_from_system()
	var path := dir.path_join("Prompt Museum backup %04d-%02d-%02d.json" % [d.year, d.month, d.day])
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		app.toast("Couldn't write to Documents", "info")
		return
	f.store_string(Store.export_text())
	f.close()
	app.toast("Saved to Documents", "check")
