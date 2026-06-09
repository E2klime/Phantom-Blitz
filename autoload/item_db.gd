extends Node
## ItemDB autoload — static database of every purchasable / equippable item.
##
## Adding new content is data-driven: append a new entry to ITEMS and it
## automatically appears in the Store, the Profile loadout and (for weapons)
## becomes usable in-game. See docs/EXTENDING.md.

enum Category { WEAPON, GRENADE, PERK }

const ITEMS: Dictionary = {
	# ----------------------------------------------------------- weapons ---
	"pistol": {
		"name": "P-9 Pistol",
		"category": Category.WEAPON,
		"description": "Reliable sidearm. Everyone starts with one.",
		"price_coins": 0,
		"price_gold": 0,
		"unlock_level": 1,
		"damage": 12,
		"fire_rate": 3.5,          # shots per second
		"automatic": false,
		"projectile_speed": 1400.0,
		"pellets": 1,
		"spread_deg": 1.5,
		"clip_size": 12,
		"reload_time": 1.1,
		"color": Color(0.85, 0.85, 0.9),
	},
	"uzi": {
		"name": "Vector SMG",
		"category": Category.WEAPON,
		"description": "High rate of fire, low damage per bullet.",
		"price_coins": 1200,
		"price_gold": 0,
		"unlock_level": 2,
		"damage": 7,
		"fire_rate": 11.0,
		"automatic": true,
		"projectile_speed": 1500.0,
		"pellets": 1,
		"spread_deg": 5.0,
		"clip_size": 32,
		"reload_time": 1.6,
		"color": Color(0.95, 0.8, 0.3),
	},
	"shotgun": {
		"name": "Riot Shotgun",
		"category": Category.WEAPON,
		"description": "Devastating up close. 6 pellets per shell.",
		"price_coins": 2600,
		"price_gold": 0,
		"unlock_level": 4,
		"damage": 9,
		"fire_rate": 1.4,
		"automatic": false,
		"projectile_speed": 1200.0,
		"pellets": 6,
		"spread_deg": 14.0,
		"clip_size": 6,
		"reload_time": 2.2,
		"color": Color(0.9, 0.45, 0.2),
	},
	"rifle": {
		"name": "AR-77 Rifle",
		"category": Category.WEAPON,
		"description": "Balanced automatic rifle for mid range.",
		"price_coins": 5200,
		"price_gold": 0,
		"unlock_level": 6,
		"damage": 14,
		"fire_rate": 7.0,
		"automatic": true,
		"projectile_speed": 1900.0,
		"pellets": 1,
		"spread_deg": 2.5,
		"clip_size": 25,
		"reload_time": 1.8,
		"color": Color(0.4, 0.85, 0.45),
	},
	"sniper": {
		"name": "Longshot DSR",
		"category": Category.WEAPON,
		"description": "One bullet, one story. Slow but lethal.",
		"price_coins": 9000,
		"price_gold": 25,
		"unlock_level": 9,
		"damage": 70,
		"fire_rate": 0.8,
		"automatic": false,
		"projectile_speed": 3200.0,
		"pellets": 1,
		"spread_deg": 0.0,
		"clip_size": 4,
		"reload_time": 2.6,
		"color": Color(0.5, 0.7, 1.0),
	},
	# ---------------------------------------------------------- grenades ---
	"frag_grenade": {
		"name": "Frag Grenade",
		"category": Category.GRENADE,
		"description": "Classic fragmentation grenade.",
		"price_coins": 800,
		"price_gold": 0,
		"unlock_level": 3,
		"damage": 55,
		"radius": 120.0,
		"fuse": 1.4,
		"throw_speed": 900.0,
		"carry_count": 2,
		"color": Color(0.45, 0.55, 0.35),
	},
	# ------------------------------------------------------------- perks ---
	"light_armor": {
		"name": "Light Vest",
		"category": Category.PERK,
		"description": "+25 max HP.",
		"price_coins": 2000,
		"price_gold": 0,
		"unlock_level": 3,
		"max_hp_bonus": 25,
		"speed_mult": 1.0,
		"color": Color(0.6, 0.6, 0.65),
	},
	"heavy_armor": {
		"name": "Heavy Plate",
		"category": Category.PERK,
		"description": "+60 max HP, but 10% slower.",
		"price_coins": 6500,
		"price_gold": 10,
		"unlock_level": 7,
		"max_hp_bonus": 60,
		"speed_mult": 0.9,
		"color": Color(0.35, 0.4, 0.5),
	},
	"sprint_boots": {
		"name": "Sprint Boots",
		"category": Category.PERK,
		"description": "+15% movement speed.",
		"price_coins": 3000,
		"price_gold": 0,
		"unlock_level": 5,
		"max_hp_bonus": 0,
		"speed_mult": 1.15,
		"color": Color(0.9, 0.3, 0.6),
	},
}


func get_item(id: String) -> Dictionary:
	return ITEMS.get(id, {})


func has_item(id: String) -> bool:
	return ITEMS.has(id)


func get_items_by_category(category: int) -> Array[String]:
	var result: Array[String] = []
	for id: String in ITEMS:
		if ITEMS[id]["category"] == category:
			result.append(id)
	return result


func category_name(category: int) -> String:
	match category:
		Category.WEAPON:
			return "Weapons"
		Category.GRENADE:
			return "Grenades"
		Category.PERK:
			return "Perks"
	return "Other"
