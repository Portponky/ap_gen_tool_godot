extends Node

var game_info
var items
var locations
var world_info

func _ready() -> void:
	game_info = JSON.parse_string(FileAccess.get_file_as_string("res://assets/json/default_game_info.json"))
	items = JSON.parse_string(FileAccess.get_file_as_string("res://assets/json/default_items.json"))
	locations = JSON.parse_string(FileAccess.get_file_as_string("res://assets/json/default_locations.json"))
	world_info = JSON.parse_string(FileAccess.get_file_as_string("res://assets/json/default_world_info.json"))
