extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("APK103_FAIL "+label)
	else: print("APK103_OK ", label)
func run() -> void:
	var boot = load("res://boot.tscn").instantiate()
	root.add_child(boot)
	for i in range(10): await process_frame
	var g = root.get_node_or_null("NoiteDaHorda")
	expect(is_instance_valid(g) and g.has_method("start_run"),"integrity audit loads final packed game")
	if not is_instance_valid(g): quit(1); return
	g.test_mode = true; g.set_process(false); g.set_physics_process(false)
	for name in ["zombie","skeleton","masked","fly","relics","prestige"]:
		var texture = load("res://assets/art/codex_v103/"+name+".png") as Texture2D
		expect(texture!=null and texture.get_width()>500,"packed codex artwork "+name)
	for name in ["Cinzel-Variable","Lora-Variable","Lora-Italic-Variable"]:
		var font = load("res://assets/fonts/"+name+".ttf") as Font
		expect(font!=null and font.get_string_size("Invocação",0,-1,22).x>0,"packed readable font "+name)
	g.data = MonsterCatalog.defaults(); g.data.wallet=987; g.data.eyes=5
	g.hub.update(g,0.01)
	g.perform_action("collection"); g.codex.update(g,0.7)
	expect(g.screen=="collection" and g.codex.total_pages()==12,"book opens twelve actual numbered pages")
	g.codex.update(g,1.9)
	expect(bool(g.data.codex_seen.get("zombie",false)) and not bool(g.data.codex_seen.get("skeleton",false)),"restoration respects ownership")
	g.perform_action("codex_next"); g.codex.update(g,0.7)
	expect(g.codex.section==1 and g.codex.page_number(1,0,0)==3,"page turn reaches transformations")
	g.perform_action("back"); g.codex.update(g,0.6); g.codex.update(g,0.35)
	expect(g.screen=="home" and g.data.codex_section==1,"animated close remembers chapter")
	var rng = RandomNumberGenerator.new(); rng.seed=103
	HordeProgress.settle(g.data,135,rng)
	expect(g.data.altar_souls==35 and g.data.graves.size()==1 and g.data.player_level==1,"souls fill cemetery with overflow and no level gain")
	g.data.ritual_ready=true; g.data.ritual_pending=[{"key":"apk-check","points":66}]
	HordeProgress.ritual(g.data,rng)
	expect(g.data.player_level==2 and g.data.altar_souls==35,"mission essence advances level independently")
	g.data.stock.power_mask=2; g.perform_action("play")
	expect(g.screen=="prepare","Play opens inventory")
	g.perform_action("select_object_power_mask"); g.perform_action("commit_play")
	expect(g.screen=="run" and g.data.stock.power_mask==1,"start consumes chosen item exactly once")
	var x: float = g.runner.world_px
	for i in range(12): g._physics_process(1.0/60)
	expect(g.runner.world_px>x and not g.runner.dead,"actual gameplay advances")
	g.perform_action("pause"); x=g.runner.world_px
	for i in range(12): g._physics_process(1.0/60)
	expect(g.runner.world_px==x,"pause freezes gameplay")
	print("APK103_RESULT checks=",checks," failures=",failures)
	g.queue_free(); g=null
	for i in range(3): await process_frame
	quit(1 if failures else 0)
