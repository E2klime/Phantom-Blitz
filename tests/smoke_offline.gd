extends Node
## Headless smoke test: starts an offline match and verifies that the arena
## loads and exactly one player spawns. Exits non-zero on failure.
##
##   godot --headless --path . res://tests/smoke_offline.tscn

func _ready() -> void:
	var tree := get_tree()
	if not _check_rewards():
		tree.quit(1)
		return
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


## Pure-function checks of Game.kill_reward against the design numbers.
func _check_rewards() -> bool:
	var cases := [
		# [killer_lv, victim_lv, combo, silver, xp]
		[10, 10, 1, 10, 5],    # base kill
		[10, 10, 7, 70, 35],   # max combo
		[10, 17, 1, 12, 6],    # +1 bonus step (victim 5+ above)
		[10, 35, 1, 20, 10],   # bonus capped at +10 / +5
		[10, 99, 7, 140, 70],  # capped bonus * max combo
		[25, 10, 1, 8, 4],     # -1 malus step (victim 10+ below)
		[40, 10, 1, 4, 2],     # malus capped at -6 / -3 (30+ levels)
		[99, 1, 1, 4, 2],      # malus stays capped
	]
	for c: Array in cases:
		var r: Dictionary = Game.kill_reward(c[0], c[1], c[2])
		if int(r["silver"]) != c[3] or int(r["xp"]) != c[4]:
			printerr("SMOKE FAIL reward(%d, %d, x%d): got %s, want %d silver / %d xp" % [
				c[0], c[1], c[2], r, c[3], c[4]])
			return false
	print("SMOKE: reward math OK (%d cases)" % cases.size())
	return true
