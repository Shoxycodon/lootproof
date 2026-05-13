extends Node2D

signal build_changed
signal trap_requested(scene: PackedScene, grid_position: Vector2i, item_index: int)

@export var tile_size := 32
@export var max_build_points := 20
@export var build_points := 20
@export var min_grid_x := -3
@export var max_grid_x := 38
@export var min_grid_y := 3
@export var max_grid_y := 17
@export var spike_scene: PackedScene = preload("res://Traps/SpikeTrap.tscn")
@export var saw_scene: PackedScene = preload("res://Traps/SawTrap.tscn")
@export var bounce_scene: PackedScene = preload("res://Traps/BouncePad.tscn")
@export var falling_scene: PackedScene = preload("res://Traps/FallingBlock.tscn")
@export var platform_texture: Texture2D = preload("res://Assets/Tiles/tile_stone_32.png")
@export var default_platform_texture: Texture2D = preload("res://Assets/Tiles/tile_stone_dark_32.png")

var build_mode := true
var selected_index := 0
var placed := {}
var item_names := ["Platform", "Spike", "Saw", "Bounce", "Falling"]
var item_costs := [1, 2, 3, 2, 3]
var build_cursor := Vector2i(5, 14)
var cursor_active := true


func _ready() -> void:
	build_points = max_build_points
	_create_default_dungeon()


func _input(event: InputEvent) -> void:
	if not build_mode:
		return
	if event is InputEventMouseMotion:
		cursor_active = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		cursor_active = false
		_try_place(world_to_grid(get_global_mouse_position()))
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("move_left"):
		_move_cursor(Vector2i.LEFT)
	if event.is_action_pressed("move_right"):
		_move_cursor(Vector2i.RIGHT)
	if event.is_action_pressed("build_up"):
		_move_cursor(Vector2i.UP)
	if event.is_action_pressed("build_down"):
		_move_cursor(Vector2i.DOWN)
	if event.is_action_pressed("trap_next"):
		selected_index = (selected_index + 1) % item_names.size()
	if event.is_action_pressed("interact"):
		_try_place(_get_target_grid())


func _draw() -> void:
	if not build_mode:
		return
	for x in range(min_grid_x, max_grid_x + 2):
		draw_line(Vector2(x * tile_size, min_grid_y * tile_size), Vector2(x * tile_size, (max_grid_y + 1) * tile_size), Color(0.35, 0.55, 0.7, 0.16))
	for y in range(min_grid_y, max_grid_y + 2):
		draw_line(Vector2(min_grid_x * tile_size, y * tile_size), Vector2((max_grid_x + 1) * tile_size, y * tile_size), Color(0.35, 0.55, 0.7, 0.16))

	draw_rect(Rect2(Vector2(min_grid_x * tile_size, min_grid_y * tile_size), Vector2((max_grid_x - min_grid_x + 1) * tile_size, (max_grid_y - min_grid_y + 1) * tile_size)), Color(1, 0.84, 0.3, 0.55), false, 4.0)

	var target_grid := _get_target_grid()
	var color := Color(0.22, 1, 0.56, 0.65) if _can_place(target_grid) else Color(1, 0.15, 0.24, 0.7)
	draw_rect(Rect2(Vector2(target_grid * tile_size), Vector2(tile_size, tile_size)), color, false, 3.0)
	draw_circle(Vector2(target_grid * tile_size) + Vector2(tile_size, tile_size) * 0.5, 5.0, color)
	_draw_hologram(target_grid, color)


func _process(_delta: float) -> void:
	if build_mode:
		queue_redraw()


func set_build_mode(enabled: bool) -> void:
	build_mode = enabled
	queue_redraw()


func reset_build_points(points := -1) -> void:
	build_points = max_build_points if points < 0 else points


func get_selected_item_name() -> String:
	return item_names[selected_index]


func get_selected_item_cost() -> int:
	return item_costs[selected_index]


func grid_to_world(grid_position: Vector2i) -> Vector2:
	return Vector2(grid_position * tile_size) + Vector2(tile_size, tile_size) * 0.5


func world_to_grid(world_position: Vector2) -> Vector2i:
	return Vector2i(floori(world_position.x / tile_size), floori(world_position.y / tile_size))


func collapse_step(elapsed: float) -> void:
	var max_x := floori(elapsed * 5.0)
	for key in placed.keys().duplicate():
		var entry: Dictionary = placed[key]
		var node = entry.get("node")
		if key.x <= max_x and node is Object and is_instance_valid(node):
			node.queue_free()
			placed.erase(key)
			break


func _try_place(grid_position: Vector2i) -> void:
	if not _can_place(grid_position):
		return
	build_points -= item_costs[selected_index]
	if selected_index == 0:
		_create_platform(grid_position)
	else:
		var scenes := [null, spike_scene, saw_scene, bounce_scene, falling_scene]
		placed[grid_position] = {"node": null, "item": selected_index, "mutable": true}
		trap_requested.emit(scenes[selected_index], grid_position, selected_index)
	build_changed.emit()


func _can_place(grid_position: Vector2i) -> bool:
	if build_points < item_costs[selected_index]:
		return false
	if placed.has(grid_position):
		return false
	return grid_position.x >= min_grid_x and grid_position.x <= max_grid_x and grid_position.y >= min_grid_y and grid_position.y <= max_grid_y


func set_trap_node(grid_position: Vector2i, trap: Node, item_index: int) -> void:
	placed[grid_position] = {"node": trap, "item": item_index, "mutable": true}


func clear_user_build() -> void:
	for key in placed.keys().duplicate():
		var entry: Dictionary = placed[key]
		if not entry.get("mutable", false):
			continue
		var node = entry.get("node")
		if node is Object and is_instance_valid(node):
			node.queue_free()
		placed.erase(key)
	build_points = max_build_points
	queue_redraw()


func snapshot_user_build() -> Dictionary:
	var items := []
	for key in placed.keys():
		var entry: Dictionary = placed[key]
		if entry.get("mutable", false):
			items.append({"grid": key, "item": entry.get("item", 0)})
	return {"items": items, "build_points": build_points}


func restore_user_build(snapshot: Dictionary) -> void:
	clear_user_build()
	build_points = int(snapshot.get("build_points", max_build_points))
	for item in snapshot.get("items", []):
		var grid_position: Vector2i = item["grid"]
		var item_index := int(item["item"])
		if item_index == 0:
			_create_platform(grid_position, true)
		else:
			var scenes := [null, spike_scene, saw_scene, bounce_scene, falling_scene]
			placed[grid_position] = {"node": null, "item": item_index, "mutable": true}
			trap_requested.emit(scenes[item_index], grid_position, item_index)
	queue_redraw()


func _create_default_dungeon() -> void:
	for x in range(min_grid_x, max_grid_x + 1):
		_create_platform(Vector2i(x, 16), false)
	for x in range(8, 13):
		_create_platform(Vector2i(x, 13), false)
	for x in range(18, 23):
		_create_platform(Vector2i(x, 11), false)
	for y in range(11, 16):
		_create_platform(Vector2i(29, y), false)
	for y in range(min_grid_y, max_grid_y + 1):
		_create_platform(Vector2i(min_grid_x - 1, y), false)
		_create_platform(Vector2i(max_grid_x + 1, y), false)


func _create_platform(grid_position: Vector2i, mutable := true) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = grid_to_world(grid_position)
	add_child(body)

	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(tile_size, tile_size)
	shape.shape = rectangle
	body.add_child(shape)

	var visual := Sprite2D.new()
	visual.texture = platform_texture if mutable else default_platform_texture
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.add_child(visual)
	placed[grid_position] = {"node": body, "item": 0, "mutable": mutable}


func _move_cursor(direction: Vector2i) -> void:
	cursor_active = true
	build_cursor += direction
	build_cursor.x = clampi(build_cursor.x, min_grid_x, max_grid_x)
	build_cursor.y = clampi(build_cursor.y, min_grid_y, max_grid_y)


func _get_target_grid() -> Vector2i:
	if cursor_active:
		return build_cursor
	return world_to_grid(get_global_mouse_position())


func _draw_hologram(grid_position: Vector2i, color: Color) -> void:
	var center := Vector2(grid_position * tile_size) + Vector2(tile_size, tile_size) * 0.5
	var fill := color
	fill.a = 0.28
	if selected_index == 0:
		draw_rect(Rect2(center - Vector2(14, 14), Vector2(28, 28)), fill, true)
	elif selected_index == 1:
		draw_colored_polygon(PackedVector2Array([center + Vector2(-15, 14), center + Vector2(-7, -12), center, center + Vector2(7, -12), center + Vector2(15, 14)]), fill)
	elif selected_index == 2:
		draw_circle(center, 14.0, fill)
		draw_line(center + Vector2(-18, 0), center + Vector2(18, 0), color, 2.0)
		draw_line(center + Vector2(0, -18), center + Vector2(0, 18), color, 2.0)
	elif selected_index == 3:
		draw_colored_polygon(PackedVector2Array([center + Vector2(-16, 14), center + Vector2(-9, -4), center + Vector2(9, -4), center + Vector2(16, 14)]), fill)
	elif selected_index == 4:
		draw_rect(Rect2(center - Vector2(15, 15), Vector2(30, 30)), fill, true)
		draw_line(center + Vector2(-15, -15), center + Vector2(15, 15), color, 2.0)
