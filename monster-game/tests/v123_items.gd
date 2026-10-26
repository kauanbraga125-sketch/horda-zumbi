extends SceneTree

const CHANGED = ["z_cyber", "z_goggles", "z_hockey", "z_clown"]
var current
var previous
var reference
var lab
var viewport: SubViewport
var canvas: Node2D
var output = ""
var failures: Array[String] = []
var checks = 0
var page: Array = []
var renderer = 0
var detail = false
var pose: Dictionary
var active_id = "z_clown"
var protected_samples = 0
var mismatches = 0
var examples: Array = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message);push_error("V123_FAIL: "+message)

func draw_board() -> void:
	var actor = current if renderer == 0 else previous if renderer == 1 else reference
	if detail:
		for reverse in [false,true]:
			actor.paint(canvas, 0, Vector2(256+512*int(reverse),565),350,pose.phase,pose.state,pose.time,pose.landing,Color.WHITE,reverse,pose.air_age,pose.vertical_speed,[active_id])
		return
	for i in range(page.size()):
		var job: Dictionary = page[i]
		var sample = lab.sample(job.kind,job.state,job.index)
		actor.paint(canvas,job.kind,Vector2(i%8*240+112,int(i/8)*240+224),154,sample.phase,sample.state,sample.time,sample.landing,Color.WHITE,job.reverse,sample.air_age,sample.vertical_speed,job.wear)

func render_image() -> Image:
	canvas.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func transform_for(f: Dictionary, reverse: bool) -> Transform2D:
	var origin = Vector2(256+512*int(reverse),565)
	var stretch=Vector2.ONE;var angle=0.0
	if pose.state=="run" and pose.landing<=0:
		var step=fposmod(pose.phase*2.0,1.0)
		if step>.76: origin.y-=2.6*pow(sin((step-.76)/.24*PI),2)*350.0/112.0
		angle=.006*sin((pose.phase*2.0-.1)*TAU)
	elif pose.state in ["idle","aim"]:
		var breath=sin(pose.time*TAU/2.4)
		stretch=Vector2(1.0-breath*.004,1.0+breath*.009);angle=sin(pose.time*TAU/4.8)*.004
	var result=Transform2D(angle*(-1 if reverse else 1),origin)
	result.x*=(-1 if reverse else 1)*stretch.x*350.0/float(f.height);result.y*=stretch.y*350.0/float(f.height)
	result.origin-=result.basis_xform(HordeCosmetics.vector(f.anchor))
	return result

func difference(a: Color, b: Color) -> float:
	return maxf(maxf(absf(a.r-b.r),absf(a.g-b.g)),maxf(absf(a.b-b.b),absf(a.a-b.a)))

func compare_source(original: Image, actual: Image) -> void:
	var f: Dictionary=current.frames[pose.key]
	var source: Image=current.texture(f.file).get_image()
	var w=float(f.head_width)
	for reverse in [false,true]:
		var transform=transform_for(f,reverse)
		for y in range(1,int(f.rect[3])-1,2):
			for x in range(1,int(f.rect[2])-1,2):
				var point=Vector2(x+.5,y+.5)
				var face=point.distance_to(HordeCosmetics.vector(f.landmarks.near))<w*.21 or point.distance_to(HordeCosmetics.vector(f.landmarks.far))<w*.12
				face=face or (y>float(f.landmarks.chin[1])-.17*w and y<float(f.landmarks.chin[1])+.03*w and x>float(f.landmarks.near[0])-.14*w and x<float(f.box[2])+.02*w)
				var body=y>=float(f.landmarks.neck[1])+.10*w
				if not body and not face: continue
				var opaque=true
				for dy in [-1,0,1]:
					for dx in [-1,0,1]:
						if source.get_pixel(int(f.rect[0])+x+dx,int(f.rect[1])+y+dy).a<.99:opaque=false
				if not opaque:continue
				var screen=Vector2i((transform*point).floor())
				if not Rect2i(Vector2i.ZERO,actual.get_size()).has_point(screen):continue
				protected_samples+=1
				if difference(original.get_pixelv(screen),actual.get_pixelv(screen))>8.1/255.0:
					mismatches+=1
					if examples.size()<20:examples.append({"frame":pose.key,"source":[x,y],"reverse":reverse,"body":body,"expected":original.get_pixelv(screen).to_html(),"actual":actual.get_pixelv(screen).to_html()})

func run() -> void:
	output=OS.get_environment("HORDA_VALIDATION_DIR");DirAccess.make_dir_recursive_absolute(output)
	current=HordeCosmetics.new();current.ensure_data()
	previous=load("res://tests/v123_original_cosmetics.gd").new();previous.ensure_data()
	previous.graphics=JSON.parse_string(FileAccess.get_file_as_string("res://tests/v123_before_graphics.json"))
	reference=load("res://tests/v123_source_reference.gd").new();reference.ensure_data()
	lab=load("res://scripts/item_lab.gd").new()
	check(str(ProjectSettings.get_setting("application/config/version"))=="0.10.23","Version 0.10.23")
	var unchanged=0
	for id in current.graphics:
		if id not in CHANGED:check(current.graphics[id]==previous.graphics[id],"Existing graphic "+id);unchanged+=1
	check(unchanged==31,"31 other accessories preserved")
	check(FileAccess.get_sha256("res://assets/art/cosmetics_v113/fitting.bin")=="5a7fdb5ebdb86a0c92f97813559272b778d3ec65987f458127f9d66d76ee8940","263 original measured frames unchanged")
	for key in current.frames:
		var f: Dictionary=current.frames[key]
		if int(f.kind)!=0:continue
		for id in CHANGED:
			var transform: Transform2D=current.fit_transform(id,f)
			check(absf(transform.x.dot(transform.y))<.00001 and absf(transform.x.length()-transform.y.length())<.00001,"No shear or flattening "+id+key)
			if id in ["z_cyber","z_goggles"]:
				for eye in ["near","far"]:check((transform*HordeCosmetics.vector(current.graphics[id].rigid_eyes[eye])).distance_to(HordeCosmetics.vector(f.landmarks[eye]))<.001,"Rigid lens placement "+id+key+eye)
	viewport=SubViewport.new();viewport.size=Vector2i(1920,1440);viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	canvas=Node2D.new();viewport.add_child(canvas);canvas.draw.connect(draw_board)
	var jobs: Array=[]
	for entry in HordeCosmeticCatalog.ITEMS:
		if entry.id in CHANGED:continue
		for state in range(9):
			for reverse in [false,true]:jobs.append({"kind":entry.kind,"state":state,"index":mini(2,int(lab.spec(entry.kind,state).x)-1),"reverse":reverse,"wear":[entry.id]})
	for start in range(0,jobs.size(),48):
		page=jobs.slice(start,mini(start+48,jobs.size()));renderer=0
		var actual=await render_image();renderer=1
		var original=await render_image()
		check(actual.get_data()==original.get_data(),"Existing accessory render page "+str(start))
		if actual.get_data()!=original.get_data():actual.save_png(output.path_join("changed_protected_%d.png"%start))
	var protected_render_count=jobs.size()
	jobs=[]
	for id in CHANGED:
		for state in range(9):
			for index in range(int(lab.spec(0,state).x)):
				for reverse in [false,true]:jobs.append({"kind":0,"state":state,"index":index,"reverse":reverse,"wear":[id]})
	for start in range(0,jobs.size(),48):
		page=jobs.slice(start,mini(start+48,jobs.size()));renderer=0
		var actual=await render_image();actual.save_png(output.path_join("four_items_%03d.png"%start))
	# Pixel checks against an independent renderer of the entire original
	# character catch eye/mouth/hand damage from wig occlusion geometry.
	detail=true;viewport.size=Vector2i(1024,600)
	var seen={}
	for state in range(9):
		for index in range(int(lab.spec(0,state).x)):
			pose=lab.sample(0,state,index)
			if seen.has(pose.key):continue
			seen[pose.key]=true
			renderer=0;var actual=await render_image()
			renderer=2;var original=await render_image()
			compare_source(original,actual)
			if examples.size()>0 and examples[-1].frame==pose.key:actual.save_png(output.path_join("pixel_failure_"+pose.key+".png"))
	check(mismatches==0,"Original eyes, mouth, hands and clothing preserved: "+str(mismatches))
	var report={"checks":checks,"failures":failures,"existing_items_rendered":protected_render_count,"changed_items_rendered":jobs.size(),"wig_frames_checked":seen.size(),"protected_pixel_samples":protected_samples,"protected_pixel_mismatches":mismatches,"examples":examples}
	FileAccess.open(output.path_join("items_validation.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("V123_ITEMS_", "OK" if failures.is_empty() else "FAILED",": ",JSON.stringify(report))
	canvas.queue_free();viewport.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
