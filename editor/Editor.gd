extends VBoxContainer

signal task_complete

const PROJECT_SELECTOR := preload("res://editor/ProjectSelector.tscn")
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
	# Clear out any previous exclusive windows
	while get_last_exclusive_window() != get_window():
		get_last_exclusive_window().queue_free()
		await get_tree().process_frame
	
	print(file)
	var game := file.get_file()
	const ext := ".game.json"
	if not game.ends_with(ext):
		print("Not a .game.json file at %s", file)
		return
	game = game.left(-ext.length())
	
	var progress := PROGRESS.instantiate()
	progress.popup_exclusive_centered(self)
	
	# close world if necessary
	
	print("Starting load thread")
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
	%Items.set_world(world)
	%Connection.set_world(world)
	load_level(0)
	var id: int = %FileMenu.get_item_index(MenuOptions.Generate)
	%FileMenu.set_item_disabled(id, false)


func generate() -> void:
	if not world:
		return
	
	var progress := PROGRESS.instantiate()
	progress.popup_exclusive_centered(self)

	var thread = Thread.new()
	thread.start(func() -> void:
		Generate.generate(world)
		task_complete.emit.call_deferred()
	)
	
	await task_complete
	thread.wait_to_finish()
	
	if not world:
		Status.set_task("Failed to generate")
		progress.show_close_button()
		return
	
	progress.queue_free()



func _on_file_menu_id_pressed(id: int) -> void:
	match id:
		MenuOptions.Open:
			var selector := PROJECT_SELECTOR.instantiate()
			selector.load_game.connect(open_file)
			selector.popup_exclusive_centered(self)
		MenuOptions.Generate:
			generate()
		MenuOptions.Quit:
			# ask to save changes
			get_tree().quit()


func load_level(id: int) -> void:
	current_level = id
	var lump: String = levels[id].lump
	%MapLabel.text = levels[id].name
	%MapView.set_map(world.maps[lump], world.data.maps[id])
	%Regions.set_map_data(world.data.maps[id])
	%Items.set_map(world.maps[lump], world.data.maps[id])
