extends VBoxContainer

const IWAD_DETAILS = [
	{
		name = "DOOM",
		world = "doom",
		filename = "DOOM.WAD"
	},
	{
		name = "DOOM II",
		world = "doom2",
		filename = "DOOM2.WAD"
	},
	{
		name = "TNT",
		world = "tnt",
		filename = "TNT.WAD"
	},
	{
		name = "Plutonia",
		world = "plutonia",
		filename = "PLUTONIA.WAD"
	},
	{
		name = "Heretic",
		world = "heretic",
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
	
	game.iwad = IWAD_DETAILS[iwad_id]
	game.short_name = %LineEditShortName.text
	game.full_name = %LineEditFullName.text
	
	var authors: String = %LineEditAuthor.text
	if authors.is_empty():
		game.authors = []
	else:
		game.authors = Array(authors.split(",")).map(func(x: String) -> String: return x.strip_edges())
	
	var description: String = %TextEditDescription.text
	if description.is_empty():
		game.description = []
	else:
		game.description = description.split("\n")
	
