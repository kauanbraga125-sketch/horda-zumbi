extends SceneTree

const ITEMS = [["z_scientist",0,"CABELO DO CIENTISTA"],["z_vampire",0,"CAPA DO VAMPIRO"],["z_scarf",0,"CACHECOL CARMESIM"],["z_chain",0,"CORRENTE DO SUBMUNDO"],["s_chaos",1,"GORRO DO CAOS"],["s_north",1,"ELMO DO NORTE"],["s_wizard",1,"CHAPÉU DAS ESTRELAS"],["s_striped",1,"CARTOLA LISTRADA"],["s_ice",1,"COROA DE GELO"]]
var game
var before
var viewport: SubViewport
var canvas: Node2D
var selected=0
var states=false
var overview=false
var output=""

func _initialize() -> void:call_deferred("run")

func board() -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO,viewport.size),Color("2b2237"))
	if overview:
		for i in range(ITEMS.size()):
			var info=ITEMS[i];var corner=Vector2(i%3*640,int(i/3)*540)
			canvas.draw_string(ThemeDB.fallback_font,corner+Vector2(15,34),info[2],HORIZONTAL_ALIGNMENT_LEFT,610,24,Color("ffcf76"))
			canvas.draw_string(ThemeDB.fallback_font,corner+Vector2(15,68),"ANTES — 0.10.25",HORIZONTAL_ALIGNMENT_LEFT,290,19,Color("9ce4c7"))
			canvas.draw_string(ThemeDB.fallback_font,corner+Vector2(335,68),"DEPOIS — 0.10.26",HORIZONTAL_ALIGNMENT_LEFT,290,19,Color("9ce4c7"))
			var old_bounds: Rect2=before.cosmetics.preview_bounds(info[0])
			var new_bounds: Rect2=game.actor.cosmetics.preview_bounds(info[0])
			var height=minf(260.0,minf(280.0/maxf(old_bounds.size.x,new_bounds.size.x),420.0/maxf(old_bounds.size.y,new_bounds.size.y)))
			var pose=game.item_lab.sample(info[1],0,6 if info[1]==0 else 8)
			for side in range(2):
				var actor=before if side==0 else game.actor
				var bounds=old_bounds if side==0 else new_bounds
				var foot=corner+Vector2(160+320*side,310)-bounds.get_center()*height
				actor.paint(canvas,info[1],foot,height,pose.phase,pose.state,pose.time,pose.landing,Color.WHITE,false,1.0,true,pose.air_age,pose.vertical_speed,[info[0]])
		return
	var item=ITEMS[selected]
	if not states:
		canvas.draw_string(ThemeDB.fallback_font,Vector2(18,38),item[2],HORIZONTAL_ALIGNMENT_LEFT,924,28,Color("ffcf76"))
		for row in range(2):
			canvas.draw_string(ThemeDB.fallback_font,Vector2(18,90+row*560),"ANTES — v0.10.25" if row==0 else "DEPOIS — v0.10.26",HORIZONTAL_ALIGNMENT_LEFT,924,25,Color("9ce4c7"))
			var pose=game.item_lab.sample(item[1],0,6 if item[1]==0 else 8)
			var actor=before if row==0 else game.actor
			for reverse in [false,true]:actor.paint(canvas,item[1],Vector2((200+560*int(reverse)) if item[1]==1 else (270+420*int(reverse)),540+row*560),300,pose.phase,pose.state,pose.time,pose.landing,Color.WHITE,reverse,1.0,true,pose.air_age,pose.vertical_speed,[item[0]])
	else:
		for i in range(18):
			var state=int(i/2)
			var pose=game.item_lab.sample(item[1],state,mini(2,int(game.item_lab.spec(item[1],state).x)-1))
			var x=i%6*320;var y=int(i/6)*400
			canvas.draw_string(ThemeDB.fallback_font,Vector2(x+10,y+25),game.item_lab.LABELS[state],HORIZONTAL_ALIGNMENT_LEFT,300,20,Color("9ce4c7"))
			game.actor.paint(canvas,item[1],Vector2(x+(125 if i%2==0 else 195) if item[1]==1 else x+160,y+385),270,pose.phase,pose.state,pose.time,pose.landing,Color.WHITE,i%2==1,1.0,true,pose.air_age,pose.vertical_speed,[item[0]])

func shot(name: String) -> void:
	canvas.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(output.path_join(name+".png"))

func run() -> void:
	output=OS.get_environment("HORDA_VALIDATION_DIR");DirAccess.make_dir_recursive_absolute(output)
	viewport=SubViewport.new();viewport.size=Vector2i(960,1160);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	game=load("res://main.tscn").instantiate();viewport.add_child(game);game.test_mode=true;game.capture_mode=true;game.set_process(false);game.set_physics_process(false);game.hide()
	before=HordeActor.new(game.art);before.cosmetics=load("res://tests/v126_original_cosmetics.gd").new();before.cosmetics.ensure_data();before.cosmetics.graphics=JSON.parse_string(FileAccess.get_file_as_string("res://tests/v126_before_graphics.json"))
	canvas=Node2D.new();viewport.add_child(canvas);canvas.draw.connect(board)
	for index in range(ITEMS.size()):
		selected=index;states=false;viewport.size=Vector2i(960,1160)
		await shot(ITEMS[index][0]+"_before_after")
		states=true;viewport.size=Vector2i(1920,1200)
		await shot(ITEMS[index][0]+"_nine_states")
	overview=true;viewport.size=Vector2i(1920,1620)
	await shot("nine_items_before_after")
	canvas.queue_free();game.queue_free();await process_frame
	print("V126_VISUAL_OK");quit()
