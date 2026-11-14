extends RefCounted
## Presentation follows the same rescued member; it never creates a replacement.
const Art = preload("res://scripts/bird_art.gd")
const VIOLET = Color("c994ff")
const MINT = Color("a4ffdf")
var age = -1.0
var member_id = -1
var origin = Vector2.ZERO
var duration = 1.25

func reset() -> void:age = -1;member_id = -1;origin = Vector2.ZERO;duration = 1.25

static func last_member(r,m: Dictionary) -> bool:
	if r.dead:return false
	var belongs = false
	# Count live companions directly: the cached count can lag a simultaneous fall.
	for other in r.members:
		if is_same(other,m):belongs = true
		elif not bool(other.get("falling",false)):return false
	return belongs

func begin(m: Dictionary,from: Vector2,protection: float) -> void:
	age = 0;member_id = int(m.id);origin = from;duration = maxf(1.25,protection)

func advance(r,dt: float) -> void:
	if dt<=0 or r.dead or age<0:return
	age += dt
	if age>=duration:age = -1

func portal(c,point: Vector2,opening: float,opacity: float,time: float) -> void:
	if opening<=.001 or opacity<=.001:return
	c.draw_set_transform(point,0,Vector2(.72,1.06)*opening)
	c.draw_circle(Vector2.ZERO,62,Color(.31,.08,.52,.13*opacity))
	c.draw_arc(Vector2.ZERO,66,0,TAU,40,Color(VIOLET,.15*opacity),10,true)
	c.draw_arc(Vector2.ZERO,63,time*2,time*2+TAU*.84,32,Color(VIOLET,.85*opacity),3,true)
	c.draw_arc(Vector2.ZERO,57,-time*3,-time*3+TAU*.72,28,Color(MINT,.75*opacity),1.8,true)
	for i in range(7):
		var a = time*2.3+i*TAU/7;var p = Vector2.from_angle(a)*63
		c.draw_line(p-Vector2.from_angle(a)*4,p+Vector2.from_angle(a)*4,Color(1,.91,1,.8*opacity),1.6,true)
	c.draw_set_transform(Vector2.ZERO)

func paint(g,bird) -> void:
	var c = g.paint_target;var r = g.runner
	if age<0:Art.paint(c,"agourinho",bird.point,68,bird.clock);return
	var m = r.member_by_id(member_id)
	if m.is_empty():Art.paint(c,"agourinho",bird.point,68,bird.clock);return
	var foot = Vector2(m.x,m.y)
	if not r.sky.active and not r.space.active and not r.sewer.active:
		for i in range(r.members.size()):
			if int(r.members[i].id)==member_id:foot = Vector2(r.member_x(i),m.y-r.member_depth(i));break
	var center = foot-Vector2(0,54)
	var opening = smoothstep(0,.18,age)*(1-smoothstep(.62,1.1,age))
	var opacity = 1-smoothstep(duration-.22,duration,age)
	portal(c,center,opening,opacity,age)
	var start = origin-Vector2(0,54)
	start.x = clampf(start.x,g.scenery.view_left+65,g.scenery.view_right-65)
	start.y = clampf(start.y,g.scenery.view_top+85,g.scenery.view_bottom-85)
	if start.distance_to(center)>110 and age<.7:
		portal(c,start,smoothstep(0,.12,age)*(1-smoothstep(.3,.7,age))*.72,.65,age)
		var line = PackedVector2Array()
		for i in range(13):
			var t = i/12.0;line.append(start.lerp(center,t)+Vector2(0,-sin(t*PI)*50))
		c.draw_polyline(line,Color(VIOLET,.36*(1-age/.7)),2.5,true)
	var cast = smoothstep(0,.2,age)*(1-smoothstep(.65,1.15,age))
	var flight = bird.point.lerp(foot+Vector2(-103,-132),cast*.6)+Vector2(0,-sin(age*5)*5*cast)
	Art.paint(c,"agourinho",flight,68+24*cast,bird.clock,"ability" if cast>.25 else "")
	# A fixed set of feather motes, with no allocated particle nodes or new textures.
	for i in range(10):
		var a = age*3.4+i*TAU/10;var radius = 54+age*13
		var p = center+Vector2(cos(a)*radius*.85,sin(a)*radius)
		var size = (4+sin(i*1.7)*1.3)*opening
		if size<=.1:continue
		c.draw_set_transform(p,a+.45)
		c.draw_colored_polygon(PackedVector2Array([Vector2(0,-size*2),Vector2(size,-size*.3),Vector2(size*.55,size),Vector2(0,size*1.7),Vector2(-size*.45,size*.4),Vector2(-size,-size*.5)]),Color(MINT if i%3==0 else VIOLET,.7*opacity))
		c.draw_line(Vector2(0,-size*1.5),Vector2(0,size*1.4),Color(1,.92,1,.6*opacity),.8,true)
	c.draw_set_transform(Vector2.ZERO)
	if age>.55 and r.hit_grace>0:
		c.draw_set_transform(center,0,Vector2(.73,1.02))
		c.draw_arc(Vector2.ZERO,60,0,TAU,36,Color(VIOLET,.36*opacity),2,true)
		c.draw_set_transform(Vector2.ZERO)
