extends RefCounted
const Catalog = preload("res://scripts/bird_catalog.gd")
static var textures: Dictionary = {}
static var laser_eyes: Array = []

static func ritual_texture() -> Texture2D:
	return special_texture("agourinho_ritual","res://assets/art/v178/agourinho_ritual.webp")

static func portal_texture() -> Texture2D:
	return special_texture("agourinho_portal","res://assets/art/v178/portal.webp")

static func special_texture(key: String,path: String) -> Texture2D:
	if not textures.has(key):
		var im = Image.new();assert(im.load_webp_from_buffer(FileAccess.get_file_as_bytes(path))==OK)
		textures[key] = ImageTexture.create_from_image(im)
	return textures[key]

static func laser_texture() -> Texture2D:
	if not textures.has("ferrugem_laser"):
		var im = Image.new()
		assert(im.load_webp_from_buffer(FileAccess.get_file_as_bytes("res://assets/art/v175/ferrugem_laser.webp"))==OK)
		textures.ferrugem_laser = ImageTexture.create_from_image(im)
		var meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/v175/ferrugem_laser.json"))
		for f in meta.frames:laser_eyes.append(Vector2(f.eye_px[0],f.eye_px[1]))
	return textures.ferrugem_laser

static func laser_frame(phase: String,age: float,progress: float) -> int:
	if phase=="charge":return 0 if progress<.12 else 1 if progress<.32 else 2 if progress<.7 else 3
	if phase=="fire":return 4 if age<.09 else 5
	return 6 if age<.18 else 7

static func laser_pose(point: Vector2,phase: String,age: float,progress: float,aim: float) -> Dictionary:
	var t = smoothstep(0,1,progress) if phase=="charge" else 1-smoothstep(0,.46,age) if phase=="recover" else 1.0
	var kick = sin(clampf(age/.22,0,1)*PI) if phase=="fire" else 0.0
	return {"point":point+Vector2(-4*t-9*kick,-5*t),"size":lerpf(68,88,t),"angle":aim*.28-.08*kick,"stretch":Vector2(1-.05*kick,1+.04*kick)}

static func laser_eye(point: Vector2,phase: String,age: float,progress: float,aim: float) -> Vector2:
	laser_texture()
	var pose = laser_pose(point,phase,age,progress,aim)
	return pose.point+((laser_eyes[laser_frame(phase,age,progress)]/256-Vector2.ONE*.5)*float(pose.size)*Vector2(pose.stretch)).rotated(pose.angle)

static func paint_laser(c,point: Vector2,phase: String,age: float,progress: float,aim: float) -> void:
	var pose = laser_pose(point,phase,age,progress,aim);var index = laser_frame(phase,age,progress)
	c.draw_set_transform(pose.point,pose.angle,pose.stretch)
	c.draw_texture_rect_region(laser_texture(),Rect2(Vector2.ONE*-pose.size*.5,Vector2.ONE*pose.size),Rect2((index%4)*256,int(index/4)*256,256,256))
	c.draw_set_transform(Vector2.ZERO)

static func paint_carrier(c,point: Vector2,height: float,time: float,face: float,lean: float,grab: bool = false,loaded: bool = false) -> void:
	var index = 4 if grab else [0,1,2,1][posmod(int(time*(12 if loaded else 9)),4)]
	var scale_x = maxf(.12,absf(face))*(-1 if face<0 else 1)
	c.draw_set_transform(point,lean,Vector2(scale_x,1))
	c.draw_texture_rect_region(texture("fiapo"),Rect2(Vector2.ONE*-height*.5,Vector2.ONE*height),Rect2(index%3*384,int(index/3)*384,384,384))
	c.draw_set_transform(Vector2.ZERO)

static func spit_texture() -> Texture2D:
	if not textures.has("pipoco_spit"):
		var im = Image.new()
		assert(im.load_webp_from_buffer(FileAccess.get_file_as_bytes("res://assets/art/v172/pipoco_spit.webp"))==OK)
		textures.pipoco_spit = ImageTexture.create_from_image(im)
	return textures.pipoco_spit

static func spit_frame(age: float) -> int:
	if age<.10:return 0
	if age<.23:return 1
	if age<.38:return 2
	if age<.50:return 3
	if age<.61:return 4
	if age<.69:return 5
	if age<.80:return 4
	if age<.91:return 5
	if age<1.08:return 6
	return 7

static func spit_pose(point: Vector2,height: float,age: float) -> Dictionary:
	var charge = smoothstep(0,.43,age)*(1-smoothstep(.49,.59,age))
	var kick = sin(clampf((age-.50)/.16,0,1)*PI)+sin(clampf((age-.69)/.16,0,1)*PI)
	var growth = 1+.10*sin(clampf(age/1.32,0,1)*PI)
	return {"point":point+Vector2(-9*charge-7*kick,-4*charge),"angle":-.12*charge+.07*kick,"size":height*growth,"stretch":Vector2(1+.055*charge-.06*kick,1-.045*charge+.04*kick)}

static func spit_mouth(point: Vector2,age: float,height: float) -> Vector2:
	var pose = spit_pose(point,height,age)
	var mouths = [Vector2(200.14,113.41),Vector2(203.23,112.54),Vector2(195.55,109.78),Vector2(176.10,134.93),Vector2(201.08,135.20),Vector2(201.25,137.88),Vector2(196.69,150.71),Vector2(199.56,132.46)]
	return pose.point+((mouths[spit_frame(age)]/256.0-Vector2.ONE*.5)*float(pose.size)*Vector2(pose.stretch)).rotated(pose.angle)

static func paint_spit(c,point: Vector2,height: float,age: float) -> void:
	var pose = spit_pose(point,height,age);var index = spit_frame(age)
	c.draw_set_transform(pose.point,pose.angle,pose.stretch)
	c.draw_texture_rect_region(spit_texture(),Rect2(Vector2.ONE*-pose.size*.5,Vector2.ONE*pose.size),Rect2((index%4)*256,int(index/4)*256,256,256))
	c.draw_set_transform(Vector2.ZERO)

static func texture(id: String) -> Texture2D:
	if not textures.has(id):
		var im = Image.new()
		var path = "res://assets/art/v176/ferrugem_idle.webp" if id=="ferrugem" else "res://assets/art/v136/"+id+".webp"
		if id=="agourinho":path = "res://assets/art/v177/agourinho.webp"
		assert(im.load_webp_from_buffer(FileAccess.get_file_as_bytes(path))==OK)
		textures[id] = ImageTexture.create_from_image(im)
	return textures[id]

static func prop(c,id: String,point: Vector2,height: float,angle: float = 0,tint: Color = Color.WHITE) -> void:
	var tex = texture(id);var size = tex.get_size()*height/tex.get_height()
	c.draw_set_transform(point,angle)
	c.draw_texture_rect(tex,Rect2(-size*.5,size),false,tint)
	c.draw_set_transform(Vector2.ZERO)

static func frame(index: int,time: float,emotion: String = "") -> int:
	if emotion=="ability": return 5
	if emotion=="hurt": return 4
	if fposmod(time+index*.73,6.5)>.6 and fposmod(time+index*.73,6.5)<.82: return 3
	return [0,1,2,1][posmod(int(time*([7.5,6.0,9.0,5.5,9.5][clampi(index,0,4)])),4)]

static func paint(c,id: String,point: Vector2,height: float,time: float,emotion: String = "",tint: Color = Color.WHITE) -> void:
	var index = Catalog.tier(id)
	if index<0: return
	if id in ["ferrugem","agourinho"]:
		# Match the old body/eye placement while leaving room for complete wings.
		point += Vector2(.04,.055)*height;height *= 1.14
	var f = frame(index,time,emotion)
	var source = Rect2((f%3)*384,int(f/3)*384,384,384)
	var bob = sin(time*(3.3 if index==4 else 4.7)+index)*height*.024
	var angle = sin(time*2.1+index)*.035
	var stretch = Vector2.ONE
	if index==4: stretch = Vector2(1+sin(time*5)*.014,1-sin(time*5)*.014)
	if emotion=="ability": stretch *= 1+sin(clampf(time,0,1)*PI)*.06
	c.draw_set_transform(point+Vector2(0,bob),angle,stretch)
	if id=="agourinho" and emotion.is_empty() and f!=3:
		var flap = time*6.6;var order = [0,1,2,1];var a = order[posmod(floori(flap),4)];var b = order[posmod(floori(flap)+1,4)]
		var blend = smoothstep(.55,1,fposmod(flap,1))
		c.draw_texture_rect_region(texture(id),Rect2(Vector2.ONE*-height*.5,Vector2.ONE*height),Rect2(a%3*384,int(a/3)*384,384,384),tint*Color(1,1,1,1-blend))
		if blend>.001:c.draw_texture_rect_region(texture(id),Rect2(Vector2.ONE*-height*.5,Vector2.ONE*height),Rect2(b%3*384,int(b/3)*384,384,384),tint*Color(1,1,1,blend))
	else:c.draw_texture_rect_region(texture(id),Rect2(Vector2.ONE*-height*.5,Vector2.ONE*height),source,tint)
	c.draw_set_transform(Vector2.ZERO)
