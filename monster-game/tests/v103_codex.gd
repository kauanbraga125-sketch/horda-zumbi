extends SceneTree

var game
var checks := 0
var failures := 0
var output := ""

func _initialize() -> void: call_deferred("run")

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("V103_FAIL "+message)

func advance(seconds: float) -> void:
	for i in range(ceili(seconds*30)):
		game.ui_time += 1.0/30
		game.codex.update(game,1.0/30)
		game.hub.update(game,1.0/30)
		game.queue_redraw()
		await process_frame

func snapshot(name: String) -> void:
	if output.is_empty(): return
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"))

func run() -> void:
	output = OS.get_environment("HORDA_VALIDATION_DIR")
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.test_mode = true
	game.set_process(false)
	game.set_physics_process(false)
	game.data = MonsterCatalog.defaults()
	game.data.wallet = 1621
	game.data.eyes = 5
	game.data.player_level = 7
	game.data.level_souls = 33
	game.data.altar_souls = 23
	game.hub.shown_level = 7
	game.hub.shown_xp = 33
	var book = game.codex
	expect(book.total_pages()==12,"twelve real pages")
	book.open(game,0)
	await advance(0.75)
	expect(book.amount>=0.99,"opening finishes")
	expect(not bool(game.data.codex_seen.get("zombie",false)),"reveal is not persisted prematurely")
	await snapshot("01-Pagina-Rasgada")
	await advance(2.0)
	expect(bool(game.data.codex_seen.get("zombie",false)),"owned page is recorded only after restoration")
	expect(not bool(game.data.codex_seen.get("skeleton",false)),"locked page stays locked")
	expect(game.data.owned==[0],"reveal never grants a monster")
	await snapshot("02-Monstros-Bloqueado")
	game.data.owned.append(1)
	await advance(0.45)
	book.action(game,"back")
	await advance(1.0)
	expect(game.screen=="home","book closes before returning home")
	expect(not bool(game.data.codex_seen.get("skeleton",false)),"interrupted reveal remains pending")
	book.open(game,0)
	await advance(2.8)
	expect(bool(game.data.codex_seen.get("skeleton",false)),"newly unlocked monster restores on reopening")
	await snapshot("03-Monstros-Completos")
	book.action(game,"codex_next")
	expect(book.section==1 and book.page_turn>0,"next starts an animated turn")
	book.action(game,"codex_next")
	expect(book.section==1,"rapid duplicate taps cannot skip pages")
	await advance(0.30)
	await snapshot("04-Folha-Virando")
	await advance(2.7)
	expect(book.page_number(1,0,0)==3,"transformation pages numbered three and four")
	expect(not bool(game.data.codex_seen.get("masked",false)),"masked remains locked")
	expect(bool(game.data.codex_seen.get("fly",false)),"owned fly is revealed")
	await snapshot("05-Transformacoes-Bloqueado")
	game.data.power_owned.append(2)
	await advance(2.0)
	await snapshot("06-Transformacoes-Completas")
	book.action(game,"codex_section_2")
	await advance(0.8)
	expect(book.section==2 and book.spread==0,"relic chapter opens at first spread")
	expect(not book.unlocked(game,book.record(2,0,0)),"first relic requires level ten")
	game.data.player_level = 75
	await advance(2.1)
	await snapshot("07-Reliquias-Primeiras")
	book.action(game,"codex_next")
	await advance(2.6)
	expect(book.section==2 and book.spread==1,"relics have another spread")
	expect(book.page_number(2,1,0)==7,"later relic pages numbered seven and eight")
	await snapshot("08-Reliquias-Pacto")
	book.action(game,"codex_next")
	await advance(0.8)
	expect(book.section==3 and book.spread==0,"next chapter follows final relic spread")
	expect(not book.unlocked(game,book.record(3,0,0)),"prestige stays locked below one hundred")
	game.data.player_level = 150
	await advance(2.0)
	await snapshot("09-Prestigio")
	book.action(game,"codex_pact")
	await advance(2.7)
	expect(book.signature_active(game),"signature accessible on pact page")
	game.hub.name_edit.text = "Kauan"
	game.hub.signature_points = [{"x":0.1,"y":0.8,"new":true},{"x":0.2,"y":0.2,"new":false},{"x":0.35,"y":0.7,"new":false},{"x":0.7,"y":0.3,"new":false}]
	game.perform_action("book_sign")
	expect(game.data.book_name=="Kauan" and not game.data.book_signed_at.is_empty(),"original signature flow persists")
	await advance(0.1)
	await snapshot("10-Pacto-Assinado")
	var restored: Dictionary = game.validate_save(game.data.duplicate(true))
	expect(restored.codex_seen==game.data.codex_seen,"restored pages survive save migration")
	expect(restored.wallet==1621 and restored.eyes==5 and restored.altar_souls==23,"balances and cemetery progress preserved")
	expect(restored.level_souls==33 and restored.book_signature==game.data.book_signature,"essence and signature preserved")
	book.action(game,"back")
	await advance(1.0)
	expect(game.data.codex_section==3 and game.data.codex_spread==1,"bookmark persisted")
	book.open(game)
	await advance(0.8)
	expect(book.section==3 and book.spread==1,"bookmark reopened")
	for size in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,960)]:
		root.size = size
		await process_frame
		game.configure_layout()
		await advance(0.1)
		var d: Dictionary = book.layout(game)
		for p in d.pages: expect(game.full_rect().encloses(p),"page inside viewport "+str(size))
		expect(d.tabs.end.x<=game.full_rect().end.x,"tabs inside viewport "+str(size))
		await snapshot("11-Layout-"+str(size.x)+"x"+str(size.y))
	root.size = Vector2i(1280,720)
	await process_frame
	game.configure_layout()
	book.action(game,"codex_section_0")
	await advance(0.8)
	var b: Rect2 = book.layout(game).book
	var start := b.get_center()+Vector2(150,-40)
	var press := InputEventScreenTouch.new()
	press.index=3; press.pressed=true; press.position=game.to_global(start)
	book.input(game,press)
	var release := InputEventScreenTouch.new()
	release.index=3; release.pressed=false; release.position=game.to_global(start-Vector2(190,0))
	book.input(game,release)
	expect(book.section==1,"touch swipe advances spread")
	book.chapters[0].append(book.chapters[0][0].duplicate())
	expect(book.spreads(0)==2 and book.total_pages()==14,"pagination adapts when another monster is added")
	book.chapters[0].pop_back()
	book.action(game,"back")
	await advance(0.7)
	await snapshot("12-Capa-Fechando")
	await advance(0.3)
	await snapshot("13-Menu-Final")
	print("V103_RESULT checks=",checks," failures=",failures)
	game.queue_free()
	await process_frame
	preload("res://scripts/bird_art.gd").textures.clear()
	quit(1 if failures else 0)
