extends Node2D

const DEFAULT_DELAYS := {
	"low_need":  10.0,
	"normal":     5.0,
	"high_need":  2.5,
	"donator":    8.0,
}

const FOOD_TYPES  = ["bread", "veg", "meat"]
const MAX_HEALTH := 10
const ANGER_MESSAGES = ["Could Obtain Food"]

signal died

var house_type: String     = "inactive"
var needs:      Array      = []
var donates:    Array      = []
var food_stock: Dictionary = {}
var health:     int        = MAX_HEALTH
var delay:      float      = 5.0

var _tilemap:  TileMapLayer = null
var _grid_pos: Vector2i

var _request_bar:  ProgressBar = null
var _health_bar:   ProgressBar = null
var _health_tween: Tween       = null

var _time_until_dispatch: float = 0.0


func _ready() -> void:
	$food_amount_label.hide()
	_setup_bars()


# ProgressBars are direct children so they share the house node's local
# coordinate space — the same math used in _draw() applies here.
# bar.theme = Theme.new() strips Godot's default minimum-size enforcement.
func _setup_bars() -> void:
	var tex_w   = $house.texture.get_size().x if $house.texture else 256.0
	var tex_h   = $house.texture.get_size().y if $house.texture else 256.0
	var bar_h   = tex_w * 0.06
	var bar_gap = bar_h * 0.4
	var req_y   = -(tex_h * 0.5)
	var hp_y    = req_y + bar_h + bar_gap

	_request_bar = _make_bar(tex_w, bar_h, Color(0.95, 0.75, 0.10), Color(0.08, 0.08, 0.08, 0.75))
	_request_bar.max_value = 1.0
	_request_bar.value     = 0.0
	_request_bar.position  = Vector2(-tex_w / 2.0, req_y)
	$house.add_child(_request_bar)

	_health_bar = _make_bar(tex_w, bar_h, Color(0.25, 0.90, 0.35), Color(0.08, 0.08, 0.08, 0.75))
	_health_bar.max_value  = MAX_HEALTH
	_health_bar.value      = MAX_HEALTH
	_health_bar.position   = Vector2(-tex_w / 2.0, hp_y)
	_health_bar.modulate.a = 0.0
	$house.add_child(_health_bar)

	_request_bar.hide()
	_health_bar.hide()


func _make_bar(width: float, height: float, fill_color: Color, bg_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.theme               = Theme.new()  # blank theme — no inherited minimum sizes
	bar.custom_minimum_size = Vector2(width, height)
	bar.size                = Vector2(width, height)
	bar.show_percentage     = false

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color              = fill_color
	fill_style.content_margin_left   = 0.0
	fill_style.content_margin_right  = 0.0
	fill_style.content_margin_top    = 0.0
	fill_style.content_margin_bottom = 0.0
	bar.add_theme_stylebox_override("fill", fill_style)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color              = bg_color
	bg_style.content_margin_left   = 0.0
	bg_style.content_margin_right  = 0.0
	bg_style.content_margin_top    = 0.0
	bg_style.content_margin_bottom = 0.0
	bar.add_theme_stylebox_override("background", bg_style)

	return bar


func setup(config: Dictionary, tilemap: TileMapLayer, grid_pos: Vector2i) -> void:
	_tilemap  = tilemap
	_grid_pos = grid_pos

	if not config.has("type"):
		house_type = "inactive"
		modulate   = Color(0.5, 0.5, 0.5)
		return

	house_type = config["type"]
	needs      = config.get("needs",   FOOD_TYPES.duplicate())
	donates    = config.get("donates", [])
	delay      = config.get("delay",   DEFAULT_DELAYS.get(house_type, 5.0))

	var starting: Array = config.get("starting_food", [2, 2, 2])
	for i in FOOD_TYPES.size():
		food_stock[FOOD_TYPES[i]] = starting[i] if i < starting.size() else 2

	_request_bar.show()
	_health_bar.show()
	_start_demand_cycle()


func _start_demand_cycle() -> void:
	var rand_offset := randf_range(0.0, delay)
	_time_until_dispatch = rand_offset
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
		_time_until_dispatch = delay
		_request_bar.value   = 1.0
		var spoilage_ui = preload("res://scenes/TextDisplay/TextDisplayy.tscn").instantiate()
		add_child(spoilage_ui)
		spoilage_ui.setup("Recieved Food", Color("#0000FF"), Vector2(50, -60))
	else:
		_take_damage()
		var spoilage_ui = preload("res://scenes/TextDisplay/TextDisplayy.tscn").instantiate()
		add_child(spoilage_ui)
		spoilage_ui.setup(ANGER_MESSAGES[randi_range(0, (len(ANGER_MESSAGES) - 1))], Color("#FF0000"), Vector2(50, -60))


func _take_damage() -> void:
	health -= 1
	_health_bar.value      = health
	_health_bar.modulate.a = 1.0
	_time_until_dispatch   = delay
	_request_bar.value     = 1.0

	if health <= 0:
		died.emit()
		return

	if _health_tween:
		_health_tween.kill()
	_health_tween = create_tween()
	_health_tween.tween_interval(2.0)
	_health_tween.tween_property(_health_bar, "modulate:a", 0.0, 1.0)


func _process(delta: float) -> void:
	if house_type == "inactive":
		return
	if _time_until_dispatch > 0.0:
		_time_until_dispatch = max(0.0, _time_until_dispatch - delta)
		_request_bar.value   = _time_until_dispatch / delay


func set_highlight(mode: String) -> void:
	match mode:
		"hovering": modulate = Color(0.5, 0.5, 0.5, 1.0)
		"none":     modulate = Color(1.0, 1.0, 1.0, 1.0)


func set_placement_mode(_mode: String) -> void:
	pass
