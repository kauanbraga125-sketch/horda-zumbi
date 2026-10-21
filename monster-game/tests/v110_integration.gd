extends SceneTree
var checks=0
var failures=0
var g
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, note: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error("V110_FAIL "+note)
	else: print("V110_OK ",note)
func finish() -> void:
	g.revive_used=true;g.finish_run();g.end_delay=-1;g.change_screen("results")
func tick(seconds: float) -> void:
	for i in range(ceili(seconds*120)):
		g.ui_time+=1.0/120;g.hub.update(g,1.0/120)
func run() -> void:
	g=load("res://main.tscn").instantiate();root.add_child(g)
	g.test_mode=true;g.capture_mode=true;g.set_process(false);g.set_physics_process(false)
	g.sound.set_enabled(true)
	var soul_cues=[0]
	g.sound.result_cue.connect(func(name, _pitch, _volume):
		if name=="result_soul": soul_cues[0]+=1)
	expect(g.hub.result_ui.soul_frames.size()==6,"six transparent soul atlas regions load in the actual result screen")
	g.data=MonsterCatalog.defaults();g.data.wallet=100;g.data.level_souls=65;g.data.altar_souls=15
	g.start_run();g.runner.souls=8;g.check_challenges()
	expect(g.run_ritual_reports.size()==1 and int(g.run_mission_report.points)>0,"actual mission completion records its report during gameplay")
	expect(g.data.player_level==2 and g.data.wallet==220 and not g.hub.presentation.busy(),"level reward is saved immediately without playing its result animation during the run")
	var settled_xp=int(g.data.level_souls);g.hub.update(g,8)
	expect(g.run_ritual_reports.size()==1 and not g.hub.presentation.busy(),"time in gameplay cannot drain the deferred results sequence")
	finish()
	var ui=g.hub.result_ui;var p=ui.presentation
	expect(p.shown_level==1 and p.shown_xp==65 and p.wallet(g.data.wallet)==100,"results open at the previous essence and wallet before the already saved reward")
	expect(ui.landed==0 and ui.board_state().amount==15,"soul board opens with its exact previous progress")
	var paid=g.data.duplicate(true)
	tick(0.7)
	expect(ui.landed==0 and p.shown_xp==65,"souls have time to fly and essence waits for the results reveal")
	var full=false;var looped=false;var stages={};var wallet=100;var monotonic=true
	for i in range(1400):
		g.ui_time+=1.0/120;g.hub.update(g,1.0/120)
		full=full or p.amount()>=0.999;looped=looped or g.sound.result_liquid.playing;stages[p.stage()]=true
		var now=p.wallet(g.data.wallet);monotonic=monotonic and now>=wallet;wallet=now
	expect(ui.landed==8 and ui.board_state().amount==23 and g.data.altar_souls==23,"each earned soul arrives at a unique destination and ends at saved progress")
	expect(soul_cues[0]==8,"each of the eight actual arrivals triggers its own sound instead of a detached timer or throttle")
	expect(full and stages.has("react") and stages.has("award") and stages.has("reset"),"results show a full liquid fill, machine reaction, coin award and next mixture")
	expect(looped and not g.sound.result_liquid.playing,"liquid sound starts with the fill and stops when it finishes")
	expect(p.shown_level==2 and is_equal_approx(p.shown_xp,settled_xp) and p.pending_coins==0,"presentation ends at exact saved level and overflowing essence")
	expect(monotonic and wallet==220,"wallet rises monotonically to its actual credited reward")
	expect(g.data==paid,"drawing and sound cannot grant, remove or replay saved rewards")
	g.perform_action("graves_open");g.perform_action("back")
	expect(g.screen=="results" and ui.landed==8 and not p.busy() and g.data==paid,"returning from gravestones does not replay souls or rewards")
	# A soul board fills fully, holds, clears, and retains the overflow.
	g.data=MonsterCatalog.defaults();g.data.altar_souls=97;g.start_run();g.runner.souls=8;finish();ui=g.hub.result_ui
	tick(1.4)
	expect(ui.board_state().amount==100 and ui.board_state().graves==2,"crossing 100 visibly fills the entire table and announces two individual gravestones")
	expect(g.data.altar_souls==5 and g.data.graves.size()==1,"actual cemetery reward keeps its original paired-card economy")
	tick(4)
	expect(ui.landed==8 and ui.board_state().amount==5 and ui.remaining_graves(g.data)==2,"table continues with five souls on the next board and accurate gravestone count")
	g.data.graves[0].claimed[0]=true
	expect(ui.remaining_graves(g.data)==1,"navigation counts only gravestones still available to reveal")
	# Exact multiples settle to an empty next table after the full-board celebration.
	g.data=MonsterCatalog.defaults();g.data.altar_souls=99;g.start_run();g.runner.souls=1;finish();ui=g.hub.result_ui;tick(3)
	expect(ui.board_state().amount==0 and ui.board_state().graves==2 and g.data.altar_souls==0,"exact 100-soul boundary settles to zero rather than displaying a permanent full board")
	# Leaving halfway through either animation changes presentation only.
	g.data=MonsterCatalog.defaults();g.data.level_souls=65;g.start_run();g.runner.souls=24
	HordeProgress.queue_mission(g.data,{"key":"interruption","title":"TEST","ritual":8});g.begin_ritual();finish();tick(2.3)
	expect(g.sound.result_liquid.playing,"fill audio is active while the liquid is visibly rising")
	paid=g.data.duplicate(true);g.perform_action("graves_open")
	expect(not g.sound.result_liquid.playing and g.hub.result_ui.presentation.pending_coins==0 and g.data==paid,"early navigation stops liquid audio and completes visual counters without another payment")
	g.perform_action("back")
	expect(g.hub.result_ui.landed==24 and not g.hub.result_ui.presentation.busy() and g.data==paid,"reopening an interrupted result cannot spend, grant or restart the ceremony")
	var path="user://v110_saved_result.json"
	expect(g.save_game(path),"real atomic save writer accepts rewards before animation finishes")
	var restored=g.validate_save(JSON.parse_string(FileAccess.get_file_as_string(path)))
	expect(restored.wallet==paid.wallet and restored.altar_souls==paid.altar_souls and restored.level_souls==paid.level_souls and restored.player_level==paid.player_level,"reloaded save contains the final rewards even when presentation was interrupted")
	for suffix in ["",".tmp",".bak"]: DirAccess.remove_absolute(path+suffix)
	# Two distinct level-ups must retain their individual steps and coin amounts.
	g.data=MonsterCatalog.defaults();g.data.level_souls=63;g.data.wallet=200;g.start_run()
	for i in range(2):
		HordeProgress.queue_mission(g.data,{"key":"multi"+str(i),"title":"TEST","ritual":90});g.begin_ritual()
	var final_wallet=int(g.data.wallet);var final_level=int(g.data.player_level);var final_xp=int(g.data.level_souls)
	finish();ui=g.hub.result_ui;tick(25)
	expect(ui.report.steps.size()==g.run_mission_report.bonuses and ui.report.points==g.run_mission_report.points,"several missions merge into one ordered presentation with every level reward")
	expect(ui.presentation.shown_level==final_level and is_equal_approx(ui.presentation.shown_xp,final_xp) and ui.presentation.wallet(g.data.wallet)==final_wallet,"multi-level sequence preserves final essence, wallet and overflow")
	# Empty runs stay quiet, and maximum level cannot invent another reward.
	g.data=MonsterCatalog.defaults();g.data.altar_souls=42;g.start_run();finish();tick(5)
	expect(g.hub.result_ui.landed==0 and g.hub.result_ui.board_state().amount==42 and not g.sound.result_liquid.playing and not g.hub.result_ui.presentation.busy(),"zero souls and zero missions do not play false fill or reward effects")
	g.data=MonsterCatalog.defaults();g.data.player_level=500;g.data.level_souls=899;g.start_run()
	HordeProgress.queue_mission(g.data,{"key":"maximum","title":"TEST","ritual":300});g.begin_ritual();var capped=int(g.data.wallet)
	finish();tick(8)
	expect(g.data.player_level==500 and g.data.wallet==capped and g.hub.result_ui.reward_level==0,"maximum level cannot produce a false coin reward")
	# Fit and performance bounds for the supported landscape sizes and long runs.
	for view in [Rect2(0,0,960,720),Rect2(0,0,1280,720),Rect2(-160,0,1600,720),Rect2(0,-120,1280,960)]:
		var d=ui.layout(view);var fit=view.encloses(d.board) and view.encloses(d.chamber) and not d.board.intersects(d.chamber)
		for i in range(100): fit=fit and d.grid.encloses(ui.cell_rect(d.grid,i))
		for nav in d.nav: fit=fit and view.encloses(nav) and not nav.intersects(d.body)
		expect(fit,"100 cells, large vessel and all navigation fit "+str(view.size))
	g.data=MonsterCatalog.defaults();g.start_run();g.runner.souls=1200;finish();ui=g.hub.result_ui;var nodes=g.get_child_count()
	g.hub.update(g,100)
	expect(ui.landed==1200 and ui.board_state().amount==0 and g.data.graves.size()==12 and g.get_child_count()==nodes,"large settlement finishes with exact rewards and no per-soul nodes or accumulated particles")
	for name in ["soul","fill","full","coin","reward"]:
		var stream=g.sound.clips["result_"+name]
		expect(stream is AudioStreamWAV and stream.data.size()>6000 and stream.mix_rate==32000,"packed onset-aligned cue loads as PCM: "+name)
	g.sound.results_fill(true);g.sound.set_enabled(false)
	expect(g.sound.result_liquid.stream_paused,"master audio disable also mutes the new liquid loop")
	g.sound.results_fill(false);g.sound.set_enabled(true)
	print("V110_RESULT checks=",checks," failures=",failures)
	g.queue_free();g=null
	for i in range(3): await process_frame
	quit(1 if failures else 0)
