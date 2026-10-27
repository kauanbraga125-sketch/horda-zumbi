extends RefCounted
## Small playable scenes give NPCs motivations, with earned rescues and real risk.
func advance(s,r,dt: float) -> void:
	if s.phase!="flight" or r.dead: return
	for e in s.objects.duplicate():
		if e.taken: continue
		if e.kind=="parasite" and e.has("prey"):
			var prey: Dictionary = e.prey
			if prey.taken or prey.state=="capture":
				e.erase("prey");e.speed = 1.0;continue
			prey.panic = true;e.state = "attack"
			e.base_y = move_toward(float(e.base_y),float(prey.y),dt*48)
			if Vector2(e.x,e.y).distance_to(Vector2(prey.x,prey.y))<38:
				prey.taken = true;e.snatched_until = float(e.age)+1.4;e.erase("prey");e.speed = 1.15
				s.visual.notify("O PARASITA PEGOU O ASTRONAUTA!",2,1.5)
		elif e.kind=="cargo" and bool(e.get("distress",false)):
			e.base_y += sin(float(e.age)*7)*dt*8
			if e.age>2.3 and not bool(e.get("evacuated",false)):
				e.evacuated = true;e.released_crew = 1
				s.add_object("pod",e.x+100,clampf(e.y-100,260,530),{"radius":35.0,"speed":.74,"grace":.5})
				s.visual.notify("CARGUEIRO AVARIADO • CÁPSULA EJETADA",2,2.0)
			if e.age>4.7 and not bool(e.get("critical",false)):
				e.critical = true;s.visual.notify("CASCO CRÍTICO • AFASTE A HORDA",3,1.7)
			if e.age>6.1:
				var at = Vector2(e.x,e.y)
				var index = s.battle.nearest_member(r,at,135)
				if index>=0: s.battle.hurt(s,r,index,"space_cargo",at)
				s.battle.destroy_ship(s,r,e)

func ship_details(g,s,e: Dictionary,size: float,alpha: float) -> void:
	if not bool(e.get("distress",false)): return
	var c = g.paint_target;var p = Vector2(e.x,e.y)
	for i in range(5):
		var t = fposmod(float(e.age)*1.7+i*.21,1)
		var point = p+Vector2(size*.27+t*37,-15+t*t*42)
		c.draw_line(point,point+Vector2(7,-3),Color(1,.57,.18,(1-t)*alpha*.8),1.5,true)
	if bool(e.get("critical",false)):
		c.draw_arc(p,110,-s.age*3,-s.age*3+TAU*.8,32,Color(1,.48,.3,(.3+sin(s.age*15)*.12)*alpha),2,true)
