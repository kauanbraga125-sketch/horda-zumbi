extends SceneTree
var game
var checks = 0
var failures = 0
var output: String
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error("V102_CHECK "+message)
func snapshot(name: String) -> void:
	game.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
func run() -> void:
	output = OS.get_environment("HORDA_VALIDATION_DIR")
	game = load("res://main.tscn").instantiate();root.add_child(game)
	game.test_mode = true;game.set_physics_process(false)
	game.data = MonsterCatalog.defaults();game.data.owned=[0,1];game.data.power_owned=[3,2]
	game.data.wallet=1621;game.data.eyes=5;game.data.altar_souls=23;game.data.player_level=7;game.data.level_souls=33
	game.hub.shown_xp=33;game.hub.shown_level=7;game.change_screen("home");game.ui_time=3
	for size in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,960)]:
		root.size=size;await process_frame;await process_frame;game.configure_layout()
		var v=game.full_rect();var d=game.home_menu.layout(v)
		expect(d.level.end.x<=d.wallet.position.x-5,"level/wallet separation")
		expect(d.ritual.end.y<d.play.position.y,"cemetery/play separation")
		expect(d.play.end.y<d.nav.position.y,"play/nav separation")
		for rect in d.tabs: expect(v.encloses(rect),"navigation fits")
		expect(v.encloses(d.profile),"profile fits")
		await snapshot("Menu-"+str(size.x)+"x"+str(size.y))
	root.size=Vector2i(1280,720);await process_frame;await process_frame
	game.perform_action("collection");expect(game.screen=="collection","collection opens bestiary")
	await create_timer(.75).timeout;expect(game.codex.amount>=.99,"book opens");await snapshot("Livro-Monstros")
	game.perform_action("codex_next");expect(game.codex.section==1,"next chapter");await snapshot("Livro-Transformacoes")
	game.perform_action("codex_section_2");expect(game.codex.section==2,"relic chapter");await snapshot("Livro-Reliquias")
	game.perform_action("codex_section_3");expect(not game.codex.signature_active(game),"signature locked before 75")
	game.data.player_level=75;expect(game.codex.signature_active(game),"signature unlocks at 75")
	game.hub.update(game,.01);expect(game.hub.name_edit.visible,"name field visible")
	game.hub.name_edit.text="Kauan";game.hub.signature_points=[{"x":.1,"y":.7,"new":true},{"x":.15,"y":.2,"new":false},{"x":.3,"y":.6,"new":false},{"x":.6,"y":.3,"new":false},{"x":.8,"y":.6,"new":false}]
	game.perform_action("book_sign");expect(game.data.book_name=="Kauan" and not game.data.book_signed_at.is_empty(),"signature saved")
	var restored=game.validate_save(game.data.duplicate(true));expect(restored.book_signature==game.data.book_signature and restored.book_name=="Kauan","signature migration")
	expect(restored.wallet==1621 and restored.eyes==5 and restored.altar_souls==23,"balances preserved");await snapshot("Livro-Assinatura")
	game.perform_action("back");expect(game.screen=="collection" and game.codex.closing,"closing begins before leaving")
	await create_timer(.56).timeout;await snapshot("Capa-Fechando");await create_timer(.4).timeout
	expect(game.screen=="home","closing returns home");expect(game.data.codex_section==3,"chapter remembered")
	game.perform_action("collection");await create_timer(.65).timeout;expect(game.codex.section==3,"chapter reopens")
	game.perform_action("codex_section_0");var b=game.codex.layout(game).book;var from=b.get_center()+Vector2(180,-65)
	var press=InputEventScreenTouch.new();press.index=3;press.pressed=true;press.position=game.to_global(from);game.codex.input(game,press)
	var release=InputEventScreenTouch.new();release.index=3;release.pressed=false;release.position=game.to_global(from-Vector2(220,0));game.codex.input(game,release)
	expect(game.codex.section==1,"swipe turns chapter")
	game.change_screen("home");await snapshot("Menu-Final");var d=game.home_menu.layout(game.full_rect())
	game.press_at(d.altar);expect(game.screen=="graves","cemetery artwork touch")
	game.perform_action("back");await process_frame;await snapshot("Menu-Toque")
	game.press_at(d.level.get_center());expect(game.screen=="missions","level opens missions")
	game.change_screen("home");game.hub.update(game,.01);expect(not game.hub.fluid.visible,"no floating vessel over menu")
	print("V102_RESULT checks=",checks," failures=",failures)
	# Short actual renderer capture: two windows show the spaced ambient cycles.
	game.set_process(false);game.data.player_level=7;game.hub.shown_level=7;game.data.codex_section=0
	var frames=output.path_join("frames");DirAccess.make_dir_recursive_absolute(frames)
	for i in range(84):
		if i<24: game.ui_time=2.0+i/12.0
		elif i<48: game.ui_time=19.0+(i-24)/12.0
		else: game.ui_time+=1.0/12.0
		if i==48: game.perform_action("collection")
		if i==72: game.perform_action("back")
		game.configure_layout();game.codex.update(game,1.0/12.0);game.hub.update(game,1.0/12.0);game.queue_redraw()
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_jpg(frames.path_join("frame_%03d.jpg"%i),.9)
	print("V102_CAPTURE frames=84 fps=12")
	game.queue_free();await process_frame;quit(1 if failures else 0)
