extends SceneTree
const Catalog = preload("res://scripts/bird_catalog.gd")
var checks = 0
var failures: Array[String] = []
const DT = 1.0/60
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label);push_error(label)
func fresh() -> Dictionary:
	var data = MonsterCatalog.defaults();data.eyes = 100000;data.wallet = 100000;return data
func receipt_done(data: Dictionary) -> void: data.bird_pending = {}
func boat_run(count: int = 4):
	var r = HordeRun.new();r.start_developer("sewer",count,0,13642);r.entities.clear();r.events.clear()
	check(r.sewer.begin(r,true),"sewer begins with real members")
	while r.sewer.phase=="entry": r.advance(DT,false)
	r.sewer.objects.clear();r.sewer.next_encounter = 1e6;r.events.clear();return r
class FailedSave:
	extends RefCounted
	var data: Dictionary
	var reward_rng = RandomNumberGenerator.new()
	var messages: Array = []
	func save_game() -> bool: return false
	func show_toast(message: String,_seconds: float = 2) -> void: messages.append(message)
func run() -> void:
	var rng = RandomNumberGenerator.new();rng.seed = 1361
	var data = fresh();var initial = int(data.eyes)
	var first = Catalog.roll(data,rng)
	check(not first.is_empty() and data.eyes==initial and data.bird_draws==1,"first invocation is free and grants one item")
	var once = data.duplicate(true)
	check(Catalog.roll(data,rng).is_empty() and data==once,"pending receipt rejects double tap without charge")
	receipt_done(data);Catalog.roll(data,rng)
	check(data.eyes==initial-30 and data.bird_draws==2,"subsequent draw costs exactly30eyes")
	check(Catalog.migrate(data).bird_pending.id==data.bird_pending.id,"unfinished reveal survives save migration")
	data = fresh();data.bird_draws = 1;data.eyes = 29;once = data.duplicate(true)
	check(Catalog.roll(data,rng).is_empty() and data==once,"insufficient currency has no side effects")
	data = fresh();data.bird_rare_pity = 9
	check(Catalog.tier(str(Catalog.roll(data,rng).id))>=2 and data.bird_rare_pity==0,"tenth unlucky draw guaranteesHyperorhigher")
	data = fresh();data.bird_legend_pity = 49
	check(Catalog.roll(data,rng).id=="barao" and data.bird_legend_pity==0 and data.bird_rare_pity==0,"fiftieth unlucky draw guaranteeslegendary")
	data = fresh()
	for i in range(9): Catalog.add_copy(data,"pipoco","draw");receipt_done(data)
	check(Catalog.level(data,"pipoco")==3 and data.bird_essence.pipoco==6,"three power levels then six surplus essences")
	var wallet = int(data.wallet);var pity = int(data.bird_rare_pity)
	var fusion = Catalog.fuse(data,"pipoco")
	check(fusion.id=="fiapo" and data.wallet==wallet-500 and data.bird_essence.pipoco==0,"same-species reserves support first catalogue fusion")
	check(Catalog.level(data,"pipoco")==3 and data.bird_rare_pity==pity,"fusion preserves source power and draw guarantees")
	once = data.duplicate(true)
	check(Catalog.fuse(data,"pipoco").is_empty() and data==once,"repeated fusion tap cannot spend twice")
	receipt_done(data);data.bird_essence.barao = 100
	check(Catalog.fuse(data,"barao").is_empty(),"legendary has no nonexistent superior rarity")
	var broken = Catalog.migrate({"bird_copies":[],"bird_essence":false,"bird_equipped":"missing","bird_rare_pity":999,"bird_legend_pity":999,"bird_pending":{"id":"unknown"}})
	check(broken.bird_copies.is_empty() and broken.bird_equipped.is_empty() and broken.bird_rare_pity==9 and broken.bird_legend_pity==49 and broken.bird_pending.is_empty(),"malformed collection is normalized")
	var fake = FailedSave.new();fake.data = fresh();fake.reward_rng.seed = 54
	once = fake.data.duplicate(true);preload("res://scripts/birds_ui.gd").new().transaction(fake,false)
	check(fake.data==once and fake.messages.size()==1,"failed persistence rolls back charge award and pity together")
	# Raw base rates, with guarantees deliberately reset, are statistically sane.
	var bins = [0,0,0,0,0];data = fresh()
	for i in range(10000):
		data.eyes = 100000;data.bird_rare_pity = 0;data.bird_legend_pity = 0;receipt_done(data)
		bins[Catalog.tier(str(Catalog.roll(data,rng).id))] += 1
	for i in range(5): check(absf(bins[i]/10000.0-Catalog.WEIGHTS[i]/100)<.018,"base rate within deterministic statistical tolerance "+str(i))
	for count in [1,4,20,64]:
		var r = boat_run(count);var s = r.sewer;var ids = r.members.map(func(m):return int(m.id))
		var seated: Array = []
		for b in s.boats: seated.append_array(b.ids)
		check(seated.size()==count and seated.size()==ids.size() and seated.all(func(id):return id in ids),"every member has a stable seat "+str(count))
		check(not r.space.begin(r,true),"space cannot overlap active sewer "+str(count))
		r.jump();var pending: Array = s.boats.map(func(b):return float(b.jump_at)-s.age)
		if count<=4: check(pending.max()<.05,"small convoy does not inherit large-horde delay")
		var lowest = s.boats[0].y
		for i in range(35): r.advance(DT,i<12);lowest = minf(lowest,s.boats[0].y)
		check(lowest<s.WATER-120,"jump clears visible low obstacles "+str(count))
		for i in range(60): r.advance(DT,false)
		check(r.active_count()==count,"jump without hazards never loses passengers "+str(count))
		var world = r.world_px;s.left = .001;r.advance(DT,false)
		check(s.phase=="exit","timer enters visible escape sequence "+str(count))
		for i in range(190): r.advance(DT,false)
		check(not s.active and r.world_px>world and r.members.map(func(m):return int(m.id))==ids,"exit preserves identities and advancing run "+str(count))
		check(r.members.all(func(m):return not m.falling and is_finite(float(m.x)) and is_finite(float(m.y))),"safe finite landing "+str(count))
	var r = boat_run(4);var s = r.sewer
	var civilian = s.add_object("rescue",s.boats[0].x,s.WATER-40)
	for i in range(40): r.advance(DT,false)
	check(civilian.taken and r.souls==1 and r.recruits==1 and r.active_count()==5,"floating civilian becomes exactly one actual recruited soul")
	r.hit_grace = 0
	var e = s.add_object("barrel",s.boats[0].x,s.WATER-35)
	for i in range(60): r.advance(DT,false)
	check(r.losses==1 and r.active_count()==4 and e.taken,"one barrel causes bounded visible loss")
	check(r.drain_events().any(func(event):return event.type=="hit" and event.get("in_sewer",false)),"sewer loss uses water casualty presentation")
	data = fresh();data.bird_copies.agourinho = 3;data.bird_equipped = "agourinho";r.bird.configure(data)
	var before = r.active_count();r.hit_grace = 0;r.remove_member(0,"fall")
	check(r.active_count()==before and r.bird.rescued and r.hit_grace>=2,"owl saves only one real member and grants level protection")
	r.remove_member(0,"fall")
	check(r.active_count()==before-1,"owl does not grant unlimited resurrection")
	data.bird_copies.pipoco = 2;data.bird_equipped = "pipoco";r.bird.configure(data)
	var coins = r.coins;r.bird.on_perfect(r)
	check(r.coins==coins+2,"Pipoco rewards an earnedPerfect according to level")
	var rr = HordeRun.new();rr.start_developer("space",4,0,13655);rr.entities.clear();rr.space.begin(rr,true)
	for i in range(300): rr.advance(DT,false)
	check(rr.space.phase=="flight","longer connected abduction reaches playable flight")
	var prey = rr.space.objects.filter(func(item):return item.kind=="astronaut")
	check(not prey.is_empty() and rr.space.objects.any(func(item):return item.kind=="parasite" and item.has("prey")),"first rescue contains an actual predator/prey scene")
	var ship = rr.space.battle.spawn_ship(rr.space,rr,"cargo",rr.view_right+500,330);ship.distress = true
	for i in range(150): rr.advance(DT,false)
	check(ship.get("evacuated",false) and ship.released_crew==1,"damaged cargo ejects one reserved passenger capsule")
	var report = {"checks":checks,"failures":failures,"base_rate_sample":bins,"physical_device_tested":false}
	print("V136_SYSTEMS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
