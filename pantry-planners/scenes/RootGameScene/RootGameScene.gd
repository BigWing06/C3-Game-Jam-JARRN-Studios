extends Node2D

var levels
var level_index = 0
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var file = FileAccess.open("res://levels.json", FileAccess.READ)
	var content = file.get_as_text()
	var json = JSON.new()
	var error = json.parse(content)
	if error == OK:
		levels = json.data
	else:
		print("JSON Parse Error: ", json.get_error_message(), " in ", content, " at line ", json.get_error_line())
	$level_timer.wait_time = levels[level_index]["time"]
	$level_timer.start()
	
func next_level():
	var level_data = levels[level_index]
	if "level" in level_data.keys():
		print("Starting level:" + level_data["level"]["name"])
	if "houses" in level_data.keys():
		for house in level_data["houses"]:
			print("Creating " + house["type"] + " @ " + str(house["location"]))
	if "pantries" in level_data.keys():
		for type in level_data["pantries"]:
			$PlacementTileMap.add_to_inventory(type, level_data["pantries"][type])
			print(str(level_data["pantries"][type]) + " more of " + type)
	level_index += 1
	if (level_index < len(levels)):
		$level_timer.wait_time = levels[level_index]["time"]
		$level_timer.start()
	else:
		print("Free Play")
