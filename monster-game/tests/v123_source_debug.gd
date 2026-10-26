extends SceneTree
var viewport: SubViewport
var canvas: Node2D
var cosmetics
var pose
var actor
func _initialize() -> void: call_deferred("run")
func paint() -> void:
	canvas.draw_rect(Rect2(0,0,1920,600),Color("2b2237"))
	var f: Dictionary=cosmetics.frames[pose.key]
	for col in range(6):
		var foot=Vector2(col*320+150,560)
		var root=Transform2D(0,foot);root.x*=350.0/float(f.height);root.y*=350.0/float(f.height);root.origin-=root.basis_xform(HordeCosmetics.vector(f.anchor))
		canvas.draw_string(ThemeDB.fallback_font,Vector2(col*320+10,25),["QUAD","CLOWN SOURCE","FACE","ORIGINAL ACTOR","CLOWN FULL","WIG FRONT"][col],HORIZONTAL_ALIGNMENT_LEFT,310,20,Color.WHITE)
		if col==0:
			canvas.draw_set_transform_matrix(root);canvas.draw_texture_rect_region(cosmetics.texture(f.file),Rect2(0,0,f.rect[2],f.rect[3]),Rect2(f.rect[0],f.rect[1],f.rect[2],f.rect[3]))
		elif col==1:cosmetics.draw_source(canvas,pose.key,"clown_base",root,Color.WHITE)
		elif col==2:cosmetics.draw_source(canvas,pose.key,"face",root,Color.WHITE)
		elif col==3:actor.paint(canvas,0,foot,350,pose.phase,pose.state,pose.time,pose.landing,Color.WHITE,false,1.0,true,pose.air_age,pose.vertical_speed,[])
		elif col==4:actor.paint(canvas,0,foot,350,pose.phase,pose.state,pose.time,pose.landing,Color.WHITE,false,1.0,true,pose.air_age,pose.vertical_speed,["z_clown"])
		else:cosmetics.draw_item(canvas,"z_clown",f,root,Color.WHITE,true)
		canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
func run() -> void:
	viewport=SubViewport.new();viewport.size=Vector2i(1920,600);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var art=HordeArt.new();actor=HordeActor.new(art);cosmetics=actor.cosmetics;cosmetics.ensure_data()
	pose=load("res://scripts/item_lab.gd").new().sample(0,4,2)
	canvas=Node2D.new();viewport.add_child(canvas);canvas.draw.connect(paint)
	await process_frame;await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(OS.get_environment("HORDA_DECODE_PATH"))
	quit()
