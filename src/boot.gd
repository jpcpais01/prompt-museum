extends Control
## The loading screen. It paints instantly (one shader and a few labels),
## loads the app on a background thread, builds it underneath while this cover
## is still fully opaque, warms every shader by drawing it once off to the
## side, and only then dissolves, so the first frames of the app are smooth.

const MAIN := "res://scenes/main.tscn"
const MIN_TIME := 1.7
const LINES := ["Opening the doors", "Lighting the galleries", "Hanging your prompts", "Polishing the frames"]

var _elapsed := 0.0
var _shown := 0.0
var _line_i := 0
var _line_t := 0.0
var _fill: Panel
var _track: Panel
var _line: Label
var _logo: Control
var _glow: TextureRect
var _main: Node
var _leaving := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/aurora.gdshader")
	var vp := get_viewport_rect().size
	m.set_shader_parameter("aspect", Vector2(vp.x / vp.y, 1.0))
	m.set_shader_parameter("strength", 1.15)
	bg.material = m
	add_child(bg)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	add_child(v)

	_logo = Control.new()
	_logo.custom_minimum_size = Vector2(132, 132)
	_logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(_logo)
	_glow = TextureRect.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	g.colors = PackedColorArray([Color(0.55, 0.45, 1.0, 0.55), Color(0.3, 0.75, 1.0, 0.18), Color(0.3, 0.75, 1.0, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 128
	_glow.texture = gt
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.size = Vector2(380, 380)
	_glow.position = Vector2(66 - 190, 66 - 190)
	_glow.pivot_offset = Vector2(190, 190)
	_logo.add_child(_glow)
	var icon := TextureRect.new()
	icon.texture = load("res://icon.png")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_logo.add_child(icon)

	v.add_child(UI.spacer(30))
	var title := UI.label("Prompt Museum", 34, UI.INK, 800)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	v.add_child(UI.spacer(6))
	var tag := UI.label("Every great prompt, beautifully kept", 15, UI.SOFT, 600)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tag)
	v.add_child(UI.spacer(54))
	var tc := CenterContainer.new()
	v.add_child(tc)
	_track = Panel.new()
	_track.custom_minimum_size = Vector2(190, 4)
	_track.add_theme_stylebox_override("panel", UI.box(Color(1, 1, 1, 0.1), 2))
	tc.add_child(_track)
	_fill = Panel.new()
	_fill.add_theme_stylebox_override("panel", UI.box(UI.ACCENT_2, 2))
	_fill.size = Vector2(0, 4)
	_track.add_child(_fill)
	v.add_child(UI.spacer(16))
	_line = UI.label(LINES[0], 13, UI.FAINT, 700)
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_line)

	# warm the app's other shaders now, so they never compile mid-animation
	for sh in [preload("res://shaders/art.gdshader"), preload("res://shaders/ring.gdshader")]:
		var r := ColorRect.new()
		var sm := ShaderMaterial.new()
		sm.shader = sh
		r.material = sm
		r.size = Vector2(2, 2)
		r.position = Vector2(-10, -10)
		r.modulate.a = 0.02
		add_child(r)

	# entrance
	_logo.pivot_offset = Vector2(66, 66)
	_logo.scale = Vector2(0.86, 0.86)
	_logo.modulate.a = 0.0
	title.modulate.a = 0.0
	tag.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_logo, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_logo, "modulate:a", 1.0, 0.5)
	tw.tween_property(title, "modulate:a", 1.0, 0.6).set_delay(0.2)
	tw.tween_property(tag, "modulate:a", 1.0, 0.6).set_delay(0.35)
	ResourceLoader.load_threaded_request(MAIN, "", true)


func _process(delta: float) -> void:
	_elapsed += delta
	# breathing glow
	var b := 1.0 + 0.06 * sin(_elapsed * 2.2)
	_glow.scale = Vector2(b, b)
	_line_t += delta
	if _line_t > 0.9 and not _leaving:
		_line_t = 0.0
		_line_i = (_line_i + 1) % LINES.size()
		_line.text = LINES[_line_i]
	var target := 1.0
	if _main == null:
		# (once the scene has been taken the request is gone, so only ask before)
		var prog := [0.0]
		var st := ResourceLoader.load_threaded_get_status(MAIN, prog)
		target = prog[0] * 0.8
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			target = 0.85
			_build_main()
	_shown = lerpf(_shown, minf(target, _elapsed / MIN_TIME + 0.05), minf(1.0, delta * 6.0))
	_fill.size = Vector2(_track.size.x * _shown, 4)
	if _main and not _leaving and _elapsed >= MIN_TIME and _shown > 0.96:
		_leave()


func _build_main() -> void:
	var packed: PackedScene = ResourceLoader.load_threaded_get(MAIN)
	_main = packed.instantiate()
	var root := get_tree().root
	root.add_child(_main)
	# keep the cover on top while the app lays out beneath it
	root.move_child(self, root.get_child_count() - 1)
	get_tree().current_scene = _main


func _leave() -> void:
	_leaving = true
	_line.text = "Welcome"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween().set_parallel()
	tw.tween_property(_logo, "scale", Vector2(1.25, 1.25), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "modulate:a", 0.0, 0.55).set_delay(0.08).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_callback(queue_free)
