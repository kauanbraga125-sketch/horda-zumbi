extends SceneTree
const CHANGED=["s_ice","s_north","s_wizard","s_striped","s_ghostpirate","s_space","s_crown","s_plague"]
var current
var previous
var reference
var lab
var viewport:SubViewport
var canvas:Node2D
var page:Array=[]
var original=false
var detail=false
var active_id="s_ice"
var pose:Dictionary
var failures:Array[String]=[]
var checks=0
var body_samples=0
var body_mismatches=0
var iris_samples=0
var iris_mismatches=0
var examples:Array=[]
var per_item:Dictionary={}
var output=""
func _initialize() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error("V128_FAIL "+message)
func draw_board() -> void:
	var actor=(reference if detail else previous) if original else current
	if detail:
		for reverse in [false,true]:actor.paint(canvas,1,Vector2(256+512*int(reverse),565),350,pose.phase,pose.state,pose.time,pose.landing,Color.WHITE,reverse,pose.air_age,pose.vertical_speed,[active_id])
		return
	for i in range(page.size()):
		var j:Dictionary=page[i];var sample=lab.sample(j.kind,j.state,j.index)
		actor.paint(canvas,j.kind,Vector2(i%8*240+112,int(i/8)*240+224),154,sample.phase,sample.state,sample.time,sample.landing,Color.WHITE,j.reverse,sample.air_age,sample.vertical_speed,j.wear)
func render_image() -> Image:
	canvas.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()
func difference(a:Color,b:Color) -> float:return maxf(maxf(absf(a.r-b.r),absf(a.g-b.g)),maxf(absf(a.b-b.b),absf(a.a-b.a)))
func compare_source(before:Image,after:Image) -> void:
	var f:Dictionary=current.frames[pose.key];var source:Image=current.texture(f.file).get_image();var w=float(f.head_width)
	for reverse in [false,true]:
		var transform=Transform2D(0,Vector2(256+512*int(reverse),565));transform.x*=(-1 if reverse else 1)*350.0/float(f.height);transform.y*=350.0/float(f.height)
		var anchor=HordeCosmetics.vector(f.anchor);var clip=HordeSkeletonApprovedSprite.clip_for(pose.state,pose.landing)
		var index=HordeSkeletonApprovedSprite.frame_for(pose.state,pose.phase,pose.time,pose.landing,pose.air_age,pose.vertical_speed)
		anchor.y=HordeSkeletonApprovedSprite.foot_anchor_for(clip,index,clip=="jump" and pose.state=="run" and pose.landing>0)
		transform.origin-=transform.basis_xform(anchor)
		for y in range(1,int(f.rect[3])-1,2):
			for x in range(1,int(f.rect[2])-1,2):
				var point=Vector2(x+.5,y+.5)
				# The replaced hood belongs to the head. Its measured cut extends
				# .98 skull widths behind the face; cape/arms beyond it are kept.
				var body=y>float(f.landmarks.neck[1])+.34*w or x<float(f.box[0])-1.10*w
				var pixel=source.get_pixel(int(f.rect[0])+x,int(f.rect[1])+y)
				var iris=point.distance_to(HordeCosmetics.vector(f.landmarks.near))<.14*w or point.distance_to(HordeCosmetics.vector(f.landmarks.far))<.08*w
				iris=iris and pixel.g>.40 and pixel.b>.40 and pixel.r<.30
				if not body and not iris:continue
				var opaque=true
				for dy in [-1,0,1]:
					for dx in [-1,0,1]:
						if source.get_pixel(int(f.rect[0])+x+dx,int(f.rect[1])+y+dy).a<.99:opaque=false
				if not opaque:continue
				var screen=Vector2i((transform*point).floor())
				if not Rect2i(Vector2i.ZERO,after.get_size()).has_point(screen) or before.get_pixelv(screen).a<.99:continue
				var changed=difference(before.get_pixelv(screen),after.get_pixelv(screen))>8.1/255.0
				if body:body_samples+=1;body_mismatches+=int(changed);per_item[active_id].body+=int(changed)
				if iris:iris_samples+=1;iris_mismatches+=int(changed);per_item[active_id].iris+=int(changed)
				if changed and examples.size()<80:examples.append({"item":active_id,"frame":pose.key,"point":[x,y],"body":body,"iris":iris})
func run() -> void:
	output=OS.get_environment("HORDA_VALIDATION_DIR");DirAccess.make_dir_recursive_absolute(output)
	current=HordeCosmetics.new();current.ensure_data();previous=load("res://tests/v128_original_cosmetics.gd").new();previous.ensure_data();previous.graphics=JSON.parse_string(FileAccess.get_file_as_string("res://tests/v128_before_graphics.json"));lab=load("res://scripts/item_lab.gd").new()
	reference=load("res://tests/v127_source_reference.gd").new();reference.ensure_data()
	for id in CHANGED:
		if HordeCosmetics.item(id).slot=="head":reference.graphics[id].preserve_source=true
	reference.graphics.s_plague.expose_cranium=false
	check(str(ProjectSettings.get_setting("application/config/version"))=="0.10.28","Current version")
	check(FileAccess.get_sha256("res://assets/art/cosmetics_v113/fitting.bin")=="5a7fdb5ebdb86a0c92f97813559272b778d3ec65987f458127f9d66d76ee8940","263 original measurements unchanged")
	var untouched=0;var fit_count=0
	for id in current.graphics:
		if id not in CHANGED:check(current.graphics[id]==previous.graphics[id],"Untouched accessory "+id);untouched+=1
	check(untouched==27,"27 prior items preserved")
	for key in current.frames:
		var f:Dictionary=current.frames[key]
		if int(f.kind)!=1:continue
		for id in CHANGED:
			var t:Transform2D=current.fit_transform(id,f)
			check(t.determinant()>0 and absf(t.x.dot(t.y))<.00001 and absf(t.x.length()-t.y.length())<.00001,"Rigid proportional fit "+id+key);fit_count+=1
	viewport=SubViewport.new();viewport.size=Vector2i(1920,1440);viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport);canvas=Node2D.new();viewport.add_child(canvas);canvas.draw.connect(draw_board)
	var jobs:Array=[]
	for entry in HordeCosmeticCatalog.ITEMS:
		if OS.get_environment("HORDA_DETAIL_ONLY")=="1":break
		if entry.id in CHANGED:continue
		for state in range(9):
			for reverse in [false,true]:jobs.append({"kind":entry.kind,"state":state,"index":mini(2,int(lab.spec(entry.kind,state).x)-1),"reverse":reverse,"wear":[entry.id]})
	for start in range(0,jobs.size(),48):
		page=jobs.slice(start,mini(start+48,jobs.size()));original=false;var actual=await render_image();original=true;var before=await render_image();check(actual.get_data()==before.get_data(),"Unchanged accessory render page "+str(start))
	var untouched_render_count=jobs.size();jobs=[]
	for id in CHANGED:
		if OS.get_environment("HORDA_DETAIL_ONLY")=="1":break
		for state in range(9):
			for index in range(int(lab.spec(1,state).x)):
				for reverse in [false,true]:jobs.append({"kind":1,"state":state,"index":index,"reverse":reverse,"wear":[id]})
	var individual_count=jobs.size()
	if OS.get_environment("HORDA_DETAIL_ONLY")!="1":
		for id in CHANGED:
			var wear=[id,"s_bat","s_hourglass","s_ice" if id=="s_plague" else "s_plague"]
			for state in range(9):
				for reverse in [false,true]:jobs.append({"kind":1,"state":state,"index":mini(2,int(lab.spec(1,state).x)-1),"reverse":reverse,"wear":wear})
	for start in range(0,jobs.size(),48):
		page=jobs.slice(start,mini(start+48,jobs.size()));original=false;var actual=await render_image();check(not actual.is_invisible(),"Animated item render "+str(start));actual.save_png(output.path_join("eight_items_%04d.png"%start))
	detail=true;viewport.size=Vector2i(1024,600)
	for id in CHANGED:
		active_id=id
		per_item[id]={"body":0,"iris":0}
		for state in range(9):
			pose=lab.sample(1,state,mini(8,int(lab.spec(1,state).x)-1));original=false;var actual=await render_image();original=true;var before=await render_image();compare_source(before,actual)
	check(body_samples>10000 and body_mismatches==0,"Original cloak, hands and body pixels: "+str(body_mismatches))
	check(iris_samples>100 and iris_mismatches==0,"Animated cyan irises stay visible: "+str(iris_mismatches))
	var report={"checks":checks,"failures":failures,"fit_count":fit_count,"unchanged_accessories":untouched,"unchanged_renders":untouched_render_count,"changed_renders":individual_count,"combination_renders":jobs.size()-individual_count,"body_samples":body_samples,"body_mismatches":body_mismatches,"iris_samples":iris_samples,"iris_mismatches":iris_mismatches,"per_item":per_item,"examples":examples}
	FileAccess.open(output.path_join("items_validation.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("V128_ITEMS_", "OK" if failures.is_empty() else "FAILED",": ",JSON.stringify(report));canvas.queue_free();viewport.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
