extends "res://tests/v134_visual.gd"
const Birds = preload("res://scripts/bird_catalog.gd")
var frame_number = 0
func capture() -> void:
	game.configure_layout();game.queue_redraw();game.world_canvas.queue_redraw();game.foreground_canvas.queue_redraw()
	await process_frame;await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_jpg(folder+"/frame-%04d.jpg" % frame_number,.93)==OK)
	if frame_number%180==0: print("V136_PREVIEW_FRAME ",frame_number)
	frame_number += 1
func space_input(s) -> void:
	var goal = Vector2(435,405);var nearest = INF
	for e in s.objects:
		if e.taken or e.x<s.x-15 or e.x>s.x+590: continue
		if e.kind in ["gate","exit"]:
			if e.x<nearest: nearest = e.x;goal = Vector2(440,float(e.y)+s.member_height(game.runner)*.5)
		elif e.kind in ["astronaut","pod","coin","core","alien_power","orbital_power"] and e.x<nearest:
			nearest = e.x;goal = Vector2(440,float(e.y)+s.member_height(game.runner)*.5)
		elif s.battle.SHIPS.has(e.kind) and (not bool(e.get("counter",false)) or bool(e.get("core_open",false))):
			if e.x<nearest:
				nearest = e.x;goal = Vector2(435,float(e.y)+s.member_height(game.runner)*.5)
				if e.x-s.x<235 and absf(e.y-(s.y-s.member_height(game.runner)*.5))<65: game.perform_action("space_dash")
	var delta = (goal-Vector2(s.aim_x,s.aim_y)).limit_length(42)
	var drag = InputEventScreenDrag.new();drag.index = 42;drag.position = Vector2(350,420);drag.relative = delta*game.camera_zoom;game._input(drag)
func run() -> void:
	folder = OS.get_environment("HORDA_VALIDATION_DIR");assert(not folder.is_empty());DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280,720);game = load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.test_mode = true;game.capture_freeze = true;game.set_physics_process(false);game.sound.set_enabled(false)
	game.data = MonsterCatalog.defaults();game.data.wallet = 1000000;game.data.eyes = 10000
	game.perform_action("birds_open");game.perform_action("bird_draw")
	for frame in range(120):
		game.birds_ui.update(game,1.0/30);game.ui_time += 1.0/30;await capture()
	game.perform_action("bird_done")
	for id in Birds.IDS: game.data.bird_copies[id] = 3;game.data.bird_essence[id] = 6
	for index in range(5):
		game.birds_ui.selected = index
		for frame in range(45): game.ui_time += 1.0/30;await capture()
	game.perform_action("back");game.lab_count = 20;game.start_lab("space");game.lab_active = false
	game.runner.active_cosmetics.clear();game.runner.bird.configure({})
	for i in range(game.runner.members.size()):
		var m = game.runner.members[i];m.kind = i%2;m.cosmetics_0 = ["z_plumber"] if i%3==0 else [];m.cosmetics_1 = ["s_ice"] if i%3==1 else []
	var s = game.runner.space;s.early_offered = true
	var touch = InputEventScreenTouch.new();touch.index = 42;touch.position = Vector2(350,420);touch.pressed = true;game._input(touch)
	for frame in range(1230):
		if s.phase=="flight" and not game.runner.dead: space_input(s)
		step(1.0/30);await capture()
		if s.active: assert(game.effects.deaths.is_empty(),"No ground coffin animation in space")
	var flight_report = {"souls":game.runner.souls,"members":game.runner.active_count(),"losses":game.runner.losses,"max_horde":game.runner.max_horde,"encounters":s.routes.history.duplicate(true),"phase":s.phase,"completed":s.completed_flights}
	game.release_touch(42);game.lab_count = 9;game.start_lab("sewer");game.lab_active = false
	game.runner.bird.configure({});var sewer = game.runner.sewer
	for i in range(game.runner.members.size()):
		var m = game.runner.members[i];m.cosmetics_0 = ["z_plumber"] if i%3==0 else [];m.cosmetics_1 = ["s_ice"] if i%3==1 else []
	var jumped: Dictionary = {};var held_until = -1.0
	for frame in range(1110):
		if sewer.active and sewer.phase=="ride" and not game.runner.dead:
			for e in sewer.objects:
				if e.taken or e.kind not in ["rubble","barrel"] or jumped.has(e.get("encounter",-1)): continue
				var eta = (float(e.x)-float(sewer.boats[0].x))/sewer.scroll_speed(game.runner)
				if eta<.45 and eta>.20:
					game.press_at(Vector2(900,350),81);held_until = sewer.age+.16;jumped[e.encounter] = true
			if held_until>=0 and sewer.age>=held_until: game.release_touch(81);held_until = -1
		for substep in range(2):
			game.runner.advance(STEP,game.jump_held);game.update_camera(STEP);game.configure_layout();game.consume_run_events();game.update_run_visuals(STEP);game.ui_time += STEP
			game.toast_left = maxf(0,game.toast_left-STEP);game.perfect_left = maxf(0,game.perfect_left-STEP)
		await capture()
	var report = {"version":"0.10.36","frames":frame_number,"fps":30,"space":flight_report,"sewer":{"souls":game.runner.souls,"members":game.runner.active_count(),"losses":game.runner.losses,"captures":sewer.captured,"completed":sewer.completed,"safe_jumps":sewer.safe_jumps,"encounters":sewer.history},"real_touch_inputs":true,"physical_device_tested":false}
	var file = FileAccess.open(folder+"/replay.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	game.set_process(false);game.queue_free();game = null
	for i in range(8): await process_frame
	preload("res://scripts/bird_art.gd").textures.clear()
	print("V136_PREVIEW_OK ",frame_number," native frames");quit()
