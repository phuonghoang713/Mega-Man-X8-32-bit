extends Node2D

# Procedural saber trail. The blade's leading edge sweeps along an (optionally
# squashed and tilted) arc with an ease-out curve while the tail lags behind and
# catches up, so the trail stretches during the swing and then retracts and
# fades. Drawn as layered bands (glow, edge, white core) with per-vertex alpha
# so the tail dissolves smoothly. Replace with a sprite effect once real art
# is available.

var start_angle := -60.0
var end_angle := 50.0
var radius := 26.0
var thickness := 8.0
var squash := 1.0      # vertical scale of the arc (1 = circle, <1 = flat ellipse)
var tilt := 0.0        # rotation of the whole arc, degrees
var echo := false      # draw a second, delayed inner arc (heavy finishers)
var sweep_time := 0.07 # time for the leading edge to reach end_angle
var fade_time := 0.14  # time for the tail to catch up and the trail to vanish
var timer := 0.0

var glow_color := Color(0.25, 0.95, 0.45, 0.35)
var edge_color := Color(0.35, 1.0, 0.55, 0.9)
var core_color := Color(0.95, 1.0, 0.95, 1.0)

const SEGMENTS := 20
const TAIL_LAG := 0.35 # fraction of sweep_time before the tail starts moving

func setup(params: Dictionary, direction: int, offset: Vector2) -> void:
	start_angle = params.arc[0]
	end_angle = params.arc[1]
	radius = params.radius
	thickness = params.thick
	squash = params.get("squash", 1.0)
	tilt = params.get("tilt", 0.0)
	echo = params.get("echo", false)
	sweep_time = params.get("sweep", 0.07)
	fade_time = params.get("fade", 0.14)
	scale.x = direction
	position = Vector2(offset.x * direction, offset.y)
	z_index = 7
	z_as_relative = false

func _process(delta: float) -> void:
	timer += delta
	if timer > sweep_time + fade_time + (0.04 if echo else 0.0):
		queue_free()
		return
	update()

func _draw() -> void:
	draw_trail(timer, radius, thickness, 1.0)
	if echo:
		draw_trail(timer - 0.04, radius * 0.72, thickness * 0.7, 0.55)

func draw_trail(t: float, r: float, width: float, strength: float) -> void:
	if t <= 0.0:
		return
	var head_p := ease_out(clamp(t / sweep_time, 0.0, 1.0))
	var tail_start := sweep_time * TAIL_LAG
	var tail_p := ease_in_out(clamp((t - tail_start) / (sweep_time - tail_start + fade_time), 0.0, 1.0))
	var head: float = lerp(start_angle, end_angle, head_p)
	var tail: float = lerp(start_angle, end_angle, tail_p)
	if abs(head - tail) < 2.0:
		return

	# overall brightness dips once the swing is done and the tail is retracting
	var alpha := strength
	if t > sweep_time:
		alpha *= 1.0 - 0.6 * clamp((t - sweep_time) / fade_time, 0.0, 1.0)

	draw_band(tail, head, r + width * 0.25, width * 1.5, glow_color, alpha)
	draw_band(tail, head, r, width, edge_color, alpha)
	draw_band(tail, head, r - width * 0.2, width * 0.45, core_color, alpha)

	# bright tip at the leading edge while the blade is still moving
	if t < sweep_time * 1.2:
		var tip := arc_point(head, r - width * 0.4)
		var tip_color := core_color
		tip_color.a = alpha
		draw_circle(tip, width * 0.45, tip_color)

# Band from angle `from` (tail) to `to` (head). Width and alpha grow toward the
# head. Drawn as one quad per segment so no polygon triangulation is needed.
func draw_band(from: float, to: float, r: float, width: float, color: Color, alpha: float) -> void:
	var prev_outer := Vector2.ZERO
	var prev_inner := Vector2.ZERO
	var prev_color := color
	for i in SEGMENTS + 1:
		var s := float(i) / SEGMENTS
		var angle: float = lerp(from, to, s)
		var w := width * (0.15 + 0.85 * s)
		var outer := arc_point(angle, r)
		var inner := arc_point(angle, r - w)
		var c := color
		c.a *= alpha * s * s
		if i > 0:
			draw_primitive(PoolVector2Array([prev_outer, outer, inner, prev_inner]),
					PoolColorArray([prev_color, c, c, prev_color]), PoolVector2Array())
		prev_outer = outer
		prev_inner = inner
		prev_color = c

func arc_point(angle_deg: float, r: float) -> Vector2:
	var a := deg2rad(angle_deg)
	return Vector2(cos(a) * r, sin(a) * r * squash).rotated(deg2rad(tilt))

static func ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3)

static func ease_in_out(x: float) -> float:
	return 3.0 * x * x - 2.0 * x * x * x
