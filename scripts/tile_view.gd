extends Control

signal tapped(view)

const PIPS := {
	0: [],
	1: [Vector2(0.5, 0.5)],
	2: [Vector2(0.28, 0.28), Vector2(0.72, 0.72)],
	3: [Vector2(0.28, 0.28), Vector2(0.5, 0.5), Vector2(0.72, 0.72)],
	4: [Vector2(0.28, 0.28), Vector2(0.72, 0.28), Vector2(0.28, 0.72), Vector2(0.72, 0.72)],
	5: [Vector2(0.28, 0.28), Vector2(0.72, 0.28), Vector2(0.5, 0.5), Vector2(0.28, 0.72), Vector2(0.72, 0.72)],
	6: [Vector2(0.28, 0.2), Vector2(0.72, 0.2), Vector2(0.28, 0.5), Vector2(0.72, 0.5), Vector2(0.28, 0.8), Vector2(0.72, 0.8)],
}

var a := 0
var b := 0
var horizontal := false
var index := -1

func setup(a_: int, b_: int, horiz: bool, idx: int) -> void:
	a = a_
	b = b_
	horizontal = horiz
	index = idx
	custom_minimum_size = Vector2(110, 56) if horiz else Vector2(60, 112)
	mouse_filter = Control.MOUSE_FILTER_PASS if idx >= 0 else Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if index < 0:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		tapped.emit(self)

func _draw() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.97, 0.95, 0.88)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.15, 0.15, 0.15)
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	var r1: Rect2
	var r2: Rect2
	if horizontal:
		r1 = Rect2(0, 0, size.x / 2.0, size.y)
		r2 = Rect2(size.x / 2.0, 0, size.x / 2.0, size.y)
		draw_line(Vector2(size.x / 2.0, 6), Vector2(size.x / 2.0, size.y - 6), Color(0.3, 0.3, 0.3), 2.0)
	else:
		r1 = Rect2(0, 0, size.x, size.y / 2.0)
		r2 = Rect2(0, size.y / 2.0, size.x, size.y / 2.0)
		draw_line(Vector2(6, size.y / 2.0), Vector2(size.x - 6, size.y / 2.0), Color(0.3, 0.3, 0.3), 2.0)
	_pips(r1, a)
	_pips(r2, b)

func _pips(r: Rect2, n: int) -> void:
	var rad: float = minf(r.size.x, r.size.y) / 9.0
	for p in PIPS[n]:
		draw_circle(r.position + Vector2(p.x * r.size.x, p.y * r.size.y), rad, Color(0.1, 0.1, 0.1))
