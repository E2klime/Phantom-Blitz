extends Node
## Integration test (client side). Joins 127.0.0.1:7895 and passes once both
## players (host + self) are spawned and the chat round-trip works.
##
##   godot --headless --path . res://tests/it_client.tscn

const PORT := 7895
const TIMEOUT := 15.0


func _ready() -> void:
	var tree := get_tree()
	var chat_ok := [false]
	# No Game.start_match() here: the server replies to registration with
	# Game._sync_match_config, which starts the match client-side. This also
	# exercises the late-join config sync path.
	Net.connection_succeeded.connect(func() -> void:
		Net.send_chat("integration test")
	)
	Net.connection_failed.connect(func(reason: String) -> void:
		printerr("IT CLIENT FAIL: " + reason)
		tree.quit(1)
	)
	Net.chat_received.connect(func(_sender: String, _team: int, text: String) -> void:
		if text == "integration test":
			chat_ok[0] = true
	)
	var err := Net.join_game("127.0.0.1", PORT)
	if not err.is_empty():
		printerr("IT CLIENT FAIL: " + err)
		tree.quit(1)
		return

	# Poll from a tree timer chain (this node dies on the scene change).
	# The callable lives in a dictionary because GDScript lambdas capture
	# locals by value — a `var poll` would be null inside its own body.
	var state := {"elapsed": 0.0, "poll": Callable()}
	state["poll"] = func() -> void:
		state["elapsed"] += 0.5
		var count := tree.get_nodes_in_group("players").size()
		if count >= 2 and chat_ok[0]:
			print("IT CLIENT PASS: %d players, chat relayed" % count)
			tree.quit(0)
		elif state["elapsed"] > TIMEOUT:
			printerr("IT CLIENT FAIL: timeout (players=%d, chat=%s)" % [count, chat_ok[0]])
			tree.quit(1)
		else:
			tree.create_timer(0.5).timeout.connect(state["poll"])
	tree.create_timer(0.5).timeout.connect(state["poll"])
