extends Node2D
## Match scene. The SERVER owns the lifecycle of player nodes: it spawns one
## per registered peer (drop-in / drop-out) and the MultiplayerSpawner
## replicates them to every client. Layout is placeholder geometry — replace
## or add maps by building new scenes with the same node contract
## (Players, SpawnPoints/Blue*, SpawnPoints/Red*, group "arena").

const PLAYER_SCENE := preload("res://scenes/game/player.tscn")

@onready var players_root: Node2D = $Players
@onready var spawn_points: Node2D = $SpawnPoints


func _ready() -> void:
	add_to_group("arena")
	Net.player_list_changed.connect(_sync_player_nodes)
	Net.server_disconnected.connect(_on_server_lost)
	Net.connection_failed.connect(func(_reason: String) -> void: _on_server_lost())
	if Net.is_server():
		_sync_player_nodes()


func _sync_player_nodes() -> void:
	if not Net.is_server():
		return
	for peer_id: int in Net.players:
		if not players_root.has_node(str(peer_id)):
			_spawn_player(peer_id)
	for node in players_root.get_children():
		if not Net.players.has(str(node.name).to_int()):
			node.queue_free()


func _spawn_player(peer_id: int) -> void:
	var player := PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.position = get_spawn_position(Net.team_of(peer_id))
	players_root.add_child(player, true)


func get_spawn_position(team: int) -> Vector2:
	var prefix := "Blue" if team == Net.Team.BLUE else "Red"
	var candidates: Array[Node] = []
	for point in spawn_points.get_children():
		if str(point.name).begins_with(prefix):
			candidates.append(point)
	if candidates.is_empty():
		candidates = spawn_points.get_children()
	return (candidates.pick_random() as Node2D).global_position


func _on_server_lost() -> void:
	Game.return_to_menu()


func _on_kill_zone_body_entered(body: Node2D) -> void:
	if Net.is_server() and body.has_method("take_damage"):
		body.take_damage(100000, body.peer_id)
