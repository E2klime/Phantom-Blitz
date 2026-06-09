extends Node
## Headless validation: instantiates every scene (with autoloads active),
## exercising all attached scripts. Exits non-zero on any failure.
##
##   godot --headless --path . res://tests/validate_scenes.tscn

const SCENES: Array[String] = [
	"res://scenes/ui/main_menu.tscn",
	"res://scenes/ui/server_browser.tscn",
	"res://scenes/ui/store.tscn",
	"res://scenes/ui/profile_screen.tscn",
	"res://scenes/ui/settings.tscn",
	"res://scenes/ui/hud.tscn",
	"res://scenes/game/player.tscn",
	"res://scenes/game/projectile.tscn",
	"res://scenes/game/grenade.tscn",
	"res://scenes/game/arena.tscn",
]


func _ready() -> void:
	var failures := 0
	for path in SCENES:
		var packed: PackedScene = load(path)
		if packed == null:
			printerr("FAIL load: %s" % path)
			failures += 1
			continue
		var instance := packed.instantiate()
		if instance == null:
			printerr("FAIL instantiate: %s" % path)
			failures += 1
			continue
		if instance.get_script() == null:
			printerr("FAIL missing script: %s" % path)
			failures += 1
		instance.free()
		print("OK  %s" % path)
	if failures > 0:
		printerr("%d scene(s) failed validation." % failures)
		get_tree().quit(1)
	else:
		print("All %d scenes validated." % SCENES.size())
		get_tree().quit(0)
