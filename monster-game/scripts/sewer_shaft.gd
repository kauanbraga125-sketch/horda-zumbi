extends RefCounted
## Escenario vertical de passagem: a cidade sai pelo alto e a galeria aparece por baixo.
## Reutiliza a textura nativa do esgoto para manter materiais, cores e escala do jogo.
const Old = preload("res://scripts/bird_art.gd")

func paint(g, s) -> void:
	var c = g.paint_target
	var view: Rect2 = Rect2(g.scenery.view_left, g.scenery.view_top, g.scenery.view_right-g.scenery.view_left, g.scenery.view_bottom-g.scenery.view_top)
	var surface: float = g.runner.FLOOR - s.entry_drop()
	var water: float = s.WATER + s.entry_depth()
	var reveal: float = 1.0 - smoothstep(3.32, s.ENTRY_SECONDS-0.10, s.phase_age)
	if reveal <= 0.002: return
	var top: float = maxf(view.position.y, surface + 3.0)
	var bottom: float = minf(view.end.y, water - 112.0)
	if bottom <= top: return

	# O velho fundo subterraneo fica POR TRAS da nova parede e emerge ao fim da queda.
	# A faixa nao desloca ou altera a colisao: e apenas desenho, preso a superficie real.
	var wall = Rect2(view.position.x, top, view.size.x, bottom-top)
	c.draw_rect(wall, Color(.065, .065, .105, .88*reveal))
	var tex: Texture2D = Old.texture("sewer")
	var sample = Rect2(tex.get_size()*Vector2(.12,.15), tex.get_size()*Vector2(.76,.47))
	c.draw_texture_rect_region(tex, wall, sample, Color(.64,.62,.73,.47*reveal))

	# Estratos de pedra em perspectiva: alvenaria maior junto da superficie,
	# blocos mais escuros e molhados quando nos aproximamos do tunel inundado.
	var brick_w: float = 146.0
	for row in range(14):
		var y: float = surface + 22.0 + row*55.0
		if y > bottom or y+52 < top: continue
		var depth: float = clampf((y-surface)/maxf(1.0,water-surface),0,1)
		var seam: float = smoothstep(0.54,0.90,depth)
		var a: float = reveal * (1.0 - smoothstep(water-340.0,water-125.0,y))
		if a <= 0.012: continue
		var offset: float = -brick_w*0.5 if row%2==1 else 0.0
		var first: int = floori((view.position.x-offset)/brick_w)-1
		var last: int = ceili((view.end.x-offset)/brick_w)+1
		for col in range(first,last):
			var x: float = float(col)*brick_w+offset+5.0
			var grain: float = sin(float(col)*18.13+float(row)*24.57)*.5+.5
			var fill: Color = Color(.18+grain*.038-seam*.047, .17+grain*.034+seam*.01, .23+grain*.035-seam*.006, .40*a)
			var rect = Rect2(x, maxf(y,top), brick_w-11.0, minf(y+49.0,bottom)-maxf(y,top))
			if rect.size.y<=0: continue
			c.draw_rect(rect, fill)
			c.draw_line(Vector2(x+5, maxf(y+3,top)),Vector2(x+brick_w-14,maxf(y+3,top)),Color(.42,.36,.48,.13*a),1.5,true)
			if grain>.6 and y+39<bottom:
				c.draw_line(Vector2(x+65,y+10),Vector2(x+58,y+31),Color(.055,.055,.09,.3*a),2,true)
				c.draw_line(Vector2(x+58,y+31),Vector2(x+78,y+43),Color(.055,.055,.09,.25*a),1.5,true)

	# Coroas de pedra, ferragens e canos na parede, sempre ancorados ao poco.
	# A parte mais baixa usa menos opacidade para se mesclar ao fundo original.
	for level in range(3):
		var ypipe: float = surface + 185.0 + level*174.0
		if ypipe < top-35 or ypipe > bottom+28: continue
		var fade: float = reveal * (1.0-smoothstep(water-350.0,water-105.0,ypipe))
		if fade<=.012: continue
		var radius: float = 19.0 if level==1 else 12.0
		c.draw_line(Vector2(view.position.x-30,ypipe),Vector2(view.end.x+30,ypipe),Color(.055,.054,.078,.90*fade),radius*2.45,true)
		c.draw_line(Vector2(view.position.x-30,ypipe),Vector2(view.end.x+30,ypipe),Color(.29,.19,.20,.95*fade),radius*1.85,true)
		c.draw_line(Vector2(view.position.x-30,ypipe-radius*.35),Vector2(view.end.x+30,ypipe-radius*.35),Color(.54,.35,.24,.42*fade),radius*.25,true)
		var firstclamp: int = floori(view.position.x/370.0)-1
		var lastclamp: int = ceili(view.end.x/370.0)+1
		for i in range(firstclamp,lastclamp):
			var px: float = float(i)*370.0+95.0+level*50.0
			c.draw_line(Vector2(px,ypipe-radius*1.4),Vector2(px,ypipe+radius*1.4),Color(.08,.075,.09,.96*fade),11,true)
			c.draw_line(Vector2(px,ypipe-radius*1.4),Vector2(px,ypipe+radius*1.4),Color(.50,.34,.26,.85*fade),6,true)
			c.draw_circle(Vector2(px,ypipe),3.0,Color(.76,.60,.39,.75*fade))

	# Raizes pendentes na parte superior e goteiras que conduzem o olhar para baixo.
	for i in range(floori(view.position.x/173.0)-1,ceili(view.end.x/173.0)+2):
		var x: float = float(i)*173.0+38.0
		var root_l: float = 26.0+fposmod(absf(sin(i*8.92))*123.0,95.0)
		if surface+root_l>top and surface<bottom:
			var start = Vector2(x,surface+6)
			var end = Vector2(x-13+sin(float(i)*.6)*19, minf(surface+root_l,bottom))
			c.draw_line(start,end,Color(.055,.095,.08,.58*reveal),5,true)
			c.draw_line(start+Vector2(3,0),end+Vector2(3,0),Color(.23,.27,.16,.34*reveal),2,true)
		var dy: float = surface+184+fposmod(float(i)*117.0,315.0)
		if dy>top and dy<bottom:
			var rain_t: float = fposmod(s.age*.68+float(i)*.37,1.0)
			c.draw_line(Vector2(x+28,dy+rain_t*56),Vector2(x+26,dy+rain_t*56+14),Color(.47,.72,.75,(1-rain_t)*.30*reveal),1.7,true)

	# Luz quente da galeria invadindo os ultimos metros: nevoa e halos
	# nao fazem um fade preto de tela, pois os personagens nunca somem.
	for i in range(floori(view.position.x/440.0)-1,ceili(view.end.x/440.0)+2):
		var lamp_x: float = float(i)*440.0+190.0
		var lamp_y: float = water-244.0
		var lamp_alpha: float = reveal*smoothstep(0.9,3.7,s.phase_age)
		if lamp_y<top-80 or lamp_y>bottom+70: continue
		for j in range(4,0,-1):
			c.draw_circle(Vector2(lamp_x,lamp_y),float(j)*26,Color(.95,.41,.13,lamp_alpha*.012))
		c.draw_line(Vector2(lamp_x,lamp_y-80),Vector2(lamp_x,lamp_y-13),Color(.07,.06,.09,.6*lamp_alpha),3,true)
		c.draw_rect(Rect2(lamp_x-11,lamp_y-16,22,30),Color(.11,.085,.075,.9*lamp_alpha))
		c.draw_rect(Rect2(lamp_x-6,lamp_y-11,12,19),Color(.99,.66,.23,.85*lamp_alpha))
	for i in range(5):
		var mist_y: float = water-330.0+float(i)*33.0
		if mist_y<=top or mist_y>=bottom: continue
		var opacity: float = (.032+float(i)*.008)*reveal*smoothstep(.7,3.2,s.phase_age)
		c.draw_rect(Rect2(view.position.x,mist_y,view.size.x,18.0),Color(.33,.46,.48,opacity))
