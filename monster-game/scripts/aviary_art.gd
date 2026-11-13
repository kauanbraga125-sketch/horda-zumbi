extends RefCounted
## Small raw sprites; book illustrations and locked bird portraits are not preloaded.
static var textures: Dictionary = {}
static var styles: Dictionary = {}
const CORE = ["background","panel","selected","row","header","button","badge","nest","fusion","crate_0","egg_0","egg_1","egg_2","egg_3","egg_4","gear"]
var warm_cursor = 0

func warm_step() -> void:
	if warm_cursor<CORE.size():texture(CORE[warm_cursor]);warm_cursor += 1

func texture(key: String) -> Texture2D:
	if not textures.has(key):
		var image = Image.new()
		if image.load_webp_from_buffer(FileAccess.get_file_as_bytes("res://assets/art/v170/"+key+".webp"))!=OK:push_error("Aviary sprite missing: "+key);return null
		textures[key] = ImageTexture.create_from_image(image)
	return textures[key]

func draw(c: Node2D,key: String,rect: Rect2,tint: Color = Color.WHITE,angle: float = 0,stretch: bool = false) -> Rect2:
	var tex = texture(key)
	if tex==null:return rect
	var size = rect.size if stretch else tex.get_size()*minf(rect.size.x/tex.get_width(),rect.size.y/tex.get_height())
	var actual = Rect2(rect.get_center()-size*.5,size)
	c.draw_set_transform(actual.get_center(),angle);c.draw_texture_rect(tex,Rect2(-size*.5,size),false,tint)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)
	return actual

func frame(c: Node2D,key: String,rect: Rect2,tint: Color = Color.WHITE) -> void:
	var cache = key+str(tint)
	if not styles.has(cache):
		var tex = texture(key)
		if tex==null:return
		var style = StyleBoxTexture.new();style.texture = tex;style.modulate_color = tint
		var edge = minf(tex.get_width()*.12,tex.get_height()*.27)
		style.set_texture_margin(SIDE_LEFT,edge);style.set_texture_margin(SIDE_RIGHT,edge)
		style.set_texture_margin(SIDE_TOP,minf(32,tex.get_height()*.24));style.set_texture_margin(SIDE_BOTTOM,minf(32,tex.get_height()*.24))
		styles[cache] = style
	# Scale the nine-patch border with its destination height. Fixed source-pixel
	# margins otherwise consume short mobile buttons and flatten their centre.
	var tex: Texture2D = styles[cache].texture
	var scale = minf(rect.size.x/tex.get_width(),rect.size.y/tex.get_height())
	c.draw_set_transform(rect.position,0,Vector2.ONE*scale)
	c.draw_style_box(styles[cache],Rect2(Vector2.ZERO,rect.size/scale))
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

func portrait(c: Node2D,id: String,rect: Rect2,time: float = 0,active: bool = false,tint: Color = Color.WHITE) -> void:
	var bob = sin(time*3+float(id.hash()%17))*(2 if active else .55)
	draw(c,"portrait/"+id,Rect2(rect.position+Vector2(0,bob),rect.size),tint)

func unknown(c: Node2D,rect: Rect2,g) -> void:
	var centre = rect.get_center();var radius = minf(rect.size.x,rect.size.y)*.34
	c.draw_circle(centre,radius,Color("21172e"));c.draw_arc(centre,radius,0,TAU,28,Color("8e709b"),1.6,true)
	g.home_menu.label(g,"?",centre+Vector2(0,rect.size.y*.19),roundi(rect.size.y*.60),Color("b7a1c5"),true,rect.size.x)

func egg(c: Node2D,index: int,rect: Rect2,time: float,shake: float = 0,taps: int = 0) -> Rect2:
	var bob = [1.4,3.0,1.0,4.5,2.6][clampi(index,0,4)]*sin(time*(2.4+index*.25))
	var angle = sin(time*47)*shake*.06+sin(time*1.9)*(.009 if index==0 else .018)
	var actual = draw(c,"egg_"+str(index),Rect2(rect.position+Vector2(sin(time*53)*shake*9,bob),rect.size),Color.WHITE,angle)
	var colour = preload("res://scripts/bird_catalog.gd").COLORS[index]
	if index>=1:
		for j in range(3 if index<4 else 5):
			var phase = fposmod(time*.32+j*.31,1)
			var p = actual.position+Vector2(actual.size.x*(.22+j*.17),actual.size.y*(.70-phase*.58))
			c.draw_circle(p,1+sin(phase*PI)*1.3,Color(colour,sin(phase*PI)*.55))
	if index==2:
		var size = actual.size.y*.22
		draw(c,"gear",Rect2(actual.position+actual.size*Vector2(.09,.47),Vector2.ONE*size),Color.WHITE,time*.7)
	if index==3:
		c.draw_arc(actual.get_center(),actual.size.y*.48,-2.8,.3,28,Color(colour,maxf(0,sin(time*.9))*.15),2,true)
	elif index==4:
		for j in range(6):
			var p = actual.get_center()+Vector2.from_angle(time*.35+j*TAU/6)*actual.size.y*.46
			c.draw_line(p-Vector2(3,0),p+Vector2(3,0),Color(colour,.5),1.2,true)
			c.draw_line(p-Vector2(0,3),p+Vector2(0,3),Color(colour,.5),1.2,true)
	for k in range(taps):
		var points = PackedVector2Array()
		for j in range(6):points.append(actual.position+actual.size*Vector2(.34+k*.21+sin(j*2.6+k)*.055,.20+j*.11))
		c.draw_polyline(points,Color("21102e"),maxf(1.3,actual.size.x*.014),true)
		c.draw_polyline(points,Color(colour,.45),maxf(.7,actual.size.x*.004),true)
	return actual

func shell(c: Node2D,index: int,rect: Rect2,progress: float) -> void:
	if progress>=1:return
	var tex = texture("egg_"+str(index))
	for i in range(8):
		var a = i*TAU/8;var b = (i+1)*TAU/8
		var uv = PackedVector2Array([Vector2(.5,.5),Vector2(.5,.5)+Vector2.from_angle(a)*.72,Vector2(.5,.5)+Vector2.from_angle(b)*.72])
		for j in range(uv.size()):uv[j] = uv[j].clamp(Vector2.ZERO,Vector2.ONE)
		var offset = Vector2.from_angle((a+b)*.5)*progress*rect.size.y*.65+Vector2(0,progress*progress*rect.size.y*.3)
		var vertices = PackedVector2Array()
		for p in uv:vertices.append(rect.position+p*rect.size+offset)
		c.draw_polygon(vertices,PackedColorArray([Color(1,1,1,1-progress)]),uv,tex)
