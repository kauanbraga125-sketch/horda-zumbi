extends SceneTree
const DT = 1.0/60
var checks = 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label);push_error(label)
func fresh(count: int = 10):
	var r = HordeRun.new();r.start_developer("sewer",count,0,13742);r.entities.clear();r.events.clear()
	check(r.sewer.begin(r,true),"chapter begins "+str(count))
	while r.sewer.phase=="entry": r.advance(DT,false)
	r.sewer.objects.clear();r.sewer.next_encounter = 1e6;r.sewer.life.next_scene = 1e6;r.sewer.life.people.clear();r.events.clear();r.hit_grace = 0
	return r
func run() -> void:
	for count in [1,2,4,6,9,10,16,20,64]:
		var r = fresh(count);var s = r.sewer;var original = r.members.map(func(m):return int(m.id))
		var seated: Array = []
		for b in s.boats: seated.append_array(b.ids)
		check(s.boats.size()==ceili(count/2.0),"minimum fleet for two seats "+str(count))
		check(s.boats.all(func(b):return b.ids.size()>0 and b.ids.size()<=2),"no third rider "+str(count))
		check(seated.size()==count and seated.all(func(id):return seated.count(id)==1 and id in original),"each real member occupies one stable seat "+str(count))
		check(s.scroll_speed(r)>=500 and s.scroll_speed(r)<=665,"faster readable scroll speed "+str(count))
		var old_x = s.boats.map(func(b):return float(b.x))
		for i in range(5): r.advance(DT,false)
		check(s.boats.all(func(b):return is_finite(b.x) and is_finite(b.y) and is_finite(b.angle)),"finite water poses "+str(count))
		var speed = s.scroll_speed(r);s.add_object("barrel",s.boats[0].x+speed*.43,s.WATER-35)
		r.jump()
		for i in range(150): r.advance(DT,i<10)
		if count<=10: check(r.losses==0,"one timed tap carries small convoy over the barrel "+str(count))
		if r.losses==0: check(r.members.map(func(m):return int(m.id))==original,"jump preserves member identities "+str(count))
		var before_world = r.world_px;var before_souls = r.souls;var ids = r.members.map(func(m):return int(m.id))
		s.left = .001;r.advance(DT,false)
		check(s.phase=="exit" and s.objects.is_empty(),"visible exit clears only chapter hazards "+str(count))
		for i in range(190): r.advance(DT,false)
		check(not s.active and s.completed==1 and r.world_px>before_world,"same run resumes after exit "+str(count))
		check(r.souls==before_souls and r.members.map(func(m):return int(m.id))==ids,"exit retains souls and identities "+str(count))
		check(r.members.all(func(m):return not m.falling and absf(m.y-r.FLOOR)<2),"safe landing on actual game floor "+str(count))
	for kind in ["pipe","gate"]:
		var r = fresh(4);var s = r.sewer;s.spawn(r,kind)
		var obstacle = s.objects.filter(func(e):return e.kind==kind)[0]
		check(obstacle.ceiling_attached and obstacle.y<s.WATER-100,"high obstacle has a ceiling attachment "+kind)
		obstacle.x = s.boats[0].x+s.scroll_speed(r)*.43;obstacle.previous_x = obstacle.x;obstacle.age = 2
		for i in range(100): r.advance(DT,false)
		check(r.losses==0 and not obstacle.damaged,"remaining on water clears suspended hazard "+kind)
		r = fresh(4);s = r.sewer;s.spawn(r,kind)
		obstacle = s.objects.filter(func(e):return e.kind==kind)[0];obstacle.x = s.boats[0].x+s.scroll_speed(r)*.43;obstacle.age = 2
		r.jump()
		for i in range(100): r.advance(DT,i<10)
		check(obstacle.damaged and r.losses>0 and r.losses<=2,"jump visibly risks suspended hazard "+kind)
	for count in [2,6,10]:
		for lead in [.42,.47,.52]:
			var convoy = fresh(count);var chapter = convoy.sewer
			chapter.add_object("rubble",chapter.boats[0].x+chapter.scroll_speed(convoy)*lead,chapter.WATER-35)
			convoy.jump()
			for i in range(180): convoy.advance(DT,i<10)
			check(convoy.losses==0,"full hull clears wide wreck with a correctly timed held jump %s %.2f" % [count,lead])
	var r = fresh(10);var s = r.sewer;var tail = s.tail_x();s.pressure = .2;var far = s.wave_edge();s.pressure = .85
	check(s.wave_edge()>far and s.wave_edge()<tail+40,"flood approaches the actual tail as danger rises")
	s.pressure = .99;s.wave_cooldown = 0;r.advance(DT,false)
	check(r.losses==1 and r.active_count()==9 and s.braking>.9,"flood removes a real rider and slows the convoy briefly")
	for i in range(30): r.advance(DT,false)
	check(r.losses==1,"flood cannot drain entire horde in one contact")
	r = fresh(10);s = r.sewer
	s.life.people.append({"x":r.view_right-320,"age":0.0,"variant":1,"fall":false,"drops":true,"taken":false})
	for i in range(60): r.advance(DT,false)
	check(s.objects.any(func(e):return e.kind=="rescue" and e.get("from_catwalk",false) and e.variant==1),"background fall creates an animated survivor in the playable water")
	for i in range(150): r.advance(DT,false)
	check(r.souls==1 and r.active_count()==11 and s.captured==1,"catwalk survivor grants exactly one soul and actual recruit")
	check(s.boats.all(func(b):return b.ids.size()<=2),"recruit never creates a third seat")
	var ids = r.members.map(func(m):return int(m.id));s.left = .001;r.advance(DT,false)
	for i in range(190): r.advance(DT,false)
	check(r.souls==1 and r.members.map(func(m):return int(m.id))==ids,"rescued passenger persists into the normal run")
	r = fresh(4);s = r.sewer
	var barrel = s.add_object("barrel",s.boats[0].x+250,s.WATER-35)
	var contact_distance = 0.0
	for i in range(60):
		r.advance(DT,false)
		if r.losses>0: contact_distance = float(barrel.x)-float(s.boats[0].x);break
	check(r.losses==1 and contact_distance>90,"bow hits barrel before the two centres overlap")
	r = fresh(4);s = r.sewer
	var gate = s.add_object("gate",s.boats[0].x+140,s.WATER-151,{"ceiling_attached":true,"age":2.0})
	r.advance(DT,false)
	check(not gate.damaged,"safe initial overlap below a suspended gate")
	r.jump()
	for i in range(25): r.advance(DT,i<10)
	check(gate.damaged and r.losses>0,"jumping while under the gate cannot phase through its visible bars")
	var report = {"version":"0.10.37","checks":checks,"failures":failures,"physical_device_tested":false}
	print("V137_SEWER ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
