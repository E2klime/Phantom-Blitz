extends Node
## Profile autoload — local player profile: identity, progression, wallet,
## inventory, loadout and settings. Persisted as JSON in user://profile.json
## so it works on every platform (desktop, mobile, web/IndexedDB).

signal profile_changed
signal level_up(new_level: int)

const SAVE_PATH := "user://profile.json"
const STARTING_ITEMS: Array = ["pistol"]
const GEAR_SLOTS: Array[String] = ["armor", "implant", "amulet_1", "amulet_2"]

var player_name: String = "Recruit"
var xp: int = 0
var level: int = 1
var silver: int = 500   # Silver coins — earned from kills, common currency.
var trinkets: int = 5   # Gold Trinkets — rare premium currency.
var kills: int = 0
var deaths: int = 0
var matches_played: int = 0
var owned_items: Array = []
## Trained skill ranks (see Stats.SKILLS). 1 skill point per level gained.
var skills: Dictionary = {
	"resilience": 0,
	"firepower": 0,
	"speed": 0,
	"intelligence": 0,
	"accuracy": 0,
	"defense": 0,
}
var loadout: Dictionary = {
	"weapon": "pistol",
	"grenade": "",
	"perk": "",
	"armor": "",
	"implant": "",
	"amulet_1": "",
	"amulet_2": "",
}
var settings: Dictionary = {
	"music_volume": 0.8,
	"sfx_volume": 1.0,
	"fullscreen": false,
	"touch_controls": "auto",  # "auto" | "on" | "off"
}

var _save_queued: bool = false


func _ready() -> void:
	load_profile()


func _notification(what: int) -> void:
	# Flush any pending save when the app closes or is backgrounded (mobile).
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		if _save_queued:
			_write_profile()


# ------------------------------------------------------------ progression --

## Total XP required to advance from `lvl` to `lvl + 1`.
func xp_needed(lvl: int) -> int:
	return 100 * lvl * lvl + 200 * lvl


func is_max_level() -> bool:
	return level >= Stats.MAX_LEVEL


func add_xp(amount: int) -> void:
	if is_max_level():
		return
	xp += amount
	while not is_max_level() and xp >= xp_needed(level):
		xp -= xp_needed(level)
		level += 1
		level_up.emit(level)
	if is_max_level():
		xp = 0
	profile_changed.emit()
	save_profile()


# ----------------------------------------------------------------- skills --

func skill_rank(skill: String) -> int:
	return int(skills.get(skill, 0))


func skill_points_earned() -> int:
	return Stats.points_for_level(level)


func skill_points_spent() -> int:
	var spent := 0
	for skill: String in skills:
		spent += Stats.total_cost(skill, skill_rank(skill))
	return spent


func skill_points_available() -> int:
	return skill_points_earned() - skill_points_spent()


## Buys the next rank of a skill. Returns "" on success or an error.
func upgrade_skill(skill: String) -> String:
	if not Stats.SKILLS.has(skill):
		return "Unknown skill."
	var next_rank := skill_rank(skill) + 1
	if next_rank > int(Stats.SKILLS[skill]["max_rank"]):
		return "Skill is already maxed."
	var required_level := Stats.rank_level_required(skill, next_rank)
	if level < required_level:
		return "Requires level %d." % required_level
	var cost := Stats.rank_cost(skill, next_rank)
	if skill_points_available() < cost:
		return "Not enough skill points (need %d)." % cost
	skills[skill] = next_rank
	profile_changed.emit()
	save_profile()
	return ""


## Total stat points per stat: trained ranks + equipped gear modifiers.
## Also carries "crit_bonus" (float) accumulated from gear.
func combat_stats() -> Dictionary:
	var points := {}
	for skill: String in Stats.SKILLS:
		points[skill] = skill_rank(skill)
	var crit_bonus := 0.0
	for slot: String in GEAR_SLOTS:
		var item: Dictionary = ItemDB.get_item(str(loadout.get(slot, "")))
		if item.is_empty():
			continue
		var mods: Dictionary = item.get("stat_mods", {})
		for stat: String in mods:
			points[stat] = int(points.get(stat, 0)) + int(mods[stat])
		crit_bonus += float(item.get("crit_bonus", 0.0))
	points["crit_bonus"] = crit_bonus
	return points


func add_silver(amount: int) -> void:
	silver = maxi(0, silver + amount)
	profile_changed.emit()
	save_profile()


func add_trinkets(amount: int) -> void:
	trinkets = maxi(0, trinkets + amount)
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


## Actual price after the Intelligence discount (4% per INT, max 44%).
func item_price(item_id: String) -> Dictionary:
	var item: Dictionary = ItemDB.get_item(item_id)
	if item.is_empty():
		return {"silver": 0, "trinkets": 0}
	var points := combat_stats()
	return {
		"silver": Stats.discounted_price(int(item["price_silver"]), points),
		"trinkets": Stats.discounted_price(int(item["price_trinkets"]), points),
	}


func can_afford(item_id: String) -> bool:
	var price := item_price(item_id)
	return silver >= int(price["silver"]) and trinkets >= int(price["trinkets"])


func is_unlocked(item_id: String) -> bool:
	var item: Dictionary = ItemDB.get_item(item_id)
	if item.is_empty():
		return false
	return level >= int(item["unlock_level"])


## Stat requirements the player does NOT meet yet: stat -> needed points.
func unmet_requirements(item_id: String) -> Dictionary:
	var item: Dictionary = ItemDB.get_item(item_id)
	var unmet := {}
	if item.is_empty():
		return unmet
	var points := combat_stats()
	var requirements: Dictionary = item.get("stat_requirements", {})
	for stat: String in requirements:
		if int(points.get(stat, 0)) < int(requirements[stat]):
			unmet[stat] = int(requirements[stat])
	return unmet


func meets_requirements(item_id: String) -> bool:
	return unmet_requirements(item_id).is_empty()


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
	var unmet := unmet_requirements(item_id)
	if not unmet.is_empty():
		var parts: Array[String] = []
		for stat: String in unmet:
			parts.append("%s %d" % [str(Stats.SKILLS[stat]["name"]), int(unmet[stat])])
		return "Requires %s." % ", ".join(parts)
	if not can_afford(item_id):
		return "Not enough funds."
	var price := item_price(item_id)
	silver -= int(price["silver"])
	trinkets -= int(price["trinkets"])
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
		ItemDB.Category.ARMOR:
			loadout["armor"] = item_id
		ItemDB.Category.IMPLANT:
			loadout["implant"] = item_id
		ItemDB.Category.AMULET:
			if is_equipped(item_id):
				return "Already equipped."
			# Fill an empty amulet slot first, otherwise swap the second one.
			if str(loadout.get("amulet_1", "")).is_empty():
				loadout["amulet_1"] = item_id
			elif str(loadout.get("amulet_2", "")).is_empty():
				loadout["amulet_2"] = item_id
			else:
				loadout["amulet_2"] = item_id
	profile_changed.emit()
	save_profile()
	return ""


## Removes an item from its loadout slot (weapons cannot be unequipped).
func unequip(item_id: String) -> String:
	var item: Dictionary = ItemDB.get_item(item_id)
	if item.is_empty():
		return "Unknown item."
	if int(item["category"]) == ItemDB.Category.WEAPON:
		return "A weapon must stay equipped."
	for slot: String in loadout:
		if str(loadout[slot]) == item_id:
			loadout[slot] = ""
			profile_changed.emit()
			save_profile()
			return ""
	return "Not equipped."


func is_equipped(item_id: String) -> bool:
	return item_id in loadout.values()


# ------------------------------------------------------------- save/load ---

## Queues a save. Writes are coalesced to one per frame so bursts of
## profile updates (XP + silver on every kill) hit the disk / IndexedDB
## only once — important on web and mobile.
func save_profile() -> void:
	if _save_queued:
		return
	_save_queued = true
	_write_profile.call_deferred()


func _write_profile() -> void:
	_save_queued = false
	var data := {
		"player_name": player_name,
		"xp": xp,
		"level": level,
		"silver": silver,
		"trinkets": trinkets,
		"kills": kills,
		"deaths": deaths,
		"matches_played": matches_played,
		"owned_items": owned_items,
		"skills": skills,
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
	level = clampi(int(data.get("level", level)), 1, Stats.MAX_LEVEL)
	# "coins"/"gold" are legacy keys from pre-currency-rework saves.
	silver = int(data.get("silver", data.get("coins", silver)))
	trinkets = int(data.get("trinkets", data.get("gold", trinkets)))
	kills = int(data.get("kills", kills))
	deaths = int(data.get("deaths", deaths))
	matches_played = int(data.get("matches_played", matches_played))
	owned_items = data.get("owned_items", STARTING_ITEMS.duplicate())
	# Merge stored dictionaries key-by-key so saves from older versions
	# (missing the newer keys) keep working.
	_merge_stored(skills, data.get("skills", {}))
	_merge_stored(loadout, data.get("loadout", {}))
	_merge_stored(settings, data.get("settings", {}))
	for skill: String in skills:
		var max_rank := int(Stats.SKILLS.get(skill, {}).get("max_rank", 0))
		skills[skill] = clampi(int(skills[skill]), 0, max_rank)
	for starter: String in STARTING_ITEMS:
		if starter not in owned_items:
			owned_items.append(starter)
	profile_changed.emit()


func _merge_stored(target: Dictionary, stored: Variant) -> void:
	if typeof(stored) != TYPE_DICTIONARY:
		return
	for key: Variant in target:
		if (stored as Dictionary).has(key):
			target[key] = stored[key]


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
