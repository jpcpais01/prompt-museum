class_name Icon
extends Control
## Crisp line icons drawn with vector strokes, so they stay sharp at any size
## and cost no textures. Every icon lives on a 24×24 grid scaled to fit.
##
## Strokes are built in real screen pixels rather than in the scaled UI space:
## Godot feathers antialiased lines by a fixed amount in whatever space they're
## drawn in, so drawing through the 2-3× phone stretch smeared every edge.
## Straight lines and box corners are snapped to the pixel grid, the way fonts
## are hinted, and the icon re-snaps once it stops moving.

var glyph := "spark"
var color := UI.INK:
	set(v):
		color = v
		queue_redraw()
var stroke := 2.0

var _o := Vector2.ZERO  # top-left of the 24-grid, in screen pixels
var _k := 1.0  # screen pixels per grid unit
var _w := 1.0  # stroke width in screen pixels
var _odd := true  # odd widths sit on pixel centres, even ones on pixel edges
var _moved_at := 0


static func make(g: String, tint := UI.INK, px := 22.0) -> Icon:
	var i := Icon.new()
	i.glyph = g
	i.color = tint
	px = roundf(px)
	i.custom_minimum_size = Vector2(px, px)
	i.size = Vector2(px, px)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return i


## Pins an icon to the middle of whatever it's added to.
static func center(i: Control) -> void:
	var h := i.custom_minimum_size / 2.0
	i.anchor_left = 0.5
	i.anchor_right = 0.5
	i.anchor_top = 0.5
	i.anchor_bottom = 0.5
	i.offset_left = -h.x
	i.offset_right = h.x
	i.offset_top = -h.y
	i.offset_bottom = h.y


func set_glyph(g: String) -> void:
	glyph = g
	queue_redraw()


func _ready() -> void:
	set_notify_transform(true)
	set_process(false)
	get_viewport().size_changed.connect(queue_redraw)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		# Moving geometry stays smooth; snap again once it comes to rest.
		_moved_at = Time.get_ticks_msec()
		set_process(true)
	elif what == NOTIFICATION_RESIZED:
		queue_redraw()


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() - _moved_at > 90:
		set_process(false)
		queue_redraw()


# --- Drawing helpers. Points come in on the 24-grid and leave in screen pixels.

func _p(x: float, y: float) -> Vector2:
	return _o + Vector2(x, y) * _k


func _snap(v: Vector2) -> Vector2:
	if _odd:
		return (v - Vector2(0.5, 0.5)).round() + Vector2(0.5, 0.5)
	return v.round()


func _ps(q: Vector2) -> Vector2:
	return _snap(_p(q.x, q.y))


## An open or closed path; repeat the first point at the end to close it.
## Snapped by default; curves sampled into many points pass snap = false.
func _line(pts: Array, snap := true) -> void:
	var out := PackedVector2Array()
	for q in pts:
		out.append(_ps(q) if snap else _p(q.x, q.y))
	draw_polyline(out, color, _w, true)


func _seg(a: Vector2, b: Vector2) -> void:
	_line([a, b])


func _arc(c: Vector2, r: float, a0: float, a1: float) -> void:
	var n := clampi(int(absf(a1 - a0) * r * _k / 2.0), 12, 64)
	draw_arc(_ps(c), r * _k, a0, a1, n, color, _w, true)


func _circle(c: Vector2, r: float) -> void:
	_arc(c, r, 0.0, TAU)


func _dot(c: Vector2, r: float) -> void:
	draw_circle(_ps(c), maxf(r * _k, _w * 0.6), color, true, -1.0, true)


func _fill(pts: Array) -> void:
	var out := PackedVector2Array()
	for q in pts:
		out.append(_p(q.x, q.y))
	draw_colored_polygon(out, color)


## Points of a quarter-circle corner, on the grid.
func _corner(c: Vector2, r: float, a0: float) -> Array:
	var pts := []
	for k in 7:
		var a := a0 + k * (PI / 2) / 6.0
		pts.append(Vector2(c.x + cos(a) * r, c.y + sin(a) * r))
	return pts


## A rounded box. Its edges are snapped first and the corners built in screen
## pixels, so all four sides land equally sharp.
func _rrect(x: float, y: float, w: float, h: float, r: float) -> void:
	var a := _ps(Vector2(x, y))
	var b := _ps(Vector2(x + w, y + h))
	var rr := r * _k
	var cs := [[Vector2(b.x - rr, a.y + rr), -PI / 2], [Vector2(b.x - rr, b.y - rr), 0.0], [Vector2(a.x + rr, b.y - rr), PI / 2], [Vector2(a.x + rr, a.y + rr), PI]]
	var out := PackedVector2Array()
	for c in cs:
		for k in 7:
			var t: float = c[1] + k * (PI / 2) / 6.0
			out.append(c[0] + Vector2(cos(t), sin(t)) * rr)
	out.append(out[0])
	draw_polyline(out, color, _w, true)


## Samples a cubic Bézier into grid points (drop the first to chain curves).
func _bez(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, n := 10) -> Array:
	var pts := []
	for k in n + 1:
		var t := float(k) / n
		var u := 1.0 - t
		pts.append(p0 * u * u * u + p1 * 3.0 * u * u * t + p2 * 3.0 * u * t * t + p3 * t * t * t)
	return pts


func _star(filled: bool) -> void:
	var pts := []
	for k in 10:
		var a := -PI / 2 + k * PI / 5
		var r := 9.5 if k % 2 == 0 else 4.4
		pts.append(Vector2(12 + cos(a) * r, 12.8 + sin(a) * r))
	if filled:
		_fill(pts)
	pts.append(pts[0])
	_line(pts, false)


func _heart(filled: bool) -> void:
	var pts := []
	for k in 41:
		var t := TAU * k / 40.0
		var x := 16 * pow(sin(t), 3)
		var y := 13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)
		pts.append(Vector2(12 + x * 0.55, 11 - y * 0.55))
	if filled:
		_fill(pts)
	_line(pts, false)


## An arrowhead at the end of a circular arc, pointing along it.
func _arc_head(c: Vector2, r: float, a: float, dir: float) -> void:
	var tip := Vector2(c.x + cos(a) * r, c.y + sin(a) * r)
	var t := Vector2(-sin(a), cos(a)) * dir * 3.6
	var n := Vector2(cos(a), sin(a)) * 3.6
	_line([tip - t + n, tip, tip - t - n], false)


func _draw() -> void:
	if not is_inside_tree():
		return
	# Draw in screen pixels: undo the UI transform, then rebuild the grid there.
	var xf := get_viewport().get_final_transform() * get_global_transform_with_canvas()
	draw_set_transform_matrix(xf.affine_inverse())
	var side := minf(size.x, size.y)
	_k = side * xf.get_scale().x / 24.0
	_o = xf * ((size - Vector2(side, side)) / 2.0)
	# The antialiasing feather adds about a pixel of visual weight, so the
	# solid core is a little thinner than the stroke it stands for.
	_w = maxf(1.0, roundf(stroke * _k - 0.9))
	_odd = int(_w) % 2 == 1
	var V := func(x, y): return Vector2(x, y)
	match glyph:
		"home":
			_line([V.call(3.5, 11.5), V.call(12, 4.5), V.call(20.5, 11.5)])
			_line([V.call(5.5, 10), V.call(5.5, 20), V.call(18.5, 20), V.call(18.5, 10)])
			_line([V.call(10, 20), V.call(10, 15), V.call(14, 15), V.call(14, 20)])
		"museum":
			_line([V.call(3, 9.5), V.call(12, 4), V.call(21, 9.5), V.call(3, 9.5)])
			for x in [6.5, 12.0, 17.5]:
				_seg(V.call(x, 12.5), V.call(x, 17))
			_seg(V.call(3, 20), V.call(21, 20))
		"library":
			_rrect(3, 4, 4, 16, 1)
			_rrect(9, 4, 4, 16, 1)
			# A third book leaning on the others, resting on its bottom corner.
			_line([V.call(18.9, 20), V.call(15.0, 19.3), V.call(17.7, 4.5), V.call(21.6, 5.2), V.call(18.9, 20)], false)
		"search":
			_circle(V.call(10.5, 10.5), 6.5)
			_seg(V.call(15.3, 15.3), V.call(20.5, 20.5))
		"gear":
			_circle(V.call(12, 12), 3)
			var pts := []
			for i in 8:
				var a := TAU * i / 8.0
				for k in 4:
					var b := a + 0.23 + (TAU / 8.0 - 0.46) * k / 3.0
					pts.append(Vector2(12 + cos(b) * 7.2, 12 + sin(b) * 7.2))
				var nx := a + TAU / 8.0
				pts.append(Vector2(12 + cos(nx - 0.15) * 9.6, 12 + sin(nx - 0.15) * 9.6))
				pts.append(Vector2(12 + cos(nx + 0.15) * 9.6, 12 + sin(nx + 0.15) * 9.6))
			pts.append(pts[0])
			_line(pts, false)
		"plus":
			_seg(V.call(12, 5), V.call(12, 19))
			_seg(V.call(5, 12), V.call(19, 12))
		"close":
			_seg(V.call(6, 6), V.call(18, 18))
			_seg(V.call(18, 6), V.call(6, 18))
		"back":
			_line([V.call(15, 5), V.call(8, 12), V.call(15, 19)])
		"chevron":
			_line([V.call(9, 5), V.call(16, 12), V.call(9, 19)])
		"down":
			_line([V.call(5, 9), V.call(12, 16), V.call(19, 9)])
		"star":
			_star(false)
		"star_on":
			_star(true)
		"heart":
			_heart(false)
		"heart_on":
			_heart(true)
		"copy", "duplicate":
			_rrect(9, 9, 11.5, 11.5, 2.5)
			var back := [V.call(6.5, 15.5)] + _corner(V.call(6.5, 13), 2.5, PI / 2) + _corner(V.call(6.5, 6.5), 2.5, PI) + _corner(V.call(13, 6.5), 2.5, -PI / 2)
			_line(back, false)
			if glyph == "duplicate":
				_seg(V.call(14.75, 12), V.call(14.75, 17.5))
				_seg(V.call(12, 14.75), V.call(17.5, 14.75))
		"edit":
			_line([V.call(4, 20), V.call(4.5, 16), V.call(15.5, 5), V.call(19, 8.5), V.call(8, 19.5), V.call(4, 20)])
			_seg(V.call(13, 7.5), V.call(16.5, 11))
		"trash":
			_seg(V.call(4, 6.5), V.call(20, 6.5))
			_line([V.call(9, 6.5), V.call(9.5, 4), V.call(14.5, 4), V.call(15, 6.5)])
			_line([V.call(6, 6.5), V.call(7, 20), V.call(17, 20), V.call(18, 6.5)])
			_seg(V.call(10, 10.5), V.call(10, 16))
			_seg(V.call(14, 10.5), V.call(14, 16))
		"tag":
			_line([V.call(3.5, 12.5), V.call(3.5, 4), V.call(12, 4), V.call(20.5, 12.5), V.call(12.5, 20.5), V.call(3.5, 12.5)])
			_dot(V.call(8, 8.5), 1.5)
		"folder":
			_line([V.call(3, 5.5), V.call(10, 5.5), V.call(12, 8.5), V.call(21, 8.5), V.call(21, 19), V.call(3, 19), V.call(3, 5.5)])
		"download":
			_seg(V.call(12, 3.5), V.call(12, 15))
			_line([V.call(7, 10), V.call(12, 15), V.call(17, 10)])
			_line([V.call(4, 15), V.call(4, 20), V.call(20, 20), V.call(20, 15)])
		"upload":
			_seg(V.call(12, 15), V.call(12, 3.5))
			_line([V.call(7, 8.5), V.call(12, 3.5), V.call(17, 8.5)])
			_line([V.call(4, 15), V.call(4, 20), V.call(20, 20), V.call(20, 15)])
		"check":
			_line([V.call(5, 12.5), V.call(10, 17.5), V.call(19.5, 7)])
		"sort":
			_seg(V.call(4, 7), V.call(20, 7))
			_seg(V.call(7, 12), V.call(17, 12))
			_seg(V.call(10, 17), V.call(14, 17))
		"wand":
			_seg(V.call(4, 20), V.call(15, 9))
			_line([V.call(17, 3), V.call(17.8, 5.2), V.call(20, 6), V.call(17.8, 6.8), V.call(17, 9), V.call(16.2, 6.8), V.call(14, 6), V.call(16.2, 5.2), V.call(17, 3)], false)
			_dot(V.call(20.5, 12), 1.0)
			_dot(V.call(11, 4), 1.0)
		"refresh":
			_arc(V.call(12, 12), 7.5, -PI * 0.5 + 0.45, PI * 1.5 - 0.05)
			_arc_head(V.call(12, 12), 7.5, PI * 1.5 - 0.05, 1.0)
		"info":
			_circle(V.call(12, 12), 8.5)
			_seg(V.call(12, 11), V.call(12, 16.5))
			_dot(V.call(12, 7.7), 1.3)
		"spark":
			_line([V.call(12, 3), V.call(13.8, 10.2), V.call(21, 12), V.call(13.8, 13.8), V.call(12, 21), V.call(10.2, 13.8), V.call(3, 12), V.call(10.2, 10.2), V.call(12, 3)], false)
		"code":
			_line([V.call(8, 6.5), V.call(3, 12), V.call(8, 17.5)])
			_line([V.call(16, 6.5), V.call(21, 12), V.call(16, 17.5)])
			_seg(V.call(13.5, 4.5), V.call(10.5, 19.5))
		"pen":
			_line([V.call(12, 3), V.call(18, 12), V.call(12, 21), V.call(6, 12), V.call(12, 3)])
			_seg(V.call(12, 3), V.call(12, 10.5))
			_circle(V.call(12, 12.3), 1.6)
		"image":
			_rrect(3, 4.5, 18, 15, 3)
			_line([V.call(3.5, 17), V.call(9, 11.5), V.call(13, 15.5), V.call(15.5, 13), V.call(20.5, 18)])
			_circle(V.call(15.5, 9), 1.7)
		"chat":
			# Bubble and tail as one outline, so they meet without a seam.
			var b := _corner(V.call(17.5, 7.5), 3.5, -PI / 2) + _corner(V.call(17.5, 14), 3.5, 0.0)
			b += [V.call(10.5, 17.5), V.call(6, 21), V.call(6.5, 17.5)]
			b += _corner(V.call(6.5, 14), 3.5, PI / 2) + _corner(V.call(6.5, 7.5), 3.5, PI)
			b.append(b[0])
			_line(b, false)
		"brain":
			# Two lobes with a soft, bumpy outline and a seam down the middle.
			var l := _bez(V.call(12, 5.5), V.call(10.5, 3.2), V.call(6.5, 3.6), V.call(6.2, 6.8))
			l += _bez(V.call(6.2, 6.8), V.call(3.2, 7.4), V.call(2.8, 11.6), V.call(4.6, 12.8)).slice(1)
			l += _bez(V.call(4.6, 12.8), V.call(2.8, 15), V.call(4.5, 18.6), V.call(7.5, 18.2)).slice(1)
			l += _bez(V.call(7.5, 18.2), V.call(8.5, 20.8), V.call(11.6, 20.8), V.call(12, 18.8)).slice(1)
			_line(l, false)
			var r := []
			for q in l:
				r.append(Vector2(24.0 - q.x, q.y))
			_line(r, false)
			_seg(V.call(12, 5.5), V.call(12, 18.8))
			_line(_bez(V.call(12, 11), V.call(10.5, 11.5), V.call(8.5, 11), V.call(7.8, 9.2), 6), false)
			_line(_bez(V.call(12, 14.5), V.call(13.5, 15), V.call(15.5, 14.5), V.call(16.2, 12.8), 6), false)
		"music":
			_line([V.call(9, 17.5), V.call(9, 5), V.call(20, 3), V.call(20, 15.5)])
			_circle(V.call(6.5, 17.5), 2.6)
			_circle(V.call(17.5, 15.5), 2.6)
		"briefcase":
			_rrect(3, 7.5, 18, 12.5, 2.5)
			_line([V.call(9, 7.5), V.call(9, 4.5), V.call(15, 4.5), V.call(15, 7.5)])
			_seg(V.call(3, 13), V.call(21, 13))
		"book":
			_line([V.call(12, 6.5), V.call(7, 4.5), V.call(3, 5), V.call(3, 18.5), V.call(7, 18), V.call(12, 20), V.call(17, 18), V.call(21, 18.5), V.call(21, 5), V.call(17, 4.5), V.call(12, 6.5), V.call(12, 20)])
		"bolt":
			_line([V.call(13.5, 2.5), V.call(5, 13.5), V.call(11.5, 13.5), V.call(10.5, 21.5), V.call(19, 10.5), V.call(12.5, 10.5), V.call(13.5, 2.5)], false)
		"globe":
			_circle(V.call(12, 12), 8.5)
			_seg(V.call(3.5, 12), V.call(20.5, 12))
			var pts := []
			for k in 49:
				var a := -PI / 2 + TAU * k / 48.0
				pts.append(Vector2(12 + cos(a) * 3.8, 12 + sin(a) * 8.5))
			_line(pts, false)
		"clock":
			_circle(V.call(12, 12), 8.5)
			_line([V.call(12, 7), V.call(12, 12), V.call(15.5, 14)])
		"fire":
			# A teardrop flame with a smaller flame burning inside it.
			var f := _bez(V.call(12, 21), V.call(16.5, 21), V.call(18.6, 17.6), V.call(18, 14))
			f += _bez(V.call(18, 14), V.call(17.4, 10.2), V.call(13.6, 8.2), V.call(12, 3)).slice(1)
			f += _bez(V.call(12, 3), V.call(10.8, 7.4), V.call(5.8, 9.6), V.call(6, 14)).slice(1)
			f += _bez(V.call(6, 14), V.call(6.2, 18.2), V.call(8.2, 21), V.call(12, 21)).slice(1)
			_line(f, false)
			var g := _bez(V.call(12, 21), V.call(14.4, 21), V.call(15.2, 18.6), V.call(14.4, 16.8), 8)
			g += _bez(V.call(14.4, 16.8), V.call(13.6, 15.2), V.call(12.4, 14.8), V.call(12, 13), 8).slice(1)
			g += _bez(V.call(12, 13), V.call(11.4, 15), V.call(9, 16), V.call(9.4, 18.2), 8).slice(1)
			g += _bez(V.call(9.4, 18.2), V.call(9.8, 20.4), V.call(11, 21), V.call(12, 21), 8).slice(1)
			_line(g, false)
		"filter":
			_line([V.call(3.5, 5), V.call(20.5, 5), V.call(14, 12.5), V.call(14, 19), V.call(10, 20.5), V.call(10, 12.5), V.call(3.5, 5)])
		"variable":
			_line([V.call(8, 4), V.call(5.5, 4.5), V.call(5.5, 10), V.call(3, 12), V.call(5.5, 14), V.call(5.5, 19.5), V.call(8, 20)])
			_line([V.call(16, 4), V.call(18.5, 4.5), V.call(18.5, 10), V.call(21, 12), V.call(18.5, 14), V.call(18.5, 19.5), V.call(16, 20)])
			_dot(V.call(12, 12), 1.6)
		"more":
			for x in [5.5, 12.0, 18.5]:
				_dot(V.call(x, 12), 1.7)
		_:
			_circle(V.call(12, 12), 8)
