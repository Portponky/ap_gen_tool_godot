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


func assign_wad_list(game: Dictionary, key: String, list: String) -> void:
	var wads: Array = list.split("\n")
	for i: int in wads.size():
		wads[i].remove_chars("\t\r ")
	wads = wads.filter(func(x: String) -> bool: return not x.is_empty())
	
	if wads.size() == 1:
		game[key] = wads[0]
	elif wads.size() > 1:
		game[key] = wads


func populate(game: Dictionary) -> void:
	var iwad_id: int = %OptionIwad.get_selected_id()
	var iwad: Dictionary = IWAD_DETAILS[iwad_id]
	
	game.short_name = %LineEditShortName.text
	game.full_name = %LineEditFullName.text
	game.ap_name = "%s - %s" % [iwad.name, game.full_name]
	game.ap_world_name = "%s_%s" % [iwad.world_name, game.short_name]
	game.iwad = iwad.filename
	assign_wad_list(game, "required_wads", %TextEditRequired.text)
	assign_wad_list(game, "optional_wads", %TextEditOptional.text)
	assign_wad_list(game, "included_wads", %TextEditIncluded.text)

	print(game)
