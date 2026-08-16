extends Node

var game_info : Dictionary
var items : Dictionary
var locations : Dictionary
var world_info : Dictionary

func _ready() -> void:
	game_info = JSON.parse_string(FileAccess.get_file_as_string("res://assets/json/default_game_info.json"))
	items = JSON.parse_string(FileAccess.get_file_as_string("res://assets/json/default_items.json"))
	locations = JSON.parse_string(FileAccess.get_file_as_string("res://assets/json/default_locations.json"))
	world_info = JSON.parse_string(FileAccess.get_file_as_string("res://assets/json/default_world_info.json"))
