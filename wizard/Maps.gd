extends VBoxContainer

var controls : Array

func set_map_list(game: Dictionary) -> void:
	var i := 0
	for e: int in game.episodes.size():
		var data := {
			episode = %Episode.duplicate(),
			maps = []
		}
		data.episode.name = str(e + 1)
		%Tabs.add_child(data.episode)
		
		var map_count: int = game.episodes[e]
		
		if map_count < 5:
			data.episode.get_node("Layout/DetailsContainer/CheckMinor").button_pressed = true
		
		for m: int in map_count:
			var map_control := %MapContainer.duplicate()
			map_control.get_node("LumpName").text = game.maps[i]
			data.episode.get_node("Layout").add_child(map_control)
			data.maps.push_back(map_control)
			i += 1
		
		controls.push_back(data)
	
	%Episode.queue_free()
	%MapContainer.queue_free()


func verify(game: Dictionary) -> String:
	var found_lumps := []
	
	for c: Dictionary in controls:
		for m: Control in c.maps:
			var lump_name: String = m.get_node("LumpName").text
			var human_name: String = m.get_node("HumanName").text
			if  lump_name.is_empty():
				return "Missing lump name"
			if not lump_name in game.maps:
				return "Unknown lump: %s" % lump_name
			if lump_name in found_lumps:
				return "Duplicate lump %s" % lump_name
			if human_name.is_empty():
				return "Unnamed map for lump %s" % lump_name
			found_lumps.push_back(lump_name)
	
	return ""


func populate(game: Dictionary) -> void:
	game.episode_details = []
	for e: int in controls.size():
		var control: Dictionary = controls[e]
		
		var details := {
			name = control.episode.get_node("Layout/EpisodeContainer/EpisodeName").text,
			is_minor = control.episode.get_node("Layout/DetailsContainer/CheckMinor").button_pressed,
			is_default = control.episode.get_node("Layout/DetailsContainer/CheckDefault").button_pressed,
			maps = []
		}
		
		for m: int in control.maps.size():
			details.maps.push_back({
				lump = control.maps[m].get_node("LumpName").text,
				name = control.maps[m].get_node("HumanName").text,
			})
		
		game.episode_details.push_back(details)
