extends RefCounted
## A covered drop, built from the same masonry and portal as ordinary tunnels.
## Street and underground meet at the physical floor; neither scene crossfades.
const PORTAL_BEFORE_EDGE = 300.0
const WALL_HEIGHT = 1350.0
const WALL_TOP = -180.0
var masonry: Texture2D
var lintel: Texture2D
var lintel_region: Rect2
const LINTEL_SEAM = 357.0

func geometry(g,s) -> Dictionary:
	var view = Rect2(g.scenery.view_left,g.scenery.view_top,g.scenery.view_right-g.scenery.view_left,g.scenery.view_bottom-g.scenery.view_top)
	var drop: float = s.entry_drop() if s.active and s.phase=="entry" else 0.0
	var depth: float = s.SHAFT_DEPTH-drop
	var edge: float = s.shore_edge() if s.active else s.encounter.dock_world-g.runner.world_px-s.DOCK_TO_EDGE
	return {"view":view,"street":g.runner.FLOOR-drop,"edge":edge,"depth":depth,"join":view.position.y+depth-20.0}

func texture_window(c,tex: Texture2D,dest: Rect2,window: Rect2,tint: Color = Color.WHITE) -> void:
	var clipped = dest.intersection(window)
	if not clipped.has_area(): return
	var source = Rect2((clipped.position-dest.position)/dest.size*tex.get_size(),clipped.size/dest.size*tex.get_size())
	c.draw_texture_rect_region(tex,clipped,source,tint)

func tunnel_wall(g,window: Rect2,top: float,offset: float,tint: Color = Color.WHITE) -> void:
	if not window.has_area(): return
	if masonry==null:
		var image = Image.new()
		assert(image.load_webp_from_buffer(FileAccess.get_file_as_bytes("res://assets/art/v144/shaft_wall.webp"))==OK)
		masonry = ImageTexture.create_from_image(image)
	var tex: Texture2D = masonry
	var size = tex.get_size()*WALL_HEIGHT/tex.get_height()
	var start = floorf((window.position.x+offset)/size.x)*size.x-offset
	for i in range(ceili(window.size.x/size.x)+2):
		texture_window(g.paint_target,tex,Rect2(start+i*size.x,top,size.x+1,size.y),window,tint)

func approach_background(g,s,edge: float) -> void:
	# A short covered throat uses the actual ordinary-tunnel art and mouth.
	# Its left seam is hidden by the portal, exactly as in the normal run.
	var view: Rect2 = geometry(g,s).view
	var portal = edge-PORTAL_BEFORE_EDGE
	var left = maxf(view.position.x,portal)
	if left>=view.end.x: return
	var window = Rect2(left,view.position.y,view.end.x-left,g.runner.FLOOR-view.position.y)
	tunnel_wall(g,window,WALL_TOP,g.runner.world_px)

func background(g,s,opening_only: bool = false) -> void:
	var p = geometry(g,s)
	var view: Rect2 = p.view
	var left = maxf(view.position.x,float(p.edge)) if opening_only else view.position.x
	var top = maxf(view.position.y,float(p.street))
	var bottom = minf(view.end.y,maxf(float(p.street),float(p.join)))
	if bottom<=top or left>=view.end.x: return
	var window = Rect2(left,top,view.end.x-left,bottom-top)
	# Opaque masonry below the surface, at a fixed scale. No stretched panel,
	# no translucent city behind it, and no underground pixels above the floor.
	g.paint_target.draw_rect(window,Color("100e1c"))
	tunnel_wall(g,window,float(p.street)-g.runner.FLOOR+WALL_TOP,g.runner.world_px)

func gallery_lintel(g,top: float,offset: float) -> void:
	# A real stone ceiling hides the join between the shaft and the gallery.
	# It stays behind the actors and keeps the same pose at the ride handoff.
	if lintel==null:
		var image = Image.new()
		assert(image.load_webp_from_buffer(FileAccess.get_file_as_bytes("res://assets/art/v144/shaft_lintel.webp"))==OK)
		lintel_region = Rect2(0,228,2172,323)
		lintel = ImageTexture.create_from_image(image)
	var view = Rect2(g.scenery.view_left,g.scenery.view_top,g.scenery.view_right-g.scenery.view_left,g.scenery.view_bottom-g.scenery.view_top)
	var scale = 104.0/lintel_region.size.y
	var width = lintel_region.size.x*scale
	var y = top-(LINTEL_SEAM-lintel_region.position.y)*scale
	if y>view.end.y or y+104.0<view.position.y: return
	var start = view.position.x-fposmod(offset,width)-width
	for i in range(ceili(view.size.x/width)+3):
		g.paint_target.draw_texture_rect_region(lintel,Rect2(start+i*width,y,width+1,104.0),lintel_region)

func portal(g,s,edge: float,drop: float = 0.0) -> void:
	var view: Rect2 = geometry(g,s).view
	var x = edge-PORTAL_BEFORE_EDGE
	if x<view.position.x-620 or x>view.end.x+620: return
	var c = g.paint_target
	c.draw_set_transform(Vector2(0,-drop))
	g.scenery.sprite(c,g.art.tunnel_mouths[0],Vector2(x-30,g.runner.FLOOR-215),430)
	c.draw_set_transform(Vector2.ZERO)

func dock_face(g,edge: float,drop: float = 0.0) -> void:
	# The normal terrain pit edge starts at the floor, below running bodies.
	HordeTerrainArt.pit_edge(g,edge,g.runner.FLOOR-drop,false)

func foreground(g,s) -> void:
	var p = geometry(g,s)

	# Debris belongs to the physical opening and stays below its rim.
	var c = g.paint_target
	for i in range(12):
		var t = fposmod(s.phase_age*.45+float(i)*.137,1.0)
		var at = Vector2(float(p.edge)+8+i%4*13,float(p.street)+14+t*t*170)
		c.draw_circle(at,1.4+float(i%3)*.6,Color(.46,.48,.57,(1.0-t)*.48))
