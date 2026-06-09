extends Area2D
## Grenade. Simple scripted arc (gravity + bounce), exploding after a fuse.
## Like bullets, each peer simulates its own copy; only the server's copy
## deals damage.

var thrower_id: int = 0
var thrower_team: int = 0
var damage: int = 50
var radius: float = 120.0
var fuse: float = 1.4
var vel: Vector2 = Vector2.ZERO

const GRAVITY := 1600.0
const BOUNCE := 0.45


func setup(thrower: int, team: int, from: Vector2, velocity_: Vector2, dmg: int, radius_: float, fuse_: float) -> void:
	thrower_id = thrower
	thrower_team = team
	position = from
	vel = velocity_
	damage = dmg
	radius = radius_
	fuse = fuse_


func _physics_process(delta: float) -> void:
	vel.y += GRAVITY * delta
	var motion := vel * delta
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(position, position + motion, 1)
	var hit := space.intersect_ray(query)
	if hit:
		position = hit["position"]
		var normal: Vector2 = hit["normal"]
		vel = vel.bounce(normal) * BOUNCE
	else:
		position += motion
	fuse -= delta
	if fuse <= 0.0:
		_explode()


func _explode() -> void:
	if Net.is_server():
		for player in get_tree().get_nodes_in_group("players"):
			var dist := position.distance_to(player.global_position)
			if dist > radius:
				continue
			if player.peer_id != thrower_id and player.team == thrower_team \
					and not Game.friendly_fire() and Net.is_online:
				continue
			var falloff := 1.0 - (dist / radius) * 0.5
			player.take_damage(int(damage * falloff), thrower_id)
	_spawn_blast_visual()
	queue_free()


func _spawn_blast_visual() -> void:
	var blast := Polygon2D.new()
	var points := PackedVector2Array()
	for i in 16:
		points.append(Vector2.from_angle(TAU * i / 16.0) * radius)
	blast.polygon = points
	blast.color = Color(1.0, 0.7, 0.2, 0.55)
	blast.position = position
	get_parent().add_child(blast)
	var tween := blast.create_tween()
	tween.tween_property(blast, "modulate:a", 0.0, 0.35)
	tween.tween_callback(blast.queue_free)
