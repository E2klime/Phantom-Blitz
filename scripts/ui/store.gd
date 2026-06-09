extends Control
## Store — browse the ItemDB by category, buy with coins/gold, equip.

@onready var coins_label: Label = %CoinsLabel
@onready var gold_label: Label = %GoldLabel
@onready var item_list: ItemList = %ItemList
@onready var detail_name: Label = %DetailName
@onready var detail_desc: Label = %DetailDesc
@onready var detail_stats: Label = %DetailStats
@onready var detail_price: Label = %DetailPrice
@onready var action_button: Button = %ActionButton
@onready var status_label: Label = %StatusLabel
@onready var category_buttons: Array[Button] = [%WeaponsTab, %GrenadesTab, %PerksTab]

var _category: int = ItemDB.Category.WEAPON
var _ids: Array[String] = []


func _ready() -> void:
	Profile.profile_changed.connect(_refresh_wallet)
	_refresh_wallet()
	_select_category(ItemDB.Category.WEAPON)


func _refresh_wallet() -> void:
	coins_label.text = "%d ¢" % Profile.coins
	gold_label.text = "%d G" % Profile.gold


func _on_weapons_tab_pressed() -> void:
	_select_category(ItemDB.Category.WEAPON)


func _on_grenades_tab_pressed() -> void:
	_select_category(ItemDB.Category.GRENADE)


func _on_perks_tab_pressed() -> void:
	_select_category(ItemDB.Category.PERK)


func _select_category(category: int) -> void:
	_category = category
	for i in category_buttons.size():
		category_buttons[i].button_pressed = i == category
	_refresh_items()


func _refresh_items() -> void:
	item_list.clear()
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
	detail_price.text = _price_text(item)
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
			return "Damage: %d   Rate: %.1f/s\nClip: %d   Reload: %.1fs" % [
				int(item["damage"]), float(item["fire_rate"]),
				int(item["clip_size"]), float(item["reload_time"])]
		ItemDB.Category.GRENADE:
			return "Damage: %d   Radius: %d\nCarry: %d" % [
				int(item["damage"]), int(item["radius"]), int(item["carry_count"])]
		ItemDB.Category.PERK:
			return "HP bonus: +%d   Speed: x%.2f" % [
				int(item["max_hp_bonus"]), float(item["speed_mult"])]
	return ""


func _price_text(item: Dictionary) -> String:
	var parts: Array[String] = []
	if int(item["price_coins"]) > 0:
		parts.append("%d ¢" % int(item["price_coins"]))
	if int(item["price_gold"]) > 0:
		parts.append("%d G" % int(item["price_gold"]))
	if parts.is_empty():
		return "Free"
	return " + ".join(parts) + "   (unlocks at LV %d)" % int(item["unlock_level"])


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
