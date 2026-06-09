extends CharacterBody2D
## Networked platformer player.
##
## Authority model:
##   * Movement + aim run on the owning client (node authority) and are
##     replicated through the MultiplayerSynchronizer.
##   * Health, deaths and respawns are decided by the SERVER and pushed to
##     everyone with RPCs — clients can never set their own HP.
##   * Shooting is announced by the owner (call_local RPC). Every peer spawns
##     a local projectile for visuals; only the server's copy deals damage.

const PROJECTILE_SCENE := preload("res://scenes/game/projectile.tscn")
const GRENADE_SCENE := preload("res://scenes/game/grenade.tscn")

const BASE_SPEED := 360.0
const JUMP_VELOCITY := -640.0
const MAX_JUMPS := 2
const COYOTE_TIME := 0.1
const RESPAWN_DELAY := 3.0
const BASE_MAX_HP := 100

const TEAM_COLORS: Array[Color] = [Color(0.3, 0.62, 1.0), Color(0.95, 0.3, 0.3)]

var peer_id: int = 1
var team: int = 0
var max_hp: int = BASE_MAX_HP
var hp: int = BASE_MAX_HP
var dead: bool = false
var grenades_left: int = 0

# Replicated state (see player.tscn replication config).
var aim_angle: float = 0.0
var weapon_id: String = "pistol"
var perk_id: String = ""
var grenade_id: String = ""

var ammo_in_clip: int = 0
var reloading: bool = false

var _jumps_used: int = 0
var _coyote_timer: float = 0.0
var _fire_cooldown: float = 0.0
var _reload_timer: float = 0.0
var _was_jump_held: bool = false

@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var body_visual: Polygon2D = $BodyVisual
@onready var gun: Node2D = $Gun
@onready var name_label: Label = $NameLabel
@onready var hp_bar: ProgressBar = $HpBar
@onready var camera: Camera2D = $Camera2D

signal local_state_changed  # HUD listens to refresh ammo/hp


func _enter_tree() -> void:
	peer_id = str(name).to_int()
	set_multiplayer_authority(peer_id)


func _ready() -> void:
	if is_multiplayer_authority():
		weapon_id = str(Profile.loadout.get("weapon", "pistol"))
		perk_id = str(Profile.loadout.get("perk", ""))
		grenade_id = str(Profile.loadout.get("grenade", ""))
		camera.enabled = true
		camera.make_current()
	_apply_loadout()
	_refresh_identity()
	Net.player_list_changed.connect(_refresh_identity)
	hp = max_hp
	_update_bars()


func _apply_loadout() -> void:
	var weapon: Dictionary = ItemDB.get_item(weapon_id)
	ammo_in_clip = int(weapon.get("clip_size", 0))
	max_hp = BASE_MAX_HP
	var perk: Dictionary = ItemDB.get_item(perk_id)
	if not perk.is_empty():
		max_hp += int(perk.get("max_hp_bonus", 0))
	grenades_left = 0
	var grenade: Dictionary = ItemDB.get_item(grenade_id)
	if not grenade.is_empty():
		grenades_left = int(grenade.get("carry_count", 0))


func _refresh_identity() -> void:
	team = Net.team_of(peer_id)
	if Net.players.has(peer_id):
		name_label.text = str(Net.players[peer_id]["name"])
	else:
		name_label.text = "Player %d" % peer_id
	body_visual.color = TEAM_COLORS[team]


func speed() -> float:
	var mult := 1.0
	var perk: Dictionary = ItemDB.get_item(perk_id)
	if not perk.is_empty():
		mult = float(perk.get("speed_mult", 1.0))
	return BASE_SPEED * mult


# ------------------------------------------------------------------ physics

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority() and not dead:
		_handle_input(delta)
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		_jumps_used = 0
		_coyote_timer = COYOTE_TIME
	_coyote_timer = maxf(0.0, _coyote_timer - delta)
	move_and_slide()
	gun.rotation = aim_angle
	gun.scale.y = -1.0 if absf(aim_angle) > PI / 2.0 else 1.0


func _handle_input(delta: float) -> void:
	var axis := Input.get_axis("move_left", "move_right")
	var jump_held := Input.is_action_pressed("jump")
	var shoot_held := Input.is_action_pressed("shoot")
	var grenade_pressed := Input.is_action_just_pressed("grenade")

	if TouchInput.active:
		if absf(TouchInput.move_axis) > 0.2:
			axis = TouchInput.move_axis
		jump_held = jump_held or TouchInput.jump_pressed
		shoot_held = shoot_held or TouchInput.shoot_held
		grenade_pressed = grenade_pressed or TouchInput.grenade_pressed
		TouchInput.grenade_pressed = false
		if TouchInput.aim_vector.length() > 0.3:
			aim_angle = TouchInput.aim_vector.angle()
	else:
		aim_angle = (get_global_mouse_position() - global_position).angle()

	velocity.x = axis * speed()

	var jump_just_pressed := jump_held and not _was_jump_held
	_was_jump_held = jump_held
	if jump_just_pressed:
		if is_on_floor() or _coyote_timer > 0.0:
			velocity.y = JUMP_VELOCITY
			_jumps_used = 1
			_coyote_timer = 0.0
		elif _jumps_used < MAX_JUMPS:
			velocity.y = JUMP_VELOCITY * 0.85
			_jumps_used += 1

	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	if reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			reloading = false
			ammo_in_clip = int(ItemDB.get_item(weapon_id).get("clip_size", 0))
			local_state_changed.emit()
	elif Input.is_action_just_pressed("reload"):
		_start_reload()
	elif shoot_held:
		_try_shoot()

	if grenade_pressed and grenades_left > 0:
		grenades_left -= 1
		_throw_grenade.rpc(global_position, Vector2.from_angle(aim_angle))
		local_state_changed.emit()


func _try_shoot() -> void:
	if _fire_cooldown > 0.0 or reloading:
		return
	var weapon: Dictionary = ItemDB.get_item(weapon_id)
	if weapon.is_empty():
		return
	if ammo_in_clip <= 0:
		_start_reload()
		return
	ammo_in_clip -= 1
	_fire_cooldown = 1.0 / float(weapon.get("fire_rate", 2.0))
	_shoot.rpc(global_position + Vector2.from_angle(aim_angle) * 34.0, aim_angle)
	local_state_changed.emit()


func _start_reload() -> void:
	var weapon: Dictionary = ItemDB.get_item(weapon_id)
	if weapon.is_empty() or reloading:
		return
	if ammo_in_clip >= int(weapon.get("clip_size", 0)):
		return
	reloading = true
	_reload_timer = float(weapon.get("reload_time", 1.5))
	local_state_changed.emit()


# ----------------------------------------------------------------- shooting

@rpc("authority", "call_local", "unreliable_ordered")
func _shoot(from: Vector2, angle: float) -> void:
	var weapon: Dictionary = ItemDB.get_item(weapon_id)
	if weapon.is_empty():
		return
	var pellets := int(weapon.get("pellets", 1))
	var spread := deg_to_rad(float(weapon.get("spread_deg", 0.0)))
	for i in pellets:
		var pellet_angle := angle
		if pellets > 1:
			pellet_angle += lerpf(-spread, spread, float(i) / float(pellets - 1))
		elif spread > 0.0:
			pellet_angle += randf_range(-spread, spread)
		var projectile := PROJECTILE_SCENE.instantiate()
		projectile.setup(
			peer_id, team, from,
			Vector2.from_angle(pellet_angle) * float(weapon.get("projectile_speed", 1400.0)),
			int(weapon.get("damage", 10)),
			Color(weapon.get("color", Color.WHITE)))
		get_parent().add_child(projectile)


@rpc("authority", "call_local", "reliable")
func _throw_grenade(from: Vector2, direction: Vector2) -> void:
	var data: Dictionary = ItemDB.get_item(grenade_id)
	if data.is_empty():
		return
	var grenade := GRENADE_SCENE.instantiate()
	grenade.setup(
		peer_id, team, from,
		direction * float(data.get("throw_speed", 900.0)) + Vector2(0, -260),
		int(data.get("damage", 50)),
		float(data.get("radius", 120.0)),
		float(data.get("fuse", 1.4)))
	get_parent().add_child(grenade)


# ------------------------------------------------------- health (server) ---

## SERVER ONLY: apply damage. attacker_id used for the kill feed / score.
func take_damage(amount: int, attacker_id: int) -> void:
	if not Net.is_server() or dead:
		return
	hp = maxi(0, hp - amount)
	_sync_hp.rpc(hp)
	if hp == 0:
		dead = true
		Game.report_kill(peer_id, attacker_id)
		_die.rpc()
		_respawn_later()


@rpc("any_peer", "call_local", "reliable")
func _sync_hp(new_hp: int) -> void:
	if multiplayer.get_remote_sender_id() not in [0, 1]:
		return
	hp = new_hp
	_update_bars()
	local_state_changed.emit()


@rpc("any_peer", "call_local", "reliable")
func _die() -> void:
	if multiplayer.get_remote_sender_id() not in [0, 1]:
		return
	dead = true
	visible = false
	body_shape.set_deferred("disabled", true)
	velocity = Vector2.ZERO


func _respawn_later() -> void:
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	if not is_inside_tree() or not Net.is_server():
		return
	var arena: Node = get_tree().get_first_node_in_group("arena")
	var spawn_pos: Vector2 = arena.get_spawn_position(Net.team_of(peer_id)) if arena else Vector2.ZERO
	hp = max_hp
	dead = false
	_sync_hp.rpc(hp)
	_respawn.rpc(spawn_pos)


@rpc("any_peer", "call_local", "reliable")
func _respawn(at: Vector2) -> void:
	if multiplayer.get_remote_sender_id() not in [0, 1]:
		return
	global_position = at
	dead = false
	visible = true
	body_shape.set_deferred("disabled", false)
	_apply_loadout()
	_update_bars()
	local_state_changed.emit()


func _update_bars() -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = hp
