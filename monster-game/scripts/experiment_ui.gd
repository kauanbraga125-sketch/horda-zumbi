class_name HordeExperimentUI
extends RefCounted
static func layout(body: Rect2) -> Dictionary:
	var chamber=Rect2(body.position,Vector2(body.size.x*0.28,body.size.y))
	var x=chamber.end.x+14;var w=body.end.x-x;var gap=10.0;var h=(body.size.y-65-gap*2)/3
	var cards: Array[Rect2]=[]
	for i in range(3): cards.append(Rect2(x,body.position.y+i*(h+gap),w,h))
	return {"chamber":chamber,"cards":cards,"adrenaline":Rect2(x,body.end.y-55,w,55)}
func paint(g) -> void:
	var r: Rect2=g.hub.frame(g,"EXPERIMENTO DE RESSURREIÇÃO","Complete missões. Encha o frasco. Ressuscite sua próxima mistura.")
	var d=layout(r);var chamber: Rect2=d.chamber;var p: HordeExperimentPresentation=g.hub.presentation
	var variant=HordeExperimentArt.variant(p.shown_level)
	g.paint_target.draw_style_box(g.hub.profile_ui.featured,chamber)
	var headline_level=int(p.current.new_level) if p.stage()=="award" else p.shown_level
	g.hub.label(g,"NÍVEL "+str(headline_level),Vector2(chamber.get_center().x,chamber.position.y+35),29,g.GOLD,true,chamber.size.x-30)
	g.pages.lines(g,variant.name,Rect2(chamber.position+Vector2(20,44),Vector2(chamber.size.x-40,39)),18,g.MINT,true,2)
	var vessel=Rect2(chamber.position+Vector2(25,77),Vector2(chamber.size.x-50,chamber.size.y-180))
	g.hub.experiment(g,vessel)
	g.hub.label(g,"FRASCO CHEIO!" if p.stage() in ["react","award"] else str(floori(p.shown_xp))+" / "+str(HordeProgress.level_target(p.shown_level))+" ESSÊNCIA",Vector2(chamber.get_center().x,chamber.end.y-85),22,g.CREAM,true,chamber.size.x-35)
	g.progress_bar(Rect2(chamber.position.x+24,chamber.end.y-72,chamber.size.x-48,10),p.amount(),variant.color)
	var reward=Rect2(chamber.position.x+17,chamber.end.y-53,chamber.size.x-34,39)
	g.home_menu.slab(g,reward,Color("24172d"),Color("b78b4b"),8,2)
	HordeExperimentArt.draw(g.paint_target,"mission_coins",Rect2(reward.position+Vector2(6,3),Vector2(37,33)))
	var next=100+mini(50,p.shown_level+1)*10
	g.hub.label(g,"PRÓXIMO NÍVEL",reward.position+Vector2(49,15),12,g.MINT,false,reward.size.x-53)
	g.hub.label(g,str(next)+" MOEDAS" if p.shown_level<500 else "NÍVEL MÁXIMO",reward.position+Vector2(49,32),18,g.GOLD,false,reward.size.x-53)
	var missions=HordeMissionCatalog.active(g.data)
	for i in range(3): card(g,missions[i],d.cards[i],i)
	adrenaline(g,d.adrenaline)
	g.hub.footer(g)
func card(g, m: Dictionary, row: Rect2, index: int) -> void:
	var complete=m.key in g.data.claimed
	var color: Color=[Color("76edba"),Color("ffd173"),Color("ff83a8")][clampi(int(m.difficulty)-1,0,2)]
	g.paint_target.draw_style_box(g.hub.profile_ui.panel,row)
	if complete: g.paint_target.draw_rect(row.grow(-6),Color(0.3,1,0.65,0.045+sin(g.ui_time*4)*0.02))
	var art_width=minf(136,row.size.x*0.22)
	HordeExperimentArt.draw(g.paint_target,"mission_"+str(m.art),Rect2(row.position+Vector2(9,8),Vector2(art_width,row.size.y-16)))
	var x=row.position.x+art_width+18;var right=row.end.x-99;var width=right-x
	var size=20 if width>350 else 18
	g.pages.lines(g,m.title,Rect2(x,row.position.y+12,width,48),size,g.GOLD,false,2)
	var badge=["FÁCIL","MÉDIA","DIFÍCIL"][clampi(int(m.difficulty)-1,0,2)]
	g.hub.label(g,badge,Vector2(x,row.position.y+74),13,color)
	var mode="SEM PERDAS" if str(m.stat).begins_with("clean_") else ("EM UMA PARTIDA" if m.mode=="best" else "ACUMULATIVA")
	if g.mission_born_stats.has(m.key) and m.mode=="best" and g.screen=="run": mode="PRÓXIMA PARTIDA"
	g.hub.label(g,mode,Vector2(x+64,row.position.y+74),12,g.MINT,false,maxf(1,width-64))
	var count=int(g.data.mission_progress.get(m.id,0));var bar=Rect2(x,row.end.y-35,maxf(40,width-75),9)
	g.progress_bar(bar,float(count)/maxf(1,int(m.target)),g.MINT if complete else color)
	g.hub.label(g,str(count)+"/"+str(int(m.target)),Vector2(bar.end.x+8,bar.end.y+3),15,g.CREAM,false,70)
	g.hub.label(g,"CONCLUÍDA ✓" if complete else "EM ANDAMENTO",Vector2(x,row.end.y-9),12,g.MINT if complete else Color("c3a0c9"),false,width)
	var reward=Rect2(row.end.x-88,row.position.y+12,75,row.size.y-24)
	g.paint_target.draw_line(Vector2(reward.position.x-8,row.position.y+16),Vector2(reward.position.x-8,row.end.y-16),Color("786076"),1,true)
	HordeExperimentArt.draw(g.paint_target,"specimen_vial",Rect2(reward.position+Vector2(17,1),Vector2(42,52)))
	g.hub.label(g,"+"+str(int(m.ritual)),Vector2(reward.get_center().x,row.end.y-34),24,g.MINT,true,76)
	g.hub.label(g,"ESSÊNCIA",Vector2(reward.get_center().x,row.end.y-15),11,g.MINT,true,80)
func adrenaline(g, box: Rect2) -> void:
	g.paint_target.draw_style_box(g.hub.profile_ui.panel,box)
	var count=int(g.data.doses) if Time.get_unix_time_from_system()<int(g.data.dose_reset_at)+86400 else 3
	HordeExperimentArt.draw(g.paint_target,"specimen_vial",Rect2(box.position+Vector2(14,6),Vector2(32,42)),Color("ff9ba7"))
	g.hub.label(g,"ADRENALINA",box.position+Vector2(54,23),18,g.GOLD)
	g.hub.label(g,str(count)+" / 3",box.position+Vector2(195,23),19,g.CREAM)
	g.hub.label(g,"+50% NAS MISSÕES · RENOVA EM 24H",box.position+Vector2(54,43),13,g.MINT,false,box.size.x-65)
