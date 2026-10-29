extends RefCounted
const Art = preload("res://scripts/sewer_art.gd")
var people: Array[Dictionary] = []
var scene_serial = 0
var next_scene = .45
var collapse_left = 0.0
var collapse_x = 0.0
func reset() -> void:
	people.clear();scene_serial = 0;next_scene = .45;collapse_left = 0;collapse_x = 0
func advance(s,r,dt: float) -> void:
	collapse_left = maxf(0,collapse_left-dt)
	if s.phase!="ride": return
	next_scene -= dt
	if next_scene<=0 and s.left>5:
		scene_serial += 1;next_scene = 5.6
		var start = r.view_right+65
		people.append({"x":start,"age":0.0,"variant":scene_serial%2,"fall":false,"drops":scene_serial%2==0,"taken":false})
		people.append({"x":start-145,"age":.22,"variant":2,"fall":false,"drops":false,"taken":false})
		if scene_serial%2==1: people.append({"x":start+145,"age":.37,"variant":(scene_serial+1)%2,"fall":false,"drops":false,"taken":false})
	for p in people:
		p.age += dt;p.x += (-s.scroll_speed(r)*.45+(145 if p.variant==2 else 128))*dt
		if p.drops and not p.fall and p.x<r.view_right-330: p.fall = true;p.fall_age = 0.0;collapse_x = p.x;collapse_left = 1.1
		if p.fall:
			p.fall_age += dt
			if p.fall_age>=.80 and not p.taken:
				p.taken = true;s.add_object("rescue",p.x+52,s.WATER-35,{"variant":p.variant,"from_catwalk":true});s.splash(Vector2(p.x+52,s.WATER),false)
	people = people.filter(func(p):return p.x>r.view_left-120 and not p.taken)
func paint(g,s,catwalk_y: float) -> void:
	var c = g.paint_target
	for p in people:
		var foot = Vector2(p.x,catwalk_y)
		if p.fall:
			var t = clampf(float(p.fall_age)/.80,0,1);foot += Vector2(t*52,t*t*(s.WATER-catwalk_y-35))
			Art.runner_new(c,int(p.variant),foot,110,p.age,Color.WHITE,t*.70)
		elif p.variant==2: g.actor.paint(c,0,foot,108,fposmod(p.age*1.72,1),"run",p.age,0,Color(.84,.94,.89),false,1,false)
		elif p.variant==0: g.art.woman.paint(c,{"woman_clip":"run","woman_time":p.age,"woman_reverse":false},foot,98,Color(.96,.98,1))
		else: g.art.civil.paint(c,{"civil_clip":"corrida","civil_time":p.age,"civil_flip":false,"state":"normal"},foot,103,Color(.96,.98,1))
		if p.variant==1: c.draw_circle(foot-Vector2(-10,85),22,Color(1,.69,.22,.05))
	if collapse_left>0:
		var age = 1.1-collapse_left
		for i in range(7):
			var at = Vector2(collapse_x+(i-3)*16-age*115,catwalk_y+age*age*(190+i*9));c.draw_set_transform(at,age*(i-3)*2)
			c.draw_texture_rect_region(g.gameplay_ui.ground_texture.atlas,Rect2(-12,-7,24,14),Rect2(40+i*30,94,80,40),Color(.65,.72,.76,1-age/1.1))
		c.draw_set_transform(Vector2.ZERO)
