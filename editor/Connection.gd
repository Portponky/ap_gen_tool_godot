extends VBoxContainer


func set_world(world: World) -> void:
	# Clear out old buttons (messy)
	for node: Control in %Ands.get_children():
		if node is Button:
			node.queue_free()
	for node: Control in %Ors.get_children():
		if node is Button:
			node.queue_free()
	
	for item: Dictionary in world.game.connection_items:
		var doom_type: int = item.doom_type
		var graphic := world.load_graphic(world.game.check_items[doom_type].sprite)
		
		var and_button := Button.new()
		and_button.icon = graphic.texture
		and_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		and_button.expand_icon = true
		and_button.custom_minimum_size = Vector2(0, 48)
		%Ands.add_child(and_button)
		
		if doom_type > 0:
			var or_button := Button.new()
			or_button.icon = graphic.texture
			or_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			or_button.expand_icon = true
			or_button.custom_minimum_size = Vector2(0, 48)
			%Ors.add_child(or_button)
