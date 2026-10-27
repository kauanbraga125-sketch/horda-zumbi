extends RefCounted
## Continuous contacts for visible solids. Damage grace never disables separation.

func sweep(start: Vector2,finish: Vector2,old_centre: Vector2,centre: Vector2,radius: float) -> Dictionary:
	var from = start-old_centre;var to = finish-centre;var delta = to-from
	var square = radius*radius;var a = delta.length_squared()
	# The entry side wins even when a fast dash ends inside the solid.
	if a>.001 and from.length_squared()>=square:
		var b = 2*from.dot(delta);var c = from.length_squared()-square
		var discriminant = b*b-4*a*c
		if discriminant>=0:
			var t = (-b-sqrt(discriminant))/(2*a)
			if t>=0 and t<=1:
				var normal = (from+delta*t).normalized()
				return {"point":centre+normal*(radius+.8),"normal":normal}
	if to.length_squared()<square:
		var normal = from.normalized() if from.length_squared()>.001 else -delta.normalized()
		if normal.length_squared()<.1: normal = Vector2.LEFT
		return {"point":centre+normal*(radius+.8),"normal":normal}
	return {}

func gate_parts(e: Dictionary) -> Array[Vector2]:
	var half = float(e.gap)*.5+63.0
	return [Vector2(e.x,e.y-half),Vector2(e.x,e.y+half)]

func push(s,r,e: Dictionary,centre: Vector2,radius: float,cause: String,damage_limit: int = 1000) -> int:
	if s.phase!="flight" or r.dead: return 0
	var shifted = 0;var old = Vector2(e.get("previous_x",e.x),e.get("previous_y",e.y))
	var old_centre = centre+old-Vector2(e.x,e.y)
	var piloting = s.battle.pilot_left>0
	var indices = [r.leader_index()] if piloting else range(r.members.size()-1,-1,-1)
	for i in indices:
		if i<0 or i>=r.members.size(): continue
		var m = r.members[i];var height = s.member_height(r)
		var point = Vector2(s.x+25,s.y-48) if piloting else Vector2(m.x,m.y-height*.5)
		var previous = Vector2(s.get("previous_x")+25,s.get("previous_y")-48) if piloting else Vector2(m.get("space_previous_x",m.x),m.get("space_previous_y",m.y))-Vector2(0,height*.5)
		var reach = radius+(77.0 if piloting else maxf(18,height*.205))
		var result = sweep(previous,point,old_centre,centre,reach)
		if result.is_empty(): continue
		var displacement: Vector2 = result.point-point
		m.x += displacement.x;m.y += displacement.y
		if piloting or i==r.leader_index():
			s.x += displacement.x;s.y += displacement.y
			if not s.path.is_empty(): s.path[-1].x = s.x;s.path[-1].y = s.y
		else: m.space_recoil = Vector2(m.get("space_recoil",Vector2.ZERO))+displacement
		m.space_contact = .22
		shifted += 1
		if s.age-float(m.get("space_impact_at",-10))>.22:
			m.space_impact_at = s.age
			s.visual.impact(result.point-result.normal*maxf(18,height*.2),result.normal,s.battle.shield_charges>0 or piloting)
		if int(e.get("damage_count",0))<damage_limit:
			if s.battle.hurt(s,r,i,cause,result.point,true): e.damage_count = int(e.get("damage_count",0))+1
		if r.dead: break
	return shifted
