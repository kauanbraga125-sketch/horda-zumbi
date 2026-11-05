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
	if s.phase not in ["ride","exit"]: return
	var exiting = s.phase=="exit"
	var gallery_scroll: float = r.world_px * s.GALLERY_PARALLAX
	var gallery_step: float = (s.exit_speed if exiting else r.speed) * s.GALLERY_PARALLAX * dt
	collapse_x -= gallery_step
	next_scene -= dt
	if not exiting and next_scene<=0 and s.left>5:
		scene_serial += 1;next_scene = 5.6
		var start = r.view_left-56.0
		people.append({"x":start,"age":0.0,"variant":(scene_serial+1)%2,"fall":false,"drops":scene_serial%2==0,"drop_x":start+gallery_scroll+585.0,"taken":false})
		people.append({"x":start-190.0,"age":.22,"variant":2,"fall":false,"drops":false,"taken":false})
		if scene_serial%2==1: people.append({"x":start-95.0,"age":.37,"variant":scene_serial%2,"fall":false,"drops":false,"taken":false})
	for p in people:
		p.age += dt
		p.x += (175.0 if p.variant==2 else 166.0)*dt-gallery_step
		if not exiting and p.drops and not p.fall and p.x+gallery_scroll>=float(p.get("drop_x",p.x+gallery_scroll)):
			p.fall = true;p.fall_age = 0.0;collapse_x = p.x;collapse_left = 1.1
		if p.fall:
			p.fall_age += dt
			if p.fall_age>=.80 and not p.taken and not exiting:
				p.taken = true
				var rescue: Dictionary = s.add_object("rescue",p.x+52,s.WATER-35,{"variant":p.variant,"from_catwalk":true})
				s.splash(s.object_surface(rescue),false)
	people = people.filter(func(p):return p.x<r.view_right+220 and not p.taken)
func paint(g,s,catwalk_y: float,opacity: float = 1.0) -> void:
	var c = g.paint_target
	for p in people:
		var foot = Vector2(p.x,catwalk_y)
		if p.fall:
			var t = clampf(float(p.fall_age)/.80,0,1)
			var surface: Vector2 = s.object_surface({"x":p.x+52.0})
			foot += Vector2(t*52,t*t*(surface.y-catwalk_y-15.0))
			Art.runner_new(c,int(p.variant),foot,110,p.age,Color(1,1,1,opacity),t*.70)
		elif p.variant==2: g.actor.paint(c,0,foot,108,fposmod(p.age*1.72,1),"run",p.age,0,Color(.84,.94,.89,opacity),false,1,false)
		elif p.variant==0: g.art.woman.paint(c,{"woman_clip":"run","woman_time":p.age,"woman_reverse":false},foot,98,Color(.96,.98,1,opacity))
		else: g.art.civil.paint(c,{"civil_clip":"corrida","civil_time":p.age,"civil_flip":false,"state":"normal"},foot,103,Color(.96,.98,1,opacity))
		if p.variant==1: c.draw_circle(foot-Vector2(-10,85),22,Color(1,.69,.22,.05*opacity))
	if collapse_left>0:
		var age = 1.1-collapse_left
		for i in range(7):
			var at = Vector2(collapse_x+(i-3)*16-age*115,catwalk_y+age*age*(190+i*9));c.draw_set_transform(at,age*(i-3)*2)
			c.draw_texture_rect_region(g.gameplay_ui.ground_texture.atlas,Rect2(-12,-7,24,14),Rect2(40+i*30,94,80,40),Color(.65,.72,.76,(1-age/1.1)*opacity))
		c.draw_set_transform(Vector2.ZERO)
