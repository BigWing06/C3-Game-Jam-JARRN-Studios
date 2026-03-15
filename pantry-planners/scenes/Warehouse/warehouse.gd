extends Sprite2D

@export var MAX_FOOD_DELIVERY: int
@export var priority_food_amount: int
@export var food_amount: int

const FOOD_TYPES = [
	"bread",
	"veg",
	"meat"
]

var inventory = {FOOD_TYPES[0]: 20, FOOD_TYPES[1]: 20, FOOD_TYPES[2]: 20}
const WAREHOUSE_TEXTURE := preload("res://Sprites/Pantries/Warehouse.png")


func _ready():
	texture = WAREHOUSE_TEXTURE
	get_parent().get_parent().get_node("WarehouseDisplay").setup(self)
	for type in FOOD_TYPES:
		get_parent().get_parent().get_node("WarehouseDisplay/display_container/" + type + "_display").update_text(inventory[type])

func set_placement_mode(mode):
	if mode == "placed":
		$restock_timer.start()
	
func set_food_value(type, amount):
	if type not in FOOD_TYPES:
		push_warning(str(type) + " is not a valid food type!")
	inventory[type] = amount
	get_parent().get_parent().get_parent().get_node("WarehouseDisplay/display_container/" + type + "_display").update_text(amount)
	
	
func add_food_amount(amount: Array):
	if len(amount) != 3:
		push_warning("Invalid food array")
	for i in range(len(FOOD_TYPES)):
		set_food_value(FOOD_TYPES[i], inventory[FOOD_TYPES[i]] + amount[i])

func push_shipment():
	var pantries = get_tree().get_nodes_in_group("pantry")
	for i in range(len(FOOD_TYPES)):
		var given_food_amount = (inventory[FOOD_TYPES[i]] - inventory[FOOD_TYPES[i]] % len(pantries)) / len(pantries)
		if (given_food_amount > MAX_FOOD_DELIVERY):
			given_food_amount = MAX_FOOD_DELIVERY
		if given_food_amount != 0:
			for pantry in pantries:
				set_food_value(FOOD_TYPES[i], inventory[FOOD_TYPES[i]] - given_food_amount)
				pantry.add_food(FOOD_TYPES[i], given_food_amount)

func on_timeout():
	push_shipment()
	
func _process(delta: float) -> void:
	$restockbar.value = $restock_timer.time_left * 100 / $restock_timer.wait_time
	
func restock(type):
	set_food_value(type, priority_food_amount)
	for t in FOOD_TYPES:
		if t != type:
			set_food_value(t, food_amount)
	
	
