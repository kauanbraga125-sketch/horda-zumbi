extends "res://tests/v134_visual.gd"
func run() -> void:
 folder = OS.get_environment("HORDA_VALIDATION_DIR");assert(not folder.is_empty());DirAccess.make_dir_recursive_absolute(folder)
 root.size = Vector2i(1280,720);game = load("res://main.tscn").instantiate();root.add_child(game);await process_frame
 game.test_mode = true;game.capture_freeze = true;game.set_physics_process(false);game.sound.set_enabled(false)
 flight(20,true);var s = game.runner.space;s.routes.start(s,game.runner,"gates");step(1.8);await snap("01_minas_orbitais")
 flight(20,true);s = game.runner.space;s.charge = 100;s.boost(game.runner)
 step(.20);await snap("02_preparar_subida");step(.43);await snap("03_subida_aceleracao");step(.50);await snap("04_subida_alta");step(.52);await snap("05_subida_nova_camada");step(.50);await snap("06_subida_fim")
 game.lab_count = 8;game.start_lab("space");step(.35);await snap("07_decolagem_inicio");step(.65);await snap("08_decolagem_chao_descendo");step(.6);await snap("09_decolagem_orbita");step(1);await snap("10_decolagem_fim")
 flight(8,true);s = game.runner.space;s.add_object("rock",s.x+80,s.y-48,{"speed":0.0,"radius":48.0});s.dash();step(.15);await snap("11_contato_durante_investida");step(.4);await snap("12_recuo_horda")
 flight(20,true);s = game.runner.space;s.altitude = 2150;s.routes.start(s,game.runner,"counterattack");step(1.8);await snap("13_ninho_vivo")
 var out = FileAccess.open(folder+"/visual.json",FileAccess.WRITE);out.store_string(JSON.stringify({"version":"0.10.35","native_captures":shots,"physical_device_tested":false},"  "));out.close()
 game.set_process(false);game.queue_free();game = null
 for i in range(8): await process_frame
 print("V135_VISUAL_OK ",shots);quit()
