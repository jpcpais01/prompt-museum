class_name SmoothScroll
extends ScrollContainer
## A scroll that feels like a phone's: the content follows the finger, keeps
## its momentum when flicked and slows down naturally, stretches like a rubber
## band past either end and springs back. The mouse wheel glides instead of
## jumping. One shared Driver reads every touch and wheel and hands it to the
## scroll under the pointer, so drags work even when they start on a button.

## How fast a flick dies away (1/s): iOS-like, about 0.998 per millisecond.
const FRICTION := 2.1
## The rubber band past the ends: a spring that settles without wobbling.
const STIFFNESS := 190.0
const MAX_SPEED := 7000.0
## Speed carried into a bounce, so a hard flick at the end stays a nudge.
const EDGE_SPEED := 2400.0
## Mouse wheel: distance per notch, and how quickly the glide catches up (1/s).
const WHEEL_STEP := 110.0
const GLIDE := 15.0

enum Mode { IDLE, DRAG, FLING, GLIDE }

static var _driver: Node
static var _all: Array[SmoothScroll] = []

## Which way this one scrolls.
var vertical := true

var _pos := 0.0
var _vel := 0.0
var _target := 0.0
var _mode := Mode.IDLE
var _setting := false
## where the content sits after the last layout pass, before any stretch
var _base := 0.0
var _base_value := 0.0
# the drag in progress
var _finger := 0.0
var _finger_from := 0.0
var _raw_from := 0.0
var _samples: Array[Vector2] = []
var _carry := 0.0
var _caught := 0.0


func _init(is_vertical := true) -> void:
	vertical = is_vertical
	# the engine's own drag never starts: ours does the dragging
	scroll_deadzone = 1 << 30
	set_process(false)


func _ready() -> void:
	for b: ScrollBar in [get_v_scroll_bar(), get_h_scroll_bar()]:
		b.step = 0.0
	_bar().value_changed.connect(_on_value_changed)
	sort_children.connect(_on_sorted)
	_pos = _bar().value
	if _driver == null or not is_instance_valid(_driver):
		_driver = Driver.new()
		get_tree().root.add_child.call_deferred(_driver)


func _enter_tree() -> void:
	_all.append(self)


func _exit_tree() -> void:
	_all.erase(self)


func _bar() -> ScrollBar:
	return get_v_scroll_bar() if vertical else get_h_scroll_bar()


func _content() -> Control:
	for c in get_children():
		if c is Control:
			return c
	return null


## How far the content can travel.
func span() -> float:
	var b := _bar()
	return maxf(0.0, b.max_value - b.page)


func _page() -> float:
	return maxf(1.0, size.y if vertical else size.x)


## Vertical ones stretch even when everything fits, like a phone's lists.
func can_scroll() -> bool:
	return is_visible_in_tree() and (vertical or span() > 0.5)


func moving() -> bool:
	return _mode != Mode.IDLE


## Glides to a position (e.g. back to the top).
func scroll_to(to: float) -> void:
	_target = clampf(to, 0.0, span())
	_vel = 0.0
	_set_mode(Mode.GLIDE)


## Sends the content off at a speed (units per second), as a flick would.
func fling(speed: float) -> void:
	_vel = clampf(speed, -MAX_SPEED, MAX_SPEED)
	_set_mode(Mode.FLING)


func wheel(notches: float) -> void:
	if _mode != Mode.GLIDE:
		_target_from_here()
	_target = clampf(_target + notches * WHEEL_STEP, 0.0, span())
	_set_mode(Mode.GLIDE)


## A trackpad pan: follows the fingers 1:1, no smoothing to lag behind them.
func nudge(by: float) -> void:
	_pos = clampf(_pos + by, 0.0, span())
	_vel = 0.0
	_set_mode(Mode.IDLE)
	_apply()


func _target_from_here() -> void:
	_target = clampf(_pos, 0.0, span())


# ------------------------------------------------------------------ dragging

func drag_begin(at: float) -> void:
	# a flick on top of a flick in the same direction adds up
	_carry = _vel if _mode == Mode.FLING else _caught
	_caught = 0.0
	_finger = at
	_finger_from = at
	_raw_from = _unstretch(_pos)
	_samples.clear()
	_sample(at)
	_vel = 0.0
	_set_mode(Mode.DRAG)


func drag_to(at: float) -> void:
	_finger = at
	_sample(at)


func drag_end() -> void:
	if _mode != Mode.DRAG:
		return
	var now := Time.get_ticks_usec() / 1e6
	var v := 0.0
	# the finger's speed over its last few moments; held still means no flick
	if _samples.size() >= 2 and now - _samples[-1].x < 0.06:
		var a := _samples[0]
		var b := _samples[-1]
		if b.x - a.x > 0.004:
			v = -(b.y - a.y) / (b.x - a.x)
	if signf(v) == signf(_carry) and absf(v) > 400.0:
		v += _carry * 0.6
	_vel = clampf(v, -MAX_SPEED, MAX_SPEED)
	if _pos < 0.0 or _pos > span():
		_vel *= 0.4
	_set_mode(Mode.FLING)


## Stops a moving scroll under a finger that lands on it.
func catch() -> bool:
	if _mode != Mode.FLING and _mode != Mode.GLIDE:
		return false
	var fast := absf(_vel) > 120.0 or (_mode == Mode.GLIDE and absf(_target - _pos) > 8.0)
	_caught = _vel
	_vel = 0.0
	if _pos < 0.0 or _pos > span():
		# mid-bounce: let it settle, a touch shouldn't freeze it stretched
		return false
	_set_mode(Mode.IDLE)
	return fast


func _sample(at: float) -> void:
	var now := Time.get_ticks_usec() / 1e6
	_samples.append(Vector2(now, at))
	while _samples.size() > 2 and now - _samples[0].x > 0.09:
		_samples.pop_front()


# ------------------------------------------------------------------ motion

func _set_mode(m: Mode) -> void:
	_mode = m
	set_process(m != Mode.IDLE)


func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	var top := span()
	match _mode:
		Mode.DRAG:
			_pos = _stretch(_raw_from - (_finger - _finger_from))
		Mode.GLIDE:
			_pos += (_target - _pos) * (1.0 - exp(-GLIDE * delta))
			if absf(_target - _pos) < 0.3:
				_pos = _target
				_set_mode(Mode.IDLE)
		Mode.FLING:
			# small steps keep the spring steady when a frame runs long
			var steps := ceili(delta / (1.0 / 240.0))
			var dt := delta / steps
			for i in steps:
				if _pos < 0.0 or _pos > top:
					var edge := 0.0 if _pos < 0.0 else top
					var k := STIFFNESS
					_vel += (-k * (_pos - edge) - 2.0 * sqrt(k) * _vel) * dt
					_pos += _vel * dt
					# a bounce never crosses back over the edge
					if (_pos - edge) * (_pos - edge - _vel * dt) < 0.0:
						_pos = edge
						_vel = 0.0
				else:
					_vel *= exp(-FRICTION * dt)
					var was := _pos
					_pos += _vel * dt
					if (_pos < 0.0 and was >= 0.0) or (_pos > top and was <= top):
						_vel = clampf(_vel, -EDGE_SPEED, EDGE_SPEED)
			var resting := _pos >= 0.0 and _pos <= top
			if resting and absf(_vel) < 14.0:
				_set_mode(Mode.IDLE)
			elif not resting and absf(_vel) < 6.0 and minf(absf(_pos), absf(_pos - top)) < 0.4:
				_pos = clampf(_pos, 0.0, top)
				_set_mode(Mode.IDLE)
	_apply()


## Rubber band: past an end the content only follows the finger partway,
## and less the further it goes (the curve iOS uses).
func _stretch(raw: float) -> float:
	var top := span()
	var d := _page()
	if raw < 0.0:
		return -(1.0 - 1.0 / (-raw * 0.55 / d + 1.0)) * d
	if raw > top:
		return top + (1.0 - 1.0 / ((raw - top) * 0.55 / d + 1.0)) * d
	return raw


func _unstretch(pos: float) -> float:
	var top := span()
	var d := _page()
	if pos < 0.0:
		return -(1.0 / (1.0 - minf(-pos, d * 0.98) / d) - 1.0) * d / 0.55
	if pos > top:
		return top + (1.0 / (1.0 - minf(pos - top, d * 0.98) / d) - 1.0) * d / 0.55
	return pos


func _apply() -> void:
	var top := span()
	var at := clampf(_pos, 0.0, top)
	var b := _bar()
	if absf(b.value - at) > 0.001:
		_setting = true
		b.value = at
		_setting = false
	_offset_content()


## The part past the ends isn't a scroll position, so it moves the content
## itself; the next layout pass puts it back and we reapply it.
func _offset_content() -> void:
	var c := _content()
	if c == null:
		return
	var over := _pos - clampf(_pos, 0.0, span())
	var p := _base - (_bar().value - _base_value) - over
	if vertical:
		c.position.y = p
	else:
		c.position.x = p


func _on_sorted() -> void:
	var c := _content()
	if c == null:
		return
	_base = c.position.y if vertical else c.position.x
	_base_value = _bar().value
	if _pos < 0.0 or _pos > span():
		_offset_content()


## Something else moved the scroll (a layout change, the scrollbar, focus):
## take that as the new resting place.
func _on_value_changed(v: float) -> void:
	if _setting:
		return
	_pos = v
	_target = v
	if _mode != Mode.DRAG:
		_vel = 0.0
		_set_mode(Mode.IDLE)


## The one listener for every scroll: finds the scroll under the pointer and
## feeds it the wheel or the finger. Touches arrive as emulated mouse events.
class Driver extends Node:
	const SLOP := 10.0

	var _down := false
	var _from := Vector2.ZERO
	var _target: SmoothScroll
	var _decided := false

	func _init() -> void:
		name = "SmoothScrollDriver"
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _input(e: InputEvent) -> void:
		if e is InputEventMouseButton:
			_button(e)
		elif e is InputEventMouseMotion:
			_motion(e)
		elif e is InputEventPanGesture:
			var s := _pick(absf(e.delta.x) > absf(e.delta.y), false)
			if s:
				s.nudge((e.delta.y if s.vertical else e.delta.x) * 12.0)
				get_viewport().set_input_as_handled()

	func _button(e: InputEventMouseButton) -> void:
		var i := e.button_index
		if i == MOUSE_BUTTON_LEFT:
			if e.pressed:
				_down = e.device == InputEvent.DEVICE_ID_EMULATION
				_from = e.position
				_target = null
				_decided = false
				if _down:
					_catch(e.position)
			else:
				if _target and is_instance_valid(_target):
					_target.drag_end()
				_down = false
				_target = null
			return
		if not e.pressed:
			return
		var notches := e.factor if e.factor > 0.0 else 1.0
		var across := i == MOUSE_BUTTON_WHEEL_LEFT or i == MOUSE_BUTTON_WHEEL_RIGHT or e.shift_pressed
		var dir := 0.0
		if i == MOUSE_BUTTON_WHEEL_UP or i == MOUSE_BUTTON_WHEEL_LEFT:
			dir = -1.0
		elif i == MOUSE_BUTTON_WHEEL_DOWN or i == MOUSE_BUTTON_WHEEL_RIGHT:
			dir = 1.0
		if dir == 0.0:
			return
		var s := _pick(across, true)
		if s:
			s.wheel(dir * notches)
			get_viewport().set_input_as_handled()

	func _motion(e: InputEventMouseMotion) -> void:
		if not _down or (e.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			return
		if not _decided:
			var d := e.position - _from
			if d.length() < SLOP:
				return
			_decided = true
			_target = _pick(absf(d.x) > absf(d.y), true)
			if _target:
				UI.dragging = true
				_target.drag_begin(e.position.y if _target.vertical else e.position.x)
			return
		if _target and is_instance_valid(_target):
			_target.drag_to(e.position.y if _target.vertical else e.position.x)

	## The innermost scroll under the pointer that can move along that axis
	## (falling back to the other axis), unless a text box there scrolls itself.
	func _pick(across: bool, fallback: bool) -> SmoothScroll:
		# by the time a drag is told apart from a tap the GUI has seen the
		# press, so this is the control the finger (or pointer) is on
		var c := get_viewport().gui_get_hovered_control()
		var found: Array[SmoothScroll] = []
		var n: Node = c
		while n:
			if n is TextEdit and n.get_v_scroll_bar().visible:
				return null
			if n is SmoothScroll and n.can_scroll():
				found.append(n)
			n = n.get_parent()
		for s in found:
			if s.vertical != across:
				return s
		if fallback and not found.is_empty():
			return found[0]
		return null

	## A finger landing on a moving list stops it, and that touch isn't a tap.
	func _catch(at: Vector2) -> void:
		for s in SmoothScroll._all:
			if s.moving() and s.is_visible_in_tree() and s.get_global_rect().has_point(at):
				if s.catch():
					(func(): UI.dragging = true).call_deferred()
