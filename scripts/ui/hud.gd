extends CanvasLayer
## In-game HUD: progression header, team scores + ping, weapon / health
## panel, quick chat (keys 1-7), kill feed, pause menu and touch controls.
## Layout inspired by classic web shooters (TDP4-style).

const QUICK_CHAT: Array[String] = [
	"Go! Go! Go!",
	"Stick together team!",
	"Cover me!",
	"Guard the base!",
	"Team, fall back!",
	"Affirmative...",
	"Negative...",
]
const TEAM_NAMES: Array[String] = ["BLUE", "RED"]
const MAX_CHAT_LINES := 6
const MAX_FEED_LINES := 4

var local_player: Node = null
var _chat_lines: Array[String] = []
var _feed_lines: Array[String] = []

@onready var exp_label: Label = %ExpLabel
@onready var exp_bar: ProgressBar = %ExpBar
@onready var level_label: Label = %LevelLabel
@onready var silver_label: Label = %SilverLabel
@onready var trinkets_label: Label = %TrinketsLabel
@onready var blue_score: Label = %BlueScore
@onready var red_score: Label = %RedScore
@onready var ffa_score: Label = %FFAScore
@onready var reward_label: Label = %RewardLabel
@onready var ping_label: Label = %PingLabel
@onready var weapon_label: Label = %WeaponLabel
@onready var ammo_label: Label = %AmmoLabel
@onready var hp_bar: ProgressBar = %HpBar
@onready var hp_label: Label = %HpLabel
@onready var grenade_label: Label = %GrenadeLabel
@onready var chat_log: Label = %ChatLog
@onready var kill_feed_label: Label = %KillFeedLabel
@onready var quick_chat_list: Label = %QuickChatList
@onready var banner: Label = %Banner
@onready var pause_menu: Control = %PauseMenu
@onready var touch_controls: Control = %TouchControls
@onready var move_stick: VirtualJoystick = %MoveStick
@onready var aim_stick: VirtualJoystick = %AimStick
@onready var jump_button: Button = %JumpButton
@onready var grenade_button: Button = %GrenadeButton
@onready var dash_button: Button = %DashButton

var _reward_token: int = 0


func _ready() -> void:
	Game.score_changed.connect(_update_scores)
	Game.kill_feed.connect(_on_kill_feed)
	Game.match_ended.connect(_on_match_ended)
	Game.reward_earned.connect(_on_reward_earned)
	Net.chat_received.connect(_on_chat)
	Net.ping_updated.connect(_on_ping)
	Net.player_list_changed.connect(_update_scores)
	Profile.profile_changed.connect(_update_profile_info)

	var lines: Array[String] = []
	for i in QUICK_CHAT.size():
		lines.append("%d.  %s" % [i + 1, QUICK_CHAT[i]])
	quick_chat_list.text = "\n".join(lines)

	banner.hide()
	pause_menu.hide()
	chat_log.text = ""
	kill_feed_label.text = ""

	var touch := Profile.wants_touch_controls()
	touch_controls.visible = touch
	TouchInput.reset()
	TouchInput.active = touch
	grenade_button.pressed.connect(func() -> void: TouchInput.grenade_pressed = true)
	dash_button.pressed.connect(func() -> void: TouchInput.dash_pressed = true)

	var team_mode := Game.is_team_mode()
	%BlueRow.visible = team_mode
	%RedRow.visible = team_mode
	ffa_score.visible = not team_mode

	_update_scores()
	_update_profile_info()
	_on_ping(0)


func _exit_tree() -> void:
	TouchInput.reset()


func _process(_delta: float) -> void:
	_ensure_local_player()
	if touch_controls.visible:
		TouchInput.move_axis = move_stick.output.x
		TouchInput.move_axis_y = move_stick.output.y
		if aim_stick.output.length() > 0.25:
			TouchInput.aim_vector = aim_stick.output
		TouchInput.shoot_held = aim_stick.output.length() > 0.6
		TouchInput.jump_pressed = jump_button.button_pressed
	_update_player_stats()


func _ensure_local_player() -> void:
	if is_instance_valid(local_player):
		return
	for player in get_tree().get_nodes_in_group("players"):
		if player.is_multiplayer_authority():
			local_player = player
			return


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		pause_menu.visible = not pause_menu.visible
		return
	for i in QUICK_CHAT.size():
		if event.is_action_pressed("chat_%d" % (i + 1)):
			Net.send_chat(QUICK_CHAT[i])
			return


# ----------------------------------------------------------------- updates

func _update_profile_info() -> void:
	level_label.text = str(Profile.level)
	exp_bar.max_value = Profile.xp_needed(Profile.level)
	exp_bar.value = Profile.xp
	exp_label.text = "EXP  %d / %d" % [Profile.xp, Profile.xp_needed(Profile.level)]
	silver_label.text = str(Profile.silver)
	trinkets_label.text = str(Profile.trinkets)


func _update_scores() -> void:
	if Game.is_team_mode():
		blue_score.text = str(Game.team_scores[0])
		red_score.text = str(Game.team_scores[1])
		return
	var own_kills := 0
	var best_kills := 0
	var best_name := "—"
	for id: int in Net.players:
		var kills := int(Net.players[id]["kills"])
		if id == Net.local_id():
			own_kills = kills
		if kills > best_kills:
			best_kills = kills
			best_name = str(Net.players[id]["name"])
	ffa_score.text = "You: %d   Leader: %s (%d)" % [own_kills, best_name, best_kills]


func _on_ping(ms: int) -> void:
	ping_label.text = "ping:  %d" % ms


func _update_player_stats() -> void:
	if not is_instance_valid(local_player):
		return
	var weapon: Dictionary = ItemDB.get_item(local_player.weapon_id)
	weapon_label.text = str(weapon.get("name", "—"))
	if local_player.reloading:
		ammo_label.text = "RELOADING"
	else:
		ammo_label.text = "%d / %d" % [local_player.ammo_in_clip, int(weapon.get("clip_size", 0))]
	hp_bar.max_value = local_player.max_hp
	hp_bar.value = local_player.hp
	hp_label.text = "%d / %d" % [local_player.hp, local_player.max_hp]
	grenade_label.text = str(local_player.grenades_left)


# ------------------------------------------------------------- chat & feed

func _on_chat(sender_name: String, team: int, text: String) -> void:
	_chat_lines.append("[%s] %s: %s" % [TEAM_NAMES[team], sender_name, text])
	while _chat_lines.size() > MAX_CHAT_LINES:
		_chat_lines.pop_front()
	chat_log.text = "\n".join(_chat_lines)


func _on_kill_feed(text: String) -> void:
	_feed_lines.append(text)
	while _feed_lines.size() > MAX_FEED_LINES:
		_feed_lines.pop_front()
	kill_feed_label.text = "\n".join(_feed_lines)


func _on_match_ended(message: String, winning_team: int) -> void:
	banner.text = message
	match winning_team:
		0:
			banner.modulate = Color(0.4, 0.7, 1.0)
		1:
			banner.modulate = Color(1.0, 0.45, 0.45)
		_:
			banner.modulate = Color.WHITE
	banner.show()
	await get_tree().create_timer(5.0).timeout
	if is_instance_valid(banner):
		banner.hide()


func _on_reward_earned(silver_amount: int, xp_amount: int, combo: int) -> void:
	var text := "+%d Silver   +%d XP" % [silver_amount, xp_amount]
	if combo > 1:
		text = "COMBO x%d!   %s" % [combo, text]
	reward_label.text = text
	reward_label.show()
	_reward_token += 1
	var token := _reward_token
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(reward_label) and token == _reward_token:
		reward_label.hide()


# ------------------------------------------------------------- pause menu

func _on_resume_pressed() -> void:
	pause_menu.hide()


func _on_leave_pressed() -> void:
	Game.return_to_menu()
