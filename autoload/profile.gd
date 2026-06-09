extends Node
## Profile autoload — local player profile: identity, progression, wallet,
## inventory, loadout and settings. Persisted as JSON in user://profile.json
## so it works on every platform (desktop, mobile, web/IndexedDB).

signal profile_changed
signal level_up(new_level: int)

const SAVE_PATH := "user://profile.json"
const STARTING_ITEMS: Array = ["pistol"]

var player_name: String = "Recruit"
var xp: int = 0
var level: int = 1
var coins: int = 500
var gold: int = 5
var kills: int = 0
var deaths: int = 0
var matches_played: int = 0
var owned_items: Array = []
var loadout: Dictionary = {
	"weapon": "pistol",
	"grenade": "",
	"perk": "",
}
var settings: Dictionary = {
	"music_volume": 0.8,
	"sfx_volume": 1.0,
	"fullscreen": false,
	"touch_controls": "auto",  # "auto" | "on" | "off"
}


func _ready() -> void:
	load_profile()


# ------------------------------------------------------------ progression --

## Total XP required to advance from `lvl` to `lvl + 1`.
func xp_needed(lvl: int) -> int:
	return 100 * lvl * lvl + 200 * lvl


func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_needed(level):
		xp -= xp_needed(level)
		level += 1
		level_up.emit(level)
	profile_changed.emit()
	save_profile()


func add_coins(amount: int) -> void:
	coins += amount
	profile_changed.emit()
	save_profile()


func add_gold(amount: int) -> void:
	gold += amount
	profile_changed.emit()
	save_profile()


func record_kill() -> void:
	kills += 1


func record_death() -> void:
	deaths += 1


func record_match() -> void:
	matches_played += 1
	save_profile()


# -------------------------------------------------------------- inventory --

func owns(item_id: String) -> bool:
	return item_id in owned_items


func can_afford(item_id: String) -> bool:
	var item: Dictionary = ItemDB.get_item(item_id)
	if item.is_empty():
		return false
	return coins >= int(item["price_coins"]) and gold >= int(item["price_gold"])


func is_unlocked(item_id: String) -> bool:
	var item: Dictionary = ItemDB.get_item(item_id)
	if item.is_empty():
		return false
	return level >= int(item["unlock_level"])


## Attempts a purchase. Returns an empty string on success or a
## human-readable error.
func purchase(item_id: String) -> String:
	var item: Dictionary = ItemDB.get_item(item_id)
	if item.is_empty():
		return "Unknown item."
	if owns(item_id):
		return "Already owned."
	if not is_unlocked(item_id):
		return "Requires level %d." % int(item["unlock_level"])
	if not can_afford(item_id):
		return "Not enough funds."
	coins -= int(item["price_coins"])
	gold -= int(item["price_gold"])
	owned_items.append(item_id)
	profile_changed.emit()
	save_profile()
	return ""


## Equips an owned item into its loadout slot. Returns "" or an error.
func equip(item_id: String) -> String:
	var item: Dictionary = ItemDB.get_item(item_id)
	if item.is_empty():
		return "Unknown item."
	if not owns(item_id):
		return "Not owned."
	match int(item["category"]):
		ItemDB.Category.WEAPON:
			loadout["weapon"] = item_id
		ItemDB.Category.GRENADE:
			loadout["grenade"] = item_id
		ItemDB.Category.PERK:
			loadout["perk"] = item_id
	profile_changed.emit()
	save_profile()
	return ""


func is_equipped(item_id: String) -> bool:
	return item_id in loadout.values()


# ------------------------------------------------------------- save/load ---

func save_profile() -> void:
	var data := {
		"player_name": player_name,
		"xp": xp,
		"level": level,
		"coins": coins,
		"gold": gold,
		"kills": kills,
		"deaths": deaths,
		"matches_played": matches_played,
		"owned_items": owned_items,
		"loadout": loadout,
		"settings": settings,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))


func load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		owned_items = STARTING_ITEMS.duplicate()
		save_profile()
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		owned_items = STARTING_ITEMS.duplicate()
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		owned_items = STARTING_ITEMS.duplicate()
		return
	var data: Dictionary = parsed
	player_name = str(data.get("player_name", player_name))
	xp = int(data.get("xp", xp))
	level = int(data.get("level", level))
	coins = int(data.get("coins", coins))
	gold = int(data.get("gold", gold))
	kills = int(data.get("kills", kills))
	deaths = int(data.get("deaths", deaths))
	matches_played = int(data.get("matches_played", matches_played))
	owned_items = data.get("owned_items", STARTING_ITEMS.duplicate())
	loadout = data.get("loadout", loadout)
	settings = data.get("settings", settings)
	for starter: String in STARTING_ITEMS:
		if starter not in owned_items:
			owned_items.append(starter)
	profile_changed.emit()


func set_player_name(new_name: String) -> void:
	new_name = new_name.strip_edges()
	if new_name.is_empty():
		return
	player_name = new_name.substr(0, 20)
	profile_changed.emit()
	save_profile()


## True when touch controls should be shown on this device.
func wants_touch_controls() -> bool:
	match str(settings.get("touch_controls", "auto")):
		"on":
			return true
		"off":
			return false
	return DisplayServer.is_touchscreen_available()
