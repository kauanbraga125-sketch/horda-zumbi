class_name HordeCodex
extends RefCounted

const CHAPTERS = ["MONSTROS", "TRANSFORMAÇÕES", "RELÍQUIAS", "PRESTÍGIO"]
const INK = Color("392b38")
const FADED = Color("785d59")
const LEAF_SIZE = Vector2(400, 440)
const TURN_DURATION = 0.64
const REVEAL_DURATION = 1.85
const Leaf = preload("res://scripts/book_leaf.gd")
var paper: Texture2D = preload("res://assets/art/menu_v102/book_open.png")
var cover: Texture2D = preload("res://assets/art/menu_v102/book_cover.png")
var body_font: Font = preload("res://assets/fonts/Lora-Variable.ttf")
var italic_font: Font = preload("res://assets/fonts/Lora-Italic-Variable.ttf")
var title_font := FontVariation.new()
var chapters: Array = []
var textures: Dictionary = {}
var section := 0
var spread := 0
var old_section := 0
var old_spread := 0
var amount := 0.0
var closing := false
var closed_hold := 0.0
var page_turn := 0.0
var turn_direction := 1
var swipe_start := Vector2.ZERO
var swipe_id := -999
var signing := false
var reveal_times: Dictionary = {}
var old_reveals: Dictionary = {}
var cover_node: TextureRect
var viewports: Array[SubViewport] = []
var leaves: Array[Node2D] = []
var curl_mesh: ArrayMesh

func _init() -> void:
	title_font.base_font = preload("res://assets/fonts/Cinzel-Variable.ttf")
	title_font.variation_opentype = {"wght": 700.0}
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/codex_v103/entries.json"))
	chapters = data.chapters

func init(g) -> void:
	if is_instance_valid(cover_node): return
	cover_node = TextureRect.new()
	cover_node.texture = cover
	cover_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover_node.z_index = 4
	var material := ShaderMaterial.new()
	material.shader = preload("res://scripts/book_cover.gdshader")
	cover_node.material = material
	g.add_child(cover_node)
	cover_node.visible = false
	for i in range(4):
		var viewport := SubViewport.new()
		viewport.size = Vector2i(800, 880)
		viewport.disable_3d = true
		viewport.world_2d = World2D.new()
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		g.add_child(viewport)
		var leaf = Leaf.new()
		leaf.game = g
		leaf.book = self
		leaf.scale = Vector2(2, 2)
		viewport.add_child(leaf)
		viewports.append(viewport)
		leaves.append(leaf)

func spreads(chapter: int) -> int:
	return maxi(1, ceili(chapters[chapter].size() / 2.0))

func total_pages() -> int:
	var count := 0
	for chapter in chapters: count += ceili(chapter.size() / 2.0) * 2
	return count

func page_number(chapter: int, book_spread: int, side: int) -> int:
	var count := 1 + book_spread * 2 + side
	for i in range(chapter): count += spreads(i) * 2
	return count

func record(chapter: int, book_spread: int, side: int) -> Dictionary:
	var index := book_spread * 2 + side
	return chapters[chapter][index] if index < chapters[chapter].size() else {}

func level_required(entry: Dictionary) -> int:
	match str(entry.get("group", "")):
		"relic": return HordeMeta.RELIC_LEVELS[int(entry.index)]
		"seal": return HordeMeta.SEAL_LEVELS[int(entry.index)]
		"pact": return HordeMeta.RELIC_LEVELS[-1]
	return 0

func unlocked(g, entry: Dictionary) -> bool:
	if entry.is_empty(): return false
	match str(entry.group):
		"monster": return int(entry.kind) in g.data.owned
		"power": return int(entry.kind) in g.data.power_owned
		_: return int(g.data.player_level) >= level_required(entry)

func open(g, chapter: int = -1) -> void:
	section = clampi(int(g.data.get("codex_section", 0)) if chapter < 0 else chapter, 0, chapters.size()-1)
	spread = clampi(int(g.data.get("codex_spread", 0)) if chapter < 0 else 0, 0, spreads(section)-1)
	amount = 0
	closing = false
	closed_hold = 0
	page_turn = 0
	swipe_id = -999
	reveal_times.clear()
	g.change_screen("collection")
	g.sound.play("ui_confirm")

func update(g, dt: float) -> void:
	init(g)
	if g.screen != "collection":
		cover_node.visible = false
		swipe_id = -999
		signing = false
		for viewport in viewports: viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	page_turn = maxf(0, page_turn-dt)
	if closing:
		amount = maxf(0, amount-dt/0.55)
		if amount <= 0:
			closed_hold += dt
			if closed_hold >= 0.32:
				g.data.codex_section = section
				g.data.codex_spread = spread
				g.save_game()
				g.change_screen("home")
				cover_node.visible = false
				return
	else:
		amount = minf(1, amount+dt/0.62)
	if amount >= 0.99 and page_turn <= 0 and not closing: update_reveals(g, dt)
	for i in range(4):
		var active := i < 2 or page_turn > 0
		viewports[i].render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
		if not active: continue
		var leaf = leaves[i]
		var chapter := section if i < 2 else old_section
		var position := spread if i < 2 else old_spread
		leaf.side = i % 2
		leaf.entry = record(chapter, position, leaf.side)
		leaf.number = page_number(chapter, position, leaf.side)
		leaf.owned = unlocked(g, leaf.entry)
		var times: Dictionary = reveal_times if i < 2 else old_reveals
		leaf.reveal = 1.0 if bool(g.data.get("codex_seen", {}).get(leaf.entry.get("id", ""), false)) else clampf(float(times.get(leaf.entry.get("id", ""), 0))/REVEAL_DURATION, 0, 1)
		configure_portrait(g, leaf)
		leaf.queue_redraw()
	var b: Rect2 = layout(g).book
	cover_node.visible = amount < 0.52
	var h := b.size.y*0.94
	var w := h*cover.get_width()/float(cover.get_height())
	cover_node.position = Vector2(lerpf(b.get_center().x-w*0.5, b.get_center().x, amount), b.get_center().y-h*0.5)
	cover_node.size = Vector2(w*maxf(0.01, cos(amount*PI)), h)
	cover_node.material.set_shader_parameter("blink", sin(clampf(closed_hold/0.30, 0, 1)*PI) if closing else 0.0)

func update_reveals(g, dt: float) -> void:
	var completed := false
	if not g.data.get("codex_seen", null) is Dictionary: g.data.codex_seen = {}
	for side in range(2):
		var entry := record(section, spread, side)
		if entry.is_empty() or not unlocked(g, entry) or bool(g.data.codex_seen.get(entry.id, false)): continue
		if not reveal_times.has(entry.id):
			reveal_times[entry.id] = 0.0
			if reveal_times.size() == 1: g.sound.play("ritual_fill", -12)
		reveal_times[entry.id] = minf(REVEAL_DURATION, float(reveal_times[entry.id])+dt)
		if float(reveal_times[entry.id]) >= REVEAL_DURATION:
			g.data.codex_seen[entry.id] = true
			completed = true
	if completed: g.save_game()

func layout(g) -> Dictionary:
	var v: Rect2 = g.full_rect()
	var available := v.size.y-164.0
	var h := minf(640, minf(available, (v.size.x-256)/1.69))
	var w := h*1.69
	var b := Rect2(Vector2(v.get_center().x-(w+190)*0.5, v.position.y+96+(available-h)*0.3), Vector2(w, h))
	var pages: Array[Rect2] = [Rect2(b.position+b.size*Vector2(0.078,0.105), b.size*Vector2(0.378,0.685)), Rect2(b.position+b.size*Vector2(0.542,0.105), b.size*Vector2(0.378,0.685))]
	return {"book": b, "pages": pages, "tabs": Rect2(b.end.x+12, b.position.y+35, 174, 300)}

func signature_active(g) -> bool:
	return g.screen == "collection" and section == 3 and spread == spreads(3)-1 and amount >= 0.99 and page_turn <= 0 and not closing and HordeMeta.relic_count(int(g.data.player_level)) >= 4 and str(g.data.book_signed_at).is_empty()

func signature_rect(g) -> Rect2:
	var p: Rect2 = layout(g).pages[1]
	return Rect2(p.position+p.size*Vector2(0.025,0.53), p.size*Vector2(0.95,0.24))

func name_rect(g) -> Rect2:
	var p: Rect2 = layout(g).pages[1]
	return Rect2(p.position+p.size*Vector2(0.025,0.38), Vector2(p.size.x*0.95,p.size.y*0.083))

func font_text(g, value: String, baseline: Vector2, size: int = 20, color: Color = INK, center: bool = true, width: float = -1, font: Font = null) -> void:
	if font == null: font = body_font
	while width > 0 and size > 14 and font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width: size -= 1
	var point := baseline
	if center: point.x -= font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x*0.5
	if font == title_font: g.paint_target.draw_string_outline(font,point,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,1,color)
	g.paint_target.draw_string(font, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func paragraph(g, value: String, rect: Rect2, size: int = 21, color: Color = INK, font: Font = null) -> void:
	if font == null: font = body_font
	var rows: Array[String] = []
	var row := ""
	for word in value.split(" "):
		var next := word if row.is_empty() else row+" "+word
		if font.get_string_size(next,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x > rect.size.x and not row.is_empty():
			rows.append(row)
			row = word
		else: row = next
	if not row.is_empty(): rows.append(row)
	var line_height := float(size)*1.30
	if rows.size()*line_height > rect.size.y and size > 17:
		paragraph(g,value,rect,size-1,color,font)
		return
	for i in range(rows.size()): font_text(g,rows[i],rect.position+Vector2(0,size+i*line_height),size,color,false,-1,font)

func ornament(g, y: float, color: Color = Color("9f7651")) -> void:
	for side in [-1,1]: g.paint_target.draw_line(Vector2(200+side*16,y),Vector2(200+side*116,y),color,1,true)
	g.paint_target.draw_colored_polygon(PackedVector2Array([Vector2(200,y-4),Vector2(204,y),Vector2(200,y+4),Vector2(196,y)]),color)

func art(entry: Dictionary) -> Texture2D:
	var key := str(entry.get("art", "cover"))
	if key == "cover": return cover
	if not textures.has(key): textures[key] = load("res://assets/art/codex_v103/"+key+".png")
	if not entry.has("cell"): return textures[key]
	var cache_key := key+"_"+str(entry.cell)
	if not textures.has(cache_key):
		var atlas := AtlasTexture.new()
		atlas.atlas = textures[key]
		var cell_size: Vector2 = atlas.atlas.get_size()/Vector2(2,2) if key == "relics" else atlas.atlas.get_size()/Vector2(3,1)
		atlas.region = Rect2(Vector2(int(entry.cell)%2,int(entry.cell)/2)*cell_size if key == "relics" else Vector2(int(entry.cell)*cell_size.x,0),cell_size)
		atlas.filter_clip = true
		textures[cache_key] = atlas
	return textures[cache_key]

func artwork_rect(entry: Dictionary) -> Rect2:
	var image := art(entry)
	var box := Rect2(28,77,344,222)
	if str(entry.group) in ["relic","seal"]: box = Rect2(53,86,294,220)
	var scale := minf(box.size.x/image.get_width(),box.size.y/image.get_height())
	var size := image.get_size()*scale
	return Rect2(box.get_center()-size*0.5,size)

func configure_portrait(g, leaf) -> void:
	leaf.portrait.visible = not leaf.entry.is_empty() and leaf.owned and leaf.reveal >= 0.999 and str(leaf.entry.group) != "pact"
	if not leaf.portrait.visible: return
	var image := art(leaf.entry)
	var rect := artwork_rect(leaf.entry)
	leaf.portrait.texture = image
	leaf.portrait.position = rect.get_center()+Vector2(0,sin(g.ui_time*1.25+leaf.number)*1.8)
	leaf.portrait.scale = rect.size/image.get_size()
	var material: ShaderMaterial = leaf.portrait.material
	var pair: Array = {"zombie":[Vector2(0.62,0.36),Vector2(0.72,0.40)],"skeleton":[Vector2(0.71,0.33),Vector2(0.78,0.34)],"masked":[Vector2(0.55,0.27),Vector2(0.65,0.28)],"fly":[Vector2(0.67,0.49),Vector2(0.81,0.55)]}.get(str(leaf.entry.id),[Vector2(-1,-1),Vector2(-1,-1)])
	material.set_shader_parameter("eye_a",pair[0])
	material.set_shader_parameter("eye_b",pair[1])
	material.set_shader_parameter("seed",float(leaf.number)*0.91)
	material.set_shader_parameter("motion",0.003 if str(leaf.entry.id)=="fly" else 0.0013)
	material.set_shader_parameter("blink_strength",0.75 if str(leaf.entry.id) in ["zombie","skeleton"] else 0.0)
	material.set_shader_parameter("eye_light",0.16 if str(leaf.entry.id) in ["skeleton","fly"] else 0.04)

func fragment_edge(a: Vector2, b: Vector2, salt: float) -> PackedVector2Array:
	var points := PackedVector2Array([a])
	var normal := (b-a).orthogonal().normalized()
	for i in range(1, 6):
		var t := float(i)/6.0
		points.append(a.lerp(b,t)+normal*sin(salt*3.71+i*7.13)*0.018)
	return points

func fragment_uv(index: int) -> PackedVector2Array:
	var x := index%3
	var y := index/3
	var a := Vector2(x/3.0,y/4.0)
	var b := Vector2((x+1)/3.0,y/4.0)
	var c := Vector2((x+1)/3.0,(y+1)/4.0)
	var d := Vector2(x/3.0,(y+1)/4.0)
	var points := PackedVector2Array()
	points.append_array(fragment_edge(a,b,x+y*3+1))
	points.append_array(fragment_edge(b,c,30+x+1+y*4))
	var bottom := fragment_edge(d,c,x+(y+1)*3+1)
	bottom.append(c); bottom.reverse(); bottom.remove_at(bottom.size()-1)
	points.append_array(bottom)
	var left := fragment_edge(a,d,30+x+y*4)
	left.append(d); left.reverse(); left.remove_at(left.size()-1)
	points.append_array(left)
	return points

func fragments(g, entry: Dictionary, progress: float, owned: bool) -> void:
	var image := art(entry)
	var rect := artwork_rect(entry)
	var hole := PackedVector2Array()
	for i in range(64):
		var angle := float(i)*TAU/64
		var radius := 0.47+sin(i*2.71)*0.024+cos(i*1.17)*0.018
		hole.append(rect.get_center()+Vector2(cos(angle),sin(angle))*rect.size*radius)
	var fill := Color("302433")
	fill.a = 1.0-smoothstep(0.75,1.0,progress)
	g.paint_target.draw_colored_polygon(hole,fill)
	var edge := hole.duplicate()
	edge.append(edge[0])
	g.paint_target.draw_polyline(edge,Color(0.55,0.31,0.16,fill.a),5,true)
	g.paint_target.draw_polyline(edge,Color(0.86,0.67,0.42,fill.a),1.3,true)
	for i in range(0,64,2):
		var point := hole[i]
		g.paint_target.draw_line(point,point+(point-rect.get_center()).normalized()*3,Color(0.94,0.78,0.52,fill.a*0.7),0.7,true)
	var actual: Texture2D = image.atlas if image is AtlasTexture else image
	for index in range(12):
		var x := index%3
		var y := index/3
		var start := Vector2(x/3.0,y/4.0)
		var finish := start+Vector2(1.0/3,1.0/4)
		var corner_uv := fragment_uv(index)
		var center := rect.position+rect.size*(start+finish)*0.5
		var delay := float(index%4)*0.045
		var assembled := smoothstep(delay,0.92,progress) if owned else 0.0
		var offset := Vector2(sin(index*2.3)*46,cos(index*1.7)*32)*(1.0-assembled)
		var rotation := sin(index*3.1+0.6)*0.33*(1.0-assembled)
		var vertices := PackedVector2Array()
		var uv := PackedVector2Array()
		for point in corner_uv:
			vertices.append(center+(rect.position+rect.size*point-center).rotated(rotation)+offset)
			uv.append((image.region.position+point*image.region.size)/actual.get_size() if image is AtlasTexture else point)
		var hint := index in [0,5,10]
		var tint := Color.WHITE if owned else Color(0.82,0.72,0.69,0.84)
		if hint or owned:
			var shadow := PackedVector2Array()
			for point in vertices: shadow.append(point+Vector2(2.5,3))
			g.paint_target.draw_colored_polygon(shadow,Color(0.18,0.11,0.15,(1.0-assembled)*0.35))
			g.paint_target.draw_colored_polygon(vertices,Color(0.91,0.76,0.53,(1.0-assembled)*0.95))
			g.paint_target.draw_polygon(vertices,PackedColorArray([tint]),uv,actual)
			var border := vertices.duplicate(); border.append(vertices[0])
			g.paint_target.draw_polyline(border,Color(0.65,0.44,0.25,(1.0-assembled)*0.8),0.8,true)
	if owned:
		var flash := sin(clampf((progress-0.70)/0.30,0,1)*PI)*0.24
		g.paint_target.draw_rect(rect.grow(9),Color(0.63,1,0.83,flash))
		for i in range(10):
			var a: float = float(i)*TAU/10+g.ui_time*0.24
			var point := rect.get_center()+Vector2(cos(a)*rect.size.x*0.62,sin(a)*rect.size.y*0.51)*(1.0-progress*0.3)
			g.paint_target.draw_circle(point,1.5+flash*5,Color(0.34,0.77,0.61,sin(progress*PI)*0.8))

func paint_leaf(g, leaf) -> void:
	var source := Rect2(paper.get_size()*Vector2(0.078 if leaf.side==0 else 0.542,0.105),paper.get_size()*Vector2(0.378,0.685))
	g.paint_target.draw_texture_rect_region(paper,Rect2(Vector2.ZERO,LEAF_SIZE),source)
	var entry: Dictionary = leaf.entry
	if entry.is_empty():
		font_text(g,"Este capítulo continua...",Vector2(200,230),24,FADED,true,370,italic_font)
		font_text(g,str(leaf.number),Vector2(200,438),16,FADED)
		return
	font_text(g,str(entry.name).to_upper(),Vector2(200,30),27,INK,true,378,title_font)
	font_text(g,str(entry.tag),Vector2(200,55),17,FADED,true,370,italic_font)
	ornament(g,69)
	if str(entry.group)=="pact":
		paint_signature(g,leaf)
	else:
		if not leaf.owned or leaf.reveal < 0.999: fragments(g,entry,leaf.reveal,leaf.owned)
		if leaf.owned and leaf.reveal>=0.999:
			for i in range(5):
				var age := fposmod(g.ui_time*0.11+i*0.2,1.0)
				var at := Vector2(125+i*38+sin(g.ui_time+i)*8,304-age*70)
				g.paint_target.draw_circle(at,1.7,Color(0.34,0.65,0.52,sin(age*PI)*0.35))
		var ready: bool = leaf.owned and leaf.reveal>=0.75
		paragraph(g,str(entry.lore if ready else entry.hint),Rect2(12,307,376,81),20,INK if ready else FADED,body_font if ready else italic_font)
		ornament(g,398,Color("b48f64"))
		var detail := str(entry.ability) if ready else requirement(entry)
		paragraph(g,detail,Rect2(12,406,376,24),17,Color("365b4d") if ready else FADED)
		var status := "REVELANDO A PÁGINA..." if leaf.owned and leaf.reveal<0.999 else ("DESBLOQUEADO" if leaf.owned else "PÁGINA RASGADA")
		font_text(g,status,Vector2(200,438),13,Color("34614c") if leaf.owned else FADED,true,270,title_font)
	font_text(g,str(leaf.number),Vector2(380,438),16,FADED)

func requirement(entry: Dictionary) -> String:
	var level := level_required(entry)
	return "Complete missões até o nível "+str(level)+"." if level>0 else "Desbloqueie no Mercado para restaurar."

func paint_signature(g, leaf) -> void:
	if not leaf.owned:
		paragraph(g,str(leaf.entry.hint),Rect2(20,100,360,80),23,FADED,italic_font)
		var size := Vector2(125,175)
		g.paint_target.draw_texture_rect(cover,Rect2(Vector2(200,270)-size*0.5,size),false,Color(0.6,0.48,0.51,0.6))
		paragraph(g,"Reúna as quatro relíquias. O pacto desperta no nível 75.",Rect2(20,350,360,75),21)
		return
	paragraph(g,str(leaf.entry.lore),Rect2(12,85,376,66),19)
	font_text(g,"Nome do invocador",Vector2(12,154),16,FADED,false)
	var sr := Rect2(10,LEAF_SIZE.y*0.53,380,LEAF_SIZE.y*0.24)
	font_text(g,"Sua assinatura",Vector2(12,sr.position.y-10),16,FADED,false)
	g.panel(sr,Color("ead2a9"),Color("b18c64"),5,1,false)
	var signed := not str(g.data.book_signed_at).is_empty()
	var points: Array = g.data.book_signature if signed else g.hub.signature_points
	for i in range(1,points.size()):
		if not points[i].get("new",false): g.paint_target.draw_line(sr.position+Vector2(points[i-1].x,points[i-1].y)*sr.size,sr.position+Vector2(points[i].x,points[i].y)*sr.size,Color("8d3443"),2.7,true)
	if signed:
		font_text(g,str(g.data.book_name),Vector2(200,199),28,Color("8d3443"),true,370,italic_font)
		font_text(g,"PACTO ASSINADO",Vector2(200,382),21,Color("365b4d"),true,370,title_font)
	else:
		font_text(g,"Desenhe com o dedo",Vector2(200,sr.end.y-9),15,Color("91785e"),true,350,italic_font)
	font_text(g,"A sua marca faz parte desta história.",Vector2(200,417),17,FADED,true,370,italic_font)

func turn_to(g, chapter: int, target_spread: int) -> void:
	if closing or amount<0.99 or page_turn>0: return
	chapter = clampi(chapter,0,chapters.size()-1)
	target_spread = clampi(target_spread,0,spreads(chapter)-1)
	if chapter==section and target_spread==spread: return
	old_section = section
	old_spread = spread
	old_reveals = reveal_times.duplicate()
	turn_direction = 1 if page_number(chapter,target_spread,0)>page_number(section,spread,0) else -1
	section = chapter
	spread = target_spread
	reveal_times.clear()
	page_turn = TURN_DURATION
	signing = false
	g.sound.play("ui_confirm",-8)

func navigate(g, direction: int) -> void:
	var chapter := section
	var position := spread+direction
	if position<0:
		chapter -= 1
		if chapter<0: return
		position = spreads(chapter)-1
	elif position>=spreads(chapter):
		chapter += 1
		if chapter>=chapters.size(): return
		position = 0
	turn_to(g,chapter,position)

func curl(g, pages: Array) -> void:
	var t := smoothstep(0,1,1.0-page_turn/TURN_DURATION)
	var angle := t*PI
	var left: Rect2 = pages[0]
	var right: Rect2 = pages[1]
	var front: Texture2D = viewports[3 if turn_direction>0 else 2].get_texture()
	var back: Texture2D = viewports[0 if turn_direction>0 else 1].get_texture()
	var hinge := lerpf(right.position.x,left.end.x,t) if turn_direction>0 else lerpf(left.end.x,right.position.x,t)
	var width := lerpf(right.size.x,left.size.x,t)
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	for strip in range(28):
		for band in range(4):
			for offset in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
				var u: float = (strip+offset.x)/28.0
				var v: float = (band+offset.y)/4.0
				var bend: float = sin(u*PI)*sin(angle)
				var x: float = hinge+turn_direction*(cos(angle)*u*width+bend*19)
				var y: float = right.position.y+v*right.size.y+bend*(v-0.5)*39
				vertices.append(Vector3(x,y,0))
				var uv_x: float = u if (t<0.5 and turn_direction>0) or (t>=0.5 and turn_direction<0) else 1.0-u
				uvs.append(Vector2(uv_x,v))
				var shade: float = 1.0-sin(angle)*(0.11+0.17*u)
				colors.append(Color(shade,shade*0.985,shade*0.965,1))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	curl_mesh = mesh
	g.paint_target.draw_mesh(mesh,front if t<0.5 else back)

func page_button(g, rect: Rect2, direction: int) -> void:
	g.home_menu.slab(g,rect,Color("392348"),Color("ae895a"),7,3)
	var p := rect.get_center()
	g.paint_target.draw_colored_polygon(PackedVector2Array([p+Vector2(-6*direction,-10),p+Vector2(7*direction,0),p+Vector2(-6*direction,10)]),g.CREAM)
	g.buttons.append({"rect":rect.grow(6),"action":"codex_next" if direction>0 else "codex_prev"})

func paint(g) -> void:
	var v: Rect2 = g.full_rect()
	font_text(g,"LIVRO DOS MORTOS",v.position+Vector2(44,48),34,g.GOLD,false,v.size.x*0.66,title_font)
	font_text(g,"Memórias da horda · "+str(total_pages())+" páginas para descobrir",v.position+Vector2(46,77),18,g.MINT,false,v.size.x*0.65)
	g.hub.wallet(g,Rect2(v.end.x-280,v.position.y+23,236,57))
	var d := layout(g)
	var b: Rect2 = d.book
	g.home_menu.atmosphere.fit(g.paint_target,paper,b,Color(1,1,1,smoothstep(0.15,0.75,amount)))
	if amount>=0.80 and viewports.size()==4:
		var opacity := Color(1,1,1,smoothstep(0.80,1.0,amount))
		if page_turn>0:
			g.paint_target.draw_texture_rect(viewports[2 if turn_direction>0 else 0].get_texture(),d.pages[0],false,opacity)
			g.paint_target.draw_texture_rect(viewports[1 if turn_direction>0 else 3].get_texture(),d.pages[1],false,opacity)
			curl(g,d.pages)
		else:
			for side in range(2): g.paint_target.draw_texture_rect(viewports[side].get_texture(),d.pages[side],false,opacity)
	if closing or amount<0.99: return
	var tabs: Rect2 = d.tabs
	for i in range(chapters.size()):
		var r := Rect2(tabs.position+Vector2(0,i*72),Vector2(tabs.size.x,61))
		g.home_menu.slab(g,r,Color("28594f") if i==section else Color("34203f"),g.MINT if i==section else Color("a67c50"),9,3)
		font_text(g,CHAPTERS[i],r.get_center()+Vector2(0,-2),18,g.CREAM,true,r.size.x-16,title_font)
		var owned := 0
		for entry in chapters[i]:
			if unlocked(g,entry): owned += 1
		font_text(g,str(owned)+" / "+str(chapters[i].size())+" descobertos",r.get_center()+Vector2(0,18),14,g.MINT if i==section else Color("c9b3bd"),true,r.size.x-14)
		g.buttons.append({"rect":r,"action":"codex_section_"+str(i)})
	if section>0 or spread>0: page_button(g,Rect2(b.position.x-9,b.end.y-58,43,43),-1)
	if section<chapters.size()-1 or spread<spreads(section)-1: page_button(g,Rect2(b.end.x-34,b.end.y-58,43,43),1)
	if section==3 and spread==0:
		var r := Rect2(tabs.position+Vector2(0,306),Vector2(tabs.size.x,45))
		g.home_menu.slab(g,r,Color("46303e"),Color("b88a52"),7,2)
		font_text(g,"SEU PACTO",r.get_center()+Vector2(0,6),17,g.GOLD,true,r.size.x-10,title_font)
		g.buttons.append({"rect":r,"action":"codex_pact"})
	if signature_active(g):
		var sr := signature_rect(g)
		g.hub.button(g,Rect2(sr.position.x,sr.end.y+12,sr.size.x*0.60,36),"ASSINAR","book_sign",true)
		g.hub.button(g,Rect2(sr.position.x+sr.size.x*0.63,sr.end.y+12,sr.size.x*0.37,36),"LIMPAR","signature_clear")
	g.hub.button(g,Rect2(v.position.x+40,v.end.y-59,190,47),"VOLTAR","back")
	g.hub.button(g,Rect2(v.end.x-292,v.end.y-59,252,47),"VER NO MERCADO","market",true)
	var first := page_number(section,spread,0)
	font_text(g,"Páginas "+str(first)+"–"+str(first+1)+" de "+str(total_pages()),Vector2(v.get_center().x,v.end.y-35),18,g.CREAM,true,v.size.x*0.36)
	font_text(g,"Deslize para folhear",Vector2(v.get_center().x,v.end.y-13),14,g.MINT,true,v.size.x*0.35,italic_font)

func action(g, a: String) -> bool:
	if a=="collection": open(g); return true
	if a=="book_open": open(g,2); return true
	if g.screen!="collection": return false
	if a=="back":
		if not closing:
			closing = true
			closed_hold = 0
			signing = false
			g.sound.play("ui_confirm",-8)
		return true
	if a.begins_with("codex_"):
		if closing or amount<0.99 or page_turn>0: return true
		if a=="codex_next": navigate(g,1)
		elif a=="codex_prev": navigate(g,-1)
		elif a=="codex_pact": turn_to(g,3,spreads(3)-1)
		elif a.begins_with("codex_section_"): turn_to(g,int(a.trim_prefix("codex_section_")),0)
		return true
	return closing

func input(g, event: InputEvent) -> bool:
	if g.screen!="collection" or amount<0.99 or closing or page_turn>0: return false
	var p := Vector2.ZERO
	var pressed := false
	var released := false
	var moved := false
	var id := -1
	if event is InputEventScreenTouch:
		p = g.to_local(event.position); pressed = event.pressed; released = not event.pressed; id = event.index
	elif event is InputEventScreenDrag:
		p = g.to_local(event.position); moved = true; id = event.index
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		p = g.to_local(event.position); pressed = event.pressed; released = not event.pressed
	elif event is InputEventMouseMotion:
		p = g.to_local(event.position); moved = true
	else: return false
	if signature_active(g):
		var sr := signature_rect(g)
		if pressed and sr.has_point(p):
			signing = true
			g.hub.signature_points.append({"x":(p.x-sr.position.x)/sr.size.x,"y":(p.y-sr.position.y)/sr.size.y,"new":true})
			return true
		if moved and signing:
			if sr.has_point(p) and g.hub.signature_points.size()<1200: g.hub.signature_points.append({"x":(p.x-sr.position.x)/sr.size.x,"y":(p.y-sr.position.y)/sr.size.y,"new":false})
			return true
		if released and signing: signing = false; return true
	if pressed and layout(g).book.grow(-38).has_point(p) and not (signature_active(g) and name_rect(g).has_point(p)):
		for button in g.buttons:
			if button.rect.has_point(p): return false
		swipe_start = p; swipe_id = id; return true
	if released and swipe_id==id:
		swipe_id = -999
		if absf(p.x-swipe_start.x)>65 and absf(p.y-swipe_start.y)<120: navigate(g,1 if p.x<swipe_start.x else -1)
		return true
	return moved and swipe_id==id
