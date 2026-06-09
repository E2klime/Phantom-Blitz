extends Area2D
## Mini-medkit dropped where a player dies. Pickup is server-authoritative:
## only the server's copy applies the heal and then tells every peer to
## remove their local copy (see arena.gd). The amount restored scales with
## the picker's Intelligence: 52 HP at INT 1 up to 72 HP at INT 11.

const LIFETIME := 20.0

var kit_id: int = 0
var _claimed: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(LIFETIME).timeout.connect(_expire)


func _expire() -> void:
	if is_inside_tree() and not _claimed:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _claimed or not Net.is_server():
		return
	if not (body is CharacterBody2D and body.has_method("heal")):
		return
	if body.dead or body.hp >= body.max_hp:
		return
	_claimed = true
	body.heal(Stats.medkit_heal(body.combat_stats))
	var arena: Node = get_tree().get_first_node_in_group("arena")
	if arena and arena.has_method("remove_medkit"):
		arena.remove_medkit(kit_id)
	else:
		queue_free()
