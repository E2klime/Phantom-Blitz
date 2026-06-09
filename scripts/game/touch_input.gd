class_name TouchInput
## Bridge between the on-screen touch controls (HUD) and the player
## controller. The HUD writes here; the locally controlled player reads it.

static var active: bool = false
static var move_axis: float = 0.0
static var move_axis_y: float = 0.0
static var aim_vector: Vector2 = Vector2.RIGHT
static var jump_pressed: bool = false
static var shoot_held: bool = false
static var grenade_pressed: bool = false
static var dash_pressed: bool = false


static func reset() -> void:
	active = false
	move_axis = 0.0
	move_axis_y = 0.0
	aim_vector = Vector2.RIGHT
	jump_pressed = false
	shoot_held = false
	grenade_pressed = false
	dash_pressed = false
