extends SceneTree
## Visual contracts plus real collision/steering regressions from the phone photos.
var checks = 0
var failures: Array[String] = []
var observations: Array = []
const STEP = 1.0/60.0

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label);push_error(label)
func ticks(r,n: int) -> void:
	for i in range(n): r.advance(STEP,false)
func flight(count: int = 4):
	var r = HordeRun.new();r.start_developer("space",count,0,133042)
	r.developer_kind = "validation";r.next_pattern_world = 1e12;r.entities.clear();r.events.clear()
	r.space.begin(r,true);r.space.phase = "flight";r.space.phase_age = 0;r.space.next_group = 1e6
	ticks(r,45);r.space.objects.clear();r.events.clear();return r

func run() -> void:
	# The first instance used to own the atlas frames, making the next lab invisible.
	var first = preload("res://scripts/space.gd").new();first.ensure_art()
	var second = preload("res://scripts/space.gd").new();second.ensure_art()
	for key in ["npcs","props"]:
		check(first.tiles.has(key) and second.tiles.has(key),"new sessions retain atlas "+key)
		check(second.tiles[key].size()==16,"all frames survive a lab change "+key)
	for i in range(100):
		var p = HordeActor.space_pose("float",i*.07,sin(i)*100)
		check(p.state=="fly" and p.air_age>.14,"floating never cycles through takeoff/fall/run")
	for pose in ["charge","launch","board","hurt","return","pilot"]:
		check(HordeActor.space_pose(pose,1,0).state!="run","dedicated space pose "+pose)
	var neutral = flight();var old_y = neutral.space.y
	neutral.jump();ticks(neutral,90)
	check(absf(neutral.space.y-old_y)<2,"tap does not trigger unrelated vertical launch")
	check(neutral.space.manual_control,"space defaults to direct steering")
	# A laser must warn first, have an emitter and only hit within its finite segment.
	var beam = flight();var c = beam.space.battle.member_centre(beam,0);var initial = beam.active_count()
	beam.space.add_object("beam",c.x+180,c.y,{"speed":0.0,"length":420.0,"contacts":{},"hit_at":-10.0})
	ticks(beam,70);check(beam.active_count()==initial,"laser warning cannot hurt the horde")
	ticks(beam,25);check(beam.active_count()==initial-1,"warned laser causes one real loss")
	ticks(beam,35);check(beam.active_count()==initial-1,"one laser cannot erase a small horde")
	var safe = flight();c = safe.space.battle.member_centre(safe,0);initial = safe.active_count()
	safe.space.add_object("beam",float(safe.members.map(func(m):return float(m.x)).min())-80,c.y,{"speed":0.0,"length":90.0,"contacts":{},"hit_at":-10.0})
	ticks(safe,120);check(safe.active_count()==initial,"laser cannot hit behind its emitter")
	# No ship remains parked in front of the player for seven seconds.
	var passing = flight();var ship = passing.space.battle.spawn_ship(passing.space,passing,"cargo",900,260)
	var start = float(ship.x);passing.hit_grace = 100;ticks(passing,480)
	check(ship not in passing.space.objects and float(ship.x)<passing.view_left-220,"ship exits view instead of accumulating")
	passing.speed = 2000;check(passing.space.battle.scroll_speed(passing)<=460,"space reaction speed bounded at high ground tunnels")
	# A visible captured hull owns collision while the horde is inside.
	var pilot = flight(8);var b = pilot.space.battle;var s = pilot.space
	b.pilot_kind = "tour_bus";b.pilot_left = 5;b.pilot_hp = 3
	var centre = Vector2(MonsterCatalog.ANCHOR+25,s.y-48)
	check(b.nearest_member(pilot,centre,20)>=0,"captured hull receives contacts")
	check(b.nearest_member(pilot,centre-Vector2(260,0),20)==-1,"invisible old formation cannot receive contacts")
	initial = pilot.active_count();b.hurt(s,pilot,0,"space_ship",centre)
	check(b.pilot_hp==2 and pilot.active_count()==initial,"hull absorbs one visible hit")
	s.age += .2;b.hurt(s,pilot,0,"space_ship",centre)
	check(b.pilot_hp==2,"hull has readable damage cooldown")
	s.age += .6;b.hurt(s,pilot,0,"space_ship",centre)
	s.age += .6;b.hurt(s,pilot,0,"space_ship",centre)
	check(b.pilot_left<=0 and pilot.active_count()==initial,"broken hull returns real party without deleting members")
	var hidden = flight(8);hidden.space.battle.pilot_kind = "tour_bus";hidden.space.battle.pilot_left = 5;hidden.space.battle.pilot_hp = 3
	var hidden_y = hidden.space.battle.member_centre(hidden,3).y
	hidden.space.add_object("beam",180,hidden_y,{"speed":0.0,"length":200.0,"contacts":{},"hit_at":-10.0})
	ticks(hidden,120);check(hidden.space.battle.pilot_hp==3,"laser ignores invisible tail behind captured hull")
	var hull_laser = flight(8);hull_laser.space.battle.pilot_kind = "tour_bus";hull_laser.space.battle.pilot_left = 5;hull_laser.space.battle.pilot_hp = 3
	hull_laser.space.add_object("beam",600,hull_laser.space.y-48,{"speed":0.0,"length":500.0,"contacts":{},"hit_at":-10.0})
	ticks(hull_laser,120);check(hull_laser.space.battle.pilot_hp==2,"laser hits visible hull once instead of hidden members")
	# Distinct layer decks and a threat budget, including quiet reward encounters.
	var variety = flight(20);var kinds = {}
	for layer in range(4):
		var sequence = []
		var layer_r = flight(20);layer_r.space.altitude = [0.0,1100.0,2150.0,3400.0][layer]
		for i in range(14):
			layer_r.space.objects.clear();layer_r.space.battle.spawn(layer_r.space,layer_r)
			sequence.append(layer_r.space.battle.encounters[-1].kind)
			for e in layer_r.space.objects: kinds[e.kind] = true
		check("rescue" in sequence and "coins" in sequence,"reward breaks between threats in layer %d" % layer)
	for kind in ["tour_bus","cargo","saucer","fighter","ghost_frigate","meteor","parasite","beam","vortex","drone"]:
		check(kinds.has(kind),"preserved readable variety "+kind)
	var budget = flight(4)
	for i in range(20): budget.space.battle.spawn(budget.space,budget)
	var threats = budget.space.objects.filter(func(e):return budget.space.battle.hostile(e))
	check(threats.size()<=1,"small horde never receives overlapping primary threats")
	# One notice is visible; stale messages cannot flood the screen later.
	var v = preload("res://scripts/space_visual.gd").new();v.notify("PERFECT!",2,1);v.notify("REENTRADA",4,1)
	check(v.current.text=="REENTRADA","reentry has priority over coin feedback")
	v.notify("LOW",1,1);v.advance(4);check(v.current.is_empty(),"expired notices are discarded")
	for width in [960.0,1280.0,1800.0]:
		var view = Rect2((1280-width)*.5,0,width,720);var d = v.layout(view)
		var keys = ["horde","coins","impulse","time","pause"]
		for i in range(keys.size()):
			check(view.encloses(d[keys[i]]),"HUD fits viewport %d %s" % [width,keys[i]])
			for j in range(i): check(not d[keys[i]].intersects(d[keys[j]]),"HUD panels never overlap %d" % width)
		check(d.notice.position.y>d.impulse.end.y,"one notice slot below HUD")
	var transition = flight();transition.space.phase = "ascent"
	transition.space.phase_age = transition.space.ASCENT_SECONDS*.2;check(v.ground_visible(transition.space),"ascent begins with ground")
	transition.space.phase_age = transition.space.ASCENT_SECONDS*.7;check(not v.ground_visible(transition.space),"ascent ends with opaque space")
	transition.space.phase = "return";transition.space.phase_age = transition.space.RETURN_SECONDS*.2;check(not v.ground_visible(transition.space),"return begins in space")
	transition.space.phase_age = transition.space.RETURN_SECONDS*.8;check(v.ground_visible(transition.space),"return reveals ground before landing")
	# Every lab replacement reuses registered new cockpit art, too.
	v.warm();check(v.ship_layout.size()==2 and v.textures.size()==5,"new ships and vortex are available")
	for kind in ["tour_bus","fighter"]:
		check(v.ship_layout[kind].facing=="right","captured hull faces travel direction "+kind)
		check(int(v.ship_layout[kind].window_pixels)>1000,"real cockpit opening "+kind)
	var folder = OS.get_environment("HORDA_VALIDATION_DIR")
	if not folder.is_empty():
		DirAccess.make_dir_recursive_absolute(folder);var file = FileAccess.open(folder+"/readability.json",FileAccess.WRITE)
		file.store_string(JSON.stringify({"version":"0.10.34","checks":checks,"failures":failures,"formations":observations},"  "));file.close()
	print("V134_READABILITY checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
