extends TileMapLayer

# ---------------------------------------------------------------------------
# Grid configuration
# ---------------------------------------------------------------------------
const GRID_WIDTH   := 30
const GRID_HEIGHT  := 18

# Cell size derived from the attached TileSet; falls back to 64x64 if not set.
var _cell_size: Vector2:
	get: return Vector2(tile_set.tile_size) if tile_set else Vector2(64.0, 64.0)

const PLACEABLE_ENTITIES = [
	{"key":"pantry",       "name": "Pantry"},
	{"key":"house",        "name": "House"},
	{"key":"small_pantry", "name": "Small Pantry"},
	{"key":"donor",        "name": "Donor"},
	{"key":"warehouse",    "name": "Warehouse"},
	{"key":"house_veg",    "name": "Veg House"},
	{"key":"house_meat",   "name": "Meat House"},
]

# ---------------------------------------------------------------------------
# Exports — swap in real scenes once pantry and house are finished
# ---------------------------------------------------------------------------
@export var scene_dict: Dictionary[String, PackedScene]

## Grid position where the warehouse is placed at startup.
@export var warehouse_tile: Vector2i = Vector2i(14, 8)

## How many pantries the player starts with in their inventory.
@export var starting_pantry_count: int = 30
## How many houses the player starts with in their inventory (usually 0).
@export var starting_house_count:  int = 30
@export var starting_small_pantry_count: int = 30
@export var starting_donor_count: int = 3  # given per donor food type

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal hovered_tile_changed
signal entity_built

# ---------------------------------------------------------------------------
# Runtime state
# ---------------------------------------------------------------------------
# grid_data (Vector2i) -> { "type": String, "player_can_edit": bool, "scene": Node }
var _grid_data:      Dictionary = {}
var _inventory:      Dictionary = {}
var _placement_mode: bool       = false
var _selected_item:  String     = "pantry"
var _hovered_tile:   Vector2i   = Vector2i(-1, -1)
var _hovering_preview:  Node       = null  # live ghost instance shown while hovering
# Tiles to highlight, set by the active hovering preview
var _highlighted_tiles: Dictionary[Vector2i, Color] = {}
var _setting_displayed: bool     = false
var _grid_layer: TileMapLayer

# Pantry inspection (click when not in placement mode)
var _inspected_pantry_tile: Vector2i = Vector2i(-1, -1)
var _pantry_info_panel:     PanelContainer = null
var _pantry_info_label:     Label          = null

# ---------------------------------------------------------------------------
# Node references
# ---------------------------------------------------------------------------
@onready var _mode_label:      Label = $UI/ModeLabel
@onready var _inventory_label: Label = $UI/InventoryLabel

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	_inventory = {
		"pantry":      starting_pantry_count,
		"house":       starting_house_count,
		"small_pantry":starting_small_pantry_count,
		"donor": starting_donor_count,
		"warehouse" :  1,
		"house_veg":   99,
		"house_meat":  99,
	}
	# Donor reuses the house scene; alias at runtime to avoid tscn edits
	scene_dict["donor"] = scene_dict["house"]
	scene_dict["house_veg"]  = scene_dict["house"]
	scene_dict["house_meat"] = scene_dict["house"]
	_setup_grid_layer()
	call_deferred("_place_entity", warehouse_tile, "warehouse", false)
	_create_pantry_info_panel()
	_update_ui()
	queue_redraw()


func _setup_grid_layer() -> void:
	var tile_size := tile_set.tile_size if tile_set else Vector2i(64, 64)
	var tile_px   := tile_size.x  # pixel width/height of one tile (assumes square)

	# Draw a single cell texture: transparent interior with a 1px white border on all edges.
	var cell_image := Image.create(tile_px, tile_px, false, Image.FORMAT_RGBA8)
	cell_image.fill(Color.TRANSPARENT)
	for i in range(tile_px):
		cell_image.set_pixel(i,           0,           Color.WHITE)
		cell_image.set_pixel(i,           tile_px - 1, Color.WHITE)
		cell_image.set_pixel(0,           i,           Color.WHITE)
		cell_image.set_pixel(tile_px - 1, i,           Color.WHITE)

	var atlas := TileSetAtlasSource.new()
	atlas.texture = ImageTexture.create_from_image(cell_image)
	atlas.texture_region_size = tile_size
	atlas.create_tile(Vector2i(0, 0))

	var grid_tile_set := TileSet.new()
	grid_tile_set.tile_size = tile_size
	grid_tile_set.add_source(atlas)

	_grid_layer = TileMapLayer.new()
	_grid_layer.tile_set = grid_tile_set
	_grid_layer.modulate = Color(0.4, 0.4, 0.4, 0.15)
	_grid_layer.z_index  = -1
	add_child(_grid_layer)

	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			_grid_layer.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_P:
				_toggle_placement_mode()
			KEY_ESCAPE:
				# Support for ESCAPE Settings Menu
				print("ESCAPE!")
				if _setting_displayed == false:
					_setting_displayed = true
					get_tree().paused = true
					var settings_scene = preload("res://scenes/Main Menu/SettingsUI.tscn")
					var settings = settings_scene.instantiate()
					add_child(settings)
					Audio.play_button_sound()
		if (event.keycode >= KEY_1 and event.keycode <= KEY_9):
			var num = event.keycode - KEY_1
			if num < len(PLACEABLE_ENTITIES):
				_selected_item = PLACEABLE_ENTITIES[num]["key"]
				_refresh_hover_preview()
				_update_ui()

	if event is InputEventMouseButton and event.pressed:
		var tile := local_to_map(to_local(get_global_mouse_position()))
		if _placement_mode:
			match event.button_index:
				MOUSE_BUTTON_LEFT:
					_try_place(tile)
				MOUSE_BUTTON_RIGHT:
					_try_remove(tile)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if _grid_data.has(tile) and _grid_data[tile]["type"] in ["pantry", "small_pantry"]:
				var pantry = _grid_data[tile]["scene"]
				pantry.cycle_requested_foods()
				_update_pantry_info_label(pantry)


func _process(_delta: float) -> void:
	if _setting_displayed:
		return

	# Show pantry info on hover, update live while hovering, hide on mouse leave
	var cur := local_to_map(to_local(get_global_mouse_position()))
	if not _placement_mode:
		if _grid_data.has(cur) and _grid_data[cur]["type"] in ["pantry", "small_pantry"] \
				and is_instance_valid(_grid_data[cur]["scene"]):
			_show_pantry_info(cur)
			_update_pantry_info_label(_grid_data[cur]["scene"])
		else:
			_hide_pantry_info()

	if not _placement_mode:
		return
	var new_tile := local_to_map(to_local(get_global_mouse_position()))
	if new_tile != _hovered_tile:
		_hovered_tile = new_tile
		hovered_tile_changed.emit()

# ---------------------------------------------------------------------------
# Drawing — grid + hovering entities, real scenes are handled automatically
# ---------------------------------------------------------------------------
func _draw() -> void:
	if _placement_mode:
		_draw_highlights()


# Destroys any existing hover preview and creates a fresh one for the selected item.
# Called when placement mode toggles or the selected item changes.
func _refresh_hover_preview() -> void:
	if is_instance_valid(_hovering_preview):
		_hovering_preview.queue_free()
		_hovering_preview = null

	if _placement_mode and scene_dict.has(_selected_item):
		_hovering_preview = scene_dict[_selected_item].instantiate()
		add_child(_hovering_preview)
		_on_hovered_tile_changed()

	queue_redraw()


# Connected to hovered_tile_changed. Moves the preview to the new tile and,
# for pantries, recalculates which houses fall inside their delivery radius.
func _on_hovered_tile_changed() -> void:
	_hovering_preview.position = map_to_local(_hovered_tile)
	if not _hovering_preview.has_method("find_reachable"):
		_highlighted_tiles.clear()
		return

	_hovering_preview.find_reachable(self, _hovered_tile)
	_highlighted_tiles.clear()

	# Highlight every reachable tile; dim houses outside the new radius.
	var unhighlighted_houses := get_tree().get_nodes_in_group("house")
	for pos: Vector2i in _hovering_preview.reachable_tiles.keys():
		_highlighted_tiles[pos] = Color(1.0, 1.0, 1.0, 0.35)
		if (_grid_data.get(pos, {}).get("type", "") as String).begins_with("house"):
			unhighlighted_houses.erase(_grid_data[pos]["scene"])
			_grid_data[pos]["scene"].set_highlight("hovering")
	for house in unhighlighted_houses:
		house.set_highlight("none")
	queue_redraw()


func _draw_highlights() -> void:
	var cs := _cell_size
	for tile: Vector2i in _highlighted_tiles:
		var rect := Rect2(map_to_local(tile) - cs * 0.5, cs)
		draw_rect(rect, _highlighted_tiles[tile], true)

# ---------------------------------------------------------------------------
# Placement logic
# ---------------------------------------------------------------------------
func _toggle_placement_mode() -> void:
	_placement_mode = not _placement_mode
	_hide_pantry_info()
	if not _placement_mode:
		_hovered_tile = Vector2i(-1, -1)
		hovered_tile_changed.disconnect(_on_hovered_tile_changed)
		for house in get_tree().get_nodes_in_group("house"):
			house.set_highlight("none")
		_grid_layer.modulate = Color(0.4, 0.4, 0.4, 0.15)
	else:
		hovered_tile_changed.connect(_on_hovered_tile_changed)
		_grid_layer.modulate = Color(0.45, 0.75, 0.45, 0.25)
	_refresh_hover_preview()
	_update_ui()


func _try_place(tile: Vector2i) -> void:
	if not _is_valid_tile(tile):
		return
	if _grid_data.has(tile):
		return
	if _inventory.get(_selected_item, 0) <= 0:
		return
	
	Audio.play_sfx(preload("res://MusicSFX/Notification Ding.mp3"))
	_place_entity(tile, _selected_item, true)
	_inventory[_selected_item] -= 1
	queue_redraw()
	_update_ui()


func _try_remove(tile: Vector2i) -> void:
	if not _grid_data.has(tile):
		return
	var data: Dictionary = _grid_data[tile]
	if not data["player_can_edit"]:
		return  # pre-placed level entities cannot be removed by the player
	if is_instance_valid(data["scene"]):
		data["scene"].queue_free()
		Audio.play_sfx(preload("res://MusicSFX/Button Press- Option 2.mp3"))
	_grid_data.erase(tile)
	_inventory[data["type"]] = _inventory.get(data["type"], 0) + 1
	queue_redraw()
	_update_ui()


func _place_entity(tile: Vector2i, entity_type: String, player_can_edit: bool) -> void:
	if not _is_valid_tile(tile) or _grid_data.has(tile):
		push_error("[PlacementTileMap] Cannot register entity at %s." % str(tile))
		return
	var scene_node: Node = null
	if is_instance_valid(_hovering_preview):
		# Convert the ghost preview into a permanent placed entity
		
		_hovering_preview.reparent($Entities)
		scene_node        = _hovering_preview
		_hovering_preview = null  # ownership transferred to _grid_data
		_refresh_hover_preview()
	elif scene_dict.has(entity_type):
		# Pre-placed: no preview exists, instantiate directly as a placed entity
		scene_node = scene_dict[entity_type].instantiate()
		scene_node.position = map_to_local(tile)
		$Entities.add_child(scene_node)
		if scene_node.has_method("find_reachable"):
			scene_node.find_reachable(self, tile)
	scene_node.set_placement_mode("placed")
	if entity_type in ["house", "house_veg", "house_meat"]:
		var needs: Array = {"house_veg": ["veg"], "house_meat": ["meat"]}.get(entity_type, [])
		scene_node.setup({"type": "normal", "needs": needs} if needs else {"type": "normal"}, self, tile)
		scene_node.died.connect(_on_game_over)
	elif entity_type == "donor":
		scene_node.setup({"type": "donator", "donates": ["bread"]}, self, tile)
	_grid_data[tile] = { "type": entity_type, "player_can_edit": player_can_edit, "scene": scene_node }
	for position_key in _grid_data.keys():
		if _grid_data[position_key]["scene"] in get_tree().get_nodes_in_group("pantry"):
			_grid_data[position_key]["scene"].find_reachable(self, position_key)
	
		
func _on_game_over() -> void:
	get_tree().paused = true
	var gameover_scene = preload("res://scenes/Main Menu/GameOver.tscn")
	var gameover = gameover_scene.instantiate()
	$UI.add_child(gameover)

# ---------------------------------------------------------------------------
# Public API — called by level scripts or a future GameManager
# ---------------------------------------------------------------------------

## Place a pre-defined (non-removable) entity at a grid position from code.
## Use this in a level's _ready() to set up fixed layout elements.
func place_entity_at(tile: Vector2i, entity_type: String) -> void:
	_place_entity(tile, entity_type, false)
	queue_redraw()


func place_house_at(tile: Vector2i, config: Dictionary = {}) -> void:
	if not _is_valid_tile(tile) or _grid_data.has(tile):
		push_error("[PlacementTileMap] Cannot place house at %s." % str(tile))
		return
	if not scene_dict.has("house") or scene_dict["house"] == null:
		push_error("[PlacementTileMap] 'house' PackedScene not assigned in scene_dict inspector export.")
		return
	var scene_node: Node = scene_dict["house"].instantiate()
	if scene_node == null:
		push_error("[PlacementTileMap] house PackedScene instantiation returned null.")
		return
	scene_node.position = map_to_local(tile)
	$Entities.add_child(scene_node)
	scene_node.set_placement_mode("placed")
	scene_node.setup(config, self, tile)
	if not config.get("inactive", false):
		scene_node.died.connect(_on_game_over)
	var player_can_edit: bool = config.get("player_can_edit", false)
	_grid_data[tile] = {"type": "house", "player_can_edit": player_can_edit, "scene": scene_node}
	for pos in _grid_data.keys():
		if _grid_data[pos]["scene"] in get_tree().get_nodes_in_group("pantry"):
			_grid_data[pos]["scene"].find_reachable(self, pos)
	queue_redraw()


## Add items to the player's inventory at runtime (e.g. after a donor event).
func add_to_inventory(entity_type: String, amount: int = 1) -> void:
	_inventory[entity_type] = _inventory.get(entity_type, 0) + amount
	_update_ui()


## Returns a copy of the current grid data for external systems to read.
func get_grid_data() -> Dictionary:
	return _grid_data.duplicate()

func get_grid_cell(pos: Vector2i) -> Dictionary:
	return _grid_data[pos].duplicate()

## Returns true if the tile is outside bounds or occupied by any entity.
## Used by Dijkstra in pantry/house scripts to determine walkable space.
func is_tile_blocked(tile: Vector2i) -> bool:
	return not _is_valid_tile(tile) or _grid_data.has(tile)


## Returns all grid positions occupied by a given entity type.
func get_positions_of_type(entity_type: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for tile: Vector2i in _grid_data:
		if _grid_data[tile]["type"] == entity_type:
			result.append(tile)
	return result
	
func get_hovered_tile() -> Vector2i:
	return _hovered_tile

func _is_valid_tile(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.x < GRID_WIDTH \
		and tile.y >= 0 and tile.y < GRID_HEIGHT

## Returns the pantry node closest to the given grid tile, or null if none exist.
## Converts the grid position to world space before comparing so distances are correct.
func get_nearest_pantry(grid_pos: Vector2i) -> Node:
	var world_pos  := map_to_local(grid_pos)
	var nearest: Node = null
	var nearest_dist  := INF
	for pantry in get_tree().get_nodes_in_group("pantry"):
		if not pantry.reachable_houses.has(grid_pos):
			continue
		var dist := world_pos.distance_to(pantry.global_position)
		if dist < nearest_dist:
			nearest      = pantry
			nearest_dist = dist
	return nearest
		
	

# ---------------------------------------------------------------------------
# Pantry info panel — shown when clicking a pantry outside placement mode
# ---------------------------------------------------------------------------
func _create_pantry_info_panel() -> void:
	_pantry_info_panel = PanelContainer.new()
	_pantry_info_label = Label.new()
	_pantry_info_label.add_theme_font_size_override("font_size", 16)
	_pantry_info_panel.add_child(_pantry_info_label)
	_pantry_info_panel.position = Vector2(1050.0, 10.0)  # top-right corner
	_pantry_info_panel.hide()
	$UI.add_child(_pantry_info_panel)


func _show_pantry_info(tile: Vector2i) -> void:
	_inspected_pantry_tile = tile
	_update_pantry_info_label(_grid_data[tile]["scene"])
	_pantry_info_panel.show()


func _hide_pantry_info() -> void:
	_inspected_pantry_tile = Vector2i(-1, -1)
	_pantry_info_panel.hide()


func _update_pantry_info_label(pantry: Node) -> void:
	var requested := " + ".join(pantry.requested_foods.map(func(f): return f.capitalize()))
	var lines := "Pantry Stock\n─────────────\n"
	for food in ["bread", "veg", "meat"]:
		lines += "  %s: %d\n" % [food.capitalize(), pantry.get_food_amount(food)]
	lines += "─────────────\nAccepts: %s\n[Click to cycle]" % requested
	_pantry_info_label.text = lines


# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------
func _update_ui() -> void:
	if _placement_mode:
		_mode_label.text = (
			"[ PLACEMENT MODE ]   P = exit   Right-click = remove\n"
			+ "Placing: " + _selected_item.to_upper() + "     "
		)
		for i in range(len(PLACEABLE_ENTITIES)):
			_mode_label.text += "["+ str(i + 1) + "] " + PLACEABLE_ENTITIES[i]["name"] + "  "
		_mode_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	else:
		_mode_label.text = "Press [P] to enter Placement Mode"
		_mode_label.remove_theme_color_override("font_color")

	var inv_text := "-- Inventory --\n"
	for item: String in _inventory:
		inv_text += "  %s: %d\n" % [item.capitalize(), _inventory[item]]
	_inventory_label.text = inv_text
