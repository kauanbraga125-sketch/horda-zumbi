extends RefCounted
## Depth, travelling cues and exhaust use the same world positions as gameplay.

func orbit(c,texture: Texture2D,destination: Rect2,view_top: float,alpha: float) -> void:
	if destination.position.y<=view_top:
		c.draw_texture_rect(texture,destination,false,Color(1,1,1,alpha));return
	# Fade only the newly exposed edge; moving the opaque image must not reveal a hard seam.
	var height = minf(180,destination.size.y*.3);var ratio = height/destination.size.y
	var left = destination.position;var right = left+Vector2(destination.size.x,0)
	c.draw_polygon(PackedVector2Array([left,right,right+Vector2(0,height),left+Vector2(0,height)]),PackedColorArray([Color(1,1,1,0),Color(1,1,1,0),Color(1,1,1,alpha),Color(1,1,1,alpha)]),PackedVector2Array([Vector2.ZERO,Vector2(1,0),Vector2(1,ratio),Vector2(0,ratio)]),texture)
	c.draw_texture_rect_region(texture,Rect2(left+Vector2(0,height),destination.size-Vector2(0,height)),Rect2(0,texture.get_height()*ratio,texture.get_width(),texture.get_height()*(1-ratio)),Color(1,1,1,alpha))

func stars(g,s,rect: Rect2) -> void:
	var c = g.paint_target;var rising = s.phase in ["ascent","boost"]
	var speed = s.climb_speed
	for i in range(62):
		var depth = .18+(i%5)*.18
		var point = Vector2(rect.position.x+fposmod(i*173.37-g.runner.world_px*depth*.13,rect.size.x),rect.position.y+fposmod(i*93.71+s.sky_scroll*depth,rect.size.y))
		var alpha = .24+.15*sin(s.age*(.7+depth)+i)
		var color = Color(.67,.88,1,alpha)
		c.draw_circle(point,.8+depth*1.2,color)
		if rising and speed>180:
			var length = minf(125,speed*.055)*depth
			c.draw_line(point-Vector2(0,length),point,Color(color,alpha*.75),1+depth*.5,true)
		elif i%9==0:
			c.draw_line(point,point+Vector2(12+depth*18,-2),Color(color,.08),1,true)
	# A few distant ships have their own flight path. They never enter the interaction plane.
	for i in range(3):
		var depth = .16+i*.055
		var x = rect.end.x+180-fposmod(s.age*(24+i*13)+i*481,rect.size.x+360)
		var y = rect.position.y+fposmod(150+i*235+s.sky_scroll*depth,rect.size.y)
		var point = Vector2(x,y+sin(s.age*.6+i)*14)
		var size = 78.0+i*13
		var frame = [2,8,6][i]
		g.runner.space.battle.art.sprite(c,"fleet",frame,point,size,sin(s.age*.3+i)*.035,Color(.44,.45,.66,.30))
		var tail = point-Vector2(size*.35,-4)
		c.draw_line(tail-Vector2(18+sin(s.age*9+i)*4,0),tail,Color(.4,.65,1,.12),3,true)
	# Small drifting rocks provide depth without resembling foreground threats.
	for i in range(6):
		var depth = .22+(i%3)*.09
		var point = Vector2(rect.position.x+fposmod(i*297.7-s.age*(30+i*4),rect.size.x),rect.position.y+fposmod(i*189.3+s.sky_scroll*depth,rect.size.y))
		s.sprite(c,"props",4+i%3,point,18+i%3*8,s.age*.06+i,Color(.48,.48,.64,.24))

func exhaust(g,s,e: Dictionary,size: float) -> void:
	var p = Vector2(e.x,e.y);var c = g.paint_target
	var pulse = .8+sin(float(e.age)*23+float(e.seed))*.18
	var tail = p+Vector2(-size*.37,4)
	if e.kind in ["fighter","tour_bus","cargo"]:
		for i in range(3):
			var offset = Vector2(-i*9*pulse,0)
			c.draw_circle(tail+offset,7.5-i*1.7,Color(.25,.65,1,(.20-i*.05)*pulse))
	elif e.kind=="saucer":
		for i in range(3):
			var offset = Vector2(sin(s.age*2.7+i*TAU/3)*27,cos(s.age*2.7+i*TAU/3)*6)
			c.draw_circle(p+Vector2(0,size*.22)+offset,2,Color(.45,1,.3,.5))

func meteor(g,point: Vector2,age: float,alpha: float) -> void:
	var c = g.paint_target
	for i in range(6,0,-1):
		var t = float(i)/6
		var at = point+Vector2(16+i*9,-i*2+sin(age*9+i)*3)
		c.draw_circle(at,(1-t)*17+3,Color(1,.35+t*.25,.1,(1-t)*.18*alpha))

func rise_wake(g,s) -> void:
	if s.phase!="boost" and s.phase!="ascent": return
	var strength = smoothstep(140,850,s.climb_speed)
	if strength<=0: return
	var c = g.paint_target
	for i in range(mini(7,g.runner.members.size())):
		var m = g.runner.members[i];var point = Vector2(m.x-18,m.y-22)
		var age = fposmod(s.age*3.5+i*.17,1)
		var end = point+Vector2(-12,48+age*48)
		c.draw_line(point,end,Color(.5,.9,1,(1-age)*.20*strength),3*(1-age)+1,true)
