extends Control
## Profile screen — identity, progression, skill upgrades, stats and
## loadout management (weapon, grenade, perk + armor / implant / amulets).

@onready var name_edit: LineEdit = %NameEdit
@onready var level_label: Label = %LevelLabel
@onready var xp_bar: ProgressBar = %XpBar
@onready var xp_label: Label = %XpLabel
@onready var stats_label: Label = %StatsLabel
@onready var loadout_label: Label = %LoadoutLabel
@onready var owned_list: ItemList = %OwnedList
@onready var equip_button: Button = %EquipButton
@onready var points_label: Label = %PointsLabel
@onready var skills_box: VBoxContainer = %SkillsBox
@onready var skill_status: Label = %SkillStatus
@onready var derived_label: Label = %DerivedLabel

var _owned_ids: Array[String] = []
var _skill_buttons: Dictionary = {}  # skill -> Button
var _skill_labels: Dictionary = {}   # skill -> Label


func _ready() -> void:
	Profile.profile_changed.connect(_refresh)
	name_edit.text = Profile.player_name
	_build_skill_rows()
	_refresh()


func _build_skill_rows() -> void:
	for skill: String in Stats.SKILLS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.tooltip_text = str(Stats.SKILLS[skill]["description"])
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		row.add_child(label)
		var button := Button.new()
		button.custom_minimum_size = Vector2(96, 0)
		button.pressed.connect(_on_skill_upgrade_pressed.bind(skill))
		row.add_child(button)
		skills_box.add_child(row)
		_skill_labels[skill] = label
		_skill_buttons[skill] = button


func _refresh() -> void:
	level_label.text = "Level %d" % Profile.level
	if Profile.is_max_level():
		xp_bar.max_value = 1
		xp_bar.value = 1
		xp_label.text = "EXP  MAX LEVEL"
	else:
		xp_bar.max_value = Profile.xp_needed(Profile.level)
		xp_bar.value = Profile.xp
		xp_label.text = "EXP  %d / %d" % [Profile.xp, Profile.xp_needed(Profile.level)]

	var kd := float(Profile.kills) / maxf(1.0, float(Profile.deaths))
	stats_label.text = "Kills: %d\nDeaths: %d\nK/D: %.2f\nMatches: %d\nSilver: %d\nTrinkets: %d" % [
		Profile.kills, Profile.deaths, kd, Profile.matches_played, Profile.silver, Profile.trinkets]

	loadout_label.text = "Weapon:   %s\nGrenade:  %s\nPerk:     %s\nArmor:    %s\nImplant:  %s\nAmulet 1: %s\nAmulet 2: %s" % [
		_item_name(str(Profile.loadout.get("weapon", ""))),
		_item_name(str(Profile.loadout.get("grenade", ""))),
		_item_name(str(Profile.loadout.get("perk", ""))),
		_item_name(str(Profile.loadout.get("armor", ""))),
		_item_name(str(Profile.loadout.get("implant", ""))),
		_item_name(str(Profile.loadout.get("amulet_1", ""))),
		_item_name(str(Profile.loadout.get("amulet_2", "")))]

	_refresh_skills()
	_refresh_owned()


func _refresh_skills() -> void:
	points_label.text = "Skill points: %d  (earned %d / %d)" % [
		Profile.skill_points_available(), Profile.skill_points_earned(),
		Stats.points_for_level(Stats.MAX_LEVEL)]
	for skill: String in Stats.SKILLS:
		var info: Dictionary = Stats.SKILLS[skill]
		var rank := Profile.skill_rank(skill)
		var max_rank := int(info["max_rank"])
		(_skill_labels[skill] as Label).text = "%s  %d / %d" % [str(info["name"]), rank, max_rank]
		var button: Button = _skill_buttons[skill]
		if rank >= max_rank:
			button.text = "MAX"
			button.disabled = true
			continue
		var next_rank := rank + 1
		var cost := Stats.rank_cost(skill, next_rank)
		var required_level := Stats.rank_level_required(skill, next_rank)
		if Profile.level < required_level:
			button.text = "LV %d" % required_level
			button.disabled = true
		else:
			button.text = "+ (%d pt)" % cost
			button.disabled = Profile.skill_points_available() < cost

	var points := Profile.combat_stats()
	derived_label.text = "HP: %d\nDamage: x%.2f   Crit: %d%% (x%.1f)\nSpeed: %d\nAccuracy: %d%%\nDefense: %d%%\nIntelligence: %d  (-%d%% prices)" % [
		Stats.max_hp(points),
		Stats.damage_mult(points),
		int(roundf(Stats.crit_chance(points) * 100.0)),
		Stats.crit_damage_mult(points),
		Stats.speed_value(points),
		int(roundf(Stats.accuracy(points) * 100.0)),
		int(roundf(Stats.defense_ratio(points) * 100.0)),
		Stats.intelligence_value(points),
		int(roundf(Stats.price_discount(points) * 100.0))]


func _refresh_owned() -> void:
	var selected := owned_list.get_selected_items()
	var selected_id := ""
	if not selected.is_empty() and selected[0] < _owned_ids.size():
		selected_id = _owned_ids[selected[0]]
	_owned_ids.clear()
	owned_list.clear()
	for id: String in Profile.owned_items:
		var item: Dictionary = ItemDB.get_item(id)
		if item.is_empty():
			continue
		_owned_ids.append(id)
		var suffix := "  [equipped]" if Profile.is_equipped(id) else ""
		owned_list.add_item("%s%s" % [item["name"], suffix])
	# Keep the selection across refreshes (e.g. right after equipping).
	var restored := _owned_ids.find(selected_id)
	if restored != -1:
		owned_list.select(restored)
	_update_equip_button()


func _update_equip_button() -> void:
	var selected := owned_list.get_selected_items()
	if selected.is_empty() or selected[0] >= _owned_ids.size():
		equip_button.disabled = true
		equip_button.text = "Equip selected"
		return
	var id := _owned_ids[selected[0]]
	equip_button.disabled = false
	if Profile.is_equipped(id):
		var category := int(ItemDB.get_item(id).get("category", -1))
		if category == ItemDB.Category.WEAPON:
			equip_button.disabled = true
			equip_button.text = "Equipped"
		else:
			equip_button.text = "Unequip"
	else:
		equip_button.text = "Equip"


func _item_name(id: String) -> String:
	var item: Dictionary = ItemDB.get_item(id)
	return str(item["name"]) if not item.is_empty() else "—"


func _on_skill_upgrade_pressed(skill: String) -> void:
	var err := Profile.upgrade_skill(skill)
	skill_status.text = err


func _on_owned_list_item_selected(_index: int) -> void:
	_update_equip_button()


func _on_equip_button_pressed() -> void:
	var selected := owned_list.get_selected_items()
	if selected.is_empty():
		return
	var id := _owned_ids[selected[0]]
	if Profile.is_equipped(id):
		Profile.unequip(id)
	else:
		Profile.equip(id)


func _on_apply_name_pressed() -> void:
	Profile.set_player_name(name_edit.text)
	name_edit.text = Profile.player_name


func _on_back_pressed() -> void:
	Game.goto_scene("res://scenes/ui/main_menu.tscn")
