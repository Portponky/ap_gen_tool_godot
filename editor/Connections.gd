extends VBoxContainer

var map_data: Dictionary

var ands := {}
var ors := {}


func set_world(world: World) -> void:
	clear_world()
	
	for item: Dictionary in world.game.connection_items:
		var doom_type: int = item.doom_type
		var graphic := world.load_graphic(world.game.check_items[doom_type].sprite)
		
		var and_button := Button.new()
		and_button.icon = graphic.texture
		and_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		and_button.expand_icon = true
		and_button.custom_minimum_size = Vector2(0, 32)
		and_button.toggle_mode = true
		%Ands.add_child(and_button)
		ands[doom_type] = and_button
		
		if doom_type > 0:
			var or_button := Button.new()
			or_button.icon = graphic.texture
			or_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			or_button.expand_icon = true
			or_button.custom_minimum_size = Vector2(0, 32)
			or_button.toggle_mode = true
			%Ors.add_child(or_button)
			ors[doom_type] = or_button
	
	clear_connection()


func clear_world() -> void:
	for doom_type: int in ands:
		ands[doom_type].queue_free()
	for doom_type: int in ors:
		ors[doom_type].queue_free()
	
	ands.clear()
	ors.clear()


func set_map_data(next_map_data: Dictionary) -> void:
	map_data = next_map_data


func select_connection(region_index: int, connection_index: int) -> void:
	var rule: Dictionary = map_data.world_rules
	if region_index != -1:
		rule = map_data.regions[region_index].rules
	
	var connection: Dictionary = rule.connections[connection_index]
	
	# if target_region is -2 it should have no options
	for doom_type in ands:
		ands[doom_type].disabled = connection.target_region == -2
		ands[doom_type].set_pressed_no_signal(connection.requirements_and.has(doom_type))
	for doom_type in ors:
		ors[doom_type].disabled = connection.target_region == -2
		ors[doom_type].set_pressed_no_signal(connection.requirements_or.has(doom_type))


func clear_connection() -> void:
	for doom_type in ands:
		ands[doom_type].disabled = true
		ands[doom_type].set_pressed_no_signal(false)
	for doom_type in ors:
		ors[doom_type].disabled = true
		ors[doom_type].set_pressed_no_signal(false)
