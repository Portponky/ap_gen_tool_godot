extends VBoxContainer

signal select_location(index: int)
signal focus_on(doom_coord: Vector2)
signal changes()

var unreachable_icon := load("res://assets/graphics/unreachable.png")
var check_sanity_icon := load("res://assets/graphics/check-sanity.png")
var ap_location_icon := load("res://assets/graphics/ap.png")

var undo: UndoRedo

var thing_cache := {}
var map: Map
var map_data: Dictionary


func set_world(world: World) -> void:
	for doom_type: int in world.game.check_items:
		var graphic := world.load_graphic(world.game.check_items[doom_type].sprite)
		thing_cache[doom_type] = {
			name = world.game.check_items[doom_type].name,
			icon = graphic
		}


func clear_world() -> void:
	%ItemList.clear()
	thing_cache.clear()


func style_item_list(index: int) -> void:
	var location: Dictionary = map_data.locations[index]
	if location.death_logic:
		%ItemList.set_item_custom_bg_color(index, Color.DARK_RED)
	else:
		%ItemList.set_item_custom_bg_color(index, Color.TRANSPARENT)
	
	if location.unreachable:
		%ItemList.set_item_icon(index, unreachable_icon)
	elif location.check_sanity:
		%ItemList.set_item_icon(index, check_sanity_icon)
	else:
		var map_index: int = location.index
		var thing := map.things[map_index]
		if Settings.locations_as_aps and World.is_in_region(map, map_data, Vector2(thing.x, thing.y)) and not location.name.is_empty():
			%ItemList.set_item_icon(index, ap_location_icon)
		else:
			var doom_type := thing.type
			%ItemList.set_item_icon(index, thing_cache[doom_type].icon.texture)
	
	if location.name.is_empty():
		var map_index: int = location.index
		var doom_type := map.things[map_index].type
		%ItemList.set_item_text(index, thing_cache[doom_type].name)
	else:
		%ItemList.set_item_text(index, location.name)


func set_map(next_map: Map, next_map_data: Dictionary) -> void:
	map = next_map
	map_data = next_map_data
	
	select_location.emit(-1)
	%ItemList.clear()
	for l in map_data.locations.size():
		var id: int = %ItemList.add_item("")
		style_item_list(id)


func refresh() -> void:
	for i in map_data.locations.size():
		style_item_list(i)
	update_entry_for_selection()


func update_entry_for_selection() -> void:
	var selection := selected_index()
	var enabled = selection != -1
	%CheckSanity.disabled = not enabled
	%Unreachable.disabled = not enabled
	%DeathLogic.disabled = not enabled
	%Name.editable = enabled
	
	if selection != -1:
		var location: Dictionary = map_data.locations[selection]
		%CheckSanity.set_pressed_no_signal(location.check_sanity)
		%Unreachable.set_pressed_no_signal(location.unreachable)
		%DeathLogic.set_pressed_no_signal(location.death_logic)
		%Name.text = location.name
	else:
		%CheckSanity.set_pressed_no_signal(false)
		%Unreachable.set_pressed_no_signal(false)
		%DeathLogic.set_pressed_no_signal(false)
		%Name.text = ""


func _on_item_list_item_selected(index: int) -> void:
	update_entry_for_selection()
	select_location.emit(index)


func _on_item_list_item_activated(index: int) -> void:
	var location: Dictionary = map_data.locations[index]
	var t: int = location.index
	var thing := map.things[t]
	focus_on.emit(Vector2(thing.x, thing.y))


func _on_select_location(index: int) -> void:
	%ItemList.select(index)
	%ItemList.ensure_current_is_visible()
	update_entry_for_selection()


func _on_clear_location() -> void:
	%ItemList.deselect_all()
	update_entry_for_selection()


func _on_location_dependencies_changed() -> void:
	if Settings.locations_as_aps:
		refresh()


func selected_index() -> int:
	var selected: Array = %ItemList.get_selected_items()
	if selected.size() == 1:
		return selected[0]
	return -1


func set_location_flags(index: int, check_sanity: bool, unreachable: bool, death_logic: bool) -> void:
	var location: Dictionary = map_data.locations[index]
	location.check_sanity = check_sanity
	location.unreachable = unreachable
	location.death_logic = death_logic
	style_item_list(index)
	if index == selected_index():
		%CheckSanity.set_pressed_no_signal(check_sanity)
		%Unreachable.set_pressed_no_signal(unreachable)
		%DeathLogic.set_pressed_no_signal(death_logic)
	
	changes.emit()


func _on_check_sanity_toggled(on: bool) -> void:
	var selected := selected_index()
	if selected == -1:
		return
	
	var location: Dictionary = map_data.locations[selected]
	
	undo.create_action("Set check sanity")
	undo.add_do_method(set_location_flags.bind(selected, on, location.unreachable, location.death_logic))
	undo.add_undo_method(set_location_flags.bind(selected, not on, location.unreachable, location.death_logic))
	undo.commit_action()


func _on_unreachable_toggled(on: bool) -> void:
	var selected := selected_index()
	if selected == -1:
		return
	
	var location: Dictionary = map_data.locations[selected]
	
	undo.create_action("Set unreachable")
	undo.add_do_method(set_location_flags.bind(selected, location.check_sanity, on, location.death_logic))
	undo.add_undo_method(set_location_flags.bind(selected, location.check_sanity, not on, location.death_logic))
	undo.commit_action()


func _on_death_logic_toggled(on: bool) -> void:
	var selected := selected_index()
	if selected == -1:
		return
	
	var location: Dictionary = map_data.locations[selected]
	
	undo.create_action("Set death logic")
	undo.add_do_method(set_location_flags.bind(selected, location.check_sanity, location.unreachable, on))
	undo.add_undo_method(set_location_flags.bind(selected, location.check_sanity, location.unreachable, not on))
	undo.commit_action()


func set_location_name(index: int, location_name: String) -> void:
	var location: Dictionary = map_data.locations[index]
	location.name = location_name
	style_item_list(index)
	if index == selected_index():
		%Name.text = location_name
	
	changes.emit()


func _on_name_text_submitted(new_text: String) -> void:
	var selected := selected_index()
	if selected == -1:
		return
	
	var location: Dictionary = map_data.locations[selected]
	
	undo.create_action("Set name")
	undo.add_do_method(set_location_name.bind(selected, new_text))
	undo.add_undo_method(set_location_name.bind(selected, location.name))
	undo.commit_action()
