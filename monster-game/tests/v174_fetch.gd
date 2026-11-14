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

func fixture() -> Dictionary:
	var d = MonsterCatalog.defaults();d.wallet = 1000000;d.eyes = 10000
	d.bird_copies = {"fiapo":3};d.bird_discovered = {"fiapo":true};d.bird_equipped_slots = ["fiapo",""];d.bird_equipped = "fiapo";return d

func model():
	var r = HordeRun.new();r.start_developer("bomb",4,0,174);r.entities.clear();r.events.clear();r.next_pattern_world = 1e12
	r.bird.configure(fixture());r.bird.fiapo.until_fetch = .1;return r

func step(r,seconds: float) -> void:
	for i in range(roundi(seconds*60)):r.bird.advance(r,1.0/60)

func reach(r,target: String) -> bool:
	for i in range(360):
		if r.bird.fiapo.phase==target:return true
		r.bird.advance(r,1.0/60)
	return false

func game_step(seconds: float) -> void:
	for i in range(roundi(seconds*30)):
		game._physics_process(1.0/30);game._process(1.0/30);await process_frame

func game_phase(target: String) -> void:
	for i in range(240):
		if game.runner.bird.fiapo.phase==target:return
		await game_step(1.0/30)
	check(false,"Gameplay reached "+target)

func snap(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	game._process(0);await process_frame;await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder+"/"+name+".png")==OK,"Native capture "+name)

func run() -> void:
	folder = OS.get_environment("HORDA_VALIDATION_DIR")
	if folder.is_empty():folder = "user://fetch-v174"
	DirAccess.make_dir_recursive_absolute(folder)
	for width in [720.0,1280.0,2000.0]:
		var r = model();r.view_right = width
		for i in range(3):r.add_entity("civilian",500+i*120,r.FLOOR,i)
		var originals = r.entities.duplicate(true);var rng_state = r.rng.state
		var p = r.bird.fiapo;var empty_until_exit = true
		for i in range(180):
			if p.phase=="search":break
			r.bird.advance(r,1.0/60)
			empty_until_exit = empty_until_exit and p.civil.is_empty() and p.serial==0
		check(p.phase=="search" and empty_until_exit,"No NPC exists during preparation or exit at width "+str(width))
		check(p.flight.x-Power.HEIGHT>r.view_right,"Fiapo is fully beyond the right edge at width "+str(width))
		step(r,.2)
		check(p.phase=="search" and p.civil.is_empty() and p.serial==0,"A short hidden search precedes the new NPC")
		check(reach(r,"carry"),"The hidden pickup starts the return flight")
		check(p.serial==1 and not p.civil.is_empty() and p.picked,"Exactly one new bonus NPC is created")
		check(p.flight.x-Power.HEIGHT>r.view_right and p.civil.x-Power.CIVIL_HEIGHT*.7>r.view_right,"Both bird and new NPC are outside the camera at creation")
		check(r.entities==originals and not r.entities.any(func(e):return e.id==p.civil.id),"Existing scene NPCs are neither claimed nor replaced")
		check(r.rng.state==rng_state and r.souls==0 and r.recruits==0,"Fetching changes neither course RNG nor rewards before contact")
		var entered_with_passenger = false
		for i in range(120):
			r.bird.advance(r,1.0/60)
			if p.flight.x+Power.HEIGHT*.5<r.view_right:
				entered_with_passenger = not p.civil.is_empty() and p.picked;break
		check(entered_with_passenger,"The returning bird enters already carrying the passenger")
		check(r.events.filter(func(e):return e.type=="npc_voice").size()==1,"Civilian voice occurs once after re-entry")
		step(r,5)
		check(p.serial==1 and p.deliveries==1 and r.active_count()==5 and r.souls==1,"One generated NPC becomes exactly one captured member")
		check(r.entities==originals,"The entire delivery leaves the scene NPCs untouched")
	var r = model();var p = r.bird.fiapo
	check(reach(r,"outbound"),"Outbound phase begins before a viewport change")
	r.view_right += 650;check(reach(r,"carry") and p.flight.x-Power.HEIGHT>r.view_right,"A widening camera cannot reveal the pickup")
	r = model();p = r.bird.fiapo;reach(r,"search");r.space.active = true;r.space.phase = "ascent";step(r,2)
	check(p.serial==0 and p.civil.is_empty(),"Covered transitions during the hidden search cannot create an NPC")
	r.space.phase = "flight";step(r,.2)
	check(p.phase=="idle" and p.serial==0 and r.souls==0,"An interrupted search resumes without a ghost passenger or reward")
	r = model();p = r.bird.fiapo;reach(r,"search");r.dead = true;step(r,30)
	check(p.serial==0 and r.souls==0,"Death while outside the camera cannot spawn or credit a passenger")
	r = null;p = null
	var boot = load("res://boot.tscn").instantiate();root.add_child(boot);current_scene = boot
	for i in range(120):
		await process_frame
		if is_instance_valid(current_scene) and current_scene.has_method("start_run"):game = current_scene;break
	check(is_instance_valid(game),"Full updated game boots through its audit")
	if not is_instance_valid(game):quit(1);return
	await process_frame;await process_frame;await process_frame
	game.test_mode = true;game.set_process(false);game.set_physics_process(false);game.sound.set_enabled(true)
	game.data = fixture();root.size = Vector2i(1600,720);game.start_run();game.intro_left = 0
	game.runner.start_developer("bomb",4,0,174);game.runner.bird.configure(game.data);game.runner.next_pattern_world = 1e12;game.runner.bird.fiapo.until_fetch = .1
	await game_phase("outbound");await game_step(.4);await snap("01_leaving_without_passenger")
	await game_phase("search");await game_step(.15);await snap("02_both_absent_from_camera")
	check(game.runner.bird.fiapo.civil.is_empty() and game.runner.bird.fiapo.serial==0,"Real gameplay has no waiting NPC in the scenery")
	var before = game.runner.bird.fiapo.age;game.change_screen("pause")
	for i in range(90):game._physics_process(1.0/30)
	check(game.runner.bird.fiapo.age==before and game.runner.bird.fiapo.serial==0,"Pausing outside the camera also pauses generation")
	game.change_screen("run");await game_phase("carry");await game_step(.4);await snap("03_reentry_with_new_passenger")
	await game_phase("capture");await game_step(1.5);await snap("04_bonus_member_joined")
	check(game.runner.active_count()==5 and game.runner.souls==1 and game.runner.bird.fiapo.serial==1,"Actual return, drop and capture add a single new member")
	var report = {"checks":checks,"failures":failures,"rendered":DisplayServer.get_name()!="headless","physical_device_tested":false,"origin":"outside_camera","scene_npcs_consumed":0,"max_generated_passengers":1}
	print("V174_FETCH ",JSON.stringify(report));game.sound.set_enabled(false);game.sound.set_process(false)
	for player in game.sound.get_children():
		if player is AudioStreamPlayer:player.stop();player.stream = null
	game.queue_free();game = null;current_scene = null
	await process_frame;await process_frame;await create_timer(.25).timeout;quit(0 if failures.is_empty() else 1)
