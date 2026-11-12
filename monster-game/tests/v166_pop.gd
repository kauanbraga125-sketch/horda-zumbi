extends SceneTree

const Pop = preload("res://scripts/sky_pop_encounters.gd")
var checks = 0
var failures: Array[String] = []

func _initialize() -> void:call_deferred("run")

func check(valid: bool, message: String) -> void:
	checks += 1
	if not valid:failures.append(message)

func run() -> void:
	for group in ["worm","kaiju","orbit"]:Pop.warm(group)
	check(Pop.frames.size()==21,"Incomplete pop encounter animation frames")
	check(Pop.atlases.size()==3,"Atlas cache duplicates image textures")
	for name in Pop.manifest.frames:
		var data: Dictionary = Pop.manifest.frames[name]
		var rect: Array = data.rect
		var atlas: Dictionary = Pop.manifest.atlases[data.atlas]
		check(rect[0]>=0 and rect[1]>=0 and rect[0]+rect[2]<=atlas.width and rect[1]+rect[3]<=atlas.height,"Frame exceeds its atlas: "+name)
		check(Pop.frames[name].texture.atlas==Pop.atlases[data.atlas],"Frame does not share the atlas texture: "+name)
	for size in [Vector2(1280,720),Vector2(1800,810),Vector2(960,720)]:
		for top in [-1000.0,-2500.0,-4500.0,-8000.0,-11000.0]:
			for x in [0.0,7000.0,18000.0]:
				var view = Rect2(Vector2(-100,top),size)
				for kind in Pop.SCENES:
					var point = Pop.position(kind,view,Vector2(x,top))
					check(absf(point.y-Pop.SCENES[kind].anchor.y)<.01,"Encounter follows camera altitude: "+kind)
	for kind in ["worm","kaiju","orbit"]:
		var first = Pop.position(kind,Rect2(-100,-2000,1280,720),Vector2(5000,-2000))
		var second = Pop.position(kind,Rect2(-100,-5000,1280,720),Vector2(5000,-5000))
		check(absf((second.y+5000)-(first.y+2000)-3000.0)<.01,"Encounter cancels vertical camera travel: "+kind)
	check(Pop.pose("worm",2.5)==[1] and Pop.pose("worm",3.8)==[2] and Pop.pose("worm",5.0)==[3],"Worm lacks prepare, lunge and chew states")
	check(Pop.pose("kaiju",1.6)==[1,2] and Pop.pose("kaiju",4.5)==[2,1],"Kaiju attack and defence frames never alternate")
	check(Pop.pose("orbit",2.5)==[1,2] and Pop.pose("orbit",5.4)==[2,1],"Orbital hunters lack distinct pounce and counterattack states")
	for x in [-165.0,-120.0,0.0,120.0,165.0]:
		var a = Pop.ledge_top(Vector2(100,-4350),x,650)
		var b = Pop.ledge_top(Vector2(100,-7520),x,650)
		check(absf(a.y-b.y-3170.0)<.01,"Monster footing is not anchored to its rock")
	var report = {"version":"0.10.66","checks":checks,"failures":failures,"fixed_world_roots":true,"distinct_animation_poses":true,"decorative_only":true,"physical_device_tested":false}
	var folder = OS.get_environment("HORDA_VALIDATION_DIR")
	if not folder.is_empty():
		DirAccess.make_dir_recursive_absolute(folder)
		var f = FileAccess.open(folder+"/pop.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "))
	for message in failures:push_error(message)
	print("V166_POP ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
