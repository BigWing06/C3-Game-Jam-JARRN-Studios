extends Node2D

# ---------------------------------------------------------------------------
# Grid configuration
# ---------------------------------------------------------------------------
const CELL_SIZE    := Vector2(128, 128)
const GRID_WIDTH   := 20
const GRID_HEIGHT  := 12

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
@export var pantry_scene: PackedScene  # leave empty while using placeholders
@export var house_scene:  PackedScene  # leave empty while using placeholders

## Pre-placed pantry grid positions set per-level in the Inspector.
@export var initial_pantry_positions: Array[Vector2i] = []
## Pre-placed house grid positions set per-level in the Inspector.
@export var initial_house_positions:  Array[Vector2i] = []

## How many pantries the player starts with in their inventory.
@export var starting_pantry_count: int = 3
## How many houses the player starts with in their inventory (usually 0).
@export var starting_house_count:  int = 0

# ---------------------------------------------------------------------------
# Runtime state
# ---------------------------------------------------------------------------
# grid_pos (Vector2i) -> { "type": String, "player_can_edit": bool }
var _grid_data:       Dictionary = {}
var _inventory:       Dictionary = {}
var _placement_mode:  bool       = false
var _selected_item:   String     = "pantry"
var _hovered_tile:    Vector2i   = Vector2i(-1, -1)

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
	for pos in initial_pantry_positions:
		_register_entity(pos, "pantry", false)
	for pos in initial_house_positions:
		_register_entity(pos, "house", false)

# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_P:
				_toggle_placement_mode()
			KEY_1:
				_selected_item = "pantry"
				_update_ui()
			KEY_2:
				_selected_item = "house"
				_update_ui()

	if event is InputEventMouseButton and event.pressed and _placement_mode:
		var tile := _world_to_grid(get_global_mouse_position())
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_try_place(tile)
			MOUSE_BUTTON_RIGHT:
				_try_remove(tile)


func _process(_delta: float) -> void:
	if not _placement_mode:
		return
	var new_tile := _world_to_grid(get_global_mouse_position())
	if new_tile != _hovered_tile:
		_hovered_tile = new_tile
		queue_redraw()

# ---------------------------------------------------------------------------
# Drawing — grid + all placeholders rendered here; no external scenes needed
# ---------------------------------------------------------------------------
func _draw() -> void:
	_draw_grid()
	_draw_placed_entities()
	if _placement_mode:
		_draw_hover()


func _draw_grid() -> void:
	var col := Color(0.45, 0.75, 0.45, 0.25) if _placement_mode \
		else Color(0.4, 0.4, 0.4, 0.15)
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			draw_rect(Rect2(Vector2(x, y) * CELL_SIZE, CELL_SIZE), col, false, 1.0)


func _draw_placed_entities() -> void:
	for grid_pos: Vector2i in _grid_data:
		var data: Dictionary = _grid_data[grid_pos]
		var entity_type: String = data["type"]
		var fill_col: Color = ENTITY_COLORS.get(entity_type, Color.GRAY)

		var origin := Vector2(grid_pos) * CELL_SIZE
		var rect   := Rect2(origin + Vector2(4, 4), CELL_SIZE - Vector2(8, 8))

		# Slightly dim pre-placed entities so player-placed ones stand out
		if not data["player_can_edit"]:
			fill_col = fill_col.darkened(0.25)

		draw_rect(rect, fill_col, true)
		draw_rect(rect, Color.WHITE, false, 1.5)

		# Single-character label centred in the cell
		var label: String = ENTITY_LABELS.get(entity_type, "?")
		var font  := ThemeDB.fallback_font
		var font_size := 20
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var text_pos  := origin + CELL_SIZE * 0.5 - text_size * 0.5 + Vector2(0, text_size.y * 0.25)
		draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func _draw_hover() -> void:
	if not _is_valid_tile(_hovered_tile):
		return
	var occupied := _grid_data.has(_hovered_tile)
	var fill     := Color(0.85, 0.2, 0.2, 0.35) if occupied \
		else Color(0.2, 0.85, 0.2, 0.35)
	var rect     := Rect2(Vector2(_hovered_tile) * CELL_SIZE, CELL_SIZE)
	draw_rect(rect, fill, true)
	draw_rect(rect, Color.WHITE, false, 2.0)

# ---------------------------------------------------------------------------
# Placement logic
# ---------------------------------------------------------------------------
func _toggle_placement_mode() -> void:
	_placement_mode = not _placement_mode
	if not _placement_mode:
		_hovered_tile = Vector2i(-1, -1)
	queue_redraw()
	_update_ui()


func _try_place(tile: Vector2i) -> void:
	if not _is_valid_tile(tile):
		return
	if _grid_data.has(tile):
		return
	if _inventory.get(_selected_item, 0) <= 0:
		return

	_register_entity(tile, _selected_item, true)
	_inventory[_selected_item] -= 1
	queue_redraw()
	_update_ui()


func _try_remove(tile: Vector2i) -> void:
	if not _grid_data.has(tile):
		return
	var data: Dictionary = _grid_data[tile]
	if not data["player_can_edit"]:
		return  # pre-placed level entities cannot be removed by the player
	_grid_data.erase(tile)
	_inventory[data["type"]] = _inventory.get(data["type"], 0) + 1
	queue_redraw()
	_update_ui()


func _register_entity(tile: Vector2i, entity_type: String, player_can_edit: bool) -> void:
	if not _is_valid_tile(tile) or _grid_data.has(tile):
		push_error("[PlacementTileMap] Cannot register entity at %s." % str(tile))
		return
	_grid_data[tile] = { "type": entity_type, "player_can_edit": player_can_edit }

# ---------------------------------------------------------------------------
# Public API — called by level scripts or a future GameManager
# ---------------------------------------------------------------------------

## Place a pre-defined (non-removable) entity at a grid position from code.
## Use this in a level's _ready() to set up fixed layout elements.
func place_entity_at(tile: Vector2i, entity_type: String) -> void:
	_register_entity(tile, entity_type, false)
	queue_redraw()


## Add items to the player's inventory at runtime (e.g. after a donor event).
func add_to_inventory(entity_type: String, amount: int = 1) -> void:
	_inventory[entity_type] = _inventory.get(entity_type, 0) + amount
	_update_ui()


## Returns a copy of the current grid data for external systems to read.
func get_grid_data() -> Dictionary:
	return _grid_data.duplicate()


## Returns all grid positions occupied by a given entity type.
func get_positions_of_type(entity_type: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for tile: Vector2i in _grid_data:
		if _grid_data[tile]["type"] == entity_type:
			result.append(tile)
	return result

# ---------------------------------------------------------------------------
# Coordinate helpers
# ---------------------------------------------------------------------------
func _world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x / CELL_SIZE.x), int(world_pos.y / CELL_SIZE.y))


func grid_to_world_center(tile: Vector2i) -> Vector2:
	return Vector2(tile) * CELL_SIZE + CELL_SIZE * 0.5


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
