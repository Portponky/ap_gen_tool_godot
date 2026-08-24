extends MapTool

var highlight_sector := -1
var selected_region := -1

var painting := false
var clearing := false

func _on_regions_select_region(index: int) -> void:
	selected_region = index


func render_sectors(view: MapView, to_map: Transform2D) -> void:
	super(view, to_map)
	
	# Draw highlighted sector if appropriate
	if highlight_sector < 0:
		return
	
	for linedef in view.map.linedefs.filter(func(x): return x.front_sector == highlight_sector or x.back_sector == highlight_sector):
		var v1 := Vector2(view.map.vertices[linedef.start_vertex])
		var v2 := Vector2(view.map.vertices[linedef.end_vertex])
		view.draw_line(Vector2(v1.x, -v1.y), Vector2(v2.x, -v2.y), Color.AQUA)


func handle_input(view: MapView, event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var doom_coord := view.doom_coordinate(event.position)
		var sector := view.map.sector_for_point(doom_coord)
		if sector != highlight_sector:
			highlight_sector = sector
			if painting:
				paint_highlighted_sector(view)
			elif clearing:
				clear_highlighted_sector(view)
			view.queue_redraw()
	
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not clearing:
			painting = true
			paint_highlighted_sector(view)
		elif event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and not painting:
			clearing = true
			clear_highlighted_sector(view)
		else:
			painting = false
			clearing = false


func stop() -> void:
	highlight_sector = -1
	selected_region = -1


func can_change() -> bool:
	return not painting and not clearing


func add_region_sector(view: MapView, region: int, sector: int) -> void:
	var sectors: Array = view.map_data.regions[region].sectors
	if not sectors.has(sector):
		sectors.push_back(sector)
		view.queue_redraw()


func clear_region_sector(view: MapView, region: int, sector: int) -> void:
	var sectors: Array = view.map_data.regions[region].sectors
	if sectors.has(sector):
		sectors.erase(sector)
		view.queue_redraw()


func paint_highlighted_sector(view: MapView) -> void:
	if highlight_sector == -1 or selected_region == -1:
		return
	
	if view.map_data.regions[selected_region].sectors.has(highlight_sector):
		return
	
	view.undo.create_action("Paint sector")
	for r: int in view.map_data.regions.size():
		if r == selected_region:
			continue
		var region: Dictionary = view.map_data.regions[r]
		if region.sectors.has(highlight_sector):
			view.undo.add_do_method(clear_region_sector.bind(view, r, highlight_sector))
			view.undo.add_undo_method(add_region_sector.bind(view, r, highlight_sector))
	
	view.undo.add_do_method(add_region_sector.bind(view, selected_region, highlight_sector))
	view.undo.add_undo_method(clear_region_sector.bind(view, selected_region, highlight_sector))
	view.undo.commit_action()


func clear_highlighted_sector(view: MapView) -> void:
	if highlight_sector == -1:
		return
	
	for r: int in view.map_data.regions.size():
		var region: Dictionary = view.map_data.regions[r]
		if region.sectors.has(highlight_sector):
			view.undo.create_action("Clear sector")
			view.undo.add_do_method(clear_region_sector.bind(view, r, highlight_sector))
			view.undo.add_undo_method(add_region_sector.bind(view, r, highlight_sector))
			view.undo.commit_action()
			return
