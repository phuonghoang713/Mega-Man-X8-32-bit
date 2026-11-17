extends RigidBody2D

# Short-lived melee hitbox spawned once per saber swing.
# Enemy receivers (EnemyDamage, BossDamage, EnemyShield, Buttons...) detect it
# through the "Player Projectile" group and call hit()/leave()/deflect() on it,
# exactly like they do with buster shots. A fresh body is spawned for every
# swing so enter events always fire, even on targets that never left the area.

var damage := 2.0
var damage_to_bosses := 1.0
var damage_to_weakness := 2.0
var break_guards := true
var continuous_damage := false
var facing_direction := 1
var lifetime := 0.1

var targets := []
var damaged := []
var timer := 0.0

signal dealt_damage(target)

func _init() -> void:
	mode = MODE_KINEMATIC
	collision_layer = 4
	collision_mask = 0
	add_to_group("Player Projectile")

func setup(_damage: float, _bosses: float, _weakness: float, direction: int,
		extents: Vector2, offset: Vector2, _lifetime: float, _break_guards := true) -> void:
	damage = _damage
	damage_to_bosses = _bosses
	damage_to_weakness = _weakness
	facing_direction = direction
	lifetime = _lifetime
	break_guards = _break_guards
	position = Vector2(offset.x * direction, offset.y)
	var shape := RectangleShape2D.new()
	shape.extents = extents
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)

func get_facing_direction() -> int:
	return facing_direction

func hit(target) -> void:
	if not target in targets:
		targets.append(target)

func leave(target) -> void:
	targets.erase(target)

func deflect(_body) -> void:
	pass

func _physics_process(delta: float) -> void:
	timer += delta
	for target in targets.duplicate():
		if not is_instance_valid(target):
			targets.erase(target)
			continue
		if target in damaged:
			continue
		damaged.append(target)
		if target.has_method("damage"):
			target.damage(damage, self)
			emit_signal("dealt_damage", target)
	if timer > lifetime:
		queue_free()
