extends VBoxContainer

var unreachable_icon := load("res://assets/graphics/unreachable.png")
var check_sanity_icon := load("res://assets/graphics/check-sanity.png")

var thing_cache := {}


func set_world(world: World) -> void:
	for doom_type: int in world.game.check_items:
		var graphic := world.load_graphic(world.game.check_items[doom_type].sprite)
		thing_cache[doom_type] = {
			name = world.game.check_items[doom_type].name,
			icon = graphic
		}



func set_map(map: Map, map_data: Dictionary) -> void:
	%ItemList.clear()
	for l in map_data.locations.size():
		var location: Dictionary = map_data.locations[l]
		var index: int = location.index
		var type := map.things[index].type
		var id: int = %ItemList.add_item(thing_cache[type].name, thing_cache[type].icon.texture)
		
		if location.death_logic:
			%ItemList.set_item_custom_bg_color(id, Color.DARK_RED)
		if location.check_sanity:
			%ItemList.set_item_icon(id, check_sanity_icon)
		if location.unreachable:
			%ItemList.set_item_icon(id, unreachable_icon)
