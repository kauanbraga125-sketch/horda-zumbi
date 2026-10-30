extends SceneTree
const DT = 1.0/60
var checks = 0
var failures: Array[String] = []
var kinds: Dictionary = {}
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label);push_error(label)
func road(seed_value: int = 13942):
	var r = HordeRun.new();r.start_developer("gap",6,0,seed_value)
	r.developer_kind = "";r.tutorial_enabled = false;r.power_owned.clear();r.entities.clear();r.events.clear()
	r.world_px = 4200;r.elapsed = 80;r.sewer.reserve_ground(r,50000);r.ensure_tunnels(50000)
	for t in r.tunnels:
		if r.world_px>=float(t.entry) and r.world_px<=float(t.entry)+float(t.length): r.world_px = float(t.entry)+float(t.length)+300
	return r
func offered(r) -> bool: return r.space.active or r.sewer.encounter.pending or r.sewer.active
func roll(r) -> void:
	for i in range(30):
		if offered(r): return
		r.elapsed = r.sewer.encounter.next_at+.01;r.sewer.encounter.tick(r)
func finish(r,kind: String) -> void:
	if kind=="space": r.space.finish(r)
	else:
		if not r.sewer.active: r.sewer.begin(r,true)
		r.sewer.finish(r)
func boat_run():
	var r = road();r.developer_kind = "validation";r.sewer.begin(r,true)
	for i in range(ceili(r.sewer.ENTRY_SECONDS/DT)+20): r.advance(DT,false)
	r.sewer.next_encounter = 1e6;r.sewer.objects.clear();r.sewer.life.next_scene = 1e6;r.sewer.life.people.clear();r.events.clear()
	return r
func run() -> void:
	check(MonsterCatalog.POWERS.all(func(p):return p.kind not in [4,9]),"both journeys are absent from the power shop")
	check(MonsterCatalog.POWER_UPGRADES.all(func(p):return p.id not in ["space_time","sewer_time"]),"journeys have no retired duration upgrades")
	check(MonsterCatalog.defaults().power_owned.all(func(p):return p not in [4,9]),"new saves do not own journey powers")
	var misses = 0
	for seed_value in range(24):
		var r = road(seed_value);var e = r.sewer.encounter;var deadline = float(e.next_at)
		check(deadline>=45 and deadline<=75,"first roll respects a normal-run interval")
		r.elapsed = deadline-.1;e.tick(r);check(not offered(r),"nothing starts before the deadline")
		r.elapsed = deadline+.01;e.tick(r)
		if not offered(r): misses += 1;check(e.next_at>r.elapsed,"a failed chance schedules another opportunity")
		roll(r);check(offered(r),"ordinary safe road eventually offers a journey")
		var kind = str(e.offered_kind);kinds[kind] = int(kinds.get(kind,0))+1
		check(kind in ["space","sewer"] and r.bonuses==0,"journeys do not increment power pickup statistics")
		check(not e.offer(r,true,"sewer" if kind=="space" else "space"),"active journey cannot overlap the other type")
		if kind=="space":
			check(r.space.phase=="ascent" and r.space.left==30 and 4 not in r.power_owned,"natural abduction uses the ship ascent without buying or collecting a power")
			check(7 not in r.power_owned and 8 not in r.power_owned,"natural events do not grant unpurchased combat powers")
		var ids = r.members.map(func(m):return int(m.id));finish(r,kind)
		check(r.members.map(func(m):return int(m.id))==ids and r.souls==0,"return preserves actual members and earned souls")
		check(e.next_at>=r.elapsed+105 and e.completed_count==1,"shared return cooldown starts only once")
		var count = e.offered;r.elapsed += 10;e.tick(r);check(e.offered==count,"a completed trip cannot immediately roll another")
		roll(r);check(e.offered_kind!=kind,"the next successful natural event avoids repeating the last scenery")
	check(misses>0 and kinds.has("space") and kinds.has("sewer"),"seeds cover failed rolls and both event families")
	var r = road();r.perk_left = 3;r.perk_kind = 3
	check(not r.sewer.encounter.offer(r,false,"space") and not r.sewer.encounter.offer(r,false,"sewer"),"active transformations block both journeys")
	r = road();r.add_entity("crystal",r.ANCHOR+500,r.FLOOR-65)
	check(not r.sewer.encounter.offer(r,false,"space"),"visible collectible powers are not displaced by an event")
	r = road();var m = r.members[0];var retired = r.add_entity("space_brain",m.x,m.y-50)
	for i in range(5):r.advance(DT,false)
	check(not r.space.active and r.bonuses==0 and retired.taken,"old space pickup is inert")
	ProjectSettings.set_setting("testing/space_early_pickup_enabled",true);r.entities.clear();r.elapsed = 15;r.space.offer_test_pickup(r)
	check(not r.entities.any(func(e):return e.kind=="space_brain"),"legacy test flag cannot inject a purchasable journey pickup")
	r = road();r.developer_kind = "validation";r.sewer.begin(r,true)
	check(r.members.all(func(member):return member.sewer_pose=="run"),"first entry frame retains the running pose on land")
	var previous: Dictionary = {};var poses: Dictionary = {};var jumps = 0
	for i in range(ceili(r.sewer.ENTRY_SECONDS/DT)+20):
		r.advance(DT,false)
		for member in r.members:
			var pose = str(member.sewer_pose);poses[pose] = true
			if pose=="run": check(member.x<=r.sewer.shore_edge()+.001 and absf(member.y-(r.FLOOR-r.sewer.entry_drop()))<.01,"running feet remain on the solid quay")
			if pose=="board" and member.y<r.FLOOR-25:jumps += 1
			if previous.has(member.id):check(Vector2(member.x,member.y).distance_to(previous[member.id])<55,"boarding follows a continuous per-member trajectory")
			previous[member.id] = Vector2(member.x,member.y)
	check(jumps>0 and poses.has("board") and poses.has("ride") and r.sewer.phase=="ride","jump from quay resolves into real seated riders")
	r.sewer.next_encounter = 1e6;r.sewer.objects.clear();r.sewer.left = .001;r.advance(DT,false)
	for i in range(ceili(r.sewer.EXIT_SECONDS/DT)+5):
		r.advance(DT,false)
		for member in r.members:
			check(Vector2(member.x,member.y).distance_to(previous[member.id])<55,"launch and landing stay continuous through the scenery return")
			previous[member.id] = Vector2(member.x,member.y)
	for variant in range(3):
		r = boat_run();var s = r.sewer;var count = 2 if variant==2 else 1
		var e = s.add_object("fugitive",s.boats[0].x,s.WATER-24,{"variant":variant})
		for i in range(90):r.advance(DT,false)
		check(s.captured==count and r.souls==count and r.active_count()==6+count,"each distinct jet-ski occupant becomes exactly one soul and member")
		s.complete_rescue(r,e)
		for i in range(30):r.advance(DT,false)
		check(s.captured==count and r.souls==count,"captured craft cannot duplicate its occupants")
		var ids: Array = []
		for b in s.boats: ids.append_array(b.ids);check(b.ids.size()<=2,"recruits continue using at most two seats")
		check(ids.size()==r.active_count() and ids.all(func(id):return ids.count(id)==1),"recruitment keeps stable unique passenger identities")
	for type in ["rescue","fugitive"]:
		r = boat_run();var s = r.sewer;var tail = s.boats[-1]
		s.add_object(type,tail.x,s.WATER-24,{"variant":2})
		for i in range(100): r.advance(DT,false)
		var amount = 2 if type=="fugitive" else 1
		check(s.captured==amount and r.souls==amount,"capture at the trailing craft finishes even beyond the visible edge "+type)
	var report = {"version":"0.10.41","checks":checks,"failures":failures,"event_distribution":kinds,"failed_rolls":misses,"physical_device_tested":false}
	var folder = OS.get_environment("HORDA_VALIDATION_DIR")
	if not folder.is_empty():
		DirAccess.make_dir_recursive_absolute(folder);var f = FileAccess.open(folder+"/journeys.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
	print("V141_JOURNEYS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
