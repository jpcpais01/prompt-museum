class_name Icon
extends Control
## Crisp line icons drawn with vector strokes, so they stay sharp at any size
## and cost no textures. Every icon lives on a 24×24 grid scaled to fit.

var glyph := "spark"
var color := UI.INK:
	set(v):
		color = v
		queue_redraw()
var stroke := 2.0


static func make(g: String, tint := UI.INK, px := 22.0) -> Icon:
	var i := Icon.new()
	i.glyph = g
	i.color = tint
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


func _p(x: float, y: float) -> Vector2:
	var s := minf(size.x, size.y) / 24.0
	var o := (size - Vector2(24, 24) * s) / 2.0
	return o + Vector2(x, y) * s


func _w() -> float:
	return maxf(1.2, stroke * minf(size.x, size.y) / 24.0)


func _line(pts: Array) -> void:
	var out := PackedVector2Array()
	for q in pts:
		out.append(_p(q.x, q.y))
	draw_polyline(out, color, _w(), true)


func _seg(a: Vector2, b: Vector2) -> void:
	draw_line(_p(a.x, a.y), _p(b.x, b.y), color, _w(), true)


func _arc(c: Vector2, r: float, a0: float, a1: float) -> void:
	var s := minf(size.x, size.y) / 24.0
	draw_arc(_p(c.x, c.y), r * s, a0, a1, 32, color, _w(), true)


func _circle(c: Vector2, r: float) -> void:
	_arc(c, r, 0.0, TAU)


func _dot(c: Vector2, r: float) -> void:
	var s := minf(size.x, size.y) / 24.0
	draw_circle(_p(c.x, c.y), r * s, color, true, -1.0, true)


func _fill(pts: Array) -> void:
	var out := PackedVector2Array()
	for q in pts:
		out.append(_p(q.x, q.y))
	draw_colored_polygon(out, color)


func _rrect(x: float, y: float, w: float, h: float, r: float) -> void:
	var pts := []
	var corners := [[x + w - r, y + r, -PI / 2], [x + w - r, y + h - r, 0.0], [x + r, y + h - r, PI / 2], [x + r, y + r, PI]]
	for c in corners:
		for k in 7:
			var a: float = c[2] + k * (PI / 2) / 6.0
			pts.append(Vector2(c[0] + cos(a) * r, c[1] + sin(a) * r))
	pts.append(pts[0])
	_line(pts)


func _star(filled: bool) -> void:
	var pts := []
	for k in 10:
		var a := -PI / 2 + k * PI / 5
		var r := 9.5 if k % 2 == 0 else 4.2
		pts.append(Vector2(12 + cos(a) * r, 12.6 + sin(a) * r))
	if filled:
		_fill(pts)
	pts.append(pts[0])
	_line(pts)


func _heart(filled: bool) -> void:
	var pts := []
	for k in 41:
		var t := TAU * k / 40.0
		var x := 16 * pow(sin(t), 3)
		var y := 13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)
		pts.append(Vector2(12 + x * 0.55, 11 - y * 0.55))
	if filled:
		_fill(pts)
	_line(pts)


func _draw() -> void:
	var V := func(x, y): return Vector2(x, y)
	match glyph:
		"home":
			_line([V.call(3.5, 11), V.call(12, 4), V.call(20.5, 11)])
			_line([V.call(5.5, 9.5), V.call(5.5, 20), V.call(18.5, 20), V.call(18.5, 9.5)])
			_line([V.call(10, 20), V.call(10, 14.5), V.call(14, 14.5), V.call(14, 20)])
		"museum":
			_line([V.call(3, 9), V.call(12, 3.5), V.call(21, 9), V.call(3, 9)])
			for x in [6.0, 10.0, 14.0, 18.0]:
				_seg(V.call(x, 11), V.call(x, 17.5))
			_seg(V.call(3, 20), V.call(21, 20))
		"library":
			_rrect(3.5, 4, 5, 16, 1.2)
			_rrect(9.5, 4, 5, 16, 1.2)
			_line([V.call(16.2, 5.2), V.call(20.6, 4.2), V.call(21, 19), V.call(17.4, 19.9), V.call(16.2, 5.2)])
		"search":
			_circle(V.call(10.5, 10.5), 6.5)
			_seg(V.call(15.4, 15.4), V.call(20.5, 20.5))
		"gear":
			_circle(V.call(12, 12), 3.2)
			var pts := []
			for k in 49:
				var a := TAU * k / 48.0
				var tooth := 1.0 if (k % 6) < 3 else 0.0
				var r := 7.0 + tooth * 1.8
				pts.append(Vector2(12 + cos(a + 0.26) * r, 12 + sin(a + 0.26) * r))
			_line(pts)
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
		"copy":
			_rrect(8.5, 8.5, 11.5, 11.5, 2.5)
			_line([V.call(15.5, 5.5), V.call(15.5, 5), V.call(6.5, 4), V.call(4, 4.6), V.call(4, 14), V.call(5.5, 15.5)])
		"edit":
			_line([V.call(4, 20), V.call(4.6, 15.6), V.call(15.6, 4.6), V.call(19.4, 8.4), V.call(8.4, 19.4), V.call(4, 20)])
			_seg(V.call(13.2, 7), V.call(17, 10.8))
		"trash":
			_seg(V.call(4, 6.5), V.call(20, 6.5))
			_line([V.call(9, 6.5), V.call(9.6, 3.8), V.call(14.4, 3.8), V.call(15, 6.5)])
			_line([V.call(6, 6.5), V.call(7, 20), V.call(17, 20), V.call(18, 6.5)])
			_seg(V.call(10, 10.5), V.call(10, 16))
			_seg(V.call(14, 10.5), V.call(14, 16))
		"duplicate":
			_rrect(8, 8, 12, 12, 2.5)
			_rrect(4, 4, 12, 12, 2.5)
		"tag":
			_line([V.call(3.5, 12.5), V.call(3.5, 4), V.call(12, 4), V.call(20.5, 12.5), V.call(12.5, 20.5), V.call(3.5, 12.5)])
			_dot(V.call(8, 8.5), 1.5)
		"folder":
			_line([V.call(3, 7), V.call(3, 19), V.call(21, 19), V.call(21, 8.5), V.call(12, 8.5), V.call(10, 5.5), V.call(3, 5.5), V.call(3, 7)])
		"download":
			_seg(V.call(12, 3.5), V.call(12, 15))
			_line([V.call(7, 10.5), V.call(12, 15.5), V.call(17, 10.5)])
			_line([V.call(4, 15), V.call(4, 20), V.call(20, 20), V.call(20, 15)])
		"upload":
			_seg(V.call(12, 15.5), V.call(12, 4))
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
			_line([V.call(17, 3), V.call(17.8, 5.2), V.call(20, 6), V.call(17.8, 6.8), V.call(17, 9), V.call(16.2, 6.8), V.call(14, 6), V.call(16.2, 5.2), V.call(17, 3)])
			_dot(V.call(20.5, 12), 1.0)
			_dot(V.call(11, 4), 1.0)
		"refresh":
			_arc(V.call(12, 12), 7.5, -PI * 0.15, PI * 1.55)
			_line([V.call(19.5, 4.5), V.call(19.6, 9.6), V.call(14.5, 9.3)])
		"info":
			_circle(V.call(12, 12), 8.5)
			_seg(V.call(12, 11), V.call(12, 16.5))
			_dot(V.call(12, 7.7), 1.3)
		"spark":
			_line([V.call(12, 3), V.call(13.8, 10.2), V.call(21, 12), V.call(13.8, 13.8), V.call(12, 21), V.call(10.2, 13.8), V.call(3, 12), V.call(10.2, 10.2), V.call(12, 3)])
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
			_line([V.call(7.5, 17.5), V.call(4, 20.5), V.call(4.6, 16.4)])
			_rrect(3, 4, 18, 13.5, 4)
		"brain":
			_arc(V.call(9, 9), 4.5, PI * 0.8, PI * 2.0)
			_arc(V.call(15, 9), 4.5, PI, PI * 2.2)
			_arc(V.call(8, 14.5), 4.3, PI * 0.5, PI * 1.4)
			_arc(V.call(16, 14.5), 4.3, -PI * 0.4, PI * 0.5)
			_seg(V.call(12, 6), V.call(12, 19.5))
			_line([V.call(8, 18.8), V.call(12, 19.5), V.call(16, 18.8)])
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
			_line([V.call(13.5, 2.5), V.call(5, 13.5), V.call(11.5, 13.5), V.call(10.5, 21.5), V.call(19, 10.5), V.call(12.5, 10.5), V.call(13.5, 2.5)])
		"globe":
			_circle(V.call(12, 12), 8.5)
			_seg(V.call(3.5, 12), V.call(20.5, 12))
			var pts := []
			for k in 25:
				var a := -PI / 2 + PI * k / 24.0
				pts.append(Vector2(12 + cos(a) * 3.8, 12 + sin(a) * 8.5))
			_line(pts)
			var pts2 := []
			for k in 25:
				var a := PI / 2 + PI * k / 24.0
				pts2.append(Vector2(12 + cos(a) * 3.8, 12 + sin(a) * 8.5))
			_line(pts2)
		"clock":
			_circle(V.call(12, 12), 8.5)
			_line([V.call(12, 7), V.call(12, 12), V.call(15.5, 14)])
		"fire":
			_line([V.call(12, 21), V.call(7.5, 19), V.call(6, 14.5), V.call(8.5, 9.5), V.call(9.5, 12.5), V.call(11.5, 3), V.call(15.5, 8.5), V.call(18, 14), V.call(16.5, 19), V.call(12, 21)])
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
