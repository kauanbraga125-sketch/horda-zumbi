extends RefCounted
## Shared physics and drawing for collectible coins released by an equipped bird.

const MAX_COINS = 12
var mode = ""
var coins: Array[Dictionary] = []

func launch_coin(point: Vector2,velocity: Vector2,spin: float,settled_y: float = INF) -> void:
	if coins.size()>=MAX_COINS:return
	coins.append({"point":point,"previous":point,"velocity":velocity,"age":0.0,"bounces":0,"spin":spin,"landed":false,"settled_y":settled_y})

func mode_of(r) -> String:
	if r.sky.active:return "sky"
	if r.space.active:return "space" if r.space.phase=="flight" else "space_transition"
	if r.sewer.active:return "sewer" if r.sewer.phase=="ride" else "sewer_transition"
	return "street"

func advance_coins(r,dt: float) -> void:
	# Swept contact plus bounded substeps handles slower devices without tunnelling.
	var steps = clampi(ceili(dt/(1.0/60)),1,12)
	var step = dt/steps
	for i in range(coins.size()-1,-1,-1):
		var coin = coins[i];var collected = false
		for unused in range(steps):
			coin.previous = coin.point;coin.age += step
			var v: Vector2 = coin.velocity
			v.y += (280.0 if mode=="space" else 720.0)*step
			if mode=="space" and coin.age>.40:v.x = move_toward(v.x,-210,step*650)
			if mode=="sewer" and coin.age>.42:v.x = move_toward(v.x,-r.sewer.scroll_speed(r)*.62,step*1400)
			var pos: Vector2 = coin.point+v*step
			var settled_y = float(coin.get("settled_y", INF))
			if v.y>0 and pos.y>=settled_y:
				pos.y = settled_y;v.y = 0
			if mode=="street" and r.has_floor(pos.x):
				var floor_y = r.ground_y(pos.x)-13
				if v.y>0 and coin.point.y<=floor_y+3 and pos.y>=floor_y:
					pos.y = floor_y
					if int(coin.bounces)<1:
						v.y = -minf(138,absf(v.y)*.29);coin.bounces += 1
					else:v.y = 0;coin.landed = true
					v.x = -r.speed
			if mode=="street" and coin.landed:
				v.x = -r.speed
				if r.has_floor(pos.x):pos.y = r.ground_y(pos.x)-13;v.y = 0
				else:coin.landed = false
			coin.point = pos;coin.velocity = v
			if float(coin.age)>.16 and touches(r,coin.previous,pos):
				var amount: int = r.bird.coin_multiplier()
				r.coins += amount
				r.events.append({"type":"coin","amount":amount,"x":pos.x,"y":pos.y,"bird_bonus":true})
				collected = true;break
		if collected or coin.age>=6 or coin.point.x<r.view_left-90 or coin.point.y>950:coins.remove_at(i)

func touches(r,from: Vector2,to: Vector2) -> bool:
	if mode=="sewer":
		for boat in r.sewer.boats:
			var center = Vector2(boat.x,boat.y-30)
			if Geometry2D.get_closest_point_to_segment(center,from,to).distance_squared_to(center)<=62*62:return true
		return false
	if mode=="space" and r.space.battle.pilot_left>0:
		var center = Vector2(r.space.x+25,r.space.y-48)
		return Geometry2D.get_closest_point_to_segment(center,from,to).distance_squared_to(center)<=80*80
	for member in r.members:
		if member.falling:continue
		var center = Vector2(member.x,member.y-(r.space.member_height(r)*.5 if mode=="space" else 48.0))
		if Geometry2D.get_closest_point_to_segment(center,from,to).distance_squared_to(center)<=54*54:return true
	return false

func paint_coins(g) -> void:
	var c = g.paint_target
	for coin in coins:
		var p: Vector2 = coin.point;var age = float(coin.age)
		var opacity = clampf((6-age)*3,0,1)
		if mode=="street" and g.runner.has_floor(p.x):
			var floor_y = g.runner.ground_y(p.x)
			var shadow = clampf(1-(floor_y-p.y)/220,.05,.36)*opacity
			c.draw_set_transform(Vector2(p.x,floor_y-1),0,Vector2(1,.24))
			c.draw_circle(Vector2.ZERO,13,Color(0,0,0,shadow));c.draw_set_transform(Vector2.ZERO)
		var flip = maxf(.16,absf(cos(age*9+float(coin.spin))))
		var diameter = g.run_coin_height(29.0*(.60+.40*smoothstep(0,.14,age)))
		c.draw_set_transform(p,sin(age*3+float(coin.spin))*.12,Vector2(flip,1))
		c.draw_texture_rect(g.art.items[1],Rect2(-diameter*.5,-diameter*.5,diameter,diameter),false,Color(1,1,1,opacity))
		c.draw_set_transform(Vector2.ZERO)
		if fposmod(age*2.4+float(coin.spin),1)<.24:
			var offset = Vector2(10,-12)
			c.draw_line(p+offset-Vector2(4,0),p+offset+Vector2(4,0),Color(1,.92,.60,.7*opacity),1.5,true)
			c.draw_line(p+offset-Vector2(0,4),p+offset+Vector2(0,4),Color(1,.92,.60,.7*opacity),1.5,true)
