extends Sprite2D

const HIGHLIGHT_MODES = ["hovering", "none"]

signal food_needed_changed

var food_needed: Dictionary = {}

# This function is called by the food pantries on all houses
# in its radius to see if they need to take food
func get_need(type: String):
	if type in food_needed.keys():
		return food_needed[type]
	return 0

# This function is called by the food pantries when they
# give food to the houses
func give_food(type: String):
	if type not in food_needed.keys():
		push_error("Food type " + type + " not in house food needed dictionary aborting function")
		return
	food_needed[type] -= 1
	food_needed_changed.emit()
	
# This function is called to set the specific need of
# a food type
func set_food_need(type: String, amount: int):
	food_needed[type] = amount

# This function is called by the food_timeout timer
# when the amount of food needs to be increased on the house
func add_food():
	set_food_need("Bread", get_need("Bread") + 1)
	food_needed_changed.emit()
	
func set_highlight(mode: String):
	if (mode not in HIGHLIGHT_MODES):
		push_warning("Invalid Highlight Mode Passed Got ->" + mode)
		return
	match mode:
		"hovering":
			modulate = Color(2, 2, 2, 1)
		"placed":
			modulate = Color(1, 1, 1, 1)

func _on_food_needed_changed() -> void:
	$food_amount_label.text = str(get_need("Bread"))
