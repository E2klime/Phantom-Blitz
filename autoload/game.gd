extends Node
## Game autoload — scene flow and authoritative match state (team scores,
## kill events, rewards, match end). The server is the source of truth;
## clients receive state through RPCs on this node.

signal score_changed
signal kill_feed(text: String)
signal match_ended(winning_team: int)

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const ARENA_SCENE := "res://scenes/game/arena.tscn"

const XP_PER_KILL := 60
const COINS_PER_KILL := 25
const SCORE_LIMIT := 20
const MATCH_RESET_DELAY := 6.0

var team_scores: Array[int] = [0, 0]
var in_match: bool = false


# --------------------------------------------------------------- scene flow

func goto_scene(path: String) -> void:
	# Deferred: scene changes can be triggered from _ready or RPC contexts
	# where the tree is busy adding/removing children.
	get_tree().change_scene_to_file.call_deferred(path)


func start_match() -> void:
	team_scores = [0, 0]
	in_match = true
	score_changed.emit()
	goto_scene(ARENA_SCENE)


func return_to_menu() -> void:
	if in_match:
		Profile.record_match()
	in_match = false
	Net.leave_game()
	goto_scene(MENU_SCENE)


# -------------------------------------------------------------- match state

## Called on the SERVER by player.gd when a player dies.
func report_kill(victim_id: int, killer_id: int) -> void:
	if not Net.is_server():
		return
	Net.record_kill(killer_id, victim_id)
	var scoring_team := -1
	if killer_id != victim_id and Net.players.has(killer_id):
		scoring_team = Net.team_of(killer_id)
		team_scores[scoring_team] += 1
	_sync_kill.rpc(victim_id, killer_id, team_scores[0], team_scores[1])
	if scoring_team != -1 and team_scores[scoring_team] >= SCORE_LIMIT:
		_sync_match_end.rpc(scoring_team)
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
		Profile.add_xp(XP_PER_KILL)
		Profile.add_coins(COINS_PER_KILL)
	if victim_id == Net.local_id():
		Profile.record_death()


@rpc("authority", "call_local", "reliable")
func _sync_match_end(winning_team: int) -> void:
	match_ended.emit(winning_team)


func _reset_after_delay() -> void:
	await get_tree().create_timer(MATCH_RESET_DELAY).timeout
	if not Net.is_server() or not in_match:
		return
	team_scores = [0, 0]
	_sync_score.rpc(0, 0)


@rpc("authority", "call_local", "reliable")
func _sync_score(blue: int, red: int) -> void:
	team_scores = [blue, red]
	score_changed.emit()


func _player_name(peer_id: int) -> String:
	if Net.players.has(peer_id):
		return str(Net.players[peer_id]["name"])
	return "Player %d" % peer_id
