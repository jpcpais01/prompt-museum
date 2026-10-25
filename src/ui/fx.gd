class_name Fx
extends RefCounted
## Motion: the small springs and fades that make taps feel physical.


## Buttons dip a little under the finger and spring back on release.
static func press_feedback(c: Control, depth := 0.96) -> void:
	c.button_down.connect(func():
		c.pivot_offset = c.size / 2.0
		var tw := c.create_tween()
		tw.tween_property(c, "scale", Vector2(depth, depth), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT))
	c.button_up.connect(func():
		c.pivot_offset = c.size / 2.0
		var tw := c.create_tween()
		tw.tween_property(c, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT))


## Blooms a control into place: from transparent and a touch small. (Inside a
## container the layout owns the position, so scale does the travelling.)
static func rise(c: CanvasItem, delay := 0.0, time := 0.45) -> void:
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel()
	tw.tween_property(c, "modulate:a", 1.0, time * 0.8).set_delay(delay)
	var ctrl := c as Control
	if ctrl:
		ctrl.pivot_offset = Vector2(ctrl.size.x / 2.0, ctrl.size.y)
		ctrl.scale = Vector2(0.96, 0.96)
		tw.tween_property(ctrl, "scale", Vector2.ONE, time).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Rises every child of a container in turn.
static func stagger(parent: Node, step := 0.045, start := 0.0, cap := 12) -> void:
	var i := 0
	for ch in parent.get_children():
		if ch is CanvasItem and ch.visible:
			rise(ch, start + mini(i, cap) * step)
			i += 1


## A soft heartbeat (for a favourite star or a copy tick).
static func pop(c: Control, amount := 1.25) -> void:
	c.pivot_offset = c.size / 2.0
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(amount, amount), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


static func haptic(ms := 12) -> void:
	if OS.get_name() == "Android":
		Input.vibrate_handheld(ms)
