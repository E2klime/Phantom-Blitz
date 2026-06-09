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
##
## Movement feature set (all tunables below):
##   acceleration / friction with reduced air control, coyote time, jump
##   buffering, variable jump height (release to cut), double jump, wall
##   slide + wall jump, dash with cooldown (one per airtime), fast fall
##   and fall speed caps.

const PROJECTILE_SCENE := preload("res://scenes/game/projectile.tscn")
const GRENADE_SCENE := preload("res://scenes/game/grenade.tscn")

const BASE_SPEED := 360.0
const GROUND_ACCEL := 3400.0
const GROUND_FRICTION := 3000.0
const AIR_ACCEL := 2100.0
const AIR_FRICTION := 420.0

const JUMP_VELOCITY := -760.0
const DOUBLE_JUMP_FACTOR := 0.9
const JUMP_CUT_FACTOR := 0.45
const JUMP_BUFFER_TIME := 0.12
const MAX_JUMPS := 2
const COYOTE_TIME := 0.1

const WALL_SLIDE_SPEED := 150.0
const WALL_JUMP_VELOCITY := -700.0
const WALL_JUMP_PUSH := 460.0

const DASH_SPEED := 950.0
const DASH_TIME := 0.16
const DASH_COOLDOWN := 0.9

const MAX_FALL_SPEED := 1300.0
const FAST_FALL_SPEED := 1750.0
const FAST_FALL_GRAVITY_MULT := 1.8

const RESPAWN_DELAY := 3.0

# Fall damage: kept deliberately mild. Falls below the safe distance are
# free; beyond it 1 HP per step, and very long drops (heavy excess) add
# extra HP per smaller step. Capped at a fraction of max HP so even the
# tallest map cannot one-shot a player.
const FALL_SAFE_DISTANCE := 500.0
const FALL_DAMAGE_STEP := 100.0
const FALL_HEAVY_EXCESS := 900.0
const FALL_HEAVY_STEP := 50.0
const FALL_DAMAGE_CAP_RATIO := 0.15

const TEAM_COLORS: Array[Color] = [Color(0.3, 0.62, 1.0), Color(0.95, 0.3, 0.3)]

var peer_id: int = 1
var team: int = 0
var max_hp: int = 200
var hp: int = 200
var dead: bool = false
var grenades_left: int = 0

# Replicated state (see player.tscn replication config).
var aim_angle: float = 0.0
var weapon_id: String = "pistol"
var perk_id: String = ""
var grenade_id: String = ""
# Total stat points (skills + gear) of this player's profile. Replicated so
# the server can compute max HP / defense and peers can show accurate bars.
var combat_stats: Dictionary = {}

var ammo_in_clip: int = 0
var reloading: bool = false

var _move_axis: float = 0.0
var _jumps_used: int = 0
var _coyote_timer: float = 0.0
var _jump_buffer: float = 0.0
var _fire_cooldown: float = 0.0
var _reload_timer: float = 0.0
var _was_jump_held: bool = false
var _fast_fall_held: bool = false
var _dash_timer: float = 0.0
var _dash_cooldown: float = 0.0
var _dash_dir: float = 1.0
var _air_dash_used: bool = false
var _airborne: bool = false
var _fall_peak_y: float = 0.0

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
		combat_stats = Profile.combat_stats()
		_apply_mode_weapon()
		camera.enabled = true
		camera.make_current()
	_apply_loadout()
	_refresh_identity()
	Net.player_list_changed.connect(_refresh_identity)
	hp = max_hp
	_update_bars()


## Modes can override the equipped weapon (Instagib rail, Gun Game ladder).
func _apply_mode_weapon() -> void:
	if not Game.forced_weapon().is_empty():
		weapon_id = Game.forced_weapon()
	elif bool(Game.mode_info()["gun_ladder"]):
		weapon_id = Game.gun_game_weapon_for(peer_id)


func _apply_loadout() -> void:
	var weapon: Dictionary = ItemDB.get_item(weapon_id)
	ammo_in_clip = int(weapon.get("clip_size", 0))
	max_hp = Stats.max_hp(combat_stats)
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
	if Game.is_team_mode():
		body_visual.color = TEAM_COLORS[team]
	else:
		# FFA-style modes: a stable distinct color per player.
		body_visual.color = Color.from_hsv(fposmod(float(peer_id) * 0.137, 1.0), 0.65, 0.95)
	# Gun Game: the ladder weapon follows the synced kill count.
	if is_multiplayer_authority() and bool(Game.mode_info()["gun_ladder"]):
		var ladder_weapon := Game.gun_game_weapon_for(peer_id)
		if ladder_weapon != weapon_id:
			weapon_id = ladder_weapon
			reloading = false
			ammo_in_clip = int(ItemDB.get_item(weapon_id).get("clip_size", 0))
			local_state_changed.emit()


func speed() -> float:
	# BASE_SPEED corresponds to the abstract speed value 120 (see Stats).
	var mult := Stats.speed_scale(combat_stats)
	var perk: Dictionary = ItemDB.get_item(perk_id)
	if not perk.is_empty():
		mult *= float(perk.get("speed_mult", 1.0))
	return BASE_SPEED * mult


# ------------------------------------------------------------------ physics

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority() and not dead:
		_handle_input(delta)

	if _dash_timer > 0.0:
		# Dash: locked horizontal burst, no gravity.
		velocity.x = _dash_dir * DASH_SPEED
		velocity.y = 0.0
	elif not is_on_floor():
		var gravity := get_gravity() * delta
		if _fast_fall_held and velocity.y > 0.0:
			gravity *= FAST_FALL_GRAVITY_MULT
		velocity += gravity
		if _is_wall_sliding():
			velocity.y = minf(velocity.y, WALL_SLIDE_SPEED)
		velocity.y = minf(velocity.y, FAST_FALL_SPEED if _fast_fall_held else MAX_FALL_SPEED)
	else:
		_jumps_used = 0
		_coyote_timer = COYOTE_TIME
		_air_dash_used = false
	_coyote_timer = maxf(0.0, _coyote_timer - delta)
	move_and_slide()
	if is_multiplayer_authority() and not dead:
		_track_fall()
	gun.rotation = aim_angle
	gun.scale.y = -1.0 if absf(aim_angle) > PI / 2.0 else 1.0


## AUTHORITY ONLY: measures the distance from the highest airborne point
## to the landing spot and asks the server for fall damage when it exceeds
## the safe threshold. Wall slides reset the measurement (controlled descent).
func _track_fall() -> void:
	if is_on_floor():
		if _airborne:
			_airborne = false
			var fall_distance := global_position.y - _fall_peak_y
			var damage := fall_damage_for(fall_distance, max_hp)
			if damage > 0:
				_request_fall_damage.rpc_id(1, damage)
		return
	if not _airborne:
		_airborne = true
		_fall_peak_y = global_position.y
	else:
		_fall_peak_y = minf(_fall_peak_y, global_position.y)
	if _is_wall_sliding():
		_fall_peak_y = global_position.y


## Pure fall-damage curve, also exercised by tests.
static func fall_damage_for(distance: float, hp_cap: int) -> int:
	var excess := distance - FALL_SAFE_DISTANCE
	if excess <= 0.0:
		return 0
	var damage := 1 + int(excess / FALL_DAMAGE_STEP)
	if excess > FALL_HEAVY_EXCESS:
		damage += int((excess - FALL_HEAVY_EXCESS) / FALL_HEAVY_STEP)
	return mini(damage, int(ceil(float(hp_cap) * FALL_DAMAGE_CAP_RATIO)))


func _is_wall_sliding() -> bool:
	return is_on_wall_only() and velocity.y > 0.0 \
		and signf(_move_axis) != 0.0 \
		and signf(_move_axis) == -signf(get_wall_normal().x)


func _handle_input(delta: float) -> void:
	var axis := Input.get_axis("move_left", "move_right")
	var jump_held := Input.is_action_pressed("jump")
	var shoot_held := Input.is_action_pressed("shoot")
	var grenade_pressed := Input.is_action_just_pressed("grenade")
	var dash_pressed := Input.is_action_just_pressed("dash")
	_fast_fall_held = Input.is_action_pressed("fast_fall")

	if TouchInput.active:
		if absf(TouchInput.move_axis) > 0.2:
			axis = TouchInput.move_axis
		jump_held = jump_held or TouchInput.jump_pressed
		shoot_held = shoot_held or TouchInput.shoot_held
		grenade_pressed = grenade_pressed or TouchInput.grenade_pressed
		TouchInput.grenade_pressed = false
		dash_pressed = dash_pressed or TouchInput.dash_pressed
		TouchInput.dash_pressed = false
		if TouchInput.aim_vector.length() > 0.3:
			aim_angle = TouchInput.aim_vector.angle()
		# Pushing the move stick all the way down = fast fall.
		_fast_fall_held = _fast_fall_held or TouchInput.move_axis_y > 0.85
	else:
		aim_angle = (get_global_mouse_position() - global_position).angle()
	_move_axis = axis

	# ------------------------------------------------------------ movement --
	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	if _dash_timer > 0.0:
		_dash_timer -= delta
	else:
		var target := axis * speed()
		if absf(axis) > 0.05:
			var accel := GROUND_ACCEL if is_on_floor() else AIR_ACCEL
			velocity.x = move_toward(velocity.x, target, accel * delta)
		else:
			var friction := GROUND_FRICTION if is_on_floor() else AIR_FRICTION
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	# Jump buffering + edge detection (works for keyboard and touch).
	var jump_just_pressed := jump_held and not _was_jump_held
	var jump_released := not jump_held and _was_jump_held
	_was_jump_held = jump_held
	if jump_just_pressed:
		_jump_buffer = JUMP_BUFFER_TIME
	else:
		_jump_buffer = maxf(0.0, _jump_buffer - delta)

	if _jump_buffer > 0.0:
		if is_on_floor() or _coyote_timer > 0.0:
			velocity.y = JUMP_VELOCITY
			_jumps_used = 1
			_coyote_timer = 0.0
			_jump_buffer = 0.0
		elif is_on_wall_only():
			# Wall jump: kick up and away from the wall.
			velocity.y = WALL_JUMP_VELOCITY
			velocity.x = get_wall_normal().x * WALL_JUMP_PUSH
			_jumps_used = 1
			_jump_buffer = 0.0
		elif _jumps_used < MAX_JUMPS:
			velocity.y = JUMP_VELOCITY * DOUBLE_JUMP_FACTOR
			_jumps_used += 1
			_jump_buffer = 0.0

	# Variable jump height: releasing early cuts the ascent.
	if jump_released and velocity.y < 0.0:
		velocity.y *= JUMP_CUT_FACTOR

	if dash_pressed and _dash_timer <= 0.0 and _dash_cooldown <= 0.0 \
			and (is_on_floor() or not _air_dash_used):
		_dash_dir = signf(axis) if absf(axis) > 0.05 else (1.0 if cos(aim_angle) >= 0.0 else -1.0)
		_dash_timer = DASH_TIME
		_dash_cooldown = DASH_COOLDOWN
		if not is_on_floor():
			_air_dash_used = true

	# ------------------------------------------------------------- weapons --
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
	# Firepower scales damage; crits and accuracy jitter are rolled per shot.
	# Each peer rolls independently for its local visuals — only the server's
	# projectile deals damage, so its roll is the authoritative one.
	var damage := int(roundf(float(weapon.get("damage", 10)) * Stats.damage_mult(combat_stats)))
	if randf() < Stats.crit_chance(combat_stats):
		damage = int(roundf(float(damage) * Stats.crit_damage_mult(combat_stats)))
	var jitter := deg_to_rad((1.0 - Stats.accuracy(combat_stats)) * 8.0)
	for i in pellets:
		var pellet_angle := angle + randf_range(-jitter, jitter)
		if pellets > 1:
			pellet_angle += lerpf(-spread, spread, float(i) / float(pellets - 1))
		elif spread > 0.0:
			pellet_angle += randf_range(-spread, spread)
		var projectile := PROJECTILE_SCENE.instantiate()
		projectile.setup(
			peer_id, team, from,
			Vector2.from_angle(pellet_angle) * float(weapon.get("projectile_speed", 1400.0)),
			damage,
			Color(weapon.get("color", Color.WHITE)),
			bool(weapon.get("explosive", false)),
			float(weapon.get("blast_radius", 0.0)))
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
## The victim's Defense stat absorbs up to 42% of any incoming damage.
func take_damage(amount: int, attacker_id: int) -> void:
	if not Net.is_server() or dead:
		return
	if amount > 0:
		amount = maxi(1, int(ceilf(float(amount) * (1.0 - Stats.defense_ratio(combat_stats)))))
	hp = maxi(0, hp - amount)
	_sync_hp.rpc(hp)
	if hp == 0:
		dead = true
		Game.report_kill(peer_id, attacker_id)
		_drop_medkit()
		_die.rpc()
		_respawn_later()


## SERVER ONLY: restore HP (medkits). Clamped to max HP.
func heal(amount: int) -> void:
	if not Net.is_server() or dead or amount <= 0:
		return
	hp = mini(max_hp, hp + amount)
	_sync_hp.rpc(hp)


func _drop_medkit() -> void:
	var arena: Node = get_tree().get_first_node_in_group("arena")
	if arena and arena.has_method("drop_medkit"):
		arena.drop_medkit(global_position)


## Sent by the owning client when it lands hard. The server sanity-caps the
## amount (fall damage can never exceed the design cap) before applying it.
@rpc("any_peer", "call_local", "reliable")
func _request_fall_damage(amount: int) -> void:
	if not Net.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != peer_id:
		return  # only the owner may report their own fall
	amount = clampi(amount, 0, int(ceilf(float(max_hp) * FALL_DAMAGE_CAP_RATIO)))
	take_damage(amount, peer_id)


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
	if is_multiplayer_authority():
		# Pick up skill upgrades / gear changes made since the last spawn.
		combat_stats = Profile.combat_stats()
		_apply_mode_weapon()
	_apply_loadout()
	_dash_timer = 0.0
	_dash_cooldown = 0.0
	_air_dash_used = false
	_airborne = false
	_update_bars()
	local_state_changed.emit()


func _update_bars() -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = hp
