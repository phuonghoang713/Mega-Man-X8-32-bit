extends Movement

# Zero's Z-Saber. Player.gd adds two instances of this ability when Zero is the
# selected character:
#   "ZSaber"   (aerial = false): 3-hit grounded combo. Roots Zero in place;
#                                 jump, dash or taking damage cancels it.
#   "SaberAir" (aerial = true):  single slash used while airborne (spin slash)
#                                 or dashing (dash slash). Runs alongside the
#                                 current movement, like X's buster does.
#
# Game feel: eased, per-hit slash trails (ZSaberSlash), afterimages on fast
# moves (ZAfterimage), hit-stop + impact spark when a hit lands (ZHitStop,
# ZSaberSpark), and a forgiving input buffer for chaining the combo.

const Hitbox = preload("res://src/Actors/Player/Zero/ZSaberHitbox.gd")
const Slash = preload("res://src/Actors/Player/Zero/ZSaberSlash.gd")
const Afterimage = preload("res://src/Actors/Player/Zero/ZAfterimage.gd")
const Spark = preload("res://src/Actors/Player/Zero/ZSaberSpark.gd")
const HitStop = preload("res://src/Actors/Player/Zero/ZHitStop.gd")
const LIGHT_SOUND = preload("res://src/Sounds/CopySigma - ClassicSaber.wav")
const HEAVY_SOUND = preload("res://src/Sounds/CopySigma - HighSlash.wav")

# hit_delay: seconds into the swing before the hitbox appears
# hit_time:  how long the hitbox stays alive
# next_at:   earliest moment a buffered press continues the combo
# arc/radius/thick/squash/tilt/echo/sweep: shape and speed of the slash trail
# ghosts:    leave afterimages during this swing
# anim:      X animation used while Zero has no sprites of his own
# zero_anim: animation used instead when zero_sprites/ provides it; its hit
#            frame can be set in zero_sprites/zero.cfg (hit_frame_<name>)
# Reach: each hitbox (offset ± extents, in pixels in front of Zero) is sized to
# cover the drawn arc, so what you see is what hits.
const GROUND_COMBO = [
	{"duration": 0.26, "hit_delay": 0.03, "hit_time": 0.09, "next_at": 0.10,
	 "damage": 3.0, "boss": 2.0, "weak": 3.0,
	 "arc": [-70.0, 45.0], "radius": 38.0, "thick": 10.0,
	 "squash": 0.75, "tilt": 0.0, "sweep": 0.07,
	 "extents": Vector2(22, 22), "offset": Vector2(24, -8),
	 "anim": "shot", "zero_anim": "saber_1", "lunge": 30.0, "heavy": false, "ghosts": false},
	{"duration": 0.26, "hit_delay": 0.03, "hit_time": 0.09, "next_at": 0.10,
	 "damage": 3.0, "boss": 2.0, "weak": 3.0,
	 "arc": [55.0, -75.0], "radius": 37.0, "thick": 10.0,
	 "squash": 0.6, "tilt": -12.0, "sweep": 0.07,
	 "extents": Vector2(22, 22), "offset": Vector2(24, -8),
	 "anim": "shot_strong", "zero_anim": "saber_2", "lunge": 30.0, "heavy": false, "ghosts": false},
	{"duration": 0.40, "hit_delay": 0.05, "hit_time": 0.12, "next_at": 1.0,
	 "damage": 5.0, "boss": 4.0, "weak": 6.0,
	 "arc": [-120.0, 80.0], "radius": 46.0, "thick": 13.0,
	 "squash": 1.0, "tilt": 0.0, "echo": true, "sweep": 0.09, "fade": 0.18,
	 "extents": Vector2(30, 30), "offset": Vector2(24, -10),
	 "anim": "counter", "zero_anim": "saber_3", "lunge": 70.0, "heavy": true, "ghosts": true},
]

const AIR_SLASH = {"duration": 0.30, "hit_delay": 0.02, "hit_time": 0.14,
	 "damage": 3.0, "boss": 2.0, "weak": 3.0,
	 "arc": [-160.0, 170.0], "radius": 38.0, "thick": 11.0,
	 "squash": 0.9, "tilt": 0.0, "sweep": 0.14, "fade": 0.12,
	 "extents": Vector2(40, 36), "offset": Vector2(4, -6),
	 "anim": "", "zero_anim": "saber_air", "heavy": false, "ghosts": true}

const DASH_SLASH = {"duration": 0.28, "hit_delay": 0.02, "hit_time": 0.12,
	 "damage": 4.0, "boss": 3.0, "weak": 4.0,
	 "arc": [-115.0, 40.0], "radius": 50.0, "thick": 12.0,
	 "squash": 0.4, "tilt": 0.0, "sweep": 0.07, "fade": 0.16,
	 "extents": Vector2(34, 18), "offset": Vector2(30, -4),
	 "anim": "", "zero_anim": "saber_dash", "heavy": true, "ghosts": true}

const GHOST_INTERVAL := 0.035
const GHOST_COLOR := Color(1.0, 0.3, 0.25, 0.55)
const COMBO_GRACE_FRAMES := 9 # physics frames (~150 ms): a press this soon after a swing ends still chains
const HITSTOP_LIGHT := 0.045
const HITSTOP_HEAVY := 0.08

var aerial := false
var step := 0
var queued := false
var spawned := false
var current: Dictionary = GROUND_COMBO[0]
var hitbox: Node = null
var ghost_timer := 0.0
var landed_hit := false
var ended_naturally := false
var last_end_frame := -100000
var last_step := -1
var hitstop: Node = null
var start_frame := -1 # physics frame the ability started on
var hit_delay := 0.0
var swing_duration := 0.0
var locked_anim := "" # aerial swing animation kept on screen while slashing
var prev_anim := ""
var prev_frame := 0

func _ready() -> void:
	hitstop = HitStop.new()
	hitstop.name = "HitStop"
	add_child(hitstop)

func _StartCondition() -> bool:
	if not character.has_control():
		return false
	if character.is_executing("Ride"):
		return false
	var dashing: bool = character.is_executing("Dash")
	if aerial:
		return dashing or not character.is_on_floor()
	return character.is_on_floor() and not dashing

func _Setup() -> void:
	step = 0
	ended_naturally = false
	start_frame = Engine.get_physics_frames()
	if aerial:
		if character.is_executing("Dash"):
			current = DASH_SLASH
		else:
			current = AIR_SLASH
	else:
		# Pressing again right after a swing finished continues the combo.
		var chain_ok := Engine.get_physics_frames() - last_end_frame <= COMBO_GRACE_FRAMES
		if chain_ok and last_step >= 0 and last_step < GROUND_COMBO.size() - 1:
			step = last_step + 1
		current = GROUND_COMBO[step]
	start_swing()

func start_swing() -> void:
	timer = 0.0
	spawned = false
	queued = false
	landed_hit = false
	ghost_timer = GHOST_INTERVAL # first ghost on the next frame
	var anim := swing_animation()
	if not aerial:
		var pressed := get_pressed_direction()
		if pressed != 0:
			character.set_direction(pressed, true)
	elif anim != "" and locked_anim == "":
		prev_anim = character.get_animation()
		prev_frame = character.animatedSprite.frame
	if anim != "":
		character.play_animation(anim)
	locked_anim = anim if aerial else ""
	hit_delay = get_hit_delay(anim)
	swing_duration = max(current.duration, hit_delay + 0.05)
	if current.heavy:
		play_sound(HEAVY_SOUND)
	else:
		play_sound(LIGHT_SOUND)
	if show_trail():
		spawn_slash_effect()

# Zero's own saber animation when his sprites provide it, else X's stand-in.
func swing_animation() -> String:
	if character.zero_custom_sprites and character.animatedSprite.frames.has_animation(current.zero_anim):
		return current.zero_anim
	return current.anim

# With custom sprites, zero.cfg can pin the hit to a frame of the animation.
func get_hit_delay(anim: String) -> float:
	if anim != "" and character.zero_custom_sprites:
		var hit_frame = character.zero_config.get_value("saber", "hit_frame_" + anim, null)
		var fps: float = character.animatedSprite.frames.get_animation_speed(anim)
		if hit_frame != null and fps > 0.0:
			return float(hit_frame) / fps
	return current.hit_delay

func show_trail() -> bool:
	return character.zero_config.get_value("saber", "procedural_trail", true)

# Movement abilities only pick their animation when they start, so after an
# aerial slash put back the one that fits the current state.
func restore_animation() -> void:
	if character.is_on_floor():
		character.play_animation("walk" if character.is_executing("Walk") else "idle")
	elif character.is_executing("Dash") or character.is_executing("AirDash"):
		character.play_animation(prev_anim, prev_frame)
	else:
		character.play_animation("fall")

func _Update(delta: float) -> void:
	if not aerial:
		if timer < 0.08:
			force_movement(current.lunge)
		else:
			force_movement(0)
		process_gravity(delta)
		update_bonus_horizontal_only_conveyor()

		# Presses are buffered for the whole swing and fire at next_at. The
		# press that started the ability is seen again on its first frame and
		# must not count, or a single tap would swing twice.
		if get_action_just_pressed("fire") and Engine.get_physics_frames() != start_frame:
			queued = true
		if queued and step < GROUND_COMBO.size() - 1 and timer >= current.next_at:
			step += 1
			current = GROUND_COMBO[step]
			start_swing()
			return

	# Jump/Fall may switch the animation mid-slash (e.g. at the apex): keep
	# the slash on screen, at the frame it should be on by now.
	if locked_anim != "" and character.get_animation() != locked_anim:
		var frames: SpriteFrames = character.animatedSprite.frames
		var frame := int(timer * frames.get_animation_speed(locked_anim))
		character.play_animation(locked_anim, int(min(frame, frames.get_frame_count(locked_anim) - 1)))

	if current.ghosts:
		ghost_timer += delta
		if ghost_timer >= GHOST_INTERVAL:
			ghost_timer = 0.0
			spawn_afterimage()

	if not spawned and timer >= hit_delay:
		spawn_hitbox()

func _EndCondition() -> bool:
	if not aerial and not character.is_on_floor():
		return true
	if timer > swing_duration:
		ended_naturally = true
		return true
	return false

func _Interrupt() -> void:
	if not aerial:
		force_movement(0)
		if ended_naturally:
			last_end_frame = Engine.get_physics_frames()
			last_step = step
		else:
			last_step = -1
	elif locked_anim != "":
		locked_anim = ""
		restore_animation()
	if is_instance_valid(hitbox):
		hitbox.queue_free()
	hitbox = null

func spawn_hitbox() -> void:
	spawned = true
	if is_instance_valid(hitbox):
		hitbox.queue_free()
	hitbox = Hitbox.new()
	hitbox.name = "ZSaber"
	hitbox.setup(current.damage, current.boss, current.weak,
			character.get_facing_direction(), current.extents, current.offset,
			current.hit_time)
	hitbox.connect("dealt_damage", self, "on_hit", [hitbox])
	add_child(hitbox)

func on_hit(target, source) -> void:
	var where: Vector2 = source.global_position
	if target is Node2D:
		where = where.linear_interpolate(target.global_position, 0.5)
	spawn_spark(where, 1.3 if current.heavy else 1.0)
	if landed_hit:
		return # one hit-stop per swing, even when several enemies are hit
	landed_hit = true
	if current.heavy:
		hitstop.trigger(HITSTOP_HEAVY)
		Event.emit_signal("screenshake", 1.0)
	else:
		hitstop.trigger(HITSTOP_LIGHT)

func spawn_slash_effect() -> void:
	var slash = Slash.new()
	slash.setup(current, character.get_facing_direction(), Vector2(4, -6))
	add_child(slash)

func spawn_spark(where: Vector2, size: float) -> void:
	var level = character.get_parent()
	if not level:
		return
	var spark = Spark.new()
	spark.setup(size)
	level.add_child(spark)
	spark.global_position = where

func spawn_afterimage() -> void:
	var level = character.get_parent()
	var sprite = character.animatedSprite
	if not level or not sprite or not sprite.visible:
		return
	var ghost = Afterimage.new()
	if not ghost.copy_from(sprite, GHOST_COLOR):
		ghost.free()
		return
	level.add_child(ghost) # its z_index sits one below the player sprite
	ghost.global_transform = sprite.global_transform
