extends VBoxContainer

var lumps : Array
var controls : Array

func set_map_list(next_lumps: Array, game: Dictionary) -> void:
	lumps = next_lumps
	lumps.sort()
	
	var i := 0
	for e: int in game.episodes.size():
		var episode: Dictionary = game.episodes[e]
		
		var data := {
			episode = %Episode.duplicate(),
			maps = []
		}
		data.episode.name = str(e + 1)
		%Tabs.add_child(data.episode)
		
		if episode.maps.size() < 5:
			data.episode.get_node("Layout/DetailsContainer/CheckMinor").button_pressed = true
		
		for m: int in episode.maps.size():
			var map_control := %MapContainer.duplicate()
			map_control.get_node("LumpName").text = lumps[i]
			data.episode.get_node("Layout").add_child(map_control)
			data.maps.push_back(map_control)
			i += 1
		
		controls.push_back(data)
	
	%Episode.queue_free()
	%MapContainer.queue_free()


func verify(_game: Dictionary) -> String:
	var found_lumps := []
	
	for c: Dictionary in controls:
		for m: Control in c.maps:
			var lump_name: String = m.get_node("LumpName").text
			var human_name: String = m.get_node("HumanName").text
			if  lump_name.is_empty():
				return "Missing lump name"
			if not lump_name in lumps:
				return "Unknown lump: %s" % lump_name
			if lump_name in found_lumps:
				return "Duplicate lump %s" % lump_name
			if human_name.is_empty():
				return "Unnamed map for lump %s" % lump_name
			found_lumps.push_back(lump_name)
	
	return ""


func populate(game: Dictionary) -> void:
	for e: int in controls.size():
		var control: Dictionary = controls[e]
		var episode: Dictionary = game.episodes[e]
		
		var episode_name: String = control.episode.get_node("Layout/EpisodeContainer/EpisodeName").text
		if not episode_name.is_empty():
			episode.name = episode_name
		
		var is_minor: bool = control.episode.get_node("Layout/DetailsContainer/CheckMinor").button_pressed
		if is_minor:
			episode.minor = is_minor
		
		var is_default: bool = control.episode.get_node("Layout/DetailsContainer/CheckDefault").button_pressed
		if not is_default:
			episode.default = is_default
		
		for m: int in control.maps.size():
			var lump_name: String = control.maps[m].get_node("LumpName").text
			var human_name: String = control.maps[m].get_node("HumanName").text
			episode.maps[m].lump = lump_name
			episode.maps[m].name  = human_name
