extends Control
## Main menu — entry point of the game. Also picks the match mode and map
## used when hosting or practicing offline (Game.set_match_config).

@onready var name_label: Label = %NameLabel
@onready var level_label: Label = %LevelLabel
@onready var silver_label: Label = %SilverLabel
@onready var trinkets_label: Label = %TrinketsLabel
@onready var quit_button: Button = %QuitButton
@onready var mode_select: OptionButton = %ModeSelect
@onready var map_select: OptionButton = %MapSelect
@onready var mode_hint: Label = %ModeHint

var _mode_ids: Array = []
var _map_ids: Array[String] = []


func _ready() -> void:
	Profile.profile_changed.connect(_refresh)
	_refresh()
	_populate_match_setup()
	if OS.has_feature("web"):
		quit_button.hide()


func _refresh() -> void:
	name_label.text = Profile.player_name
	level_label.text = "LV %d" % Profile.level
	silver_label.text = "%d Silver" % Profile.silver
	trinkets_label.text = "%d Trinkets" % Profile.trinkets


func _populate_match_setup() -> void:
	mode_select.clear()
	_mode_ids.clear()
	for mode_id: int in Game.MODES:
		_mode_ids.append(mode_id)
		mode_select.add_item(str(Game.MODES[mode_id]["name"]))
		if mode_id == Game.mode:
			mode_select.select(mode_select.item_count - 1)

	map_select.clear()
	_map_ids = MapDB.ids()
	for i in _map_ids.size():
		map_select.add_item(str(MapDB.get_map(_map_ids[i])["name"]))
		if _map_ids[i] == Game.map_id:
			map_select.select(i)
	_update_hint()


func _update_hint() -> void:
	var info: Dictionary = Game.mode_info()
	var desc := str(info["description"])
	if desc.contains("%d"):
		desc = desc % Game.score_limit()
	mode_hint.text = "%s  —  %s" % [desc, str(MapDB.get_map(Game.map_id)["description"])]


func _apply_match_setup() -> void:
	var mode_idx := mode_select.selected
	var map_idx := map_select.selected
	if mode_idx >= 0 and map_idx >= 0:
		Game.set_match_config(int(_mode_ids[mode_idx]), _map_ids[map_idx])
	_update_hint()


func _on_mode_select_item_selected(_index: int) -> void:
	_apply_match_setup()


func _on_map_select_item_selected(_index: int) -> void:
	_apply_match_setup()


func _on_play_online_pressed() -> void:
	_apply_match_setup()
	Game.goto_scene("res://scenes/ui/server_browser.tscn")


func _on_play_offline_pressed() -> void:
	_apply_match_setup()
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
