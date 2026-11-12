extends RefCounted

const ROOT = "res://assets/audio/v167/"
const Orbit = preload("res://scripts/sky_cosmic_vista.gd")
const SKY = ["sky_mist","sky_storm","sky_atmosphere","sky_universe"]
const SPACE = ["space_earth","space_graveyard","space_nest","space_horizon"]
const AMBIENT = ["NEW_mist","NEW_storm","NEW_orbit","NEW_abyss"]
var manifest: Dictionary = {}
var music_cache: Dictionary = {}
var effect_cache: Dictionary = {}
var music_order: Array[String] = []
var effect_order: Array[String] = []
var variants: Dictionary = {}
var mode = ""
var stage = 0

func warm() -> void:
	if manifest.is_empty():manifest = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"manifest.json"))

static func sky_stage(height: float) -> int:
	if Orbit.space_blend(height)>=.56:return 3
	if Orbit.blend(height)>=.66:return 2
	return 1 if height>=3600.0 else 0

static func space_stage(height: float) -> int:
	return 3 if height>=3100.0 else 2 if height>=1900.0 else 1 if height>=850.0 else 0

func choose(run) -> String:
	var next_mode = "sewer" if run.sewer.active else "space" if run.space.active else "sky" if run.sky.active else "ground"
	var height: float = run.sky.altitude if next_mode=="sky" else run.space.altitude
	var target = sky_stage(height) if next_mode=="sky" else space_stage(height)
	if mode!=next_mode:
		mode = next_mode;stage = target
	elif next_mode in ["sky","space"]:
		# A small altitude dead band prevents musical flicker while hovering.
		var below = sky_stage(height-60.0) if mode=="sky" else space_stage(height-30.0)
		var above = sky_stage(height+60.0) if mode=="sky" else space_stage(height+30.0)
		if target>stage and below>=target:stage = target
		elif target<stage and above<=target:stage = target
	match mode:
		"sky":return SKY[stage]
		"space":return SPACE[stage]
		"sewer":return "sewer"
	return "midnight_late" if run.tunnel_number()>=6 else "midnight_run"

func ambient() -> String:
	if mode=="sky":return AMBIENT[stage]
	if mode=="space":return "NEW_orbit" if stage<=1 else "NEW_abyss"
	return ""

func music(key: String) -> AudioStreamOggVorbis:
	warm()
	if not music_cache.has(key):
		music_cache[key] = decode(manifest.music[key])
	music_order.erase(key);music_order.append(key)
	while music_order.size()>3:music_cache.erase(music_order.pop_front())
	return music_cache[key]

func effect(key: String) -> AudioStreamOggVorbis:
	warm()
	var options: Array = manifest.effects[key]
	var index = int(variants.get(key,0))%options.size()
	variants[key] = index+1
	var record: Dictionary = options[index]
	var file: String = record.file
	if not effect_cache.has(file):effect_cache[file] = decode(record)
	effect_order.erase(file);effect_order.append(file)
	while effect_order.size()>12:effect_cache.erase(effect_order.pop_front())
	return effect_cache[file]

static func decode(record: Dictionary) -> AudioStreamOggVorbis:
	var stream = AudioStreamOggVorbis.load_from_buffer(FileAccess.get_file_as_bytes(ROOT+str(record.file)))
	assert(stream!=null,"Invalid compressed audio: "+str(record.file))
	stream.loop = bool(record.loop)
	return stream
