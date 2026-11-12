extends SceneTree

const Landscape = preload("res://scripts/sky_landscape.gd")
const Hauntings = preload("res://scripts/sky_hauntings.gd")
var checks = 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(valid: bool, message: String) -> void:
	checks += 1
	if not valid: failures.append(message)

func run() -> void:
	var image = Image.load_from_file(Landscape.ART)
	check(image != null and not image.is_empty(),"Mountain artwork cannot be read as an exported raw resource")
	for time in [0.0,4.0,6.0,12.0,30.0,48.0,60.0]:
		var anchor = Landscape.walker_anchor(time)
		var u = (anchor.x-Landscape.RIDGE.position.x)/Landscape.RIDGE.size.x
		var col = roundi(u*float(image.get_width()-1))
		var crest = 0
		while crest<image.get_height() and image.get_pixel(col,crest).a<.5: crest += 1
		var actual_y = Landscape.RIDGE.position.y+float(crest)/image.get_height()*Landscape.RIDGE.size.y
		check(absf(anchor.y-actual_y)<6.0,"Feet do not follow the painted mountain silhouette")
		for size in [Vector2(1280,720),Vector2(1800,810),Vector2(960,720)]:
			for camera_y in [180.0,-400.0,-1200.0,-3200.0,-9000.0]:
				var view = Rect2(Vector2(-100,camera_y),size)
				var foot = Hauntings.walker_position(view,Vector2(900,camera_y),time)
				check(absf(foot.y-anchor.y)<.01,"Camera altitude moves the giant away from the ridge's world altitude")
				var ridge_point = Landscape.project(anchor,view,Vector2(900,camera_y),Landscape.RIDGE_DEPTH)
				check(foot.distance_to(ridge_point)<.01,"Giant and mountain use different projection planes")
	var low_view = Rect2(-100,-1100,1280,720)
	var high_view = Rect2(-100,-3000,1280,720)
	var low = Hauntings.walker_position(low_view,Vector2(900,-1100),6.0)
	var high = Hauntings.walker_position(high_view,Vector2(900,-3000),6.0)
	check(low_view.has_point(low),"The ridge crossing never reveals the walking giant")
	check(high.y-Hauntings.WALKER_SCALE>high_view.end.y,"The giant follows the horde into higher sky instead of leaving below")
	check(absf((high.y-high_view.position.y)-(low.y-low_view.position.y)-1900.0)<.01,"Relative camera travel is canceled by a viewport anchor")
	var descent_view = Rect2(-100,-1300,1280,720)
	var returning = Hauntings.walker_position(descent_view,Vector2(16000,-1300),48.0)
	check(descent_view.has_point(returning),"The distant ridge and giant cannot be seen again during the return")
	check(absf(returning.y-Landscape.walker_anchor(48.0).y)<.01,"Descent creates a different world altitude for the giant")
	var report = {"version":"0.10.63","checks":checks,"failures":failures,"feet_follow_painted_skyline":true,"world_altitude_independent_of_camera":true,"leaves_view_above_ridge":true,"physical_device_tested":false}
	var folder = OS.get_environment("HORDA_VALIDATION_DIR")
	if not folder.is_empty():
		DirAccess.make_dir_recursive_absolute(folder)
		var out = FileAccess.open(folder+"/landscape.json",FileAccess.WRITE)
		out.store_string(JSON.stringify(report,"  "))
	for message in failures: push_error(message)
	print("V163_LANDSCAPE ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
