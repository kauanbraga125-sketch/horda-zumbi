extends SceneTree

const Deep = preload("res://scripts/sky_deep_landscape.gd")
const Hauntings = preload("res://scripts/sky_hauntings.gd")
const Motion = preload("res://scripts/sky_motion.gd")
var failures: Array[String] = []
var checks = 0

func _initialize() -> void: call_deferred("run")

func check(valid: bool, message: String) -> void:
	checks += 1
	if not valid: failures.append(message)

func run() -> void:
	Deep.warm()
	check(Deep.backdrop!=null and Deep.dust!=null,"Cosmic artwork cannot load from exported raw resources")
	var motion = Motion.new();motion.warm()
	for key in ["space_cathedral","devour_open","devour_closed","devour_planet","devour_bitten","meteor_shards","derelict","orbit_saucer_far"]:
		check(motion.frames.has(key),"Missing cosmic frame: "+key)
	for size in [Vector2(1280,720),Vector2(1800,810),Vector2(960,720)]:
		for top in [-9200.0,-10000.0,-10600.0,-11200.0,-12800.0]:
			for travel in [0.0,12000.0,20000.0]:
				var view = Rect2(Vector2(-100,top),size)
				var camera = Vector2(travel,top)
				check(absf(Deep.planet_position(view,camera).y-Deep.PLANET.y)<.01,"The planet follows camera altitude")
				check(absf(Deep.devourer_position(view,camera).y-Deep.DEVOURER.y)<.01,"The devourer follows camera altitude")
				check(absf(Deep.duel_position(view,camera).y-Deep.DUEL.y)<.01,"The distant duel follows camera altitude")
	var lower = Rect2(-100,-10000,1280,720)
	var upper = Rect2(-100,-11200,1280,720)
	var low = Deep.devourer_position(lower,Vector2(12000,-10000))-lower.position
	var high = Deep.devourer_position(upper,Vector2(12000,-11200))-upper.position
	check(absf(high.y-low.y-1200.0)<.01,"The devourer's camera travel is canceled by viewport anchoring")
	var planet = Deep.planet_position(upper,Vector2(12000,-11200))
	var eater = Deep.devourer_position(upper,Vector2(12000,-11200))
	check(planet.x<eater.x and planet.y<eater.y,"The background planet is hidden directly behind the creature's face")
	check(Deep.devourer_position(upper,Vector2(12000,-11200)).y==Deep.devourer_position(upper,Vector2(20000,-11200)).y,"Horizontal travel changes the devourer's altitude")
	var dust = Image.load_from_file(Deep.DUST)
	var cover = dust.get_pixel(roundi(dust.get_width()*.461),roundi(dust.get_height()*.741)).a
	check(cover>.85,"Foreground dust leaves the cut edge of the creature bust exposed")
	var h = Hauntings.new();h.reset(16210)
	h.advance(1.0,10899.0)
	check(not h.devour_seen,"The devourer starts animating before its region is reached")
	h.advance(.5,10900.0)
	check(h.devour_seen and is_equal_approx(h.devour_clock,.5),"The devourer does not start its independent animation")
	h.advance(8.0,11200.0)
	check(h.devour_seen and h.devour_clock>6.4,"The creature disappears when the old timed scene ends")
	h.advance(1.0,9800.0)
	check(h.devour_clock>9.0,"Descending resets the world landmark")
	h.reset(16210)
	check(not h.devour_seen and h.devour_clock==0.0,"A new flight retains the old devourer state")
	var report = {"version":"0.10.64","checks":checks,"failures":failures,"world_altitude_fixed":true,"foreground_masks_bust_edge":true,"persistent_landmark":true,"physical_device_tested":false}
	var folder = OS.get_environment("HORDA_VALIDATION_DIR")
	if not folder.is_empty():
		DirAccess.make_dir_recursive_absolute(folder)
		var out = FileAccess.open(folder+"/cosmic.json",FileAccess.WRITE)
		out.store_string(JSON.stringify(report,"  "))
	for message in failures:push_error(message)
	print("V164_COSMIC ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
