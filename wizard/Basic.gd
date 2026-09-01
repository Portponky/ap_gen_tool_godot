extends VBoxContainer

const IWAD_DETAILS = [
	{
		name = "DOOM",
		world_name = "doom",
		filename = "DOOM.WAD"
	},
	{
		name = "DOOM II",
		world_name = "doom2",
		filename = "DOOM2.WAD"
	},
	{
		name = "TNT",
		world_name = "tnt",
		filename = "TNT.WAD"
	},
	{
		name = "Plutonia",
		world_name = "plutonia",
		filename = "PLUTONIA.WAD"
	},
	{
		name = "Heretic",
		world_name = "heretic",
		filename = "HERETIC.WAD"
	}
]

var short_name_check := RegEx.create_from_string("[^a-z0-9]")



func verify(_game: Dictionary) -> String:
	if %OptionIwad.get_selected_id() == -1:
		return "No IWAD selected"
	if %LineEditFullName.text.is_empty():
		return "Enter a full name"
	if %LineEditShortName.text.is_empty():
		return "Enter a short name"
	if short_name_check.search_all(%LineEditShortName.text).size() > 0:
		return "Short name should be lower case character, numbers, or underscores"
	
	var path := ProjectSettings.globalize_path("res://games/") if OS.has_feature("editor") else "%s/games" % OS.get_executable_path().get_base_dir()
	var target := "%s/%s.game.json" % [path, %LineEditShortName.text]
	if FileAccess.file_exists(target):
		return "%s.game.json already exists in games directory" % %LineEditShortName.text
	
	return ""


func populate(game: Dictionary) -> void:
	var iwad_id: int = %OptionIwad.get_selected_id()
	var iwad: Dictionary = IWAD_DETAILS[iwad_id]
	
	game.short_name = %LineEditShortName.text
	game.full_name = %LineEditFullName.text
	game.ap_name = "%s - %s" % [iwad.name, game.full_name]
	game.ap_world_name = "%s_%s" % [iwad.world_name, game.short_name]
	game.iwad = iwad.filename
	
	var author: String = %LineEditAuthor.text
	if not author.is_empty():
		game.authors = Array(author.split(",")).map(func(x: String) -> String: return x.strip_edges())
	
	game.world_info = {
		world_options = [
			{name = "Difficulty", preset = "Doom"},
			{name = "Start with Maps"},
			{name = "Invis as Trap"},
			{name = "Capacity Upgrades"},
			{name = "Custom Ammo Capacity"}
		]
	}
	
	var description = %TextEditDescription.text
	if not description.is_empty():
		game.world_info.description = description.split("\n")
	
	game.settings = { extended_names = true }
	game.map_tweaks = {}
	
