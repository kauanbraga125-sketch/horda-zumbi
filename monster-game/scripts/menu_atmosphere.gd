class_name HordeMenuAtmosphere
extends RefCounted

const ROOT = "res://assets/art/menu_v102/"
var cover: Texture2D = preload(ROOT+"book_cover.png")
var cemetery: Texture2D = preload(ROOT+"cemetery.png")
var hands: Array[Texture2D] = [preload(ROOT+"hand_open.png"),preload(ROOT+"hand_grasp.png")]

func fit(canvas: Node2D, texture: Texture2D, box: Rect2, tint: Color = Color.WHITE, angle: float = 0.0) -> Rect2:
	var size = texture.get_size()*minf(box.size.x/texture.get_width(),box.size.y/texture.get_height())
	canvas.draw_set_transform(box.get_center(),angle)
	canvas.draw_texture_rect(texture,Rect2(-size*.5,size),false,tint)
	canvas.draw_set_transform(Vector2.ZERO)
	return Rect2(box.get_center()-size*.5,size)

func clear_of_ui(p: Vector2, d: Dictionary, margin: float = 14.0) -> bool:
	for key in ["title","level","wallet","audio","help","play","ritual","nav","record","profile"]:
		if d[key].grow(margin).has_point(p): return false
	return true

func bat(c: Node2D, p: Vector2, scale: float, clock: float, bird: bool = false) -> void:
	var flap = sin(clock*(9.0 if bird else 14.0))
	var color = Color(.105,.065,.18,.65 if bird else .78)
	c.draw_set_transform(p,sin(clock*1.8)*.05,Vector2.ONE*scale)
	if bird:
		c.draw_polyline(PackedVector2Array([Vector2(-14,-8*flap),Vector2(-6,-3),Vector2(0,2),Vector2(7,-3),Vector2(14,-8*flap)]),color,2.2,true)
	else:
		c.draw_colored_polygon(PackedVector2Array([Vector2(-2,0),Vector2(-17,-4-11*flap),Vector2(-6,5)]),color)
		c.draw_colored_polygon(PackedVector2Array([Vector2(2,0),Vector2(17,-4-11*flap),Vector2(6,5)]),color)
		c.draw_circle(Vector2(0,1),2.5,color)
	c.draw_set_transform(Vector2.ZERO)

func rat(c: Node2D, p: Vector2, clock: float, facing: float, scale: float) -> void:
	c.draw_set_transform(p+Vector2(0,abs(sin(clock*15))),0,Vector2(facing*scale,scale))
	var dark = Color("39263e");var tail = PackedVector2Array()
	for j in range(9): tail.append(Vector2(-10-j*2.2,-3+sin(j*.6+clock*9)*1.5))
	c.draw_polyline(tail,Color("80626e"),1.6,true)
	c.draw_set_transform(p,0,Vector2(facing*scale,scale)*Vector2(1,.6));c.draw_circle(Vector2(-1,-7),12,dark)
	c.draw_set_transform(p,0,Vector2(facing*scale,scale))
	c.draw_colored_polygon(PackedVector2Array([Vector2(5,-10),Vector2(17,-5),Vector2(6,-2)]),dark)
	c.draw_circle(Vector2(6,-11),3.5,Color("685064"));c.draw_circle(Vector2(11,-7),.85,Color("d5be8b"))
	for side in [-1,1]: c.draw_line(Vector2(side*6,-2),Vector2(side*6+sin(clock*16+side*PI*.5)*3,2),dark,2.2,true)
	c.draw_set_transform(Vector2.ZERO)

func hand(c: Node2D, at: Vector2, time: float, phase: float) -> void:
	var amount = smoothstep(0.0,1.25,phase)*(1.0-smoothstep(4.5,5.8,phase))
	if amount <= .001: return
	var wave = sin(time*2.6)*.5+.5
	for pose in range(2):
		var texture: Texture2D = hands[pose]
		var height = 69.0*amount;var width = 37.0
		c.draw_texture_rect_region(texture,Rect2(at-Vector2(width*.5-sin(time*1.8)*3*amount,height),Vector2(width,height)),Rect2(0,0,texture.get_width(),texture.get_height()*amount),Color(.67,.74,.76,(1.0-wave if pose==0 else wave)*.85))
	c.draw_set_transform(at,0,Vector2(1,.22));c.draw_circle(Vector2.ZERO,23,Color(.08,.045,.12,.8));c.draw_set_transform(Vector2.ZERO)

func background(g, d: Dictionary) -> void:
	var v: Rect2 = d.view;var t: float = g.ui_time
	for flock in range(2):
		var phase = fposmod(t+flock*12.0,24.0+flock*7.0)
		if phase > 8.0: continue
		for i in range(3):
			var p = v.position+Vector2((phase/8.0*1.25-.12)*v.size.x+i*19,v.size.y*(.24+flock*.15)+sin(t*.8+i)*12+i*5)
			if clear_of_ui(p,d,18): bat(g.paint_target,p,.55+flock*.16,t+i,flock==1)
	for i in range(2):
		var phase = fposmod(t+float(i)*9,19.0+i*7)
		if phase > 5: continue
		var p = v.position+Vector2(v.size.x*((.09 if i==0 else .51)+phase/5.0*.17),v.size.y*(.69 if i==0 else .57))
		if clear_of_ui(p,d,20): rat(g.paint_target,p,t+i,1.0,.68 if i==0 else .48)
	for i in range(2):
		var phase = fposmod(t+float(i)*8,20.0+i*5)-2
		if phase < 0 or phase > 5.8: continue
		var p = v.position+Vector2(v.size.x*(.12 if i==0 else .51),v.size.y*(.77 if i==0 else .73))
		if clear_of_ui(p-Vector2(0,30),d,8): hand(g.paint_target,p,t+i,phase)

func monument(g, d: Dictionary) -> void:
	var p: Vector2 = d.altar;var h: float = d.altar_height
	var w = h*cemetery.get_width()/cemetery.get_height();var c = g.paint_target
	for ring in range(3):
		c.draw_set_transform(p+Vector2(0,h*.3),0,Vector2(1,.16))
		c.draw_arc(Vector2.ZERO,w*(.37+ring*.035),0,TAU,48,Color(.3,1,.82,.08*(.8+.2*sin(g.ui_time*1.4))),4,true);c.draw_set_transform(Vector2.ZERO)
	fit(c,cemetery,Rect2(p-Vector2(w,h)*.5,Vector2(w,h)))
	for i in range(3):
		var a = g.ui_time*.55+i*TAU/3
		g.animated_soul(p+Vector2(cos(a)*w*.43,-h*.04+sin(a)*h*.18),17+sin(a)*2,g.ui_time+i,Color(1,1,1,.62))
	for i in range(7):
		var life = fposmod(g.ui_time*.14+i*.151,1)
		c.draw_circle(p+Vector2(sin(i*8.3+life)*w*.4,h*.25-life*h*.7),1.5,Color(.6,1,.85,sin(life*PI)*.45))
	for i in range(4):
		c.draw_circle(p+Vector2((-.33+i*.22)*w,h*.18),8,Color(1,.57,.13,.06*(.65+.2*sin(g.ui_time*7.2+i*2)+.12*sin(g.ui_time*11+i))))
