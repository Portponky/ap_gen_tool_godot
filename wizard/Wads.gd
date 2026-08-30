extends VBoxContainer


func _on_wad_folder_button_pressed() -> void:
	var path := ProjectSettings.globalize_path("res://wads/") if OS.has_feature("editor") else "%s/wads" % OS.get_executable_path().get_base_dir()
	OS.shell_open(path)


func clean_list_from_text(text: String) -> Array:
	var wads: Array = text.split("\n")
	for i: int in wads.size():
		wads[i].remove_chars("\t\r ")
	wads = wads.filter(func(x: String) -> bool: return not x.is_empty())
	return wads


func assign_wad_list(game: Dictionary, key: String, text: String) -> void:
	var wads := clean_list_from_text(text)
	
	if wads.size() == 1:
		game[key] = wads[0]
	elif wads.size() > 1:
		game[key] = wads


func verify(_game: Dictionary) -> String:
	var required := clean_list_from_text(%TextEditRequired.text)
	if required.is_empty():
		return "Need at least one required WAD file"
	
	required.append_array(clean_list_from_text(%TextEditIncluded.text))
	var path := "res://" if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()
	for file: String in required:
		# check file is accessible in wads folder
		var full_path := "%s/wads/%s" % [path, file]
		if not FileAccess.file_exists(full_path):
			return "%s not found in wads folder" % file
	
	return ""


func populate(game: Dictionary) -> void:
	assign_wad_list(game, "required_wads", %TextEditRequired.text)
	assign_wad_list(game, "optional_wads", %TextEditOptional.text)
	assign_wad_list(game, "included_wads", %TextEditIncluded.text)
