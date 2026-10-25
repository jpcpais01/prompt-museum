extends Node
## Walks every screen, sheet and overlay headlessly so a script error anywhere
## in the UI fails the build. Not a render test: nothing here looks at pixels.

func _ready() -> void:
	# never hang CI: a stuck walk-through fails after 40 s
	get_tree().create_timer(40.0).timeout.connect(func():
		printerr("smoke: timed out")
		get_tree().quit(1))
	get_window().mode = Window.MODE_WINDOWED
	var boot: Control = load("res://scenes/boot.tscn").instantiate()
	get_tree().root.add_child.call_deferred(boot)
	await _wait(2.6)
	var app := App.i
	assert(app != null)
	for t in ["library", "settings", "home"]:
		app.go_tab(t)
		await _wait(0.3)
	var c: Dictionary = Store.collections[0]
	app.open_collection(c.id)
	await _wait(0.5)
	var p: Dictionary = Store.in_collection(c.id)[0]
	app.open_prompt(p.id)
	await _wait(0.5)
	app.current()._more()
	await _wait(0.4)
	app.confirm("Sure?", "A question.", "Yes", func(): pass)
	await _wait(0.4)
	app.close_sheet()
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
	for view in [Store.ALL, Store.FAVS, Store.UNFILED]:
		app.open_collection(view)
		await _wait(0.3)
		app.current()._cycle_sort()
		await _wait(0.2)
		app.pop_to_root()
	app.find("smoke")
	await _wait(0.3)
	if Store.search("smoke").is_empty():
		printerr("smoke: library search found nothing")
		get_tree().quit(1)
		return
	app.find()
	await _wait(0.3)
	app.back()
	await _wait(0.2)
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
		for t in ["library", "settings", "home"]:
			app.go_tab(t)
			await _wait(0.3)
		app.open_prompt(p.id)
		await _wait(0.4)
		app.edit_collection(c.id)
		await _wait(0.4)
		app.close_sheet()
		app.pop_to_root()
		print("smoke: %s layout ok" % ("desktop" if app.desktop() else "phone"))
	# delete a wing the way a person does: Delete wing, then confirm
	var doomed := Store.put_collection({"id": Store.new_id(), "name": "Doomed", "color": Store.PALETTE[0], "glyph": Store.GLYPHS[0]})
	app.open_collection(doomed.id)
	await _wait(0.4)
	app.edit_collection(doomed.id)
	await _wait(0.4)
	app._sheet.get_meta("content")._delete()
	await _wait(0.4)
	var yes := _find_button(app._sheet, "Delete wing")
	assert(yes != null)
	yes.pressed.emit()
	await _wait(0.6)
	if not Store.get_collection(doomed.id).is_empty():
		printerr("smoke: confirming Delete wing left the wing in place")
		get_tree().quit(1)
		return
	if app.current().has_method("current_collection") and app.current().current_collection() == doomed.id:
		printerr("smoke: still inside a deleted wing")
		get_tree().quit(1)
		return
	print("smoke: wing deleted")
	if not await _scrolling(app):
		get_tree().quit(1)
		return
	app.toast("Done", "check", "Undo", func(): pass)
	await _wait(0.5)
	print("smoke: ok, %d prompts" % Store.prompts.size())
	get_tree().quit(0)


## Flicks, drags and wheels the Library (the physics, not the pixels).
func _scrolling(app: App) -> bool:
	get_window().size = Vector2i(480, 900)
	await _wait(0.3)
	app.go_tab("library")
	await _wait(0.5)
	var sc: SmoothScroll = app.current()._scroll
	sc.fling(-3000.0)
	await _wait(0.08)
	if sc._pos >= 0.0:
		printerr("smoke: a flick past the top didn't stretch")
		return false
	await _wait(1.6)
	if sc.moving() or absf(sc._pos) > 0.01:
		printerr("smoke: the stretch didn't spring back (%s)" % sc._pos)
		return false
	# a finger drag upwards (touches arrive as emulated mouse events)
	var at := sc.get_global_rect().get_center()
	_touch(at, true)
	var peak := 0.0
	for i in 10:
		at.y -= 24.0
		_drag(at)
		await get_tree().process_frame
		peak = maxf(peak, sc._pos)
	_touch(at, false)
	if peak <= 0.0:
		printerr("smoke: dragging didn't move the list")
		return false
	await _wait(2.5)
	if sc.moving() or sc._pos < -0.01 or sc._pos > sc.span() + 0.01:
		printerr("smoke: the list didn't come to rest inside its ends (%s)" % sc._pos)
		return false
	# the mouse wheel glides up a notch at a time
	var before := sc._pos
	var w := InputEventMouseButton.new()
	w.button_index = MOUSE_BUTTON_WHEEL_UP
	w.pressed = true
	w.factor = 1.0
	w.position = at
	w.global_position = at
	get_viewport().push_input(w)
	await _wait(0.6)
	if sc._pos >= before - 1.0:
		printerr("smoke: the wheel didn't scroll (%s -> %s)" % [before, sc._pos])
		return false
	print("smoke: scrolling ok")
	return true


func _touch(at: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.device = InputEvent.DEVICE_ID_EMULATION
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = at
	e.global_position = at
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	get_viewport().push_input(e)


func _drag(at: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.device = InputEvent.DEVICE_ID_EMULATION
	e.position = at
	e.global_position = at
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(e)


func _find_button(n: Node, text: String) -> Button:
	if n is Button and n.text == text:
		return n
	for ch in n.get_children():
		var b := _find_button(ch, text)
		if b:
			return b
	return null


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
