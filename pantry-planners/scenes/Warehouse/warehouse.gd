extends Sprite2D

@export var MAX_FOOD_DELIVERY: int

const FOOD_TYPES = ["bread", "veg", "meat"]

const RESTOCK_PRIORITY := {"bread": 18, "veg": 15, "meat": 10}
const RESTOCK_BASE     := {"bread":  4, "veg":  3, "meat":  2}

var inventory = {"bread": 18, "veg": 15, "meat": 10}

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
	var total = 0
	if len(amount) != 3:
		push_warning("Invalid food array")
	for i in range(len(FOOD_TYPES)):
		set_food_value(FOOD_TYPES[i], inventory[FOOD_TYPES[i]] + amount[i])
		total += inventory[FOOD_TYPES[i]]
	var spoilage_ui = preload("res://scenes/TextDisplay/TextDisplayy.tscn").instantiate()
	add_child(spoilage_ui)
	spoilage_ui.setup("Recieved Food +"+str(total), Color("#0000FF"), Vector2(30, -40))
	

func push_shipment():
	var pantries = get_tree().get_nodes_in_group("pantry")
	for food_type in FOOD_TYPES:
		var recipients = pantries.filter(func(p): return food_type in p.requested_foods)
		if recipients.is_empty():
			continue
		var amount = min(MAX_FOOD_DELIVERY, inventory[food_type] / recipients.size())
		if amount == 0:
			continue
		for pantry in recipients:
			set_food_value(food_type, inventory[food_type] - amount)
			pantry.add_food(food_type, amount)

func on_timeout():
	push_shipment()
	
func _process(delta: float) -> void:
	$restockbar.value = $restock_timer.time_left * 100 / $restock_timer.wait_time
	
func restock(type: String) -> void:
	for t in FOOD_TYPES:
		set_food_value(t, RESTOCK_PRIORITY[t] if t == type else RESTOCK_BASE[t])
	
	
