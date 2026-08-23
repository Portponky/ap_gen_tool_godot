class_name MapView
extends Control

const RULE_SIZE := Vector2(1024, 400)
const RULE_BOUNDARY := RULE_SIZE + 128.0 * Vector2.ONE
const RULE_CONNECTION_OFFSET := 64.0
const RULE_ARROWHEAD := 32.0
const RULE_REQUIREMENT_SIZE := 96.0

enum Mode {
	SectorPaint,
	RuleModify,
	ItemClassify,
	BoundingBox
}

# Come up with correct list of states
enum Action {
	None,
	PaintSector,
	ClearSector,
}

var undo: UndoRedo

var map : Map
var map_data : Dictionary

var zoom := 1.0
var offset := Vector2.ZERO

var mode := Mode.SectorPaint
var action := Action.None

var mouse_dragging := false
var mouse_position : Vector2

var selected_region := -1
var highlight_sector := -1

var thing_cache := {}
var rule_cache := []
var line_cache := []


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
	
	queue_redraw()


func _add_to_rule_cache(rule: Dictionary, rule_name: String, color: Color) -> void:
	rule_cache.push_back({
		name = rule_name,
		color = color,
		dim_color = color * Color(1.0, 1.0, 1.0, 0.5),
		rule = rule,
		pos = Vector2(rule.x, -rule.y)
	})


func rebuild_rule_cache() -> void:
	rule_cache.clear()
	
	for region in map_data.regions:
		_add_to_rule_cache(region.rules, region.name, Color(region.tint[0], region.tint[1], region.tint[2], region.tint[3]))
	_add_to_rule_cache(map_data.exit_rules, "Exit", Color.DIM_GRAY)
	_add_to_rule_cache(map_data.world_rules, "Hub", Color.DIM_GRAY)


# external changes, flush state
func refresh() -> void:
	rebuild_rule_cache()
	queue_redraw()


func doom_coordinate(screen_pos: Vector2) -> Vector2:
	var offset_from_center := screen_pos - size / 2
	var doom_coord := offset + offset_from_center / zoom
	doom_coord.y = -doom_coord.y
	return doom_coord


# Return a new value for b which intersects the rectangle
func _clip_line_end(a: Vector2, b: Vector2, rect_pos: Vector2, rect_size: Vector2) -> Vector2:
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


func _draw() -> void:
	if not map:
		return
	
	# Render in doom coordinates
	var to_map := Transform2D.IDENTITY.translated(-offset).scaled(zoom * Vector2.ONE).translated(size / 2)
	draw_set_transform_matrix(to_map)
	
	# Draw all sectors
	for i: int in map_data.regions.size():
		for s: int in map_data.regions[i].sectors:
			var sector = map.sectors[s]
			if sector.mesh:
				draw_mesh(sector.mesh, null, Transform2D.IDENTITY, rule_cache[i].dim_color)
	
	# Draw linedefs
	for color in map.lines:
		draw_multiline(map.lines[color], color)
	
	# Draw highlighted sector if appropriate
	if highlight_sector >= 0:
		for linedef in map.linedefs.filter(func(x): return x.front_sector == highlight_sector or x.back_sector == highlight_sector):
			var v1 := Vector2(map.vertices[linedef.start_vertex])
			var v2 := Vector2(map.vertices[linedef.end_vertex])
			draw_line(Vector2(v1.x, -v1.y), Vector2(v2.x, -v2.y), Color.AQUA)
	
	# Draw all the things
	draw_set_transform_matrix(Transform2D.IDENTITY)
	for location: Dictionary in map_data.locations:
		var t: int = location.index
		var thing := map.things[t]
		if thing.type in thing_cache:
			var pos := to_map * Vector2(thing.x, -thing.y)
			draw_texture(thing_cache[thing.type].texture, pos - Vector2(thing_cache[thing.type].center))
	
	# Draw rules
	# Connections first
	# Cache as we go for selection
	line_cache.clear()
	for r: int in rule_cache.size():
		var from: Dictionary = rule_cache[r]
		for c: int in from.rule.connections.size():
			var connection: Dictionary= from.rule.connections[c]
			var to: Dictionary = rule_cache[int(connection.target_region)]
			var forward: Vector2 = (to.pos - from.pos).normalized()
			var right := forward.rotated(0.5 * PI)
			var a: Vector2 = from.pos + right * RULE_CONNECTION_OFFSET
			var b: Vector2 = _clip_line_end(a, to.pos + right * RULE_CONNECTION_OFFSET, to.pos, RULE_BOUNDARY)
			a = _clip_line_end(b, a, from.pos, RULE_BOUNDARY)
			
			line_cache.push_back({
				rule_index = r,
				connection_index = c, # no it isn't
				a = a,
				b = b,
				forward = forward
			})
			
			draw_line(to_map * a, to_map * b, Color.WHITE, 1)
			draw_line(to_map * b, to_map * (b + RULE_ARROWHEAD * (right - forward)), Color.WHITE, 1)
			draw_line(to_map * b, to_map * (b - RULE_ARROWHEAD * (right + forward)), Color.WHITE, 1)
			
			# requirements
			var requirements: int = connection.requirements_and.size() + connection.requirements_or.size()
			if requirements == 0:
				continue
			
			var distance := a.distance_to(b)
			var requirement_length := minf(RULE_REQUIREMENT_SIZE * (requirements - 1), distance)
			var requirements_space := 0.5 * (distance - requirement_length)
			
			a += right * RULE_REQUIREMENT_SIZE
			b += right * RULE_REQUIREMENT_SIZE
			var d := (b - a) / distance
			var i := 0
			for type: int in connection.requirements_or:
				if type in thing_cache:
					var pos := to_map * (a + d * (requirements_space + i * RULE_REQUIREMENT_SIZE))
					draw_texture(thing_cache[int(type)].texture, pos - Vector2(thing_cache[int(type)].center))
					i += 1
			for type: int in connection.requirements_and:
				if type in thing_cache:
					var pos := to_map * (a + d * (requirements_space + i * RULE_REQUIREMENT_SIZE))
					draw_texture(thing_cache[int(type)].texture, pos - Vector2(thing_cache[int(type)].center))
					i += 1
	
	# Now boxes
	var box_size := zoom * RULE_SIZE
	const font_size := 128
	var font_vertical_offset := ThemeDB.fallback_font.get_height(font_size) / 2 - ThemeDB.fallback_font.get_descent(font_size)
	for rule in rule_cache:
		var pos = to_map * rule.pos
		var test := Rect2(pos - 0.5 * box_size, box_size)
		draw_rect(test, Color.BLACK)
		draw_rect(test, rule.color, false, 2.0)
		draw_set_transform_matrix(to_map)
		draw_string(ThemeDB.fallback_font, Vector2(rule.pos.x - RULE_SIZE.x / 2, rule.pos.y + font_vertical_offset), rule.name, HORIZONTAL_ALIGNMENT_CENTER, RULE_SIZE.x, font_size, Color.WHITE)
		draw_set_transform_matrix(Transform2D.IDENTITY)


func _gui_input(event: InputEvent) -> void:
	if not map:
		return
	
	if event is InputEventMouseMotion:
		if mouse_dragging:
			do_mouse_pan_motion(event)
		
		if mode == Mode.SectorPaint:
			var doom_coord := doom_coordinate(event.position)
			var sector := map.sector_for_point(doom_coord)
			if sector != highlight_sector:
				highlight_sector = sector
				if action == Action.PaintSector:
					paint_highlighted_sector()
				elif action == Action.ClearSector:
					clear_highlighted_sector()
				queue_redraw()
	
	if event is InputEventMouseButton:
		do_mouse_pan(event)
		do_wheel_zoom(event)
		
		if mode == Mode.SectorPaint:
			if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				action = Action.PaintSector
				paint_highlighted_sector()
			elif event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
				action = Action.ClearSector
				clear_highlighted_sector()
			else:
				action = Action.None


func do_mouse_pan_motion(event: InputEventMouseMotion) -> void:
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
		mouse_dragging = true
		mouse_position = get_global_mouse_position()
	else:
		mouse_dragging = false


func do_wheel_zoom(event: InputEventMouseButton) -> void:
	var zoom_factor := 1.0
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		zoom_factor = 1.0 / 0.9
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		zoom_factor = 0.9
	else:
		return
	
	var pre_coord := doom_coordinate(event.position)
	zoom *= zoom_factor
	var post_coord := doom_coordinate(event.position)
	offset.x += pre_coord.x - post_coord.x
	offset.y -= pre_coord.y - post_coord.y
	queue_redraw()


func add_region_sector(region: int, sector: int) -> void:
	var sectors: Array = map_data.regions[region].sectors
	if not sectors.has(sector):
		sectors.push_back(sector)
		queue_redraw()


func clear_region_sector(region: int, sector: int) -> void:
	var sectors: Array = map_data.regions[region].sectors
	if sectors.has(sector):
		sectors.erase(sector)
		queue_redraw()


func paint_highlighted_sector() -> void:
	if highlight_sector == -1 or selected_region == -1:
		return
	
	if map_data.regions[selected_region].sectors.has(highlight_sector):
		return
	
	undo.create_action("Paint sector")
	for r: int in map_data.regions.size():
		if r == selected_region:
			continue
		var region: Dictionary = map_data.regions[r]
		if region.sectors.has(highlight_sector):
			undo.add_do_method(clear_region_sector.bind(r, highlight_sector))
			undo.add_undo_method(add_region_sector.bind(r, highlight_sector))
	
	undo.add_do_method(add_region_sector.bind(selected_region, highlight_sector))
	undo.add_undo_method(clear_region_sector.bind(selected_region, highlight_sector))
	undo.commit_action()


func clear_highlighted_sector() -> void:
	if highlight_sector == -1 or selected_region == -1:
		return
	
	if not map_data.regions[selected_region].sectors.has(highlight_sector):
		return
	
	undo.create_action("Clear sector")
	undo.add_do_method(clear_region_sector.bind(selected_region, highlight_sector))
	undo.add_undo_method(add_region_sector.bind(selected_region, highlight_sector))
	undo.commit_action()
