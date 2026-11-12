extends SceneTree

var results: Array = []
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(valid: bool, message: String) -> void:
	if not valid: failures.append(message)

func simulate(choice: String, count: int, fps: int) -> void:
	var r = HordeRun.new()
	r.start_developer("gap", count, 0, 16161)
	r.developer_kind = ""
	r.entities.clear()
	r.rebuild_surfaces()
	r.next_pattern_world = 1e9
	r.bonus_director.next_window = 1e9
	var s = r.sewer
	check(s.encounter.offer(r, true, "both"), "Could not offer physical branches")
	var ids = r.members.map(func(m): return int(m.id))
	check(not r.has_floor(s.encounter.left(r)+s.encounter.gap_width*.5), "Hole still has collision floor")
	check(r.has_floor(s.encounter.right(r)+12.0), "Far bank has no floor")
	check(r.has_floor(r.sky.pad_world-r.world_px), "Trampoline is over the hole")
	var pressed_at = -1.0
	var held = false
	var entered = -1.0
	var minimum_y = r.FLOOR
	var landing_clear = false
	var overlap = false
	var step = 1.0 / fps
	for frame in range(fps*12):
		var pad_distance = r.sky.pad_world-r.world_px-float(r.members[r.leader_index()].x) if r.leader_index()>=0 else INF
		if pressed_at<0 and choice!="sewer" and pad_distance <= (150.0 if choice=="sky" else 80.0):
			r.jump()
			held = true
			pressed_at = r.elapsed
		if pressed_at>=0 and r.elapsed-pressed_at >= (.08 if choice=="sky" else 1.25): held = false
		var before_y = r.members.map(func(m): return float(m.y))
		r.advance(step, held)
		overlap = overlap or (r.sky.active and s.active)
		for member in r.members: minimum_y = minf(minimum_y,float(member.y))
		if s.active and entered<0:
			entered = r.elapsed
			check(before_y.any(func(y): return y>r.FLOOR) or r.members.any(func(m): return m.y>r.FLOOR), "Descent began before a real fall")
		if choice=="sewer" and s.phase=="ride": break
		if choice=="sky" and r.sky.active and r.sky.altitude>600.0: break
		if choice=="street" and s.encounter.route=="street" and r.members.all(func(m): return r.has_floor(m.x) and absf(float(m.y)-r.FLOOR)<.5):
			landing_clear = true
			break
		if r.dead: break
	check(not overlap,"Sky and sewer activated together")
	check(not r.dead and r.active_count()==count,"Lost members in "+choice+" count="+str(count)+" fps="+str(fps))
	check(r.members.map(func(m): return int(m.id))==ids,"Member identities changed in "+choice)
	if choice=="sewer":
		check(s.active and s.phase=="ride" and not r.sky.active,"Running did not enter the sewer")
		check(s.starts.size()==count,"Missing individual fall starts")
		check(r.members.all(func(m): return bool(m.get("sewer_onboard",false))),"Horde did not board the jet-skis")
	elif choice=="sky":
		check(r.sky.active and not s.active and r.sky.altitude>600.0,"Tap did not land on the trampoline")
	else:
		check(landing_clear and not s.active and not r.sky.active,"Held jump did not return to normal road")
	results.append({"choice":choice,"members":count,"fps":fps,"route":s.encounter.route,"sewer_phase":s.phase,"sky_active":r.sky.active,"landing_on_far_bank":landing_clear,"losses":r.losses,"entered_at":entered,"peak_jump":r.FLOOR-minimum_y})

func run() -> void:
	for fps in [30,60,120]:
		for count in [1,6,20]:
			for choice in ["sewer","sky","street"]: simulate(choice,count,fps)
	check(results.size()==27,"Missing route simulations")
	var report = {"version":"0.10.61","cases":results,"failures":failures,"physical_device_tested":false}
	var destination = OS.get_environment("HORDA_VALIDATION_DIR")
	if not destination.is_empty():
		DirAccess.make_dir_recursive_absolute(destination)
		var file = FileAccess.open(destination+"/routes.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"  "))
	for failure in failures: push_error(failure)
	print("V161_ROUTES ",results.size()," cases, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
