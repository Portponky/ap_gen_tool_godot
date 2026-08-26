extends VBoxContainer

signal select_region(index: int)
signal changes

var undo: UndoRedo

var map_data: Dictionary


func _ready() -> void:
	%ColorPopup.size = %ColorPopup.get_child(0).get_combined_minimum_size()
	%AddButton.disabled = true
	%RemoveButton.disabled = true


func create_tree_item(index: int, region: Dictionary) -> void:
	var root: TreeItem = %Tree.get_root()
	var item: TreeItem = %Tree.create_item(root, index)
	item.set_text(0, region.name)
	item.add_button(0, load("res://assets/graphics/white-24.png"), index)
	var color := Color(region.tint[0], region.tint[1], region.tint[2], region.tint[3])
	item.set_button_color(0, 0, color)


func set_map_data(next_map_data: Dictionary) -> void:
	map_data = next_map_data
	
	%Tree.clear()
	%Tree.create_item()
	for r in map_data.regions.size():
		var region: Dictionary = map_data.regions[r]
		create_tree_item(r, region)
	
	select_region.emit(-1)
	
	%AddButton.disabled = false
	%RemoveButton.disabled = false


func clear_world() -> void:
	%Tree.clear()
	%AddButton.disabled = true
	%RemoveButton.disabled = true


func _on_tree_item_selected() -> void:
	var selected: TreeItem = %Tree.get_selected()
	select_region.emit(selected.get_index() if selected else -1)


func set_selected_region(index: int) -> void:
	if index == -1:
		%Tree.deselect_all()
	else:
		var root: TreeItem = %Tree.get_root()
		%Tree.set_selected(root.get_child(index), 0)


func add_region(region: Dictionary) -> void:
	create_tree_item(map_data.regions.size(), region)
	map_data.regions.push_back(region)
	changes.emit()


func remove_last_region() -> void:
	var root: TreeItem = %Tree.get_root()
	root.remove_child(root.get_child(-1))
	map_data.regions.pop_back()
	
	# selection may have changed as a consequence
	_on_tree_item_selected()
	changes.emit()


func swap_regions(first: int, second: int) -> void:
	if first == second or first < 0 or first >= map_data.regions.size() or second < 0 or second >= map_data.regions.size():
		return
	
	# rewire all connections first <-> second
	for region: Dictionary in map_data.regions:
		for connection: Dictionary in region.rules.connections:
			if connection.target_region == first:
				connection.target_region = second
			elif connection.target_region == second:
				connection.target_region = first
	for connection: Dictionary in map_data.world_rules.connections:
		if connection.target_region == first:
			connection.target_region = second
		elif connection.target_region == second:
			connection.target_region = first
	
	var temp: Dictionary = map_data.regions[first]
	map_data.regions[first] = map_data.regions[second]
	map_data.regions[second] = temp
	
	# update tree items
	var root: TreeItem = %Tree.get_root()
	for i in [first, second]:
		var item: TreeItem = root.get_child(i)
		var region: Dictionary = map_data.regions[i]
		item.set_text(0, region.name)
		var color := Color(region.tint[0], region.tint[1], region.tint[2], region.tint[3])
		item.set_button_color(0, 0, color)
	changes.emit()


func apply_connections(index: int, connections: Array) -> void:
	if index == -1:
		map_data.world_rules.connections = connections
	else:
		map_data.regions[index].rules.connections = connections
	changes.emit()


func apply_bounding_boxes(bbs: Array) -> void:
	map_data.bbs = bbs
	changes.emit()


func _on_add_button_pressed() -> void:
	# no duplicate names
	for region: Dictionary in map_data.regions:
		if region.name == %RegionName.text:
			return
	
	var target: String = %RegionName.text
	var color := Color.from_string(target.to_lower(), Color.WHITE)
	%RegionName.text = ""
	
	var region := {
		name = target,
		tint = [color.r, color.g, color.b, color.a],
		sectors = [],
		rules = {
			connections = [],
			x = 0,
			y = 0
		}
	}
	
	undo.create_action("Add region")
	undo.add_do_method(add_region.bind(region))
	undo.add_undo_method(remove_last_region)
	undo.commit_action()


func _on_remove_button_pressed() -> void:
	var selection = %Tree.get_selected()
	if not selection:
		return
	
	var index: int = selection.get_index()
	
	undo.create_action("Remove region")
	
	var target_region: Dictionary = map_data.regions[index]
	
	# fix up all bounding boxes
	var cleared_bbs = map_data.bbs.duplicate(true).filter(func(x: Array) -> bool: return x[4] != index)
	for bb: Array in cleared_bbs:
		if bb[4] > index:
			bb[4] -= 1
	if cleared_bbs != map_data.bbs:
		undo.add_do_method(apply_bounding_boxes.bind(cleared_bbs))
	
	# undo: replace region
	undo.add_undo_method(add_region.bind(target_region))
	for i in range(map_data.regions.size() - 1, index, -1):
		undo.add_undo_method(swap_regions.bind(i - 1, i))
	
	# modify all connections
	for r in map_data.regions.size():
		var region: Dictionary = map_data.regions[r]
		var stripped: Array = region.rules.connections.filter(func(x: Dictionary) -> bool: return x.target_region != index)
		if stripped.size() == region.rules.connections.size():
			continue
		
		undo.add_do_method(apply_connections.bind(r, stripped))
		undo.add_undo_method(apply_connections.bind(r, region.rules.connections))
	
	var world_stripped: Array = map_data.world_rules.connections.filter(func(x: Dictionary) -> bool: return x.target_region != index)
	if world_stripped.size() != map_data.world_rules.connections.size():
		undo.add_do_method(apply_connections.bind(-1, world_stripped))
		undo.add_undo_method(apply_connections.bind(-1, map_data.world_rules.connections))
	
	# shuffle to end and eliminate
	for i in range(index, map_data.regions.size() - 1):
		undo.add_do_method(swap_regions.bind(i, i + 1))
	undo.add_do_method(remove_last_region)
	
	if cleared_bbs != map_data.bbs:
		undo.add_undo_method(apply_bounding_boxes.bind(map_data.bbs))
	
	undo.commit_action()


func set_region_color(index: int, color: Color) -> void:
	var tint := [
		color.r,
		color.g,
		color.b,
		color.a
	]

	map_data.regions[index].tint = tint
	%Tree.get_root().get_child(index).set_button_color(0, 0, color)
	changes.emit()


func _on_set_region_color(index: int) -> void:
	var region: Dictionary = map_data.regions[index]
	var old_color := Color(region.tint[0], region.tint[1], region.tint[2], region.tint[3])
	%ColorPopup.hide()
	
	undo.create_action("Set region color")
	undo.add_do_method(set_region_color.bind(index, %ColorPicker.color))
	undo.add_undo_method(set_region_color.bind(index, old_color))
	undo.commit_action()


func _on_tree_button_clicked(_item: TreeItem, _column: int, id: int, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_LEFT:
		return
	
	# id is index
	var region: Dictionary = map_data.regions[id]
	var color := Color(region.tint[0], region.tint[1], region.tint[2], region.tint[3])
	
	%ColorPicker.color = color
	%ColorPopup.popup()
	%AcceptButton.pressed.connect(_on_set_region_color.bind(id), CONNECT_ONE_SHOT)


func _on_color_popup_close_requested() -> void:
	%ColorPopup.hide()
	for c: Dictionary in %AcceptButton.pressed.get_connections():
		%AcceptButton.pressed.disconnect(c.callable)
