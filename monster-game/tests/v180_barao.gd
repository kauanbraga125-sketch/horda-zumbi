extends SceneTree

const Barao = preload("res://scripts/barao_power.gd")
const Art = preload("res://scripts/bird_art.gd")
var failures: Array[String] = []

func _initialize() -> void:call_deferred("run")

func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)

func model(second: bool = false) -> HordeRun:
	var r = HordeRun.new()
	r.start_developer("bomb",4,0,180)
	r.next_pattern_world = 1e12
	var data = MonsterCatalog.defaults()
	data.bird_copies = {"barao":1,"pipoco":1}
	data.bird_equipped_slots = ["pipoco","barao"] if second else ["barao",""]
	r.bird.configure(data)
	return r

func step(r: HordeRun,seconds: float) -> void:
	for i in range(roundi(seconds*60)):r.advance(1.0/60)

func run() -> void:
	var r = model()
	var power = r.bird.barao
	check(Art.barao_texture().get_size()==Vector2(960,640),"Action atlas has all 20 frames")
	for i in range(12):r.bird.on_perfect(r)
	step(r,24.9)
	check(r.bird.coin_multiplier()==1 and power.next_power==Barao.Power.DOUBLE,"Perfects cannot trigger an early cast")
	step(r,.2)
	check(r.bird.coin_multiplier()==2,"First cast doubles collectible coins")
	var coin = r.add_entity("coin",r.ANCHOR+32,r.FLOOR-48)
	step(r,.1)
	check(coin.taken and r.coins==2,"Street pickup has twice its normal value")
	step(r,8.0)
	coin = r.add_entity("coin",r.ANCHOR+32,r.FLOOR-48)
	step(r,.1)
	check(coin.taken and r.coins==3 and r.bird.coin_multiplier()==1,"Normal value returns after the cast")

	step(r,16.8)
	check(power.active_power==Barao.Power.DROP and r.coins==3,"Second cast starts with a flight and no payout")
	step(r,4)
	check(power.released==6 and r.coins==9,"All six trail coins can be collected on the street")
	step(r,21)
	check(power.bombs_ready and power.active_power==Barao.Power.NONE,"Third cast holds its charge without a bomb")
	var crate = r.add_entity("crate",r.ANCHOR+560)
	var bomb = r.add_entity("bomb",r.view_right+160)
	step(r,.2)
	check(not crate.taken and not bomb.taken and power.bombs_ready,"Neither offscreen hazards nor crates consume the charge")
	crate.taken = true
	step(r,1.0)
	check(bomb.taken and not power.bombs_ready and r.coins==9,"Visible bomb is removed before paying a coin")
	step(r,3.5)
	check(r.coins==10 and int(r.mission_stats.bombs_broken)==1,"Transmuted bomb yields a single collectible")
	check(r.losses==0,"Converted bomb causes no damage")

	r = model(true)
	power = r.bird.companion.barao
	power.until_power = .1
	r.bird.pipoco.until_spit = .1
	step(r,4)
	check(r.bird.coin_multiplier()==2 and r.coins==4,"Pipoco's coins double even with Barão in the second slot")

	r = model()
	power = r.bird.barao
	power.until_power = .1
	r.sewer.begin(r,true)
	step(r,2)
	check(is_equal_approx(power.until_power,.1),"Sewer entry suspends the clock")
	r.sewer.phase = "ride"
	r.sewer.next_encounter = 1e12
	step(r,.2)
	var boat = r.sewer.boats[0]
	var pickup = r.sewer.add_object("coin",boat.x+24,boat.y-24,{"water_depth":0.0})
	step(r,.1)
	check(pickup.taken and r.coins==2,"Sewer pickups double too")
	step(r,8)
	power.until_power = .1
	step(r,4.5)
	check(r.coins==8,"The trail reaches the sewer riders")
	power.until_power = .1
	var barrel = r.sewer.add_object("barrel",r.sewer.boats[0].x+440,r.sewer.WATER-35)
	step(r,1.8)
	check(barrel.taken and r.coins==9 and r.losses==0,"The sewer bomb becomes a collectible")

	r = model()
	power = r.bird.barao
	power.until_power = .1
	r.space.active = true
	r.space.phase = "flight"
	r.space.flight_age = 1.0
	r.space.left = 28.0
	r.space.next_group = 1e12
	r.space.manual_control = true
	step(r,.2)
	var centre: Vector2 = r.space.battle.member_centre(r,r.leader_index())
	pickup = r.space.add_object("coin",centre.x+24,centre.y,{"radius":20.0})
	step(r,.1)
	check(pickup.taken and r.coins==4,"Orbital pickups double from two coins to four")
	step(r,8)
	power.until_power = .1
	step(r,4.5)
	check(r.coins==10,"The trail reaches the formation in space")

	r = model()
	power = r.bird.barao
	r.bird.configure(MonsterCatalog.defaults())
	step(r,26)
	check(power.active_power==Barao.Power.NONE and r.bird.coin_multiplier()==1,"An unequipped Barão has no effect")
	print("V180_BARAO ",JSON.stringify({"failures":failures}))
	quit(0 if failures.is_empty() else 1)
