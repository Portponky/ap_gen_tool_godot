class_name World
extends Resource

var game: Dictionary
var data: Dictionary
var wads: Array[Wad]
var palette: Array[Color]
var maps: Dictionary[String, Map]

func populate_default_data() -> void:
	Status.set_task("Populating default data")
	
	# ensure maps structure exists
	var data_maps: Array = data.get_or_add("maps", [])
	
	var i := 0
	for e: int in game.episodes.size():
		var episode: Dictionary = game.episodes[e]
		for m: int in episode.maps.size():
			var map: Dictionary = episode.maps[m]
			
			if data_maps.size() <= i:
				data_maps.push_back({
					regions = [],
					bbs = [],
					locations = [],
					world_rules = {
						connections = [],
						x = 0,
						y = 0
					},
					exit_rules = {
						connections = [],
						x = 0,
						y = 0
					}
				})
			
			var target: Dictionary = data_maps[i]
			target._lump = map.lump
			target.ep = e
			target.map = m
			
			var locations_by_thing := {}
			for location in target.locations:
				locations_by_thing[int(location.index)] = location
			
			target.locations.clear()
			for t: int in maps[map.lump].things.size():
				var thing := maps[map.lump].things[t] 
				if thing.flags & Map.Thing.Flags.Multiplayer:
					continue
				if not game.check_items.has(thing.type):
					continue
				
				if locations_by_thing.has(t):
					target.locations.append(locations_by_thing[t])
				else:
					target.locations.append({
						index = t,
						name = "",
						description = "",
						check_sanity = false,
						death_logic = false,
						unreachable = false
					})
			
			i += 1
	
	# ensure region sectors are integers
	# ensure target_regions are integers
	for map: Dictionary in data.maps:
		for region: Dictionary in map.regions:
			region.sectors = region.sectors.map(func(x: float) -> int: return int(x))
			for connection: Dictionary in region.rules.connections:
				connection.target_region = int(connection.target_region)
		for connection: Dictionary in map.world_rules.connections:
			connection.target_region = int(connection.target_region)


static func attempt_load_json(path: String) -> Dictionary:
	Status.set_task("Loading %s" % path.get_file())
	
	var string := FileAccess.get_file_as_string(path)
	if string.is_empty():
		Status.add_error("Unable to read file %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return {}
	var json := JSON.new()
	if json.parse(string) != OK:
		Status.add_error("Error parsing %s at line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	
	return json.data


static func load_palette(world: World) -> bool:
	Status.set_task("Loading palette")
	var wad := world.wad_for_lump("PLAYPAL")
	if not wad:
		Status.add_error("No wads have a PLAYPAL lump, cannot load palette")
		return false
	
	world.palette.clear()
	var playpal := wad.load_lump("PLAYPAL")
	for i in 256:
		var r := playpal.decode_u8(3 * i + 0)
		var g := playpal.decode_u8(3 * i + 1)
		var b := playpal.decode_u8(3 * i + 2)
		world.palette.push_back(Color.from_rgba8(r, g, b))
	
	return true


static func enforce_array(world_game: Dictionary, key: String) -> void:
	world_game.get_or_add(key, [])
	if not world_game[key] is Array:
		world_game[key] = [world_game[key]]


static func load_and_merge(world_game: Dictionary, host: String, all_defaults: Dictionary) -> void:
	if not world_game.iwad in all_defaults:
		print("Unable to load defaults into %s for iwad %s", host, world_game.iwad)
		return
	
	var iwad_defaults := all_defaults[world_game.iwad] as Dictionary
	var target := world_game.get_or_add(host, {}) as Dictionary
	for key: String in iwad_defaults:
		if key in target:
			continue
		target[key] = iwad_defaults[key]


static func load(gamename: String) -> World:
	Status.reset()
	
	var world := World.new()
	Status.set_task("Loading %s game files" % gamename)
	var path := "res://" if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()
	world.game = attempt_load_json("%s/games/%s.game.json" % [path, gamename])
	world.data = attempt_load_json("%s/data/%s.data.json" % [path, gamename])
	if not world.game:
		Status.add_error("Game json not present")
		return null
	
	if not world.game.has("iwad"):
		Status.add_error("No iwad specified in game json")
		return null
	
	Status.set_task("Verifying game json")
	enforce_array(world.game, "required_wads")
	enforce_array(world.game, "included_wads")
	enforce_array(world.game, "optional_wads")
	enforce_array(world.game, "authors")
	world.game.get_or_add("world_info", {})
	enforce_array(world.game.world_info, "description")
	
	var all_wads := [world.game.iwad]
	all_wads.append_array(world.game.required_wads)
	all_wads.append_array(world.game.included_wads)
	
	for wadname: String in all_wads:
		Status.set_task("Loading wad %s" % wadname)
		var wad := Wad.load("%s/wads/%s" % [path, wadname])
		if not wad:
			Status.add_error("Unable to load wad %s" % wadname)
			return null
		world.wads.push_front(wad)
	
	if not load_palette(world):
		return null
	
	for episode: Dictionary in world.game.episodes:
		for map: Dictionary in episode.maps:
			Status.set_task("Loading map for lump %s" % map.lump)
			world.maps[map.lump] = Map.load(world, map.lump)
	
	for lump: String in world.game.get("map_tweaks", {}):
		Status.set_task("Applying map tweaks for %s" % lump)
		world.maps[lump].apply_map_tweaks(world.game.map_tweaks[lump])
	
	Status.set_task("Merging default settings for iwad")
	load_and_merge(world.game, "game_info", Default.game_info)
	load_and_merge(world.game, "location_doom_types", Default.locations)
	load_and_merge(world.game, "items", Default.items)
	load_and_merge(world.game, "world_info", Default.world_info)
	
	Status.set_task("Assigning default settings for iwad")
	
	# Ensure weird items are present
	world.game.items.get_or_add("unique_progression", [])
	world.game.items.get_or_add("unique_useful", [])
	world.game.items.get_or_add("unique_filler", [])
	
	# Extra things that are required
	# Used in connection generation
	world.game.connection_items = []
	world.game.connection_items.append_array(world.game.items.extra_connection_requirements)
	world.game.connection_items.append_array(world.game.items.progression)
	world.game.connection_items.append_array(world.game.items.unique_progression)
	world.game.connection_items.append_array(world.game.items.keys)
	
	# Used by energy link shop
	world.game.common_items = []
	world.game.common_items.append_array(world.game.items.progression)
	world.game.common_items.append_array(world.game.items.useful)
	world.game.common_items.append_array(world.game.items.filler)
	
	# Used by type sprites
	world.game.all_items = []
	world.game.all_items.append_array(world.game.common_items)
	world.game.all_items.append_array(world.game.items.unique_progression)
	world.game.all_items.append_array(world.game.items.unique_useful)
	world.game.all_items.append_array(world.game.items.unique_filler)
	world.game.all_items.append_array(world.game.items.keys)
	
	world.game.check_items = {}
	for item: Dictionary in world.game.all_items:
		if item.get("count", 1.0) == 0.0:
			continue
		if item.has("group") and "Junk" in item.group:
			continue
		world.game.check_items[int(item.doom_type)] = item
	for item: Dictionary in world.game.items.extra_connection_requirements:
		world.game.check_items[int(item.doom_type)] = item
	
	world.game.get_or_add("ap_name", "Unnamed id1 Game")
	world.game.get_or_add("ap_world_name", "id1_game")
	world.game.get_or_add("ap_class_name", "id1Game")
	world.game.get_or_add("full_name", world.game.ap_name)
	world.game.get_or_add("settings", {})
	
	world.game.get_or_add("check_sanity", false)
	
	world.populate_default_data()
	
	return world


func wad_for_lump(lump_name: String) -> Wad:
	for wad in wads:
		if wad.has_lump(lump_name):
			return wad
	return null


func load_graphic(lump_name: String) -> Dictionary:
	var wad := wad_for_lump(lump_name)
	if not wad:
		return { valid = false }
		
	var lump := wad.load_lump(lump_name)
	if not lump or lump.is_empty():
		return { valid = false }
	
	var width := lump.decode_u16(0)
	var height := lump.decode_u16(2)
	var x_offset := lump.decode_s16(4)
	var y_offset := lump.decode_s16(6)
	
	var image := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	
	for x in width:
		var i := lump.decode_u32(8 + 4 * x)
		
		var y := lump.decode_u8(i + 0)
		while y != 0xff:
			var length := lump.decode_u8(i + 1)
			
			for j in length:
				var color := lump.decode_u8(i + 3 + j)
				image.set_pixel(x, y + j, palette[color])
			
			i += 4 + length
			y = lump.decode_u8(i + 0)
	
	return {
		valid = true,
		texture = ImageTexture.create_from_image(image),
		offset = Vector2i(x_offset, y_offset),
		center = Vector2i(width, height) / 2
	}


func get_item_name(doom_type: int) -> String:
	var index : int = game.all_items.find_custom(func(x: Dictionary) -> bool: return x.doom_type == doom_type)
	return "(no item)" if index == -1 else game.all_items[index].name
