class_name PyOptions
extends Node

enum OptionType {
	Removed,
	InID1Common,

	Toggle,
	Choice,
	Range,
	OptionSet,

	BoundedRandomRange,
	CheckSanity,
	Episode,
	InvisibilityTrap,
	StartWithMaps,
	CapacitySplit,
	CapacityCount,
}

static func create(py_data_name: String, name: String, type: OptionType) -> Dictionary:
	var py_class_name := name if type == OptionType.InID1Common else py_data_name.to_pascal_case()
	return {
		py_data_name = py_data_name,
		py_class_name = py_class_name,
		name = name,
		type = type,
		has_own_class = not (name.is_empty() or type in [OptionType.Removed, OptionType.InID1Common]),
		docstring = []
	}


static func get_class_name(py_option: Dictionary) -> String:
	return py_option.py_class_name if py_option.has_own_class else get_base_class(py_option)


static func get_base_class(py_option: Dictionary) -> String:
	match py_option.type:
		OptionType.Removed: return "BaseOptions.Removed"
		OptionType.InID1Common: return "id1Options.%s" % py_option.py_class_name
		OptionType.Toggle: return "BaseOptions.DefaultOnToggle" if py_option.default_int else "BaseOptions.Toggle"
		OptionType.Choice: return "BaseOptions.Choice"
		OptionType.Range: return "BaseOptions.Range"
		OptionType.OptionSet: return "BaseOptions.OptionSet"
		OptionType.BoundedRandomRange: return "id1Options.BoundedRandomRange"
		OptionType.CheckSanity: return "id1Options.CheckSanity"
		OptionType.Episode:
			if py_option.is_minor_episode:
				return "id1Options.MinorDefaultEpisode" if py_option.default_int else "id1Options.MinorEpisode"
			return "id1Options.DefaultEpisode" if py_option.default_int else "id1Options.Episode"
		OptionType.InvisibilityTrap: return "id1Options.PartialInvisibilityAsTrap"
		OptionType.StartWithMaps: return "id1Options.StartWithComputerAreaMaps";
		OptionType.CapacitySplit: return "id1Options.SplitBagOfHolding" if py_option.split_item_count == 6 else "id1Options.SplitBackpack"
		OptionType.CapacityCount: return "id1Options.BackpackCount"
		_: return "ERROR"


static func generate_py_option_class(py_option: Dictionary) -> String:
	if not py_option.has_own_class:
		return ""
	
	var result := [
		"class %s(%s):" % [py_option.py_class_name, get_base_class(py_option)],
		"    \"\"\"",
		Python.make_indent(py_option.docstring, 4),
		"    \"\"\"",
		"    display_name = \"%s\"" % py_option.name.json_escape()
	]
	
	if py_option.has("doom_type"):
		result.push_back("    doom_type = %d" % py_option.doom_type)
	
	match py_option.type:
		OptionType.Choice:
			for opt in py_option.option_list:
				if opt.find("=") != -1:
					result.push_back("    %s" % opt)
			result.push_back("    default = %d" % [0 if py_option.default_int == -9999 else py_option.default_int])
		OptionType.BoundedRandomRange:
			if py_option.has("random_start"):
				result.push_back("    random_start = %d" % py_option.random_start)
			if py_option.has("random_end"):
				result.push_back("    random_end = %d" % py_option.random_end)
			result.push_back("    range_start = %d" % py_option.range_start)
			result.push_back("    range_end = %d" % py_option.range_end)
			result.push_back("    default = %d" % [py_option.range_end if py_option.default_int == -9999 else py_option.default_int])
		OptionType.Range:
			result.push_back("    range_start = %d" % py_option.range_start)
			result.push_back("    range_end = %d" % py_option.range_end)
			result.push_back("    default = %d" % [py_option.range_end if py_option.default_int == -9999 else py_option.default_int])
		OptionType.OptionSet:
			result.push_back("    valid_keys = (")
			for opt in py_option.option_list:
				result.push_back("        \"%s\"," % opt.json_escape())
			result.push_back("    )")
			result.push_back("    default = frozenset({")
			for opt in py_option.default_list:
				result.push_back("        \"%s\"," % opt.json_escape())
			result.push_back("    })")
	
	result.push_back("")
	result.push_back("")
	return "\n".join(result)


static func generate_data_class(py_option: Dictionary) -> String:
	var suffix := ""
	if py_option.py_data_name in ["goal_num_levels", "goal_specific_levels", "flip_levels", "difficulty"]:
		suffix = "  # type: ignore[assignment]"
	
	return "%s: %s%s" % [py_option.py_data_name, get_class_name(py_option), suffix]
