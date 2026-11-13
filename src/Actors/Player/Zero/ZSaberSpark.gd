extends Node2D

# Impact flash where a saber hit lands: a white core, an expanding ring and a
# burst of short rays, all gone in a fraction of a second.

var lifetime := 0.16
var size := 1.0
var timer := 0.0
var ray_angles := []

func setup(_size: float) -> void:
	size = _size
	z_index = 8
	z_as_relative = false
	var base := randf() * 45.0
	for i in 6:
		ray_angles.append(deg2rad(base + i * 60.0 + rand_range(-12.0, 12.0)))

func _process(delta: float) -> void:
	timer += delta
	if timer >= lifetime:
		queue_free()
		return
	update()

func _draw() -> void:
	var p := timer / lifetime
	var fade := 1.0 - p
	var edge := Color(0.4, 1.0, 0.6, fade)
	var core := Color(1.0, 1.0, 1.0, fade)
	if p < 0.45:
		draw_circle(Vector2.ZERO, size * 6.0 * (1.0 - p), core)
	draw_arc(Vector2.ZERO, size * (4.0 + 14.0 * p), 0.0, TAU, 20, edge, max(1.0, 2.5 * fade))
	for angle in ray_angles:
		var dir := Vector2(cos(angle), sin(angle))
		draw_line(dir * size * (3.0 + 10.0 * p), dir * size * (8.0 + 16.0 * p), core, max(1.0, 2.0 * fade))
