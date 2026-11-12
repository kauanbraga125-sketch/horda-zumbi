extends RefCounted

const ART = "res://assets/art/v163/mountains.webp"
const PROFILE = "res://assets/art/v163/ridge.json"
const RIDGE = Rect2(-1700,-1380,3600,1200)
const RIDGE_DEPTH = Vector2(.025,1.0)
const GIANT_START_X = 1165.0
const GIANT_SPEED = 6.0
static var texture: Texture2D
static var skyline: Array = []

static func warm() -> void:
	if texture != null: return
	# Raw WebP and JSON are explicitly included in Android exports.
	var image = Image.load_from_file(ART)
	assert(image != null and not image.is_empty())
	texture = ImageTexture.create_from_image(image)

static func ridge_height(x: float) -> float:
	if skyline.is_empty():
		skyline = JSON.parse_string(FileAccess.get_file_as_string(PROFILE)).skyline
	var sample = clampf((x-RIDGE.position.x)/RIDGE.size.x,0.0,1.0)*float(skyline.size()-1)
	var index = floori(sample)
	var v = lerpf(float(skyline[index]),float(skyline[mini(index+1,skyline.size()-1)]),sample-float(index))
	return RIDGE.position.y+v*RIDGE.size.y

static func project(anchor: Vector2, view: Rect2, camera: Vector2, depth: Vector2) -> Vector2:
	return view.position+anchor-camera*depth

static func walker_anchor(time: float) -> Vector2:
	# The path is measured from the painted mountain's actual silhouette.
	# Its altitude changes only with terrain underfoot, never with the camera.
	var x = maxf(350.0,GIANT_START_X-time*GIANT_SPEED)
	return Vector2(x,ridge_height(x))

static func walker_position(view: Rect2, camera: Vector2, time: float) -> Vector2:
	return project(walker_anchor(time),view,camera,RIDGE_DEPTH)

static func paint(canvas: Node2D, motion, view: Rect2, camera: Vector2, time: float, alpha: float) -> void:
	if alpha <= .01: return
	warm()
	# Three altitudes and horizontal speeds create depth. The walker and its
	# ridge share full vertical projection: they leave view as the horde rises.
	paint_range(canvas,view,camera,Rect2(-1150,-470,3600,1200),Vector2(.008,.42),Color(.55,.52,.71,alpha*.43))
	paint_range(canvas,view,camera,Rect2(-800,-720,3200,1067),Vector2(.015,.68),Color(.58,.53,.73,alpha*.57))
	paint_range(canvas,view,camera,RIDGE,RIDGE_DEPTH,Color(.66,.61,.81,alpha*.76))
	var foot = walker_position(view,camera,time)
	if foot.y > view.position.y-150 and foot.y < view.end.y+150:
		for i in range(4):
			var point = Vector2(view.position.x+float(i)*510.0+sin(time*.12+i)*27.0,foot.y+70.0+float(i%2)*32.0)
			motion.sprite(canvas,"mist_far",point,450.0,Color(.65,.59,.81,alpha*.22))

static func paint_range(canvas: Node2D, view: Rect2, camera: Vector2, plane: Rect2, depth: Vector2, tint: Color) -> void:
	var rect = Rect2(project(plane.position,view,camera,depth),plane.size)
	if not rect.intersects(view): return
	# Fade only the foot of the range; preserve the painted peaks and cliffs.
	var bands = [0.0,.66,.82,1.0]
	var opacity = [1.0,1.0,.60,0.0]
	for i in range(bands.size()-1):
		var y0 = rect.position.y+rect.size.y*bands[i]
		var y1 = rect.position.y+rect.size.y*bands[i+1]
		var points = PackedVector2Array([Vector2(rect.position.x,y0),Vector2(rect.end.x,y0),Vector2(rect.end.x,y1),Vector2(rect.position.x,y1)])
		var uv = PackedVector2Array([Vector2(0,bands[i]),Vector2(1,bands[i]),Vector2(1,bands[i+1]),Vector2(0,bands[i+1])])
		var upper = Color(tint,tint.a*opacity[i])
		var lower = Color(tint,tint.a*opacity[i+1])
		canvas.draw_polygon(points,PackedColorArray([upper,upper,lower,lower]),uv,texture)

static func contact_shadow(canvas: Node2D, foot: Vector2, alpha: float) -> void:
	canvas.draw_set_transform(foot+Vector2(0,2),0,Vector2(49,3.0))
	canvas.draw_circle(Vector2.ZERO,1.0,Color(.20,.17,.29,alpha*.27),true,-1,true)
	canvas.draw_set_transform(Vector2.ZERO)
