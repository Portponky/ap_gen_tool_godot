extends Window

signal load_game

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var path := "res://games/" if OS.has_feature("editor") else "%s/games" % OS.get_executable_path().get_base_dir()
	var dir := DirAccess.open(path)
	if not dir:
		print("%s don't work" % path)
		return
	
	var root: TreeItem = %Tree.create_item()
	%Tree.hide_root = true
	for filename in dir.get_files():
		print(filename)
		if not filename.ends_with(".game.json"):
			continue
		var target: TreeItem = %Tree.create_item(root)
		target.set_text(0, filename)
	
	close_requested.connect(queue_free)
	%Cancel.pressed.connect(queue_free)


func _on_accept_pressed() -> void:
	var selected: TreeItem = %Tree.get_selected()
	if not selected:
		return
	
	load_game.emit(selected.get_text(0))
	queue_free()


func _on_folder_pressed() -> void:
	var path := ProjectSettings.globalize_path("res://games/") if OS.has_feature("editor") else "%s/games" % OS.get_executable_path().get_base_dir()
	OS.shell_open(path)
