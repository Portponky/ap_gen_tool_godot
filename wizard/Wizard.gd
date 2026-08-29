extends Control


func _on_next_button_pressed() -> void:
	# Let's see if the page works
	var game_json := {}
	%Basic.populate(game_json)
