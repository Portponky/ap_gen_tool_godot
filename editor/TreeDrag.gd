extends Tree

signal move_item(from: int, to: int)

func _get_drag_data(_at_position: Vector2) -> Variant:
	var item := get_selected()
	if not item:
		return null
	
	var l := Label.new()
	l.text = item.get_text(0)
	set_drag_preview(l)
	
	return item


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	drop_mode_flags = Tree.DROP_MODE_INBETWEEN
	var drop_section := get_drop_section_at_position(at_position)
	if drop_section in [-100, -2, 0]:
		return false
	var item := get_item_at_position(at_position)
	return item != (data as TreeItem)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var drop_section := get_drop_section_at_position(at_position)
	var other_item := get_item_at_position(at_position)
	var item := data as TreeItem
	if item:
		var source := item.get_index()
		var target := other_item.get_index()
		if target > source:
			target -= 1
		if drop_section == 1:
			target += 1
		
		move_item.emit(source, target)
