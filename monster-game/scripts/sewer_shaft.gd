extends RefCounted
## Transicao ilustrada: 4 artes SVG originais (fundo, frente, rua quebrada, chegada).
## A geometria acompanha o mesmo deslocamento vertical dos personagens.
## Sem faixas opacas, sem repetir blocos procedurais, sem mascarar o gameplay.
const BACK: Texture2D = preload("res://assets/art/sewer_transition/shaft_back.svg")
const FRONT: Texture2D = preload("res://assets/art/sewer_transition/shaft_foreground.svg")
const RIM: Texture2D = preload("res://assets/art/sewer_transition/street_fracture.svg")
const ARRIVAL: Texture2D = preload("res://assets/art/sewer_transition/sewer_arrival.svg")

func limits(g,s) -> Dictionary:
	var view = Rect2(g.scenery.view_left,g.scenery.view_top,g.scenery.view_right-g.scenery.view_left,g.scenery.view_bottom-g.scenery.view_top)
	var street_y = g.runner.FLOOR-s.entry_drop()
	var water_y = s.WATER+s.entry_depth()
	return {"view":view,"street":street_y,"water":water_y,"edge":s.shore_edge()}

func background(g,s) -> void:
	if s.phase!="entry": return
	var c = g.paint_target
	var p = limits(g,s)
	var view: Rect2 = p.view
	var top: float = p.street-63.0
	var height: float = p.water-p.street+132.0
	var appearance = smoothstep(0.10,0.94,s.phase_age)
	# A arte inteira e um unico painel, com translucidez graduada
	# nas extremidades. A parede original permanece atras do painel.
	c.draw_texture_rect(BACK,Rect2(view.position.x,top,view.size.x,height),false,Color(1,1,1,appearance))
	# A luz do esgoto entra no ultimo terco da descida;
	# sem criar outra faixa de contraste na entrada da agua.
	var glow = smoothstep(2.55,4.10,s.phase_age)
	if glow>.01:
		c.draw_texture_rect(ARRIVAL,Rect2(view.position.x,p.water-352,view.size.x,352),false,Color(1,1,1,glow*.89))

func foreground(g,s) -> void:
	if s.phase!="entry": return
	var c = g.paint_target
	var p = limits(g,s)
	var view: Rect2 = p.view
	var top: float = p.street-63.0
	var height: float = p.water-p.street+132.0
	var presence = smoothstep(0.45,1.20,s.phase_age)
	# Molduras, correntes e tubulacoes passam NA FRENTE dos zumbis,
	# mas deixam a faixa central aberta para que continuem legiveis.
	c.draw_texture_rect(FRONT,Rect2(view.position.x,top,view.size.x,height),false,Color(1,1,1,presence*.88))
	# Borda fragmentada cobre o encontro da calçada com o abismo.
	# Apenas junto da abertura real, nunca em um X fixo da tela.
	var edge: float = p.edge
	if edge>view.position.x-260 and edge<view.end.x+130:
		c.draw_texture_rect(RIM,Rect2(edge-129,p.street-148,290,267),false,Color(1,1,1,.91))
	# Poeira e detritos pequenos: se movem com a mesma gravidade de entrada.
	for i in range(22):
		var t = fposmod(s.phase_age*.31+float(i)*.137,1.0)
		var x = edge+27+float(i%7)*28+sin(float(i)*2.75)*9
		var y = p.street+31+t*t*265
		if x<view.position.x-5 or x>view.end.x+5 or y<view.position.y or y>view.end.y: continue
		var radius = 1.3+float(i%4)*.65
		c.draw_circle(Vector2(x,y),radius,Color(.67,.62,.69,(1.0-t)*.31))
	# Goteiras e neblina suave junto ao espelho da agua, nao sobre a tela.
	if s.phase_age>2.5:
		var mist = smoothstep(2.5,4.2,s.phase_age)
		for i in range(5):
			var y = p.water-195+float(i)*21
			if y<view.position.y or y>view.end.y: continue
			c.draw_line(Vector2(view.position.x,y),Vector2(view.end.x,y),Color(.38,.57,.64,.022*mist),10,true)

func dock_face(g,edge: float) -> void:
	# A abertura durante a corrida normal tem a MESMA arte da descida.
	var c = g.paint_target
	var view = Rect2(g.scenery.view_left,g.scenery.view_top,g.scenery.view_right-g.scenery.view_left,g.scenery.view_bottom-g.scenery.view_top)
	var top: float = g.runner.FLOOR-70.0
	var right = view.end.x+80
	if edge>=right: return
	var region = Rect2(edge,top,right-edge,maxf(180.0,view.end.y-top+90))
	var tex_rect = Rect2(0,110,BACK.get_width(),BACK.get_height()-110)
	c.draw_texture_rect_region(BACK,region,tex_rect,Color(1,1,1,.86))
	# A arte quebra apenas a borda imediata (20 px); os blocos firmes
	# a esquerda continuam 100% visiveis ate a colisao fisica.
	c.draw_texture_rect_region(RIM,Rect2(edge-20,g.runner.FLOOR-148,181,267),Rect2(RIM.get_width()*109.0/290.0,0,RIM.get_width()*181.0/290.0,RIM.get_height()),Color.WHITE)
