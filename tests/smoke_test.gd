extends Node
## Walks every screen, sheet and overlay headlessly so a script error anywhere
## in the UI fails the build. Not a render test: nothing here looks at pixels.

func _ready() -> void:
	# never hang CI: a stuck walk-through fails after 40 s
	get_tree().create_timer(40.0).timeout.connect(func():
		printerr("smoke: timed out")
		get_tree().quit(1))
	var boot: Control = load("res://scenes/boot.tscn").instantiate()
	get_tree().root.add_child.call_deferred(boot)
	await _wait(2.6)
	var app := App.i
	assert(app != null)
	for t in ["library", "search", "settings", "home"]:
		app.go_tab(t)
		await _wait(0.3)
	var c: Dictionary = Store.collections[0]
	app.open_collection(c.id)
	await _wait(0.5)
	var p: Dictionary = Store.in_collection(c.id)[0]
	app.open_prompt(p.id)
	await _wait(0.5)
	app.copy_prompt(p.id)
	await _wait(0.5)
	app.close_sheet()
	app.copy_prompt(p.id, true)
	app.edit_collection(c.id)
	await _wait(0.5)
	app.close_sheet()
	app.edit_prompt(p.id)
	await _wait(0.5)
	app.back()
	await _wait(0.3)
	app.back()
	await _wait(0.3)
	app.edit_prompt("", c.id)
	await _wait(0.5)
	var ed := app.current()
	ed._title.text = "Smoke"
	ed._body.text = "Hello {{who}}"
	ed._add_tag("smoke, test")
	ed._save()
	await _wait(0.6)
	app.go_tab("library", true, {"filter": "fav"})
	await _wait(0.3)
	app.go_tab("search", true, {"query": "smoke"})
	await _wait(0.3)
	Updater.latest = "9.9.9"
	Updater._state = 1
	Updater._notes = Updater.new_notes("", FileAccess.get_file_as_string("res://PATCH_NOTES.md"))
	Updater.open_overlay()
	await _wait(0.5)
	Updater._swap_to_download()
	await _wait(0.5)
	Updater.close_overlay()
	app.go_tab("home")
	await _wait(0.5)
	# flip between the phone and desktop layouts mid-edit and walk every tab
	for form_size in [Vector2i(1500, 900), Vector2i(480, 900)]:
		get_window().size = form_size
		await _wait(0.3)
		app.edit_prompt(p.id)
		await _wait(0.3)
		get_window().size = Vector2i(480, 900) if form_size.x > 900 else Vector2i(1500, 900)
		await _wait(0.4)
		app.current()._title.text = "Kept"
		app.back()
		await _wait(0.3)
		app.close_sheet()
		app.pop_to_root()
		for t in ["library", "search", "settings", "home"]:
			app.go_tab(t)
			await _wait(0.3)
		app.open_prompt(p.id)
		await _wait(0.4)
		app.edit_collection(c.id)
		await _wait(0.4)
		app.close_sheet()
		app.pop_to_root()
		print("smoke: %s layout ok" % ("desktop" if app.desktop() else "phone"))
	app.toast("Done", "check", "Undo", func(): pass)
	await _wait(0.5)
	print("smoke: ok, %d prompts" % Store.prompts.size())
	get_tree().quit(0)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
