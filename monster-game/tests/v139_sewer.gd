extends SceneTree
const DT = 1.0/60
var checks = 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label);push_error(label)
func fresh(count: int = 6):
	var r = HordeRun.new();r.start_developer("sewer",count,0,13842);r.entities.clear();r.events.clear();r.power_owned.clear()
	check(r.sewer.begin(r,true),"event can carry the real horde without owning a power")
	for i in range(290): r.advance(DT,false)
	check(r.sewer.phase=="ride","boarding and connected entrance finish")
	r.sewer.objects.clear();r.sewer.next_encounter = 1e6;r.sewer.life.next_scene = 1e6;r.sewer.life.people.clear();r.events.clear();r.hit_grace = 0
	return r
func run() -> void:
	check(not MonsterCatalog.POWERS.any(func(p):return p.kind==9),"sewer is absent from the power shop")
	check(not MonsterCatalog.POWER_UPGRADES.any(func(p):return p.id=="sewer_time"),"event duration is not a bought power upgrade")
	var schedules: Array = []
	for seed_value in range(8):
		var e = preload("res://scripts/sewer_event.gd").new();e.reset(seed_value)
		check(e.next_at>=45 and e.next_at<=75,"first event has a normal-run cooldown")
		schedules.append(e.next_at)
	check(schedules.any(func(at):return absf(float(at)-float(schedules[0]))>2),"run seeds vary the event timing")
	var ordinary = HordeRun.new();ordinary.start_developer("bomb",6,0,1387);ordinary.developer_kind = "";ordinary.tutorial_enabled = false;ordinary.power_owned.clear();ordinary.entities.clear()
	ordinary.world_px = 4200;ordinary.sewer.reserve_ground(ordinary,30000);ordinary.ensure_tunnels(40000)
	for t in ordinary.tunnels:
		if ordinary.world_px>=float(t.entry) and ordinary.world_px<=float(t.entry)+float(t.length): ordinary.world_px = float(t.entry)+float(t.length)+300
	ordinary.elapsed = 80;ordinary.sewer.encounter.next_at = 81;ordinary.sewer.encounter.tick(ordinary)
	check(not ordinary.sewer.encounter.pending,"event is not offered before its random deadline")
	ordinary.elapsed = 82;ordinary.sewer.encounter.offer(ordinary,true,"sewer")
	check(ordinary.sewer.encounter.pending and not ordinary.sewer.active,"dock appears ahead while the ordinary run continues")
	check(not ordinary.power_eligible() and ordinary.bonus_director.active(ordinary),"dock approach reserves the event from overlapping powers")
	var ids = ordinary.members.map(func(m):return int(m.id))
	for i in range(600):
		if ordinary.sewer.active: break
		ordinary.advance(DT,false)
	check(ordinary.sewer.active and ordinary.sewer.phase=="entry","reaching visible dock starts the event without a pickup")
	check(ordinary.bonuses==0 and ordinary.members.map(func(m):return int(m.id))==ids,"boarding does not invent a bonus or change the horde")
	var poses: Array = []
	for i in range(290):
		ordinary.advance(DT,false)
		for m in ordinary.members:
			var pose = str(m.get("sewer_pose",""))
			if pose not in poses: poses.append(pose)
	check("run" in poses and "board" in poses and "duck" in poses and "ride" in poses,"entrance has run boarding seated and braced animation states")
	for count in [1,2,4,6,10,20,64]:
		var r = fresh(count);var s = r.sewer;ids = r.members.map(func(m):return int(m.id));var seats: Array = []
		for b in s.boats: seats.append_array(b.ids)
		check(s.boats.size()==ceili(count/2.0) and s.boats.all(func(b):return b.ids.size()<=2),"exactly two seats per ski "+str(count))
		check(seats.size()==count and seats.all(func(id):return seats.count(id)==1 and id in ids),"one stable seat for each actual member "+str(count))
		var world = r.world_px;var souls = r.souls;s.left = .001;r.advance(DT,false)
		for i in range(190): r.advance(DT,false)
		check(not s.active and s.completed==1 and r.world_px>world,"same run advances after approved exit "+str(count))
		check(r.members.map(func(m):return int(m.id))==ids and r.souls==souls,"exit retains recruited identities and souls "+str(count))
		check(r.members.all(func(m):return not m.falling and absf(float(m.y)-r.FLOOR)<2),"safe actual ground landing "+str(count))
		check(s.encounter.next_at>=r.elapsed+100,"events cannot repeat immediately after a trip")
	var heights: Array = []
	for held in [false,true]:
		var sample = fresh(2);var bottom = float(sample.sewer.boats[0].y);var top = bottom;sample.jump()
		for i in range(100):
			sample.advance(DT,held and i<12);top = minf(top,float(sample.sewer.boats[0].y))
		heights.append(bottom-top)
	check(float(heights[1])>float(heights[0])+12,"holding truly changes the leader's jump as well as the followers")
	for kind in ["barrel","rubble","rotor"]:
		for count in [2,6,8,10]:
			for lead in [.40,.45,.50]:
				var r = fresh(count);var s = r.sewer
				s.add_object(kind,s.boats[0].x+s.scroll_speed(r)*lead,s.WATER-35);r.jump()
				for i in range(180): r.advance(DT,i<11)
				check(r.losses==0,"held jump clears whole small convoy %s %d %.2f" % [kind,count,lead])
	for kind in ["pipe","gate"]:
		for count in [2,6,10]:
			var r = fresh(count);var s = r.sewer;s.spawn(r,kind)
			var e = s.objects.filter(func(item):return item.kind==kind)[0];e.x = s.boats[0].x+s.scroll_speed(r)*.50;e.age = 2
			s.request_duck(r)
			for i in range(140): r.advance(DT,false)
			check(r.losses==0 and not e.damaged,"duck command travels to all followers before the same gate %s %d" % [kind,count])
		var r = fresh(6);var s = r.sewer;s.spawn(r,kind)
		var e = s.objects.filter(func(item):return item.kind==kind)[0];e.x = s.boats[0].x+s.scroll_speed(r)*.5;e.age = 2
		for i in range(140): r.advance(DT,false)
		check(e.damaged and r.losses>0 and r.losses<=2,"ignoring low hazard causes bounded real rider loss "+kind)
	var r = fresh(6);var s = r.sewer;var old_targets: Dictionary = {}
	for i in range(s.boats.size()): old_targets[s.boats[i].id] = s.boat_x(r,i)
	r.add_member(0,true);s.assign_boats(r)
	check(s.boats.all(func(b):return not old_targets.has(b.id) or absf(s.boat_x(r,s.boats.find(b))-float(old_targets[b.id]))<.01),"first new boat adds a stable row without moving existing seated pairs")
	r = fresh(6);s = r.sewer;s.pressure = .91;var before = s.wave_edge();s.pressure = .25
	check(s.wave_edge()<before,"mistakes physically bring the flood toward the tail")
	s.pressure = .99;r.advance(DT,false)
	check(r.losses==1 and r.active_count()==5,"flood takes a real tail passenger")
	for i in range(60): r.advance(DT,false)
	check(r.losses==1,"flood protection interval prevents draining a horde at once")
	s.pressure = .7;s.reward_line();check(s.pressure<.61 and s.rush_left>1,"earned coin lines push flood away and accelerate briefly")
	r = fresh(6);s = r.sewer;s.life.people.append({"x":r.view_right-350,"age":0.0,"variant":1,"fall":false,"drops":true,"taken":false})
	for i in range(60): r.advance(DT,false)
	check(s.objects.any(func(e):return e.kind=="rescue" and e.get("from_catwalk",false)),"falling background worker becomes the same rescue in the water")
	for i in range(170): r.advance(DT,false)
	check(s.captured==1 and r.souls==1 and r.active_count()==7,"background rescue grants exactly one real member and soul")
	r = fresh(6);s = r.sewer;var e = s.add_object("collapse",s.boats[0].x+s.scroll_speed(r)*1.85,s.WATER-370,{"warning":1.0,"landed":false})
	for i in range(60): r.advance(DT,false)
	check(not e.landed and r.losses==0,"falling ceiling gives a real warning before impact")
	for i in range(75): r.advance(DT,false)
	check(e.landed and r.losses>0,"ceiling debris lands as an actual jump hazard")
	r = fresh(6);s = r.sewer;s.next_encounter = 0
	for i in range(650):
		# Isolate authored cadence from mistakes; the full native replay tests input.
		r.hit_grace = 1;r.advance(DT,false)
	check(s.history.size()>=4 and s.history.any(func(h):return h.kind=="pipe") and s.history.any(func(h):return h.kind in ["rescue","fugitive"]),"encounter rhythm makes varied decisions inside the first eleven seconds")
	var report = {"version":"0.10.39","checks":checks,"failures":failures,"physical_device_tested":false}
	print("V139_SEWER ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
