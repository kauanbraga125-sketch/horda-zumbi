extends SceneTree
var actor: HordeActor
var canvas: Node2D
var viewport: SubViewport
var entries: Array = []
var pose = 0
var reverse_mode = false
var preview_mode = false
var phase = .23
var output = ""
const STATES = ["run","idle","push","capture","rise","fly","fall","run"]
func _initialize() -> void: call_deferred("run")
func draw_board() -> void:
	if preview_mode:
		for i in range(entries.size()):
			var item: Dictionary = entries[i]
			var box = Rect2(Vector2(i%6*240+20,int(i/6)*320+15),Vector2(200,270))
			var bounds: Rect2 = actor.cosmetics.preview_bounds(item.id)
			if reverse_mode: bounds.position.x = -bounds.end.x
			var height = minf(box.size.x/bounds.size.x,box.size.y/bounds.size.y)*.98
			var foot = box.get_center()-bounds.get_center()*height
			actor.paint(canvas,item.kind,foot,height,phase,"run",.41,0,Color.WHITE,reverse_mode,1,true,-1,0,[item.id])
		return
	canvas.draw_rect(Rect2(0,0,1920,1200),Color("2d263b"))
	for i in range(entries.size()):
		var item: Dictionary = entries[i]
		var base = Vector2(i%6*320+150,int(i/6)*600+265)
		for facing in [false,true]:
			var foot = base+Vector2(0,265 if facing else 0)
			canvas.draw_line(foot-Vector2(140,0),foot+Vector2(140,0),Color("57485d"),1)
			actor.paint(canvas,item.kind,foot,180,.23,STATES[pose],.41,.12 if pose == 7 else 0,Color.WHITE,facing,1,true,.12,320,item.get("wear",[item.id]))
		canvas.draw_string(ThemeDB.fallback_font,base+Vector2(-140,-235),item.id,HORIZONTAL_ALIGNMENT_LEFT,300,22,Color.WHITE)
func shot(name: String) -> void:
	canvas.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(output.path_join(name+".png"))
func run() -> void:
	output = OS.get_environment("HORDA_VALIDATION_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	viewport=SubViewport.new();viewport.size=Vector2i(1920,1200);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport);actor=HordeActor.new(HordeArt.new());canvas=Node2D.new();viewport.add_child(canvas);canvas.draw.connect(draw_board)
	if OS.get_environment("HORDA_COMBINATIONS") == "1":
		entries=[{"id":"electric + vampire","kind":0,"wear":["z_electric","z_vampire"]},{"id":"scientist + chain","kind":0,"wear":["z_scientist","z_chain"]},{"id":"beanie + cyber","kind":0,"wear":["z_beanie","z_cyber"]},{"id":"north + bat","kind":1,"wear":["s_north","s_bat"]},{"id":"silver + bat","kind":1,"wear":["s_silver","s_bat"]},{"id":"space + hourglass","kind":1,"wear":["s_space","s_hourglass"]}]
		for state in [0,1,2,4]:
			pose=state;await shot("combined_%d"%state)
		print("V114_COMBINATIONS_COMPLETE: 6 pairs, 4 poses, both facings")
		quit();return
	for group in range(3):
		entries=HordeCosmeticCatalog.ITEMS.slice(group*12,mini(group*12+12,35))
		for state in range(8):
			pose=state;await shot("wear_%d_%d"%[group,state])
	preview_mode=true;viewport.transparent_bg=true;viewport.size=Vector2i(1440,1920);entries=HordeCosmeticCatalog.ITEMS
	for facing in [false,true]:
		reverse_mode=facing
		for step in range(8):
			phase=float(step)/8;await shot("preview_%d_%d"%[int(facing),step])
	print("V114_VISUAL_COMPLETE: 24 boards and 560 rendered previews")
	quit()
