extends Sprite2D

# This varible controls if the food pantry is active meaning
# it is receiving and handing out food
@export var active: bool = false 
# Signal that is emmited when the active state changes
signal active_changed()

func _ready():
	set_active(active)

# Used to set state of the active variable. Handles resetting, 
# starting, and stopping the effect_timer
func set_active(new_state: bool):
	active = new_state
	active_changed.emit()
	if (active):
		$effect_timer.start()
	else:
		$effect_timer.stop()

# This function is called by the effect timer and calls the check_food_need()
# function in all houses that are in it's effect_radius
func effect_houses() -> void:
	for area in $effect_radius.get_overlapping_areas():
		var house = area.get_parent()
		if (house.is_in_group("house")):
			house.check_food_need()
