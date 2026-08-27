class_name Map
extends Resource

const SUBSECTOR_FLAG = 0x8000

class Thing:
	var x: int
	var y: int
	var angle: int
	var type: int
	var flags: int
	
	enum Flags {
		Easy = 0x0001,
		Medium = 0x0002,
		Hard = 0x0004,
		Ambush = 0x0008,
		Multiplayer = 0x0010
	}

class Linedef:
	var start_vertex : int
	var end_vertex: int
	var flags: int
	var special_type: int
	var sector_tag: int
	var front_sidedef: int
	var back_sidedef: int
	
	var color := Color.WHITE
	var front_sector := -1
	var back_sector := -1
	enum Flags {
		Blocking = 0x0001,
		BlockMonsters = 0x0002,
		TwoSided = 0x0004,
		UnpeggedTop = 0x0008,
		UnpeggedBottom = 0x0010,
		Secret = 0x0020,
		SoundBlocking = 0x0040,
		NeverMap = 0x0080,
		AlwaysMap = 0x0100
	}

class Sidedef:
	var x_offset: int
	var y_offset: int
	var upper_texture: String
	var lower_texture: String
	var middle_texture: String
	var sector: int

class Sector:
	var floor_height: int
	var ceiling_height: int
	var floor_texture: String
	var ceiling_texture: String
	var light_level: int
	var type: int
	var tag: int
	
	var polygons: Array[PackedVector2Array]
	var mesh: Mesh

class Subsector:
	var numsegs: int
	var firstseg: int
	var sector: int # discerned at runtime

class BSPNode:
	var pos: Vector2i
	var cut: Vector2i
	var bbox := [Rect2i(), Rect2i()]
	var children := [-1, -1]

class Seg:
	var v1 : int
	var v2 : int
	var angle : int
	var linedef : int
	var side : int
	var offset : int


var things: Array[Thing]
var linedefs: Array[Linedef]
var sidedefs: Array[Sidedef]
var vertices: Array[Vector2i]
var sectors: Array[Sector]
var subsectors: Array[Subsector]
var nodes: Array[BSPNode]
var segs: Array[Seg]

var bbox: Rect2i
var lines: Dictionary[Color, PackedVector2Array]

static func load_things(map: Map, things_lump: PackedByteArray) -> void:
	for i in range(0, things_lump.size(), 10):
		var thing: = Thing.new()
		thing.x = things_lump.decode_s16(i + 0)
		thing.y = things_lump.decode_s16(i + 2)
		thing.angle = things_lump.decode_s16(i + 4)
		thing.type = things_lump.decode_s16(i + 6)
		thing.flags = things_lump.decode_s16(i + 8)
		map.things.push_back(thing)


static func load_linedefs(map: Map, linedefs_lump: PackedByteArray, heretic_specials: bool) -> void:
	for i in range(0, linedefs_lump.size(), 14):
		var linedef := Linedef.new()
		linedef.start_vertex = linedefs_lump.decode_s16(i + 0)
		linedef.end_vertex = linedefs_lump.decode_s16(i + 2)
		linedef.flags = linedefs_lump.decode_s16(i + 4)
		linedef.special_type = linedefs_lump.decode_s16(i + 6)
		linedef.sector_tag = linedefs_lump.decode_s16(i + 8)
		linedef.front_sidedef = linedefs_lump.decode_s16(i + 10)
		linedef.back_sidedef = linedefs_lump.decode_s16(i + 12)
		
		# Pick color
		if linedef.flags & (Linedef.Flags.Blocking | Linedef.Flags.TwoSided) == Linedef.Flags.TwoSided:
			linedef.color = Color.DIM_GRAY
		
		if heretic_specials:
			if linedef.special_type in [26, 32]:
				linedef.color = Color.BLUE
			elif linedef.special_type in [28, 33]:
				linedef.color = Color.GREEN
			elif linedef.special_type in [27, 34]:
				linedef.color = Color.YELLOW
			elif linedef.special_type in [11, 51, 52, 105]:
				linedef.color = Color.MAGENTA
		else:
			if linedef.special_type in [26, 32, 99, 133]:
				linedef.color = Color.BLUE
			elif linedef.special_type in [28, 33, 134, 135]:
				linedef.color = Color.RED
			elif linedef.special_type in [27, 34, 136, 137]:
				linedef.color = Color.YELLOW
			elif linedef.special_type in [11, 51, 52, 124]:
				linedef.color = Color.MAGENTA
		
		map.linedefs.push_back(linedef)


static func load_sidedefs(map: Map, sidedefs_lump: PackedByteArray) -> void:
	for i in range(0, sidedefs_lump.size(), 30):
		var sidedef := Sidedef.new()
		sidedef.x_offset = sidedefs_lump.decode_s16(i + 0)
		sidedef.y_offset = sidedefs_lump.decode_s16(i + 2)
		sidedef.upper_texture = sidedefs_lump.slice(i + 4, i + 4 + 8).get_string_from_ascii()
		sidedef.lower_texture = sidedefs_lump.slice(i + 12, i + 12 + 8).get_string_from_ascii()
		sidedef.middle_texture = sidedefs_lump.slice(i + 20, i + 20 + 8).get_string_from_ascii()
		sidedef.sector = sidedefs_lump.decode_s16(i + 28)
		map.sidedefs.push_back(sidedef)


static func load_vertices(map: Map, vertices_lump: PackedByteArray) -> void:
	for i in range(0, vertices_lump.size(), 4):
		var x : int = vertices_lump.decode_s16(i + 0)
		var y : int = vertices_lump.decode_s16(i + 2)
		map.vertices.push_back(Vector2i(x, y))


static func load_sectors(map: Map, sectors_lump: PackedByteArray) -> void:
	for i in range(0, sectors_lump.size(), 26):
		var sector := Sector.new()
		sector.floor_height = sectors_lump.decode_s16(i + 0)
		sector.ceiling_height = sectors_lump.decode_s16(i + 2)
		sector.floor_texture = sectors_lump.slice(i + 4, i + 4 + 8).get_string_from_ascii()
		sector.ceiling_texture = sectors_lump.slice(i + 12, i + 12 + 8).get_string_from_ascii()
		sector.light_level = sectors_lump.decode_s16(i + 20)
		sector.type = sectors_lump.decode_s16(i + 22)
		sector.tag = sectors_lump.decode_s16(i + 24)
		map.sectors.push_back(sector)


static func load_subsectors(map: Map, ssectors_lump: PackedByteArray) -> void:
	for i in range(0, ssectors_lump.size(), 4):
		var subsector := Subsector.new()
		subsector.numsegs = ssectors_lump.decode_s16(i + 0)
		subsector.firstseg = ssectors_lump.decode_s16(i + 2)
		map.subsectors.push_back(subsector)


static func load_nodes(map: Map, nodes_lump: PackedByteArray) -> void:
	for i in range(0, nodes_lump.size(), 28):
		var node := BSPNode.new()
		var x : int = nodes_lump.decode_s16(i + 0)
		var y : int = nodes_lump.decode_s16(i + 2)
		node.pos = Vector2i(x, y)
		var x2 : int = nodes_lump.decode_s16(i + 4)
		var y2 : int = nodes_lump.decode_s16(i + 6)
		node.cut = Vector2i(x2, y2)
		x = nodes_lump.decode_s16(i + 8)
		x2 = nodes_lump.decode_s16(i + 10)
		y = nodes_lump.decode_s16(i + 12)
		y2 = nodes_lump.decode_s16(i + 14)
		node.bbox[0] = Rect2i(x, y, x2 - x, y2 - y)
		x = nodes_lump.decode_s16(i + 16)
		x2 = nodes_lump.decode_s16(i + 18)
		y = nodes_lump.decode_s16(i + 20)
		y2 = nodes_lump.decode_s16(i + 22)
		node.bbox[1] = Rect2i(x, y, x2 - x, y2 - y)
		node.children[0] = nodes_lump.decode_u16(i + 24)
		node.children[1] = nodes_lump.decode_u16(i + 26)
		map.nodes.push_back(node)


static func load_segs(map: Map, segs_lump: PackedByteArray) -> void:
	for i in range(0, segs_lump.size(), 12):
		var seg := Seg.new()
		seg.v1 = segs_lump.decode_u16(i + 0)
		seg.v2 = segs_lump.decode_u16(i + 2)
		seg.angle = segs_lump.decode_s16(i + 4)
		seg.linedef = segs_lump.decode_u16(i + 6)
		seg.side = segs_lump.decode_s16(i + 8)
		seg.offset = segs_lump.decode_s16(i + 10)
		map.segs.push_back(seg)

static func cut_convex_polygon(polygon: PackedVector2Array, pos: Vector2, cut: Vector2) -> PackedVector2Array:
	var result: PackedVector2Array = []
	var delta := cut.normalized()
	
	const epsilon = 0.01
	for j in polygon.size():
		var a := polygon[j - 1]
		var b := polygon[j]
		var a_on_line := pos + delta * (a - pos).dot(delta)
		var b_on_line := pos + delta * (b - pos).dot(delta)
		if a_on_line.distance_to(a) < epsilon and b_on_line.distance_to(b) < epsilon:
			result.push_back(a)
			continue
		
		var a_side := cut.cross(a - pos) > 0.0
		var b_side := cut.cross(b - pos) > 0.0
		if a_side:
			result.push_back(a);
		if a_side != b_side:
			var d :=  b - a
			var t := (pos - a).cross(cut) / d.cross(cut)
			result.push_back(a + d * t)
	
	return result


static func triangulate_subsector(map: Map, subsector_id: int, polygon: PackedVector2Array) -> void:
	var subsector := map.subsectors[subsector_id]
	
	var clip := polygon
	for i in subsector.numsegs:
		var seg := map.segs[subsector.firstseg + i]
		var v1 := map.vertices[seg.v1]
		var v2 := map.vertices[seg.v2]
		clip = cut_convex_polygon(clip, Vector2(v1), Vector2(v1 - v2))
	
	for i in clip.size():
		clip[i].y = -clip[i].y
	
	if polygon.size() >= 3:
		var sector := map.sectors[subsector.sector]
		sector.polygons.push_back(clip)


static func triangulate_node(map: Map, node_id: int, polygon: PackedVector2Array) -> void:
	if node_id & SUBSECTOR_FLAG:
		triangulate_subsector(map, node_id & ~SUBSECTOR_FLAG, polygon)
		return
	
	var node := map.nodes[node_id]
	triangulate_node(map, node.children[0], cut_convex_polygon(polygon, Vector2(node.pos), -Vector2(node.cut)))
	triangulate_node(map, node.children[1], cut_convex_polygon(polygon, Vector2(node.pos), Vector2(node.cut)))


static func build_mesh(sector: Sector) -> void:
	var verts := PackedVector3Array()
	for polygon in sector.polygons:
		var indices := Geometry2D.triangulate_polygon(polygon)
		for i in indices:
			verts.push_back(Vector3(polygon[i].x, polygon[i].y, 0.0))
	
	if verts.is_empty():
		return
	
	var array_mesh := ArrayMesh.new()
	
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	sector.mesh = array_mesh


static func load(world: World, map_lump: String, heretic_specials: bool) -> Map:
	var load_wad := world.wad_for_lump(map_lump)
	if not load_wad:
		Status.add_error("Unable to find lump %s" % map_lump)
		return null
	
	var map := Map.new()
	load_things(map, load_wad.load_lump("THINGS", map_lump))
	load_linedefs(map, load_wad.load_lump("LINEDEFS", map_lump), heretic_specials)
	load_sidedefs(map, load_wad.load_lump("SIDEDEFS", map_lump))
	load_vertices(map, load_wad.load_lump("VERTEXES", map_lump))
	load_sectors(map, load_wad.load_lump("SECTORS", map_lump))
	load_subsectors(map, load_wad.load_lump("SSECTORS", map_lump))
	load_nodes(map, load_wad.load_lump("NODES", map_lump))
	load_segs(map, load_wad.load_lump("SEGS", map_lump))
	
	# find linedef sectors
	for linedef in map.linedefs:
		if linedef.front_sidedef != -1:
			linedef.front_sector = map.sidedefs[linedef.front_sidedef].sector
		if linedef.back_sidedef != -1:
			linedef.back_sector = map.sidedefs[linedef.back_sidedef].sector
	
	# find subsector sectors
	for subsector in map.subsectors:
		var seg := map.segs[subsector.firstseg]
		var linedef := map.linedefs[seg.linedef]
		subsector.sector = linedef.back_sector if seg.side else linedef.front_sector
	
	# find map bounding box
	if not map.vertices.is_empty():
		map.bbox = Rect2i(map.vertices[0], Vector2i.ZERO)
		for vertex in map.vertices:
			map.bbox = map.bbox.expand(vertex)
	
	# triangulate sectors
	var polygon: PackedVector2Array = [
		map.bbox.position,
		Vector2(map.bbox.end.x, map.bbox.position.y),
		map.bbox.end,
		Vector2(map.bbox.position.x, map.bbox.end.y)
	]
	triangulate_node(map, map.nodes.size() - 1, polygon)
	
	# build meshes for sectors
	for sector in map.sectors:
		build_mesh(sector)
	
	# build lines
	for linedef in map.linedefs:
		if not map.lines.has(linedef.color):
			map.lines[linedef.color] = PackedVector2Array()
		var v1 := map.vertices[linedef.start_vertex]
		var v2 := map.vertices[linedef.end_vertex]
		map.lines[linedef.color].push_back(Vector2(v1.x, -v1.y))
		map.lines[linedef.color].push_back(Vector2(v2.x, -v2.y))
	
	return map


func apply_map_tweaks(tweaks: Dictionary) -> void:
	if not tweaks.has("things"):
		return
	
	for id: String in tweaks.things:
		var i := id.to_int()
		if i < 0 or i >= things.size():
			print("Out of bounds map tweak thing error")
			continue
		var tweak : Dictionary = tweaks.things[id]
		var target := things[i]
		target.x = tweak.get("x", target.x)
		target.y = tweak.get("y", target.y)
		target.type = tweak.get("type", target.type)
		target.angle = tweak.get("angle", target.angle)
		target.flags = tweak.get("flags", target.flags)
		if tweak.get("dont_randomize", false):
			target.flags |= Thing.Flags.Multiplayer


func sector_for_point(point: Vector2) -> int:
	var n := nodes.size() - 1
	
	while ((n & SUBSECTOR_FLAG) == 0):
		var node := nodes[n]
		var right := (point - Vector2(node.pos)).cross(Vector2(node.cut)) > 0.0
		n = node.children[0] if right else node.children[1]
	
	n &= ~SUBSECTOR_FLAG
	return subsectors[n].sector
