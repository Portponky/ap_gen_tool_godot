extends MapTool

var highlight_sector := -1
var highlight_line := -1

var arrows := []


func render_sectors(view: MapView, to_map: Transform2D) -> void:
	super(view, to_map)
	
	# Draw highlighted sector if appropriate
	if highlight_sector < 0:
		return
	
	for linedef in view.map.linedefs.filter(func(x): return x.front_sector == highlight_sector or x.back_sector == highlight_sector):
		var v1 := Vector2(view.map.vertices[linedef.start_vertex])
		var v2 := Vector2(view.map.vertices[linedef.end_vertex])
		view.draw_line(Vector2(v1.x, -v1.y), Vector2(v2.x, -v2.y), Color.AQUA)
	
	if highlight_line < 0:
		return
	
	view.draw_set_transform_matrix(Transform2D.IDENTITY)
	var line := view.map.linedefs[highlight_line]
	var l1 := view.map.vertices[line.start_vertex]
	var l2 := view.map.vertices[line.end_vertex]
	view.draw_line(to_map * Vector2(l1.x, -l1.y), to_map * Vector2(l2.x, -l2.y), Color.GOLD, 2.0)


func handle_render(view: MapView, to_map: Transform2D) -> void:
	super(view, to_map)
	
	view.draw_set_transform_matrix(Transform2D.IDENTITY)
	for a: Dictionary in arrows:
		var dest: Vector2 = to_map * a.to
		view.draw_line(to_map * a.from, dest, Color.LIME, 2.0)
		view.draw_line(dest, dest - 5.0 * (a.normal + a.right), Color.LIME, 2.0)
		view.draw_line(dest, dest - 5.0 * (a.normal - a.right), Color.LIME, 2.0)
	
	var text := ""
	if highlight_sector > -1 and highlight_line > -1:
		var line := view.map.linedefs[highlight_line]
		var sidedef := line.front_sidedef if line.front_sector == highlight_sector else line.back_sidedef
		text = "Sector %d, linedef %d (sidedef %d)" % [highlight_sector, highlight_line, sidedef]
	elif highlight_sector > -1:
		text = "Sector %d" % highlight_sector
	
	if not text.is_empty():
		var font := ThemeDB.fallback_font
		view.draw_string(font, Vector2(10.0, view.size.y - 10.0), text)


func handle_input(view: MapView, event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var doom_coord := view.doom_coordinate(event.position)
		var sector := view.map.sector_for_point(doom_coord)
		var line := find_closest_line(view, sector, event.position)
		
		if sector != highlight_sector or line != highlight_line:
			highlight_sector = sector
			highlight_line = line
			calculate_arrows(view)
			view.queue_redraw()


func find_closest_line(view: MapView, sector: int, screen_pos: Vector2) -> int:
	var closest := -1
	var best_distance := 100.0
	var pos := view.doom_coordinate(screen_pos)
	
	for i: int in view.map.linedefs.size():
		var line := view.map.linedefs[i]
		if line.front_sector != sector and line.back_sector != sector:
			continue
		
		var v1 := Vector2(view.map.vertices[line.start_vertex])
		var v2 := Vector2(view.map.vertices[line.end_vertex])
		
		var dir := (v2 - v1).normalized()
		var t := dir.dot(pos - v1)
		var distance := pos.distance_to(v1 + t * dir)
		if t < 0.0:
			distance = pos.distance_to(v1)
		elif t > v1.distance_to(v2):
			distance = pos.distance_to(v2)
		
		if distance < best_distance:
			best_distance = distance
			closest = i
	
	return closest


func calculate_arrows(view: MapView) -> void:
	arrows.clear()
	
	if highlight_sector > -1:
		var sector := view.map.sectors[highlight_sector]
		if sector.tag != 0:
			for l: int in view.map.linedefs.size():
				if view.map.linedefs[l].sector_tag == sector.tag:
					arrows.push_back(generate_arrow(view, l, highlight_sector))
	
	if highlight_line > -1:
		var line := view.map.linedefs[highlight_line]
		if line.sector_tag != 0:
			for s: int in view.map.sectors.size():
				if view.map.sectors[s].tag == line.sector_tag:
					arrows.push_back(generate_arrow(view, highlight_line, s))


func generate_arrow(view: MapView, line_index: int, sector_index: int) -> Dictionary:
	var sector := view.map.sectors[sector_index]
	
	# calculate vector bounding box
	var bbox := Rect2(sector.polygons[0][0], Vector2.ZERO) # might somehow be invalid
	for polygon: PackedVector2Array in sector.polygons:
		for coord: Vector2 in polygon:
			bbox = bbox.expand(coord)
	
	var line := view.map.linedefs[line_index]
	var v1 := view.map.vertices[line.start_vertex]
	var v2 := view.map.vertices[line.end_vertex]
	var midpoint = 0.5 * Vector2(v1.x + v2.x, -v1.y - v2.y) 
	var normal := (bbox.get_center() - midpoint).normalized()
	
	return {
		from = midpoint,
		to = bbox.get_center(),
		normal = normal,
		right = Vector2(normal.y, -normal.x)
	}


func stop() -> void:
	highlight_sector = -1
	highlight_line = -1
