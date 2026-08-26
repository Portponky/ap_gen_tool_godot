extends MapTool

signal select_connection(rule: int, connection: int)
signal clear_connection()

var selected_connection := -1

var highlight_rule := -1
var highlight_rule_target := -1
var highlight_connection := -1

var mouse_position: Vector2
var dragging_rule := false
var drawing_connection := false

func render_rules(view: MapView, to_map: Transform2D) -> void:
	super(view, to_map)
	
	view.draw_set_transform_matrix(Transform2D.IDENTITY)
	
	var box_size := to_map.get_scale() * view.RULE_SIZE
	if highlight_rule >= 0:
		var rule: Dictionary = view.rule_cache[highlight_rule]
		var box := Rect2(to_map * rule.pos - 0.5 * box_size, box_size)
		view.draw_rect(box, Color.AQUA, false, 5.0)


func render_connections(view: MapView, to_map: Transform2D) -> void:
	super(view, to_map)
	
	view.draw_set_transform_matrix(Transform2D.IDENTITY)
	
	if selected_connection >= 0:
		var c: Dictionary = view.connection_cache[selected_connection]
		view.draw_line(to_map * c.a, to_map * c.b, Color.RED, 2)
		view.draw_line(to_map * c.b, to_map * (c.b + view.RULE_ARROWHEAD * (c.right - c.forward)), Color.RED, 2)
		view.draw_line(to_map * c.b, to_map * (c.b - view.RULE_ARROWHEAD * (c.right + c.forward)), Color.RED, 2)
	
	if highlight_connection >= 0 and highlight_connection != selected_connection:
		var c: Dictionary = view.connection_cache[highlight_connection]
		view.draw_line(to_map * c.a, to_map * c.b, Color.AQUA, 3)
		view.draw_line(to_map * c.b, to_map * (c.b + view.RULE_ARROWHEAD * (c.right - c.forward)), Color.AQUA, 3)
		view.draw_line(to_map * c.b, to_map * (c.b - view.RULE_ARROWHEAD * (c.right + c.forward)), Color.AQUA, 3)
	
	# draw arrow being drawn
	if drawing_connection:
		var from: Dictionary = view.rule_cache[highlight_rule]
		var a: Vector2 = from.pos
		var b: Vector2 = view.map_coordinate(mouse_position)
		if highlight_rule_target != -1:
			var to: Dictionary = view.rule_cache[highlight_rule_target]
			b = to.pos
		var forward: Vector2 = (b - a).normalized()
		var right := forward.rotated(0.5 * PI)
		a += right * view.RULE_CONNECTION_OFFSET
		if highlight_rule_target != -1:
			b = MapView.clip_line_end(a, b + right * view.RULE_CONNECTION_OFFSET, b, view.RULE_BOUNDARY)
		a = MapView.clip_line_end(b, a, from.pos, view.RULE_BOUNDARY)
		view.draw_line(to_map * a, to_map * b, Color.WHITE, 2)
		view.draw_line(to_map * b, to_map * (b + view.RULE_ARROWHEAD * (right - forward)), Color.WHITE, 2)
		view.draw_line(to_map * b, to_map * (b - view.RULE_ARROWHEAD * (right + forward)), Color.WHITE, 2)


func handle_input(view: MapView, event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if dragging_rule:
			var diff := view.map_coordinate(event.position) - view.map_coordinate(mouse_position) 
			mouse_position = event.position
			view.rule_cache[highlight_rule].pos += diff
			view.rebuild_connection_cache()
			view.queue_redraw()
		elif drawing_connection:
			mouse_position = event.position
			var target = rule_for_position(view, mouse_position)
			if target != highlight_rule:
				highlight_rule_target = target
			view.queue_redraw()
		else:
			do_select_rules_and_connections(view, event.position)
	
	if event is InputEventMouseButton:
		if not dragging_rule and not drawing_connection:
			do_select_rules_and_connections(view, event.position)
			if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and highlight_rule != -1:
				mouse_position = event.position
				dragging_rule = true
				view.queue_redraw()
			elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT and highlight_connection != -1:
				selected_connection = highlight_connection
				var connection: Dictionary = view.connection_cache[selected_connection]
				select_connection.emit(connection.rule_index, connection.connection_index)
				view.queue_redraw()
			elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT and selected_connection != -1:
				selected_connection = -1
				clear_connection.emit()
				view.queue_redraw()
			elif event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and highlight_rule != -1 and highlight_rule != view.rule_cache.size() - 2:
				drawing_connection = true
				mouse_position = event.position
				selected_connection = -1
				clear_connection.emit()
				highlight_rule_target = -1
				view.queue_redraw()
		elif dragging_rule and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			move_rule(view, view.rule_cache[highlight_rule].pos)
			dragging_rule = false
			do_select_rules_and_connections(view, event.position)
			view.queue_redraw()
		elif drawing_connection and not event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			if highlight_rule != -1 and highlight_rule_target != -1:
				draw_new_connection(view)
			drawing_connection = false
			do_select_rules_and_connections(view, event.position)
			view.queue_redraw()


func rule_for_position(view: MapView, screen_pos: Vector2) -> int:
	var doom_coord := view.doom_coordinate(screen_pos)
	for r: int in view.rule_cache.size():
		var rule: Dictionary = view.rule_cache[r]
		var diff: Vector2 = rule.doom_pos - doom_coord
		if absf(diff.x) < 0.5 * view.RULE_SIZE.x and absf(diff.y) < 0.5 * view.RULE_SIZE.y:
			return r
	return -1


func connection_for_position(view: MapView, screen_pos: Vector2) -> int:
	var map_coord := view.map_coordinate(screen_pos)
	for c: int in view.connection_cache.size():
		var connection: Dictionary = view.connection_cache[c]
		
		var diff: Vector2 = map_coord - connection.a
		var param := diff.dot(connection.forward)
		if param < 0 or param > connection.a.distance_to(connection.b):
			continue
		var offline: Vector2 = diff - connection.forward * param 
		if offline.length() > view.RULE_CONNECTION_OFFSET:
			continue
		return c
	
	return -1


func do_select_rules_and_connections(view: MapView, screen_pos: Vector2) -> void:
	var rule := rule_for_position(view, screen_pos)
	if rule != highlight_rule:
		highlight_rule = rule
		highlight_connection = -1
		view.queue_redraw()
	var connection := connection_for_position(view, screen_pos)
	if highlight_rule == -1 and connection != highlight_connection:
		highlight_connection = connection
		view.queue_redraw()


func stop() -> void:
	selected_connection = -1
	clear_connection.emit()
	highlight_rule = -1
	highlight_connection = -1


func can_change() -> bool:
	return not dragging_rule and not drawing_connection


func delete(view: MapView) -> bool:
	if selected_connection != -1:
		delete_selected_connection(view)
		return true
	return false


func set_rule_position(view: MapView, rule: int, x: int, y: int) -> void:
	# Don't get from rule cache, write directly
	var target_rule := view.mapdata_rule_from_index(rule)
	
	target_rule.x = x
	target_rule.y = y
	view.rebuild_rule_cache()
	view.rebuild_connection_cache()
	view.queue_redraw()


func add_connection(view: MapView, from_rule: int, to_rule: int) -> void:
	var target_rule := view.mapdata_rule_from_index(from_rule)
	target_rule.connections.push_back({
		requirements_and = [],
		requirements_or = [],
		target_region = to_rule
	})
	view.rebuild_connection_cache()
	view.queue_redraw()


func remove_connection(view: MapView, from_rule: int, to_rule: int) -> void:
	selected_connection = -1
	clear_connection.emit()
	
	var target_rule := view.mapdata_rule_from_index(from_rule)
	target_rule.connections = target_rule.connections.filter(func(x: Dictionary) -> bool: return x.target_region != to_rule)
	view.rebuild_connection_cache()
	view.queue_redraw()


func set_connection_requirements(view: MapView, from_rule: int, to_rule: int, ands: Array, ors: Array) -> void:
	var target_rule := view.mapdata_rule_from_index(from_rule)
	for connection: Dictionary in target_rule.connections:
		if connection.target_region == to_rule:
			connection.requirements_and = ands
			connection.requirements_or = ors
			break
	
	view.rebuild_connection_cache()
	view.queue_redraw()


func move_rule(view: MapView, map_pos: Vector2) -> void:
	var doom_coord := Vector2(map_pos.x, -map_pos.y)
	var target_rule := view.mapdata_rule_from_index(highlight_rule)
	
	view.undo.create_action("Move rule")
	view.undo.add_do_method(set_rule_position.bind(view, highlight_rule, doom_coord.x, doom_coord.y))
	view.undo.add_undo_method(set_rule_position.bind(view, highlight_rule, target_rule.x, target_rule.y))
	view.undo.commit_action()


func draw_new_connection(view: MapView) -> void:
	if highlight_rule == -1 or highlight_rule_target == -1:
		return
	
	var from_index := view.normalized_rule_index(highlight_rule)
	var to_index := view.normalized_rule_index(highlight_rule_target)
	
	# prevent incorrect exits
	if to_index == -2:
		if from_index == -1: # can't go straight from hub to exit
			return
		# can't multi exit
		for region: Dictionary in view.map_data.regions:
			for connection: Dictionary in region.rules.connections:
				if connection.target_region == -2:
					return
	
	# prevent dupe connections
	var rule: Dictionary = view.rule_cache[highlight_rule].rule
	if rule.connections.any(func(x: Dictionary) -> bool: return x.target_region == to_index):
		return
	
	view.undo.create_action("Create connection")
	view.undo.add_do_method(add_connection.bind(view, from_index, to_index))
	view.undo.add_undo_method(remove_connection.bind(view, from_index, to_index))
	view.undo.commit_action()


func delete_selected_connection(view: MapView) -> void:
	if selected_connection == -1:
		return
	
	var connection: Dictionary = view.connection_cache[selected_connection]
	var raw: Dictionary = connection.connection
	
	var from_index: int = connection.rule_index
	var to_index: int = raw.target_region
	
	view.undo.create_action("Delete connection")
	view.undo.add_do_method(remove_connection.bind(view, from_index, to_index))
	view.undo.add_undo_method(add_connection.bind(view, from_index, to_index))
	view.undo.add_undo_method(set_connection_requirements.bind(view, from_index, to_index, raw.requirements_and, raw.requirements_or))
	view.undo.commit_action()
