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
	pv.add_child(_head("chat", "What should we call you?", UI.ACCENT))
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
	uv.add_child(_head("download", "Updates", UI.ACCENT_2))
	_update_line = UI.wrap("You have version %s." % Updater.current, 15, UI.SOFT)
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
	bv.add_child(_head("upload", "Backup", UI.GOLD))
	bv.add_child(UI.wrap("Copy your whole museum as text to keep it safe or move it to another device, then paste it back with Import.", 14, UI.SOFT))
	var row := UI.hbox(10)
	var ex := UI.secondary("Copy backup", func():
		app.copy_text(Store.export_text(), "Backup copied: %s" % UI.plural(Store.prompts.size(), "prompt")))
	ex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ex)
	var im := UI.secondary("Import", _import)
	im.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(im)
	bv.add_child(row)
	if OS.get_name() == "Windows":
		bv.add_child(UI.secondary("Save backup file to Documents", _save_file))
	bk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wall.add_child(bk)

	# housekeeping
	var hk := UI.panel(18)
	var hv := UI.vbox(12)
	hk.add_child(hv)
	hv.add_child(_head("wand", "Housekeeping", UI.ACCENT))
	hv.add_child(UI.secondary("Add the sample exhibition", func():
		var keep_c := Store.collections.duplicate(true)
		var keep_p := Store.prompts.duplicate(true)
		Store.seed_samples()
		Store.collections = keep_c + Store.collections
		Store.prompts = Store.prompts + keep_p
		Store.save_soon()
		app.toast("Sample prompts added")))
	hv.add_child(UI.danger("Erase everything", func():
		app.confirm("Erase the whole museum?", "Every prompt and wing is deleted from this device. Copy a backup first if you might want them back.", "Erase all", func():
			Store.collections = []
			Store.prompts = []
			Store.save_soon()
			app.toast("The museum is empty", "trash"))))
	hk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wall.add_child(hk)

	var about := UI.vbox(4)
	var a1 := UI.label("Prompt Museum  %s" % Updater.current, 13, UI.FAINT, 700)
	a1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	about.add_child(a1)
	var a2 := UI.label("Your prompts stay on this device.", 12, UI.FAINT, 500)
	a2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	about.add_child(a2)
	body.add_child(UI.spacer(4))
	body.add_child(about)


func _head(icon: String, title: String, color: Color) -> HBoxContainer:
	var h := UI.hbox(12)
	h.add_child(W.badge(icon, color, 38))
	var l := UI.label(title, 17, UI.INK, 800)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
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
