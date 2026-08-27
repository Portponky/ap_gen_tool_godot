extends MapTool

signal select_location(index: int)
signal clear_location()
signal request_redraw()

var highlight_location := -1

func render_things(view: MapView, to_map: Transform2D) -> void:
	super(view, to_map)
	
	if highlight_location < 0:
		return
	
	view.draw_set_transform_matrix(Transform2D.IDENTITY)
	
	var location: Dictionary = view.map_data.locations[highlight_location]
	var t: int = location.index
	var thing := view.map.things[t]
	var pos := to_map * Vector2(thing.x, -thing.y)
	
	const rect_size := 48.0 * Vector2.ONE
	var rect := Rect2(pos - 0.5 * rect_size, rect_size)
	view.draw_rect(rect, Color.AQUA, false, 3.0)
	
	var font := ThemeDB.fallback_font
	const size := 16
	var thing_id_pos := Vector2(rect.position.x, rect.end.y + font.get_ascent(size))
	view.draw_string(font, thing_id_pos, str(t), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, Color.AQUA)


func handle_input(view: MapView, event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var items := all_items_at(view, event.position)
			if items.is_empty():
				highlight_location = -1
				clear_location.emit()
			else:
				var index := items.find(highlight_location)
				if index == items.size() - 1:
					index = -1
				highlight_location = items[index + 1]
				select_location.emit(highlight_location)
			view.queue_redraw()


func all_items_at(view: MapView, screen_pos: Vector2) -> Array:
	var doom_pos := view.doom_coordinate(screen_pos)
	var result := []
	for l: int in view.map_data.locations.size():
		var location: Dictionary = view.map_data.locations[l]
		var t: int = location.index
		var thing := view.map.things[t]
		var doom_coord := Vector2(thing.x, thing.y)
		if doom_coord.distance_to(doom_pos) < 32.0 / view.zoom:
			result.push_back(l)
	return result


func _on_select_location(index: int) -> void:
	highlight_location = index
	request_redraw.emit()


func _on_clear_location() -> void:
	_on_select_location(-1)
