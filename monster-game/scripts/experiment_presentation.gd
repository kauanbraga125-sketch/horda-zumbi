class_name HordeExperimentPresentation
extends RefCounted
# Presentation only. HordeProgress commits the reward once before this queue starts.
var shown_level = 1
var shown_xp = 0.0
var initialized = false
var queue: Array[Dictionary] = []
var current: Dictionary = {}
var elapsed = 0.0
var pending_coins = 0
var changed = ""
func reset(level: int, xp: float) -> void:
	shown_level=level;shown_xp=xp;initialized=true;queue.clear();current={};elapsed=0;pending_coins=0
func busy() -> bool: return not current.is_empty() or not queue.is_empty()
func stage() -> String: return str(current.get("kind","idle"))
func portion() -> float: return clampf(elapsed/maxf(0.01,float(current.get("seconds",1))),0,1)
func award_portion() -> float: return clampf((elapsed-0.15)/1.1,0,1) if stage()=="award" else 0.0
func wallet(actual: int) -> int:
	return maxi(0,actual-pending_coins+(floori(int(current.get("coins",0))*award_portion()) if stage()=="award" else 0))
func enqueue(report: Dictionary) -> void:
	if not initialized or not busy(): reset(int(report.old_level),float(report.old_progress))
	var level = int(report.old_level);var xp = float(report.old_progress);var points = maxi(0,int(report.points));var rewards: Array = report.get("steps",[]);var index = 0
	while level<500 and xp+points>=HordeProgress.level_target(level):
		var target = HordeProgress.level_target(level);var used = target-xp
		queue.append({"kind":"fill","level":level,"from":xp,"to":float(target),"seconds":0.95})
		queue.append({"kind":"react","level":level,"seconds":0.42})
		var reward: Dictionary = rewards[index] if index<rewards.size() else {"coins":0,"eyes":0}
		queue.append({"kind":"award","level":level,"new_level":level+1,"coins":int(reward.coins),"eyes":int(reward.eyes),"seconds":1.5})
		pending_coins+=int(reward.coins)
		queue.append({"kind":"reset","level":level+1,"seconds":0.38})
		points-=int(used);level+=1;xp=0;index+=1
	var end = minf(xp+points,HordeProgress.level_target(level)-1)
	if end>xp: queue.append({"kind":"fill","level":level,"from":xp,"to":end,"seconds":0.85})
func advance(dt: float) -> void:
	changed=""
	var remaining = maxf(0,dt)
	for i in range(80):
		if current.is_empty():
			if queue.is_empty(): return
			current=queue.pop_front();elapsed=0;changed=stage()
			if stage() in ["fill","reset"]: shown_level=int(current.level)
			if stage()=="reset": shown_xp=0
		var step = minf(remaining,float(current.seconds)-elapsed);elapsed+=step;remaining-=step
		if stage()=="fill": shown_xp=lerpf(float(current.from),float(current.to),smoothstep(0,1,portion()))
		if elapsed<float(current.seconds): return
		if stage()=="award": pending_coins-=int(current.coins)
		current={}
		if remaining<=0: return
func amount() -> float: return clampf(shown_xp/HordeProgress.level_target(shown_level),0,1)
func energy() -> float:
	return 1.0 if stage()=="react" else (0.6 if stage()=="award" else (0.28*sin(portion()*PI) if stage()=="fill" else 0.0))
