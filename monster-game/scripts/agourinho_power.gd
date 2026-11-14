extends RefCounted
## The horde really dies; a single creature returns after the invocation.
const Art = preload("res://scripts/bird_art.gd")
const VIOLET = Color("c994ff")
const MINT = Color("a4ffdf")
const RETURN_AT = 3.35
const DURATION = 3.90
var phase = "idle"
var age = -1.0
var member_id = -1
var saved: Dictionary = {}
var kind = 0
var wear: Array = []
var origin = Vector2.ZERO
var foot = Vector2.ZERO
var home = Vector2.ZERO
var level = 1
var mode = "street"
var restored = false
var cues = 0

func reset() -> void:
	phase = "idle";age = -1;member_id = -1;saved = {};wear = [];origin = Vector2.ZERO
	foot = Vector2.ZERO;home = Vector2.ZERO;level = 1;mode = "street";restored = false;cues = 0

static func last_member(r,m: Dictionary) -> bool:
	if r.dead:return false
	var belongs = false
	for other in r.members:
		if is_same(other,m):belongs = true
		elif not bool(other.get("falling",false)):return false
	return belongs

func begin(bird,r,m: Dictionary) -> void:
	phase = "ritual";age = 0;member_id = int(m.id);level = bird.level;restored = false;cues = 0
	kind = int(m.get("death_kind",m.kind)) if m.falling else r.perk_kind if r.perk_left>0 else int(m.kind)
	wear = r.cosmetics_for(m,kind).duplicate();saved = m.duplicate(true)
	origin = Vector2(m.x,m.y);home = bird.point
	mode = "space" if r.space.active else "sewer" if r.sewer.active else "sky" if r.sky.active else "street"
	foot = origin
	if mode=="street":
		var right = maxf(r.ANCHOR+80,r.view_right-120)
		foot.x = r.ANCHOR
		for offset in range(0,ceili(right-r.ANCHOR)+1,28):
			var x = r.ANCHOR+offset
			if r.has_floor(x-30) and r.has_floor(x+30):foot.x = x;break
		foot.y = r.ground_y(foot.x)
	elif mode=="space":foot = Vector2(r.space.x,r.space.y)
	r.events.append({"type":"agourinho_begin","x":foot.x,"y":foot.y-65,"member_id":member_id})

func restore(r) -> void:
	if restored or saved.is_empty() or r.dead:return
	var m = saved.duplicate(true)
	m.falling = false;m.vy = 0;m.hurt_left = 0;m.push_left = 0;m.attack_left = 0;m.mask_flip_left = 0
	m.jump_queue.clear();m.jump_delay = -1;m.jump_at = -1;m.coyote = 0;m.air_jumps = 0;m.hold_open = false
	m.x = foot.x;m.y = foot.y;m.roof_id = -1;m.formation_rank = 0;m.glide_left = 1.2
	m.reform_hold_until = r.elapsed+1.2;m.agourinho_hidden = true;m.agourinho_protection = true
	r.members.append(m);r.cached_active = -1
	r.jump_buffer_until = -1;r.wave_holds.clear();r.wave_durations.clear();r.wave_started.clear()
	for e in r.entities:
		if e.get("contacts") is Dictionary:e.contacts.erase(member_id)
	if mode=="sewer":
		r.sewer.assign_boats(r);r.sewer._update_members(r,0);foot = Vector2(m.x,m.y)
	elif mode=="space":
		r.space._update_members(r,0);foot = Vector2(m.x,m.y)
	r.hit_grace = 1.0+(clampi(level,1,3)-1)*.5
	restored = true;saved = {}
	r.events.append({"type":"bird_rescue","bird":"agourinho","member_id":member_id,"last_chance":true,"x":foot.x,"y":foot.y-55})

func advance(r,dt: float) -> void:
	if dt<=0 or r.dead:return
	if phase=="shield":
		if r.hit_grace<=0:
			var m = r.member_by_id(member_id)
			if not m.is_empty():m.agourinho_protection = false
			phase = "spent"
		return
	if phase!="ritual":return
	if not restored:
		for i in range(r.members.size()-1,-1,-1):r.remove_member(i,"fall")
	age += dt
	if cues<1 and age>=.65:
		cues = 1;r.events.append({"type":"agourinho_gather","x":foot.x,"y":foot.y-90})
	if cues<2 and age>=1.55:
		cues = 2;r.events.append({"type":"agourinho_portal","x":foot.x,"y":foot.y-65})
	if not restored and age>=RETURN_AT:restore(r)
	if age>=DURATION:
		var m = r.member_by_id(member_id)
		if not m.is_empty():m.agourinho_hidden = false
		phase = "shield";r.events.append({"type":"agourinho_end"})

func sequence() -> Dictionary:
	var frames = [0,1,2,1];var t = age*9.0
	if age>=.65 and age<1.55:frames = [3,4,5,4];t = (age-.65)*8.5
	elif age>=1.55 and age<3.35:frames = [4,5,6,5];t = (age-1.55)*9.5
	elif age>=3.35:frames = [6,1,2,7];t = (age-3.35)*6.0
	var i = floori(t)
	return {"a":frames[posmod(i,frames.size())],"b":frames[posmod(i+1,frames.size())],"mix":smoothstep(.58,1,fposmod(t,1))}

func flight() -> Dictionary:
	var focus = foot+Vector2(-100,-174);var arrive = smoothstep(0,.85,age)
	var p = home.lerp(focus,arrive)
	p += Vector2(sin(age*5.8)*19,sin(age*8.3)*7-cos(age*3.7)*8)*arrive
	if age>1.55:p += Vector2(sin((age-1.55)*3.6)*18,-sin((age-1.55)*2.4)*16)
	var leaving = smoothstep(3.42,DURATION,age)
	p = p.lerp(home,leaving)
	return {"point":p,"angle":sin(age*5.8)*.12+sin(age*2.2)*.07,"height":lerpf(84,132,smoothstep(0,.6,age))*(1-leaving*.28),"stretch":Vector2(1+sin(age*11)*.035,1-sin(age*11)*.025)}

func paint_bird(c) -> Vector2:
	var pose = flight();var f = sequence()
	c.draw_set_transform(pose.point,pose.angle,pose.stretch)
	for entry in [[f.a,1-f.mix],[f.b,f.mix]]:
		if entry[1]<=.001:continue
		var i = int(entry[0]);var h = float(pose.height)
		c.draw_texture_rect_region(Art.ritual_texture(),Rect2(-h*.5,-h*.5,h,h),Rect2(i%4*256,int(i/4)*256,256,256),Color(1,1,1,entry[1]))
	c.draw_set_transform(Vector2.ZERO)
	return pose.point+((Vector2(172,104)/256-Vector2.ONE*.5)*float(pose.height)*Vector2(pose.stretch)).rotated(pose.angle)

func paint(g,bird) -> void:
	var c = g.paint_target;var r = g.runner
	if phase!="ritual":
		Art.paint(c,"agourinho",bird.point,68,bird.clock)
		if phase=="shield" and r.hit_grace>0:
			var m = r.member_by_id(member_id)
			if not m.is_empty():
				var center = Vector2(m.x,m.y)-Vector2(0,56)
				var opacity = minf(.35,r.hit_grace*.4)
				c.draw_set_transform(center,0,Vector2(.72,1))
				c.draw_arc(Vector2.ZERO,65,0,TAU,40,Color(MINT,opacity),3,true)
				c.draw_set_transform(Vector2.ZERO)
		return
	var center = foot-Vector2(0,108)
	var open = smoothstep(1.25,2.05,age)*(1-smoothstep(3.72,DURATION,age))
	var s = 248.0*open;var opacity = smoothstep(1.25,1.6,age)
	var portal_angle = sin(age*.9)*.035+age*.12
	if open>.015:
		c.draw_set_transform(center,0,Vector2(.81,1.02))
		c.draw_circle(Vector2.ZERO,s*.4,Color(.41,.12,.75,.12*opacity))
		c.draw_set_transform(center,portal_angle,Vector2(.81,1.02))
		c.draw_texture_rect(Art.portal_texture(),Rect2(-s*.5,-s*.5,s,s),false,Color(1,1,1,opacity))
		c.draw_set_transform(Vector2.ZERO)
	var eye = paint_bird(c)
	if age>.62 and age<3.42:
		var channel = smoothstep(.62,1,age)*(1-smoothstep(3.1,3.42,age));var points = PackedVector2Array()
		for i in range(17):
			var t = i/16.0;points.append(eye.lerp(center,t)+Vector2(sin(t*PI)*sin(age*9+t*8)*8,-sin(t*PI)*24))
		c.draw_polyline(points,Color(VIOLET,.16*channel),7,true)
		c.draw_polyline(points,Color(MINT,.65*channel),1.7,true)
		c.draw_circle(eye,4+sin(age*14),Color(MINT,.66*channel))
	for i in range(14):
		var t = fposmod(age*.75+i*.137,1);var a = age*1.4+i*TAU/14
		var radius = lerpf(108,32,t);var p = center+Vector2(cos(a)*radius*.85,sin(a)*radius*.7)
		var alpha = sin(t*PI)*smoothstep(.5,1.2,age)*(1-smoothstep(3.55,DURATION,age))
		c.draw_line(p,p+Vector2(cos(a+.6),sin(a+.6))*7,Color(MINT if i%3==0 else VIOLET,alpha*.65),1.8,true)
		c.draw_circle(p,1.5,Color(1,.94,1,alpha*.8))
	if restored:
		var p = smoothstep(RETURN_AT,DURATION-.06,age);var h = lerpf(16,112,p)
		var body_center = center.lerp(foot-Vector2(0,56),p)
		var render_foot = body_center+Vector2(-10*(1-p),h*.5)
		var tint = Color(1,1,1,smoothstep(RETURN_AT,RETURN_AT+.15,age))
		if mode=="space":g.actor.paint_space(c,kind,render_foot,h,age,"return",0,wear,tint)
		elif mode=="sewer":g.actor.paint_rider(c,kind,render_foot,h,age,0,wear,tint,0,"ride",0)
		else:g.actor.paint(c,kind,render_foot,h,age*.4,"idle",age,0,tint,false,1,true,-1,0,wear)
		if p<.80 and open>.015:
			c.draw_set_transform(center,portal_angle,Vector2(.81,1.02))
			c.draw_texture_rect_region(Art.portal_texture(),Rect2(-s*.5,s*.24,s,s*.26),Rect2(0,512*.74,512,512*.26),Color(1,1,1,opacity))
			c.draw_set_transform(Vector2.ZERO)
