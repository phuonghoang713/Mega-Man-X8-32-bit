extends Sprite

# A fading, single-color copy of the player's current animation frame, left
# behind in world space during fast saber moves.

const SILHOUETTE = preload("res://src/Actors/Player/Zeno/afterimage.shader")

var lifetime := 0.2
var start_alpha := 0.55
var timer := 0.0

func copy_from(source: AnimatedSprite, color: Color, _lifetime := 0.2) -> bool:
	if not source.frames or not source.frames.has_animation(source.animation):
		return false
	texture = source.frames.get_frame(source.animation, source.frame)
	if not texture:
		return false
	centered = source.centered
	offset = source.offset
	flip_h = source.flip_h
	flip_v = source.flip_v
	global_transform = source.global_transform
	z_index = source.z_index - 1
	var mat := ShaderMaterial.new()
	mat.shader = SILHOUETTE
	material = mat
	lifetime = _lifetime
	start_alpha = color.a
	modulate = color
	return true

func _process(delta: float) -> void:
	timer += delta
	if timer >= lifetime:
		queue_free()
		return
	modulate.a = start_alpha * (1.0 - timer / lifetime)
