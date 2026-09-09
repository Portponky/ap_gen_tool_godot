extends Window

var lump_name := "MAP01"


func _ready() -> void:
	generate()


func generate() -> void:
	var things_count := int(%SpinThings.value)
	var sectors_count := int(%SpinSectors.value)
	var linedefs_count := int(%SpinLinedefs.value)
	var sidedefs_count := int(%SpinSidedefs.value)
	var tweaks := \
		(1 if %CheckMeta.button_pressed else 0) +\
		(1 if %CheckHub.button_pressed else 0) +\
		(1 if things_count > 0 else 0) +\
		(1 if sectors_count > 0 else 0) +\
		(1 if linedefs_count > 0 else 0) +\
		(1 if sidedefs_count > 0 else 0)
	
	var strings := [
		"    \"%s\": {" % lump_name,
		"      \"comment\": \"Comment goes here\"%s" % ending_comma(-1, tweaks)
	]
	
	var t := 0
	
	if %CheckMeta.button_pressed:
		strings.append_array([
			"      \"meta\": {",
			"        \"behaves_as\": \"normal\",",
			"        \"allow_secret_exits\": false,",
			"        \"sky_texture\": \"RSKY1\"",
			"      }%s" % ending_comma(t, tweaks)
		])
		t += 1
	
	if %CheckHub.button_pressed:
		strings.push_back("      \"hub\": {\"x\": 64, \"y\": 128, \"angle\": 0}%s" % ending_comma(t, tweaks))
		t += 1
	
	if things_count > 0:
		strings.push_back("      \"things\": {")
		for i: int in things_count:
			strings.push_back("        \"123\": {\"x\": 128, \"y\": 256, \"type\": 2013, \"angle\": 0, \"flags\": 7, \"voodoo_ignore_items\": false, \"voodoo_ignore_damage\": false, , \"flying_enemies_only\": false, , \"dont_randomize\": false}%s" % ending_comma(i, things_count))
		strings.push_back("      }%s" % ending_comma(t, tweaks))
		t += 1
	
	if sectors_count > 0:
		strings.push_back("      \"sectors\": {")
		for i: int in sectors_count:
			strings.push_back("        \"123\": {\"special\": 10, \"tag\": 5, \"floor\": 0, \"ceiling\": 128, \"floor_pic\": \"FLAT1\", \"ceiling_pic\": \"FLAT2\"}%s" % ending_comma(i, sectors_count))
		strings.push_back("      }%s" % ending_comma(t, tweaks))
		t += 1
	
	if linedefs_count > 0:
		strings.push_back("      \"linedefs\": {")
		for i: int in linedefs_count:
			strings.push_back("        \"123\": {\"special\": 10, \"tag\": 5, \"flags\": 0}%s" % ending_comma(i, linedefs_count))
		strings.push_back("      }%s" % ending_comma(t, tweaks))
		t += 1
	
	if sidedefs_count > 0:
		strings.push_back("      \"sidedefs\": {")
		for i: int in sidedefs_count:
			strings.push_back("        \"123\": {\"x\": 0, \"y\": 0, \"lower\": \"GRAYTALL\", \"middle\": \"GRAYTALL\", \"upper\": \"GRAYTALL\"}%s" % ending_comma(i, sidedefs_count))
		strings.push_back("      }%s" % ending_comma(t, tweaks))
		t += 1
	
	strings.push_back("    }")
	%TweakEdit.text = "\n".join(strings)


func ending_comma(n: int, length: int) -> String:
	return "" if n == length - 1 else ","


func _on_toggled(_toggled_on: bool) -> void:
	generate()


func _on_value_changed(_value: float) -> void:
	generate()


func _on_close_requested() -> void:
	queue_free()
