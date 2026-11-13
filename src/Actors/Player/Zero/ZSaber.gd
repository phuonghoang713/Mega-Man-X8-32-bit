extends Movement

# Zero's Z-Saber. Player.gd adds two instances of this ability when Zero is the
# selected character:
#   "ZSaber"   (aerial = false): 3-hit grounded combo. Roots Zero in place;
#                                 jump, dash or taking damage cancels it.
#   "SaberAir" (aerial = true):  single slash used while airborne (spin slash)
#                                 or dashing (dash slash). Runs alongside the
#                                 current movement, like X's buster does.

const Hitbox = preload("res://src/Actors/Player/Zero/ZSaberHitbox.gd")
const Slash = preload("res://src/Actors/Player/Zero/ZSaberSlash.gd")
const LIGHT_SOUND = preload("res://src/Sounds/CopySigma - ClassicSaber.wav")
const HEAVY_SOUND = preload("res://src/Sounds/CopySigma - HighSlash.wav")

# hit_delay: seconds into the swing before the hitbox appears
# hit_time:  how long the hitbox stays alive
# next_at:   earliest moment a buffered press continues the combo
const GROUND_COMBO = [
	{"duration": 0.26, "hit_delay": 0.03, "hit_time": 0.09, "next_at": 0.13,
	 "damage": 3.0, "boss": 2.0, "weak": 3.0,
	 "arc": [-70.0, 45.0], "radius": 26.0, "thick": 8.0,
	 "extents": Vector2(20, 16), "offset": Vector2(18, -6),
	 "anim": "shot", "lunge": 30.0, "heavy": false},
	{"duration": 0.26, "hit_delay": 0.03, "hit_time": 0.09, "next_at": 0.13,
	 "damage": 3.0, "boss": 2.0, "weak": 3.0,
	 "arc": [55.0, -75.0], "radius": 26.0, "thick": 8.0,
	 "extents": Vector2(20, 16), "offset": Vector2(18, -6),
	 "anim": "shot_strong", "lunge": 30.0, "heavy": false},
	{"duration": 0.40, "hit_delay": 0.05, "hit_time": 0.12, "next_at": 1.0,
	 "damage": 5.0, "boss": 4.0, "weak": 6.0,
	 "arc": [-120.0, 80.0], "radius": 32.0, "thick": 11.0,
	 "extents": Vector2(26, 22), "offset": Vector2(18, -8),
	 "anim": "counter", "lunge": 70.0, "heavy": true},
]

const AIR_SLASH = {"duration": 0.30, "hit_delay": 0.02, "hit_time": 0.14,
	 "damage": 3.0, "boss": 2.0, "weak": 3.0,
	 "arc": [-160.0, 170.0], "radius": 28.0, "thick": 9.0,
	 "extents": Vector2(26, 24), "offset": Vector2(6, -6),
	 "anim": "", "heavy": false}

const DASH_SLASH = {"duration": 0.28, "hit_delay": 0.02, "hit_time": 0.12,
	 "damage": 4.0, "boss": 3.0, "weak": 4.0,
	 "arc": [-45.0, 40.0], "radius": 36.0, "thick": 10.0,
	 "extents": Vector2(30, 14), "offset": Vector2(22, -2),
	 "anim": "", "heavy": true}

var aerial := false
var step := 0
var queued := false
var spawned := false
var current: Dictionary = GROUND_COMBO[0]
var hitbox: Node = null

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
	if aerial:
		if character.is_executing("Dash"):
			current = DASH_SLASH
		else:
			current = AIR_SLASH
	else:
		current = GROUND_COMBO[0]
	start_swing()

func start_swing() -> void:
	timer = 0.0
	spawned = false
	queued = false
	if not aerial:
		var pressed := get_pressed_direction()
		if pressed != 0:
			character.set_direction(pressed, true)
		character.play_animation(current.anim)
	if current.heavy:
		play_sound(HEAVY_SOUND)
	else:
		play_sound(LIGHT_SOUND)
	spawn_slash_effect()

func _Update(delta: float) -> void:
	if not aerial:
		if timer < 0.08:
			force_movement(current.lunge)
		else:
			force_movement(0)
		process_gravity(delta)
		update_bonus_horizontal_only_conveyor()

		if timer > 0.04 and get_action_just_pressed("fire"):
			queued = true
		if queued and step < GROUND_COMBO.size() - 1 and timer >= current.next_at:
			step += 1
			current = GROUND_COMBO[step]
			start_swing()
			return

	if not spawned and timer >= current.hit_delay:
		spawn_hitbox()

func _EndCondition() -> bool:
	if not aerial and not character.is_on_floor():
		return true
	return timer > current.duration

func _Interrupt() -> void:
	if not aerial:
		force_movement(0)
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
	add_child(hitbox)

func spawn_slash_effect() -> void:
	var slash = Slash.new()
	slash.setup(current.arc[0], current.arc[1], current.radius, current.thick,
			character.get_facing_direction(), Vector2(4, -6))
	add_child(slash)
