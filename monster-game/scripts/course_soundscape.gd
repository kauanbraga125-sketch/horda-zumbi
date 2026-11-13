extends RefCounted

const Pop = preload("res://scripts/sky_pop_encounters.gd")
const Regions = preload("res://scripts/sky_region_scenery.gd")
const Landscape = preload("res://scripts/sky_landscape.gd")
const Deep = preload("res://scripts/sky_deep_landscape.gd")
var seen: Dictionary = {}
var cue_times: Dictionary = {}
var journey = -1.0
var last_age = -1.0
var sea_age = -1.0

func reset() -> void:
	seen.clear();cue_times.clear();journey = -1.0;last_age = -1.0;sea_age = -1.0

func gate(key: String, time: float, period: float, at: float, window: float = .30) -> bool:
	var cycle = floori(time/period)
	var target = cycle*period+at
	var previous = float(cue_times.get(key,time-.05));cue_times[key] = time
	var crossed = previous<target and time>=target
	var in_window = time>=target and time<=target+window
	if not (crossed or in_window) or int(seen.get(key,-100000))==cycle:return false
	seen[key] = cycle
	return true

static func visible(point: Vector2, view: Rect2, radius: Vector2) -> bool:
	return Rect2(point-radius,radius*2.0).intersects(view)

static func spatial(point: Vector2, view: Rect2) -> Vector2:
	var delta = point-view.get_center()
	return Vector2(clampf(delta.x/maxf(1.0,view.size.x*.5),-.75,.75),clampf(absf(delta.y)/maxf(1.0,view.size.y)*7.0,0,10))

func once_at(key: String, token: float, phase: float, at: float) -> bool:
	if phase<at or phase>at+.24 or float(seen.get(key,-100000.0))==token:return false
	seen[key] = token
	return true

func cue(sound, key: String, point: Vector2, view: Rect2, db: float = -14.0, pitch: float = 1.0) -> void:
	sound.play_distant_at(key,db,point,view,pitch)

func advance(sound, run, view: Rect2, camera: Vector2) -> void:
	if run.sewer.active:
		if run.sewer.age<sea_age:seen.clear()
		sea_age = run.sewer.age
		if run.sewer.pressure>.35 and run.sewer.wave_strength()>.4 and gate("flood",sea_age,9.0,1.0):sound.play_distant("flood",-17.0+run.sewer.pressure*4.0,-.65)
		return
	sea_age = -1.0
	if not run.sky.active:return
	var s = run.sky
	if journey!=s.start_world or s.age<last_age:
		seen.clear();cue_times.clear();journey = s.start_world
	last_age = s.age
	var age: float = s.age
	var p = Landscape.walker_position(view,camera,age)
	if visible(p,view,Vector2(210,290)) and age>2.6 and gate("step",age,1.6,0.0):cue(sound,"step",p,view,-18)
	p = Regions.position("elder",view,camera,age)
	if visible(p,view,Vector2(250,280)) and gate("elder",age,9.0,1.0):cue(sound,"elder",p,view,-17)
	p = Regions.position("dragon",view,camera,age)
	if visible(p,view,Vector2(160,140)) and gate("dragon",age,8.0,2.0):cue(sound,"dragon",p,view,-17)
	p = Regions.position("witch",view,camera,age)
	if visible(p,view,Vector2(120,100)) and gate("witch",age,9.0,4.0):cue(sound,"witch",p,view,-18)
	if sound.score.stage==1 and sound.score.mode=="sky" and gate("thunder",age,11.0,3.0):sound.play_distant("thunder",-20,.25)
	p = Pop.position("worm",view,camera)
	if visible(p-Vector2(0,180),view,Vector2(350,280)):
		if gate("worm_lunge",age-4.5,12.0,3.4):cue(sound,"worm_lunge",p,view,-15)
		if gate("worm_burp",age-4.5,12.0,4.4):cue(sound,"worm_burp",p,view,-17)
	p = Pop.position("kaiju",view,camera)
	if visible(p-Vector2(0,160),view,Vector2(430,310)):
		if gate("ape",age-9.0,13.0,.8):cue(sound,"ape",p+Vector2(-150,-150),view,-15)
		if gate("impact",age-9.0,13.0,1.5):cue(sound,"impact",p-Vector2(0,150),view,-18)
		if gate("reptile",age-9.0,13.0,2.6):cue(sound,"reptile",p+Vector2(150,-150),view,-16)
		if gate("breath",age-9.0,13.0,3.6):cue(sound,"breath",p+Vector2(100,-150),view,-17)
	p = Pop.position("orbit",view,camera)
	if visible(p-Vector2(0,140),view,Vector2(400,280)):
		if gate("cloak",age-20.0,11.5,.1):cue(sound,"cloak",p+Vector2(139,-100),view,-18)
		if gate("alien",age-20.0,11.5,1.6):cue(sound,"alien",p+Vector2(-100,-150),view,-16)
		if gate("plasma",age-20.0,11.5,4.75):sound.play_energy_fallback(-21,spatial(p,view).x)
	p = Pop.position("time_car",view,camera)
	if visible(p,view,Vector2(250,100)) and gate("time_car",age-27.0,17.0,1.3,5.2):
		sound.play_distant_at("time_car",-18,p,view,1.0,maxf(0.0,Pop.phase("time_car",age)-1.3))
	p = Deep.devourer_position(view,camera)
	if s.hauntings.devour_seen and visible(p,view,Vector2(460,330)) and gate("planet",s.hauntings.devour_clock,12.0,2.49):cue(sound,"planet",p,view,-15)
	var duel_age: float = s.hauntings.clock-s.hauntings.scene_at
	p = Deep.duel_position(view,camera)
	if s.hauntings.scene==1 and duel_age<6.4 and visible(p,view,Vector2(450,250)):
		if once_at("duel_a",s.hauntings.scene_at,duel_age,2.35):cue(sound,"impact",p,view,-21)
		if once_at("duel_b",s.hauntings.scene_at,duel_age,4.25):cue(sound,"impact",p,view,-21,.94)
	# Keys are fixed cue names; memory does not grow with travelled distance.
