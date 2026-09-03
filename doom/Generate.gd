class_name Generate
extends Node

const DOOM_TYPE_LEVEL_UNLOCK := -1
const DOOM_TYPE_LEVEL_COMPLETE := -2
const FILLER := 0x0000
const PROGRESSION := 0x0001
const USEFUL := 0x0002
const TRAP := 0x0004
const SKIP_BALANCING := 0x0008
const DEPRIORITIZED := 0x0010


static func get_location_id_base(idx: Dictionary) -> int:
	return ((idx.ep + 1) * 100_000) + ((idx.map + 1) * 1_000)


static func get_item_id_base(idx: Dictionary) -> int:
	return ((idx.ep + 1) * 10_000_000) + ((idx.map + 1) * 100_000)


static func build_levels(world: World) -> Array:
	Status.set_task("Building level info")
	var levels := []
	for e: int in world.game.episodes.size():
		var episode: Dictionary = world.game.episodes[e]
		for m: int in episode.maps.size():
			var map: Dictionary = episode.maps[m]
			var map_index: int = world.data.maps.find_custom(func(x: Dictionary) -> bool: return x._lump == map.lump)
			levels.push_back({
				idx = {ep = e, map = m},
				name = map.name,
				group_name = map.lump, #incorrect
				music_override = map.get("music_override", ""),
				map = world.maps[map.lump],
				state = world.data.maps[map_index]
			})
	
	return levels


static func region_name_for_position(pos: Vector2, level: Dictionary) -> String:
	var region_name : String
	var sector: int = level.map.sector_for_point(pos)
	for region: Dictionary in level.state.regions:
		if region.sectors.any(func(x: float) -> bool: return int(x) == sector):
			region_name = "%s @ %s" % [level.name, region.name]
			break
	
	for bb: Array in level.state.bbs:
		if pos.x < bb[0] or pos.x > bb[2]:
			continue
		if pos.y < bb[1] or pos.y > bb[3]:
			continue
		var region : int = bb[4]
		if region > -1 and region < level.state.regions.size():
			region_name = "%s @ %s" % [level.name, level.state.regions[region].name]
	
	return region_name


static func build_locations(world: World, levels: Array) -> Array:
	Status.set_task("Building location info")
	var locations := []
	
	for level: Dictionary in levels:
		var next_location := 1
		for i: int in level.map.things.size():
			var thing: Map.Thing = level.map.things[i]
			var string_type := str(thing.type)
			if not world.game.location_doom_types.has(string_type) or thing.flags & Map.Thing.Flags.Multiplayer:
				continue
			
			var location_index: int = level.state.locations.find_custom(func(x: Dictionary) -> bool: return x.index == i)
			var location: Dictionary = level.state.locations[location_index]
			if location.unreachable:
				continue
			if next_location > 999:
				print("Max locations error")
				break
			
			var extension := ""
			if world.game.settings.get("extended_names", false) and not location.get("name", "").is_empty():
				extension = " (%s)" % location.name
			
			var item_name: String = world.game.location_doom_types[str(thing.type)]
			var location_name := "%s - %s%s" % [level.name, item_name, extension]
			var count := 1
			while locations.find_custom(func(x: Dictionary) -> bool: return x.name == location_name) != -1:
				count += 1
				location_name = "%s - %s %d%s" % [level.name, item_name, count, extension]
			
			locations.push_back({
				name = location_name,
				region_name = region_name_for_position(Vector2(thing.x, thing.y), level),
				level_name = level.name,
				idx = level.idx,
				id = get_location_id_base(level.idx) + next_location,
				doom_type = thing.type,
				doom_thing_index = i,
				check_sanity = location.check_sanity,
				state = location
			})
			next_location += 1
		
		# exit location
		var exit_location_name := "Hub @ Entrance to %s" % level.name
		var exit_found := false
		for region: Dictionary in level.state.regions:
			for connection: Dictionary in region.rules.connections:
				if connection.target_region == DOOM_TYPE_LEVEL_COMPLETE:
					exit_location_name = "%s @ %s" % [level.name, region.name]
					exit_found = true
					break
			if exit_found:
				break
		
		if not exit_found:
			print("%s has no region that connects to the exit" % level.name)
		locations.push_back({
			region_name = exit_location_name,
			doom_type = DOOM_TYPE_LEVEL_COMPLETE,
			doom_thing_index = -1,
			idx = level.idx,
			name = "%s - Exit" % level.name,
			level_name = level.name,
			id = get_location_id_base(level.idx)
		})
	
	return locations


static func make_item(def: Dictionary, type: int, level: Dictionary, key := false) -> Dictionary:
	var item := {
		is_key = key,
		count = def.get("count", 1),
		classification = type,
		doom_type = def.doom_type,
		group = def.get("group", []),
		level = level
	}
	
	var base_item_id := int(def.doom_type)
	if base_item_id == DOOM_TYPE_LEVEL_UNLOCK:
		base_item_id = 0
	elif base_item_id == DOOM_TYPE_LEVEL_COMPLETE:
		base_item_id = 99999
	elif base_item_id < 0:
		print("Unknown special doom type error")
	
	if level:
		item.name = level.name if def.get("name", "").is_empty() else "%s - %s" % [level.name, def.name]
		item.idx = level.idx
		item.id = get_item_id_base(level.idx) + base_item_id
	else:
		item.name = def.name
		item.idx = {ep = -2, map = -2}
		item.id = base_item_id
	
	return item


static func build_items(world: World, levels: Array) -> Array:
	Status.set_task("Building item info")
	var items := []
	
	for def: Dictionary in world.game.items.progression:
		items.push_back(make_item(def, PROGRESSION, {}))
	for def: Dictionary in world.game.items.useful:
		items.push_back(make_item(def, USEFUL, {}))
	for def: Dictionary in world.game.items.filler:
		items.push_back(make_item(def, FILLER, {}))
	
	var level_unlock_item := {
		doom_type = DOOM_TYPE_LEVEL_UNLOCK,
		count = 1,
		group = ["Levels", "%MAP%"]
	}
	
	var level_complete_item := {
		doom_type = DOOM_TYPE_LEVEL_COMPLETE,
		count = 0,
		name = "Complete"
	}
	
	for level: Dictionary in levels:
		items.push_back(make_item(level_unlock_item, PROGRESSION | USEFUL, level))
		items.push_back(make_item(level_complete_item, PROGRESSION, level))
		for def: Dictionary in world.game.items.unique_progression:
			items.push_back(make_item(def, PROGRESSION, level))
		for def: Dictionary in world.game.items.unique_useful:
			items.push_back(make_item(def, USEFUL, level))
		for def: Dictionary in world.game.items.unique_filler:
			items.push_back(make_item(def, FILLER, level))
		
		# add unique keys
		for i: int in level.map.things.size():
			var thing : Map.Thing = level.map.things[i]
			var string_type := str(thing.type)
			if not world.game.location_doom_types.has(string_type) or thing.flags & Map.Thing.Flags.Multiplayer:
				continue
			
			for key: Dictionary in world.game.items.keys:
				if key.doom_type != thing.type:
					continue
				var key_item := make_item(key, PROGRESSION, level, true)
				if items.find_custom(func(x: Dictionary) -> bool: return x.name == key_item.name) == -1:
					items.push_back(key_item)
	
	return items


static func build_manifest(world: World) -> Dictionary:
	Status.set_task("Building manifest info")
	var result := {
		short_name = world.game.short_name,
		iwad = world.game.iwad,
		definitions = "%s/%s.game.json" % [world.game.ap_world_name, world.game.short_name]
	}
	
	if world.game.full_name != world.game.ap_name:
		result.full_name = world.game.full_name
	
	if world.game.required_wads:
		result.wads_required = world.game.required_wads
	
	if world.game.optional_wads:
		result.wads_optional = world.game.optional_wads
	
	if world.game.included_wads:
		result.wads_included = world.game.included_wads.map(
			func(x: String) -> String: return "%s/wad/%s" % [world.game.ap_world_name, x.get_file()]
		)
	
	return result


static func get_requirement_name(world: World, level_name: String, doom_type: int) -> String:
	for item: Dictionary in world.game.connection_items:
		if item.doom_type != doom_type:
			continue
		for g: String in item.get("group", []):
			if g.begins_with("%MAP%"):
				return "%s - %s" % [level_name, item.name]
		return item.name
	
	return "ERROR"


static func make_connection(world: World, connection: Dictionary, level_name: String, region_name: String) -> Dictionary:
	var result := {
		_target = region_name
	}
	
	var requires := []
	var rules := {}
	
	for doom_type: int in connection.requirements_and:
		rules.get_or_add("and", []).push_back(get_requirement_name(world, level_name, doom_type))
	
	for doom_type: int in connection.requirements_or:
		rules.get_or_add("or", []).push_back(get_requirement_name(world, level_name, doom_type))
	
	if not rules.is_empty():
		result.rules = [rules]
	if not requires.is_empty():
		result.requires = requires
	
	return result


static func generate_regions(world: World, levels: Array) -> Array:
	Status.set_task("Generating regions")
	var result := []
	
	var game_hub_region := {
		_name = "Hub",
		connections = []
	}
	for level: Dictionary in levels:
		var connection := {
			_target = "Hub @ Entrance to %s" % level.name,
			rules = [{"and": [level.name]}]
		}
		game_hub_region.connections.append(connection)
	result.append(game_hub_region)
	
	for level: Dictionary in levels:
		var level_hub_region := {
			_name = "Hub @ Entrance to %s" % level.name,
			exmx = [level.idx.ep + 1, level.idx.map + 1],
			connections = []
		}
		
		for connection: Dictionary in level.state.world_rules.connections:
			var target_region: Dictionary = level.state.regions[connection.target_region]
			var region_name := "%s @ %s" % [level.name, target_region.name]
			level_hub_region.connections.push_back(make_connection(world, connection, level.name, region_name))
		
		result.append(level_hub_region)
		
		for region: Dictionary in level.state.regions:
			var connections := []
			for connection: Dictionary in region.rules.connections:
				var target_region_name : String
				if connection.target_region == DOOM_TYPE_LEVEL_COMPLETE:
					continue
				if connection.target_region == DOOM_TYPE_LEVEL_UNLOCK:
					target_region_name = "Hub @ Entrance to %s" % level.name
				else:
					target_region_name = "%s @ %s" % [level.name, level.state.regions[connection.target_region].name]
				connections.push_back(make_connection(world, connection, level.name, target_region_name))
			
			result.append({
				_name = "%s @ %s" % [level.name, region.name],
				exmx = [level.idx.ep + 1, level.idx.map + 1],
				connections = connections
			})
	
	return result


static func generate_item_table(items: Array) -> Dictionary:
	Status.set_task("Generating item table")
	var result := {}
	
	for item: Dictionary in items:
		var i := {
			_name = item.name,
			classification = item.classification,
			doom_type = item.doom_type,
		}
		if item.count > 0:
			i.count = item.count
		if item.idx.ep >= 0:
			i.exmx = [item.idx.ep + 1, item.idx.map + 1]
		result[str(item.id)] = i
	
	return result


static func generate_item_name_groups(items: Array) -> Dictionary:
	var result := {}
	
	for item: Dictionary in items:
		for group: String in item.group:
			var key := group.replace("%MAP%", item.level.group_name if item.level else "NULL")
			var list: Array = result.get_or_add(key, [])
			list.append(item.name)
	
	return result


static func generate_location_table(world: World, locations: Array) -> Dictionary:
	Status.set_task("Generating location table")
	var result := {}
	
	for location: Dictionary in locations:
		var id := str(location.id)
		var region_name := location.get("region_name", "") as String
		if region_name.is_empty():
			print("Unreachable thing warning")
			region_name = "Hub @ Entrance to " + location.level_name
		
		result[id] = {
			_name = location.name,
			doom_type = location.doom_type,
			exmx = [location.idx.ep + 1, location.idx.map + 1],
			region = region_name
		}
		if world.game.check_sanity and location.check_sanity:
			result[id].check_sanity = true
	
	return result


static func generate_location_name_groups(locations: Array) -> Dictionary:
	Status.set_task("Generating location name groups")
	var result := {}
	
	for location: Dictionary in locations:
		result.get_or_add(location.level_name, []).push_back(location.name)
	
	return result


static func generate_death_logic_excluded_locations(locations: Array) -> Array:
	Status.set_task("Generating death logic excluded locations")
	var result := []
	
	for location: Dictionary in locations:
		if location.has("state") and location.state.death_logic:
			result.push_back(location.name)
	
	return result


static func generate_starting_levels_by_episode(world: World) -> Dictionary:
	Status.set_task("Generating starting levels by episode")
	var result := {}
	
	for ep: int in world.game.episodes.size():
		if world.game.episodes[ep].get("minor", false):
			continue
		var start_level: int = world.game.episodes[ep].get("start_level", 1) - 1
		if start_level >= 0 and start_level < world.game.episodes[ep].maps.size():
			result[str(ep + 1)] = world.game.episodes[ep].maps[start_level].name
	
	return result


static func generate_item_pool_ratio(world: World) -> Dictionary:
	Status.set_task("Generating item pool ratio")
	var result := {}
	
	for pool: String in world.game.world_info.item_pool_ratio:
		var ratio: Dictionary = world.game.world_info.item_pool_ratio[pool]
		result[pool] = [ratio.helpful, ratio.random]
	
	return result


static func generate_helpful_item_weight(world: World) -> Dictionary:
	Status.set_task("Generating helpful item weight")
	return world.game.world_info.helpful_item_weight


static func generate_flat_location_table(locations: Array) -> Dictionary:
	Status.set_task("Generating flat location table")
	var result := {}
	
	for location: Dictionary in locations:
		var ep := str(location.idx.ep + 1)
		var map := str(location.idx.map + 1)
		var index := str(location.doom_thing_index)
		
		result.get_or_add(ep, {}).get_or_add(map, {})[index] = location.id
	
	return result


static func generate_flat_item_table(items: Array) -> Dictionary:
	Status.set_task("Generating flat item table")
	var result := {}
	
	for item: Dictionary in items:
		var id := str(item.id)
		if item.idx.ep >= 0:
			result[id] = [item.name, item.doom_type, item.idx.ep + 1, item.idx.map + 1]
		else:
			result[id] = [item.name, item.doom_type]
	
	return result


static func generate_level_info(world: World, levels: Array, locations: Array) -> Array:
	var result := []
	
	for level: Dictionary in levels:
		Status.set_task("Generating level info for %s" % level.name)
		
		var map_index := [1, level.group_name.right(-3).to_int()]
		if not level.group_name.begins_with("MAP"):
			map_index[0] = level.group_name[1].to_int()
		
		var info := {
			_name = level.name,
			key = [false, false, false],
			use_skull = [false, false, false],
			game_map = map_index
		}
		
		if not level.music_override.is_empty():
			info.music = level.music_override
		
		var thing_list := []
		for t: int in level.map.things.size():
			var thing: Map.Thing = level.map.things[t]
			
			for key: Dictionary in world.game.items.keys:
				if key.doom_type == thing.type:
					info.key[key.key] = true
					if key.get("use_skull", false):
						info.use_skull[key.key] = true
					break
			
			for location: Dictionary in locations:
				if location.idx == level.idx and t == location.doom_thing_index:
					thing_list.push_back([thing.type, location.id])
					break
			
			if thing_list.size() <= t:
				thing_list.push_back(thing.type)
		info.thing_list = thing_list
		
		while result.size() <= level.idx.ep:
			result.push_back([])
		result[level.idx.ep].push_back(info)
	
	return result


static func generate_type_sprites(world: World) -> Dictionary:
	Status.set_task("Generating type sprites")
	var result := {}
	
	for item: Dictionary in world.game.all_items:
		result[str(int(item.doom_type))] = item.sprite
	
	return result


static func generate_energy_link_shop(world: World) -> Array:
	Status.set_task("Generating energy link shop")
	var result := []
	
	for item: Dictionary in world.game.common_items:
		if item.get("buyable", false):
			result.push_back(int(item.doom_type))
	
	return result


static func generate_ap_location_types(world: World) -> Array:
	Status.set_task("Generating ap location types")
	var result := []
	
	for type: String in world.game.location_doom_types:
		result.push_back(type.to_int())
	
	result.sort() # cosmetic
	return result


static func generate_manifest(world: World, info: Dictionary) -> Dictionary:
	Status.set_task("Generating manifest")
	var dt := Time.get_date_dict_from_system()
	
	var result := {
		game = world.game.ap_name,
		world_version = "2.0.%04d%02d%02d" % [dt.year, dt.month, dt.day],
		minimum_ap_version = "0.6.3",
		__apdoom = info,
		version = 7,
		compatible_version = 7,        
		repo_url = "https://archipelagodoom.github.io/worlds/index.json"
	}
	
	if world.game.authors:
		result.authors = world.game.authors
	
	return result


static func generate_copy(target: Dictionary, from: Dictionary, key: String) -> void:
	Status.set_task("Generating copy of %s" % key)
	if from.has(key):
		target[key] = from[key]


static func patch_zip_file(filename: String) -> void:
	# Godot outputs zip files with utf-8 set
	# APDoom rejects the files because of this
	# However, the zip files are only ascii so we can manually disable the utf-8 setting
	
	Status.set_task("Patching zip file")
	var bytes := FileAccess.get_file_as_bytes(filename)
	
	# check header, assuming no comment
	if bytes.decode_u32(bytes.size() - 22) != 0x06054b50:
		print("Invalid central header")
		return
	
	var num_entries := bytes.decode_u16(bytes.size() - 14)
	var dir_offset := bytes.decode_u32(bytes.size() - 6)
	for n in num_entries:
		if bytes.decode_u32(dir_offset) != 0x02014b50:
			print("Invalid directory header")
			return
		
		var local_offset := bytes.decode_u32(dir_offset + 42)
		
		if bytes.decode_u32(local_offset) != 0x04034b50:
			print("Invalid local header")
			return
		
		var flags := bytes.decode_u16(local_offset + 6)
		if flags == 2050:
			bytes.encode_u16(local_offset + 6, 2)
		
		var fn_len := bytes.decode_u16(dir_offset + 28)
		var ef_len := bytes.decode_u16(dir_offset + 30)
		var fc_len := bytes.decode_u16(dir_offset + 32)
		
		dir_offset += 46 + fn_len + ef_len + fc_len
	
	var rewrite := FileAccess.open(filename, FileAccess.WRITE)
	rewrite.store_buffer(bytes)
	rewrite.close()
	print("Patch complete")


static func generate(world: World) -> void:
	var info := {}
	info.levels = build_levels(world)
	info.locations = build_locations(world, info.levels)
	info.items = build_items(world, info.levels)
	info.manifest = build_manifest(world)
	info.options = WorldOptions.build_options(world)
	
	var d := {}
	d["regions"] = generate_regions(world, info.levels)
	d["item_table"] = generate_item_table(info.items)
	d["item_name_groups"] = generate_item_name_groups(info.items)
	d["location_table"] = generate_location_table(world, info.locations)
	d["location_name_groups"] = generate_location_name_groups(info.locations)
	d["death_logic_excluded_locations"] = generate_death_logic_excluded_locations(info.locations)
	d["starting_levels_by_episode"] = generate_starting_levels_by_episode(world)
	d["item_pool_ratio"] = generate_item_pool_ratio(world)
	d["helpful_item_weight"] = generate_helpful_item_weight(world)
	
	var g := {}
	g["location_table"] = generate_flat_location_table(info.locations)
	g["item_table"] = generate_flat_item_table(info.items)
	g["level_info"] = generate_level_info(world, info.levels, info.locations)
	g["type_sprites"] = generate_type_sprites(world)
	g["energy_link_shop"] = generate_energy_link_shop(world)
	g["ap_location_types"] = generate_ap_location_types(world)
	generate_copy(g, world.game, "game_info")
	generate_copy(g, world.game, "map_tweaks")
	generate_copy(g, world.game, "level_select")
	generate_copy(g, world.game, "rename_lumps")
	
	var m := generate_manifest(world, info.manifest)
	
	var zip := ZIPPacker.new()
	zip.compression_level = ZIPPacker.COMPRESSION_BEST
	
	var path := "res://" if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()

	var output_file_name := "%s/output/%s.apworld" % [path, world.game.ap_world_name]
	zip.open(output_file_name)
	
	zip.start_file("%s/%s.data.json" % [world.game.ap_world_name, world.game.short_name])
	zip.write_file(JSON.stringify(d).to_ascii_buffer())
	zip.close_file()
	
	zip.start_file("%s/%s.game.json" % [world.game.ap_world_name, world.game.short_name])
	zip.write_file(JSON.stringify(g).to_ascii_buffer())
	zip.close_file()
	
	zip.start_file("%s/archipelago.json" % world.game.ap_world_name)
	zip.write_file(JSON.stringify(m).to_ascii_buffer())
	zip.close_file()
	
	zip.start_file("%s/__init__.py" % world.game.ap_world_name)
	zip.write_file(Python.generate_init(world, info.options))
	zip.close_file()
	
	zip.start_file("%s/options.py" % world.game.ap_world_name)
	zip.write_file(Python.generate_options(world, info.levels, info.options))
	zip.close_file()
	
	for wad: String in world.game.included_wads:
		zip.start_file("%s/wad/%s" % [world.game.ap_world_name, wad.get_file()])
		zip.write_file(FileAccess.get_file_as_bytes("%s/wads/%s" % [path, wad]))
		zip.close_file()
	
	zip.start_file("%s/id1common/__init__.py" % world.game.ap_world_name)
	zip.write_file(FileAccess.get_file_as_bytes("res://assets/py/id1common/__init__.py"))
	zip.close_file()
	
	zip.start_file("%s/id1common/options.py" % world.game.ap_world_name)
	zip.write_file(FileAccess.get_file_as_bytes("res://assets/py/id1common/options.py"))
	zip.close_file()
	
	zip.start_file("%s/id1common/LICENSE" % world.game.ap_world_name)
	zip.write_file(FileAccess.get_file_as_bytes("res://assets/py/id1common/LICENSE"))
	zip.close_file()
	
	zip.close()
	
	patch_zip_file(output_file_name)
