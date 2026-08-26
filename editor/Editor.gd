extends VBoxContainer

signal task_complete

const PROJECT_SELECTOR := preload("res://editor/ProjectSelector.tscn")
const PROGRESS := preload("res://editor/Progress.tscn")

enum MenuChoice {
	Open,
	Save,
	Close,
	Generate,
	Quit,
	
	Undo,
	Redo,
	Delete,
	
	FilterKeys,
	FilterGuns,
	LocationAPs,
	
	ToolSectors,
	ToolRules,
	ToolItems,
	ToolBoxes,
	
	PreviousLevel,
	NextLevel,
}

var world_stem : String
var world: World
var levels : Array[Dictionary]

var undo := UndoRedo.new()
var current_level: int
var current_map: Map
var modified := false

var current_region := -1
var current_location := -1

func _ready() -> void:
	%Items.undo = undo
	%Regions.undo = undo
	%Connections.undo = undo
	%MapView.undo = undo
	undo.version_changed.connect(_on_modified)
	
	add_menu_shortcut(%FileMenu, "Open", MenuChoice.Open, KEY_O, true, false)
	add_menu_shortcut(%FileMenu, "Save", MenuChoice.Save, KEY_S, true, false)
	add_menu_shortcut(%FileMenu, "Generate APWorld", MenuChoice.Generate, KEY_G, true, false)
	add_menu_shortcut(%FileMenu, "Close", MenuChoice.Close, KEY_W, true, false)
	add_menu_shortcut(%FileMenu, "Quit", MenuChoice.Quit, KEY_Q, true, false)
	
	add_menu_shortcut(%EditMenu, "Undo", MenuChoice.Undo, KEY_Z, true, false)
	add_menu_shortcut(%EditMenu, "Redo", MenuChoice.Redo, KEY_Z, true, true)
	%EditMenu.add_separator()
	add_menu_shortcut(%EditMenu, "Delete", MenuChoice.Delete, KEY_DELETE, false, false)
	%EditMenu.add_separator()
	%EditMenu.add_check_item("Filter connection keys", MenuChoice.FilterKeys)
	%EditMenu.add_check_item("Filter connection weapons", MenuChoice.FilterGuns)
	%EditMenu.add_check_item("Show complete locations as APs", MenuChoice.LocationAPs)
	
	add_menu_shortcut(%ToolMenu, "Region assignment", MenuChoice.ToolSectors, KEY_F1, false, false)
	add_menu_shortcut(%ToolMenu, "Rules and connections", MenuChoice.ToolRules, KEY_F2, false, false)
	add_menu_shortcut(%ToolMenu, "Items", MenuChoice.ToolItems, KEY_F3, false, false)
	add_menu_shortcut(%ToolMenu, "Bounding boxes", MenuChoice.ToolBoxes, KEY_F4, false, false)
	
	enable_specific_menus(false)
	_execute_menu_choice(MenuChoice.ToolSectors)
	
	await get_tree().process_frame
	update_menu_checks()


func add_menu_shortcut(menu: PopupMenu, title: String, id: int, keycode: Key, ctrl: bool, shift: bool) -> void:
	var input := InputEventKey.new()
	input.keycode = keycode
	input.command_or_control_autoremap = ctrl
	input.shift_pressed = shift
	
	var shortcut := Shortcut.new()
	shortcut.events = [input]
	shortcut.resource_name = title
	
	menu.add_shortcut(shortcut, id, true)


func open(file: String) -> void:
	# Clear out any previous exclusive windows
	while get_last_exclusive_window() != get_window():
		get_last_exclusive_window().queue_free()
		await get_tree().process_frame
	
	# generate world stem
	var game := file.get_file()
	const ext := ".game.json"
	if not game.ends_with(ext):
		print("Not a .game.json file at %s", file)
		return
	world_stem = game.left(-ext.length())
	
	var progress := PROGRESS.instantiate()
	progress.popup_exclusive_centered(self)
	
	var thread := Thread.new()
	thread.start(func() -> void:
		world = World.load(world_stem)
		task_complete.emit.call_deferred()
	)
	
	await task_complete
	thread.wait_to_finish()
	
	if not world:
		Status.set_task("Failed to load %s" % file.get_file())
		progress.show_close_button()
		return
	
	progress.queue_free()
	
	# Sort out menus
	enable_specific_menus(true)
	
	%MapMenu.clear(true)
	add_menu_shortcut(%MapMenu, "Previous level", MenuChoice.PreviousLevel, KEY_PAGEUP, false, false)
	add_menu_shortcut(%MapMenu, "Next level", MenuChoice.NextLevel, KEY_PAGEDOWN, false, false)
	%MapMenu.add_separator()
	
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
	
	# init to first level
	%MapView.set_world(world)
	%Items.set_world(world)
	%Connections.set_world(world)
	load_level(0)


func save() -> void:
	if not world or not modified:
		return
	
	var path := "res://data/" if OS.has_feature("editor") else "%s/data" % OS.get_executable_path().get_base_dir()
	var target := "%s/%s.data.json" % [path, world_stem]
	
	var backup := "%s.back" % target
	if FileAccess.file_exists(target):
		if FileAccess.file_exists(backup):
			DirAccess.remove_absolute(backup)
		DirAccess.rename_absolute(target, backup)
	
	var save_file := FileAccess.open(target, FileAccess.WRITE)
	save_file.store_string(JSON.stringify(world.data))
	save_file.close()
	
	modified = false


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


func close() -> void:
	if not world:
		return
	
	%MapView.clear_world()
	%Items.clear_world()
	%Regions.clear_world()
	%Connections.clear_world()
	
	world = null
	
	# Sort out menus
	enable_specific_menus(false)
	
	%MapMenu.clear(true)
	%MapMenu.title = "Maps"
	%MapMenu.add_item("No game loaded")
	%MapMenu.set_item_disabled(0, true)
	
	modified = false


func enable_specific_menus(enabled: bool) -> void:
	%FileMenu.set_item_disabled(%FileMenu.get_item_index(MenuChoice.Save), not enabled)
	%FileMenu.set_item_disabled(%FileMenu.get_item_index(MenuChoice.Generate), not enabled)
	%FileMenu.set_item_disabled(%FileMenu.get_item_index(MenuChoice.Close), not enabled)
	
	%EditMenu.set_item_disabled(%EditMenu.get_item_index(MenuChoice.Undo), not enabled)
	%EditMenu.set_item_disabled(%EditMenu.get_item_index(MenuChoice.Redo), not enabled)


func update_menu_checks() -> void:
	var items := {
		MenuChoice.FilterKeys: Settings.filter_connection_keys,
		MenuChoice.FilterGuns: Settings.filter_connection_guns,
		MenuChoice.LocationAPs: Settings.locations_as_aps
	}
	
	for choice: int in items:
		var index: int = %EditMenu.get_item_index(choice)
		%EditMenu.set_item_checked(index, items[choice])


func _execute_menu_choice(id: int) -> void:
	match id:
		MenuChoice.Open:
			var selector := PROJECT_SELECTOR.instantiate()
			selector.load_game.connect(open)
			selector.popup_exclusive_centered(self)
		MenuChoice.Save:
			if modified:
				save()
		MenuChoice.Close:
			close()
		MenuChoice.Generate:
			generate()
		MenuChoice.Quit:
			# ask to save changes
			get_tree().quit()
		
		MenuChoice.Undo:
			undo.undo()
			%MapView.refresh()
		MenuChoice.Redo:
			undo.redo()
			%MapView.refresh()
		MenuChoice.Delete:
			%MapView.handle_delete()
		MenuChoice.FilterKeys:
			Settings.filter_connection_keys = not Settings.filter_connection_keys
			update_menu_checks()
			%Connections.update_filters(current_map)
		MenuChoice.FilterGuns:
			Settings.filter_connection_guns = not Settings.filter_connection_guns
			update_menu_checks()
			%Connections.update_filters(current_map)
		MenuChoice.LocationAPs:
			Settings.locations_as_aps = not Settings.locations_as_aps
			update_menu_checks()
			%Items.refresh()
		
		
		MenuChoice.ToolSectors:
			if %MapView.set_tool(%SectorPaintTool):
				%ToolLabel.text = "Sectors"
				%MapView.refresh()
		MenuChoice.ToolRules:
			if %MapView.set_tool(%ModifyRuleTool):
				%ToolLabel.text = "Rules"
				%MapView.refresh()
		MenuChoice.ToolItems:
			if %MapView.set_tool(%ItemTool):
				%ToolLabel.text = "Items"
				%MapView.refresh()
		MenuChoice.ToolBoxes:
			if %MapView.set_tool(%BoundingBoxTool):
				%ToolLabel.text = "Bounding boxes"
				%MapView.refresh()
		
		MenuChoice.PreviousLevel:
			if current_level > 0:
				load_level(current_level - 1)
		MenuChoice.NextLevel:
			if current_level < levels.size() - 1:
				load_level(current_level + 1)


func _on_modified() -> void:
	modified = true


func load_level(id: int) -> void:
	var tool: MapTool = %MapView.tool
	if not %MapView.set_tool(null):
		return
	
	current_level = id
	var lump: String = levels[id].lump
	current_map = world.maps[lump]
	var map_data: Dictionary = world.data.maps[id]
	%MapMenu.title = levels[id].name
	%MapView.set_map(current_map, map_data)
	%Regions.set_map_data(map_data)
	%Items.set_map(current_map, map_data)
	%Connections.set_map_data(map_data)
	%Connections.update_filters(current_map)
	%MapView.set_tool(tool)
	undo.clear_history()
