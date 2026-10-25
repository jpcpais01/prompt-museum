extends Node
## Saves screenshots of the main screens (local layout sanity check only).

var out := OS.get_environment("SHOTS_DIR")


func _ready() -> void:
	get_window().mode = Window.MODE_WINDOWED
	var boot: Control = load("res://scenes/boot.tscn").instantiate()
	get_tree().root.add_child.call_deferred(boot)
	await _wait(0.8)
	await _shot("0_loading")
	await _wait(2.6)
	var app := App.i
	await _shot("1_home")
	app._stack[0]._scroll.scroll_vertical = 700
	await _wait(0.6)
	await _shot("2_home_scrolled")
	app.go_tab("library")
	await _wait(0.8)
	await _shot("3_library")
	var c: Dictionary = Store.collections[1]
	app.open_collection(c.id)
	await _wait(0.9)
	await _shot("4_collection")
	var p: Dictionary = Store.in_collection(c.id)[0]
	app.open_prompt(p.id)
	await _wait(0.9)
	await _shot("5_prompt")
	app.copy_prompt(p.id)
	await _wait(0.9)
	await _shot("6_fill")
	app.close_sheet()
	app.edit_prompt(p.id)
	await _wait(0.9)
	await _shot("7_editor")
	app.edit_collection(c.id)
	await _wait(0.9)
	await _shot("8_wing")
	app.close_sheet()
	app.pop_to_root()
	app.go_tab("settings")
	await _wait(0.8)
	await _shot("9_settings")
	Updater.latest = "0.1.12"
	Updater.current = "0.1.7"
	Updater._asset_size = 31457280
	Updater._state = 1
	Updater._notes = Updater.new_notes("", FileAccess.get_file_as_string("res://PATCH_NOTES.md"))
	Updater.open_overlay()
	await _wait(1.0)
	await _shot("10_update")
	Updater._swap_to_download()
	await _wait(0.8)
	Updater._ring_mat.set_shader_parameter("progress", 0.64)
	Updater._pct.text = "64%"
	Updater._dl_line.text = "19.2 of 30.0 MB  ·  4.1 MB/s  ·  3 s left"
	await _wait(0.3)
	await _shot("11_download")
	Updater.close_overlay()
	app.go_tab("search", true, {"query": "code"})
	await _wait(0.8)
	await _shot("12_search")
	get_tree().quit()


func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(n + ".png"))


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
