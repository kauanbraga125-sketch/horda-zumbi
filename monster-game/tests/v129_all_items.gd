extends SceneTree
const CHANGED=["s_goth","s_comic","s_silver","s_punk","s_vest","s_bat","s_hourglass"]
var current
var previous
var lab
var viewport:SubViewport
var canvas:Node2D
var page:Array=[]
var mode="current"
var checks=0
var failures:Array=[]
var output=""
var body_samples=0
var body_differences=0
var eye_samples=0
var eye_differences=0
var examples:Array=[]
var per_item:Dictionary={}
func _initialize() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error("V129_FAIL "+message)
func draw_board() -> void:
	var actor=previous if mode=="previous" else current
	for i in range(page.size()):
		var j:Dictionary=page[i];var pose=lab.sample(j.kind,j.state,j.index)
		check(actor.paint(canvas,j.kind,Vector2(i%8*240+115,int(i/8)*240+222),154,pose.phase,pose.state,pose.time,pose.landing,Color.WHITE,j.reverse,pose.air_age,pose.vertical_speed,["__original"] if mode=="source" else j.wear),"Renderer handles "+str(j))
func render() -> Image:
	canvas.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()
func difference(a:Color,b:Color) -> float:
	return maxf(maxf(absf(a.r-b.r),absf(a.g-b.g)),maxf(absf(a.b-b.b),absf(a.a-b.a)))
func compare_source(before:Image,after:Image) -> void:
	for i in range(page.size()):
		var j:Dictionary=page[i];var id:String=j.wear[0];var pose=lab.sample(j.kind,j.state,j.index);var f:Dictionary=current.frames[pose.key];var image:Image=current.texture(f.file).get_image();var w=float(f.head_width)
		var transform=Transform2D(0,Vector2(i%8*240+115,int(i/8)*240+222));transform.x*=(-1 if j.reverse else 1)*154.0/float(f.height);transform.y*=154.0/float(f.height)
		transform.origin-=transform.basis_xform(lab.anchor_for(f,pose,1))
		for y in range(2,int(f.rect[3])-2,2):
			for x in range(2,int(f.rect[2])-2,2):
				var color=image.get_pixel(int(f.rect[0])+x,int(f.rect[1])+y)
				if color.a<.99:continue
				var bone=color.r>.56 and color.g>.45 and color.b<color.g*.91 and color.r>color.g*1.02
				var protect_bone=bone and y>float(f.landmarks.neck[1])+(.80 if id in ["s_silver","s_punk"] else .24)*w
				var eye=id in ["s_silver","s_punk","s_comic"] and color.g>.40 and color.b>.40 and color.r<.30
				if not protect_bone and not eye:continue
				var opaque=true
				for dy in [-1,0,1]:
					for dx in [-1,0,1]:
						if image.get_pixel(int(f.rect[0])+x+dx,int(f.rect[1])+y+dy).a<.99:opaque=false
				if not opaque:continue
				var point=Vector2i((transform*Vector2(x+.5,y+.5)).floor())
				if not Rect2i(Vector2i.ZERO,after.get_size()).has_point(point):continue
				var changed=difference(before.get_pixelv(point),after.get_pixelv(point))>9.0/255.0
				if not per_item.has(id):per_item[id]={"bone_samples":0,"bone_differences":0,"eye_samples":0,"eye_differences":0}
				if protect_bone:body_samples+=1;body_differences+=int(changed);per_item[id].bone_samples+=1;per_item[id].bone_differences+=int(changed)
				if eye:eye_samples+=1;eye_differences+=int(changed);per_item[id].eye_samples+=1;per_item[id].eye_differences+=int(changed)
				if changed and examples.size()<60:examples.append({"id":id,"frame":pose.key,"point":[x,y],"bone":protect_bone,"eye":eye})
func run() -> void:
	output=OS.get_environment("HORDA_VALIDATION_DIR");DirAccess.make_dir_recursive_absolute(output)
	current=HordeCosmetics.new();current.ensure_data();previous=load("res://tests/v129_original_cosmetics.gd").new();previous.ensure_data();previous.graphics=JSON.parse_string(FileAccess.get_file_as_string("res://tests/v129_before_graphics.json"));lab=load("res://scripts/item_lab.gd").new()
	var unchanged=0
	for id in current.graphics:
		if id not in CHANGED:check(current.graphics[id]==previous.graphics[id],"Preserved metadata "+id);unchanged+=1
	check(unchanged==28,"28 other accessories preserved")
	viewport=SubViewport.new();viewport.size=Vector2i(1920,1440);viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	canvas=Node2D.new();viewport.add_child(canvas);canvas.draw.connect(draw_board)
	var old_jobs:Array=[];var new_jobs:Array=[];var repaired_jobs:Array=[]
	for entry in HordeCosmeticCatalog.ITEMS:
		for state in range(9):
			for index in range(int(lab.spec(entry.kind,state).x)):
				for reverse in [false,true]:
					var j={"kind":entry.kind,"state":state,"index":index,"reverse":reverse,"wear":[entry.id]}
					if entry.id in CHANGED:new_jobs.append(j)
					elif entry.kind==1 and current.frames[lab.sample(j.kind,j.state,j.index).key].get("head_v129",false):repaired_jobs.append(j)
					else:old_jobs.append(j)
	if OS.get_environment("HORDA_CHANGED_ONLY")=="1" or OS.get_environment("HORDA_SKIP_UNCHANGED")=="1":old_jobs=[]
	for start in range(0,old_jobs.size(),48):
		page=old_jobs.slice(start,mini(start+48,old_jobs.size()));mode="current";var after=await render();mode="previous";var before=await render()
		check(after.get_data()==before.get_data(),"Unchanged renders "+str(start))
		if start%480==0:print("UNCHANGED_RENDER_PROGRESS ",start,"/",old_jobs.size())
	var targets=OS.get_environment("HORDA_TARGET_FRAMES").split(",",false)
	if not targets.is_empty():new_jobs=new_jobs.filter(func(j):return lab.sample(j.kind,j.state,j.index).key in targets)
	for start in range(0,new_jobs.size(),48):
		page=new_jobs.slice(start,mini(start+48,new_jobs.size()));mode="current";var after=await render();mode="source";var before=await render();compare_source(before,after)
		after.save_png(output.path_join("seven_%04d.png"%start))
		if start%480==0:print("CHANGED_RENDER_PROGRESS ",start,"/",new_jobs.size())
	var combos:Array=repaired_jobs.duplicate()
	for head in ["s_chaos","s_north","s_wizard","s_striped","s_ice","s_ghostpirate","s_space","s_crown","s_silver","s_punk"]:
		for face in ["s_goth","s_comic","s_plague"]:
			for body in ["s_vest","s_bat"]:
				for state in range(9):
					for reverse in [false,true]:combos.append({"kind":1,"state":state,"index":mini(8,int(lab.spec(1,state).x)-1),"reverse":reverse,"wear":[head,face,body,"s_hourglass"]})
	if OS.get_environment("HORDA_CHANGED_ONLY")=="1":combos=[]
	for start in range(0,combos.size(),48):
		page=combos.slice(start,mini(start+48,combos.size()));mode="current";var result=await render();check(not result.is_invisible(),"Combined slot render "+str(start));result.save_png(output.path_join("combinations_%04d.png"%start))
	check(body_differences==0,"Native limb pixels preserved")
	check(eye_differences==0,"Native visible irises preserved")
	var report={"checks":checks,"failures":failures,"unchanged_renders":old_jobs.size(),"revised_renders":new_jobs.size(),"combination_renders":combos.size(),"bone_samples":body_samples,"bone_differences":body_differences,"eye_samples":eye_samples,"eye_differences":eye_differences,"examples":examples,"per_item":per_item,"repaired_existing_renders":repaired_jobs.size()}
	var file=FileAccess.open(output.path_join("all_items_validation.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("V129_ALL_ITEMS_",("OK" if failures.is_empty() else "FAILED")," ",JSON.stringify(report))
	canvas.queue_free();viewport.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
