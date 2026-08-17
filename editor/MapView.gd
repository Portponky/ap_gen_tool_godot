extends Control

var map : Map
var map_data : Dictionary

var zoom := 1.0
var offset := Vector2.ZERO

var mouse_dragging := false
var mouse_position : Vector2
var highlight_sector := -1

var cached_things := {}


func set_world(world: World) -> void:
	for item: Dictionary in world.game.ap_doom_types:
		cached_things[int(item.doom_type)] = world.load_graphic(item.sprite)


func set_map(next_map: Map, next_map_data: Dictionary) -> void:
	map = next_map
	map_data = next_map_data
	
	offset = map.bbox.get_center()
	offset.y = -offset.y
	zoom = min(size.x / map.bbox.size.x, size.y / map.bbox.size.y) * 0.9
	
	queue_redraw()



func _draw() -> void:
	if not map:
		return
	
	var to_map := Transform2D.IDENTITY.translated(-offset).scaled(zoom * Vector2.ONE).translated(size / 2)
	draw_set_transform_matrix(to_map)
	
	for region: Dictionary in map_data.regions:
		var color := Color(region.tint[0], region.tint[1], region.tint[2], 0.5 * region.tint[3])
		for s: int in region.sectors:
			var sector = map.sectors[s]
			if sector.mesh:
				draw_mesh(sector.mesh, null, Transform2D.IDENTITY, color)
	
	for color in map.lines:
		draw_multiline(map.lines[color], color)
	
	if highlight_sector >= 0:
		for linedef in map.linedefs.filter(func(x): return x.front_sector == highlight_sector or x.back_sector == highlight_sector):
			var v1 := Vector2(map.vertices[linedef.start_vertex])
			var v2 := Vector2(map.vertices[linedef.end_vertex])
			draw_line(Vector2(v1.x, -v1.y), Vector2(v2.x, -v2.y), Color.AQUA)
	
	draw_set_transform_matrix(Transform2D.IDENTITY)
	for thing in map.things:
		if thing.flags & Map.Thing.Flags.Multiplayer:
			continue
		if thing.type in cached_things:
			var pos := to_map * Vector2(thing.x, -thing.y)
			draw_texture(cached_things[thing.type].texture, pos - Vector2(cached_things[thing.type].center))


func _gui_input(event: InputEvent) -> void:
	if not map:
		return
	
	if event is InputEventMouseMotion:
		if mouse_dragging:
			var pos := get_global_mouse_position()
			var diff : Vector2 = (pos - mouse_position) / zoom
			offset.x -= diff.x
			offset.y -= diff.y
			queue_redraw()
			mouse_position = pos
		if not mouse_dragging:
			var doom_coord := doom_coordinate(event.position)
			highlight_sector = map.sector_for_point(doom_coord)
			queue_redraw()
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
			mouse_dragging = true
			mouse_position = get_global_mouse_position()
		if not event.pressed:
			mouse_dragging = false
		
		var zoom_factor := 1.0
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_factor = 1.0 / 0.9
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_factor = 0.9
		
		if zoom_factor != 1.0:
			var pre_coord := doom_coordinate(event.position)
			zoom *= zoom_factor
			var post_coord := doom_coordinate(event.position)
			offset.x += pre_coord.x - post_coord.x
			offset.y -= pre_coord.y - post_coord.y
		
		queue_redraw()


func doom_coordinate(screen_pos: Vector2) -> Vector2:
	var offset_from_center := screen_pos - size / 2
	var doom_coord := offset + offset_from_center / zoom
	doom_coord.y = -doom_coord.y
	return doom_coord
