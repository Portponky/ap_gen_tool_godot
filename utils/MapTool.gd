class_name MapTool
extends Node


func render_sectors(view: MapView, to_map: Transform2D) -> void:
	view.draw_set_transform_matrix(to_map)
	
	# Draw all sectors
	for i: int in view.map_data.regions.size():
		for s: int in view.map_data.regions[i].sectors:
			var sector = view.map.sectors[s]
			if sector.mesh:
				view.draw_mesh(sector.mesh, null, Transform2D.IDENTITY, view.rule_cache[i].dim_color)
	
	# Draw linedefs
	for color in view.map.lines:
		view.draw_multiline(view.map.lines[color], color)


func render_things(view: MapView, to_map: Transform2D) -> void:
	view.draw_set_transform_matrix(Transform2D.IDENTITY)
	
	# Draw all the things
	for location: Dictionary in view.map_data.locations:
		var t: int = location.index
		var thing := view.map.things[t]
		if thing.type in view.thing_cache:
			var pos := to_map * Vector2(thing.x, -thing.y)
			view.draw_texture(view.thing_cache[thing.type].texture, pos - Vector2(view.thing_cache[thing.type].center))


func render_connections(view: MapView, to_map: Transform2D) -> void:
	view.draw_set_transform_matrix(Transform2D.IDENTITY)
	
	for c: Dictionary in view.connection_cache:
		view.draw_line(to_map * c.a, to_map * c.b, Color.WHITE, 1)
		view.draw_line(to_map * c.b, to_map * (c.b + view.RULE_ARROWHEAD * (c.right - c.forward)), Color.WHITE, 1)
		view.draw_line(to_map * c.b, to_map * (c.b - view.RULE_ARROWHEAD * (c.right + c.forward)), Color.WHITE, 1)
		
		var i := 0
		for type: int in c.connection.requirements_or:
			if type in view.thing_cache:
				view.draw_texture(view.thing_cache[type].texture, to_map * c.requirements[i] - Vector2(view.thing_cache[type].center))
			i += 1
		for type: int in c.connection.requirements_and:
			if type in view.thing_cache:
				view.draw_texture(view.thing_cache[type].texture, to_map * c.requirements[i] - Vector2(view.thing_cache[type].center))
			i += 1


func render_rules(view: MapView, to_map: Transform2D) -> void:
	view.draw_set_transform_matrix(Transform2D.IDENTITY)
	
	var box_size := to_map.get_scale() * view.RULE_SIZE
	const font_size := 128
	var font_vertical_offset := ThemeDB.fallback_font.get_height(font_size) / 2 - ThemeDB.fallback_font.get_descent(font_size)
	for r in view.rule_cache.size():
		var rule: Dictionary = view.rule_cache[r]
		var box := Rect2(to_map * rule.pos - 0.5 * box_size, box_size)
		view.draw_rect(box, Color.BLACK)
		view.draw_rect(box, rule.color, false, 2.0)
		view.draw_set_transform_matrix(to_map)
		view.draw_string(ThemeDB.fallback_font, Vector2(rule.pos.x - view.RULE_SIZE.x / 2, rule.pos.y + font_vertical_offset), rule.name, HORIZONTAL_ALIGNMENT_CENTER, view.RULE_SIZE.x, font_size, Color.WHITE)
		view.draw_set_transform_matrix(Transform2D.IDENTITY)


func render_bounding_boxes(view: MapView, to_map: Transform2D) -> void:
	view.draw_set_transform_matrix(Transform2D.IDENTITY)
	
	for bb: Array in view.map_data.bbs:
		var from := to_map * Vector2(bb[0], -bb[1])
		var to := to_map * Vector2(bb[2], -bb[3])
		
		var color := Color.AQUA
		if bb[4] >= 0:
			color = view.rule_cache[bb[4]].color
		
		var rect := Rect2(from, to - from).abs()
		view.draw_rect(rect, color * Color(1.0, 1.0, 1.0, 0.2), true)
		view.draw_rect(rect, color, false, 2)


func handle_render(view: MapView, to_map: Transform2D) -> void:
	render_sectors(view, to_map)
	render_bounding_boxes(view, to_map)
	render_things(view, to_map)
	render_connections(view, to_map)
	render_rules(view, to_map)


func handle_input(_view: MapView, _event: InputEvent) -> void:
	pass


func start() -> void:
	pass


func stop() -> void:
	pass


func can_change() -> bool:
	return true


func delete(view: MapView) -> bool:
	return false
