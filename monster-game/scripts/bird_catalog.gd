extends RefCounted
## Collection rules are independent of animation, rendering and the run RNG.
const IDS = ["pipoco","fiapo","ferrugem","agourinho","barao"]
const RARITIES = ["CLÁSSICA","SUPER","HIPER","ULTRA","LENDÁRIA"]
const COLORS = [Color("9ce4aa"),Color("71ded5"),Color("79b8ff"),Color("c994ff"),Color("ffce73")]
const WEIGHTS = [60.0,25.0,10.0,4.0,1.0]
const NAMES = ["PIPOCO","FIAPO","FERRUGEM","AGOURINHO","BARÃO GOELA"]
const PERSONALITIES = ["Uma barriga enorme. Uma fome maior ainda.","Magrelo, medroso e sempre vendo perigo.","Metade corvo. Metade sucata. Inteiro mau humor.","Três olhos. Um segredo. Nenhum pio normal.","Sua excelência exige espaço para a barriga."]
const HINTS = ["Adora ver uma fileira inteira de moedas sumir.","O pescoço estica quando o perigo se aproxima.","Está sempre procurando algo para desmontar.","Não gosta de despedidas definitivas.","Só faz uma entrada triunfal depois de bons saltos."]
const PRICE = 30
const FUSION_PRICE = 500
const ESSENCE_NEEDED = 6

static func defaults() -> Dictionary:
	return {"bird_copies":{},"bird_essence":{},"bird_equipped":"","bird_draws":0,"bird_rare_pity":0,"bird_legend_pity":0,"bird_pending":{},"bird_serial":0}

static func tier(id: String) -> int: return IDS.find(id)

static func copies(data: Dictionary,id: String) -> int:
	return clampi(int(data.get("bird_copies",{}).get(id,0)),0,100000)

static func level(data: Dictionary,id: String) -> int: return mini(3,copies(data,id))

static func migrate(raw: Dictionary) -> Dictionary:
	var safe = defaults()
	for field in ["bird_copies","bird_essence"]:
		if raw.get(field) is Dictionary:
			for id in IDS:
				var value = raw[field].get(id,0)
				if value is int or value is float: safe[field][id] = clampi(int(value),0,100000)
	for key in ["bird_draws","bird_serial","bird_rare_pity","bird_legend_pity"]:
		var value = raw.get(key,0)
		if value is int or value is float: safe[key] = clampi(int(value),0,1000000)
	safe.bird_rare_pity = mini(9,safe.bird_rare_pity);safe.bird_legend_pity = mini(49,safe.bird_legend_pity)
	var equipped = raw.get("bird_equipped","")
	if equipped is String and equipped in IDS and copies(safe,equipped)>0: safe.bird_equipped = equipped
	var receipt = raw.get("bird_pending",{})
	if receipt is Dictionary and receipt.get("id","") in IDS:
		var id = str(receipt.id)
		if copies(safe,id)>0:
			safe.bird_pending = {"id":id,"serial":maxi(1,int(safe.bird_serial)),"level":level(safe,id),"new":bool(receipt.get("new",false)),"essence":clampi(int(receipt.get("essence",0)),0,1),"source":"fusion" if receipt.get("source","")=="fusion" else "draw"}
	return safe

static func add_copy(data: Dictionary,id: String,source: String) -> Dictionary:
	var old = copies(data,id)
	data.bird_copies[id] = mini(100000,old+1)
	var essence = 1 if old>=3 else 0
	if essence: data.bird_essence[id] = mini(100000,int(data.bird_essence.get(id,0))+1)
	if str(data.bird_equipped).is_empty(): data.bird_equipped = id
	data.bird_serial = int(data.bird_serial)+1
	var receipt = {"id":id,"serial":data.bird_serial,"level":level(data,id),"new":old==0,"essence":essence,"source":source}
	data.bird_pending = receipt.duplicate()
	return receipt

static func roll(data: Dictionary,random: RandomNumberGenerator) -> Dictionary:
	# Pending means the item was already paid, awarded and saved: never reroll it.
	if not data.get("bird_pending",{}).is_empty(): return {}
	var price = 0 if int(data.bird_draws)==0 else PRICE
	if int(data.eyes)<price: return {}
	var result = 0
	if int(data.bird_legend_pity)>=49: result = 4
	elif int(data.bird_rare_pity)>=9:
		var n = random.randf()*15.0
		result = 2 if n<10 else 3 if n<14 else 4
	else:
		var n = random.randf()*100.0
		for i in range(5):
			n -= WEIGHTS[i]
			if n<0: result = i;break
	data.eyes = int(data.eyes)-price;data.bird_draws = int(data.bird_draws)+1
	data.bird_rare_pity = 0 if result>=2 else int(data.bird_rare_pity)+1
	data.bird_legend_pity = 0 if result==4 else int(data.bird_legend_pity)+1
	return add_copy(data,IDS[result],"draw")

static func fuse(data: Dictionary,id: String) -> Dictionary:
	var rarity = tier(id)
	if rarity<0 or rarity>=4 or not data.get("bird_pending",{}).is_empty(): return {}
	if int(data.wallet)<FUSION_PRICE or int(data.bird_essence.get(id,0))<ESSENCE_NEEDED: return {}
	data.wallet = int(data.wallet)-FUSION_PRICE
	data.bird_essence[id] = int(data.bird_essence[id])-ESSENCE_NEEDED
	# The initial catalogue has ONE species per tier. Six surplus copies represent
	# two groups of three. Future catalogues may select two different species.
	return add_copy(data,IDS[rarity+1],"fusion")

static func description(index: int,lv: int) -> String:
	var n = clampi(lv,1,3)
	match index:
		0: return "Entrega +%d moeda%s quando você faz um Perfect. Complete a fileira!" % [n,"" if n==1 else "s"]
		1: return "Anuncia uma ameaça a cada %d s. Você ainda precisa desviar." % [22-(n-1)*4]
		2: return "Sabota uma ameaça a cada %d s. Naves e veículos ficam mais fracos." % [30-(n-1)*4]
		3: return "Resgata um membro por partida e o protege por %.1f s. Funciona nos três cenários." % [1.0+(n-1)*.5]
		4: return "A cada %d Perfects, avança contra uma ameaça. Até três ataques por partida." % [6-n]
	return ""
