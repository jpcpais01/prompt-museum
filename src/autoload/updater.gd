extends CanvasLayer
## Updates from inside the app. A few seconds after start it asks GitHub for
## the latest release; if that's newer than this build a banner drops in. Its
## full-screen page shows what's new since your version, then downloads the
## update with a live progress ring. On Android the signed APK goes to the
## system installer; on Windows the new .exe is swapped in once the app has
## quit, and the app starts again.

const REPO := "jpcpais01/prompt-museum"
const API := "https://api.github.com/repos/%s/releases/latest" % REPO
## the patch notes as they stand in a release's tagged source
const NOTES := "https://raw.githubusercontent.com/%s/%s/PATCH_NOTES.md"
const NOTES_MAX := 40
const RECHECK := 1200.0
const AURORA := preload("res://shaders/aurora.gdshader")
const RING := preload("res://shaders/ring.gdshader")

enum State { IDLE, OFFER, DOWNLOADING, READY, FAILED }

## the answer to a check the user asked for (see check_now): "newer",
## "latest", "pending" (a release whose download isn't attached yet),
## "failed" or "unsupported" (a build that can't update itself)
signal checked(status: String, version: String)
signal found(version: String)

var current := ""
var latest := ""
var _asset_url := ""
var _asset_size := 0
var _page_url := ""
var _state := State.IDLE
var _http: HTTPRequest
var _notes_http: HTTPRequest
var _dl: HTTPRequest
var _file := ""
var _notes := ""
var _manual := false
var _banner_shown := false

# the full-screen page
var _overlay: Control
var _page_offer: Control
var _page_dl: Control
var _notes_label: RichTextLabel
var _size_label: Label
var _ring: Control
var _ring_mat: ShaderMaterial
var _pct: Label
var _dl_title: Label
var _dl_line: Label
var _dl_btn: Button
var _done_icon: Icon
var _speed_t := 0.0
var _speed_bytes := 0
var _speed := 0.0
var _shown_p := 0.0


func _ready() -> void:
	layer = 20
	current = str(ProjectSettings.get_setting("application/config/version", "0.1.0"))
	# local and editor builds carry the placeholder version and never update
	if OS.has_feature("editor") or current == "0.1.0" or not (_android() or _windows()):
		return
	_clean_old()
	_http = HTTPRequest.new()
	_http.timeout = 20.0
	_http.request_completed.connect(_on_release)
	add_child(_http)
	var t := Timer.new()
	t.wait_time = RECHECK
	t.timeout.connect(_check)
	add_child(t)
	t.start()
	get_tree().create_timer(4.0).timeout.connect(_check)


## Whether this build can update itself.
func supported() -> bool:
	return _http != null


func has_update() -> bool:
	return _state != State.IDLE and latest != ""


func overlay_open() -> bool:
	return _overlay != null


## Looks for a newer version right now (the Settings button); `checked`
## reports back, and a newer one opens its page.
func check_now() -> void:
	if not supported():
		checked.emit.call_deferred("unsupported", current)
		return
	if has_update():
		checked.emit.call_deferred("newer", latest)
		open_overlay()
		return
	_manual = true
	if _http.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
		_check()


func _android() -> bool:
	return OS.get_name() == "Android"


func _windows() -> bool:
	return OS.get_name() == "Windows"


## "0.1.57" -> [0, 1, 57]; a leading "v" is ignored.
static func parse_version(v: String) -> PackedInt32Array:
	var out := PackedInt32Array()
	for p in v.strip_edges().trim_prefix("v").split("."):
		out.append(p.to_int())
	return out


static func is_newer(a: String, b: String) -> bool:
	var x := parse_version(a)
	var y := parse_version(b)
	for i in maxi(x.size(), y.size()):
		var xi := x[i] if i < x.size() else 0
		var yi := y[i] if i < y.size() else 0
		if xi != yi:
			return xi > yi
	return false


func _dir() -> String:
	return OS.get_user_data_dir().path_join("update")


## Drop leftovers from updates that are now installed.
func _clean_old() -> void:
	var da := DirAccess.open(_dir())
	if da == null:
		return
	for f in da.get_files():
		da.remove(f)


func _check() -> void:
	if _state != State.IDLE and _state != State.OFFER:
		return
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	_http.request(API, ["User-Agent: PromptMuseum/" + current, "Accept: application/vnd.github+json"])


func _on_release(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var manual := _manual
	_manual = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		if manual:
			checked.emit("failed", current)
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if not (data is Dictionary):
		if manual:
			checked.emit("failed", current)
		return
	var tag := str(data.get("tag_name", ""))
	if tag == "" or not is_newer(tag, current):
		if manual:
			checked.emit("latest", current)
		return
	var asset := pick_asset(data.get("assets", []), ".apk" if _android() else ".exe")
	if asset.is_empty():
		# not attached yet: the next check picks it up
		if manual:
			checked.emit("pending", tag.trim_prefix("v"))
		return
	var fresh := tag.trim_prefix("v") != latest
	latest = tag.trim_prefix("v")
	_asset_url = str(asset.get("browser_download_url", ""))
	_asset_size = int(asset.get("size", 0))
	_page_url = str(data.get("html_url", ""))
	_state = State.OFFER
	if fresh or _notes == "":
		_fetch_notes(tag)
	if fresh:
		found.emit(latest)
		Store.changed.emit()
	if manual:
		checked.emit("newer", latest)
		open_overlay()
	elif fresh and not _banner_shown:
		_banner_shown = true
		_show_banner()


## The release file for this platform (an .apk or the Windows .exe).
static func pick_asset(assets: Array, ext: String) -> Dictionary:
	for a in assets:
		if a is Dictionary and str(a.get("name", "")).to_lower().ends_with(ext):
			return a
	return {}


# ------------------------------------------------------------------ what's new

func _fetch_notes(tag: String) -> void:
	if _notes_http == null:
		_notes_http = HTTPRequest.new()
		_notes_http.timeout = 20.0
		_notes_http.request_completed.connect(_on_notes)
		add_child(_notes_http)
	if _notes_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	_notes_http.request(NOTES % [REPO, tag], ["User-Agent: PromptMuseum/" + current])


func _on_notes(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var mine := ""
	if FileAccess.file_exists("res://PATCH_NOTES.md"):
		mine = FileAccess.get_file_as_string("res://PATCH_NOTES.md")
	_notes = new_notes(mine, body.get_string_from_utf8())
	if _notes_label:
		_notes_label.text = _notes if _notes != "" else "Fixes and polish."


## The entries in the newer patch notes that this build's own notes don't
## have yet, kept under their headings, as BBCode (newest first).
static func new_notes(mine: String, theirs: String) -> String:
	var have := {}
	for line in mine.split("\n"):
		if line.begins_with("- "):
			have[line.strip_edges()] = true
	var out := ""
	var head := ""
	var count := 0
	for line in theirs.split("\n"):
		if line.begins_with("## "):
			head = line.substr(3).strip_edges()
		elif line.begins_with("- ") and not have.has(line.strip_edges()):
			if count >= NOTES_MAX:
				out += "[color=#6b7385]…and more[/color]\n"
				break
			if head != "":
				out += "%s[color=#3dd6f5][b]%s[/b][/color]\n" % ["\n" if out != "" else "", head.to_upper()]
				head = ""
			out += "[indent]•  %s[/indent]\n" % line.substr(2).strip_edges().replace("[", "[lb]")
			count += 1
	return out.strip_edges()


# ------------------------------------------------------------------ banner

func _show_banner() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var card := PanelContainer.new()
	var sb := UI.box(Color(0.1, 0.105, 0.16, 0.97), 24, Color(UI.ACCENT_2, 0.35))
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 24
	sb.set_content_margin_all(12)
	sb.content_margin_left = 14
	card.add_theme_stylebox_override("panel", sb)
	root.add_child(card)
	var row := UI.hbox(12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	row.add_child(W.badge("download", UI.ACCENT_2, 42))
	var col := UI.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(UI.label("Version %s is here" % latest, 16, UI.INK, 800))
	col.add_child(UI.label("Tap to see what's new", 13, UI.SOFT, 600))
	row.add_child(col)
	var close := UI.icon_button("close", func(): _drop_banner(card), 36.0, UI.SOFT, Color(0, 0, 0, 0))
	row.add_child(close)
	var vp := root.get_viewport_rect().size
	var top: float = App.i.safe_top if App.i else 0.0
	var w := minf(440.0, vp.x - 24.0)
	card.custom_minimum_size.x = w
	card.reset_size()
	card.position = Vector2((vp.x - w) / 2.0, -card.size.y - 20)
	var tw := card.create_tween()
	tw.tween_property(card, "position:y", top + 12.0, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	UI.tap(card, func():
		_drop_banner(card)
		open_overlay())
	var ref: WeakRef = weakref(card)
	get_tree().create_timer(9.0).timeout.connect(func():
		if ref.get_ref():
			_drop_banner(ref.get_ref()))


func _drop_banner(card: Control) -> void:
	if not is_instance_valid(card) or card.get_meta("gone", false):
		return
	card.set_meta("gone", true)
	var tw := card.create_tween()
	tw.tween_property(card, "position:y", -card.size.y - 30, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(card.get_parent().queue_free)


# ------------------------------------------------------------------ the update page

func open_overlay() -> void:
	if _overlay or latest == "":
		return
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var m := ShaderMaterial.new()
	m.shader = AURORA
	m.set_shader_parameter("c1", Color("3dd6f5"))
	m.set_shader_parameter("c2", Color("8b6cff"))
	m.set_shader_parameter("c3", Color("4ade80"))
	m.set_shader_parameter("strength", 1.25)
	var vp := _overlay.get_viewport_rect().size
	m.set_shader_parameter("aspect", Vector2(vp.x / vp.y, 1.0))
	bg.material = m
	_overlay.add_child(bg)
	var top: float = App.i.safe_top if App.i else 0.0
	var bottom: float = App.i.safe_bottom if App.i else 0.0
	var gut: float = App.i.gutter() if App.i else 20.0
	var frame := MarginContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("margin_left", int(gut))
	frame.add_theme_constant_override("margin_right", int(gut))
	frame.add_theme_constant_override("margin_top", int(top + 12))
	frame.add_theme_constant_override("margin_bottom", int(bottom + 20))
	_overlay.add_child(frame)
	var stack := Control.new()
	frame.add_child(stack)
	_page_offer = _build_offer()
	_page_offer.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_page_offer)
	_page_dl = _build_download()
	_page_dl.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_page_dl)
	var downloading := _state == State.DOWNLOADING or _state == State.READY
	_page_offer.visible = not downloading
	_page_dl.visible = downloading
	_overlay.modulate.a = 0.0
	var tw := _overlay.create_tween()
	tw.tween_property(_overlay, "modulate:a", 1.0, 0.3)
	Fx.stagger(_page_offer.get_child(0), 0.05, 0.05)


func close_overlay() -> void:
	if _overlay == null:
		return
	var o := _overlay
	_overlay = null
	_notes_label = null
	var tw := o.create_tween()
	tw.tween_property(o, "modulate:a", 0.0, 0.22)
	tw.tween_callback(o.queue_free)


func _build_offer() -> Control:
	var v := UI.vbox(16)
	var root := Control.new()
	root.add_child(v)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bar := UI.hbox(8)
	bar.add_child(UI.expand())
	bar.add_child(UI.icon_button("close", close_overlay, 46.0))
	v.add_child(bar)
	v.add_child(UI.label("SOFTWARE UPDATE", 12, UI.ACCENT_2, 800))
	var t := UI.wrap("Version %s is here" % latest, 34, UI.INK, 800)
	v.add_child(t)
	_size_label = UI.wrap(_size_text(), 15, UI.SOFT, 600)
	v.add_child(_size_label)
	var panel := UI.panel(20, Color(0.07, 0.075, 0.115, 0.88))
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var pv := UI.vbox(12)
	panel.add_child(pv)
	pv.add_child(UI.label("WHAT'S NEW", 12, UI.GOLD, 800))
	var sc := UI.scroll()
	pv.add_child(sc)
	_notes_label = RichTextLabel.new()
	_notes_label.bbcode_enabled = true
	_notes_label.fit_content = true
	_notes_label.scroll_active = false
	_notes_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_notes_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_notes_label.add_theme_font_override("normal_font", UI.font(500))
	_notes_label.add_theme_font_override("bold_font", UI.font(800))
	_notes_label.add_theme_font_size_override("normal_font_size", 16)
	_notes_label.add_theme_font_size_override("bold_font_size", 12)
	_notes_label.add_theme_color_override("default_color", UI.INK)
	_notes_label.add_theme_constant_override("line_separation", 8)
	_notes_label.text = _notes if _notes != "" else "[color=#8a90a6]Loading the patch notes…[/color]"
	sc.add_child(_notes_label)
	v.add_child(panel)
	var go := UI.primary("Download & install", _start_download)
	go.custom_minimum_size.y = 58
	v.add_child(go)
	var later := UI.secondary("Not now", close_overlay)
	v.add_child(later)
	return root


func _size_text() -> String:
	var s := "You have %s" % current
	if _asset_size > 0:
		s += "  ·  %.1f MB download" % (_asset_size / 1048576.0)
	return s


func _build_download() -> Control:
	var root := Control.new()
	var v := UI.vbox(14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(v)
	var cc := CenterContainer.new()
	v.add_child(cc)
	_ring = Control.new()
	_ring.custom_minimum_size = Vector2(250, 250)
	cc.add_child(_ring)
	var ring_rect := ColorRect.new()
	ring_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ring_mat = ShaderMaterial.new()
	_ring_mat.shader = RING
	ring_rect.material = _ring_mat
	_ring.add_child(ring_rect)
	_pct = UI.label("0%", 52, UI.INK, 800)
	_pct.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pct.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ring.add_child(_pct)
	_done_icon = Icon.make("check", Color.WHITE, 84)
	_done_icon.stroke = 2.4
	Icon.center(_done_icon)
	_done_icon.visible = false
	_ring.add_child(_done_icon)
	v.add_child(UI.spacer(10))
	_dl_title = UI.label("Downloading %s" % latest, 24, UI.INK, 800)
	_dl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_dl_title)
	_dl_line = UI.label("Connecting…", 15, UI.SOFT, 600)
	_dl_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_dl_line)
	v.add_child(UI.spacer(14))
	var bc := CenterContainer.new()
	_dl_btn = UI.secondary("Cancel", _on_dl_button)
	_dl_btn.custom_minimum_size.x = 220
	bc.add_child(_dl_btn)
	v.add_child(bc)
	return root


func _swap_to_download() -> void:
	if _overlay == null:
		return
	var tw := _page_offer.create_tween()
	tw.tween_property(_page_offer, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		_page_offer.visible = false
		_page_dl.visible = true
		_page_dl.modulate.a = 0.0
		_ring.pivot_offset = _ring.size / 2.0
		_ring.scale = Vector2(0.8, 0.8)
		var t2 := _page_dl.create_tween().set_parallel()
		t2.tween_property(_page_dl, "modulate:a", 1.0, 0.3)
		t2.tween_property(_ring, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))


# ------------------------------------------------------------------ download

func _start_download() -> void:
	DirAccess.make_dir_recursive_absolute(_dir())
	_file = _dir().path_join("PromptMuseum-%s.%s" % [latest, "apk" if _android() else "exe"])
	if _dl == null:
		_dl = HTTPRequest.new()
		_dl.download_chunk_size = 262144
		_dl.request_completed.connect(_on_downloaded)
		add_child(_dl)
	_dl.download_file = _file
	_swap_to_download()
	if _dl.request(_asset_url, ["User-Agent: PromptMuseum/" + current]) != OK:
		_failed("Couldn't reach GitHub. Check your connection.")
		return
	_state = State.DOWNLOADING
	_shown_p = 0.0
	_speed_t = 0.0
	_speed_bytes = 0
	_speed = 0.0
	_set_dl_ui("Downloading %s" % latest, "Connecting…", "Cancel")
	_done_icon.visible = false
	_pct.visible = true
	_ring_mat.set_shader_parameter("spin", 1.0)


func _set_dl_ui(title: String, line: String, btn: String) -> void:
	if _dl_title == null or not is_instance_valid(_dl_title):
		return
	_dl_title.text = title
	_dl_line.text = line
	_dl_btn.text = btn


func _process(delta: float) -> void:
	if _state != State.DOWNLOADING or _dl == null:
		return
	var got := _dl.get_downloaded_bytes()
	var total := _dl.get_body_size()
	if total <= 0:
		total = _asset_size
	_speed_t += delta
	if _speed_t >= 0.5:
		var rate := (got - _speed_bytes) / _speed_t
		_speed = rate if _speed == 0.0 else lerpf(_speed, rate, 0.3)
		_speed_bytes = got
		_speed_t = 0.0
	if _overlay == null or not is_instance_valid(_ring_mat):
		return
	if total > 0 and got > 0:
		var p := float(got) / total
		_shown_p = lerpf(_shown_p, p, minf(1.0, delta * 8.0))
		_ring_mat.set_shader_parameter("spin", 0.0)
		_ring_mat.set_shader_parameter("progress", _shown_p)
		_pct.text = "%d%%" % roundi(_shown_p * 100.0)
		var line := "%.1f of %.1f MB" % [got / 1048576.0, total / 1048576.0]
		if _speed > 1024.0:
			line += "  ·  %.1f MB/s  ·  %s left" % [_speed / 1048576.0, _eta((total - got) / _speed)]
		_dl_line.text = line


static func _eta(s: float) -> String:
	if s < 60.0:
		return "%d s" % maxi(1, ceili(s))
	return "%d min" % ceili(s / 60.0)


func _on_dl_button() -> void:
	match _state:
		State.DOWNLOADING:
			_dl.cancel_request()
			_state = State.OFFER
			close_overlay()
		State.FAILED:
			_start_download()
		State.READY:
			_install()


func _failed(msg: String) -> void:
	_state = State.FAILED
	_ring_mat.set_shader_parameter("spin", 0.0)
	_set_dl_ui("Update didn't finish", msg, "Try again")


func _on_downloaded(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if _state != State.DOWNLOADING:
		return
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_failed("The download stopped (%s)." % (str(code) if code else "no connection"))
		return
	_state = State.READY
	if _overlay:
		_ring_mat.set_shader_parameter("progress", 1.0)
		_pct.visible = false
		_done_icon.visible = true
		Fx.pop(_done_icon, 1.4)
	Fx.haptic(30)
	_set_dl_ui("Ready to install", "Tap Install, then confirm" if _android() else "Prompt Museum restarts to finish", "Install" if _android() else "Restart now")
	await get_tree().create_timer(0.9).timeout
	if _state == State.READY:
		_install()


func _install() -> void:
	if _android():
		# Godot hands the path to its FileProvider and the system installer opens
		# on the APK. The first time, Android asks to allow installs from Prompt
		# Museum; the page stays up so Install can be tapped again after that.
		if OS.shell_open(_file) != OK:
			_failed("Couldn't open the installer.")
	elif _windows():
		_restart_windows()


func _restart_windows() -> void:
	var exe := OS.get_executable_path()
	var app_dir := exe.get_base_dir()
	# an app sitting somewhere read-only can't replace itself: open the release page
	var probe := app_dir.path_join(".pm_write_test")
	var fa := FileAccess.open(probe, FileAccess.WRITE)
	if fa == null:
		OS.shell_open(_page_url)
		_failed("This folder is read-only, so the download page is open instead.")
		return
	fa.close()
	DirAccess.remove_absolute(probe)
	Store.save_now()
	var pid := OS.get_process_id()
	var win := func(p: String) -> String: return p.replace("/", "\\")
	var bat := _dir().path_join("apply_update.bat")
	var lines := [
		"@echo off",
		":wait",
		"tasklist /FI \"PID eq %d\" 2>nul | find \" %d \" >nul" % [pid, pid],
		"if not errorlevel 1 (ping -n 2 127.0.0.1 >nul & goto wait)",
		"set n=0",
		":copy",
		"move /Y \"%s\" \"%s\" >nul" % [win.call(_file), win.call(exe)],
		"if not errorlevel 1 goto run",
		"set /a n+=1",
		"if %n% geq 15 goto run",
		"ping -n 2 127.0.0.1 >nul",
		"goto copy",
		":run",
		"start \"\" \"%s\"" % win.call(exe),
		"(goto) 2>nul & del \"%~f0\"",
	]
	var f := FileAccess.open(bat, FileAccess.WRITE)
	if f == null:
		_failed("Couldn't prepare the update.")
		return
	f.store_string("\r\n".join(PackedStringArray(lines)) + "\r\n")
	f.close()
	if OS.create_process("cmd.exe", ["/c", win.call(bat)]) <= 0:
		_failed("Couldn't start the updater.")
		return
	get_tree().quit()
