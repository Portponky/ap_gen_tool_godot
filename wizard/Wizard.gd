extends Window

signal task_complete

var map_regex := RegEx.create_from_string("^(MAP\\d\\d)|(E\\dM\\d)$")

var current_step := -1
var game_json := {}
var wads: Array

func _ready() -> void:
	%Error.text = ""
	start_next_step()


func start_next_step() -> void:
	current_step += 1
	print(game_json)
	
	match current_step:
		0:
			%Basic.show()
		1:
			%Wads.show()
		2:
			if not await load_wads():
				wads.clear()
				current_step = 1
				return
			
			find_all_maps()
			%Episodes.set_map_list(game_json)
			%Episodes.show()
		3:
			%Maps.set_map_list(game_json)
			%Maps.show()
		4:
			write_nice_json()


func _on_next_button_pressed() -> void:
	# Let's see if the page works
	%Error.text = ""
	var current_page: Control = %Pages.get_current_tab_control()
	var error: String = current_page.verify(game_json)
	
	if not error.is_empty():
		%Error.text = error
	else:
		current_page.populate(game_json)
		start_next_step()


func _on_quit_button_pressed() -> void:
	pass # Replace with function body.


func load_wads() -> bool:
	Status.reset()
	var path := "res://" if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()
	
	var target_wads := []
	target_wads.append_array(game_json.required_wads)
	target_wads.append_array(game_json.included_wads)
	
	var thread := Thread.new()
	thread.start(func() -> bool:
		var success := true
		for wad_name: String in target_wads:
			var wad := Wad.load("%s/wads/%s" % [path, wad_name])
			if not wad:
				%Error.text = "Unable to load wad %s" % wad_name
				success = false
				break
			
			wads.push_back(wad)

		task_complete.emit.call_deferred()
		return success
	)
	
	await task_complete
	return thread.wait_to_finish()


func find_all_maps() -> void:
	game_json.maps = []
	var matcher := func(x: String) -> bool:
		return map_regex.search(x) != null
	
	for wad in wads:
		game_json.maps.append_array(wad.matching_lumps(matcher))
	
	game_json.maps.sort()


func write_nice_json() -> void:
	# just splaffing out the json is horrible, let's hand roll it so it's neat for human editing
	var strings := [
		'{',
		'  "short_name": "%s",' % game_json.short_name,
		'  "full_name": "%s",' % game_json.full_name.json_escape(),
		'  "ap_name": "%s - %s",' % [game_json.iwad.name, game_json.full_name.json_escape()],
		'  "ap_world_name": "%s_%s",' % [game_json.iwad.world, game_json.short_name],
		'  "iwad": "%s",' % game_json.iwad.filename
	]
	
	strings.append_array(write_nice_wad_json("required_wads"))
	strings.append_array(write_nice_wad_json("included_wads"))
	strings.append_array(write_nice_wad_json("optional_wads"))
	
	strings.append_array([
		'',
		'  "settings": {',
		'    "extended_names": true',
		'  },',
		'',
		'  "episodes": [',
	])
	
	for e: int in game_json.episode_details.size():
		var episode: Dictionary = game_json.episode_details[e]
		strings.push_back('    {')
		if not episode.name.is_empty():
			strings.push_back('      "name": "%s",' % episode.name.json_escape())
		if episode.is_minor:
			strings.push_back('      "minor": true,')
		if not episode.is_default:
			strings.push_back('      "default": false,')
		strings.push_back('      "maps": [')
		for m: int in episode.maps.size():
			var map: Dictionary = episode.maps[m]
			strings.push_back('        { "lump": "%s", "name": "%s (%s)" }%s' % [
				map.lump,
				map.name.json_escape(),
				map.lump,
				ending_comma(m, episode.maps.size())
			])
		
		strings.push_back('      ]')
		strings.push_back('    }%s' % ending_comma(e, game_json.episode_details.size()))
	
	strings.append_array([
		'  ],',
		'',
		'  "world_info": {'
	])
	
	if not game_json.description.is_empty():
		strings.push_back('    "description": [')
		for d: int in game_json.description.size():
			strings.push_back('      "%s"%s' % [game_json.description[d].json_escape(), ending_comma(d, game_json.description.size())])
		strings.push_back('    ],')
		strings.push_back('')
	
	strings.append_array([
		'    "hooks": {',
		'    },',
		'',
		'    "world_options": [',
		'      { "name": "Difficulty", "preset": "Doom" },',
		'      { "name": "Start with Maps" },',
		'      { "name": "Invis as Trap" },',
		'      { "name": "Capacity Upgrades" },',
		'      { "name": "Custom Ammo Capacity" }',
		'    ]',
		'  },',
		'',
		'  "map_tweaks": {',
		'  },',
		'',
		'  "level_select": {',
		'  }',
		'}'
	])
	
	var path := ProjectSettings.globalize_path("res://games/") if OS.has_feature("editor") else "%s/games" % OS.get_executable_path().get_base_dir()
	var target := "%s/%s.game.json" % [path, game_json.short_name]
	var file = FileAccess.open(target, FileAccess.WRITE)
	file.store_string("\n".join(strings))
	print("Output game.json file")


func write_nice_wad_json(key: String) -> Array:
	match game_json[key].size():
		0:
			return []
		1:
			return [
				'  "%s": "%s",' % [key, game_json[key][0]],
			]
		_:
			var quoted: Array = game_json[key].map(func(x: String) -> String: return '"%s"' % x)
			return [
				'  "%s": [%s],' % [key, ", ".join(quoted)],
			]


func ending_comma(n: int, length: int) -> String:
	return "" if n == length - 1 else ","
