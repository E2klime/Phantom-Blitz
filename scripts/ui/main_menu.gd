extends Control
## Main menu — entry point of the game.

@onready var name_label: Label = %NameLabel
@onready var level_label: Label = %LevelLabel
@onready var coins_label: Label = %CoinsLabel
@onready var gold_label: Label = %GoldLabel
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	Profile.profile_changed.connect(_refresh)
	_refresh()
	if OS.has_feature("web"):
		quit_button.hide()


func _refresh() -> void:
	name_label.text = Profile.player_name
	level_label.text = "LV %d" % Profile.level
	coins_label.text = "%d ¢" % Profile.coins
	gold_label.text = "%d G" % Profile.gold


func _on_play_online_pressed() -> void:
	Game.goto_scene("res://scenes/ui/server_browser.tscn")


func _on_play_offline_pressed() -> void:
	Net.start_offline()
	Game.start_match()


func _on_store_pressed() -> void:
	Game.goto_scene("res://scenes/ui/store.tscn")


func _on_profile_pressed() -> void:
	Game.goto_scene("res://scenes/ui/profile_screen.tscn")


func _on_settings_pressed() -> void:
	Game.goto_scene("res://scenes/ui/settings.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
