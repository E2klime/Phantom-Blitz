extends Node
## Game autoload — scene flow, match configuration (mode + map) and
## authoritative match state (scores, kill events, rewards, match end).
## The server is the source of truth; clients receive state through RPCs
## on this node.

signal score_changed
signal kill_feed(text: String)
signal match_ended(message: String, winning_team: int)  # winning_team -1 = no team
signal reward_earned(silver_amount: int, xp_amount: int, combo: int)
signal match_config_changed

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const ARENA_SCENE := "res://scenes/game/arena.tscn"

enum Mode { TEAM_DEATHMATCH, FREE_FOR_ALL, GUN_GAME, INSTAGIB }

const MODES: Dictionary = {
	Mode.TEAM_DEATHMATCH: {
		"name": "Team Deathmatch",
		"description": "Two teams. First to %d kills wins.",
		"team_based": true,
		"score_limit": 20,
		"forced_weapon": "",
		"gun_ladder": false,
	},
	Mode.FREE_FOR_ALL: {
		"name": "Free-For-All",
		"description": "Everyone for themselves. First to %d kills wins.",
		"team_based": false,
		"score_limit": 15,
		"forced_weapon": "",
		"gun_ladder": false,
	},
	Mode.GUN_GAME: {
		"name": "Gun Game",
		"description": "Every kill swaps your gun. Finish the ladder first.",
		"team_based": false,
		"score_limit": 0,  # ladder length is the limit
		"forced_weapon": "",
		"gun_ladder": true,
	},
	Mode.INSTAGIB: {
		"name": "Instagib",
		"description": "Railguns only. One hit, one kill. First team to %d.",
		"team_based": true,
		"score_limit": 20,
		"forced_weapon": "railgun_xc",
		"gun_ladder": false,
	},
}

## Weapon progression for Gun Game, from humble to absurd.
const GUN_GAME_LADDER: Array[String] = [
	"pistol", "rust_revolver", "uzi", "shotgun", "carbine_kt", "rifle",
	"brute_mg", "hunting_carbine", "lobber_gl", "plasma_carbine",
	"railgun_xc", "golden_judge",
]

# ------------------------------------------------------------ kill rewards --
# Base: 10 silver + 5 XP per kill.
# Combo: another kill within 6 s multiplies the reward, up to x7.
# Victim above your level: +2 silver / +1 XP per full 5 levels (cap +10 / +5).
# Victim below your level: -2 silver / -1 XP per full 10 levels (cap -6 / -3
# at a 30+ level difference in your favor → minimum 4 silver / 2 XP).
const KILL_SILVER := 10
const KILL_XP := 5
const COMBO_WINDOW := 6.0
const COMBO_MAX := 7
const BONUS_LEVEL_STEP := 5
const BONUS_SILVER_PER_STEP := 2
const BONUS_XP_PER_STEP := 1
const BONUS_SILVER_CAP := 10
const BONUS_XP_CAP := 5
const MALUS_LEVEL_STEP := 10
const MALUS_SILVER_PER_STEP := 2
const MALUS_XP_PER_STEP := 1
const MALUS_SILVER_CAP := 6
const MALUS_XP_CAP := 3

const MATCH_RESET_DELAY := 6.0

var mode: int = Mode.TEAM_DEATHMATCH
var map_id: String = "foundry"
var team_scores: Array[int] = [0, 0]
var in_match: bool = false

var _combo_count: int = 0
var _last_kill_ms: int = -1000000


# --------------------------------------------------------------- scene flow

func goto_scene(path: String) -> void:
	# Deferred: scene changes can be triggered from _ready or RPC contexts
	# where the tree is busy adding/removing children.
	get_tree().change_scene_to_file.call_deferred(path)


func set_match_config(new_mode: int, new_map: String) -> void:
	if MODES.has(new_mode):
		mode = new_mode
	if MapDB.has_map(new_map):
		map_id = new_map
	match_config_changed.emit()


func start_match() -> void:
	team_scores = [0, 0]
	_combo_count = 0
	_last_kill_ms = -1000000
	in_match = true
	score_changed.emit()
	goto_scene(ARENA_SCENE)


func return_to_menu() -> void:
	if in_match:
		Profile.record_match()
	in_match = false
	Net.leave_game()
	goto_scene(MENU_SCENE)


# ----------------------------------------------------------- mode helpers --

func mode_info() -> Dictionary:
	return MODES[mode]


func is_team_mode() -> bool:
	return bool(mode_info()["team_based"])


## True when players may damage anyone, including same-team colors.
func friendly_fire() -> bool:
	return not is_team_mode()


## Weapon forced on everyone by the current mode ("" = use loadout).
func forced_weapon() -> String:
	return str(mode_info()["forced_weapon"])


func score_limit() -> int:
	if bool(mode_info()["gun_ladder"]):
		return GUN_GAME_LADDER.size()
	return int(mode_info()["score_limit"])


## Gun Game: the weapon a player should currently hold, from their kills.
func gun_game_weapon_for(peer_id: int) -> String:
	var kills := 0
	if Net.players.has(peer_id):
		kills = int(Net.players[peer_id]["kills"])
	return GUN_GAME_LADDER[clampi(kills, 0, GUN_GAME_LADDER.size() - 1)]


## Pushed by the server to a late joiner (and on match start) so every
## peer agrees on mode + map before the arena loads.
@rpc("authority", "call_local", "reliable")
func _sync_match_config(mode_: int, map_: String) -> void:
	mode = mode_ if MODES.has(mode_) else Mode.TEAM_DEATHMATCH
	map_id = map_ if MapDB.has_map(map_) else MapDB.DEFAULT_MAP
	match_config_changed.emit()
	if not in_match:
		start_match()


# -------------------------------------------------------------- match state

## Called on the SERVER by player.gd when a player dies.
func report_kill(victim_id: int, killer_id: int) -> void:
	if not Net.is_server():
		return
	Net.record_kill(killer_id, victim_id)
	var scoring_team := -1
	if killer_id != victim_id and Net.players.has(killer_id):
		if is_team_mode():
			scoring_team = Net.team_of(killer_id)
			team_scores[scoring_team] += 1
	_sync_kill.rpc(victim_id, killer_id, team_scores[0], team_scores[1])

	# Win conditions.
	if killer_id == victim_id or not Net.players.has(killer_id):
		return
	if is_team_mode():
		if scoring_team != -1 and team_scores[scoring_team] >= score_limit():
			_sync_match_end.rpc("%s TEAM WINS!" % ["BLUE", "RED"][scoring_team], scoring_team)
			_reset_after_delay()
	else:
		if int(Net.players[killer_id]["kills"]) >= score_limit():
			_sync_match_end.rpc("%s WINS!" % _player_name(killer_id), -1)
			_reset_after_delay()


@rpc("authority", "call_local", "reliable")
func _sync_kill(victim_id: int, killer_id: int, blue: int, red: int) -> void:
	team_scores = [blue, red]
	score_changed.emit()

	var victim_name := _player_name(victim_id)
	var killer_name := _player_name(killer_id)
	if killer_id == victim_id:
		kill_feed.emit("%s self-destructed" % victim_name)
	else:
		kill_feed.emit("%s eliminated %s" % [killer_name, victim_name])

	if killer_id == Net.local_id() and killer_id != victim_id:
		Profile.record_kill()
		_grant_kill_reward(victim_id)
	if victim_id == Net.local_id():
		Profile.record_death()
		_combo_count = 0


## Computes and pays the local player's reward for killing victim_id.
func _grant_kill_reward(victim_id: int) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_kill_ms <= int(COMBO_WINDOW * 1000.0):
		_combo_count = mini(_combo_count + 1, COMBO_MAX)
	else:
		_combo_count = 1
	_last_kill_ms = now

	var victim_level := Profile.level
	if Net.players.has(victim_id):
		victim_level = int(Net.players[victim_id]["level"])
	var reward := kill_reward(Profile.level, victim_level, _combo_count)

	Profile.add_xp(int(reward["xp"]))
	Profile.add_silver(int(reward["silver"]))
	reward_earned.emit(int(reward["silver"]), int(reward["xp"]), _combo_count)


## Pure reward math, also exercised by tests.
func kill_reward(killer_level: int, victim_level: int, combo: int) -> Dictionary:
	var silver := KILL_SILVER
	var xp := KILL_XP
	var diff := victim_level - killer_level
	if diff > 0:
		var steps := diff / BONUS_LEVEL_STEP
		silver += mini(steps * BONUS_SILVER_PER_STEP, BONUS_SILVER_CAP)
		xp += mini(steps * BONUS_XP_PER_STEP, BONUS_XP_CAP)
	elif diff < 0:
		var steps := -diff / MALUS_LEVEL_STEP
		silver -= mini(steps * MALUS_SILVER_PER_STEP, MALUS_SILVER_CAP)
		xp -= mini(steps * MALUS_XP_PER_STEP, MALUS_XP_CAP)
	combo = clampi(combo, 1, COMBO_MAX)
	return {"silver": silver * combo, "xp": xp * combo}


@rpc("authority", "call_local", "reliable")
func _sync_match_end(message: String, winning_team: int) -> void:
	match_ended.emit(message, winning_team)


func _reset_after_delay() -> void:
	await get_tree().create_timer(MATCH_RESET_DELAY).timeout
	if not Net.is_server() or not in_match:
		return
	team_scores = [0, 0]
	Net.reset_stats()
	_sync_score.rpc(0, 0)


@rpc("authority", "call_local", "reliable")
func _sync_score(blue: int, red: int) -> void:
	team_scores = [blue, red]
	score_changed.emit()


func _player_name(peer_id: int) -> String:
	if Net.players.has(peer_id):
		return str(Net.players[peer_id]["name"])
	return "Player %d" % peer_id
