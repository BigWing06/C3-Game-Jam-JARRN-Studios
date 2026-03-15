extends Sprite2D

# Default seconds between food requests for each house type.
# Can be overridden per house in levels.json via the "delay" field.
const DEFAULT_DELAYS := {
	"low_need":  10.0,
	"normal":     5.0,
	"high_need":  2.5,
	"donator":    8.0,
}

const FOOD_TYPES = [
	"bread",
	"veg",
	"meat"
]

const MAX_HEALTH   := 10
const TRAVEL_SPEED := 0.5  # seconds per tile (one way); round trip = 2x

# Emitted when health reaches 0. Connect to the loss screen trigger.
signal died

var house_type:  String        = "inactive"
var needs:       Array[String] = []  # food types this house requests
var donates:     Array[String] = []  # donor only: food types deposited at pantry
var food_stock:  Dictionary    = {}  # food_type -> amount currently on hand
var health:      int           = MAX_HEALTH
var delay:       float         = 5.0

var _tilemap:         TileMapLayer  # set by setup(); used for path queries
var _grid_pos:        Vector2i
var _target_pantry:   Node = null
var _person_en_route: bool = false


# Called by RootGameScene after the house is placed on the grid.
# config mirrors the house entry in levels.json; an empty dict means inactive.
func setup(config: Dictionary, tilemap: TileMapLayer, grid_pos: Vector2i) -> void:
	_tilemap  = tilemap
	_grid_pos = grid_pos

	if not config.has("type"):
		house_type = "inactive"
		modulate   = Color(0.5, 0.5, 0.5)  # grey placeholder; replace with sprite later
		return

	house_type = config["type"]
	needs      = config.get("needs",    FOOD_TYPES.duplicate())
	donates    = config.get("donates",  [])
	delay      = config.get("delay",    DEFAULT_DELAYS.get(house_type, 5.0))

	# starting_food is [bread_amt, veg_amt, meat_amt] — matches FOOD_TYPES 
	var starting: Array = config.get("starting_food", [2, 2, 2])
	for i in FOOD_TYPES.size():
		food_stock[FOOD_TYPES[i]] = starting[i] if i < starting.size() else 2

	update_target_pantry()
	_start_demand_cycle()


# Finds the nearest reachable pantry by BFS path distance.
# Called on setup and whenever the grid layout changes (pantry placed/removed).
func update_target_pantry() -> void:
	if house_type == "inactive" or _tilemap == null:
		return
	var result: Array = _tilemap.get_nearest_pantry(_grid_pos)
	_target_pantry    = result[0] if result.size() > 0 else null


func _start_demand_cycle() -> void:
	# Stagger houses so they don't all fire at the same instant.
	var offset_timer := get_tree().create_timer(randf_range(0.0, delay))
	offset_timer.timeout.connect(func():
		_dispatch_person()  # first request after the random offset
		var recurring := Timer.new()
		recurring.wait_time = delay
		recurring.one_shot  = false
		recurring.timeout.connect(_dispatch_person)
		add_child(recurring)
		recurring.start()
	)


func _dispatch_person() -> void:
	if _person_en_route:
		return

	# Re-query each dispatch in case pantries were added/removed since last check.
	var result: Array = _tilemap.get_nearest_pantry(_grid_pos)
	if result.is_empty():
		_take_damage()  # no pantry reachable; house goes without food
		return

	var pantry:   Node  = result[0]
	var distance: int   = result[1]
	var one_way:  float = distance * TRAVEL_SPEED

	_person_en_route = true
	get_tree().create_timer(one_way).timeout.connect(func():
		_arrive_at_pantry(pantry, one_way)
	)


func _arrive_at_pantry(pantry: Node, return_time: float) -> void:
	var got_food := false

	if house_type == "donator":
		# Donor deposits food; always returns satisfied.
		for food_type in donates:
			pantry.add_food(food_type)
		got_food = true
	else:
		# Take the first available food type that matches this house's needs.
		for food_type in needs:
			if pantry.get_food_amount(food_type) > 0:
				pantry.take_food(food_type)
				food_stock[food_type] = food_stock.get(food_type, 0) + 1
				got_food = true
				break

	get_tree().create_timer(return_time).timeout.connect(func():
		_person_returned(got_food)
	)


func _person_returned(got_food: bool) -> void:
	_person_en_route = false
	if not got_food:
		_take_damage()


func _take_damage() -> void:
	health -= 1
	$food_amount_label.text = "HP: %d" % health  # temporary; replace with health bar
	if health <= 0:
		died.emit()


func set_highlight(mode: String) -> void:
	match mode:
		"hovering": modulate = Color(0.5, 0.5, 0.5, 1.0)
		"none":     modulate = Color(1.0, 1.0, 1.0, 1.0)


# Required by PlacementTileMap when converting a hover preview into a placed entity.
func set_placement_mode(_mode: String) -> void:
	pass
