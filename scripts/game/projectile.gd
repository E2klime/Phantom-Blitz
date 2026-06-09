extends Area2D
## Bullet. Spawned locally on every peer for visuals; damage is applied only
## by the server's copy (see player.gd shooting model).

const LIFETIME := 1.5

var shooter_id: int = 0
var shooter_team: int = 0
var damage: int = 10
var direction_velocity: Vector2 = Vector2.RIGHT
var _age: float = 0.0


func setup(shooter: int, team: int, from: Vector2, vel: Vector2, dmg: int, color: Color) -> void:
	shooter_id = shooter
	shooter_team = team
	position = from
	direction_velocity = vel
	damage = dmg
	rotation = vel.angle()
	$Visual.color = color


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += direction_velocity * delta
	_age += delta
	if _age > LIFETIME:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.has_method("take_damage"):
		if body.peer_id == shooter_id:
			return
		if body.team == shooter_team and Net.is_online:
			return  # no friendly fire in team games
		if Net.is_server():
			body.take_damage(damage, shooter_id)
		queue_free()
		return
	# Hit world geometry.
	queue_free()
