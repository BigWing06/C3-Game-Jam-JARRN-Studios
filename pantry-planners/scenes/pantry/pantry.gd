extends Sprite2D

# This varible controls if the food pantry is active meaning
# it is receiving and handing out food
@export var active: bool = false 
# Signal that is emmited when the active state changes
signal active_changed()
signal food_changed()

var food: int #TODO Change this a list with different food types

func _ready():
	set_active(active)
	set_food("", 10)

# Used to set state of the active variable. Handles resetting, 
# starting, and stopping the effect_timer
func set_active(new_state: bool):
	active = new_state
	active_changed.emit()
	if (active):
		$effect_timer.start()
	else:
		$effect_timer.stop()

func set_food(type: String, amount: int):
	food = amount
	food_changed.emit()

# This function adds one food of a specific type to the pantry
func add_food(type: String):
	set_food(type, get_food_amount(type) + 1)
	
# This function is called by houses in radius when
# they want to take food from the pantry
func take_food(type: String) -> void:
	food -= 1
	food_changed.emit()

# This function is called by the effect timer and calls the check_food_need()
# function in all houses that are in it's effect_radius
func effect_houses() -> void:
	while (food > 0):
		var greatest_need: int = 0
		var neediest_house = null
		print("Looping list")
		for area in $effect_radius.get_overlapping_areas():
			var house = area.get_parent()
			if house.is_in_group("house"):
				var house_need = house.get_need("null")
				print(str(greatest_need) + "    " + str(house.get_need("null")))
				if greatest_need < house_need: #TODO replace null with food type as string
					greatest_need = house_need
					neediest_house = house
		print(greatest_need)
		if greatest_need == 0:
			break
		neediest_house.give_food("null") #TODO replace null with food type as string
		take_food("null")

# This function is called to get the amount of a specific food type
func get_food_amount(type: String) -> int:
	return food

func _on_food_changed() -> void:
	$food_amount_label.text = str(get_food_amount("null"))
