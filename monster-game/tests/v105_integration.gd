extends SceneTree
var checks=0
var failures=0
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, note: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error("V105_FAIL "+note)
	else: print("V105_OK ",note)
func fresh() -> HordeRun:
	var r=HordeRun.new();r.start_developer("animation_check",4,0,105);return r
func run() -> void:
	var g=load("res://main.tscn").instantiate();root.add_child(g);g.test_mode=true;g.set_process(false);g.set_physics_process(false)
	var catalog=HordeMissionCatalog.all();var difficulties=[0,0,0];var stats={};var ids={}
	for m in catalog:
		difficulties[int(m.difficulty)-1]+=1;stats[m.stat]=true;ids[m.id]=true
		if not ResourceLoader.exists(HordeExperimentArt.ROOT+"mission_"+str(m.art)+".png"): failures+=1;push_error("Missing illustration "+str(m.art))
	expect(catalog.size()==90 and ids.size()==90 and difficulties==[30,30,30],"90 unique missions with 30 easy, 30 medium and 30 hard")
	expect(stats.size()>=25,"specific mission conditions beyond numerical variations")
	var manifest=JSON.parse_string(FileAccess.get_file_as_string(HordeExperimentArt.ROOT+"manifest.json"))
	expect(manifest.mission_art.size()==24 and manifest.specimens.size()==16,"24 illustrations and 16 isolated specimen assets")
	var variants={};var used={}
	for level in range(1,501):
		var v=HordeExperimentArt.variant(level);var key=str(v.palette)+":"+str(v.objects)
		variants[key]=true
		for id in v.objects: used[id]=true
	expect(variants.size()==500 and used.size()==15,"500 deterministic distinct color and specimen combinations")
	expect(HordeExperimentArt.variant(16)==HordeExperimentArt.variant(16),"mixtures remain stable after reopening")
	var data=MonsterCatalog.defaults();var active=HordeMissionCatalog.active(data)
	expect(active[0].stat=="souls" and active[1].stat=="coins" and active[2].stat=="distance","accessible opening challenges")
	expect(not HordeMissionCatalog.eligible(HordeMissionCatalog.template("plane_1"),data),"locked airport cannot issue aircraft mission")
	data.player_level=20
	expect(not HordeMissionCatalog.eligible(HordeMissionCatalog.template("mask_captures_1"),data),"locked mask cannot issue mask objective")
	data.power_owned.append(2);data.owned.append(1);data.areas.append(3)
	expect(HordeMissionCatalog.eligible(HordeMissionCatalog.template("plane_1"),data),"aircraft mission becomes eligible after airport unlock")
	data=MonsterCatalog.defaults()
	var complete=HordeMissionCatalog.advance(data,{"souls":8,"coins":15,"distance":200},{})
	expect(complete.size()==1 and data.missions_completed==1,"one completed mission is credited once")
	expect(HordeMissionCatalog.advance(data,{"souls":8,"coins":15,"distance":200},{"souls":8,"coins":15,"distance":200}).is_empty(),"rechecking identical telemetry cannot repeat completion")
	expect(data.mission_progress[active[1].id]==15,"partial accumulated progress persists")
	expect(HordeMissionCatalog.replace_completed(data,0) and not HordeMissionCatalog.replace_completed(data,1),"each completed slot rotates independently")
	expect(data.mission_progress[active[1].id]==15,"rotating a slot keeps its neighbors intact")
	var raw=data.duplicate(true);var restored=g.validate_save(raw)
	expect(restored.mission_slots==raw.mission_slots and restored.mission_progress==raw.mission_progress,"new mission slots and progress survive validated save")
	var legacy=MonsterCatalog.defaults()
	for key in ["mission_schema","mission_slots","mission_serial","mission_history"]: legacy.erase(key)
	legacy.mission_tier=1;legacy.mission_progress={"cars":2,"jumps":4,"bonuses":1};legacy.claimed=["1:cars"]
	restored=g.validate_save(legacy)
	expect(restored.mission_slots[0].key=="1:cars" and restored.mission_progress.jumps==4 and "1:cars" in restored.claimed,"0.10.4 missions migrate without losing active progress or claims")
	HordeMissionCatalog.replace_completed(restored,0);restored.mission_tier=8
	var again=g.validate_save(restored)
	expect(again.mission_slots[1].key=="1:jumps" and again.mission_progress.jumps==4,"unfinished legacy slot survives later tier changes")
	data=MonsterCatalog.defaults();data.mission_slots[0]=HordeMissionCatalog.make(HordeMissionCatalog.template("coins_run_1"),10)
	var first=HordeMissionCatalog.advance(data,{"coins":60},{})
	HordeMissionCatalog.advance(data,{"coins":50},{})
	expect(data.mission_progress[data.mission_slots[0].id]==60,"single-run objective keeps the best run instead of summing runs")
	var best_key=data.mission_slots[0].key
	HordeMissionCatalog.advance(data,{"coins":200},{"coins":50},{best_key:{"coins":50}})
	expect(best_key not in data.claimed,"new peak objective waits for a fresh run when issued during play")
	data=MonsterCatalog.defaults();data.player_level=3;data.level_souls=78;data.wallet=533
	var rng=RandomNumberGenerator.new();rng.seed=105
	HordeProgress.queue_mission(data,{"key":"test","title":"TEST","ritual":35});var report=HordeProgress.ritual(data,rng)
	expect(data.player_level==4 and data.level_souls>=29 and data.wallet==673,"level-up commits reward and retains overflowing essence")
	var snapshot=data.duplicate(true);HordeProgress.ritual(data,rng)
	expect(data==snapshot,"reopening settled ritual cannot recredit currency")
	var presentation=HordeExperimentPresentation.new();presentation.enqueue(report)
	var phases={};var wallets=[];var full=false
	for i in range(300):
		presentation.advance(1.0/60.0);phases[presentation.stage()]=true;wallets.append(presentation.wallet(data.wallet));full=full or presentation.amount()>=0.999
	expect(full and phases.has("react") and phases.has("award") and phases.has("reset"),"universal animation fills, reacts, awards coins and starts next mixture")
	expect(presentation.shown_level==4 and is_equal_approx(presentation.shown_xp,data.level_souls),"animation ends at exact saved level and overflow")
	expect(wallets[0]==533 and wallets[-1]==673 and presentation.pending_coins==0,"visible wallet counts up to already committed reward")
	var monotonic=true
	for i in range(1,wallets.size()): monotonic=monotonic and wallets[i]>=wallets[i-1]
	expect(monotonic,"flying coin effect never decreases wallet")
	presentation.reset(data.player_level,data.level_souls)
	expect(presentation.wallet(data.wallet)==673 and data==snapshot,"interrupting presentation leaves saved rewards intact")
	data=MonsterCatalog.defaults();data.level_souls=60
	HordeProgress.queue_mission(data,{"key":"bulk","title":"BULK","ritual":350});report=HordeProgress.ritual(data,rng)
	presentation.reset(1,60);presentation.enqueue(report)
	HordeProgress.queue_mission(data,{"key":"bulk2","title":"BULK2","ritual":50});var report2=HordeProgress.ritual(data,rng);presentation.enqueue(report2)
	for i in range(1800): presentation.advance(1.0/60)
	expect(presentation.shown_level==data.player_level and is_equal_approx(presentation.shown_xp,data.level_souls) and presentation.pending_coins==0,"back-to-back multi-level rewards preserve queue order and overflow")
	data=MonsterCatalog.defaults();data.wallet=9999998;data.level_souls=65
	HordeProgress.queue_mission(data,{"key":"cap","title":"CAP","ritual":3});report=HordeProgress.ritual(data,rng)
	expect(report.coins==1 and report.steps[0].coins==1 and data.wallet==9999999,"wallet cap reports only actual credited coins")
	data.player_level=500;data.level_souls=899;var before=data.wallet
	HordeProgress.queue_mission(data,{"key":"cap500","title":"CAP","ritual":500});report=HordeProgress.ritual(data,rng)
	expect(data.player_level==500 and data.wallet==before and report.steps.is_empty(),"maximum level cannot create false level rewards")
	var r=fresh();r.world_px=9000;r.register_loss();r.world_px=12000
	expect(r.stats().clean_distance==300,"no-loss distance retains best completed streak")
	r.mission_stats.clean_coin_current=14;r.mission_stats.clean_coins=14;r.register_loss()
	expect(r.mission_stats.clean_coin_current==0 and r.stats().clean_coins==14,"loss resets live coin streak and preserves recorded peak")
	r=fresh();var e=r.add_entity("police",400);e.rescued=false;r.complete_capture(e)
	expect(r.stats().army==0,"police capture cannot satisfy soldier mission")
	e=r.add_entity("soldier",400);e.rescued=false;r.complete_capture(e)
	expect(r.stats().army==1,"actual soldier capture advances dedicated mission")
	e=r.add_entity("civilian",400);e.capture_kind=2;r.complete_capture(e)
	expect(r.stats().mask_captures==1 and r.stats().civilians==1,"mask civilian capture records the real capturer")
	var car=r.add_entity("car",500);r.perk_kind=2;r.perk_left=5;r.flip_vehicle(car)
	expect(r.stats().vehicle_car==1 and r.stats().mask_vehicles==1 and r.stats().mask_captures==1,"vehicle and passenger actions do not leak into civilian power missions")
	r.flip_vehicle(car);expect(r.stats().vehicle_car==1,"vehicle telemetry follows idempotent gameplay credit")
	r=fresh();r.world_px=0;r.tunnels.assign([{"number":1,"entry":1,"length":10,"from":0,"to":1,"entered":false,"completed":false,"rewards_spawned":true}]);r.developer_kind="";r.world_px=2;r.update_tunnels();r.world_px=12;r.update_tunnels()
	expect(r.stats().clean_tunnel_streak==1,"clean tunnel checks losses at actual entry and exit")
	r=fresh();g.runner=r;r.members[0].x=HordeRun.ANCHOR;r.members[0].y=HordeRun.FLOOR
	r.boost_left=5;r.run_items.double_coins=true
	r.add_entity("coin",HordeRun.ANCHOR,HordeRun.FLOOR-48)
	r.advance(0.0);g.consume_run_events()
	expect(r.stats().frenzy_coins==4 and r.stats().clean_coins==4,"physical frenzy pickup and double-coins item share exact mission attribution")
	r.events.append({"type":"coin","amount":12,"x":300,"y":500});g.consume_run_events()
	expect(r.stats().frenzy_coins==4 and r.stats().clean_coins==4,"bonus coin grants cannot satisfy physical streak and frenzy collection")
	r=fresh();r.perk_kind=2;r.perk_left=5;r.add_entity("air_bomb",HordeRun.ANCHOR,HordeRun.FLOOR-45);r.advance(0.0)
	expect(r.stats().bombs_broken==1,"protected aerial bomb destruction advances hazard mission once")
	r.advance(0.0);expect(r.stats().bombs_broken==1,"destroyed hazard cannot repeat objective credit")
	r=fresh()
	for i in range(3):
		var civil=r.add_entity("civilian",450);civil.group=999;civil.capture_kind=0;r.complete_capture(civil)
	expect(r.stats().civil_groups==1,"three actual members complete a civilian group")
	var bus=r.add_entity("bus",600);r.flip_vehicle(bus)
	expect(r.stats().civil_groups==1,"rescued passengers cannot masquerade as an on-foot group")
	data=MonsterCatalog.defaults();g.data=data;g.hub.update(g,0.0)
	var m: Dictionary=HordeMissionCatalog.active(data)[0];data.claimed.append(m.key);data.mission_progress[m.id]=m.target
	g.hub.update(g,2.0)
	expect(HordeMissionCatalog.active(data)[0].key!=m.key,"real hub replaces the completed card after its confirmation delay")
	g.data=MonsterCatalog.defaults();g.hub.update(g,0.01)
	for width in [960,1280,1600]:
		var body=Rect2(60,165,width-120,455);var d=HordeExperimentUI.layout(body);var fit=body.encloses(d.chamber) and body.encloses(d.adrenaline)
		for row in d.cards: fit=fit and body.encloses(row) and not row.intersects(d.chamber)
		expect(fit,"mission panels fit viewport width "+str(width))
	print("V105_RESULT checks=",checks," failures=",failures)
	g.queue_free();g=null
	for i in range(3): await process_frame
	preload("res://scripts/bird_art.gd").textures.clear()
	quit(1 if failures else 0)
