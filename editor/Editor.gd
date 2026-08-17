extends VBoxContainer

signal task_complete

const PROGRESS := preload("res://editor/Progress.tscn")

enum MenuOptions {
	Open,
	Generate,
	Quit,
}

var world: World
var levels : Array[Dictionary]
var current_level: int

func _ready() -> void:
	%FileMenu.add_item("Open", MenuOptions.Open, KEY_MASK_CMD_OR_CTRL | KEY_O)
	%FileMenu.add_item("Generate APWorld", MenuOptions.Generate, KEY_MASK_CMD_OR_CTRL | KEY_G)
	%FileMenu.set_item_disabled(1, true)
	%FileMenu.add_item("Quit", MenuOptions.Quit, KEY_MASK_CMD_OR_CTRL | KEY_Q)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_PAGEDOWN and current_level < levels.size() - 1:
			load_level(current_level + 1)
		elif event.pressed and event.keycode == KEY_PAGEUP and current_level > 0:
			load_level(current_level - 1)



func open_file(file: String) -> void:
	var game := file.get_file()
	const ext := ".game.json"
	if not game.ends_with(ext):
		return
	game = game.left(-ext.length())
	
	var progress := PROGRESS.instantiate()
	progress.popup_exclusive_centered(self)
	
	# close world if necessary
	
	var thread := Thread.new()
	thread.start(func() -> void:
		world = World.load(game)
		task_complete.emit.call_deferred()
	)
	
	await task_complete
	thread.wait_to_finish()
	
	if not world:
		Status.set_task("Failed to load %s" % file.get_file())
		progress.show_close_button()
		return
	
	progress.queue_free()
	
	%MapMenu.clear(true)
	levels.clear()
	
	for ep: int in world.game.episodes.size():
		var episode: Dictionary = world.game.episodes[ep]
		var episode_menu := PopupMenu.new()
		for map: Dictionary in episode.maps:
			episode_menu.add_item(map.name, levels.size())
			levels.push_back({
				lump = map.lump,
				name = map.name
			})
		episode_menu.id_pressed.connect(load_level)
		%MapMenu.add_submenu_node_item(episode.get("name", "Episode %d" % (ep + 1)), episode_menu)
	
	%MapView.set_world(world)
	load_level(0)


func _on_file_menu_id_pressed(id: int) -> void:
	match id:
		MenuOptions.Open:
			var fd := FileDialog.new()
			fd.use_native_dialog = true
			fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
			fd.add_filter("*.game.json", "APDoom games", "application/json")
			fd.current_dir = "res://games/"
			fd.root_subfolder = "res://games/"
			fd.favorites_enabled = false
			fd.file_filter_toggle_enabled = false
			add_child(fd)
			
			fd.canceled.connect(fd.queue_free)
			fd.file_selected.connect(open_file)
			fd.file_selected.connect(func(_x: String) -> void: fd.queue_free())
			
			fd.popup_centered_clamped()
		MenuOptions.Generate:
			pass
		MenuOptions.Quit:
			# ask to save changes
			get_tree().quit()


func load_level(id: int) -> void:
	current_level = id
	var lump: String = levels[id].lump
	%MapLabel.text = levels[id].name
	%MapView.set_map(world.maps[lump], world.data.maps[id])
