extends RefCounted
## One continuous underground surface, positioned in world coordinates.
## Its material blend depends on depth, never on phase age or viewport height.
const GALLERY_HEIGHT = 760.0
const GALLERY_ABOVE_WATER = 621.0
var soil: Texture2D
var dust: GradientTexture2D
var throat_depth = 180.0
var painted_view = Rect2()

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
	var visible: bool = (s.active or s.encounter.cutout_pending()) and g.screen in ["run","pause","results","revive"]
	g.sewer_background_canvas.visible = visible
	if not visible:
		painted_view = Rect2()
		return
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
	mat.set_shader_parameter("bank_texture",g.gameplay_ui.ground_texture.atlas)
	mat.set_shader_parameter("surface_y",p.surface)
	mat.set_shader_parameter("gallery_offset",p.gallery_offset)
	mat.set_shader_parameter("gallery_width",sewer.get_width()*GALLERY_HEIGHT/sewer.get_height())
	mat.set_shader_parameter("gallery_height",GALLERY_HEIGHT)
	mat.set_shader_parameter("scroll_x",g.runner.world_px*s.GALLERY_PARALLAX)
	mat.set_shader_parameter("soil_scroll_x",g.runner.world_px)
	mat.set_shader_parameter("throat_depth",throat_depth)
	mat.set_shader_parameter("effect_time",g.frozen_world_time if g.screen in ["pause","results","revive"] else g.ui_time)
	mat.set_shader_parameter("water_clock",s.age)
	mat.set_shader_parameter("water_scroll",s.scroll)
	mat.set_shader_parameter("shore_edge",p.edge)
	mat.set_shader_parameter("opening_width",s.entry_gap_width if s.active else s.encounter.gap_width)
	mat.set_shader_parameter("opening_mask",not s.active or s.phase=="entry")
	var exiting: bool = s.active and s.phase=="exit"
	mat.set_shader_parameter("exit_mode",exiting)
	mat.set_shader_parameter("exit_opening",s.exit_opening() if exiting else 0.0)
	mat.set_shader_parameter("exit_clear",s.exit_clear() if exiting else 0.0)
	mat.set_shader_parameter("exit_bank",s.exit_bank(g.runner) if exiting else 0.0)
	var view = Rect2(g.scenery.view_left, g.scenery.view_top,
		g.scenery.view_right - g.scenery.view_left, g.scenery.view_bottom - g.scenery.view_top)
	if view != painted_view:
		painted_view = view
		g.sewer_background_canvas.queue_redraw()

func catwalk_y(g,s) -> float:
	return float(geometry(g,s).gallery_top)+GALLERY_HEIGHT*.588

func rupture_debris(g, s) -> void:
	var falling: float = s.fall_age(g.runner)
	if falling < 0 or falling > 1.45: return
	var edge: float = s.shore_edge()
	if edge + 110 < g.scenery.view_left or edge - 40 > g.scenery.view_right: return
	var top: float = g.runner.FLOOR - s.entry_drop()
	if dust == null:
		var gradient = Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.46, 1.0])
		gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.48), Color(1, 1, 1, 0)])
		dust = GradientTexture2D.new()
		dust.gradient = gradient
		dust.fill = GradientTexture2D.FILL_RADIAL
		dust.fill_from = Vector2(0.5, 0.5)
		dust.fill_to = Vector2(1, 0.5)
	for i in range(6):
		var age = falling - i * 0.052
		if age <= 0 or age >= 0.95: continue
		var radius = 10.0 + i * 1.7 + age * 32.0
		var centre = Vector2(edge - 6 + i * 4 + age * (28 + i * 7), top + radius + 4 + age * age * 72)
		var opacity = smoothstep(0, 0.065, age) * (1 - smoothstep(0.30, 0.95, age)) * 0.28
		g.paint_target.draw_texture_rect(dust, Rect2(centre - Vector2.ONE * radius, Vector2.ONE * radius * 2), false, Color(0.53, 0.43, 0.50, opacity))
	for i in range(11):
		var age = falling - i * 0.037
		if age <= 0 or age >= 1.05: continue
		var point = Vector2(edge + 8 + (i % 3) * 8 + age * (29 + (i * 13) % 38), top + 12 + (i % 4) * 7 + age * age * (155 + i % 4 * 27))
		var angle = (1 if i % 2 == 0 else -1) * age * (2.2 + i % 3)
		var size = (5.0 + (i * 7) % 10) * smoothstep(0, 0.05, age)
		HordeTerrainArt.sewer_chip(g, i, point, size, angle, 1 - smoothstep(0.58, 1.05, age))
