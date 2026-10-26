extends SceneTree

const CHANGED = ["z_scientist","z_vampire","z_scarf","z_chain","s_chaos","s_north","s_wizard","s_striped","s_ice"]
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
var active_id = "z_scientist"
var protected_samples = 0
var mismatches = 0
var hair_samples = 0
var purple_leaks = 0
var examples: Array = []
var hair_examples: Array = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message);push_error("V127_FAIL: "+message)

func draw_board() -> void:
	var actor = current if renderer == 0 else previous if renderer == 1 else reference
	if detail:
		for reverse in [false,true]:
			actor.paint(canvas, int(HordeCosmetics.item(active_id).kind), Vector2(256+512*int(reverse),565),350,pose.phase,pose.state,pose.time,pose.landing,Color.WHITE,reverse,pose.air_age,pose.vertical_speed,[active_id])
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
	var kind=int(HordeCosmetics.item(active_id).kind)
	if kind==0 and pose.state=="run" and pose.landing<=0:
		var step=fposmod(pose.phase*2.0,1.0)
		if step>.76: origin.y-=2.6*pow(sin((step-.76)/.24*PI),2)*350.0/112.0
		angle=.006*sin((pose.phase*2.0-.1)*TAU)
	elif kind==0 and pose.state in ["idle","aim"]:
		var breath=sin(pose.time*TAU/2.4)
		stretch=Vector2(1.0-breath*.004,1.0+breath*.009);angle=sin(pose.time*TAU/4.8)*.004
	var result=Transform2D(angle*(-1 if reverse else 1),origin)
	result.x*=(-1 if reverse else 1)*stretch.x*350.0/float(f.height);result.y*=stretch.y*350.0/float(f.height)
	var anchor=HordeCosmetics.vector(f.anchor)
	if kind==1:
		var clip=HordeSkeletonApprovedSprite.clip_for(pose.state,pose.landing)
		var index=HordeSkeletonApprovedSprite.frame_for(pose.state,pose.phase,pose.time,pose.landing,pose.air_age,pose.vertical_speed)
		anchor.y=HordeSkeletonApprovedSprite.foot_anchor_for(clip,index,clip=="jump" and pose.state=="run" and pose.landing>0)
	result.origin-=result.basis_xform(anchor)
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
				var face=point.distance_to(HordeCosmetics.vector(f.landmarks.near))<w*.15 or point.distance_to(HordeCosmetics.vector(f.landmarks.far))<w*.085
				face=face or (y>float(f.landmarks.chin[1])-.17*w and y<float(f.landmarks.chin[1])+.03*w and x>float(f.landmarks.near[0])+.02*w and x<float(f.box[2])+.02*w)
				var body=y>=float(f.landmarks.neck[1])+.10*w
				if active_id in ["z_vampire","z_scarf","z_chain"]:body=y>=float(f.landmarks.hip[1])+.10*w
				var original_pixel=source.get_pixel(int(f.rect[0])+x,int(f.rect[1])+y)
				var mouth_feature=(original_pixel.r>original_pixel.g*1.12 and original_pixel.b<original_pixel.r*.80) or (original_pixel.r>160.0/255.0 and original_pixel.g>130.0/255.0 and original_pixel.b<original_pixel.g*.85 and original_pixel.r>original_pixel.g*1.01)
				var eye=point.distance_to(HordeCosmetics.vector(f.landmarks.near))<w*.15 or point.distance_to(HordeCosmetics.vector(f.landmarks.far))<w*.085
				face=eye or (face and mouth_feature)
				var hair=active_id=="z_scientist" and y<minf(float(f.landmarks.near[1]),float(f.landmarks.far[1]))-.18*w and x>float(f.box[0])-.05*w and x<float(f.box[2])+.05*w
				hair=hair and original_pixel.a>.99 and original_pixel.b>original_pixel.r*.90 and original_pixel.b>original_pixel.g*1.7 and original_pixel.b>.09
				if not body and not face and not hair: continue
				var opaque=true
				for dy in [-1,0,1]:
					for dx in [-1,0,1]:
						if source.get_pixel(int(f.rect[0])+x+dx,int(f.rect[1])+y+dy).a<.99:opaque=false
				if not opaque:continue
				var screen=Vector2i((transform*point).floor())
				if not Rect2i(Vector2i.ZERO,actual.get_size()).has_point(screen):continue
				if hair:
					hair_samples+=1
					var pixel=actual.get_pixelv(screen)
					# Cool shadows in the new silver hair may be violet. A leak must
					# also match the independent original source at this exact pixel.
					if pixel.a>.99 and pixel.b>pixel.r*.90 and pixel.b>pixel.g*1.7 and pixel.b>.09 and difference(pixel,original.get_pixelv(screen))<3.1/255.0:
						purple_leaks+=1
						if hair_examples.size()<20:hair_examples.append({"item":active_id,"frame":pose.key,"source":[x,y],"color":pixel.to_html()})
				if not face and not body:continue
				if original.get_pixelv(screen).a<.99:continue
				var expected=original.get_pixelv(screen)
				# Legacy feature bounds occasionally include the purple vest's
				# neckline. Collars intentionally replace those clothing pixels.
				if not body and expected.b>.15 and expected.b>expected.g*1.15 and expected.r>expected.g*1.1:continue
				protected_samples+=1
				if difference(original.get_pixelv(screen),actual.get_pixelv(screen))>8.1/255.0:
					mismatches+=1
					if examples.size()<20:examples.append({"item":active_id,"frame":pose.key,"source":[x,y],"reverse":reverse,"body":body,"expected":original.get_pixelv(screen).to_html(),"actual":actual.get_pixelv(screen).to_html()})

func run() -> void:
	output=OS.get_environment("HORDA_VALIDATION_DIR");DirAccess.make_dir_recursive_absolute(output)
	current=HordeCosmetics.new();current.ensure_data()
	previous=load("res://tests/v127_original_cosmetics.gd").new();previous.ensure_data()
	previous.graphics=JSON.parse_string(FileAccess.get_file_as_string("res://tests/v127_before_graphics.json"))
	reference=load("res://tests/v127_source_reference.gd").new();reference.ensure_data()
	for id in CHANGED:
		if HordeCosmetics.item(id).slot=="head":reference.graphics[id].preserve_source=true
	lab=load("res://scripts/item_lab.gd").new()
	check(str(ProjectSettings.get_setting("application/config/version"))=="0.10.27","Version 0.10.27")
	var unchanged=0
	for id in current.graphics:
		if id not in CHANGED:check(current.graphics[id]==previous.graphics[id],"Existing graphic "+id);unchanged+=1
	check(unchanged==26,"26 other accessories preserved")
	check(FileAccess.get_sha256("res://assets/art/cosmetics_v113/fitting.bin")=="5a7fdb5ebdb86a0c92f97813559272b778d3ec65987f458127f9d66d76ee8940","263 original measured frames unchanged")
	var fitted_frames=0
	for key in current.frames:
		var f: Dictionary=current.frames[key]
		for id in CHANGED:
			if int(HordeCosmetics.item(id).kind)!=int(f.kind):continue
			var transform: Transform2D=current.fit_transform(id,f)
			check(transform.determinant()>0 and absf(transform.x.dot(transform.y))<.00001 and absf(transform.x.length()-transform.y.length())<.00001,"Rigid proportional fit "+id+key)
			fitted_frames+=1
	check(current.frames.size()==263,"Complete fitted wardrobe data")

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
			var kind=int(HordeCosmetics.item(id).kind)
			for index in range(int(lab.spec(kind,state).x)):
				for reverse in [false,true]:jobs.append({"kind":kind,"state":state,"index":index,"reverse":reverse,"wear":[id]})
	for start in range(0,jobs.size(),48):
		page=jobs.slice(start,mini(start+48,jobs.size()));renderer=0
		var actual=await render_image();actual.save_png(output.path_join("four_items_%03d.png"%start))
	var combined:Array=[]
	for wear in [["z_scientist","z_cyber","z_vampire","z_chain"],["z_scientist","z_hockey","z_vampire","z_scarf"],["s_chaos","s_bat","s_goth"],["s_north","s_bat","s_hourglass"],["s_wizard","s_bat","s_goth"],["s_striped","s_bat","s_goth"],["s_ice","s_bat","s_goth"]]:
		var kind=int(HordeCosmetics.item(wear[0]).kind)
		for state in range(9):
			for reverse in [false,true]:combined.append({"kind":kind,"state":state,"index":mini(2,int(lab.spec(kind,state).x)-1),"reverse":reverse,"wear":wear})
	for start in range(0,combined.size(),48):
		page=combined.slice(start,mini(start+48,combined.size()));renderer=0
		var image=await render_image();check(not image.is_invisible(),"Combined accessories render "+str(start))
	# Pixel checks against an independent renderer of the entire original
	# character catch eye/mouth/hand damage from wig occlusion geometry.
	detail=true;viewport.size=Vector2i(1024,600)
	var seen={}
	for id in CHANGED:
		active_id=id
		var kind=int(HordeCosmetics.item(id).kind)
		for state in range(9):
			var index=mini(6 if kind==0 else 8,int(lab.spec(kind,state).x)-1)
			pose=lab.sample(kind,state,index)
			seen[id+pose.key]=true
			renderer=0;var actual=await render_image()
			renderer=2;var original=await render_image()
			compare_source(original,actual)
			if examples.size()>0 and examples[-1].frame==pose.key:actual.save_png(output.path_join("pixel_failure_"+id+pose.key+".png"))
	check(mismatches==0,"Original irises, mouth, hands and clothing preserved: "+str(mismatches))
	check(hair_samples>500 and purple_leaks==0,"Purple hair hidden under the wig: "+str(purple_leaks))
	var report={"checks":checks,"failures":failures,"existing_items_rendered":protected_render_count,"changed_items_rendered":jobs.size(),"combination_renders":combined.size(),"source_poses_checked":seen.size(),"fitted_frames":fitted_frames,"protected_pixel_samples":protected_samples,"protected_pixel_mismatches":mismatches,"old_hair_samples":hair_samples,"purple_leaks":purple_leaks,"examples":examples,"hair_examples":hair_examples}
	FileAccess.open(output.path_join("items_validation.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("V127_ITEMS_", "OK" if failures.is_empty() else "FAILED",": ",JSON.stringify(report))
	canvas.queue_free();viewport.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
