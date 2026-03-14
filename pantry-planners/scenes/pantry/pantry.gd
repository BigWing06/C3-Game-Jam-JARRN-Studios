extends StaticBody2D

# This varible controls if the food pantry is active meaning
# it is receiving and handing out food
var active: bool = false 

# Used to set state of the active variable. Handles resetting, 
# starting, and stopping the effect_timer
func set_active(new_state: bool):
	active = new_state
	if (active):
		$effect_timer.start()
	else:
		$effect_timer.stop()

# This function is called by the effect timer and calls the check_food_need()
# function in all houses that are in it's effect_radius
func effect_houses() -> void:
	for house in $effect_radius.get_overlapping_areas():
		house.check_food_need()
