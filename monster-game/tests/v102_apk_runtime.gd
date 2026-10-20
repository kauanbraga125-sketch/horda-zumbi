extends SceneTree
var checks = 0
var failures = 0
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error("APK102_FAIL "+label)
	else: print("APK102_OK ",label)
func run() -> void:
	var boot=load("res://boot.tscn").instantiate();root.add_child(boot)
	for i in range(8): await process_frame
	var g=root.get_node_or_null("NoiteDaHorda")
	expect(is_instance_valid(g) and g.has_method("start_run"),"startup integrity loads complete game")
	if not is_instance_valid(g): quit(1);return
	g.test_mode=true;g.set_process(false);g.set_physics_process(false)
	for name in ["book_cover","book_open","cemetery","hand_open","hand_grasp"]:
		var texture=load("res://assets/art/menu_v102/"+name+".png") as Texture2D
		expect(texture!=null and texture.get_width()>0,"packed artwork "+name)
	g.data=MonsterCatalog.defaults();g.data.wallet=987;g.data.eyes=5;g.hub.update(g,.01)
	g.perform_action("collection");g.codex.update(g,.6)
	expect(g.screen=="collection" and g.codex.amount==1,"collection opens book")
	g.perform_action("codex_next");expect(g.codex.section==1,"chapter changes")
	g.perform_action("back");g.codex.update(g,.5);g.codex.update(g,.3)
	expect(g.screen=="home" and g.data.codex_section==1,"book closes and remembers chapter")
	var rng=RandomNumberGenerator.new();rng.seed=102
	HordeProgress.settle(g.data,135,rng)
	expect(g.data.altar_souls==35 and g.data.graves.size()==1 and g.data.player_level==1,"souls fill cemetery with overflow")
	g.data.ritual_ready=true;g.data.ritual_pending=[{"key":"apk-check","points":66}];HordeProgress.ritual(g.data,rng)
	expect(g.data.player_level==2 and g.data.altar_souls==35,"mission essence advances level independently")
	g.data.stock.power_mask=2;g.perform_action("play");expect(g.screen=="prepare","Play opens inventory")
	g.perform_action("select_object_power_mask");g.perform_action("commit_play")
	expect(g.screen=="run" and g.data.stock.power_mask==1,"start consumes selected item once")
	var x: float=g.runner.world_px
	for i in range(12): g._physics_process(1.0/60)
	expect(g.runner.world_px>x and not g.runner.dead,"real gameplay advances")
	g.perform_action("pause");x=g.runner.world_px
	for i in range(12): g._physics_process(1.0/60)
	expect(g.runner.world_px==x,"pause freezes gameplay")
	print("APK102_RESULT checks=",checks," failures=",failures)
	g.queue_free();await process_frame;quit(1 if failures else 0)
