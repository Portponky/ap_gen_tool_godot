extends Window

signal task_complete

var map_regex := RegEx.create_from_string("^(MAP\\d\\d)|(E\\dM\\d)$")

var current_step := -1
var game_json := {}
var wads: Array
var maps: Array

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
			%Episodes.set_map_list(maps)
			%Episodes.show()
		3:
			%Maps.set_map_list(maps, game_json)
			%Maps.show()
		4:
			var path := ProjectSettings.globalize_path("res://games/") if OS.has_feature("editor") else "%s/games" % OS.get_executable_path().get_base_dir()
			var target := "%s/%s.game.json" % [path, game_json.short_name]
			var output := JSON.stringify(game_json, "  ")
			var file = FileAccess.open(target, FileAccess.WRITE)
			file.store_string(output)
			print("Output game.json file")


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


func append_content_to_array(target: Array, key: String) -> void:
	if not game_json.has(key):
		return
	
	if game_json[key] is Array:
		target.append_array(game_json[key])
	else:
		target.append(game_json[key])


func load_wads() -> bool:
	Status.reset()
	var path := "res://" if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()
	
	var target_wads := []
	append_content_to_array(target_wads, "required_wads")
	append_content_to_array(target_wads, "included_wads")
	
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
	var matcher := func(x: String) -> bool:
		return map_regex.search(x) != null
	
	for wad in wads:
		maps.append_array(wad.matching_lumps(matcher))
