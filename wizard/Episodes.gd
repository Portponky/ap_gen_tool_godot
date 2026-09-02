extends VBoxContainer

const MAX_EPISODES := 8

var episode_labels := []
var episode_spinners := []

var current_total := 0
var required_total := 0

func _ready() -> void:
	for n: int in MAX_EPISODES:
		var label := Label.new()
		label.text = "Episode %d:" % (n + 1)
		label.visible = false
		%EpisodeContainer.add_child(label)
		episode_labels.append(label)
		
		var spin := SpinBox.new()
		spin.min_value = 1
		spin.max_value = 12
		spin.visible = false
		spin.value_changed.connect(_on_level_value_changed)
		%EpisodeContainer.add_child(spin)
		episode_spinners.append(spin)


func episode_for_map(map: String) -> int:
	if map.begins_with("MAP"):
		if map <= "MAP11": return 1
		if map <= "MAP20": return 2
		if map <= "MAP30": return 3
		return 4
	if map.begins_with("E"):
		return clampi(int(map[1]), 1, 8)
	return 1


func set_map_list(game: Dictionary) -> void:
	required_total = game.maps.size()
	
	var episodes := {}
	for map: String in game.maps:
		var episode := episode_for_map(map)
		episodes.get_or_add(episode, 0)
		episodes[episode] += 1
	
	var numeric_episodes := episodes.keys()
	numeric_episodes.sort()
	for index: int in numeric_episodes.size():
		var key: int = numeric_episodes[index]
		episode_spinners[index].value = episodes[key]
	
	%SpinBoxEpisode.value = numeric_episodes.size()


func verify(_game: Dictionary) -> String:
	if required_total != current_total:
		return "Levels numbers do not match"
	return ""


func populate(game: Dictionary) -> void:
	game.episodes = []
	for i: int in int(%SpinBoxEpisode.value):
		game.episodes.push_back(int(episode_spinners[i].value))


func _on_spin_box_episode_value_changed(value: float) -> void:
	var episodes := int(value)
	for n in MAX_EPISODES:
		episode_labels[n].visible = n < episodes
		episode_spinners[n].visible = n < episodes
	
	_on_level_value_changed()


func _on_level_value_changed(_value := 0.0) -> void:
	current_total = 0
	for n in MAX_EPISODES:
		if episode_spinners[n].visible:
			current_total += int(episode_spinners[n].value)
	
	if %CheckCredits.button_pressed:
		current_total += 1
	
	%LabelTotal.text = "Total: %d / %d" % [current_total, required_total]


func _on_check_credits_toggled(_toggled_on: bool) -> void:
	_on_level_value_changed()
