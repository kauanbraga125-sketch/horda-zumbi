extends "res://tests/v134_visual.gd"
var checks = 0
var failures: Array[String] = []
var measurements: Array = []
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok and label not in failures: failures.append(label);push_error(label)
func picture(layout: bool = true) -> Image:
	if layout: game.configure_layout()
	game.queue_redraw();game.world_canvas.queue_redraw();game.foreground_canvas.queue_redraw();game.sewer_background_canvas.queue_redraw();game.sewer_street_canvas.queue_redraw()
	await process_frame;await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func assignments(label: String) -> void:
	var r = game.runner;var s = r.sewer;var ids: Array = []
	for b in s.boats: ids.append_array(b.ids)
	check(s.boats.size()==r.members.size() and s.boats.all(func(b):return b.ids.size()==1),label+": exactly one real member per craft")
	check(ids.size()==r.members.size() and ids.all(func(id):return ids.count(id)==1 and r.members.any(func(m):return m.id==id)),label+": no duplicate or missing pilot IDs")
func framed(label: String) -> void:
	var view = game.full_rect();var s = game.runner.sewer
	for b in s.boats:
		var top = game.world_to_ui(Vector2(b.x-s.HULL_HALF_WIDTH,b.y-114))
		var bottom = game.world_to_ui(Vector2(b.x+s.HULL_HALF_WIDTH,b.y+s.HULL_HEIGHT*.5))
		check(top.x>=view.position.x+4 and bottom.x<=view.end.x-4,label+": every hull fits horizontally")
		check(top.y>=view.position.y+140 and bottom.y<=view.end.y-8,label+": every pilot and hull fits below the HUD and above the bottom")
	for a in s.boats:
		for b in s.boats:
			if a.id>=b.id or s.slot_lane(a.slot)!=s.slot_lane(b.slot): continue
			check(absf(a.x-b.x)>200,label+": boats in the same row have distinct space")
func upper_wall(label: String) -> void:
	var s = game.runner.sewer;var geometry = s.visual.shaft.geometry(game,s)
	# The irregular material join is fully sewer at gallery_offset + 20.5.
	var upper_end = game.world_to_ui(Vector2(0,float(geometry.surface)+float(geometry.gallery_offset)+21)).y
	check(upper_end<game.full_rect().position.y,label+": the upper transition wall is physically outside the viewport")
	measurements.append({"fixture":label,"upper_wall_end_ui":upper_end,"viewport_top_ui":game.full_rect().position.y,"boats":s.boats.size(),"zoom":game.camera_zoom,"shift":game.camera_ground_shift})
func run() -> void:
	folder = OS.get_environment("HORDA_VALIDATION_DIR");assert(not folder.is_empty());DirAccess.make_dir_recursive_absolute(folder)
	game = load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.test_mode = true;game.capture_freeze = true;game.set_physics_process(false);game.set_process(false);game.sound.set_enabled(false);game.data = MonsterCatalog.defaults()
	for fixture in [[Vector2i(1280,720),6],[Vector2i(1800,810),12],[Vector2i(960,720),12],[Vector2i(1280,720),20],[Vector2i(1280,720),64]]:
		root.size = fixture[0];await process_frame
		game.lab_count = fixture[1];game.start_lab("sewer");game.lab_active = false
		var r = game.runner;r.start_developer("sewer",fixture[1],0,14142);r.developer_kind = "";r.entities.clear();r.events.clear();r.sewer.encounter.offer(r,true)
		for i in range(r.members.size()): r.members[i].kind = i%2
		var s = r.sewer;var label = "%dx%d-%d" % [root.size.x,root.size.y,fixture[1]]
		var boarded = false
		for i in range(600):
			step(STEP)
			if s.active and r.members.all(func(m):return bool(m.get("sewer_onboard",false))): boarded = true;break
		check(boarded,label+": every individual pilot completes the actual fall")
		step(.85);assignments(label+"-boarded");upper_wall(label+"-boarded");await snap(label+"-boarded")
		for i in range(240):
			if s.phase=="ride": break
			step(STEP)
		s.objects.clear();s.next_encounter = 1e6;s.life.people.clear();s.life.next_scene = 1e6
		step(.6);assignments(label+"-ride");framed(label+"-ride");upper_wall(label+"-ride");await snap(label+"-ride")
		game.press_at(game.full_rect().get_center(),81);step(.16);game.release_touch(81)
		check(s.boats.any(func(b):return b.vy<0),label+": actual touch jumps the solo convoy")
		await snap(label+"-jump");step(3.5)
		var duck = game.buttons.filter(func(b):return b.action=="sewer_duck")
		check(not duck.is_empty(),label+": duck action remains reachable")
		if not duck.is_empty(): game.press_at(duck[0].rect.get_center(),82);game.release_touch(82)
		var ducked: Dictionary = {}
		for i in range(ceili(s.fleet_size().x/s.scroll_speed(r)*60)+90):
			step(STEP)
			for b in s.boats:
				if b.duck_left>.1: ducked[b.id] = true
		check(ducked.size()==s.boats.size(),label+": duck timing reaches every individual pilot")
		var before = r.active_count();s.add_object("rescue",s.boats[0].x,s.WATER-8);step(1.25)
		check(r.active_count()==before+1,label+": a real rescue creates one recruit")
		assignments(label+"-rescue");await snap(label+"-rescue")
		r.hit_grace = 0;r.damage(0,"solo_probe");step(STEP);assignments(label+"-loss")
		check(r.active_count()==before,label+": one real casualty removes only its own craft")
		check(s.boats.all(func(b):return b.x<=s.boats[0].x+1),label+": a surviving front craft becomes the leader after a loss")
		s.left = .001;step(STEP)
		var previous: Dictionary = {};var escaped_view = 0;var jumps: Array = []
		var decked: Dictionary = {}
		var takeoff_height: Dictionary = {}
		var climbing: Dictionary = {}
		var crossed_below_bank = 0
		var receding_wave = false
		for i in range(ceili(s.EXIT_SECONDS/STEP)+3):
			step(STEP)
			if s.active:
				var rise: float = s.exit_rise(r)
				receding_wave = receding_wave or (s.wave_strength()>0.08 and s.wave_strength()<0.92)
				for b in s.boats:
					var flight: Dictionary = s.exit_boat(r,b)
					var distance: float = float(b.exit_x)-s.ramp_left(r)-s.RAMP_INSET
					if distance>=0.0 and flight.launch<0.0:
						var bottom = Vector2(flight.p)+Vector2(0,s.HULL_WATERLINE).rotated(flight.angle)
						if absf(bottom.y-rise-s.ramp_deck(distance))<0.05: decked[b.id] = true
					elif flight.launch>=0.0:
						var y = float(flight.p.y)-rise
						if not takeoff_height.has(b.id): takeoff_height[b.id] = y
						if flight.launch>=0.20 and flight.launch<=0.24 and takeoff_height[b.id]-y>73.0: climbing[b.id] = true
			for m in r.members:
				var point = Vector2(m.x,m.y)
				if s.active and m.x>s.exit_bank(r)+8.0 and m.y>r.FLOOR+s.exit_rise(r)-s.EXIT_ELEVATION+3.0:
					crossed_below_bank += 1
				if previous.has(m.id):
					var delta = point.distance_to(previous[m.id])
					check(delta<55,label+": individual riders return without a per-frame teleport")
					if delta>=55 and jumps.size()<8: jumps.append({"frame":i,"phase":s.phase,"phase_age":s.phase_age,"id":m.id,"before":previous[m.id],"after":point,"distance":delta,"pose":m.get("sewer_pose",""),"exit_speed":s.exit_speed})
				previous[m.id] = point
				var ui = game.world_to_ui(point);var view = game.full_rect()
				if ui.y<view.position.y+130 or ui.y>view.end.y-8: escaped_view += 1
			if i in [90,190,290]: await snap(label+"-exit-%03d" % i)
			if not s.active: break
		check(escaped_view==0,label+": the exit camera keeps the real pilots on screen")
		check(decked.size()==r.members.size(),label+": each hull touches the same painted ramp deck")
		check(climbing.size()==r.members.size(),label+": every pilot climbs immediately after leaving the lip")
		check(crossed_below_bank==0,label+": riders clear the raised bank before crossing")
		check(receding_wave,label+": the flood visibly diminishes over the approach to the ramp")
		if not jumps.is_empty(): print("V149_JUMPS ",label," ",JSON.stringify(jumps))
		check(not s.active and s.completed==1 and not r.dead,label+": the same living horde reaches the running ground")
	var report = {"version":ProjectSettings.get_setting("application/config/version"),"checks":checks,"failures":failures,"measurements":measurements,"captures":shots,"physical_device_tested":false}
	var out = FileAccess.open(folder+"/solo.json",FileAccess.WRITE);out.store_string(JSON.stringify(report,"  "));out.close()
	game.queue_free();game = null
	for i in range(8): await process_frame
	print("V149_SOLO ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
