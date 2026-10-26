extends SceneTree
const IDS=["s_goth","s_comic","s_silver","s_punk","s_vest","s_bat","s_hourglass"]
var cosmetics
var lab
var viewport:SubViewport
var canvas:Node2D
var output=""
var mode="overview"
var selected=0
var page=0
var font:Font=preload("res://assets/fonts/DejaVuSans.ttf")
var title:Font=preload("res://assets/fonts/LilitaOne-Regular.ttf")
func _initialize() -> void:call_deferred("run")
func label_at(value:String,point:Vector2,size:int=24,color:Color=Color("ffcd77")) -> void:
	canvas.draw_string(font,point,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
func centered(id:String,pose:Dictionary,rect:Rect2,reverse:bool,height:float,all_states:bool=true) -> void:
	for i in range(HordeCosmeticCatalog.ITEMS.size()):
		if HordeCosmeticCatalog.ITEMS[i].id==id:lab.selected=i;break
	var bounds:Rect2=lab.bounds_for(cosmetics) if all_states else cosmetics.preview_bounds(id)
	var fit=minf(height,minf((rect.size.x-24)/bounds.size.x,(rect.size.y-20)/bounds.size.y))
	var centre=bounds.get_center()
	if reverse:centre.x=-centre.x
	var foot=rect.get_center()-centre*fit
	assert(cosmetics.paint(canvas,HordeCosmetics.item(id).kind,foot,fit,pose.phase,pose.state,pose.time,pose.landing,Color.WHITE,reverse,pose.air_age,pose.vertical_speed,[id]))
func board() -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO,viewport.size),Color("21192d"))
	if mode=="overview":
		canvas.draw_string(title,Vector2(35,55),"7 ITENS REVISADOS • v0.10.29",HORIZONTAL_ALIGNMENT_LEFT,-1,43,Color("ffcd77"))
		label_at("Arte e encaixe nas animações originais",Vector2(38,94),24,Color("9ce4c7"))
		for i in range(7):
			var corner=Vector2(28+i%2*772,125+int(i/2)*460)
			var width=744.0 if i<6 else 1516.0
			canvas.draw_rect(Rect2(corner,Vector2(width,440)),Color("2e243d"))
			label_at("%d  %s"%[i+1,HordeCosmetics.item(IDS[i]).name],corner+Vector2(20,38),25)
			for side in range(2):centered(IDS[i],lab.sample(1,int(OS.get_environment("HORDA_OVERVIEW_STATE")),int(OS.get_environment("HORDA_OVERVIEW_FRAME")) if not OS.get_environment("HORDA_OVERVIEW_FRAME").is_empty() else 8),Rect2(corner+Vector2(side*width/2,55),Vector2(width/2,370)),side==1,320,false)
	elif mode=="states":
		label_at(HordeCosmetics.item(IDS[selected]).name+" • v0.10.29",Vector2(20,40),30)
		for state in range(9):
			var corner=Vector2(state%3*820,int(state/3)*460+60)
			label_at(lab.LABELS[state],corner+Vector2(18,30),23,Color("9ce4c7"))
			var indexes=[8,8,8,3,5,5,18,18,8]
			var pose=lab.sample(1,state,mini(indexes[state],int(lab.spec(1,state).x)-1))
			for side in range(2):centered(IDS[selected],pose,Rect2(corner+Vector2(side*410,45),Vector2(410,395)),side==1,310)
	elif mode=="catalog":
		for row in range(7):
			var index=page*7+row
			if index>=35:break
			var entry:Dictionary=HordeCosmeticCatalog.ITEMS[index]
			label_at("%02d %s"%[index+1,entry.name],Vector2(10,row*350+25),22)
			for state in range(9):
				var corner=Vector2(state*300,row*350+30)
				label_at(lab.LABELS[state],corner+Vector2(10,20),16,Color("9ce4c7"))
				var indexes=[8,8,8,3,5,5,18,18,8]
				var pose=lab.sample(entry.kind,state,mini(indexes[state],int(lab.spec(entry.kind,state).x)-1))
				centered(entry.id,pose,Rect2(corner+Vector2(0,25),Vector2(300,285)),false,200)
func shot(name:String) -> void:
	canvas.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().save_png(output.path_join(name+".png"))==OK)
func run() -> void:
	assert(str(ProjectSettings.get_setting("application/config/version"))=="0.10.29")
	output=OS.get_environment("HORDA_VALIDATION_DIR");DirAccess.make_dir_recursive_absolute(output)
	cosmetics=HordeCosmetics.new();cosmetics.ensure_data();lab=load("res://scripts/item_lab.gd").new()
	viewport=SubViewport.new();viewport.size=Vector2i(1572,1980);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	canvas=Node2D.new();viewport.add_child(canvas);canvas.draw.connect(board)
	await shot("Sete-Itens-Revisados")
	if OS.get_environment("HORDA_OVERVIEW_ONLY")=="1":
		canvas.queue_free();viewport.queue_free();await process_frame;quit();return
	mode="states";viewport.size=Vector2i(2460,1440)
	for i in range(7):
		selected=i;await shot(IDS[i]+"-Nove-Animacoes")
	mode="catalog";viewport.size=Vector2i(2700,2450)
	for i in range(5):
		page=i;await shot("catalog_%02d"%(i+1))
	print("V129_VISUAL_OK seven_items=7 all_catalog=35 states=9")
	canvas.queue_free();viewport.queue_free();await process_frame;quit()
