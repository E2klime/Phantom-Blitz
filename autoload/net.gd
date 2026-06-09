extends Node
## Net autoload — connection lifecycle and player registry.
##
## Transport selection is automatic:
##   * Desktop / mobile  -> ENetMultiplayerPeer (UDP).
##   * Web (HTML5)       -> WebSocketMultiplayerPeer (browsers cannot use UDP).
## A dedicated server can be started with:
##   godot --headless -- --server [--websocket] [--port 7777]
## See docs/NETWORKING.md for the full picture.

signal connection_succeeded
signal connection_failed(reason: String)
signal server_disconnected
signal player_list_changed
signal chat_received(sender_name: String, team: int, text: String)
signal ping_updated(ms: int)

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 16

enum Team { BLUE = 0, RED = 1 }

## peer_id -> {name: String, team: int, kills: int, deaths: int, level: int}
var players: Dictionary = {}
var server_name: String = "Phantom Blitz Server"
var is_dedicated: bool = false
var is_online: bool = false
var ping_ms: int = 0

var _ping_timer: Timer


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	_ping_timer = Timer.new()
	_ping_timer.wait_time = 2.0
	_ping_timer.timeout.connect(_send_ping)
	add_child(_ping_timer)

	_check_dedicated_server()


func is_server() -> bool:
	return multiplayer.is_server()


func local_id() -> int:
	return multiplayer.get_unique_id()


# ---------------------------------------------------------------- hosting --

func host_game(port: int = DEFAULT_PORT, use_websocket: bool = false, name_: String = "") -> String:
	if OS.has_feature("web"):
		return "Browsers cannot host servers. Use a desktop build or a dedicated server."
	leave_game()
	var peer: MultiplayerPeer
	if use_websocket:
		var ws := WebSocketMultiplayerPeer.new()
		if ws.create_server(port) != OK:
			return "Failed to open WebSocket server on port %d." % port
		peer = ws
	else:
		var enet := ENetMultiplayerPeer.new()
		if enet.create_server(port, MAX_PLAYERS) != OK:
			return "Failed to open server on port %d (port in use?)." % port
		peer = enet
	multiplayer.multiplayer_peer = peer
	if not name_.is_empty():
		server_name = name_
	is_online = true
	players.clear()
	if not is_dedicated:
		players[1] = _local_player_info()
		players[1]["team"] = _pick_team()
	player_list_changed.emit()
	return ""


func start_offline() -> void:
	leave_game()
	is_online = false
	players.clear()
	players[1] = _local_player_info()
	players[1]["team"] = Team.BLUE
	player_list_changed.emit()


# ---------------------------------------------------------------- joining --

func join_game(address: String, port: int = DEFAULT_PORT) -> String:
	leave_game()
	var peer: MultiplayerPeer
	if OS.has_feature("web"):
		var ws := WebSocketMultiplayerPeer.new()
		var url := "ws://%s:%d" % [address, port]
		if ws.create_client(url) != OK:
			return "Failed to start WebSocket client for %s." % url
		peer = ws
	else:
		var enet := ENetMultiplayerPeer.new()
		if enet.create_client(address, port) != OK:
			return "Invalid address: %s:%d" % [address, port]
		peer = enet
	multiplayer.multiplayer_peer = peer
	is_online = true
	players.clear()
	return ""


func leave_game() -> void:
	_ping_timer.stop()
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	is_online = false
	ping_ms = 0
	player_list_changed.emit()


# ---------------------------------------------------------- signal plumbing

func _on_peer_connected(_id: int) -> void:
	# The client introduces itself via _register_player once connected.
	pass


func _on_peer_disconnected(id: int) -> void:
	if is_server() and players.has(id):
		players.erase(id)
		_broadcast_players()
		player_list_changed.emit()


func _on_connected_to_server() -> void:
	_register_player.rpc_id(1, Profile.player_name, Profile.level)
	_ping_timer.start()
	connection_succeeded.emit()


func _on_connection_failed() -> void:
	leave_game()
	connection_failed.emit("Could not reach the server.")


func _on_server_disconnected() -> void:
	leave_game()
	server_disconnected.emit()


# ----------------------------------------------------------------- registry

func _local_player_info() -> Dictionary:
	return {
		"name": Profile.player_name,
		"team": Team.BLUE,
		"kills": 0,
		"deaths": 0,
		"level": Profile.level,
	}


func _pick_team() -> int:
	var counts := [0, 0]
	for id: int in players:
		counts[int(players[id]["team"])] += 1
	return Team.BLUE if counts[Team.BLUE] <= counts[Team.RED] else Team.RED


@rpc("any_peer", "reliable")
func _register_player(name_: String, level_: int) -> void:
	if not is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	players[sender] = {
		"name": name_.substr(0, 20),
		"team": _pick_team(),
		"kills": 0,
		"deaths": 0,
		"level": level_,
	}
	_broadcast_players()
	player_list_changed.emit()
	# Bring the late joiner up to date with the current match score.
	Game._sync_score.rpc_id(sender, Game.team_scores[0], Game.team_scores[1])


func _broadcast_players() -> void:
	_sync_players.rpc(players)


@rpc("authority", "reliable")
func _sync_players(server_players: Dictionary) -> void:
	players = server_players
	player_list_changed.emit()


func record_kill(killer_id: int, victim_id: int) -> void:
	if not is_server():
		return
	if players.has(killer_id) and killer_id != victim_id:
		players[killer_id]["kills"] = int(players[killer_id]["kills"]) + 1
	if players.has(victim_id):
		players[victim_id]["deaths"] = int(players[victim_id]["deaths"]) + 1
	_broadcast_players()
	player_list_changed.emit()


func team_of(peer_id: int) -> int:
	if players.has(peer_id):
		return int(players[peer_id]["team"])
	return Team.BLUE


# --------------------------------------------------------------------- chat

func send_chat(text: String) -> void:
	text = text.strip_edges().substr(0, 120)
	if text.is_empty():
		return
	_request_chat.rpc_id(1, text)


@rpc("any_peer", "call_local", "reliable")
func _request_chat(text: String) -> void:
	if not is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = 1
	if not players.has(sender):
		return
	var info: Dictionary = players[sender]
	_receive_chat.rpc(str(info["name"]), int(info["team"]), text.substr(0, 120))


@rpc("authority", "call_local", "reliable")
func _receive_chat(sender_name: String, team: int, text: String) -> void:
	chat_received.emit(sender_name, team, text)


# --------------------------------------------------------------------- ping

func _send_ping() -> void:
	if is_online and not is_server():
		_ping_request.rpc_id(1, Time.get_ticks_msec())


@rpc("any_peer", "unreliable")
func _ping_request(client_time: int) -> void:
	if not is_server():
		return
	_ping_reply.rpc_id(multiplayer.get_remote_sender_id(), client_time)


@rpc("authority", "unreliable")
func _ping_reply(client_time: int) -> void:
	ping_ms = maxi(0, Time.get_ticks_msec() - client_time)
	ping_updated.emit(ping_ms)


# ----------------------------------------------------------- dedicated mode

func _check_dedicated_server() -> void:
	var args := OS.get_cmdline_user_args()
	if "--server" not in args:
		return
	is_dedicated = true
	var port := DEFAULT_PORT
	var idx := args.find("--port")
	if idx != -1 and idx + 1 < args.size():
		port = int(args[idx + 1])
	var err := host_game(port, "--websocket" in args, "Dedicated Server")
	if not err.is_empty():
		push_error(err)
		get_tree().quit(1)
		return
	print("Dedicated server listening on port %d (%s)." % [
		port, "WebSocket" if "--websocket" in args else "ENet"])
	Game.start_match.call_deferred()
