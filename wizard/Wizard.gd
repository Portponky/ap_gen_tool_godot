extends Window

signal task_complete

const BASIC := preload("res://wizard/Basic.tscn")
const WADS := preload("res://wizard/Wads.tscn")

var current_step := -1
var current_page : Control
var game_json := {}
var wads: Array

func _ready() -> void:
	%Error.text = ""
	start_next_step()


func start_next_step() -> void:
	current_step += 1
	clear_page()
	
	match current_step:
		0:
			load_page(BASIC)
		1:
			load_page(WADS)
		2:
			if await load_wads():
				pass
			else:
				pass


func clear_page() -> void:
	if current_page:
		current_page.queue_free()


func load_page(page_scene: PackedScene) -> void:
	current_page = page_scene.instantiate()
	%Page.add_child(current_page)


func _on_next_button_pressed() -> void:
	# Let's see if the page works
	%Error.text = ""
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
