extends "res://tests/v134_visual.gd"
var checks = 0
var failures: Array[String] = []
var samples: Array = []
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok and label not in failures: failures.append(label);push_error(label)
func run() -> void:
	folder = OS.get_environment("HORDA_VALIDATION_DIR");assert(not folder.is_empty());DirAccess.make_dir_recursive_absolute(folder)
	game = load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.test_mode = true;game.capture_freeze = true;game.set_physics_process(false);game.sound.set_enabled(false);game.data = MonsterCatalog.defaults()
	for fixture in [[Vector2i(1280,720),6],[Vector2i(1800,810),12],[Vector2i(960,720),12]]:
		root.size = fixture[0];await process_frame
		game.lab_count = int(fixture[1]);game.start_lab("sewer");game.lab_active = false;game.toast_left = 0
		for i in range(game.runner.members.size()): game.runner.members[i].kind = i%2
		var r = game.runner;var s = r.sewer;var old_edge = INF;var approach_checked = false
		for i in range(600):
			old_edge = s.encounter.dock_world-r.world_px-s.DOCK_TO_EDGE;step(STEP)
			var edge_now = s.encounter.dock_world-r.world_px-s.DOCK_TO_EDGE
			if not approach_checked and s.encounter.pending and edge_now>r.ANCHOR+220 and edge_now<r.view_right-110:
				await snap("%dx%d_%02d_aproximacao"%[root.size.x,root.size.y,r.members.size()])
				var img = root.get_texture().get_image();var solid = 0;var pixels = 0
				for dx in range(40,101,3):
					var point = (game.world_to_ui(Vector2(edge_now-dx,r.FLOOR+6))+game.layout_origin)*Vector2(img.get_size())/game.get_viewport_rect().size
					if point.x<0 or point.x>=img.get_width() or point.y<0 or point.y>=img.get_height(): continue
					var color = img.get_pixelv(Vector2i(point));pixels += 1
					if color.g>.35 and color.r>.25: solid += 1
				check(pixels>=10 and solid>pixels*.5,"the pit never erases solid road before its actual edge")
				approach_checked = true
			if s.active: break
		check(approach_checked,"the actual approach is captured before the first fall")
		check(s.active and s.phase=="entry","normal street approach reaches the sewer")
		check(r.members.size()==int(fixture[1]),"the approach preserves every existing member")
		var identities = r.members.map(func(m):return int(m.id))
		check(absf(s.shore_edge()-old_edge)<=r.speed*STEP+1,"the road edge does not jump when the event starts")
		var first_falls: Dictionary = {};var previous: Dictionary = {};var spread_seen = false;var shore_checked = false
		for frame in range(ceili(s.ENTRY_SECONDS/STEP)+5):
			step(STEP)
			if s.phase!="entry": break
			check(absf(s.shore_edge()-(s.entry_edge_world-r.world_px))<.001,"road edge and world travel use the same distance")
			var dropping: Array = []
			for m in r.members:
				var foot = Vector2(m.x,m.y);var source = Vector2(s.starts[m.id]);var ui = game.world_to_ui(foot);var view = game.full_rect()
				if previous.has(m.id): check(foot.distance_to(previous[m.id])<55,"no per-frame teleport during descent")
				previous[m.id] = foot
				if m.sewer_pose=="run":
					check(m.x<=s.shore_edge()+.001,"running feet never continue beyond solid ground")
					check(absf(m.y-(r.FLOOR-s.entry_drop()))<.01,"grounded feet remain on the moving street surface")
				elif m.sewer_pose=="board":
					check(s.shore_edge()<=source.x+.001,"each member only falls after its foot reaches the edge")
					check(m.x>=source.x-.001 and m.x>=s.shore_edge(),"falling members advance into the opening")
					dropping.append(float(m.x))
					if not first_falls.has(m.id): first_falls[m.id] = s.phase_age
					check(ui.y>=view.position.y+125 and ui.y<=view.end.y-12,"camera retains falling members below the HUD and above the bottom")
				if r.members.size()==6 and dropping.size()>=3 and dropping.max()-dropping.min()>100: spread_seen = true
			if frame in [0,20,40,60,80,100,125,160,220,290]:
				await snap("%dx%d_%02d_entrada_%03d"%[root.size.x,root.size.y,r.members.size(),frame])
				if not shore_checked and s.phase_age<.2:
					var clear = RenderingServer.get_default_clear_color();RenderingServer.set_default_clear_color(Color.MAGENTA)
					game.self_modulate.a = 0;game.world_canvas.self_modulate.a = 0;game.foreground_canvas.self_modulate.a = 0
					await process_frame;await RenderingServer.frame_post_draw
					var img = root.get_texture().get_image();var painted = 0;var pixels = 0
					img.save_png(folder+"/%dx%d_street_mask.png"%[root.size.x,root.size.y])
					for dx in range(35,160,3):
						var point = (game.world_to_ui(Vector2(s.shore_edge()+dx,r.FLOOR-s.entry_drop()-6))+game.layout_origin)*Vector2(img.get_size())/game.get_viewport_rect().size
						if point.x<0 or point.x>=img.get_width() or point.y<0 or point.y>=img.get_height(): continue
						var color = img.get_pixelv(Vector2i(point));pixels += 1
						if color.g>.02 or color.r<.98 or color.b<.98: painted += 1
					check(pixels>=10 and painted==0,"the rendered sidewalk ends beyond the opening in every scenery layer")
					RenderingServer.set_default_clear_color(clear)
					game.self_modulate.a = 1;game.world_canvas.self_modulate.a = 1;game.foreground_canvas.self_modulate.a = 1
					await process_frame;await RenderingServer.frame_post_draw
					shore_checked = true
			if frame%12==0: samples.append({"size":str(root.size),"count":r.members.size(),"age":s.phase_age,"edge":s.shore_edge(),"drop":s.entry_drop(),"zoom":game.camera_zoom,"camera_y":game.camera_ground_shift,"members":r.members.map(func(m):return {"id":m.id,"x":m.x,"y":m.y,"pose":m.sewer_pose})})
		check(s.phase=="ride" and r.members.all(func(m):return m.sewer_pose=="ride" and m.get("sewer_onboard",false)),"all members land in their actual seats before the ride begins")
		check(first_falls.size()==r.members.size(),"every member went through the falling animation")
		if r.members.size()==6:
			check(spread_seen,"falling members keep horizontal separation instead of forming a vertical column")
			check(first_falls.values().max()-first_falls.values().min()>.35,"followers leave the edge one after the other")
		s.objects.clear();s.next_encounter = 1e6;s.life.people.clear();s.life.next_scene = 1e6;s.left = .001;step(STEP)
		check(s.phase=="exit","the ramp return still starts from the water")
		for frame in range(ceili(s.EXIT_SECONDS/STEP)+3):
			step(STEP)
			for m in r.members:
				var point = Vector2(m.x,m.y)
				check(point.distance_to(previous[m.id])<55,"ramp flight and return to running remain continuous")
				previous[m.id] = point
			if frame in [40,100,150,210,280,350]: await snap("%dx%d_%02d_saida_%03d"%[root.size.x,root.size.y,r.members.size(),frame])
			if not s.active: break
		check(not s.active and s.completed==1 and not r.dead,"exit lands the living horde in the same run")
		check(r.members.all(func(m):return absf(m.y-r.FLOOR)<.01),"feet meet the normal ground at the exit handoff")
		step(.5)
		check(identities.all(func(id):return r.members.any(func(m):return int(m.id)==id)),"normal camera return does not discard existing members")
	var report = {"version":"0.10.41","checks":checks,"failures":failures,"native_captures":shots,"samples":samples,"physical_device_tested":false}
	var out = FileAccess.open(folder+"/transitions.json",FileAccess.WRITE);out.store_string(JSON.stringify(report,"  "));out.close()
	game.queue_free();game = null
	for i in range(8): await process_frame
	print("V141_TRANSITIONS ",JSON.stringify({"checks":checks,"failures":failures,"captures":shots}));quit(0 if failures.is_empty() else 1)
