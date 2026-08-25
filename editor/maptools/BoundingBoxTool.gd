extends MapTool

var bb_cache := []
var bb_cache_dirty = true

var selected_region := -1
var selected_bbox := -1
var highlight_bbox := -1

var mouse_position: Vector2
var draw_origin : Vector2
var dragging_box := false
var drawing_box := false
var resizing_axis := -1

func _on_regions_select_region(index: int) -> void:
	selected_region = index


func _on_regions_changes() -> void:
	bb_cache_dirty = true


func rebuild_bb_cache(view: MapView) -> void:
	bb_cache.clear()
	for bb: Array in view.map_data.bbs:
		var from := Vector2(bb[0], -bb[1])
		var to := Vector2(bb[2], -bb[3])
		
		var color := Color.AQUA
		if bb[4] >= 0:
			color = view.rule_cache[bb[4]].color
		
		bb_cache.push_back({
			rect = Rect2(from, to - from).abs(),
			color = color
		})
	bb_cache_dirty = false


func render_bounding_boxes(view: MapView, to_map: Transform2D) -> void:
	view.draw_set_transform_matrix(Transform2D.IDENTITY)
	for b: int in bb_cache.size():
		var bb: Dictionary = bb_cache[b]
		var color: Color = bb.color
		var thickness := 2
		if b == selected_bbox:
			color = Color.RED
			thickness = 3
		elif b == highlight_bbox:
			color = Color.AQUA
			thickness = 2
		var rect: Rect2 = to_map * bb.rect
		view.draw_rect(rect, bb.color * Color(1.0, 1.0, 1.0, 0.2), true)
		view.draw_rect(rect, color, false, thickness)
	
	if drawing_box:
		var rect := Rect2(draw_origin, mouse_position - draw_origin).abs()
		view.draw_rect(rect, Color.AQUA * Color(1.0, 1.0, 1.0, 0.2), true)
		view.draw_rect(rect, Color.AQUA, false, 4)


func handle_render(view: MapView, to_map: Transform2D) -> void:
	if bb_cache_dirty:
		rebuild_bb_cache(view)
	super(view, to_map)


func handle_input(view: MapView, event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if dragging_box:
			var diff: Vector2 = (event.position - mouse_position) / view.zoom
			match resizing_axis:
				-1:
					bb_cache[selected_bbox].rect.position += diff
				0:
					bb_cache[selected_bbox].rect.position.x += diff.x
					bb_cache[selected_bbox].rect.size.x -= diff.x
				1:
					bb_cache[selected_bbox].rect.position.y += diff.y
					bb_cache[selected_bbox].rect.size.y -= diff.y
				2:
					bb_cache[selected_bbox].rect.size.x += diff.x
				3:
					bb_cache[selected_bbox].rect.size.y += diff.y
			mouse_position = event.position
			view.queue_redraw()
		elif drawing_box:
			mouse_position = event.position
			view.queue_redraw()
		else:
			var box := bounding_box_at_position(view, event.position)
			if box != highlight_bbox:
				highlight_bbox = box
				view.queue_redraw()
	
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not drawing_box:
			if highlight_bbox == selected_bbox:
				# modify existing box
				dragging_box = true
				resizing_axis = edge_index_for_box(view, event.position, selected_bbox)
				mouse_position = event.position
			else:
				# select box
				selected_bbox = highlight_bbox
			view.queue_redraw()
		elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and dragging_box:
			apply_drag_box_position(view)
			dragging_box = false
		elif event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and not dragging_box and selected_region != -1:
			drawing_box = true
			draw_origin = event.position
			mouse_position = event.position
			view.queue_redraw()
		elif not event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and drawing_box:
			create_new_bounding_box(view)
			drawing_box = false


func bounding_box_at_position(view: MapView, screen_pos: Vector2) -> int:
	# calculate a bit of additional screen size, 16 pixels
	var map_pos := view.map_coordinate(screen_pos)
	var bonus := 16.0 / view.zoom
	for b: int in bb_cache.size():
		var bb: Dictionary = bb_cache[b]
		if bb.rect.abs().grow(bonus).has_point(map_pos):
			return b
	
	return -1


func edge_index_for_box(view: MapView, screen_pos: Vector2, box_index: int) -> int:
	# x0 y1 x2 y3
	var map_pos := view.map_coordinate(screen_pos)
	var similarity := 16.0 / view.zoom
	var box: Dictionary = bb_cache[box_index]
	if abs(map_pos.x - box.rect.position.x) < similarity:
		return 0
	if abs(map_pos.y - box.rect.position.y) < similarity:
		return 1
	if abs(map_pos.x - box.rect.end.x) < similarity:
		return 2
	if abs(map_pos.y - box.rect.end.y) < similarity:
		return 3
	return -1


func start() -> void:
	bb_cache_dirty = true


func can_change() -> bool:
	return not dragging_box and not drawing_box


func delete(view: MapView) -> bool:
	if selected_bbox == -1:
		return false
	
	delete_bounding_box(view)
	selected_bbox = -1
	return true


func set_bounding_box(view: MapView, index: int, x0: int, y0: int, x1: int, y1: int) -> void:
	view.map_data.bbs[index][0] = x0
	view.map_data.bbs[index][1] = y0
	view.map_data.bbs[index][2] = x1
	view.map_data.bbs[index][3] = y1
	bb_cache_dirty = true
	view.queue_redraw()


func add_new_bounding_box(view: MapView, region: int) -> void:
	view.map_data.bbs.push_back([0, 0, 0, 0, region])
	bb_cache_dirty = true
	view.queue_redraw()


func remove_last_bounding_box(view: MapView) -> void:
	view.map_data.bbs.pop_back()
	bb_cache_dirty = true
	view.queue_redraw()


func swap_with_last_bounding_box(view: MapView, index: int) -> void:
	var last: int = view.map_data.bbs.size() - 1
	if index != last:
		var temp = view.map_data.bbs[index]
		view.map_data.bbs[index] = view.map_data.bbs[last]
		view.map_data.bbs[last] = temp
	bb_cache_dirty = true
	view.queue_redraw()


func apply_drag_box_position(view: MapView) -> void:
	var box: Dictionary = bb_cache[selected_bbox]
	var rect: Rect2 = box.rect.abs()
	var bb: Array = view.map_data.bbs[selected_bbox]
	
	view.undo.create_action("Resize bounding box")
	view.undo.add_do_method(set_bounding_box.bind(view, selected_bbox, rect.position.x, -rect.end.y, rect.end.x, -rect.position.y))
	view.undo.add_undo_method(set_bounding_box.bind(view, selected_bbox, bb[0], bb[1], bb[2], bb[3]))
	view.undo.commit_action()


func create_new_bounding_box(view: MapView) -> void:
	var a := view.doom_coordinate(draw_origin)
	var b := view.doom_coordinate(mouse_position)
	var rect := Rect2(a, b - a).abs()
	
	view.undo.create_action("Create bounding box")
	view.undo.add_do_method(add_new_bounding_box.bind(view, selected_region))
	view.undo.add_do_method(set_bounding_box.bind(view, view.map_data.bbs.size(), rect.position.x, rect.position.y, rect.end.x, rect.end.y))
	view.undo.add_undo_method(remove_last_bounding_box.bind(view))
	view.undo.commit_action()


func delete_bounding_box(view: MapView) -> void:
	if selected_bbox == -1:
		return
	
	var bb: Array = view.map_data.bbs[selected_bbox]
	
	view.undo.create_action("Delete bounding box")
	view.undo.add_do_method(swap_with_last_bounding_box.bind(view, selected_bbox))
	view.undo.add_do_method(remove_last_bounding_box.bind(view))
	view.undo.add_undo_method(add_new_bounding_box.bind(view, bb[4]))
	view.undo.add_undo_method(swap_with_last_bounding_box.bind(view, selected_bbox))
	view.undo.add_undo_method(set_bounding_box.bind(view, selected_bbox, bb[0], bb[1], bb[2], bb[3]))
	view.undo.commit_action()
