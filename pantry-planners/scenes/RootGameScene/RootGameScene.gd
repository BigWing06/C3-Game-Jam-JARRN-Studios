extends Node2D

var levels
var level_index = 0

const PLACEMENT_TILEMAP_SCENE = preload("res://scenes/PlacementTileMap/PlacementTileMap.tscn")
const SCENE_DICT = {
	"house": preload("res://scenes/house/house.tscn"),
	"pantry": preload("res://scenes/pantry/pantry.tscn"),
	"small_pantry": preload("res://scenes/pantry/small_pantry.tscn"),
	"warehouse": preload("res://scenes/Warehouse/Warehouse.tscn")
}
var placement_tilemap = null

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
	load_level()


	
func next_level():
	if level_index > 0:
		level_success()
		return
	load_level()
		
func load_level():
	if is_instance_valid(placement_tilemap):
		placement_tilemap.queue_free()
	var level_data = levels[level_index]
	print(level_data)
	print(level_index)
	if "level" in level_data.keys():
		print("entering if")
		#await ScreenTransition.fade_out()
		#await ScreenTransition.fade_in()
		var cutscene_scene = preload("res://scenes/Cutscenes/Cutscene.tscn")
		var cutscene = cutscene_scene.instantiate()
		add_child(cutscene)
		cutscene.start_cutscene(level_data["level"])
		cutscene.finish_level_load.connect(finish_load.bind(level_data))
	else:
		finish_load(level_data)
func finish_load(level_data):
	placement_tilemap = PLACEMENT_TILEMAP_SCENE.instantiate()
	add_child(placement_tilemap)
	if "houses" in level_data.keys():
		for house in level_data["houses"]:
			var config := {
				"type": house.get("type", "normal"),
				"inactive": house.get("inactive", false),
				"player_can_edit": false,
			}
			if "needs" in house:
				config["needs"] = house["needs"]
			placement_tilemap.place_house_at(
				Vector2i(house["location"][0], house["location"][1]), config)
	if "pantries" in level_data.keys():
		for type in level_data["pantries"]:
			placement_tilemap.add_to_inventory(type, level_data["pantries"][type])
	level_index += 1
	if (level_index < len(levels)):
		$level_timer.wait_time = levels[level_index]["time"]
		$level_timer.start()
	else:
		get_tree().change_scene_to_file("res://scenes/Main Menu/CreditsUI.tscn")
		
func _place_house_deferred(tile: Vector2i, config: Dictionary) -> void:
	$PlacementTileMap.place_house_at(tile, config)


func _on_success_next():
	get_tree().paused = false
	await ScreenTransition.fade_out()
	load_level()
	await ScreenTransition.fade_in()

func level_success():
	var success_scene = preload("res://scenes/Main Menu/Success.tscn")
	var success = success_scene.instantiate()
	success.next_pressed.connect(load_level)
	add_child(success)
