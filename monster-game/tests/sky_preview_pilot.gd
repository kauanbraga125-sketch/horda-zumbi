extends RefCounted

const SUPPORTS = ["ember","balloon","cloud","meteor_small","meteor_large"]
var finished_climb = false
var next_press = 0.0
var boosts = 0
var target_height = 12700.0
var tolerance = 50.0
var lookahead = 2.1
var last_support = -1.0
var tapped_since_support = false
var plan_support = true

func observe(events: Array, age: float) -> void:
	for event in events:
		if event.type in ["sky_bounce","sky_meteor"]:
			last_support = age
			tapped_since_support = false

func wants_tap(r) -> bool:
	var s = r.sky
	if not s.active or s.age<.3 or s.age<next_press: return false
	if s.peak>=target_height: finished_climb = true
	if finished_climb or s.charges<=0 or s.cooldown>0 or s.impact_left>0: return false
	# Time a normal tap early enough to descend onto the next free support.
	# This plans inputs from visible props; it never edits physics or pickups.
	if plan_support and last_support>=8.0 and not tapped_since_support and s.velocity<820.0:
		var support: Dictionary = {}
		var support_eta = INF
		for e in s.objects:
			if e.used_at>=0 or e.kind not in ["cloud","balloon","meteor_small","meteor_large"]: continue
			var point = s.object_point(r,e,s.age)
			if point.x<r.ANCHOR+90.0 or point.x>r.view_right: continue
			var rock = e.kind in ["meteor_small","meteor_large"]
			var eta = (point.x-r.ANCHOR)/(r.speed+(45.0 if rock else 0.0))
			if eta>=support_eta: continue
			var height = r.FLOOR-point.y-(0.0 if e.kind=="cloud" or rock else 46.0)
			if rock:
				height -= (124.0 if e.kind=="meteor_small" else 87.0)*eta
				height += 27.0 if e.kind=="meteor_small" else 37.0
			support = {"eta":eta,"height":height}
			support_eta = eta
		if not support.is_empty() and support_eta>.45:
			var eta = support_eta
			var forecast = s.altitude+850.0*eta-.5*s.GRAVITY*eta*eta
			var natural = s.altitude+s.velocity*eta-.5*s.GRAVITY*eta*eta
			if natural<float(support.height)-20.0 and forecast>=float(support.height)-20.0 and forecast<=float(support.height)+55.0 and 850.0-s.GRAVITY*eta< -80.0:
				next_press = s.age+.22;tapped_since_support = true;boosts += 1
				return true
	var best: Dictionary = {}
	var best_eta = INF
	for e in s.objects:
		if e.used_at>=0 or e.kind not in SUPPORTS: continue
		var point = s.object_point(r,e,s.age)
		if point.x<r.view_left or point.x>r.view_right: continue
		var eta = (point.x-r.ANCHOR)/r.speed
		if eta<-.22 or eta>lookahead: continue
		var height = r.FLOOR-point.y-(0.0 if e.kind in ["cloud","meteor_small","meteor_large"] else 50.0)
		if height<s.altitude-180.0 and s.velocity>0: continue
		if eta<best_eta:
			best = {"height":height,"eta":maxf(.08,eta),"kind":e.kind}
			best_eta = eta
	var needed = s.velocity<(-80.0 if s.recovering else 120.0)
	if not best.is_empty():
		var eta = float(best.eta)
		var natural = s.altitude+s.velocity*eta-.5*s.GRAVITY*eta*eta
		var boosted = s.altitude+850.0*eta-.5*s.GRAVITY*eta*eta
		needed = natural<float(best.height)-tolerance and boosted<float(best.height)+tolerance
		if s.velocity< -260.0 and eta>.75: needed = true
	if needed:
		next_press = s.age+.22
		tapped_since_support = true
		boosts += 1
		return true
	return false
