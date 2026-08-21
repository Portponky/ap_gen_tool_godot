extends VBoxContainer

func set_map_data(map_data: Dictionary) -> void:
	%Tree.clear()
	var root: TreeItem = %Tree.create_item()
	for r in map_data.regions.size():
		var region: Dictionary = map_data.regions[r]
		var item: TreeItem = %Tree.create_item(root, r)
		item.set_text(0, region.name)
		item.add_button(0, load("res://assets/graphics/white-24.png"), r)
		var color := Color(region.tint[0], region.tint[1], region.tint[2], region.tint[3])
		item.set_button_color(0, 0, color)


func clear_world() -> void:
	%Tree.clear()
