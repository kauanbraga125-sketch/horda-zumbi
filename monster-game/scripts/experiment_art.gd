class_name HordeExperimentArt
extends RefCounted
const ROOT = "res://assets/art/experiment_v105/"
const PALETTES = [
	["SORO REANIMADOR","63fa4e"],["SORO DO ACAMPAMENTO","fa405c"],["EXTRATO DO PORÃO","d247ff"],
	["ECTOPLASMA","39ebef"],["ESSÊNCIA DO HOSPEDEIRO","ffae24"],["PLASMA DA FITA PERDIDA","419aff"],
	["OURO MALDITO","ffd234"],["PLASMA CORAL","ff6287"],["NÉCTAR DO ALÉM","ad86ff"],
	["NÉVOA PEROLADA","b9f6f2"],["SEIVA DA MEIA-NOITE","b5f23b"],["ELIXIR DO CALDEIRÃO","fc7c29"]]
const SPECIMENS = ["brain","eye","hand","mask","tentacle","ghost","larva","egg","vhs","skull","fang","heart","bat","mushroom","leaves"]
const BASE_PAIRS = [[0,1],[3,14],[1,4],[5,9],[6,7],[2,8],[9,10],[6,11],[0,3],[1,5],[7,12],[2,13]]
static var cached: Dictionary = {}
static func texture(id: String) -> Texture2D:
	if not cached.has(id): cached[id]=load(ROOT+id+".png")
	return cached[id]
static func variant(level: int) -> Dictionary:
	var number = maxi(0,level-1);var palette = posmod(number,12);var cycle = number/12
	var pairs: Array = []
	for a in range(15):
		for b in range(a+1,15): pairs.append([a,b])
	var seed_pair = pairs.find(BASE_PAIRS[palette])
	var pair: Array = pairs[posmod(seed_pair+cycle*37,105)]
	return {"name":PALETTES[palette][0],"color":Color(PALETTES[palette][1]),"palette":palette,"objects":[SPECIMENS[pair[0]],SPECIMENS[pair[1]]],"mood":posmod(cycle+palette,4),"speed":0.7+0.13*posmod(palette,4)}
static func draw(canvas: CanvasItem, id: String, box: Rect2, tint: Color = Color.WHITE) -> void:
	var tex = texture(id)
	if tex==null: return
	var size = tex.get_size()*minf(box.size.x/tex.get_width(),box.size.y/tex.get_height())
	canvas.draw_texture_rect(tex,Rect2(box.get_center()-size*0.5,size),false,tint)
