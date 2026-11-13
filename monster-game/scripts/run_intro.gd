extends RefCounted
func paint(g,c: Node2D) -> void:
	if g.intro_left<=0:return
	var duration = 1.5
	for i in range(g.runner.members.size()):
		var m: Dictionary = g.runner.members[i]
		var x = g.runner.member_x(i)
		if x<g.runner.view_left-100 or x>g.runner.view_right+100:continue
		var delay = float(i%4)*.06
		var p = smoothstep(delay,1.25+delay,duration-g.intro_left)
		var floor_y = g.runner.ground_y(x)
		var foot = Vector2(x,floor_y+(1-p)*118-sin(p*PI)*7)
		var old = g.paint_target;g.paint_target = c
		g.actor.paint(c,int(m.kind),foot,112,0.0,"idle",g.ui_time,0,Color.WHITE,false,0.0,true,-1.0,0.0,g.runner.cosmetics_for(m,int(m.kind)))
		g.paint_target = old
func dirt(g,c: Node2D) -> void:
	if g.intro_left<=0:return
	for i in range(mini(g.runner.members.size(),32)):
		var x = g.runner.member_x(i);var y = g.runner.ground_y(x)+2
		var amount = sin(clampf((1.5-g.intro_left-float(i%4)*.06)/1.3,0,1)*PI)
		c.draw_set_transform(Vector2(x,y),0,Vector2(29,5));c.draw_circle(Vector2.ZERO,1,Color("24152b"));c.draw_set_transform(Vector2.ZERO)
		for j in range(5):
			var t = fposmod(g.ui_time*1.5+j*.19,1)
			var pos = Vector2(x+(j-2)*10*(.5+t),y-t*29*amount)
			c.draw_circle(pos,2.4*(1-t),Color(.40,.29,.31,amount*(1-t)))
