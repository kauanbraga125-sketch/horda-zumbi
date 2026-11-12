extends SceneTree

const Hauntings = preload("res://scripts/sky_hauntings.gd")
var failures: Array[String] = []
var checks = 0

func _initialize() -> void: call_deferred("run")

func check(valid: bool, message: String) -> void:
	checks += 1
	if not valid: failures.append(message)

func runner() -> HordeRun:
	var r = HordeRun.new()
	r.start_developer("gap",6,0,16202)
	r.developer_kind = ""
	r.entities.clear();r.rebuild_surfaces();r.next_pattern_world = 1e9;r.bonus_director.next_window = 1e9
	check(r.sewer.encounter.offer(r,true,"both"),"Could not offer both routes")
	return r

func launch(r) -> void:
	var pressed = -1.0
	for frame in range(240):
		if pressed<0 and r.sky.pad_world-r.world_px-r.ANCHOR<=150.0:
			r.jump();pressed = r.elapsed
		r.advance(1.0/60.0,pressed>=0 and r.elapsed-pressed<.08)
		if r.sky.active: return
	check(false,"Trampoline never launched the horde")

func run() -> void:
	for size in [Vector2(1280,720),Vector2(1800,810),Vector2(960,720)]:
		var low_view = Rect2(Vector2(-100,-400),size)
		var high_view = Rect2(Vector2(-100,-3400),size)
		var low = Hauntings.walker_position(low_view,Vector2(600,-400),8.0)-low_view.position
		var high = Hauntings.walker_position(high_view,Vector2(600,-3400),8.0)-high_view.position
		check(high.y>low.y and high.y-low.y<150.0,"Giant follows the horde's altitude instead of remaining distant")
		var later = Hauntings.walker_position(low_view,Vector2(600,-400),11.0)-low_view.position
		check(absf(later.y-low.y)<.01,"Walking animation shifts the giant's horizon height")
	var small = Hauntings.walker_position(Rect2(0,-400,1280,600),Vector2(0,-400),8.0)
	var tall = Hauntings.walker_position(Rect2(0,-400,1280,900),Vector2(0,-400),8.0)
	check(absf(small.y-tall.y)<.01,"Viewport resize moves the giant's anchor")
	for count in [1,6,20]:
		var r = runner()
		while r.members.size()>count: r.members.pop_back()
		while r.members.size()<count: r.add_member(0,false)
		launch(r)
		var event = r.sewer.encounter
		var world_left = event.left(r)+r.world_px
		var width = event.right(r)-event.left(r)
		check(not event.pending and r.sky.active,"Sky selection did not consume the gameplay choice")
		check(event.cutout_pending(),"The hole disappears at trampoline contact")
		for frame in range(240):
			if r.sky.active:r.advance(1.0/60.0,false)
			else:break
			check(absf(event.left(r)+r.world_px-world_left)<.01,"Hole is no longer anchored to the road")
			check(absf(event.right(r)-event.left(r)-width)<.01,"Hole changes width during ascent")
			if event.right(r)>=r.view_left-120.0:
				check(event.cutout_pending(),"Visible opening was filled in during ascent")
				check(not r.has_floor((event.left(r)+event.right(r))*.5),"Collision fills the same visible hole")
			else:
				check(not event.cutout_pending(),"Offscreen opening was never retired")
				break
	# A real knock-down can return the horde over the same opening. It must
	# remain an entrance, rather than an invisible platform or a fatal pit.
	var r = runner();launch(r)
	for frame in range(36):r.advance(1.0/60.0,false)
	r.sky.knock_down(r,-1180.0)
	for frame in range(120):
		r.advance(1.0/60.0,false)
		if r.sewer.active:break
	check(r.sewer.active and not r.sky.active,"Returning onto the hole did not enter the sewer")
	check(not r.dead and r.active_count()==6,"Returning over the same opening loses the horde")
	var report = {"version":"0.10.62","checks":checks,"failures":failures,"physical_device_tested":false}
	var path = OS.get_environment("HORDA_VALIDATION_DIR")
	if not path.is_empty():
		DirAccess.make_dir_recursive_absolute(path)
		var file = FileAccess.open(path+"/regression.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"  "))
	for message in failures:push_error(message)
	print("V162_REGRESSION ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
