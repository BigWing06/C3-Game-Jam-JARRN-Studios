extends Sprite2D

signal food_needed_changed

var food_needed: int = 0

# This function is called by the food pantries on all houses
# in its radius to see if they need to take food
func get_need(type: String):
	return food_needed

# This function is called by the food pantries when they
# give food to the houses
func give_food(type: String):
	food_needed -= 1
	food_needed_changed.emit()

# This function is called by the food_timeout timer
# when the amount of food needs to be increased on the house
func add_food():
	food_needed += 1
	food_needed_changed.emit()


func _on_food_needed_changed() -> void:
	$food_amount_label.text = str(get_need(""))
