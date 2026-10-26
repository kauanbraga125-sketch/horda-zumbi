extends SceneTree
var checks=0
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:push_error(message);quit(1)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var game=load("res://main.tscn").instantiate()
	game.data=MonsterCatalog.defaults()
	game.data.best=4567;game.data.runs=31;game.data.total_souls=842
	game.data.cosmetics=["bruxa"];game.data.active_cosmetics=["bruxa"]
	check(game.apply_test_funds(),"Funds granted for new and existing saves")
	check(game.data.wallet==1000000 and game.data.eyes==10000,"Both shop currencies funded")
	check(game.data.best==4567 and game.data.runs==31 and game.data.total_souls==842,"Progress preserved")
	check(game.data.cosmetics==["bruxa"] and game.data.active_cosmetics==["bruxa"],"Owned/equipped items preserved")
	for entry in HordeCosmeticCatalog.ITEMS:
		check(HordeMeta.equip_cosmetic(game.data,entry.id),"Can purchase "+entry.id)
	check(game.data.cosmetics.size()==35,"Can own all 35 cosmetics")
	check(game.data.wallet>0 and game.data.eyes>0,"Budget remains for other tests")
	check(game.apply_test_funds(),"Next app start refills spent funds")
	check(not game.apply_test_funds(),"Refilling is idempotent")
	game.data.wallet=2000000;game.data.eyes=20000
	check(not game.apply_test_funds() and game.data.wallet==2000000 and game.data.eyes==20000,"Larger balances never decrease")
	ProjectSettings.set_setting("testing/catalog_funds_enabled",false)
	game.data.wallet=500;game.data.eyes=2
	check(not game.apply_test_funds() and game.data.wallet==500 and game.data.eyes==2,"Release flag disables test grant")
	print("V129_CURRENCY_OK checks=",checks," all_cosmetics=35")
	game.free();quit()
