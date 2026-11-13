extends Node2D

# Placeholder saber trail: a procedurally drawn crescent that sweeps and fades.
# Replace with a sprite-based effect once real Zero art is available.

var start_angle := -60.0
var end_angle := 50.0
var radius := 26.0
var thickness := 8.0
var sweep_time := 0.06
var fade_time := 0.12
var timer := 0.0
var core_color := Color(0.92, 1.0, 0.92, 1.0)
var edge_color := Color(0.25, 0.95, 0.45, 0.85)

const segments := 14

func setup(_start: float, _end: float, _radius: float, _thickness: float, direction: int, offset: Vector2) -> void:
	start_angle = _start
	end_angle = _end
	radius = _radius
	thickness = _thickness
	scale.x = direction
	position = Vector2(offset.x * direction, offset.y)
	z_index = 7
	z_as_relative = false

func _process(delta: float) -> void:
	timer += delta
	if timer > sweep_time + fade_time:
		queue_free()
		return
	update()

func _draw() -> void:
	var progress: float = clamp(timer / sweep_time, 0.0, 1.0)
	var alpha := 1.0
	if timer > sweep_time:
		alpha = 1.0 - (timer - sweep_time) / fade_time
	var current_end: float = lerp(start_angle, end_angle, progress)
	if abs(current_end - start_angle) < 4.0:
		return
	draw_crescent(radius, thickness, current_end, edge_color, alpha)
	draw_crescent(radius - thickness * 0.25, thickness * 0.45, current_end, core_color, alpha)

func draw_crescent(r: float, width: float, current_end: float, color: Color, alpha: float) -> void:
	var outer := PoolVector2Array()
	var inner := PoolVector2Array()
	for i in segments + 1:
		var t := float(i) / segments
		var angle := deg2rad(lerp(start_angle, current_end, t))
		# the blade is thickest at the leading edge and tapers toward the tail
		var w := width * (0.2 + 0.8 * t)
		var dir := Vector2(cos(angle), sin(angle))
		outer.append(dir * r)
		inner.append(dir * (r - w))
	inner.invert()
	var polygon := outer
	polygon.append_array(inner)
	var c := color
	c.a *= alpha
	if polygon.size() >= 3:
		draw_colored_polygon(polygon, c)
