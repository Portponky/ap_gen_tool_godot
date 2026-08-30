extends Window

var pages = [
	preload("res://wizard/Basic.tscn"),
	preload("res://wizard/Wads.tscn")
]

var current_page_index := -1
var current_page : Control


func _ready() -> void:
	%Error.text = ""
	load_next_page()


func load_next_page() -> void:
	current_page_index += 1
	if current_page:
		current_page.queue_free()
	
	current_page = pages[current_page_index].instantiate()
	%Page.add_child(current_page)


func _on_next_button_pressed() -> void:
	# Let's see if the page works
	var game_json := {}
	%Error.text = ""
	
	var error: String = current_page.verify(game_json)
	
	if not error.is_empty():
		%Error.text = error
	else:
		current_page.populate(game_json)
		load_next_page()


func _on_quit_button_pressed() -> void:
	pass # Replace with function body.
