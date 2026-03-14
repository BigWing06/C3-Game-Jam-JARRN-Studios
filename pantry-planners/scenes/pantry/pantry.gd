extends Node2D

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

@export var max_range: int = 5

# Updated by find_reachable() Vector2i : Node
var reachable_tiles: Dictionary = {}

func _ready():
	
	set_active(start_active)
	set_placement_mode(start_placement_mode)
	set_food("Bread", 10)

# Used to set state of the active variable. Handles resetting, 
# starting, and stopping the effect_timer
func set_active(new_state: bool):
	active = new_state
	active_changed.emit()
	if (active) and placement_mode != "hovering":
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

# Dijkstra reachability search. Fills reachable_tiles with every tile within
# max_range travel cost, mapping Vector2i -> the Node placed there (or null).
# Occupied tiles block passage unless they carry a "travel_cost" custom-data
# value on the TileSet (e.g. roads = 0, forests = 2). Occupied tiles that are
# valid destinations (e.g. houses) are recorded but not expanded through.
func find_reachable(tilemap: TileMapLayer, self_pos: Vector2i) -> void:
	if tilemap.is_tile_blocked(self_pos):
		return
	reachable_tiles.clear()

	var grid_data: Dictionary = tilemap.get_grid_data()
	# dist[pos] = minimum travel cost to reach pos
	var dist: Dictionary = { self_pos: 0 }
	# Simple sorted-on-insert min-priority queue: entries are [cost, Vector2i]
	var queue: Array = [[0, self_pos]]

	while queue.size() > 0:
		var entry: Array  = queue.pop_front()
		var current_cost: int     = entry[0]
		var current_pos:  Vector2i = entry[1]

		# Skip stale queue entries
		if current_cost > dist.get(current_pos, INF):
			continue

		# Record tile and any Node living on it
		var node_here: Node = null
		if grid_data.has(current_pos):
			var scene = grid_data[current_pos].get("scene")

			if is_instance_valid(scene):
				node_here = scene
		reachable_tiles[current_pos] = node_here

		# Don't expand through occupied tiles — they are destinations, not corridors
		if current_pos != self_pos and grid_data.has(current_pos):
			continue

		for neighbor: Vector2i in tilemap.get_surrounding_cells(current_pos):

			var step_cost: int = _get_tile_travel_cost(tilemap, neighbor)
			var new_cost:  int = current_cost + step_cost

			if new_cost <= max_range and new_cost < dist.get(neighbor, INF):
				dist[neighbor] = new_cost
				# Sorted insertion to keep the queue ordered by cost
				var inserted := false
				for i in queue.size():
					if queue[i][0] > new_cost:
						queue.insert(i, [new_cost, neighbor])
						inserted = true
						break
				if not inserted:
					queue.append([new_cost, neighbor])


# Returns the travel cost of stepping onto `pos` by reading the custom
# data layer named "travel_cost". Currently not used yet but might be in the future.
func _get_tile_travel_cost(tilemap: TileMapLayer, pos: Vector2i) -> int:
	if tilemap.tile_set == null:
		return 1
	for i in tilemap.tile_set.get_custom_data_layers_count():
		if tilemap.tile_set.get_custom_data_layer_name(i) == "travel_cost":
			var tile_data := tilemap.get_cell_tile_data(pos)
			if tile_data:
				return int(tile_data.get_custom_data_by_layer_id(i))
			break
	return 1

func get_reachable_houses(tilemap: TileMapLayer, pos: Vector2i):
	find_reachable(tilemap, pos)
	var reachable_houses = []
	for position_key in reachable_tiles.keys():
		if reachable_tiles[pos]["type"] == "house":
			reachable_houses.append(position_key)
	return reachable_houses

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
		"placed":
			set_active(true)
			remove_from_group("hovering")

func _on_food_changed() -> void:
	$food_amount_label.text = str(get_food_amount("Bread"))
