extends Node
## Headless smoke test: starts an offline match and verifies that the arena
## loads and exactly one player spawns. Exits non-zero on failure.
##
##   godot --headless --path . res://tests/smoke_offline.tscn

func _ready() -> void:
	var tree := get_tree()
	# This node is freed when the scene changes, so the check must not
	# reference self — capture the tree in a lambda instead.
	tree.create_timer(3.0).timeout.connect(func() -> void:
		var arena := tree.get_first_node_in_group("arena")
		var players := tree.get_nodes_in_group("players")
		var ok := arena != null and players.size() == 1
		if ok and players[0].hp == players[0].max_hp and players[0].ammo_in_clip > 0:
			print("SMOKE PASS: arena + player spawned, hp %d, ammo %d" % [
				players[0].hp, players[0].ammo_in_clip])
			tree.quit(0)
		else:
			printerr("SMOKE FAIL: arena=%s players=%d" % [arena, players.size()])
			tree.quit(1)
	)
	Net.start_offline()
	Game.start_match()
