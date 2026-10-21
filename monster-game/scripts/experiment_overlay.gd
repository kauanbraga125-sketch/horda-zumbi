class_name HordeExperimentOverlay
extends Node2D
var game
var source = Rect2()
var wallet_target = Vector2.ZERO
func _init() -> void: z_index=10
func _draw() -> void:
	if game==null or not visible: return
	if game.screen == "results":
		game.hub.result_ui.paint_overlay(game,self);return
	var p: HordeExperimentPresentation=game.hub.presentation
	var before=game.paint_target;game.paint_target=self
	if p.stage()=="fill":
		var phase=p.portion()
		for i in range(8):
			var t=fposmod(phase*1.4-i*0.11,1.0)
			var point=source.get_center()+Vector2(sin(t*PI)*44,-source.size.y*0.7*(1-t))
			draw_circle(point,2.0+sin(t*PI)*2.2,Color(0.65,1.0,0.8,sin(t*PI)*0.7))
	if p.stage()=="award":
		var value = floori(int(p.current.coins)*p.award_portion())
		var compact=source.size.y<180
		var point=source.get_center()+Vector2(-176,-source.size.y*0.25) if compact else source.get_center()+Vector2(0,-source.size.y*0.38)
		game.home_menu.label(game,"NÍVEL "+str(p.current.new_level)+"!",point,25 if compact else 37,game.GOLD,true,300,true,3)
		game.home_menu.label(game,"+"+str(value)+" MOEDAS",point+Vector2(0,33),18 if compact else 25,game.GOLD,true,300,true,2)
		if int(p.current.eyes)>0: game.home_menu.label(game,"+"+str(p.current.eyes)+" OLHOS",point+Vector2(0,58),18,Color("dda7ff"),true,260,true,2)
		var from=source.get_center()+Vector2(0,source.size.y*0.15)
		var lift=36.0 if compact else 70.0
		for i in range(16):
			var t=clampf((p.elapsed-i*0.035)/0.8,0,1)
			if t<=0 or t>=1: continue
			var angle=i*2.39996;var burst=Vector2(cos(angle)*70,sin(angle)*46)
			var position=from+burst*sin(t*PI)*(1-t)+ (wallet_target-from)*smoothstep(0.1,1.0,t)+Vector2(0,-sin(t*PI)*lift)
			game.scenery.sprite(self,game.art.items[1],position,18+sin(t*PI)*10,Color(1,1,1,minf(1,t*7)))
			var star=from+Vector2(cos(angle),sin(angle))*((p.elapsed*90+i*7)*0.7)
			draw_circle(star,1.5,Color(1.0,0.8,0.24,maxf(0,1-p.elapsed)*0.7))
	game.paint_target=before
