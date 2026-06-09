extends Node
## Integration test (server side). Hosts a match on port 7895 and passes once
## a client has joined (2 players spawned) and left again.
##
##   godot --headless --path . res://tests/it_host.tscn

const PORT := 7895
const TIMEOUT := 25.0


func _ready() -> void:
	var tree := get_tree()
	var err := Net.host_game(PORT)
	if not err.is_empty():
		printerr("IT HOST FAIL: " + err)
		tree.quit(1)
		return
	Game.start_match()

	# Poll from a tree timer chain (this node dies on the scene change).
	# The callable lives in a dictionary because GDScript lambdas capture
	# locals by value — a `var poll` would be null inside its own body.
	var state := {"saw_two": false, "elapsed": 0.0, "poll": Callable()}
	state["poll"] = func() -> void:
		state["elapsed"] += 0.5
		var count := tree.get_nodes_in_group("players").size()
		if count >= 2:
			state["saw_two"] = true
		if state["saw_two"] and count <= 1:
			print("IT HOST PASS: client joined and left cleanly")
			tree.quit(0)
		elif state["elapsed"] > TIMEOUT:
			printerr("IT HOST FAIL: timeout (saw_two=%s, players=%d)" % [state["saw_two"], count])
			tree.quit(1)
		else:
			tree.create_timer(0.5).timeout.connect(state["poll"])
	tree.create_timer(0.5).timeout.connect(state["poll"])
