class_name MapView
extends Control

const RULE_SIZE := Vector2(1024, 400)
const RULE_BOUNDARY := RULE_SIZE + 128.0 * Vector2.ONE
const RULE_CONNECTION_OFFSET := 64.0
const RULE_ARROWHEAD := 32.0
const RULE_REQUIREMENT_SIZE := 96.0

var tool: MapTool
var undo: UndoRedo

var map : Map
var map_data : Dictionary

var zoom := 1.0
var offset := Vector2.ZERO

var mouse_position : Vector2
var mouse_panning := false

var thing_cache := {}
var rule_cache := []
var connection_cache := []


func set_world(world: World) -> void:
	for doom_type: int in world.game.check_items:
		thing_cache[doom_type] = world.load_graphic(world.game.check_items[doom_type].sprite)


func clear_world() -> void:
	map = null
	thing_cache.clear()
	queue_redraw()


func set_map(next_map: Map, next_map_data: Dictionary) -> void:
	map = next_map
	map_data = next_map_data
	
	offset = map.bbox.get_center()
	offset.y = -offset.y
	zoom = min(size.x / map.bbox.size.x, size.y / map.bbox.size.y) * 0.9
	
	rebuild_rule_cache()
	rebuild_connection_cache()
	queue_redraw()


func set_tool(next_tool: MapTool) -> bool:
	if tool == next_tool:
		return true
	if tool and not tool.can_change():
		return false
	
	if tool:
		tool.stop()
	tool = next_tool
	if tool:
		tool.start()
	return true


func _add_to_rule_cache(rule: Dictionary, rule_name: String, color: Color) -> void:
	rule_cache.push_back({
		name = rule_name,
		color = color,
		dim_color = color * Color(1.0, 1.0, 1.0, 0.5),
		rule = rule,
		doom_pos = Vector2(rule.x, rule.y),
		pos = Vector2(rule.x, -rule.y)
	})


func rebuild_rule_cache() -> void:
	rule_cache.clear()
	if not map_data:
		return
	
	for region: Dictionary in map_data.regions:
		_add_to_rule_cache(region.rules, region.name, Color(region.tint[0], region.tint[1], region.tint[2], region.tint[3]))
	_add_to_rule_cache(map_data.exit_rules, "Exit", Color.DIM_GRAY)
	_add_to_rule_cache(map_data.world_rules, "Hub", Color.DIM_GRAY)


# Return a new value for b which intersects the rectangle
static func clip_line_end(a: Vector2, b: Vector2, rect_pos: Vector2, rect_size: Vector2) -> Vector2:
	var relative_b := b - rect_pos
	if relative_b.x > rect_size.x or relative_b.y > rect_size.y:
		return b
	
	var d := b - a
	var s: Vector2 = sign(d)
	var edge := rect_pos - 0.5 * s * rect_size
	
	var hit := (edge - a) / d
	if s.x * (edge.x - a.x) < 0.0 or is_zero_approx(d.x): hit.x = 0.0
	if s.y * (edge.y - a.y) < 0.0 or is_zero_approx(d.y): hit.y = 0.0
	
	return  a + max(hit.x, hit.y) * d


func _add_to_connection_cache(r: int, c: int) -> void:
	var from: Dictionary = rule_cache[r]
	var connection: Dictionary = from.rule.connections[c]
	var to: Dictionary = rule_cache[connection.target_region]
	
	var forward: Vector2 = (to.pos - from.pos).normalized()
	var right := forward.rotated(0.5 * PI)
	var a: Vector2 = from.pos + right * RULE_CONNECTION_OFFSET
	var b: Vector2 = clip_line_end(a, to.pos + right * RULE_CONNECTION_OFFSET, to.pos, RULE_BOUNDARY)
	a = clip_line_end(b, a, from.pos, RULE_BOUNDARY)
	
	var requirements := []
	
	connection_cache.push_back({
		rule_index = normalized_rule_index(r),
		connection_index = c,
		connection = connection,
		a = a,
		b = b,
		forward = forward,
		right = right,
		requirements = requirements
	})
	
	# requirements
	var requirements_count: int = connection.requirements_and.size() + connection.requirements_or.size()
	if requirements_count == 0:
		return
	
	var distance := a.distance_to(b)
	var requirement_length := minf(RULE_REQUIREMENT_SIZE * (requirements_count - 1), distance)
	var requirements_space := 0.5 * (distance - requirement_length)
	
	a += right * RULE_REQUIREMENT_SIZE
	b += right * RULE_REQUIREMENT_SIZE
	var d := (b - a) / distance
	var i := 0
	for type: int in connection.requirements_or:
		requirements.push_back(a + d * (requirements_space + i * RULE_REQUIREMENT_SIZE))
		i += 1
	for type: int in connection.requirements_and:
		requirements.push_back(a + d * (requirements_space + i * RULE_REQUIREMENT_SIZE))
		i += 1


func rebuild_connection_cache() -> void:
	connection_cache.clear()
	if not map_data:
		return
	
	for r: int in rule_cache.size():
		var rule: Dictionary = rule_cache[r]
		for c: int in rule.rule.connections.size():
			_add_to_connection_cache(r, c)


# external changes, flush state
func refresh() -> void:
	rebuild_rule_cache()
	rebuild_connection_cache()
	queue_redraw()


func doom_coordinate(screen_pos: Vector2) -> Vector2:
	var offset_from_center := screen_pos - size / 2
	var doom_coord := offset + offset_from_center / zoom
	doom_coord.y = -doom_coord.y
	return doom_coord


func map_coordinate(screen_pos: Vector2) -> Vector2:
	var doom_coord := doom_coordinate(screen_pos)
	return Vector2(doom_coord.x, -doom_coord.y)


func normalized_rule_index(index: int) -> int:
	if index < map_data.regions.size():
		return index
	if index == map_data.regions.size():
		return -2
	return -1


func mapdata_rule_from_index(index: int) -> Dictionary:
	match normalized_rule_index(index):
		-2: return map_data.exit_rules
		-1: return map_data.world_rules
		_: return map_data.regions[index].rules


func _draw() -> void:
	if not map or not tool:
		return
	
	# Render in map coordinates
	var to_map := Transform2D.IDENTITY.translated(-offset).scaled(zoom * Vector2.ONE).translated(size / 2)
	tool.handle_render(self, to_map)


func _gui_input(event: InputEvent) -> void:
	if not map:
		return
	
	if event is InputEventMouseMotion and mouse_panning:
		do_mouse_pan_motion(event)
	
	if event is InputEventMouseButton:
		do_mouse_pan(event)
		do_wheel_zoom(event)
	
	tool.handle_input(self, event)


func do_mouse_pan_motion(_event: InputEventMouseMotion) -> void:
	var pos := get_global_mouse_position()
	var diff : Vector2 = (pos - mouse_position) / zoom
	offset.x -= diff.x
	offset.y -= diff.y
	queue_redraw()
	mouse_position = pos


func do_mouse_pan(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_MIDDLE:
		return
	
	if event.pressed:
		mouse_position = get_global_mouse_position()
		mouse_panning = true
	elif not event.pressed:
		mouse_panning = false


func do_wheel_zoom(event: InputEventMouseButton) -> void:
	var zoom_factor := 1.0
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		zoom_factor = 1.0 / 0.9
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		zoom_factor = 0.9
	else:
		return
	
	var pre_coord := map_coordinate(event.position)
	zoom *= zoom_factor
	var post_coord := map_coordinate(event.position)
	offset.x += pre_coord.x - post_coord.x
	offset.y += pre_coord.y - post_coord.y
	queue_redraw()
