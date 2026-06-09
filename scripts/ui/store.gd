extends Control
## Store — browse the ItemDB by category, buy with Silver/Trinkets, equip.
## Weapons can additionally be filtered by class (pistol ... exotic).

@onready var silver_label: Label = %SilverLabel
@onready var trinkets_label: Label = %TrinketsLabel
@onready var item_list: ItemList = %ItemList
@onready var class_filter: OptionButton = %ClassFilter
@onready var detail_name: Label = %DetailName
@onready var detail_desc: Label = %DetailDesc
@onready var detail_stats: Label = %DetailStats
@onready var detail_price: Label = %DetailPrice
@onready var action_button: Button = %ActionButton
@onready var status_label: Label = %StatusLabel
# Index in this array == ItemDB.Category value.
@onready var category_buttons: Array[Button] = [
	%WeaponsTab, %GrenadesTab, %PerksTab, %ArmorTab, %ImplantsTab, %AmuletsTab]

var _category: int = ItemDB.Category.WEAPON
var _weapon_class: int = -1  # -1 = all classes
var _ids: Array[String] = []


func _ready() -> void:
	Profile.profile_changed.connect(_refresh_wallet)
	_refresh_wallet()
	_populate_class_filter()
	_select_category(ItemDB.Category.WEAPON)


func _refresh_wallet() -> void:
	silver_label.text = "%d Silver" % Profile.silver
	trinkets_label.text = "%d Trinkets" % Profile.trinkets


func _populate_class_filter() -> void:
	class_filter.clear()
	class_filter.add_item("All classes")
	for weapon_type: int in ItemDB.WEAPON_TYPE_NAMES:
		class_filter.add_item(ItemDB.weapon_type_name(weapon_type))
	class_filter.select(0)


func _on_weapons_tab_pressed() -> void:
	_select_category(ItemDB.Category.WEAPON)


func _on_grenades_tab_pressed() -> void:
	_select_category(ItemDB.Category.GRENADE)


func _on_perks_tab_pressed() -> void:
	_select_category(ItemDB.Category.PERK)


func _on_armor_tab_pressed() -> void:
	_select_category(ItemDB.Category.ARMOR)


func _on_implants_tab_pressed() -> void:
	_select_category(ItemDB.Category.IMPLANT)


func _on_amulets_tab_pressed() -> void:
	_select_category(ItemDB.Category.AMULET)


func _on_class_filter_item_selected(index: int) -> void:
	_weapon_class = index - 1  # item 0 is "All classes"
	_refresh_items()


func _select_category(category: int) -> void:
	_category = category
	for i in category_buttons.size():
		category_buttons[i].button_pressed = i == category
	class_filter.visible = category == ItemDB.Category.WEAPON
	_refresh_items()


func _refresh_items() -> void:
	item_list.clear()
	if _category == ItemDB.Category.WEAPON:
		_ids = ItemDB.get_weapons_by_type(_weapon_class)
	else:
		_ids = ItemDB.get_items_by_category(_category)
	for id in _ids:
		var item: Dictionary = ItemDB.get_item(id)
		var suffix := ""
		if Profile.is_equipped(id):
			suffix = "  [equipped]"
		elif Profile.owns(id):
			suffix = "  [owned]"
		elif not Profile.is_unlocked(id):
			suffix = "  [LV %d]" % int(item["unlock_level"])
		elif not Profile.meets_requirements(id):
			suffix = "  [stats too low]"
		item_list.add_item("%s%s" % [item["name"], suffix])
	_show_details(-1)


func _on_item_selected(index: int) -> void:
	_show_details(index)


func _show_details(index: int) -> void:
	status_label.text = ""
	if index < 0 or index >= _ids.size():
		detail_name.text = "Select an item"
		detail_desc.text = ""
		detail_stats.text = ""
		detail_price.text = ""
		action_button.disabled = true
		action_button.text = "Buy"
		return
	var id := _ids[index]
	var item: Dictionary = ItemDB.get_item(id)
	detail_name.text = str(item["name"])
	detail_desc.text = str(item["description"])
	detail_stats.text = _stats_text(item)
	detail_price.text = _price_text(id, item)
	action_button.disabled = false
	if Profile.is_equipped(id):
		action_button.text = "Equipped"
		action_button.disabled = true
	elif Profile.owns(id):
		action_button.text = "Equip"
	else:
		action_button.text = "Buy"


func _stats_text(item: Dictionary) -> String:
	match int(item["category"]):
		ItemDB.Category.WEAPON:
			var text := "Class: %s\nDamage: %d   Rate: %.1f/s\nClip: %d   Reload: %.1fs" % [
				ItemDB.weapon_type_name(int(item["weapon_type"])),
				int(item["damage"]), float(item["fire_rate"]),
				int(item["clip_size"]), float(item["reload_time"])]
			if bool(item.get("explosive", false)):
				text += "\nExplosive (blast radius %d)" % int(item.get("blast_radius", 0))
			return text
		ItemDB.Category.GRENADE:
			return "Damage: %d   Radius: %d\nCarry: %d" % [
				int(item["damage"]), int(item["radius"]), int(item["carry_count"])]
		ItemDB.Category.PERK:
			return "HP bonus: +%d   Speed: x%.2f" % [
				int(item["max_hp_bonus"]), float(item["speed_mult"])]
		ItemDB.Category.ARMOR, ItemDB.Category.IMPLANT, ItemDB.Category.AMULET:
			return _gear_stats_text(item)
	return ""


func _gear_stats_text(item: Dictionary) -> String:
	var lines: Array[String] = []
	var mods: Dictionary = item.get("stat_mods", {})
	for stat: String in mods:
		var value := int(mods[stat])
		lines.append("%s %s%d" % [_stat_name(stat), "+" if value >= 0 else "", value])
	if float(item.get("crit_bonus", 0.0)) > 0.0:
		lines.append("Crit damage +%d%%" % int(roundf(float(item["crit_bonus"]) * 100.0)))
	return "\n".join(lines) if not lines.is_empty() else "No stat changes"


func _stat_name(stat: String) -> String:
	return str(Stats.SKILLS.get(stat, {}).get("name", stat.capitalize()))


func _price_text(id: String, item: Dictionary) -> String:
	var price := Profile.item_price(id)
	var parts: Array[String] = []
	if int(item["price_silver"]) > 0:
		parts.append(_price_part(int(item["price_silver"]), int(price["silver"]), "Silver"))
	if int(item["price_trinkets"]) > 0:
		parts.append(_price_part(int(item["price_trinkets"]), int(price["trinkets"]), "Trinkets"))
	var text := "Free" if parts.is_empty() else " + ".join(parts)
	text += "   (unlocks at LV %d)" % int(item["unlock_level"])
	var requirements: Dictionary = item.get("stat_requirements", {})
	if not requirements.is_empty():
		var req_parts: Array[String] = []
		for stat: String in requirements:
			req_parts.append("%s %d" % [_stat_name(stat), int(requirements[stat])])
		text += "\nRequires: %s" % ", ".join(req_parts)
	return text


## Shows the Intelligence discount: "24000 -> 21120 Silver".
func _price_part(base: int, discounted: int, currency: String) -> String:
	if discounted < base:
		return "%d -> %d %s" % [base, discounted, currency]
	return "%d %s" % [base, currency]


func _on_action_button_pressed() -> void:
	var selected := item_list.get_selected_items()
	if selected.is_empty():
		return
	var index := selected[0]
	var id := _ids[index]
	var err: String
	if Profile.owns(id):
		err = Profile.equip(id)
	else:
		err = Profile.purchase(id)
	status_label.text = err if not err.is_empty() else "Done!"
	_refresh_items()
	item_list.select(index)
	_show_details(index)


func _on_back_pressed() -> void:
	Game.goto_scene("res://scenes/ui/main_menu.tscn")
