extends SceneTree

const Catalog = preload("res://scripts/bird_catalog.gd")
const Power = preload("res://scripts/fuba_power.gd")
const FPS = 60.0
const DT = 1.0/FPS
const SEED = 181
const PIT_AT = 1233
const JUMP_BEFORE = 90.0
const JUMP_HOLD = .27
const PIT_WIDTH = 240.0
const FIRST_FRAME = 892
const LAST_FRAME = 1584
var game

func _initialize() -> void:
	call_deferred("run")

func fail(message: String) -> void:
	push_error(message)
	quit(1)

func make_course(r) -> void:
	r.start_developer("fuba",1,0,SEED)
	r.next_pattern_world = 1e12

func add_pit(r,width: float) -> Dictionary:
	return r.add_entity("gap",r.ANCHOR+910,r.FLOOR,0,width)

func tick_game() -> void:
	game._physics_process(DT)
	game._process(DT)

func trial(width: float,equipped: bool,should_jump: bool = true,prior_uses: int = 0) -> Dictionary:
	var r = HordeRun.new()
	make_course(r)
	if equipped:
		var data = MonsterCatalog.defaults()
		data.bird_copies = {"pipoco":1,"fuba":1}
		Catalog.equip(data,"pipoco",0)
		Catalog.equip(data,"fuba",1)
		r.bird.configure(data)
		r.bird.fuba_slot().fuba.uses = prior_uses
	for frame in range(PIT_AT):r.advance(DT)
	var gap = add_pit(r,width)
	var jump_at = -1.0
	for frame in range(340):
		if r.members.is_empty():break
		if should_jump and jump_at<0 and gap.x-r.members[0].x<=JUMP_BEFORE:
			jump_at = r.elapsed
			r.jump()
		r.advance(DT,jump_at>=0 and r.elapsed-jump_at<JUMP_HOLD)
	var slot = r.bird.fuba_slot()
	return {"losses":r.losses,"uses":slot.fuba.uses if slot!=null else 0,
		"remaining":slot.fuba.remaining if slot!=null else 0}

func run() -> void:
	var folder = OS.get_environment("HORDA_VIDEO_OUTPUT")
	if folder.is_empty():fail("HORDA_VIDEO_OUTPUT missing");return
	DirAccess.make_dir_recursive_absolute(folder)
	if Catalog.tier("fuba")!=0:fail("Fubá must hatch in the classic tier");return
	if trial(PIT_WIDTH,false).losses!=1:fail("The same jump without Fubá must fail");return
	var safe = trial(110,true)
	if safe.uses!=0 or safe.losses!=0:fail("A safe jump must keep the charge");return
	var wide = trial(420,true)
	if wide.uses!=0 or wide.losses!=1:fail("The gust must not save a jump far from the rim");return
	var walk = trial(PIT_WIDTH,true,false)
	if walk.uses!=0 or walk.losses!=1:fail("The gust must help a jump");return
	var second = trial(PIT_WIDTH,true,true,1)
	if second.uses!=2 or second.losses!=0 or second.remaining<76 or second.remaining>=80:
		fail("Two uses must start the 80-second cooldown, also from slot two");return

	root.size = Vector2i(1280,720)
	root.add_child(load("res://boot.tscn").instantiate())
	for i in range(120):
		await process_frame
		if is_instance_valid(current_scene) and current_scene.has_method("start_run"):
			game = current_scene
			break
	if not is_instance_valid(game):fail("The game did not boot");return
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.test_mode = true
	game.sound.set_enabled(true)
	game.data = MonsterCatalog.defaults()
	game.data.bird_copies = {"fuba":1}
	if not Catalog.equip(game.data,"fuba",0):fail("Fubá could not equip");return
	game.sound.set_mix(game.data.audio_levels)
	game.start_run()
	game.intro_left = 0
	var r = game.runner
	make_course(r)
	r.bird.configure(game.data)
	for i in range(FIRST_FRAME):tick_game()
	if r.bird.fuba.remaining<=0:fail("First charge must still be building before 20 s");return
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	var start_frame = Engine.get_process_frames()
	var gap: Dictionary = {}
	var jump_at = -1.0
	var ready_at = -1.0
	var dive_at = -1.0
	var lift_at = -1.0
	var wind_seen = false
	var hold_observed = false
	for frame in range(FIRST_FRAME,LAST_FRAME):
		if frame==PIT_AT:gap = add_pit(r,PIT_WIDTH)
		if not gap.is_empty() and jump_at<0 and not r.members.is_empty() and gap.x-r.members[0].x<=JUMP_BEFORE:
			jump_at = r.elapsed
			r.jump()
		game.jump_held = jump_at>=0 and r.elapsed-jump_at<JUMP_HOLD
		tick_game()
		var time = (frame-FIRST_FRAME)/FPS
		var fuba = r.bird.fuba
		if ready_at<0 and fuba.ready_age>=0:
			ready_at = time
			if absf(r.elapsed-20.0)>DT:fail("First charge did not take 20 seconds");return
		if dive_at<0 and fuba.phase==Power.Phase.DIVE:dive_at = time
		if lift_at<0 and fuba.uses==1:
			lift_at = time
			var m: Dictionary = r.member_by_id(fuba.member_id)
			hold_observed = not m.is_empty() and absf(float(m.fuba_until)-r.elapsed-.20)<.00001
			if absf(fuba.remaining-50.0)>.00001:fail("First rescue must start a 50-second cooldown");return
		wind_seen = wind_seen or game.effects.particles.any(func(p):return p.kind=="fuba_wind")
		await process_frame
	if ready_at<0 or dive_at<=ready_at or lift_at<=dive_at or not wind_seen or not hold_observed:
		fail("Missing ready, dive, and animated lift in the preview");return
	if r.losses!=0 or r.members.size()!=1 or r.bird.fuba.uses!=1 or not HordeJump.grounded(r,r.members[0]):
		fail("Fubá did not bring the monster to the rim");return
	var report = {"trim_start":start_frame/FPS,"duration":(LAST_FRAME-FIRST_FRAME)/FPS,
		"ready":ready_at,"dive":dive_at,"lift":lift_at,"next_charge":50,"losses":r.losses}
	var file = FileAccess.open(folder+"/capture.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("FUBA_PREVIEW_OK ",JSON.stringify(report))
	game.sound.set_enabled(false)
	game.queue_free()
	game = null
	await process_frame
	await process_frame
	quit(0)
