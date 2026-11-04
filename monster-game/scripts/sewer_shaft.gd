extends RefCounted
## One continuous underground surface, positioned in world coordinates.
## Its material blend depends on depth, never on phase age or viewport height.
const GALLERY_HEIGHT = 760.0
const GALLERY_ABOVE_WATER = 621.0
var soil: Texture2D
var throat_depth = 180.0

func reset_cover() -> void:
	throat_depth = 180.0

func geometry(g,s) -> Dictionary:
	var drop: float = s.entry_drop() if s.active and s.phase=="entry" else s.SHAFT_DEPTH if s.active else 0.0
	var rise: float = s.exit_rise(g.runner) if s.active and s.phase=="exit" else 0.0
	var surface: float = g.runner.FLOOR-drop+rise
	var gallery: float = s.SHAFT_DEPTH+s.WATER-g.runner.FLOOR-GALLERY_ABOVE_WATER
	var edge: float = s.shore_edge() if s.active else s.encounter.dock_world-g.runner.world_px-s.DOCK_TO_EDGE
	return {"surface":surface,"gallery_offset":gallery,"gallery_top":surface+gallery,"edge":edge,"throat_depth":throat_depth,"street_cover":throat_depth+224.0}

func configure(g,s) -> void:
	var visible: bool = (s.active or s.encounter.pending) and g.screen in ["run","pause","results","revive"]
	g.sewer_background_canvas.visible = visible
	if not visible: return
	# Adapt the unseen throat to the initial framing, then lock it to the world
	# as soon as the first real foot leaves the road. No phase-clock fade.
	if not s.active or (s.phase=="entry" and s.fall_age(g.runner)<0):
		throat_depth = maxf(throat_depth,g.scenery.view_bottom-g.runner.FLOOR+72.0)
	if soil==null:
		var image = Image.new()
		assert(image.load_webp_from_buffer(FileAccess.get_file_as_bytes("res://assets/art/v145/soil_to_sewer.webp"))==OK)
		soil = ImageTexture.create_from_image(image)
	var sewer = preload("res://scripts/bird_art.gd").texture("sewer")
	var p = geometry(g,s)
	var mat: ShaderMaterial = g.sewer_background_canvas.material
	mat.set_shader_parameter("soil_texture",soil)
	mat.set_shader_parameter("sewer_texture",sewer)
	mat.set_shader_parameter("surface_y",p.surface)
	mat.set_shader_parameter("gallery_offset",p.gallery_offset)
	mat.set_shader_parameter("gallery_width",sewer.get_width()*GALLERY_HEIGHT/sewer.get_height())
	mat.set_shader_parameter("gallery_height",GALLERY_HEIGHT)
	mat.set_shader_parameter("scroll_x",g.runner.world_px*.28)
	mat.set_shader_parameter("soil_scroll_x",g.runner.world_px)
	mat.set_shader_parameter("throat_depth",throat_depth)
	mat.set_shader_parameter("shore_edge",p.edge)
	mat.set_shader_parameter("opening_mask",not s.active or s.phase=="entry")
	mat.set_shader_parameter("exit_mode",s.active and s.phase=="exit")
	g.sewer_background_canvas.queue_redraw()

func catwalk_y(g,s) -> float:
	return float(geometry(g,s).gallery_top)+GALLERY_HEIGHT*.588

func dock_face(g,edge: float,drop: float = 0.0) -> void:
	HordeTerrainArt.pit_edge(g,edge,g.runner.FLOOR-drop,false)

func foreground(g,s) -> void:
	# Dust and falling grit remain tied to the broken lip, below solid feet.
	var falling: float = s.fall_age(g.runner)
	if falling<0 or falling>1.8: return
	var c = g.paint_target
	var edge: float = s.shore_edge()
	var top: float = g.runner.FLOOR-s.entry_drop()
	for i in range(20):
		var age = maxf(0,falling-.02-float(i)*.021)
		if age<=0 or age>1.2: continue
		var at = Vector2(edge+12+age*(25+i%5*14),top+8+age*age*(95+i%4*28))
		var fade = (1.0-age/1.2)*.5
		c.draw_circle(at,1.5+float(i%3)*.7,Color(.39,.31,.42,fade))
	for i in range(5):
		var age = maxf(0,falling-.06-float(i)*.09)
		if age<=0 or age>1.05: continue
		var at = Vector2(edge+18+i*11+age*24,top+12+age*age*110)
		c.draw_circle(at,8+age*18,Color(.35,.26,.38,(1.0-age/1.05)*.075))
