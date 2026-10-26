extends SceneTree
const ITEMS=[["s_ice", 1, "COROA DE GELO"], ["s_north", 1, "ELMO DO NORTE"], ["s_wizard", 1, "CHAPÉU DAS ESTRELAS"], ["s_striped", 1, "CARTOLA LISTRADA"], ["s_ghostpirate", 1, "TRICÓRNIO FANTASMA"], ["s_space", 1, "CAPACETE ESPACIAL"], ["s_crown", 1, "COROA DO REI OSSUDO"], ["s_plague", 1, "MÁSCARA DA PESTE"]]
var game
var before
var viewport:SubViewport
var canvas:Node2D
var selected=0
var states=false
var overview=false
var catalog=false
var output=""
func _initialize() -> void:call_deferred("run")
func paint_center(actor,kind:int,pose:Dictionary,id:String,cell:Rect2,reverse:bool,height:float) -> void:
	var bounds:Rect2=actor.cosmetics.preview_bounds(id)
	var fit=minf(height,minf((cell.size.x-40)/bounds.size.x,(cell.size.y-65)/bounds.size.y))
	var center=bounds.get_center();if reverse:center.x=-center.x
	var foot=cell.get_center()-center*fit+Vector2(0,20)
	actor.paint(canvas,kind,foot,fit,pose.phase,pose.state,pose.time,pose.landing,Color.WHITE,reverse,1.0,true,pose.air_age,pose.vertical_speed,[id])
func board() -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO,viewport.size),Color("2b2237"))
	if catalog:
		for i in range(HordeCosmeticCatalog.ITEMS.size()):
			var info=HordeCosmeticCatalog.ITEMS[i];var corner=Vector2(i%7*320,int(i/7)*460)
			canvas.draw_string(ThemeDB.fallback_font,corner+Vector2(12,28),info.name,HORIZONTAL_ALIGNMENT_LEFT,300,16,Color("ffcf76"))
			paint_center(game.actor,info.kind,game.item_lab.sample(info.kind,0,6 if info.kind==0 else 8),info.id,Rect2(corner+Vector2(0,30),Vector2(320,420)),false,240)
		return
	if overview:
		for i in range(ITEMS.size()):
			var info=ITEMS[i];var corner=Vector2(i%3*640,int(i/3)*600)
			canvas.draw_string(ThemeDB.fallback_font,corner+Vector2(15,34),info[2],HORIZONTAL_ALIGNMENT_LEFT,610,24,Color("ffcf76"))
			var pose=game.item_lab.sample(info[1],0,6 if info[1]==0 else 8)
			for side in range(2):paint_center(game.actor,info[1],pose,info[0],Rect2(corner+Vector2(side*320,40),Vector2(320,540)),side==1,340)
		return
	var info=ITEMS[selected]
	if not states:
		canvas.draw_string(ThemeDB.fallback_font,Vector2(20,38),info[2],HORIZONTAL_ALIGNMENT_LEFT,1480,30,Color("ffcf76"))
		for row in range(2):
			canvas.draw_string(ThemeDB.fallback_font,Vector2(20,88+row*760),"ANTES — v0.10.27" if row==0 else "DEPOIS — v0.10.28",HORIZONTAL_ALIGNMENT_LEFT,1480,27,Color("9ce4c7"))
			var pose=game.item_lab.sample(info[1],0,6 if info[1]==0 else 8)
			for reverse in [false,true]:paint_center(before if row==0 else game.actor,info[1],pose,info[0],Rect2(Vector2(int(reverse)*800,90+row*760),Vector2(800,670)),reverse,500)
	else:
		for i in range(18):
			var state=int(i/2);var pose=game.item_lab.sample(info[1],state,mini(2,int(game.item_lab.spec(info[1],state).x)-1));var corner=Vector2(i%6*420,int(i/6)*500)
			canvas.draw_string(ThemeDB.fallback_font,corner+Vector2(15,32),game.item_lab.LABELS[state],HORIZONTAL_ALIGNMENT_LEFT,390,24,Color("9ce4c7"))
			paint_center(game.actor,info[1],pose,info[0],Rect2(corner+Vector2(0,35),Vector2(420,455)),i%2==1,330)
func shot(name:String) -> void:
	canvas.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(output.path_join(name+".png"))
func run() -> void:
	output=OS.get_environment("HORDA_VALIDATION_DIR");DirAccess.make_dir_recursive_absolute(output)
	viewport=SubViewport.new();viewport.size=Vector2i(1600,1620);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	game=load("res://main.tscn").instantiate();viewport.add_child(game);game.test_mode=true;game.capture_mode=true;game.set_process(false);game.set_physics_process(false);game.hide()
	before=HordeActor.new(game.art);before.cosmetics=load("res://tests/v128_original_cosmetics.gd").new();before.cosmetics.ensure_data();before.cosmetics.graphics=JSON.parse_string(FileAccess.get_file_as_string("res://tests/v128_before_graphics.json"))
	canvas=Node2D.new();viewport.add_child(canvas);canvas.draw.connect(board)
	for i in range(ITEMS.size()):
		if OS.get_environment("HORDA_OVERVIEW_ONLY")=="1":break
		selected=i;states=false;viewport.size=Vector2i(1600,1620);await shot(ITEMS[i][0]+"_before_after")
		states=true;viewport.size=Vector2i(2520,1500);await shot(ITEMS[i][0]+"_nine_states")
	overview=true;viewport.size=Vector2i(1920,1800);await shot("eight_items")
	catalog=true;overview=false;viewport.size=Vector2i(2240,2300);await shot("all_35_items")
	print("V128_VISUAL_OK");quit()
