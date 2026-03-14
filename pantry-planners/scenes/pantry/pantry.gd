extends Sprite2D

const PLACEMENT_MODES = ["hovering", "placed"]

@export var start_active: bool = false 
@export var start_placement_mode: String = "hovering"
# Signal that is emmited when the active state changes

# This varible controls if the food pantry is active meaning
# it is receiving and handing out food
var active: bool
var placement_mode: String

signal active_changed()
signal food_changed()

var food_amounts: Dictionary = {}

func _ready():
	set_active(start_active)
	set_placement_mode(start_placement_mode)
	set_food("Bread", 10)

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
	food_amounts[type] = amount
	food_changed.emit()

# This function adds one food of a specific type to the pantry
func add_food(type: String):
	set_food(type, get_food_amount(type) + 1)
	
# This function is called by houses in radius when
# they want to take food from the pantry
func take_food(type: String) -> void:
	set_food(type, get_food_amount(type) - 1)
	food_changed.emit()

# This function is called by the effect timer and calls the check_food_need()
# function in all houses that are in it's effect_radius
func effect_houses() -> void:
	for type in food_amounts.keys():
		while (food_amounts[type] > 0):
			var greatest_need: int = 0
			var neediest_house = null
			for area in $effect_radius.get_overlapping_areas():
				var house = area.get_parent()
				if house.is_in_group("house"):
					var house_need = house.get_need(type)
					if greatest_need < house_need: #TODO replace null with food type as string
						greatest_need = house_need
						neediest_house = house
			if greatest_need == 0:
				break
			neediest_house.give_food(type) #TODO replace null with food type as string
			take_food(type)

# This function is called to get the amount of a specific food type
func get_food_amount(type: String) -> int:
	if type in food_amounts.keys():
		return food_amounts[type]
	else:
		push_warning("Type " + type + " is not in food_amounts dict returning 0. This might cause unexpected behavior")
		return 0

func set_placement_mode(mode: String) -> void:
	if (mode not in PLACEMENT_MODES):
		push_warning("Invalid Placement Mode Passed Got ->" + mode)
		return
	placement_mode = mode
	match mode:
		"hovering":
			set_active(false)
			add_to_group("hovering")
			$effect_radius.connect("area_entered", _on_house_entered)
			for area in $effect_radius.get_overlapping_areas():
				_on_house_entered(area)
		"placed":
			set_active(true)
			remove_from_group("hovering")
			$effect_radius.connect("area_exited", _on_house_exited)
			for area in $effect_radius.get_overlapping_areas():
				_on_house_exited(area)

func _on_food_changed() -> void:
	$food_amount_label.text = str(get_food_amount("Bread"))
	
func _on_house_entered(area: Area2D) -> void:
	var house = area.get_parent()
	if house.is_in_group("house"):
		house.set_highlight("hovering")

func _on_house_exited(area: Area2D) -> void:
	var house = area.get_parent()
	if house.is_in_group("house"):
		house.set_highlight("none")
