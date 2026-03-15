extends Sprite2D

# Default seconds between food requests for each house type.
# Can be overridden per house in levels.json via the "delay" field.
const DEFAULT_DELAYS := {
	"low_need":  10.0,
	"normal":     5.0,
	"high_need":  2.5,
	"donator":    8.0,
}

const FOOD_TYPES   = ["bread", "veg", "meat"]
const MAX_HEALTH  := 10
const TRAVEL_SPEED := 0.5  # seconds per tile; kept for future use

signal died

var house_type:  String     = "inactive"
var needs:       Array      = []  # food types this house requests
var donates:     Array      = []  # donor only: food types deposited at pantry
var food_stock:  Dictionary = {}  # food_type -> amount on hand
var health:      int        = MAX_HEALTH
var delay:       float      = 5.0

var _tilemap:       TileMapLayer = null
var _grid_pos:      Vector2i
var _target_pantry: Node  = null

# --- visual bar state -------------------------------------------------------
var _health_bar_alpha:    float = 0.0  # 0 = hidden, 1 = fully visible
var _request_progress:    float = 0.0  # 1 = just got food, 0 = request firing
var _time_until_dispatch: float = 0.0  # countdown (seconds) to next request
var _health_tween:        Tween = null


# Called by PlacementTileMap after the house is placed.
# config mirrors the house entry in levels.json; empty dict = inactive.
func setup(config: Dictionary, tilemap: TileMapLayer, grid_pos: Vector2i) -> void:
	_tilemap  = tilemap
	_grid_pos = grid_pos

	if not config.has("type"):
		house_type = "inactive"
		modulate   = Color(0.5, 0.5, 0.5)  # grey placeholder
		return

	house_type = config["type"]
	needs      = config.get("needs",   FOOD_TYPES.duplicate())
	donates    = config.get("donates", [])
	delay      = config.get("delay",   DEFAULT_DELAYS.get(house_type, 5.0))

	# starting_food is [bread_amt, veg_amt, meat_amt] — matches FOOD_TYPES order
	var starting: Array = config.get("starting_food", [2, 2, 2])
	for i in FOOD_TYPES.size():
		food_stock[FOOD_TYPES[i]] = starting[i] if i < starting.size() else 2

	update_target_pantry()
	_start_demand_cycle()


# Finds the nearest reachable pantry. Called on setup and when the grid changes.
func update_target_pantry() -> void:
	if house_type == "inactive" or _tilemap == null:
		return
	_target_pantry = _tilemap.get_nearest_pantry(_grid_pos)


func _start_demand_cycle() -> void:
	# Stagger houses so they don't all request food at the same moment.
	var rand_offset := randf_range(0.0, delay)
	_time_until_dispatch = rand_offset  # bar starts depleting right away
	get_tree().create_timer(rand_offset).timeout.connect(func():
		_take_food()
		var recurring := Timer.new()
		recurring.wait_time = delay
		recurring.one_shot  = false
		recurring.timeout.connect(_take_food)
		add_child(recurring)
		recurring.start()
	)


func _take_food() -> void:
	var result = _tilemap.get_nearest_pantry(_grid_pos)
	if result == null:
		_take_damage()
		return

	var pantry: Node = result
	var got_food     := false

	if house_type == "donator":
		for food_type in donates:
			pantry.add_food(food_type)
		got_food = true
	else:
		for food_type in needs:
			if pantry.get_food_amount(food_type) > 0:
				pantry.take_food(food_type)
				food_stock[food_type] = food_stock.get(food_type, 0) + 1
				got_food = true
				break

	if got_food:
		# Reset countdown bar — house is satisfied, next request in `delay` seconds
		_time_until_dispatch = delay
		_request_progress    = 1.0
		queue_redraw()
	else:
		_take_damage()


func _take_damage() -> void:
	health -= 1
	_health_bar_alpha = 1.0
	queue_redraw()

	if health <= 0:
		died.emit()
		return

	# Keep health bar visible for 2 s, then fade out over 1 s
	if _health_tween:
		_health_tween.kill()
	_health_tween = create_tween()
	_health_tween.tween_interval(2.0)
	_health_tween.tween_method(
		func(a: float): _health_bar_alpha = a; queue_redraw(),
		1.0, 0.0, 1.0
	)


# Deplete the request bar each frame while waiting for the next dispatch.
func _process(delta: float) -> void:
	if house_type == "inactive":
		return
	if _time_until_dispatch > 0.0:
		_time_until_dispatch = max(0.0, _time_until_dispatch - delta)
		_request_progress    = _time_until_dispatch / delay
		queue_redraw()


# Draw the request bar (always visible for active houses) and health bar (fades).
# All coordinates are in local sprite space; at the default 0.25 node scale,
# 256 local units = 64 screen pixels.
func _draw() -> void:
	if house_type == "inactive" or texture == null:
		return

	var tex_w := texture.get_size().x
	var tex_h := texture.get_size().y
	var bar_w := tex_w          # bar spans the full sprite width
	var bar_h := 24.0           # at 0.25 scale → ~6 px on screen

	# Request bar — sits just above the sprite top
	var req_y := -(tex_h * 0.5) - bar_h - 12.0
	draw_rect(Rect2(-bar_w / 2.0, req_y, bar_w, bar_h),                        Color(0.1, 0.1, 0.1, 0.65))
	draw_rect(Rect2(-bar_w / 2.0, req_y, bar_w * _request_progress, bar_h),    Color(0.95, 0.78, 0.1, 0.9))

	# Health bar — appears above the request bar, fades out when not damaged
	if _health_bar_alpha > 0.01:
		var hp_y   := req_y - bar_h - 8.0
		var hp_pct := float(health) / float(MAX_HEALTH)
		draw_rect(Rect2(-bar_w / 2.0, hp_y, bar_w, bar_h),                   Color(0.1, 0.1, 0.1, _health_bar_alpha * 0.65))
		draw_rect(Rect2(-bar_w / 2.0, hp_y, bar_w * hp_pct, bar_h),          Color(0.15, 0.9, 0.25, _health_bar_alpha))


func set_highlight(mode: String) -> void:
	match mode:
		"hovering": modulate = Color(0.5, 0.5, 0.5, 1.0)
		"none":     modulate = Color(1.0, 1.0, 1.0, 1.0)


# Required by PlacementTileMap when converting a hover preview into a placed entity.
func set_placement_mode(_mode: String) -> void:
	pass
