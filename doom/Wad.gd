class_name Wad
extends Resource

class Lump:
	var name: String
	var offset: int
	var size: int

var file: FileAccess
var path: String
var lumps: Array[Lump]
var lump_names := {}


static func get_fixed_text(file_access: FileAccess, length: int) -> String:
	return file_access.get_buffer(length).get_string_from_ascii()


static func load(wad_path: String) -> Wad:
	if not FileAccess.file_exists(wad_path):
		return null
	
	var wad := Wad.new()
	wad.path = wad_path
	wad.file = FileAccess.open(wad_path, FileAccess.READ)
	
	var header: String = get_fixed_text(wad.file, 4)
	if header != "PWAD" and header != "IWAD":
		push_warning("This ain't a wad file lol")
		return null
	
	var num_lumps := wad.file.get_32()
	var directory_offset := wad.file.get_32()
	
	print("Loading %d lumps from %s" % [num_lumps, wad_path])
	
	wad.file.seek(directory_offset)
	for i in num_lumps:
		var dir := Lump.new()
		dir.offset = wad.file.get_32()
		dir.size = wad.file.get_32()
		dir.name = get_fixed_text(wad.file, 8)
		wad.lumps.append(dir)
		wad.lump_names[dir.name] = true
	
	return wad


func has_lump(name: String) -> bool:
	return lump_names.has(name)


func load_lump(name: String, category := "") -> PackedByteArray:
	var i := 0
	if not category.is_empty():
		while i < lumps.size():
			if lumps[i].name == category:
				break
			i += 1
	
	while i < lumps.size():
		if lumps[i].name == name:
			file.seek(lumps[i].offset)
			return file.get_buffer(lumps[i].size)
		i += 1
	
	return PackedByteArray()
