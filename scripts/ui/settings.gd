extends Control
## Settings — audio, display and control options. Stored in the profile.

@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var fullscreen_check: CheckButton = %FullscreenCheck
@onready var touch_option: OptionButton = %TouchOption


func _ready() -> void:
	music_slider.value = float(Profile.settings.get("music_volume", 0.8))
	sfx_slider.value = float(Profile.settings.get("sfx_volume", 1.0))
	fullscreen_check.button_pressed = bool(Profile.settings.get("fullscreen", false))
	if OS.has_feature("web") or OS.has_feature("mobile"):
		fullscreen_check.disabled = true
	touch_option.clear()
	touch_option.add_item("Auto (detect touchscreen)")
	touch_option.add_item("Always on")
	touch_option.add_item("Always off")
	touch_option.selected = ["auto", "on", "off"].find(str(Profile.settings.get("touch_controls", "auto")))


func _on_music_slider_value_changed(value: float) -> void:
	Profile.settings["music_volume"] = value
	Profile.save_profile()


func _on_sfx_slider_value_changed(value: float) -> void:
	Profile.settings["sfx_volume"] = value
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.001, value)))
	Profile.save_profile()


func _on_fullscreen_check_toggled(pressed: bool) -> void:
	Profile.settings["fullscreen"] = pressed
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if pressed else DisplayServer.WINDOW_MODE_WINDOWED)
	Profile.save_profile()


func _on_touch_option_item_selected(index: int) -> void:
	Profile.settings["touch_controls"] = ["auto", "on", "off"][index]
	Profile.save_profile()


func _on_back_pressed() -> void:
	Game.goto_scene("res://scenes/ui/main_menu.tscn")
