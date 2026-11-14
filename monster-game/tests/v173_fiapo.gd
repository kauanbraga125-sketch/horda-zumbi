extends SceneTree
const Catalog = preload("res://scripts/bird_catalog.gd")
const Power = preload("res://scripts/fiapo_power.gd")
var checks = 0
var failures: Array[String] = []
var game
var folder = ""

func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:failures.append(message);push_error(message)

func fixture(level: int = 1,second: bool = false) -> Dictionary:
	var d = MonsterCatalog.defaults();d.wallet = 1000000;d.eyes = 10000
	d.bird_copies = {"fiapo":level,"pipoco":3};d.bird_discovered = {"fiapo":true,"pipoco":true}
	d.bird_equipped_slots = ["pipoco","fiapo"] if second else ["fiapo",""]
	d.bird_equipped = d.bird_equipped_slots[0];return d

func model(level: int = 1,second: bool = false):
	var r = HordeRun.new();r.start_developer("bomb",4,0,173)
	r.entities.clear();r.events.clear();r.next_pattern_world = 1e12;r.bird.configure(fixture(level,second));return r

func step(r,seconds: float,dt: float = 1.0/60) -> void:
	for i in range(roundi(seconds/dt)):r.bird.advance(r,dt)

func until_phase(r,power,target: String) -> bool:
	for i in range(480):
		if power.phase==target:return true
		r.bird.advance(r,1.0/60)
	return false

func game_step(seconds: float) -> void:
	for i in range(roundi(seconds*30)):
		game._physics_process(1.0/30);game._process(1.0/30);await process_frame

func game_phase(target: String) -> void:
	for i in range(240):
		if game.runner.bird.fiapo.phase==target:return
		await game_step(1.0/30)
	check(false,"Native gameplay reached "+target)

func snap(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	game._process(0);await process_frame;await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder+"/"+name+".png")==OK,"Native capture "+name)

func run() -> void:
	folder = OS.get_environment("HORDA_VALIDATION_DIR")
	if folder.is_empty():folder = "user://fiapo-v173"
	DirAccess.make_dir_recursive_absolute(folder)
	for level in range(1,4):
		var r = model(level);var p = r.bird.fiapo
		step(r,Power.interval(level)-.1)
		check(p.phase=="idle" and p.civil.is_empty() and r.active_count()==4,"Level %d waits its real interval" % level)
		step(r,.2);check(p.phase=="prepare" and p.civil.is_empty(),"Visible preparation precedes the offscreen NPC at level %d" % level)
		var rows = r.coin_rows.duplicate(true)
		for phase in ["outbound","search","carry","drop","capture"]:
			check(until_phase(r,p,phase),"Animated phase %s at level %d" % [phase,level])
			check(r.active_count()==4 and r.souls==0 and r.recruits==0,"No early recruit in %s at level %d" % [phase,level])
			if phase=="carry":
				var collar = Vector2(p.civil.x,p.civil.y)+Power.COLLAR.rotated(p.civil.bird_angle)
				check(collar.distance_to(p.grip())<.01,"Collar stays attached to claws in "+phase)
		var passenger: Dictionary = p.civil;until_phase(r,p,"recover")
		check(p.deliveries==1 and r.active_count()==5 and r.souls==1 and r.recruits==1,"Exactly one completed capture at level %d" % level)
		r.complete_capture(passenger);check(r.souls==1 and r.active_count()==5,"A converted passenger cannot recruit twice")
		step(r,1)
		check(p.phase=="idle" and p.civil.is_empty(),"Passenger and flight clean up at level %d" % level)
		check(r.events.filter(func(e):return e.type=="bird_fetch").size()==1 and r.events.filter(func(e):return e.type=="bird_fetch_grab").size()==1,"One launch and grab cue at level %d" % level)
		check(r.events.filter(func(e):return e.type=="capture").size()==1 and r.events.filter(func(e):return e.type=="soul").size()==1,"Normal capture and soul events once at level %d" % level)
		check(r.coin_rows==rows and r.entities.is_empty(),"Carry cannot alter coin formations or duplicate civilians at level %d" % level)
		check(Catalog.description(1,level).contains(str(Power.interval(level)).replace(".0","")+" s"),"Collection describes the real cooldown at level %d" % level)
	for activity in ["street","sewer","space"]:
		for second in [false,true]:
			var r = model(1,second)
			if activity=="space":
				r.space.active = true;r.space.phase = "flight"
				for m in r.members:m.y = 430
			elif activity=="sewer":
				r.sewer.active = true;r.sewer.phase = "ride"
				for m in r.members:m.y = 531
			var p = r.bird.companion.fiapo if second else r.bird.fiapo;p.until_fetch = .1;step(r,7)
			check(p.deliveries==1 and r.souls==1 and r.active_count()==5,"Complete rescue in %s, nest %d" % [activity,2 if second else 1])
	for rate in [15,30,60]:
		var r = model();r.bird.fiapo.until_fetch = .1;step(r,7,1.0/rate)
		check(r.souls==1 and r.bird.fiapo.deliveries==1,"Rescue remains single at %d updates/s" % rate)
	for activity in ["sewer","space"]:
		var full = model()
		if activity=="space":full.space.begin(full,true)
		else:full.sewer.begin(full,true)
		for i in range(600):
			full.advance(1.0/60,false)
			if (full.space.active and full.space.phase=="flight") or (full.sewer.active and full.sewer.phase=="ride"):break
		full.space.objects.clear();full.sewer.objects.clear();full.space.next_group = 1e9;full.sewer.next_encounter = 1e9
		full.bird.fiapo.until_fetch = .1
		var initial_count = full.active_count();var initial_souls = full.souls
		for i in range(450):full.advance(1.0/60,false)
		check(not full.dead and full.bird.fiapo.deliveries==1 and full.active_count()==initial_count+1 and full.souls==initial_souls+1,"Full %s physics accepts the delivered member into its moving formation" % activity)
		full = null
	var r = model();var p = r.bird.fiapo;p.until_fetch = .1
	until_phase(r,p,"carry");r.space.active = true;r.space.phase = "ascent"
	var before = p.age;step(r,3)
	check(p.suspended and p.age==before and r.souls==0,"Covered transitions suspend a carried passenger without awarding it")
	r.space.phase = "flight"
	for m in r.members:m.y = 430
	step(r,5);check(p.deliveries==1 and r.souls==1,"A carried passenger resumes after a transition and recruits once")
	r = model();p = r.bird.fiapo;p.until_fetch = .1;until_phase(r,p,"outbound")
	r.sewer.active = true;r.sewer.phase = "entry";step(r,1);r.sewer.phase = "ride";step(r,.2)
	check(p.phase=="idle" and p.civil.is_empty() and r.souls==0,"An interrupted unclaimed pickup cancels cleanly")
	r = model();p = r.bird.fiapo;p.until_fetch = .1;until_phase(r,p,"carry");r.dead = true;step(r,30)
	check(p.deliveries==0 and r.souls==0,"Death cannot finish a late rescue")
	r = model();var d = fixture();d.bird_discovered.erase("fiapo");d.bird_pending = {"id":"fiapo","new":true,"taps":0,"source":"draw"};r.bird.configure(d);step(r,40)
	check(r.bird.id.is_empty() and r.bird.fiapo.deliveries==0,"A locked bird cannot appear or deliver")
	d = fixture();d.bird_equipped_slots = ["pipoco",""];d.bird_equipped = "pipoco";r.bird.configure(d);step(r,35)
	check(r.bird.fiapo.deliveries==0,"An unequipped Fiapo cannot deliver")
	r = model();p = r.bird.fiapo;p.until_fetch = .1;r.transform_left = 2;step(r,5)
	check(p.phase=="idle" and is_equal_approx(p.until_fetch,.1),"Transformation freezes the rescue clock")
	r = model();r.physics_gaps.assign([{"kind":"gap","x":-1000.0,"width":10000.0}]);r.bird.fiapo.until_fetch = .1;step(r,7)
	check(r.bird.fiapo.deliveries==1 and r.souls==1,"Offscreen generation does not require an empty platform in the visible course")
	r = model(3,true);r.bird.pipoco.until_spit = .1;r.bird.companion.fiapo.until_fetch = .1;step(r,7)
	check(r.coins==2 and r.souls==1 and r.active_count()==5,"Pipoco and Fiapo can finish their separate powers together")
	check(r.bird.companion.fiapo.trail.size()<=9,"Bounded flight trail and only one passenger")
	r = null;p = null
	var boot = load("res://boot.tscn").instantiate();root.add_child(boot);current_scene = boot
	for i in range(120):
		await process_frame
		if is_instance_valid(current_scene) and current_scene.has_method("start_run"):game = current_scene;break
	check(is_instance_valid(game),"Updated full game boots through integrity audit")
	if not is_instance_valid(game):quit(1);return
	await process_frame;await process_frame;await process_frame
	game.test_mode = true;game.set_process(false);game.set_physics_process(false);game.sound.set_enabled(true)
	game.data = fixture(3);root.size = Vector2i(1600,720);game.start_run();game.intro_left = 0
	game.runner.start_developer("bomb",4,0,173);game.runner.bird.configure(game.data);game.runner.next_pattern_world = 1e12
	game.runner.bird.fiapo.until_fetch = .1
	await game_phase("outbound");await game_step(.3);await snap("01_approaching_civilian")
	await game_phase("search");await game_step(.15);await snap("02_searching_outside_camera")
	await game_phase("carry");await game_step(.4);await snap("03_returning_with_new_civilian")
	await game_step(.45);await snap("04_carrying_over_horde")
	var held = game.runner.bird.fiapo.civil.duplicate(true);var held_point = game.runner.bird.fiapo.flight
	game.change_screen("pause")
	for i in range(90):game._physics_process(1.0/30)
	check(game.runner.bird.fiapo.civil==held and game.runner.bird.fiapo.flight==held_point,"Real pause freezes bird and passenger together")
	game.change_screen("run");await game_phase("drop");await game_step(.2);await snap("05_releasing")
	check(game.runner.active_count()==4 and game.runner.souls==0,"Real gameplay does not credit the drop before contact")
	await game_phase("capture");await game_step(.22);await snap("06_existing_capture_animation")
	await game_step(1.6);await snap("07_recruited")
	check(game.runner.bird.fiapo.deliveries==1 and game.runner.active_count()==5 and game.runner.souls==1 and game.data.active_souls==1,"Real capture updates horde, soul HUD and saved run data once")
	check(game.sound.clips.has("bird_fiapo") and game.sound.clips.has("creeper_wing"),"Existing bird and lift sounds are available")
	var report = {"checks":checks,"failures":failures,"rendered":DisplayServer.get_name()!="headless","physical_device_tested":false,"new_civilian_assets":0,"max_passengers":1,"max_trail_points":9}
	print("V173_FIAPO ",JSON.stringify(report));game.sound.set_enabled(false);game.sound.set_process(false)
	for player in game.sound.get_children():
		if player is AudioStreamPlayer:player.stop();player.stream = null
	# Release the scene while the audio/render servers are still alive.
	game.queue_free();game = null;current_scene = null
	await process_frame;await process_frame;await create_timer(.25).timeout
	quit(0 if failures.is_empty() else 1)
