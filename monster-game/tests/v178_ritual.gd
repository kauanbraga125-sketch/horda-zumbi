extends SceneTree
const Catalog = preload("res://scripts/bird_catalog.gd")
const Art = preload("res://scripts/bird_art.gd")
const Power = preload("res://scripts/agourinho_power.gd")
var checks = 0
var failures: Array[String] = []
var game
var folder = ""

func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:failures.append(message);push_error(message)

func fixture(level: int = 3,second: bool = false) -> Dictionary:
	var d = MonsterCatalog.defaults();d.bird_copies = {"agourinho":level,"pipoco":3};d.bird_discovered = {"agourinho":true,"pipoco":true}
	d.bird_equipped_slots = ["pipoco","agourinho"] if second else ["agourinho",""];d.bird_equipped = d.bird_equipped_slots[0];return d

func model(count: int = 4,level: int = 3,second: bool = false):
	var r = HordeRun.new();r.start_developer("bomb",count,0,178);r.entities.clear();r.events.clear();r.next_pattern_world = 1e12
	r.bird.configure(fixture(level,second));return r
func owl(r):return r.bird.companion if r.bird.id!="agourinho" else r.bird
func step(r,seconds: float,dt: float = 1.0/60) -> void:
	for i in range(roundi(seconds/dt)):r.advance(dt,false)
func game_step(seconds: float) -> void:
	for i in range(roundi(seconds*30)):
		game._physics_process(1.0/30);game._process(1.0/30);await process_frame
func snap(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	game._process(0);await process_frame;await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder+"/"+name+".png")==OK,"Native capture "+name)

func run() -> void:
	folder = OS.get_environment("HORDA_VALIDATION_DIR")
	if folder.is_empty():folder = "user://ritual-v178"
	DirAccess.make_dir_recursive_absolute(folder)
	check(Art.ritual_texture().get_size()==Vector2(1024,512) and Art.portal_texture().get_size()==Vector2(512,512),"Bounded action and portal textures load")
	var image = Art.ritual_texture().get_image()
	for i in range(8):
		var used = image.get_region(Rect2i(i%4*256,int(i/4)*256,256,256)).get_used_rect()
		check(used.position.x>=12 and used.position.y>=12 and used.end.x<=244 and used.end.y<=244,"Action pose has complete feather margins: "+str(i))
	for count in [1,4,12]:
		for second in [false,true]:
			var r = model(count,3,second);var bird = owl(r)
			while r.members.size()>1:
				var before = r.active_count();r.hit_grace = 0;r.damage(0,"impact")
				check(r.active_count()==before-1 and not bird.rescued and not r.bird.rescue_pending(),"Ordinary losses do not start the invocation")
			var id = int(r.members[0].id);var species = int(r.members[0].kind)
			r.members[0].cosmetics_0 = ["saved-marker"]
			var coins = r.coins;var souls = r.souls;var distance = r.world_px;var elapsed = r.elapsed
			r.hit_grace = 0;r.damage(0,"impact")
			check(r.members.is_empty() and r.active_count()==0 and r.losses==count,"The entire horde actually dies and all losses are recorded")
			check(not r.dead and bird.rescued and r.bird.rescue_pending(),"Game over waits for the single charged invocation")
			step(r,3.3)
			check(r.members.is_empty() and r.active_count()==0 and not bird.agourinho.restored,"No creature is alive before 3.35 seconds")
			check(r.world_px==distance and r.elapsed==elapsed and r.coins==coins and r.souls==souls,"Travel, timers and rewards freeze while the horde is dead")
			r.add_member(0);check(r.members.is_empty(),"Other recruit callbacks cannot refill the empty horde during the ritual")
			step(r,.1)
			check(r.members.size()==1 and int(r.members[0].id)==id and int(r.members[0].kind)==species and r.members[0].cosmetics_0==["saved-marker"],"Exactly the saved identity, species and accessories return")
			check(r.members[0].agourinho_hidden and r.world_px==distance and not r.damage(0,"impact"),"The emerging creature has no duplicate rendering or gameplay contact")
			step(r,.6)
			check(not r.bird.rescue_pending() and not r.members[0].agourinho_hidden and r.active_count()==1,"The 3.9-second sequence ends with one playable creature")
			check(r.coins==coins and r.souls==souls and r.recruits==0 and r.losses==count,"Resurrection grants no recruit, currency or loss refund")
			var cues = r.events.filter(func(e):return e.type in ["agourinho_begin","agourinho_gather","agourinho_portal","bird_rescue","agourinho_end"]).map(func(e):return e.type)
			check(cues==["agourinho_begin","agourinho_gather","agourinho_portal","bird_rescue","agourinho_end"],"Death, gather, portal, return and release cues occur once in order")
			r.add_member(0,false);r.hit_grace = 0;r.remove_member(1,"impact");r.hit_grace = 0;r.damage(0,"impact")
			check(r.dead and r.members.is_empty() and not r.bird.rescue_pending(),"Regrowing the horde grants no second resurrection")
	for lv in [1,2,3]:
		var r = model(1,lv);r.damage(0,"impact");step(r,3.4)
		check(is_equal_approx(r.hit_grace,1+(lv-1)*.5),"Protection starts on return and does not expire during emergence")
	for rate in [15,30,60]:
		var r = model(1);r.damage(0,"impact");var returned_at = 0.0
		for i in range(rate*4):
			r.advance(1.0/rate,false)
			if not r.members.is_empty():returned_at = (i+1.0)/rate;break
		check(returned_at>=Power.RETURN_AT-.001 and returned_at<=Power.RETURN_AT+1.0/rate+.001,"Return timing is stable at "+str(rate)+" updates per second")
	var r = model(2);r.members[0].falling = true;r.cached_active = 0;r.remove_member(0,"fall")
	check(not owl(r).rescued and r.members.size()==1,"A falling member is not the final loss while another remains viable")
	r = model(4)
	for m in r.members:m.falling = true;m.y = r.FLOOR+190
	r.remove_member(3,"fall");step(r,.1)
	check(r.members.is_empty() and r.losses==4,"A simultaneous fall removes all doomed bodies before invocation")
	step(r,3.9);check(r.active_count()==1 and not r.dead,"A simultaneous fall resurrects one creature only")
	r = model(4);r.add_entity("gap",r.ANCHOR-120,r.FLOOR,0,520);step(r,8)
	check(owl(r).rescued and r.active_count()==1 and r.losses==4 and not r.dead,"Real pit physics permits the complete death and delayed return")
	for mode in ["space","sewer","sky"]:
		r = model(1)
		if mode=="space":r.space.active = true;r.space.phase = "flight"
		elif mode=="sewer":r.sewer.active = true;r.sewer.phase = "ride"
		else:r.sky.active = true
		r.damage(0,"impact");step(r,3.2)
		check(r.members.is_empty() and r.bird.rescue_pending(),"The empty-horde invocation is preserved in "+mode)
		if mode=="space":r.space.finish(r)
		elif mode=="sewer":r.sewer.finish(r)
		else:r.sky.finish(r)
		check(r.space.active or r.sewer.active or r.sky.active,"The activity cannot exit in the middle of a pending ritual")
		step(r,.7)
		check(r.members.size()==1 and not r.members[0].falling and not r.dead,"One creature returns to its activity in "+mode)
	r = model(1);r.shields = 1;r.damage(0,"impact")
	check(not owl(r).rescued and r.members.size()==1,"An existing shield prevents death without consuming invocation")
	r = model(1);r.damage(0,"impact");step(r,1);r.finish();step(r,5)
	check(r.dead and r.members.is_empty() and not r.bird.rescue_pending(),"An explicitly abandoned ritual never revives later")
	r = model(1);r.damage(0,"impact");r.start_developer("bomb",1,0,179);r.entities.clear();r.bird.configure(fixture());r.damage(0,"impact");step(r,4)
	check(r.active_count()==1 and owl(r).rescued and not r.dead,"A fresh match receives its own one-time ritual")
	r = model(1);var d = fixture();d.bird_discovered = {};d.bird_pending = {"id":"agourinho","new":true,"source":"draw","taps":0};r.bird.configure(d);r.damage(0,"impact")
	check(r.dead and not r.bird.rescue_pending(),"A locked owl cannot postpone defeat")
	r = null;d = {}
	var boot = load("res://boot.tscn").instantiate();root.add_child(boot);current_scene = boot
	for i in range(120):
		await process_frame
		if is_instance_valid(current_scene) and current_scene.has_method("start_run"):game = current_scene;break
	check(is_instance_valid(game),"Full game boots with its updated audit")
	if not is_instance_valid(game):quit(1);return
	await process_frame;await process_frame;await process_frame
	game.test_mode = true;game.set_process(false);game.set_physics_process(false);game.sound.set_enabled(true)
	game.data = fixture();root.size = Vector2i(1600,720);game.start_run();game.intro_left = 0
	game.runner.start_developer("bomb",1,0,178);game.runner.entities.clear();game.runner.next_pattern_world = 1e12;game.runner.bird.configure(game.data)
	game.runner.damage(0,"impact");await game_step(.3);await snap("01_horde_dead_owl_reacts")
	check(game.runner.members.is_empty() and game.end_delay<0,"Actual game remains on the empty-horde invocation, not the results screen")
	var age = game.runner.bird.agourinho.age;game.change_screen("pause")
	for i in range(60):game._physics_process(1.0/30)
	check(game.runner.bird.agourinho.age==age and game.runner.members.is_empty(),"Pause freezes the complete ritual and its pending return")
	game.change_screen("run");await game_step(.7);await snap("02_gathering_with_wingbeats")
	await game_step(1.1);await snap("03_opaque_vortex_no_monster")
	check(game.runner.members.is_empty() and game.runner.active_count()==0,"The open dimensional portal contains no living creature yet")
	await game_step(1.4);await snap("04_creature_emerges_after_three_seconds")
	check(game.runner.members.size()==1 and game.runner.members[0].agourinho_hidden,"Only the portal draws the emerging real survivor")
	await game_step(.5);await snap("05_play_resumes_with_one_creature")
	check(not game.runner.bird.rescue_pending() and game.runner.active_count()==1 and not game.runner.dead,"The completed ritual returns control with one survivor")
	check(game.sound.last_played.has("ritual_fill") and game.sound.last_played.has("space_energy") and game.sound.last_played.has("revive"),"Gather, portal and resurrection sounds were requested by their timed events")
	var report = {"checks":checks,"failures":failures,"rendered":DisplayServer.get_name()!="headless","physical_device_tested":false,"trigger":"full_horde_death","return_seconds":Power.RETURN_AT,"ritual_seconds":Power.DURATION,"max_resurrections_per_run":1,"max_returned_creatures":1,"action_frames":8,"portal_pixels":[512,512],"max_motes":14}
	print("V178_RITUAL ",JSON.stringify(report));game.sound.set_enabled(false);game.sound.set_process(false)
	for player in game.sound.get_children():
		if player is AudioStreamPlayer:player.stop();player.stream = null
	game.queue_free();game = null;current_scene = null
	await process_frame;await process_frame;await create_timer(.25).timeout;quit(0 if failures.is_empty() else 1)
