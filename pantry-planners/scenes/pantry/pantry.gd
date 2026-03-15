extends Node2D

const PLACEMENT_MODES := ["hovering", "placed"]

@export var spoliage_thereshhold: int = 5
@export var spoliage_timer: int = 5

const FOOD_TYPES = [
	"bread",
	"veg",
	"meat"
]

const FOOD_PRESETS: Array = [
	["bread", "veg", "meat"],
	["bread"],
	["veg"],
	["meat"],
]

var requested_foods: Array = FOOD_PRESETS[0].duplicate()
var _preset_index:   int   = 0

func cycle_requested_foods() -> void:
	_preset_index  = (_preset_index + 1) % FOOD_PRESETS.size()
	requested_foods = FOOD_PRESETS[_preset_index].duplicate()

@export var start_active: bool = false 
@export var start_placement_mode: String = "hovering"
@export var max_supply: int = 20
@export var max_health: int = 20
# Signal that is emmited when the active state changes

# This varible controls if the food pantry is active meaning
# it is receiving and handing out food
var active: bool
var placement_mode: String

signal active_changed
signal food_changed

# food_type -> amount currently stocked. Houses pull from this via take_food().
var food_amounts: Dictionary = {}
var food_calls: Dictionary = {}

@export var max_range: int = 5

# Updated by find_reachable() Vector2i : Node
var reachable_tiles: Dictionary = {}
var reachable_houses: Dictionary = {}

func _ready():
	$Control/food_amount_label.hide()
	set_active(start_active)
	set_placement_mode(start_placement_mode)
	for food_type in ["bread", "veg", "meat"]:
		set_food(food_type, 5)

func set_active(new_state: bool) -> void:
	active = new_state
	active_changed.emit()
	if active:
		$spoilage_timer.wait_time = spoliage_timer
		$spoilage_timer.start()

func check_food(type) -> bool:
	if type in food_amounts.keys():
		var called_amount = 0
		if type in food_calls.keys():
			called_amount = food_calls[type]
		print(food_amounts[type])
		print(called_amount)
		if food_amounts[type] - called_amount > 0:
			if type in food_calls.keys():
				food_calls[type] += 1
			else:
				food_calls[type] = 0
			return true
	return false
	

func set_food(type: String, amount: int):
	food_amounts[type] = amount
	food_amounts[type] = min(amount, max_supply)
	food_changed.emit()
	
# This function is called by houses in radius when
# they want to take food from the pantry
func add_food(type: String, amount) -> void:
	set_food(type, get_food_amount(type) + amount)
	var spoilage_ui = preload("res://scenes/TextDisplay/TextDisplayy.tscn").instantiate()
	add_child(spoilage_ui)
	spoilage_ui.setup("Recieved Food +"+str(amount), Color("#0000FF"), Vector2(30, -40))

func take_food(type: String) -> void:
	set_food(type, get_food_amount(type) - 1)
	if (type in food_calls.keys()):
		food_calls[type] -= 1
		if food_calls[type] < 0:
			food_calls[type] = 0
	food_changed.emit()

# Dijkstra reachability search. Fills reachable_tiles with every tile within
# max_range travel cost, mapping Vector2i -> the Node placed there (or null).
# Occupied tiles block passage unless they carry a "travel_cost" custom-data
# value on the TileSet (e.g. roads = 0, forests = 2). Occupied tiles that are
# valid destinations (e.g. houses) are recorded but not expanded through.
func find_reachable(tilemap: TileMapLayer, self_pos: Vector2i) -> void:
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

		# Don't expand neighbors of occupied tiles, but do not return before registering them
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
	reachable_houses = {}
	for position_key in reachable_tiles.keys():
		if position_key in grid_data.keys():
			if grid_data[position_key]["type"].begins_with("house"):
				reachable_houses[position_key] = reachable_tiles[position_key]

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
			
		
func get_spoilage():
	var total = 0
	for type in FOOD_TYPES:
		if spoliage_thereshhold < get_food_amount(type):
			return true
	return false

func _on_food_changed() -> void:
	if not active:
		return
	var text := ""
	for food_type in ["bread", "veg", "meat"]:
		text += "%s:%d " % [food_type[0].to_upper(), get_food_amount(food_type)]
	$Control/food_amount_label.text = text.strip_edges()
	if get_spoilage():
		if $spoilage_timer.is_stopped():
			$spoilage_timer.start()
	else:
		print("spoilage set to false")
		$spoilage_timer.stop()


func _on_spoilage_timer_timeout() -> void:
	for type in FOOD_TYPES:
		if spoliage_thereshhold < get_food_amount(type):
			set_food(type, get_food_amount(type) - 1)
			var spoilage_ui = preload("res://scenes/TextDisplay/TextDisplayy.tscn").instantiate()
			add_child(spoilage_ui)
			spoilage_ui.setup("Spoliage -1", Color("#FF0000"), Vector2(30, -40))
