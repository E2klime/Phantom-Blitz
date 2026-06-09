extends Area2D
## Bullet / rocket. Spawned locally on every peer for visuals; damage is
## applied only by the server's copy (see player.gd shooting model).
## Explosive projectiles (launchers, some exotics) detonate on impact and
## deal radius damage with falloff, like grenades.

const LIFETIME := 1.5

var shooter_id: int = 0
var shooter_team: int = 0
var damage: int = 10
var direction_velocity: Vector2 = Vector2.RIGHT
var explosive: bool = false
var blast_radius: float = 0.0
var _age: float = 0.0
var _done: bool = false


func setup(shooter: int, team: int, from: Vector2, vel: Vector2, dmg: int,
		color: Color, explosive_: bool = false, blast_radius_: float = 0.0) -> void:
	shooter_id = shooter
	shooter_team = team
	position = from
	direction_velocity = vel
	damage = dmg
	rotation = vel.angle()
	explosive = explosive_
	blast_radius = blast_radius_
	$Visual.color = color
	if explosive:
		$Visual.scale = Vector2(1.6, 1.6)


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += direction_velocity * delta
	_age += delta
	if _age > LIFETIME:
		queue_free()


func _blocks_friendly(body: Node2D) -> bool:
	return body.team == shooter_team and not Game.friendly_fire() and Net.is_online


func _on_body_entered(body: Node2D) -> void:
	if _done:
		return
	if body is CharacterBody2D and body.has_method("take_damage"):
		if body.peer_id == shooter_id:
			return
		if _blocks_friendly(body):
			return  # no friendly fire in team modes
		if explosive:
			_explode()
			return
		if Net.is_server():
			body.take_damage(damage, shooter_id)
		_done = true
		queue_free()
		return
	# Hit world geometry.
	if explosive:
		_explode()
		return
	queue_free()


func _explode() -> void:
	_done = true
	if Net.is_server():
		for player in get_tree().get_nodes_in_group("players"):
			var dist := position.distance_to(player.global_position)
			if dist > blast_radius:
				continue
			if player.peer_id != shooter_id and _blocks_friendly(player):
				continue
			var falloff := 1.0 - (dist / blast_radius) * 0.5
			player.take_damage(int(damage * falloff), shooter_id)
	_spawn_blast_visual()
	queue_free()


func _spawn_blast_visual() -> void:
	var blast := Polygon2D.new()
	var points := PackedVector2Array()
	for i in 16:
		points.append(Vector2.from_angle(TAU * i / 16.0) * blast_radius)
	blast.polygon = points
	blast.color = Color(1.0, 0.6, 0.25, 0.55)
	blast.position = position
	get_parent().add_child(blast)
	var tween := blast.create_tween()
	tween.tween_property(blast, "modulate:a", 0.0, 0.3)
	tween.tween_callback(blast.queue_free)
