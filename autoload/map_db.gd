extends Node
## MapDB autoload — registry of every playable map. All map scenes live in
## res://maps/. A map scene is script-less geometry that follows the node
## contract expected by arena.gd:
##   * "World"        — StaticBody2D geometry.
##   * "SpawnPoints"  — Marker2D children named Blue*/Red*.
##   * "KillZone"     — optional Area2D; bodies entering it die instantly.
## Add a new map by dropping a scene in res://maps/ and registering it here.

const DEFAULT_MAP := "foundry"

const MAPS: Dictionary = {
	"foundry": {
		"name": "Foundry",
		"scene": "res://maps/foundry.tscn",
		"description": "The classic enclosed arena. Balanced walkways and a center block.",
	},
	"skyline": {
		"name": "Skyline",
		"scene": "res://maps/skyline.tscn",
		"description": "Rooftop towers above a deadly drop. Watch your step.",
	},
	"bunker": {
		"name": "Bunker",
		"scene": "res://maps/bunker.tscn",
		"description": "Tight two-story corridors. Shotgun country.",
	},
	"canyon": {
		"name": "Canyon",
		"scene": "res://maps/canyon.tscn",
		"description": "Wide open cliffs over a central chasm. Sniper heaven.",
	},
	"crossfire": {
		"name": "Crossfire",
		"scene": "res://maps/crossfire.tscn",
		"description": "Symmetric arena around a contested central tower.",
	},
}


func has_map(id: String) -> bool:
	return MAPS.has(id)


func get_map(id: String) -> Dictionary:
	return MAPS.get(id, MAPS[DEFAULT_MAP])


func ids() -> Array[String]:
	var result: Array[String] = []
	for id: String in MAPS:
		result.append(id)
	return result
