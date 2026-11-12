extends SceneTree

const Regions = preload("res://scripts/sky_region_scenery.gd")
const Motion = preload("res://scripts/sky_motion.gd")
const Deep = preload("res://scripts/sky_deep_landscape.gd")
var checks = 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(valid: bool, message: String) -> void:
	checks += 1
	if not valid:failures.append(message)

func run() -> void:
	for name in ["sanctuary","storm","graveyard"]:
		var tex = Regions.texture(name)
		check(tex!=null and tex.get_width()>1000,"Missing detailed region: "+name)
		check(tex==Regions.texture(name),"Region texture is decoded every frame: "+name)
	check(Regions.texture("graveyard_high")==Regions.texture("graveyard"),"Orbital layers duplicate the same GPU texture")
	check(Regions.textures.size()==3,"The sky region cache contains unexpected duplicate textures")
	var motion = Motion.new();motion.warm()
	for name in ["elder","dragon_up","dragon_down","witch","mist_far","mist_front","orbit_dust","orbit_eyes","orbit_eyes_shut","meteor_shards","derelict"]:
		check(motion.frames.has(name),"Missing region frame: "+name)
	for time in [0.0,12.0,48.0]:
		for size in [Vector2(1280,720),Vector2(1800,810),Vector2(960,720)]:
			for top in [-1000.0,-2800.0,-4000.0,-7000.0,-10500.0]:
				for travel in [500.0,6000.0,16000.0]:
					var view = Rect2(Vector2(-100,top),size)
					for kind in ["elder","dragon","witch","fireflies"]:
						var point = Regions.position(kind,view,Vector2(travel,top),time)
						var reference = Regions.position(kind,Rect2(-100,0,size.x,size.y),Vector2(travel,0),time)
						check(absf(point.y-reference.y)<.01,kind+" follows altitude or viewport height")
	var low = Rect2(-100,-2700,1280,720)
	var high = Rect2(-100,-4500,1280,720)
	for kind in ["elder","dragon","witch"]:
		var a = Regions.position(kind,low,Vector2(4000,-2700),14)-low.position
		var b = Regions.position(kind,high,Vector2(4000,-4500),14)-high.position
		check(absf(b.y-a.y-1800.0)<.01,kind+" cancels camera travel")
	var far_above = Rect2(-100,-10000,1280,720)
	check(not far_above.grow(500).has_point(Regions.position("elder",far_above,Vector2(12000,-10000),30)),"Elder wraps vertically into the higher sky")
	check(not far_above.grow(500).has_point(Regions.position("dragon",far_above,Vector2(12000,-10000),30)),"Dragon wraps vertically into the higher sky")
	var report = {"version":"0.10.65","checks":checks,"failures":failures,"fixed_region_altitudes":true,"shared_texture_cache":true,"physical_device_tested":false}
	var folder = OS.get_environment("HORDA_VALIDATION_DIR")
	if not folder.is_empty():
		DirAccess.make_dir_recursive_absolute(folder)
		var file = FileAccess.open(folder+"/regions.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"  "))
	for message in failures:push_error(message)
	print("V165_REGIONS ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
