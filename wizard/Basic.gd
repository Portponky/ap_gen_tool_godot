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
	return ""


func populate(game: Dictionary) -> void:
	var iwad_id: int = %OptionIwad.get_selected_id()
	var iwad: Dictionary = IWAD_DETAILS[iwad_id]
	
	game.short_name = %LineEditShortName.text
	game.full_name = %LineEditFullName.text
	game.ap_name = "%s - %s" % [iwad.name, game.full_name]
	game.ap_world_name = "%s_%s" % [iwad.world_name, game.short_name]
	game.iwad = iwad.filename
