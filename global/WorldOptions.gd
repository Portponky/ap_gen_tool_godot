extends Node


var option_definitions := {
	"Difficulty" = {
		py_options = difficulty_py_options
	},
	"Start with Maps" = {
		init = start_with_maps_init,
		world_hook = start_with_maps_world_hook,
		py_options = start_with_maps_py_options,
	},
	"Invis as Trap" = {
		init = invis_as_trap_init,
		world_hook = invis_as_trap_world_hook,
		py_options = invis_as_trap_py_options,
	},
	"Custom Ammo Capacity" = {
		init = custom_ammo_capacity_init,
		world_hook = custom_ammo_capacity_world_hook,
		py_options = custom_ammo_capacity_py_options,
	},
	"Capacity Upgrades" = {
		init = capacity_upgrades_init,
		world_hook = capacity_upgrades_world_hook,
		py_options = capacity_upgrades_py_options,
	},
	"Custom Option" = {
		py_options = custom_option_py_options,
	}
}

# ==== Difficult ===

func difficulty_py_options(_world: World, _option: Dictionary, py_options: Array) -> void:
	var opt_difficulty := PyOptions.create("difficulty", "DifficultyDoom", PyOptions.OptionType.InID1Common)
	opt_difficulty.option_group = "Difficulty Options"
	py_options.push_back(opt_difficulty)

# === Start with maps ===

func start_with_maps_init(world: World, option: Dictionary) -> void:
	var default_type := 35 if world.game.iwad == "HERETIC.WAD" else 2026
	option.get_or_add("doom_type", default_type)
	option.singular = world.get_item_name(option.doom_type)
	option.plural = option.get("plural_name", "%ss" % option.singular)
	option.py_data_name = "start_with_%s" % option.plural.to_snake_case()


func start_with_maps_world_hook(_world: World, hook: String, option: Dictionary) -> Array:
	if hook != "create_items":
		return []
	
	return [
		"map_opt = self.options.%s" % option.py_data_name,
		"if map_opt.value:",
		"    map_items = [pop_from_pool(i.name) for i in self.matching_items(doom_type=map_opt.doom_type).values()]",
		"    [self.multiworld.push_precollected(self.create_item(n)) for n in map_items if n is not None]"
	]


func start_with_maps_py_options(_world: World, option: Dictionary, py_options: Array) -> void:
	var opt_maps := PyOptions.create(option.py_data_name, "StartWithComputerAreaMaps", PyOptions.OptionType.InID1Common)
	opt_maps.option_group = "Randomizer Options"
	py_options.push_back(opt_maps)


# === Invis as trap ===

func invis_as_trap_init(world: World, option: Dictionary) -> void:
	option.get_or_add("doom_type", 2024)
	option.invis_name = world.get_item_name(option.doom_type)
	option.py_data_name = "%s_as_trap" % option.invis_name.to_snake_case()


func invis_as_trap_world_hook(_world: World, hook: String, option: Dictionary) -> Array:
	if hook != "create_item":
		return []
	
	return [
		"invis_trap = self.options.%s" % option.py_data_name,
		"if invis_trap.value and item_data.doom_type == invis_trap.doom_type:",
		"    classification = AP.ItemClassification.trap"
	]


func invis_as_trap_py_options(_world: World, option: Dictionary, py_options: Array) -> void:
	var opt_invis := PyOptions.create(option.py_data_name, "", PyOptions.OptionType.InvisibilityTrap)
	opt_invis.option_group = "Randomizer Options"
	py_options.push_back(opt_invis)


# === Custom ammo capacity ===

func custom_ammo_capacity_init(world: World, option: Dictionary) -> void:
	option.ammo_types = []
	for ammo: Dictionary in world.game.game_info.ammo:
		var ammo_name := ammo.get("name", "(no name)") as String
		option.ammo_types.push_back({
			name = ammo_name,
			py_suffix = ammo_name.to_snake_case(),
			capacity = ammo.get("max", 0)
		})


func custom_ammo_capacity_world_hook(_world: World, hook: String, option: Dictionary) -> Array:
	if hook == "generate_early":
		var result := ["if ("]
		var first := true
		for ammo: Dictionary in option.ammo_types:
			var condition := "    " if first else "    or "
			condition += "self.options.max_ammo_%s.value < " % ammo.py_suffix
			condition += "self.options.max_ammo_%s.default" % ammo.py_suffix
			result.push_back(condition)
			first = false
		result.push_back("):")
		result.push_back("    self.warning(\"Some starting ammo capacity options are set below their default values.\\n\"")
		result.push_back("                 \"This may make games significantly harder than intended; you have been warned.\")")
		return result
	
	elif hook == "fill_slot_data":
		var result := ["slot_data[\"ammo_start\"] = ["]
		for ammo: Dictionary in option.ammo_types:
			result.push_back("    self.options.max_ammo_%s.value," % ammo.py_suffix)
		result.push_back("]")
		result.push_back("slot_data[\"ammo_add\"] = [")
		for ammo: Dictionary in option.ammo_types:
			result.push_back("    self.options.added_ammo_%s.value," % ammo.py_suffix)
		result.push_back("]")
		return result
	
	return []


func custom_ammo_capacity_py_options(_world: World, option: Dictionary, py_options: Array) -> void:
	for ammo: Dictionary in option.ammo_types:
		var opt_max := PyOptions.create("max_ammo_%s" % ammo.py_suffix, "Max Ammo - %s" % ammo.name, PyOptions.OptionType.BoundedRandomRange)
		opt_max.docstring = [
			"Set the starting capacity for %s." % ammo.name,
			"",
			"Setting this below the default of %d is allowed, but may be logically unsafe." % ammo.capacity
		]
		opt_max.option_group = "Ammo Capacity"
		opt_max.range_start = ammo.capacity / 10
		opt_max.random_start = ammo.capacity
		opt_max.range_end = 999
		opt_max.default_int = ammo.capacity
		py_options.push_back(opt_max)
	
	for ammo: Dictionary in option.ammo_types:
		var opt_add := PyOptions.create("added_ammo_%s" % ammo.py_suffix, "Added Ammo - %s" % ammo.name, PyOptions.OptionType.Range)
		opt_add.docstring = ["Set how much capacity for %s will be added when a capacity upgrade is obtained." % ammo.name]
		opt_add.option_group = "Ammo Capacity"
		opt_add.range_start = ammo.capacity / 10
		opt_add.range_end = 999
		opt_add.default_int = ammo.capacity
		py_options.push_back(opt_add)


# === Capacity Upgrades ===

func capacity_upgrades_init(world: World, option: Dictionary) -> void:
	option.get_or_add("doom_type", 8)
	var singular := world.get_item_name(option.doom_type)
	option.plural = option.get("combined_plural_name", "%ss" % singular)
	option.split_name = "split_%s" % singular.to_snake_case()
	option.count_name = "%s_count" % singular.to_snake_case()
	option.get_or_add("item_count", 6 if world.game.iwad == "HERETIC.WAD" else 4)


func capacity_upgrades_world_hook(_world: World, hook: String, option: Dictionary) -> Array:
	if hook != "create_items":
		return []
	
	return [
		"split_opt = self.options.%s" % option.split_name,
		"split_items = list(self.matching_items(doom_type=split_opt.split_doom_types).values())",
		"combined_items = list(self.matching_items(doom_type=split_opt.doom_type).values())",
		"",
		"# Remove stray capacity upgrades of all types from the pool",
		"item_names = [i.name for i in split_items] + [i.name for i in combined_items]",
		"itempool = [n for n in itempool if n not in item_names]",
		"",
		"# Insert requested types and count of capacity upgrades",
		"if split_opt.value:",
		"    itempool += [i.name for i in split_items for _ in range(self.options.%s.value)]" % option.count_name,
		"else:",
		"    itempool += [i.name for i in combined_items for _ in range(self.options.%s.value)]" % option.count_name
	]


func capacity_upgrades_py_options(_world: World, option: Dictionary, py_options: Array) -> void:
	var opt_split := PyOptions.create(option.split_name, "SplitBackpack", PyOptions.OptionType.InID1Common)
	opt_split.option_group = "Randomizer Options"
	py_options.push_back(opt_split)
	
	var opt_count := PyOptions.create(option.count_name, "BackpackCount", PyOptions.OptionType.InID1Common)
	opt_count.option_group = "Randomizer Options"
	py_options.push_back(opt_count)


# === Custom Options ===

func custom_option_py_options(_world: World, option: Dictionary, py_options: Array) -> void:
	var type := PyOptions.OptionType.Removed
	match option.get("type", "(not set)"):
		"Toggle": type = PyOptions.OptionType.Toggle
		"Choice": type = PyOptions.OptionType.Choice
		"Range": type = PyOptions.OptionType.Range
		"BoundedRandomRange": type = PyOptions.OptionType.BoundedRandomRange
		# Option set
		_: push_error("Unknown custom option error goes here")
	
	var public_name := option.get("display_name", "") as String
	if public_name.is_empty():
		push_error("Missing display name for custom option error goes here")
	
	var private_name := option.get("option_name", "") as String
	if private_name.is_empty():
		private_name = public_name.to_snake_case()
	
	var opt := PyOptions.create(private_name, public_name, type)
	opt.option_group = option.get("group", "Randomizer Options")
	opt.doom_type = option.get("doom_type", 0)
	opt.docstring = option.get("description", [])
	if opt.docstring is String:
		opt.docstring = [opt.docstring]
	
	match type:
		PyOptions.OptionType.Toggle:
			opt.default_int = 1 if option.get("default", false) else 0
		PyOptions.OptionType.BoundedRandomRange, PyOptions.OptionType.Range:
			opt.range_start = option.get("range_start", 0)
			opt.range_end = option.get("range_end", 100)
			opt.default_int = option.get("default", opt.range_start)
			opt.random_start = option.get("random_start", -9999)
			opt.random_end = option.get("random_end", -9999)
		PyOptions.OptionType.Choice:
			if option.has("options") and option.options is Array:
				var first_value := -9999
				var choices := []
				var aliases := []
				for choice: Dictionary in option.options:
					if not choice.has("name") or not choice.has("value"):
						continue
					if first_value == -9999:
						first_value = choice.value
					choices.push_back("option_%s = %d" % [choice.name.to_snake_case(), choice.value])
					for alias: String in option.get("aliases", []):
						aliases.push_back("alias_%s = %d" % [alias.to_snake_case(), choice.value])
				opt.option_list = choices
				opt.option_list.append_array(aliases)
			opt.default_int = option.get("default", 0) # this seems wrong in original source, not sure...
	
	py_options.push_back(opt)


# ===

func build_options(world: World) -> Array:
	Status.set_task("Building options")
	var result := []
	
	for option: Dictionary in world.game.world_info.get("world_options", []):
		# name, some other params
		if not option.name in option_definitions:
			print("Unknown option warning goes here")
			continue
		
		var build := {}.merged(option).merged(option_definitions[option.name])
		
		if build.has("init"):
			build.init.call(world, build)
		
		result.push_back(build)
	
	return result


func add_hook(world: World, hook: String, options: Array) -> Array:
	var content := []
	
	if hook == "generate_early" and "warnings" == "bad":
		print("Warning thing goes here")
	
	if world.game.world_info.has("hooks") and world.game.world_info.hooks.has(hook):
		content.push_back("######## Custom code for this world begins here ########")
		content.append_array(world.game.world_info.hooks[hook])
		content.push_back("######## Custom code for this world ends here ########")
		content.push_back("")
	
	for option: Dictionary in options:
		if not option.has("world_hook"):
			continue
		
		var premade_content := option.world_hook.call(world, hook, option) as Array
		if premade_content.is_empty():
			continue
		
		content.push_back("######## Custom code for world option '%s' begins here ########" % option.name)
		content.append_array(premade_content)
		content.push_back("######## Custom code for world option '%s' ends here ########" % option.name)
		content.push_back("")
	
	return content


func add_default_options(world: World, levels: Array, py_options: Array) -> void:
	# Goals
	
	var opt_num_levels := PyOptions.create("goal_num_levels", "Goal: Number of Levels", PyOptions.OptionType.Range)
	opt_num_levels.docstring = [
		"If the goal is 'Complete Some Levels', 'Complete Random Levels', or 'Complete Some And Specific Levels',",
		"this is how many levels must be completed."
	]
	opt_num_levels.option_group = "Goal Options"
	opt_num_levels.range_start = 1
	opt_num_levels.range_end = levels.size()
	opt_num_levels.default_int = levels.size()
	py_options.push_back(opt_num_levels)
	
	var opt_specific_levels := PyOptions.create("goal_specific_levels", "Goal: Specific Levels", PyOptions.OptionType.OptionSet)
	opt_specific_levels.docstring = [
		"If the goal is 'Complete Specific Levels', or 'Complete Some And Specific Levels',",
		"all levels chosen here must be completed."
	]
	opt_specific_levels.option_group = "Goal Options"
	opt_specific_levels.option_list = []
	opt_specific_levels.default_list = []
	for level: Dictionary in levels:
		opt_specific_levels.option_list.push_back(level.name)
	for ep: int in world.game.episodes.size():
		if world.game.episodes[ep].get("minor", false):
			continue
		var boss_level := world.game.episodes[ep].get("boss_level", world.game.episodes[ep].maps.size()) as int - 1 
		if boss_level >= 0 and boss_level < world.game.episodes[ep].maps.size():
			opt_specific_levels.default_list.push_back(world.game.episodes[ep].maps[boss_level].name)
	py_options.push_back(opt_specific_levels)
	
	# Episodes
	
	if world.game.episodes.size() > 1:
		for ep: int in world.game.episodes.size():
			var episode := world.game.episodes[ep] as Dictionary
			var opt_episode := PyOptions.create("episode%d" % (ep + 1), "Episode %d" % (ep + 1), PyOptions.OptionType.Episode)
			opt_episode.option_group = "Episodes to Play"
			opt_episode.docstring = [
				"%s." % episode.get("name", "Episode %d" % (ep + 1)),
				""
			]
			if not episode.get("description", "").is_empty():
				opt_episode.docstring.push_back(episode.description)
			opt_episode.is_minor_episode = episode.get("minor", false)
			if opt_episode.is_minor_episode:
				opt_episode.docstring.push_back("This is a minor episode. Another episode must be played alongside this one.")
			opt_episode.docstring.push_back("This episode includes the following levels:")
			opt_episode.docstring.push_back("")
			for map: Dictionary in episode.maps:
				opt_episode.docstring.push_back("- %s" % map.name)
			opt_episode.default_int = 1 if episode.get("default", true) else 0
			py_options.push_back(opt_episode)
	
	# Level flipping
	
	if world.game.iwad == "HERETIC.WAD" or world.game.iwad == "HEXEN.WAD":
		py_options.push_back(PyOptions.create("flip_levels", "", PyOptions.OptionType.Removed))
	
	# Check sanity
	
	if world.game.check_sanity:
		py_options.push_back(PyOptions.create("check_sanity", "", PyOptions.OptionType.CheckSanity))


func add_py_options(world: World, options: Array, py_options: Array) -> void:
	for option: Dictionary in options:
		if not option.has("py_options"):
			continue
		option.py_options.call(world, option, py_options)
