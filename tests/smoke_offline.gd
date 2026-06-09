extends Node
## Headless smoke test: starts an offline match and verifies that the arena
## loads and exactly one player spawns. Exits non-zero on failure.
##
##   godot --headless --path . res://tests/smoke_offline.tscn

const PlayerScript := preload("res://scripts/game/player.gd")


func _ready() -> void:
	var tree := get_tree()
	if not _check_rewards() or not _check_stats() or not _check_fall_damage():
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


## Pure-function checks of the Stats skill / stat math design numbers.
func _check_stats() -> bool:
	var checks := [
		# [label, got, want]
		["points at max level", Stats.points_for_level(Stats.MAX_LEVEL), 84],
		["cost to max all skills", Stats.total_cost_all(), 84],
		["base HP", Stats.max_hp({}), 200],
		["trained HP", Stats.max_hp({"resilience": 12}), 500],
		["geared HP max", Stats.max_hp({"resilience": 20}), 700],
		["trained speed", Stats.speed_value({"speed": 8}), 160],
		["geared speed cap", Stats.speed_value({"speed": 12}), 175],
		["INT value cap", Stats.intelligence_value({"intelligence": 11}), 11],
		["medkit heal INT 1", Stats.medkit_heal({}), 52],
		["medkit heal INT 11", Stats.medkit_heal({"intelligence": 10}), 72],
		["discount 4% base", Stats.discounted_price(100, {}), 96],
		["discount 44% max", Stats.discounted_price(1000, {"intelligence": 10}), 560],
		["resilience rank 12 level gate", Stats.rank_level_required("resilience", 12), 67],
		["defense rank 8 level gate", Stats.rank_level_required("defense", 8), 64],
	]
	var float_checks := [
		["trained damage", Stats.damage_mult({"firepower": 12}), 1.60],
		["geared damage max", Stats.damage_mult({"firepower": 18}), 1.90],
		["trained crit", Stats.crit_chance({"firepower": 12}), 0.17],
		["geared crit max", Stats.crit_chance({"firepower": 18}), 0.23],
		["crit damage with charm", Stats.crit_damage_mult({"crit_bonus": 0.2}), 2.2],
		["trained accuracy", Stats.accuracy({"accuracy": 8}), 0.94],
		["accuracy hard cap", Stats.accuracy({"accuracy": 11}), 1.0],
		["defense cap", Stats.defense_ratio({"defense": 14}), 0.42],
	]
	for c: Array in checks:
		if int(c[1]) != int(c[2]):
			printerr("SMOKE FAIL stats %s: got %s, want %s" % [c[0], c[1], c[2]])
			return false
	for c: Array in float_checks:
		if absf(float(c[1]) - float(c[2])) > 0.0001:
			printerr("SMOKE FAIL stats %s: got %s, want %s" % [c[0], c[1], c[2]])
			return false
	print("SMOKE: stats math OK (%d cases)" % (checks.size() + float_checks.size()))
	return true


## Fall damage: free below the safe distance, mild beyond it, hard-capped.
func _check_fall_damage() -> bool:
	var cases := [
		# [fall_px, max_hp, want]
		[400.0, 200, 0],    # within the safe distance
		[500.0, 200, 0],    # exactly the threshold
		[550.0, 200, 1],    # barely over
		[700.0, 200, 3],    # 200 px excess
		[1600.0, 200, 16],  # long drop incl. heavy-excess bonus
		[9999.0, 200, 30],  # capped at 15% of max HP
	]
	for c: Array in cases:
		var got: int = PlayerScript.fall_damage_for(float(c[0]), int(c[1]))
		if got != int(c[2]):
			printerr("SMOKE FAIL fall(%s px, %s hp): got %d, want %d" % [c[0], c[1], got, c[2]])
			return false
	print("SMOKE: fall damage OK (%d cases)" % cases.size())
	return true
