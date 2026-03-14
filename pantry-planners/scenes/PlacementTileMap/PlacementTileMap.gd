extends TileMapLayer

# ---------------------------------------------------------------------------
# Grid configuration
# ---------------------------------------------------------------------------
const GRID_WIDTH   := 20
const GRID_HEIGHT  := 12

# Cell size derived from the attached TileSet; falls back to 64x64 if not set.
var _cell_size: Vector2:
	get: return Vector2(tile_set.tile_size) if tile_set else Vector2(64.0, 64.0)

# ---------------------------------------------------------------------------
# Placeholder appearance per entity type
# ---------------------------------------------------------------------------
const ENTITY_COLORS := {
	"pantry": Color(1.0, 0.65, 0.0, 0.85),   # orange
	"house":  Color(0.3, 0.6,  1.0, 0.85),   # blue
}
const ENTITY_LABELS := {
	"pantry": "P",
	"house":  "H",
}

# ---------------------------------------------------------------------------
# Exports — swap in real scenes once pantry and house are finished
# ---------------------------------------------------------------------------
@export var scene_dict: Dictionary[String, PackedScene]

## Initial tile layout for this level. Each entry needs "pos" (Vector2i) and "type" (String).
## Example: { "pos": Vector2i(3, 2), "type": "pantry" }
@export var initial_tile_positions: Array[Dictionary] = [
{"pos": Vector2i(3, 3), "type": "house"},
{"pos": Vector2i(5, 3), "type": "pantry"},
]

## How many pantries the player starts with in their inventory.
@export var starting_pantry_count: int = 30
## How many houses the player starts with in their inventory (usually 0).
@export var starting_house_count:  int = 30

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal update_hovered_cell

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

# ---------------------------------------------------------------------------
# Node references
# ---------------------------------------------------------------------------
@onready var _mode_label:      Label = $UI/ModeLabel
@onready var _inventory_label: Label = $UI/InventoryDisplay/InventoryLabel

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	_inventory = {
		"pantry": starting_pantry_count,
		"house":  starting_house_count,
	}
	_place_initial_entities()
	_update_ui()
	queue_redraw()


func _place_initial_entities() -> void:
	for entry: Dictionary in initial_tile_positions:
		_place_entity(entry["pos"], entry["type"], false)

# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_P:
				_toggle_placement_mode()
			KEY_1:
				print(_selected_item)
				if _selected_item != "pantry":
					_selected_item = "pantry"
					_refresh_hover_preview()
					_update_ui()
			KEY_2:
				if _selected_item != "house":
					_selected_item = "house"
					_refresh_hover_preview()
					_update_ui()
			KEY_ESCAPE:
				# Support for ESCAPE Settings Menu
				print("ESCAPE!")
				if _setting_displayed == false:
					_setting_displayed = true
					var settings_scene = preload("res://scenes/Main Menu/SettingsUI.tscn")
					var settings = settings_scene.instantiate()
					add_child(settings)
					Audio.play_button_sound()

	if event is InputEventMouseButton and event.pressed and _placement_mode:
		var tile := local_to_map(to_local(get_global_mouse_position()))
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_try_place(tile)
			MOUSE_BUTTON_RIGHT:
				_try_remove(tile)


func _process(_delta: float) -> void:
	if not _placement_mode:
		return
	var new_tile := local_to_map(to_local(get_global_mouse_position()))
	if new_tile != _hovered_tile:
		_hovered_tile = new_tile
		update_hovered_cell.emit()

# ---------------------------------------------------------------------------
# Drawing — grid + hovering entities, real scenes are handled automatically
# ---------------------------------------------------------------------------
func _draw() -> void:
	_draw_grid()
	_draw_placed_entities()
	if _placement_mode:
		_draw_hover()
		_draw_highlights()



func _draw_grid() -> void:
	var col := Color(0.45, 0.75, 0.45, 0.25) if _placement_mode \
		else Color(0.4, 0.4, 0.4, 0.15)
	var cs := _cell_size
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var top_left := map_to_local(Vector2i(x, y)) - cs * 0.5
			draw_rect(Rect2(top_left, cs), col, false, 1.0)


func _draw_placed_entities() -> void:
	var cs := _cell_size
	for grid_pos: Vector2i in _grid_data:
		var data: Dictionary = _grid_data[grid_pos]
		var entity_type: String = data["type"]

		var center := map_to_local(grid_pos)
		var origin := center - cs * 0.5

		if is_instance_valid(data["scene"]):
			continue
			# no need because scenes will render themselves,
			# they are placed via _place_initial_entities()
		else:
			# fallback placeholder
			var fill_col: Color = ENTITY_COLORS.get(entity_type, Color.GRAY)
			if not data["player_can_edit"]:
				fill_col = fill_col.darkened(0.25)

			var rect := Rect2(origin + Vector2(4, 4), cs - Vector2(8, 8))
			draw_rect(rect, fill_col, true)
			draw_rect(rect, Color.WHITE, false, 1.5)

			var label: String = ENTITY_LABELS.get(entity_type, "?")
			var font  := ThemeDB.fallback_font
			var font_size := 20
			var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var text_pos  := center - text_size * 0.5 + Vector2(0, text_size.y * 0.25)
			draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


# Spawns (or clears) the live hover preview node.
# Called whenever the hovered tile or selected item changes, and on mode toggle.
func _refresh_hover_preview() -> void:
	# No preview needed outside placement mode or off the grid
	if not _placement_mode:
		
		if (is_instance_valid(_hovering_preview)):
			_hovering_preview.queue_free()
			_hovering_preview = null
		queue_redraw()
		return
	
	if is_instance_valid(_hovering_preview):
		_hovering_preview.queue_free()
		_hovering_preview = null
		
	# If the item has a real scene, spawn a translucent ghost preview
	if scene_dict.has(_selected_item):
		_hovering_preview = scene_dict[_selected_item].instantiate()
		_update_hover_position()
		add_child(_hovering_preview)
		

	queue_redraw()

func _update_hover_position():
	_hovering_preview.position = map_to_local(_hovered_tile)
	if _hovering_preview.has_method("find_reachable"):
		_hovering_preview.find_reachable(self, _hovered_tile)
		_highlighted_tiles.clear()
		var houses = get_tree().get_nodes_in_group("house")
		for pos: Vector2i in _hovering_preview.reachable_tiles.keys():
			_highlighted_tiles[pos] = Color(1.0, 1.0, 1, 0.35)
			if pos in _grid_data.keys():
				if _grid_data[pos]["type"] == "house":
					houses.erase(_grid_data[pos]["scene"])
					_grid_data[pos]["scene"].set_highlight("hovering")
		for node in houses:
			node.set_highlight("none")
		queue_redraw()


# MOSTLY UNUSED. only used when the selected item has no entry in scene_dict.
func _draw_hover() -> void:
	if not _is_valid_tile(_hovered_tile):
		return
	if scene_dict.has(_selected_item):
		return  # real preview is handled by _refresh_hover_preview, nothing to draw here

	var cs       := _cell_size
	var occupied := _grid_data.has(_hovered_tile)
	var fill     := Color(0.85, 0.2, 0.2, 0.35) if occupied \
		else Color(0.2, 0.85, 0.2, 0.35)
	var rect     := Rect2(map_to_local(_hovered_tile) - cs * 0.5, cs)
	draw_rect(rect, fill, true)
	draw_rect(rect, Color.WHITE, false, 2.0)

func _draw_highlights() -> void:
	var cs := _cell_size
	var houses = get_tree().get_nodes_in_group("houses")
	
	for tile: Vector2i in _highlighted_tiles:
		var rect := Rect2(map_to_local(tile) - cs * 0.5, cs)
		draw_rect(rect, _highlighted_tiles[tile], true)

# ---------------------------------------------------------------------------
# Placement logic
# ---------------------------------------------------------------------------
func _toggle_placement_mode() -> void:
	_placement_mode = not _placement_mode
	if not _placement_mode:
		_hovered_tile = Vector2i(-1, -1)
		update_hovered_cell.disconnect(_update_hover_position)
		var houses = get_tree().get_nodes_in_group("house")
		for node in houses:
			node.set_highlight("none")
	else:
		update_hovered_cell.connect(_update_hover_position)
	_refresh_hover_preview()
	_update_ui()


func _try_place(tile: Vector2i) -> void:
	if not _is_valid_tile(tile):
		return
	if _grid_data.has(tile):
		return
	if _inventory.get(_selected_item, 0) <= 0:
		return

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
		_hovering_preview.set_placement_mode("placed")
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
	_grid_data[tile] = { "type": entity_type, "player_can_edit": player_can_edit, "scene": scene_node }
		

# ---------------------------------------------------------------------------
# Public API — called by level scripts or a future GameManager
# ---------------------------------------------------------------------------

## Place a pre-defined (non-removable) entity at a grid position from code.
## Use this in a level's _ready() to set up fixed layout elements.
func place_entity_at(tile: Vector2i, entity_type: String) -> void:
	_place_entity(tile, entity_type, false)
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

# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------
func _update_ui() -> void:
	if _placement_mode:
		_mode_label.text = (
			"[ PLACEMENT MODE ]   P = exit   Right-click = remove\n"
			+ "Placing: %s      [1] Pantry   [2] House" % _selected_item.to_upper()
		)
		_mode_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	else:
		_mode_label.text = "Press [P] to enter Placement Mode"
		_mode_label.remove_theme_color_override("font_color")

	var inv_text := "-- Inventory --\n"
	for item: String in _inventory:
		inv_text += "  %s: %d\n" % [item.capitalize(), _inventory[item]]
	_inventory_label.text = inv_text
