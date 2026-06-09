extends Node2D
## Match scene. Loads the selected map from res://maps/ (see MapDB) and lets
## the SERVER own the lifecycle of player nodes: it spawns one per registered
## peer (drop-in / drop-out) and the MultiplayerSpawner replicates them to
## every client. Maps are script-less scenes following the node contract:
## World geometry, SpawnPoints/Blue*, SpawnPoints/Red*, optional KillZone.

const PLAYER_SCENE := preload("res://scenes/game/player.tscn")

var map_node: Node2D = null

@onready var players_root: Node2D = $Players


func _ready() -> void:
	add_to_group("arena")
	_load_map()
	Game.match_config_changed.connect(_on_match_config_changed)
	Net.player_list_changed.connect(_sync_player_nodes)
	Net.server_disconnected.connect(_on_server_lost)
	Net.connection_failed.connect(func(_reason: String) -> void: _on_server_lost())
	if Net.is_server():
		_sync_player_nodes()


func _load_map() -> void:
	if is_instance_valid(map_node):
		map_node.queue_free()
	var info := MapDB.get_map(Game.map_id)
	var packed: PackedScene = load(str(info["scene"]))
	map_node = packed.instantiate()
	add_child(map_node)
	move_child(map_node, 0)  # draw the world behind the players
	var kill_zone: Area2D = map_node.get_node_or_null("KillZone")
	if kill_zone:
		kill_zone.body_entered.connect(_on_kill_zone_body_entered)


func _on_match_config_changed() -> void:
	# Late config sync (e.g. a client that joined before receiving the map).
	if is_instance_valid(map_node) and map_node.scene_file_path != str(MapDB.get_map(Game.map_id)["scene"]):
		_load_map()


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
	if not is_instance_valid(map_node):
		return Vector2.ZERO
	var spawn_points: Node2D = map_node.get_node("SpawnPoints")
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
