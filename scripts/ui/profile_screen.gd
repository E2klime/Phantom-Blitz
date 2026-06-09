extends Control
## Profile screen — identity, progression, stats, loadout management.

@onready var name_edit: LineEdit = %NameEdit
@onready var level_label: Label = %LevelLabel
@onready var xp_bar: ProgressBar = %XpBar
@onready var xp_label: Label = %XpLabel
@onready var stats_label: Label = %StatsLabel
@onready var loadout_label: Label = %LoadoutLabel
@onready var owned_list: ItemList = %OwnedList
@onready var equip_button: Button = %EquipButton

var _owned_ids: Array[String] = []


func _ready() -> void:
	Profile.profile_changed.connect(_refresh)
	name_edit.text = Profile.player_name
	_refresh()


func _refresh() -> void:
	level_label.text = "Level %d" % Profile.level
	xp_bar.max_value = Profile.xp_needed(Profile.level)
	xp_bar.value = Profile.xp
	xp_label.text = "EXP  %d / %d" % [Profile.xp, Profile.xp_needed(Profile.level)]

	var kd := float(Profile.kills) / maxf(1.0, float(Profile.deaths))
	stats_label.text = "Kills: %d\nDeaths: %d\nK/D: %.2f\nMatches: %d\nCoins: %d ¢\nGold: %d G" % [
		Profile.kills, Profile.deaths, kd, Profile.matches_played, Profile.coins, Profile.gold]

	loadout_label.text = "Weapon:  %s\nGrenade: %s\nPerk:    %s" % [
		_item_name(str(Profile.loadout.get("weapon", ""))),
		_item_name(str(Profile.loadout.get("grenade", ""))),
		_item_name(str(Profile.loadout.get("perk", "")))]

	_owned_ids.clear()
	owned_list.clear()
	for id: String in Profile.owned_items:
		var item: Dictionary = ItemDB.get_item(id)
		if item.is_empty():
			continue
		_owned_ids.append(id)
		var suffix := "  [equipped]" if Profile.is_equipped(id) else ""
		owned_list.add_item("%s%s" % [item["name"], suffix])
	equip_button.disabled = owned_list.get_selected_items().is_empty()


func _item_name(id: String) -> String:
	var item: Dictionary = ItemDB.get_item(id)
	return str(item["name"]) if not item.is_empty() else "—"


func _on_owned_list_item_selected(_index: int) -> void:
	equip_button.disabled = false


func _on_equip_button_pressed() -> void:
	var selected := owned_list.get_selected_items()
	if selected.is_empty():
		return
	Profile.equip(_owned_ids[selected[0]])


func _on_apply_name_pressed() -> void:
	Profile.set_player_name(name_edit.text)
	name_edit.text = Profile.player_name


func _on_back_pressed() -> void:
	Game.goto_scene("res://scenes/ui/main_menu.tscn")
