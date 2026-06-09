extends Node
## ItemDB autoload — static database of every purchasable / equippable item.
##
## Weapons are split into 8 classes (no melee in this game): PISTOL, SMG,
## SHOTGUN, RIFLE, SNIPER, LMG, LAUNCHER and EXOTIC. Prices use the two
## currencies: Silver coins (earned from kills) and Trinkets (premium).
##
## Adding new content is data-driven: append a new entry in _build_items()
## and it automatically appears in the Store, the Profile loadout and (for
## weapons) becomes usable in-game. See docs/EXTENDING.md.

enum Category { WEAPON, GRENADE, PERK }
enum WeaponType { PISTOL, SMG, SHOTGUN, RIFLE, SNIPER, LMG, LAUNCHER, EXOTIC }

const WEAPON_TYPE_NAMES: Dictionary = {
	WeaponType.PISTOL: "Pistols",
	WeaponType.SMG: "SMGs",
	WeaponType.SHOTGUN: "Shotguns",
	WeaponType.RIFLE: "Rifles",
	WeaponType.SNIPER: "Snipers",
	WeaponType.LMG: "LMGs",
	WeaponType.LAUNCHER: "Launchers",
	WeaponType.EXOTIC: "Exotic",
}

var ITEMS: Dictionary = {}


func _init() -> void:
	_build_items()


## Compact weapon entry builder. Args:
## type, name, desc, lvl, silver, trinkets, dmg, rate, auto, speed,
## pellets, spread, clip, reload, color, extra (e.g. explosive weapons).
func _w(id: String, type: int, name_: String, desc: String, lvl: int,
		silver: int, trinkets: int, dmg: int, rate: float, auto: bool,
		speed: float, pellets: int, spread: float, clip: int, reload: float,
		color: Color, extra: Dictionary = {}) -> void:
	var entry := {
		"name": name_,
		"category": Category.WEAPON,
		"weapon_type": type,
		"description": desc,
		"price_silver": silver,
		"price_trinkets": trinkets,
		"unlock_level": lvl,
		"damage": dmg,
		"fire_rate": rate,
		"automatic": auto,
		"projectile_speed": speed,
		"pellets": pellets,
		"spread_deg": spread,
		"clip_size": clip,
		"reload_time": reload,
		"color": color,
	}
	entry.merge(extra)
	ITEMS[id] = entry


func _build_items() -> void:
	var P := WeaponType.PISTOL
	var S := WeaponType.SMG
	var SG := WeaponType.SHOTGUN
	var R := WeaponType.RIFLE
	var SN := WeaponType.SNIPER
	var L := WeaponType.LMG
	var LA := WeaponType.LAUNCHER
	var EX := WeaponType.EXOTIC

	# ------------------------------------------------------------ pistols (8)
	_w("pistol", P, "P-9 Pistol", "Reliable sidearm. Everyone starts with one.",
		1, 0, 0, 12, 3.5, false, 1400.0, 1, 1.5, 12, 1.1, Color(0.85, 0.85, 0.9))
	_w("rust_revolver", P, "Rusty Revolver", "Old iron with a heavy punch.",
		1, 300, 0, 22, 1.6, false, 1500.0, 1, 2.0, 6, 1.6, Color(0.7, 0.5, 0.35))
	_w("compact_88", P, "Compact 88", "Pocket pistol with a generous clip.",
		3, 900, 0, 10, 5.0, false, 1450.0, 1, 2.2, 15, 1.0, Color(0.75, 0.8, 0.85))
	_w("heavy_magnum", P, "Magnum .44", "Slow, loud and very persuasive.",
		6, 2400, 0, 34, 1.2, false, 1800.0, 1, 1.0, 6, 1.8, Color(0.55, 0.55, 0.6))
	_w("tactic_p12", P, "Tactic P-12", "Service pistol with match trigger.",
		9, 4200, 0, 14, 4.5, false, 1600.0, 1, 1.2, 18, 1.0, Color(0.45, 0.6, 0.7))
	_w("dual_vipers", P, "Dual Vipers", "Two machine pistols, zero discipline.",
		13, 7000, 0, 9, 8.0, true, 1450.0, 1, 6.0, 26, 1.7, Color(0.85, 0.65, 0.25))
	_w("hand_cannon", P, "Hand Cannon", "Basically a portable artillery piece.",
		18, 11000, 5, 48, 0.9, false, 1900.0, 1, 0.8, 5, 2.0, Color(0.4, 0.42, 0.48))
	_w("golden_judge", P, "Golden Judge", "Gilded revolver of the arena elite.",
		24, 16000, 20, 30, 2.6, false, 1900.0, 1, 0.6, 8, 1.4, Color(1.0, 0.84, 0.25))

	# --------------------------------------------------------------- SMGs (8)
	_w("uzi", S, "Vector SMG", "High rate of fire, low damage per bullet.",
		2, 1200, 0, 7, 11.0, true, 1500.0, 1, 5.0, 32, 1.6, Color(0.95, 0.8, 0.3))
	_w("scorpion_vz", S, "Scorpion VZ", "Light skeleton SMG for run-and-gun.",
		4, 1800, 0, 8, 10.0, true, 1500.0, 1, 4.5, 30, 1.5, Color(0.8, 0.75, 0.45))
	_w("korsak_mp", S, "Korsak MP", "Vintage stamped-steel bullet hose.",
		7, 3200, 0, 9, 11.0, true, 1450.0, 1, 5.5, 34, 1.7, Color(0.6, 0.55, 0.45))
	_w("needler_9", S, "Needler 9", "Tiny darts, absurd cyclic rate.",
		10, 5200, 0, 6, 16.0, true, 1600.0, 1, 6.0, 40, 1.8, Color(0.7, 0.9, 0.95))
	_w("raptor_pdw", S, "Raptor PDW", "Compact defense weapon, crisp bursts.",
		14, 8000, 0, 11, 10.0, true, 1650.0, 1, 3.5, 35, 1.5, Color(0.5, 0.8, 0.6))
	_w("twin_stingers", S, "Twin Stingers", "Akimbo SMGs that empty in seconds.",
		17, 10500, 0, 7, 18.0, true, 1500.0, 1, 7.5, 50, 2.2, Color(0.95, 0.6, 0.2))
	_w("cyclone_smg", S, "Cyclone", "Premium PDW with recoil dampers.",
		21, 14000, 5, 12, 12.0, true, 1700.0, 1, 3.0, 38, 1.4, Color(0.55, 0.7, 0.95))
	_w("whisper_smg", S, "Whisper", "Integrally silenced. They never hear it.",
		26, 18000, 15, 14, 10.0, true, 1750.0, 1, 2.0, 30, 1.5, Color(0.35, 0.4, 0.45))

	# ----------------------------------------------------------- shotguns (8)
	_w("shotgun", SG, "Riot Shotgun", "Devastating up close. 6 pellets per shell.",
		4, 2600, 0, 9, 1.4, false, 1200.0, 6, 14.0, 6, 2.2, Color(0.9, 0.45, 0.2))
	_w("sawn_off", SG, "Sawn-Off", "Two barrels, no manners.",
		5, 2000, 0, 11, 1.8, false, 1100.0, 5, 20.0, 2, 1.8, Color(0.65, 0.4, 0.3))
	_w("pump_master", SG, "Pump Master 12", "Classic pump action, tight pattern.",
		8, 4500, 0, 10, 1.3, false, 1250.0, 7, 11.0, 7, 2.4, Color(0.8, 0.55, 0.3))
	_w("auto_scatter", SG, "Auto Scatter", "Semi-auto shells as fast as you can aim.",
		12, 7500, 0, 8, 2.6, true, 1200.0, 5, 15.0, 9, 2.6, Color(0.85, 0.5, 0.45))
	_w("drum_blaster", SG, "Drum Blaster", "Drum-fed crowd control.",
		16, 10500, 0, 9, 2.0, true, 1200.0, 6, 16.0, 12, 3.0, Color(0.7, 0.45, 0.55))
	_w("dragon_maw", SG, "Dragon Maw", "Breathes a cone of burning shrapnel.",
		20, 14500, 5, 11, 1.6, false, 1150.0, 8, 18.0, 6, 2.5, Color(1.0, 0.45, 0.15))
	_w("siege_breacher", SG, "Siege Breacher", "Door? What door?",
		25, 19000, 15, 14, 1.2, false, 1300.0, 8, 12.0, 5, 2.6, Color(0.55, 0.6, 0.7))
	_w("royal_decree", SG, "Royal Decree", "Ten pellets of pure aristocracy.",
		30, 24000, 30, 12, 1.5, false, 1300.0, 10, 15.0, 6, 2.4, Color(0.9, 0.8, 0.4))

	# ------------------------------------------------------------- rifles (8)
	_w("rifle", R, "AR-77 Rifle", "Balanced automatic rifle for mid range.",
		6, 5200, 0, 14, 7.0, true, 1900.0, 1, 2.5, 25, 1.8, Color(0.4, 0.85, 0.45))
	_w("carbine_kt", R, "KT Carbine", "Short-barrel carbine, quick handling.",
		8, 4000, 0, 12, 8.0, true, 1800.0, 1, 3.0, 28, 1.6, Color(0.5, 0.75, 0.5))
	_w("bullpup_fox", R, "Bullpup Fox", "Compact bullpup with clean optics.",
		11, 6800, 0, 15, 7.5, true, 1950.0, 1, 2.2, 30, 1.8, Color(0.45, 0.7, 0.65))
	_w("br3_burst", R, "BR-3 Burst", "Heavy battle rounds, manageable pace.",
		15, 9500, 0, 17, 6.0, true, 2000.0, 1, 2.0, 24, 1.9, Color(0.6, 0.65, 0.4))
	_w("dmr_falcon", R, "DMR Falcon", "Designated marksman rifle. Tap fire.",
		19, 13000, 0, 26, 3.2, false, 2400.0, 1, 0.8, 15, 2.0, Color(0.55, 0.6, 0.8))
	_w("storm_ar", R, "Storm AR", "High-cycle assault platform.",
		23, 17000, 5, 16, 9.0, true, 2000.0, 1, 2.6, 32, 1.8, Color(0.4, 0.6, 0.9))
	_w("anvil_battle", R, "Anvil Battle Rifle", "Hits like its namesake.",
		28, 22000, 15, 22, 6.5, true, 2100.0, 1, 2.4, 26, 2.0, Color(0.5, 0.5, 0.55))
	_w("spectre_ar", R, "Spectre AR", "Tournament-grade rifle of champions.",
		34, 28000, 30, 18, 10.0, true, 2200.0, 1, 1.8, 34, 1.7, Color(0.75, 0.85, 1.0))

	# ------------------------------------------------------------ snipers (8)
	_w("hunting_carbine", SN, "Hunting Carbine", "Entry scoped rifle for patient hands.",
		7, 3800, 0, 45, 1.2, false, 2800.0, 1, 0.3, 5, 2.2, Color(0.6, 0.5, 0.35))
	_w("sniper", SN, "Longshot DSR", "One bullet, one story. Slow but lethal.",
		9, 9000, 0, 70, 0.8, false, 3200.0, 1, 0.0, 4, 2.6, Color(0.5, 0.7, 1.0))
	_w("recon_sr", SN, "Recon SR-1", "Scout rifle balancing pace and punch.",
		12, 8000, 0, 60, 1.0, false, 3000.0, 1, 0.2, 6, 2.4, Color(0.45, 0.65, 0.55))
	_w("piercer_amr", SN, "Piercer AMR", "Anti-materiel rifle. Bring earplugs.",
		17, 12500, 0, 85, 0.7, false, 3400.0, 1, 0.0, 4, 2.8, Color(0.5, 0.55, 0.65))
	_w("ghost_bolt", SN, "Ghost Bolt", "Bolt action favored by phantoms.",
		22, 16500, 5, 95, 0.65, false, 3400.0, 1, 0.0, 5, 2.7, Color(0.8, 0.85, 0.95))
	_w("twin_scope", SN, "Twin Scope DR", "Fast double-tap marksman rifle.",
		27, 21000, 10, 55, 1.6, false, 3000.0, 1, 0.4, 8, 2.3, Color(0.6, 0.75, 0.85))
	_w("avalanche_50", SN, "Avalanche .50", "Stops anything that moves. Once.",
		32, 27000, 25, 120, 0.5, false, 3600.0, 1, 0.0, 3, 3.2, Color(0.85, 0.9, 1.0))
	_w("eclipse_lr", SN, "Eclipse LR", "The last thing they never see.",
		38, 34000, 40, 140, 0.45, false, 3800.0, 1, 0.0, 3, 3.4, Color(0.3, 0.3, 0.5))

	# --------------------------------------------------------------- LMGs (8)
	_w("brute_mg", L, "Brute MG", "Belt-fed suppression on a budget.",
		10, 6000, 0, 10, 9.0, true, 1700.0, 1, 4.5, 60, 3.2, Color(0.55, 0.5, 0.4))
	_w("sawblade_lmg", L, "Sawblade", "Rips cover and nerves apart.",
		14, 9000, 0, 11, 10.0, true, 1700.0, 1, 4.8, 70, 3.4, Color(0.7, 0.6, 0.35))
	_w("bastion_mg", L, "Bastion MG", "Defensive platform with deep belts.",
		18, 12500, 0, 13, 8.5, true, 1750.0, 1, 4.0, 80, 3.6, Color(0.45, 0.55, 0.5))
	_w("hailstorm", L, "Hailstorm", "A storm front made of lead.",
		22, 16000, 0, 9, 14.0, true, 1650.0, 1, 6.0, 90, 3.8, Color(0.6, 0.7, 0.8))
	_w("warhog_mg", L, "Warhog", "Heavy slugs, heavier attitude.",
		26, 20000, 5, 15, 9.0, true, 1800.0, 1, 3.6, 75, 3.6, Color(0.65, 0.45, 0.4))
	_w("cerberus_mg", L, "Cerberus", "Three barrels sharing one appetite.",
		30, 25000, 15, 13, 12.0, true, 1800.0, 1, 4.2, 100, 4.0, Color(0.75, 0.35, 0.3))
	_w("titan_feed", L, "Titan Feed", "Endgame support weapon.",
		35, 30000, 25, 17, 10.0, true, 1900.0, 1, 3.2, 90, 3.8, Color(0.5, 0.6, 0.75))
	_w("leviathan_mg", L, "Leviathan", "The wall of bullets has a name.",
		40, 36000, 40, 16, 13.0, true, 1900.0, 1, 3.8, 120, 4.2, Color(0.35, 0.5, 0.6))

	# ---------------------------------------------------------- launchers (7)
	_w("lobber_gl", LA, "Lobber GL-1", "Grenade launcher with forgiving arcs.",
		13, 8500, 0, 40, 1.3, false, 1000.0, 1, 1.5, 4, 2.6, Color(0.5, 0.6, 0.35),
		{"explosive": true, "blast_radius": 90.0})
	_w("rpg_fist", LA, "RPG Fist", "Single rocket. Singular results.",
		17, 12000, 0, 70, 0.8, false, 1100.0, 1, 0.8, 1, 2.4, Color(0.7, 0.55, 0.3),
		{"explosive": true, "blast_radius": 120.0})
	_w("thumper_x2", LA, "Thumper X2", "Rapid grenade volley platform.",
		21, 16000, 5, 45, 1.6, false, 1050.0, 1, 2.0, 6, 3.0, Color(0.6, 0.5, 0.45),
		{"explosive": true, "blast_radius": 100.0})
	_w("pocket_mortar", LA, "Pocket Mortar", "Indirect misery, direct delivery.",
		25, 20000, 10, 85, 0.6, false, 950.0, 1, 1.0, 2, 3.2, Color(0.45, 0.5, 0.4),
		{"explosive": true, "blast_radius": 150.0})
	_w("hydra_pod", LA, "Hydra Pod", "Swarm of micro rockets.",
		29, 25000, 20, 30, 3.0, true, 1200.0, 1, 4.0, 8, 3.0, Color(0.75, 0.5, 0.6),
		{"explosive": true, "blast_radius": 80.0})
	_w("inferno_rpg", LA, "Inferno RPG", "Leaves craters and reputations.",
		33, 30000, 30, 95, 0.7, false, 1150.0, 1, 0.6, 2, 3.0, Color(1.0, 0.4, 0.1),
		{"explosive": true, "blast_radius": 140.0})
	_w("doomsday_lr", LA, "Doomsday Launcher", "The treaty-violation special.",
		39, 38000, 50, 120, 0.5, false, 1100.0, 1, 0.5, 1, 3.4, Color(0.9, 0.2, 0.2),
		{"explosive": true, "blast_radius": 170.0})

	# ------------------------------------------------------------ exotics (7)
	_w("plasma_carbine", EX, "Plasma Carbine", "Superheated bolts that sizzle past.",
		15, 6000, 30, 20, 7.0, true, 1100.0, 1, 2.0, 30, 1.9, Color(0.2, 0.95, 0.9))
	_w("tesla_arc", EX, "Tesla Arc", "A handheld thunderstorm.",
		20, 8000, 45, 6, 20.0, true, 1500.0, 1, 8.0, 60, 2.4, Color(0.55, 0.75, 1.0))
	_w("railgun_xc", EX, "XC Railgun", "Magnetically accelerated finality.",
		25, 10000, 60, 110, 0.6, false, 4500.0, 1, 0.0, 3, 2.8, Color(0.7, 0.95, 1.0))
	_w("void_reaper", EX, "Void Reaper", "Shreds reality in a wide cone.",
		30, 12000, 80, 13, 1.2, false, 1300.0, 12, 20.0, 5, 2.8, Color(0.6, 0.3, 0.9))
	_w("solar_lance", EX, "Solar Lance", "Spears of focused sunlight.",
		34, 15000, 100, 36, 3.4, false, 3000.0, 1, 0.2, 12, 2.2, Color(1.0, 0.85, 0.3))
	_w("singularity_cannon", EX, "Singularity Cannon", "Fires a very small, very angry star.",
		38, 18000, 125, 100, 0.45, false, 900.0, 1, 0.0, 1, 3.6, Color(0.4, 0.2, 0.7),
		{"explosive": true, "blast_radius": 200.0})
	_w("omega_decimator", EX, "Omega Decimator", "The final word in arena warfare.",
		45, 25000, 160, 24, 11.0, true, 2300.0, 1, 1.5, 80, 3.0, Color(0.95, 0.3, 0.55))

	# ---------------------------------------------------------- grenades ---
	ITEMS["frag_grenade"] = {
		"name": "Frag Grenade",
		"category": Category.GRENADE,
		"description": "Classic fragmentation grenade.",
		"price_silver": 800,
		"price_trinkets": 0,
		"unlock_level": 3,
		"damage": 55,
		"radius": 120.0,
		"fuse": 1.4,
		"throw_speed": 900.0,
		"carry_count": 2,
		"color": Color(0.45, 0.55, 0.35),
	}
	ITEMS["impact_grenade"] = {
		"name": "Impact Grenade",
		"category": Category.GRENADE,
		"description": "Short fuse, smaller blast. Pops almost on contact.",
		"price_silver": 2400,
		"price_trinkets": 0,
		"unlock_level": 8,
		"damage": 45,
		"radius": 95.0,
		"fuse": 0.5,
		"throw_speed": 1000.0,
		"carry_count": 3,
		"color": Color(0.8, 0.5, 0.3),
	}
	ITEMS["heavy_grenade"] = {
		"name": "Heavy Grenade",
		"category": Category.GRENADE,
		"description": "Demolition charge with a huge radius.",
		"price_silver": 6000,
		"price_trinkets": 10,
		"unlock_level": 16,
		"damage": 80,
		"radius": 170.0,
		"fuse": 1.8,
		"throw_speed": 800.0,
		"carry_count": 1,
		"color": Color(0.6, 0.3, 0.3),
	}

	# ------------------------------------------------------------- perks ---
	ITEMS["light_armor"] = {
		"name": "Light Vest",
		"category": Category.PERK,
		"description": "+25 max HP.",
		"price_silver": 2000,
		"price_trinkets": 0,
		"unlock_level": 3,
		"max_hp_bonus": 25,
		"speed_mult": 1.0,
		"color": Color(0.6, 0.6, 0.65),
	}
	ITEMS["heavy_armor"] = {
		"name": "Heavy Plate",
		"category": Category.PERK,
		"description": "+60 max HP, but 10% slower.",
		"price_silver": 6500,
		"price_trinkets": 10,
		"unlock_level": 7,
		"max_hp_bonus": 60,
		"speed_mult": 0.9,
		"color": Color(0.35, 0.4, 0.5),
	}
	ITEMS["sprint_boots"] = {
		"name": "Sprint Boots",
		"category": Category.PERK,
		"description": "+15% movement speed.",
		"price_silver": 3000,
		"price_trinkets": 0,
		"unlock_level": 5,
		"max_hp_bonus": 0,
		"speed_mult": 1.15,
		"color": Color(0.9, 0.3, 0.6),
	}
	ITEMS["ninja_gear"] = {
		"name": "Ninja Gear",
		"category": Category.PERK,
		"description": "+10 max HP and +10% movement speed.",
		"price_silver": 9000,
		"price_trinkets": 15,
		"unlock_level": 12,
		"max_hp_bonus": 10,
		"speed_mult": 1.1,
		"color": Color(0.3, 0.3, 0.35),
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


## Weapons of a given WeaponType. Pass -1 for all weapons.
func get_weapons_by_type(weapon_type: int) -> Array[String]:
	var result: Array[String] = []
	for id: String in ITEMS:
		if ITEMS[id]["category"] != Category.WEAPON:
			continue
		if weapon_type == -1 or int(ITEMS[id]["weapon_type"]) == weapon_type:
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


func weapon_type_name(weapon_type: int) -> String:
	return str(WEAPON_TYPE_NAMES.get(weapon_type, "Weapons"))
