extends RefCounted
const Art = preload("res://scripts/sewer_art.gd")
var people: Array[Dictionary] = []
var scene_serial = 0
var next_scene = .7
var collapse_left = 0.0
var collapse_x = 0.0

func reset() -> void:
	people.clear();scene_serial = 0;next_scene = .7;collapse_left = 0;collapse_x = 0

func advance(s,r,dt: float) -> void:
	collapse_left = maxf(0,collapse_left-dt)
	if s.phase!="ride": return
	next_scene -= dt
	if next_scene<=0 and s.left>5:
		scene_serial += 1;next_scene = 7.2
		var start = r.view_right+70
		people.append({"x":start,"age":0.0,"variant":scene_serial%2,"fall":false,"drops":scene_serial%2==0,"taken":false})
		people.append({"x":start-100,"age":.2,"variant":2,"fall":false,"drops":false,"taken":false})
		if scene_serial%2==1: people.append({"x":start+150,"age":.4,"variant":(scene_serial+1)%2,"fall":false,"drops":false,"taken":false})
	for p in people:
		p.age += dt;p.x -= s.scroll_speed(r)*.29*dt
		if p.drops and not p.fall and p.x<r.view_right-280:
			p.fall = true;p.fall_age = 0.0;collapse_x = p.x;collapse_left = 1.1
		if p.fall:
			p.fall_age += dt
			if p.fall_age>=.72 and not p.taken:
				p.taken = true;s.add_object("rescue",p.x+45,s.WATER-40,{"variant":p.variant,"from_catwalk":true});s.splash(Vector2(p.x+45,s.WATER),false)
	people = people.filter(func(p):return p.x>r.view_left-100 and not p.taken)

func paint(g,s,catwalk_y: float) -> void:
	var c = g.paint_target
	for p in people:
		var foot = Vector2(p.x,catwalk_y)
		if p.fall:
			var t = float(p.fall_age)/.72
			foot += Vector2(t*45,t*t*(s.WATER-catwalk_y-40))
			Art.survivor(c,int(p.variant),foot,lerpf(75,104,t),p.age)
		else:
			Art.runner(c,int(p.variant),foot,94 if p.variant==2 else 87,p.age,Color(.92,.94,.94,.90))
		if p.variant==1:
			c.draw_circle(foot-Vector2(-5,58),17,Color(1,.69,.22,.055))
	if collapse_left>0:
		var age = 1.1-collapse_left
		for i in range(5):
			var p = Vector2(collapse_x+(i-2)*18-age*150,catwalk_y+age*age*(190+i*9))
			c.draw_set_transform(p,age*(i-2)*2)
			c.draw_texture_rect_region(g.gameplay_ui.ground_texture.atlas,Rect2(-12,-7,24,14),Rect2(40+i*30,94,80,40),Color(.65,.72,.76,1-age/1.1))
		c.draw_set_transform(Vector2.ZERO)
