extends SceneTree
var actor: HordeActor
var canvas: Node2D
var frame = 0
var group = 0
var output = ""
var entries: Array = []
func _initialize() -> void: call_deferred("run")
func draw_board() -> void:
	canvas.draw_rect(Rect2(0,0,1920,1080),Color("2d263b"))
	for i in range(entries.size()):
		var item: Dictionary = entries[i]
		var base = Vector2(i % 8 * 240 + 120, int(i / 8) * 535 + 260)
		var state = ["run", "idle", "push", "capture", "rise", "fly", "fall", "run"][frame]
		for reverse in [false, true]:
			var foot = base + Vector2(0, 190 if reverse else 0)
			canvas.draw_line(foot-Vector2(105,0), foot+Vector2(105,0),Color("57485d"),1)
			actor.paint(canvas, item.kind, foot, 172, .23, state, .41, .12 if frame == 7 else 0,Color.WHITE,reverse,1,true,.12,320,[item.id])
		canvas.draw_string(ThemeDB.fallback_font, base+Vector2(-110,-205), item.id, HORIZONTAL_ALIGNMENT_LEFT, 220, 19, Color.WHITE)
func run() -> void:
	output = OS.get_environment("HORDA_VALIDATION_DIR")
	if output.is_empty(): output = ProjectSettings.globalize_path("res://validation/v113")
	DisplayServer.window_set_size(Vector2i(1920,1080));root.content_scale_size=Vector2i(1920,1080)
	actor = HordeActor.new(HordeArt.new());canvas=Node2D.new();root.add_child(canvas);canvas.draw.connect(draw_board)
	DirAccess.make_dir_recursive_absolute(output)
	for g in range(3):
		entries = HordeCosmeticCatalog.ITEMS.slice(g*16,mini(g*16+16,HordeCosmeticCatalog.ITEMS.size()))
		for f in range(8):
			group=g;frame=f;canvas.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("board_%d_%d.png"%[g,f]))
	print("V113_VISUAL_COMPLETE 24 boards, 35 items, 8 poses, both facings")
	quit()
