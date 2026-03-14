extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var masterVal = db_to_linear(AudioServer.get_bus_volume_db(0))
	$"Button Manager/Master Slider".value = masterVal
	var musicVal = db_to_linear(AudioServer.get_bus_volume_db(1))
	$"Button Manager/Music Slider".value = musicVal
	var sfxVal = db_to_linear(AudioServer.get_bus_volume_db(2))
	$"Button Manager/SFX Slider".value = sfxVal


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# Buttons and Sliders ---------------

func _on_navigate_back_pressed() -> void:
	queue_free()
	

func _on_master_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(0,linear_to_db(value))


func _on_music_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(1,linear_to_db(value))


func _on_sfx_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(2,linear_to_db(value))


func _on_master_mute_toggled(toggled_on: bool) -> void:
	AudioServer.set_bus_mute(0, toggled_on)


func _on_music_mute_toggled(toggled_on: bool) -> void:
	AudioServer.set_bus_mute(1, toggled_on)


func _on_sfx_mute_toggled(toggled_on: bool) -> void:
	AudioServer.set_bus_mute(2, toggled_on)
