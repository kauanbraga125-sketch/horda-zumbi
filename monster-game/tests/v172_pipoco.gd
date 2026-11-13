extends SceneTree
const Catalog = preload("res://scripts/bird_catalog.gd")
const Art = preload("res://scripts/bird_art.gd")
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
	d.bird_copies = {"pipoco":level,"fiapo":1};d.bird_discovered = {"pipoco":true,"fiapo":true}
	d.bird_equipped_slots = ["fiapo","pipoco"] if second else ["pipoco",""]
	d.bird_equipped = d.bird_equipped_slots[0];return d

func model(level: int = 1,second: bool = false):
	var r = HordeRun.new();r.start_developer("bomb",4,0,172)
	r.entities.clear();r.events.clear();r.next_pattern_world = 1e12
	r.bird.configure(fixture(level,second));return r

func step_bird(r,seconds: float,dt: float = 1.0/60) -> void:
	for i in range(roundi(seconds/dt)):r.bird.advance(r,dt)

func snap(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	game._process(0);await process_frame;await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder+"/"+name+".png")==OK,"Native capture "+name)

func run() -> void:
	folder = OS.get_environment("HORDA_VALIDATION_DIR")
	if folder.is_empty():folder = "user://pipoco-v172"
	DirAccess.make_dir_recursive_absolute(folder)
	for level in range(1,4):
		var r = model(level);var power = r.bird.pipoco
		step_bird(r,24-(level-1)*4-.1)
		check(power.action_age<0 and power.coins.is_empty() and r.coins==0,"Level %d waits its full interval" % level)
		step_bird(r,.2)
		check(power.action_age>=0 and power.coins.is_empty(),"Anticipation precedes coins at level %d" % level)
		step_bird(r,.5)
		check(power.released==1 and power.coins.size()==1 and r.coins==0,"First visible coin precedes its reward at level %d" % level)
		step_bird(r,.2)
		check(power.released==2 and power.coins.size()==2,"Second coin is staggered at level %d" % level)
		check(r.events.filter(func(e):return e.type=="bird_spit").size()==1,"One spit sound per pair at level %d" % level)
		r.new_coin_row(3);var rows = r.coin_rows.duplicate(true);step_bird(r,3)
		check(r.coins==2 and power.coins.is_empty(),"Two physical pickups count once at level %d" % level)
		check(r.coin_rows==rows and not r.events.any(func(e):return e.type=="perfect"),"Course Perfect accounting stays independent at level %d" % level)
		check(r.events.filter(func(e):return e.type=="coin" and e.get("bird_bonus",false)).size()==2,"Two pickup events for normal HUD and piano at level %d" % level)
		check(Catalog.description(0,level).contains(str(24-(level-1)*4)+" s"),"Collection shows real interval %d" % level)
		var before = r.coins;r.bird.on_perfect(r)
		check(r.coins==before,"No invisible Perfect bonus at level %d" % level)
	for rate in [15,30,60]:
		var r = model();r.bird.pipoco.until_spit = .1;step_bird(r,5,1.0/rate)
		check(r.coins==2 and r.bird.pipoco.coins.is_empty(),"Continuous pickup at %d updates per second" % rate)
	var r = model();r.bird.pipoco.until_spit = .1;step_bird(r,.9)
	check(r.bird.pipoco.coins.size()==2,"Visible airborne interval")
	var coin = r.bird.pipoco.coins[0];var old: Vector2 = coin.point;step_bird(r,.2)
	check(coin.point.x>old.x and coin.point.y>old.y,"Coins arc forward then fall")
	step_bird(r,.5);check(coin.bounces==1 and coin.velocity.y<0,"Street coin bounces once")
	r = model();r.bird.pipoco.until_spit = .1
	for m in r.members:m.x = -1000
	step_bird(r,7);check(r.coins==0 and r.bird.pipoco.coins.is_empty(),"Missed coins expire without automatic credit")
	r = model();var rng_state = r.rng.state;var course_state = r.course_rng.state
	r.bird.pipoco.until_spit = 0;step_bird(r,2)
	check(r.rng.state==rng_state and r.course_rng.state==course_state,"Power does not change course or reward RNG")
	r = model(3,true);r.bird.companion.pipoco.until_spit = .1;step_bird(r,5)
	check(r.coins==2 and r.bird.id=="fiapo" and r.bird.companion.id=="pipoco","Works from the second nest")
	var data = fixture();data.bird_pending = {"id":"pipoco","new":true,"taps":0,"source":"draw"};data.bird_discovered.erase("pipoco")
	r.bird.configure(data);step_bird(r,30)
	check(r.bird.id.is_empty() and r.bird.pipoco.cycles==0,"Unrevealed Pipoco cannot spawn or cast")
	data = fixture();data.bird_equipped_slots = ["fiapo",""];data.bird_equipped = "fiapo";r.bird.configure(data);step_bird(r,30)
	check(r.bird.pipoco.cycles==0,"Unequipped Pipoco cannot cast")
	r = model();r.bird.pipoco.until_spit = .1;r.transform_left = 2;step_bird(r,2)
	check(is_equal_approx(r.bird.pipoco.until_spit,.1) and r.bird.pipoco.cycles==0,"Transformation suspends power clock")
	r.transform_left = 0;r.space.active = true;r.space.phase = "ascent";step_bird(r,2)
	check(r.bird.pipoco.cycles==0,"Ascent suspends spitting")
	r.space.active = false;r.dead = true;step_bird(r,30)
	check(r.bird.pipoco.cycles==0,"No rewards after death")
	for activity in ["space","sewer"]:
		for second in [false,true]:
			r = model(1,second)
			if activity=="space":
				r.space.active = true;r.space.phase = "flight";r.space.x = r.ANCHOR;r.space.y = 430
				for m in r.members:m.y = 430
			else:
				r.sewer.active = true;r.sewer.phase = "ride";r.sewer.boats.assign([{"x":r.ANCHOR,"y":531.0}])
				for m in r.members:m.y = 531
			var power = r.bird.companion.pipoco if second else r.bird.pipoco;power.until_spit = .1
			step_bird(r,.9)
			check(power.mode==activity and power.coins.size()==2,"Visible cast in %s, nest %d" % [activity,2 if second else 1])
			step_bird(r,4.1)
			check(r.coins==2 and power.coins.is_empty(),"Natural reachable trajectories in %s, nest %d" % [activity,2 if second else 1])
			power.until_spit = 0;step_bird(r,.9);r.space.active = false;r.sewer.active = false;step_bird(r,.1)
			check(r.coins==2 and power.coins.is_empty(),"Scene change clears live objects without hidden payout: "+activity)
	r = model();r.bird.pipoco.until_spit = 0
	var max_coins = 0;var max_sparks = 0
	for i in range(1200):
		r.bird.pipoco.until_spit = 0;r.bird.advance(r,1.0/60)
		max_coins = maxi(max_coins,r.bird.pipoco.coins.size());max_sparks = maxi(max_sparks,r.bird.pipoco.sparks.size())
	check(max_coins<=12 and max_sparks<=16,"Stress test keeps fixed object limits")
	check(Art.spit_texture().get_size()==Vector2(1024,512),"Bounded action atlas: 2 MiB decoded RGBA")
	r = null;coin = {}
	var boot = load("res://boot.tscn").instantiate();root.add_child(boot);current_scene = boot
	for i in range(120):
		await process_frame
		if is_instance_valid(current_scene) and current_scene.has_method("start_run"):game = current_scene;break
	check(is_instance_valid(game),"Full updated game boots through resource audit")
	if not is_instance_valid(game):quit(1);return
	await process_frame;await process_frame;await process_frame
	game.test_mode = true;game.set_process(false);game.set_physics_process(false);game.sound.set_enabled(true)
	game.data = fixture(3);root.size = Vector2i(1600,720);game.start_run();game.intro_left = 0
	game.runner.start_developer("bomb",4,0,172);game.runner.bird.configure(game.data);game.runner.next_pattern_world = 1e12
	game.runner.bird.pipoco.until_spit = .1
	for i in range(15):game._physics_process(1.0/30);game._process(1.0/30)
	await snap("01_inflated_cheeks")
	for i in range(8):game._physics_process(1.0/30);game._process(1.0/30)
	await snap("02_spitting")
	check(game.sound.players.any(func(p):return p.stream==game.sound.clips.get("bird_pipoco")),"Spit cue reaches real mixer")
	var held = game.runner.bird.pipoco.coins.duplicate(true);var clock_before = game.runner.bird.pipoco.until_spit
	game.change_screen("pause")
	for i in range(60):game._physics_process(1.0/30)
	check(game.runner.bird.pipoco.coins==held and game.runner.bird.pipoco.until_spit==clock_before,"Pause freezes both coin objects and power clock")
	game.change_screen("run")
	for i in range(10):game._physics_process(1.0/30);game._process(1.0/30)
	await snap("03_falling_coins")
	for i in range(14):game._physics_process(1.0/30);game._process(1.0/30)
	await snap("04_bounce")
	for i in range(90):game._physics_process(1.0/30);game._process(1.0/30)
	check(game.runner.coins==2 and game.data.wallet==1000002,"Gameplay credits wallet and run on actual pickups")
	await snap("05_collected")
	game.runner.run_items.double_coins = true;game.runner.bird.pipoco.until_spit = .1
	for i in range(150):game._physics_process(1.0/30);game._process(1.0/30)
	check(game.runner.coins==6 and game.data.wallet==1000006,"Double-coins item applies once to each physical pickup")
	if DisplayServer.get_name()!="headless":
		var image = Art.spit_texture().get_image();var valid = 0
		for index in range(8):
			var region = image.get_region(Rect2i(index%4*256,int(index/4)*256,256,256))
			if region.get_used_rect().size.x>150 and region.get_pixel(0,0).a<.01:valid += 1
		check(valid==8,"Eight full poses have transparent gutters")
	var report = {"checks":checks,"failures":failures,"rendered":DisplayServer.get_name()!="headless","max_coins":max_coins,"max_sparks":max_sparks,"physical_device_tested":false}
	print("V172_PIPOCO ",JSON.stringify(report));game.sound.set_enabled(false);game.sound.set_process(false)
	# Let the audio thread release decoder references before engine shutdown.
	for player in game.sound.get_children():
		if player is AudioStreamPlayer:player.stop();player.stream = null
	# Release the scene while the audio/render servers are still alive.
	game.queue_free();game = null;current_scene = null
	await process_frame;await process_frame;await create_timer(.25).timeout
	quit(0 if failures.is_empty() else 1)
