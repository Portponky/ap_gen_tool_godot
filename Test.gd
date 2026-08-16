extends Node2D

signal task_complete

var world : World
var map : Map
var lump_name: String

var zoom := 1.0
var offset := Vector2.ZERO
var highlight_sector := 0

var mouse_dragging := false
var mouse_position : Vector2

var cached_things := {}

func _ready() -> void:
	Status.task_changed.connect(%Label.set_text)
	Status.new_error.connect(issue)
	Status.new_warning.connect(issue)


func _draw() -> void:
	if not world or not map:
		return
	
	var to_map := Transform2D.IDENTITY.translated(-offset).scaled(zoom * Vector2.ONE).translated(get_viewport_rect().get_center())
	draw_set_transform_matrix(to_map)
	
	var mapdata = world.data.maps.filter(func(x): return x._lump == lump_name)[0]
	for r in mapdata.regions:
		var color := Color(r.tint[0], r.tint[1], r.tint[2], 0.5 * r.tint[3])
		for s in r.sectors:
			var sector = map.sectors[s]
			if sector.mesh:
				draw_mesh(sector.mesh, null, Transform2D.IDENTITY, color)
	
	for color in map.lines:
		draw_multiline(map.lines[color], color)
	
	if highlight_sector >= 0:
		for linedef in map.linedefs.filter(func(x): return x.front_sector == highlight_sector or x.back_sector == highlight_sector):
			var v1 := Vector2(map.vertices[linedef.start_vertex])
			var v2 := Vector2(map.vertices[linedef.end_vertex])
			draw_line(Vector2(v1.x, -v1.y), Vector2(v2.x, -v2.y), Color.AQUA)
	
	draw_set_transform_matrix(Transform2D.IDENTITY)
	for thing in map.things:
		if thing.flags & Map.Thing.Flags.Multiplayer:
			continue
		if thing.type in cached_things:
			var pos := to_map * Vector2(thing.x, -thing.y)
			draw_texture(cached_things[thing.type].texture, pos + Vector2(cached_things[thing.type].offset))


func _unhandled_input(event: InputEvent) -> void:
	if not map:
		return
	
	if event is InputEventMouseMotion:
		if mouse_dragging:
			var pos := get_global_mouse_position()
			var diff : Vector2 = (pos - mouse_position) / zoom
			offset.x -= diff.x
			offset.y -= diff.y
			queue_redraw()
			mouse_position = pos
		if not mouse_dragging:
			var pos := get_global_mouse_position()
			# convert to doom coord...
			var offset_from_center := pos - get_viewport_rect().get_center()
			#offset_from_center.y = -offset_from_center.y
			var doom_coord := offset + offset_from_center / zoom
			doom_coord.y = -doom_coord.y
			highlight_sector = map.sector_for_point(doom_coord)
			queue_redraw()
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
			mouse_dragging = true
			mouse_position = get_global_mouse_position()
		if not event.pressed:
			mouse_dragging = false
		
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom /= 0.9
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom *= 0.9
		
		queue_redraw()
	
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_PAGEDOWN:
			next_map()
		elif event.pressed and event.keycode == KEY_PAGEUP:
			previous_map()


func load_map(request) -> void:
	if not world.maps.has(request):
		return
	
	lump_name = request
	map = world.maps[lump_name]
	
	offset = map.bbox.get_center()
	offset.y = -offset.y
	var rect = get_viewport_rect()
	zoom = min(rect.size.x / map.bbox.size.x, rect.size.y / map.bbox.size.y) * 0.9
	queue_redraw()


func previous_map() -> void:
	var lumps = world.maps.keys()
	var i := lumps.find(lump_name)
	if i >= 1:
		load_map(lumps[i - 1])


func next_map() -> void:
	var lumps = world.maps.keys()
	var i := lumps.find(lump_name)
	if i >= 0 and i < lumps.size() - 1:
		load_map(lumps[i + 1])


func issue(what: String) -> void:
	print(what)


func _on_load_pressed() -> void:
	var thread := Thread.new()
	thread.start(func() -> void:
		world = World.load("doom2")
		task_complete.emit.call_deferred()
	)
	
	await task_complete
	thread.wait_to_finish()
	%Label.text = ""
	
	if not world:
		return
	
	load_map(world.maps.keys()[0])
	
	for item in world.game.ap_doom_types:
		cached_things[int(item.doom_type)] = world.load_graphic(item.sprite)


func _on_generate_pressed() -> void:
	if not world:
		return
	
	var thread = Thread.new()
	thread.start(func() -> void:
		Generate.generate(world)
		task_complete.emit.call_deferred()
	)
	
	await task_complete
	thread.wait_to_finish()
	%Label.text = ""
