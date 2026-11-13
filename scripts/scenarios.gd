class_name Scenarios
extends RefCounted
## Oyunun verisi: birim sınıfları, ülkeler ve envanterleri, doktrinler, araştırmalar, haritalar, senaryolar.
## Denge buradan ayarlanır.

static var chosen := 0     # seçilen senaryo
static var side := 0       # oyuncunun tarafı: 0 = a ülkesi, 1 = b ülkesi
static var difficulty := 0   # Defs.DIFFS içindeki sıra
static var mode := 0         # Defs.MODES içindeki sıra (teke tek, iki düşman üssü, takım)
static var tutorial := false
static var load_data := {}  # boş değilse kayıtlı oyun yüklenir

# ---------------------------------------------------------------- birim sınıfları
# armor: inf / light / heavy / bld / air (büyük hava aracı) / drone (küçük İHA)
# mult: zırh sınıfına göre hasar çarpanı. Listede olmayan sınıfa ateş edilemez.
# from: üretildiği bina türü.  home: silahlanmak için döndüğü bina türü.
const CLASSES := {
	"inf": {
		cat = "kara", from = "kisla", cost = 150, time = 10.0, tier = 1,
		hp = 260, speed = 3.4, vision = 14.0, radius = 1.0, armor = "inf",
		range = 8.0, dmg = 10.0, cd = 0.5, proj = "tracer",
		mult = {inf = 1.0, light = 0.6, heavy = 0.15, bld = 0.3, drone = 0.25},
		capture = true,
	},
	"at": {
		cat = "kara", from = "kisla", cost = 220, time = 12.0, tier = 1,
		hp = 180, speed = 3.4, vision = 14.0, radius = 0.9, armor = "inf",
		range = 12.0, dmg = 70.0, cd = 3.0, proj = "missile",
		mult = {inf = 0.15, light = 1.3, heavy = 1.6, bld = 0.5},
	},
	"ifv": {
		cat = "kara", from = "fabrika", cost = 380, time = 14.0, tier = 1,
		hp = 620, speed = 5.2, vision = 15.0, radius = 1.4, armor = "light",
		range = 9.0, dmg = 16.0, cd = 0.4, proj = "tracer",
		mult = {inf = 1.2, light = 0.8, heavy = 0.35, bld = 0.4, drone = 0.3},
	},
	"tank": {
		cat = "kara", from = "fabrika", cost = 700, time = 22.0, tier = 1,
		hp = 1100, speed = 4.2, vision = 14.0, radius = 1.5, armor = "heavy",
		range = 10.5, dmg = 75.0, cd = 2.2, proj = "shell",
		mult = {inf = 0.8, light = 1.2, heavy = 1.0, bld = 1.0},
	},
	"arty": {
		cat = "kara", from = "fabrika", cost = 900, time = 28.0, tier = 2,
		hp = 520, speed = 3.0, vision = 12.0, radius = 1.6, armor = "light",
		range = 34.0, min_range = 9.0, dmg = 110.0, cd = 5.0, proj = "arc", splash = 3.5, no_chase = true,
		mult = {inf = 0.8, light = 0.7, heavy = 0.6, bld = 1.6},
	},
	"mlrs": {
		cat = "kara", from = "fabrika", cost = 1100, time = 30.0, tier = 2,
		hp = 420, speed = 3.6, vision = 12.0, radius = 1.6, armor = "light",
		range = 42.0, min_range = 12.0, dmg = 95.0, cd = 8.0, proj = "arc", splash = 7.5, no_chase = true,
		mult = {inf = 1.2, light = 1.0, heavy = 0.4, bld = 1.2},
	},
	"spaag": {
		cat = "hs", from = "fabrika", cost = 550, time = 18.0, tier = 1,
		hp = 560, speed = 4.2, vision = 14.0, radius = 1.5, armor = "light",
		range = 14.0, dmg = 22.0, cd = 0.35, proj = "tracer",
		mult = {air = 0.6, drone = 1.0},
	},
	"laser": {
		cat = "hs", from = "fabrika", cost = 1400, time = 35.0, tier = 3,
		hp = 500, speed = 3.6, vision = 16.0, radius = 1.5, armor = "light",
		range = 18.0, dmg = 60.0, cd = 0.6, proj = "beam",
		mult = {air = 0.5, drone = 3.0},
	},
	"ew": {
		cat = "hs", from = "fabrika", cost = 650, time = 20.0, tier = 1,
		hp = 480, speed = 4.0, vision = 16.0, radius = 1.5, armor = "light", ew = 16.0,
	},
	# ---- küçük İHA'lar: kışladan çıkar, elden atılır
	"sdrone_recon": {
		cat = "hava", from = "kisla", cost = 120, time = 8.0, tier = 1, air = true, small = true, alt = 4.0,
		hp = 40, speed = 6.0, vision = 19.0, radius = 0.6, armor = "drone", icon_r = 1.1,
	},
	"sdrone_fpv": {
		cat = "hava", from = "kisla", cost = 200, time = 10.0, tier = 1, air = true, small = true, alt = 3.5,
		count = 3, pop = 0, life = 70.0, kamikaze = true, tag = "drone",
		hp = 25, speed = 7.5, vision = 11.0, radius = 0.5, armor = "drone", icon_r = 1.0,
		dmg = 130.0, mult = {inf = 0.8, light = 1.2, heavy = 0.8, bld = 0.3},
	},
	"sdrone_bomb": {
		cat = "hava", from = "kisla", cost = 320, time = 14.0, tier = 1, air = true, small = true, alt = 4.5,
		home = "kisla", tag = "drone",
		hp = 70, speed = 5.0, vision = 13.0, radius = 0.8, armor = "drone", icon_r = 1.5,
		range = 3.0, dmg = 90.0, cd = 2.0, proj = "arc", splash = 2.5, ammo = 2, rearm = 8.0,
		mult = {inf = 1.2, light = 1.0, heavy = 0.6, bld = 0.5},
	},
	"loiter": {
		cat = "hava", from = "kisla", cost = 260, time = 12.0, tier = 1, air = true, small = true, alt = 5.0,
		pop = 0, life = 110.0, kamikaze = true, tag = "drone",
		hp = 35, speed = 8.5, vision = 15.0, radius = 0.6, armor = "drone", icon_r = 1.2,
		dmg = 280.0, mult = {inf = 0.4, light = 1.3, heavy = 1.0, bld = 0.4},
	},
	# ---- büyük İHA'lar: hava alanı gerekir
	"uav_recon": {
		cat = "hava", from = "havaalani", cost = 450, time = 18.0, tier = 2, air = true, alt = 9.0,
		hp = 260, speed = 8.0, vision = 30.0, radius = 1.6, armor = "air", icon_r = 3.4,
	},
	"uav_strike": {
		cat = "hava", from = "havaalani", cost = 800, time = 26.0, tier = 2, air = true, alt = 9.0, tag = "drone",
		hp = 220, speed = 7.0, vision = 17.0, radius = 1.4, armor = "air", icon_r = 2.9,
		range = 11.0, dmg = 160.0, cd = 3.5, proj = "missile", ammo = 2, rearm = 10.0,
		mult = {inf = 0.6, light = 1.2, heavy = 1.0, bld = 0.8},
	},
	"uav_heavy": {
		cat = "hava", from = "havaalani", cost = 1300, time = 34.0, tier = 2, air = true, alt = 9.5, tag = "drone",
		hp = 340, speed = 7.5, vision = 21.0, radius = 1.6, armor = "air", icon_r = 3.6,
		range = 13.0, dmg = 190.0, cd = 3.0, proj = "missile", ammo = 4, rearm = 14.0,
		mult = {inf = 0.6, light = 1.2, heavy = 1.1, bld = 1.0},
	},
	"uav_kami": {
		cat = "hava", from = "havaalani", cost = 320, time = 12.0, tier = 2, air = true, alt = 7.0,
		pop = 0, kamikaze = true, tag = "drone", leash = 30.0,
		hp = 90, speed = 6.5, vision = 14.0, radius = 1.0, armor = "air", icon_r = 2.0,
		dmg = 380.0, splash = 3.0, mult = {inf = 0.6, light = 1.0, heavy = 0.6, bld = 1.5},
	},
	# ---- uçaklar: hava alanı gerekir, pist sayısı sınırlar
	"fighter": {
		cat = "hava", from = "havaalani", cost = 1500, time = 35.0, tier = 2, air = true, alt = 11.0,
		hp = 420, speed = 13.0, turn = 2.4, vision = 22.0, radius = 1.8, armor = "air", icon_r = 3.2,
		range = 15.0, dmg = 130.0, cd = 2.0, proj = "missile", ammo = 4, rearm = 14.0,
		mult = {air = 1.2, drone = 0.3, inf = 0.4, light = 1.0, heavy = 0.9, bld = 0.9},
	},
	"striker": {
		cat = "hava", from = "havaalani", cost = 1800, time = 40.0, tier = 2, air = true, alt = 11.0,
		hp = 520, speed = 12.0, turn = 2.2, vision = 22.0, radius = 1.9, armor = "air", icon_r = 3.5,
		range = 14.0, dmg = 260.0, cd = 2.5, proj = "missile", splash = 3.0, ammo = 3, rearm = 16.0,
		mult = {inf = 0.8, light = 1.2, heavy = 1.1, bld = 1.4},
	},
	"stealth": {
		cat = "hava", from = "havaalani", cost = 2600, time = 50.0, tier = 3, air = true, alt = 11.5, stealth = true,
		hp = 450, speed = 14.0, turn = 2.4, vision = 24.0, radius = 1.8, armor = "air", icon_r = 3.2,
		range = 16.0, dmg = 220.0, cd = 2.0, proj = "missile", ammo = 4, rearm = 16.0,
		mult = {air = 1.3, drone = 0.3, inf = 0.5, light = 1.1, heavy = 1.0, bld = 1.3},
	},
}

# ---------------------------------------------------------------- binalar (bütün ülkelerde ortak)
# power: artı ise üretir, eksi ise tüketir
const BUILDING_KINDS := {
	"hq": {name = "Karargâh", hp = 8000, vision = 20.0, radius = 5.5, power = 2},
	"santral": {name = "Santral", cost = 300, time = 15.0, tier = 1, hp = 900, vision = 10.0, radius = 3.0, power = 3},
	"maden": {name = "Maden Ocağı", cost = 1600, time = 40.0, tier = 1, hp = 1400, vision = 12.0, radius = 3.2, field = true, deposit = true},
	"ileri": {name = "İleri Harekât Üssü", cost = 900, time = 25.0, tier = 1, hp = 1500, vision = 16.0, radius = 3.6, field = true},
	"kisla": {name = "Kışla", cost = 300, time = 15.0, tier = 1, hp = 1200, vision = 12.0, radius = 3.2},
	"fabrika": {name = "Fabrika", cost = 600, time = 22.0, tier = 1, hp = 1500, vision = 12.0, radius = 3.6, power = -1},
	"havaalani": {name = "Hava Alanı", cost = 900, time = 30.0, tier = 2, hp = 1600, vision = 14.0, radius = 6.0, power = -2},
	"sam": {
		name = "Hava Savunma", cost = 700, time = 20.0, tier = 2, hp = 800, vision = 14.0, radius = 2.2, power = -1,
		cls = "sam", range = 26.0, dmg = 140.0, cd = 3.0, proj = "missile", mult = {air = 1.0},
	},
	"teknoloji": {name = "Teknoloji Merkezi", cost = 800, time = 30.0, tier = 2, hp = 1000, vision = 12.0, radius = 3.4, power = -1},
	"engel": {name = "Tanksavar Engeli", cost = 150, time = 6.0, tier = 1, hp = 1400, vision = 4.0, radius = 2.0, field = true},
	"fuze": {name = "Füze Üssü", cost = 1200, time = 35.0, tier = 3, hp = 900, vision = 12.0, radius = 3.2, power = -2},
}

# ---------------------------------------------------------------- doktrinler
# mods anahtarları: cost_<sınıf>, hp_<sınıf>, dmg_<sınıf>, range_<sınıf>, rearm, missile_cost, missile_cd, pop_cap, drone_resist
# Doktrin, ülkenin savaş tarzını fiyatla dayatır: doktrine uyan birimler çok ucuz, uymayanlar cezalı pahalıdır.
const DOCTRINES := {
	"hava": {
		name = "Hava Üstünlüğü", desc = "Uçaklar %30 ucuz ve hızlı silahlanır, İHA'lar ucuz. Tank ve topçu %35-40 pahalı.",
		mods = {cost_fighter = 0.7, cost_striker = 0.7, cost_stealth = 0.75, cost_uav_recon = 0.85, cost_uav_strike = 0.85,
			cost_uav_heavy = 0.85, rearm = 0.7, cost_tank = 1.35, cost_arty = 1.4, cost_mlrs = 1.4, cost_ifv = 1.2,
			cost_sdrone_fpv = 1.3, cost_sdrone_bomb = 1.3},
		ability = {id = "ikmal", name = "Havada Yakıt İkmali", cost = 800, cd = 150.0, tier = 2, target = false,
			desc = "60 saniye boyunca uçakların mühimmatı havada yenilenir ve %20 hızlı uçarlar: üsse dönmeden uzun devriye."},
	},
	"iha": {
		name = "İHA Doktrini", desc = "Küçük dronlar %40, büyük İHA'lar %30 ucuz. Tank yok; zırhlı, topçu ve uçaklar %30-60 pahalı.",
		mods = {cost_sdrone_recon = 0.6, cost_sdrone_fpv = 0.6, cost_sdrone_bomb = 0.6, cost_loiter = 0.6,
			cost_uav_recon = 0.7, cost_uav_strike = 0.7, cost_uav_kami = 0.7, cost_uav_heavy = 0.7,
			cost_ifv = 1.3, cost_arty = 1.3, cost_mlrs = 1.3, cost_spaag = 1.2, cost_tank = 1.6,
			cost_fighter = 1.5, cost_striker = 1.6, cost_stealth = 1.6},
		ability = {id = "suru", name = "Sürü Saldırısı", cost = 600, cd = 120.0, tier = 1, target = true,
			desc = "Görülen bir noktaya, en yakın birliğinden 8 FPV dronu birden fırlatır. Hava savunmasını doyurur."},
	},
	"zirh": {
		name = "Zırhlı / Topçu", desc = "Tank ve topçu %20-25 ucuz ve daha dayanıklı. Dronlar ve İHA'lar %40 pahalı.",
		mods = {hp_tank = 1.2, hp_arty = 1.2, hp_mlrs = 1.2, cost_tank = 0.75, cost_arty = 0.8, cost_mlrs = 0.8, cost_ifv = 0.85,
			cost_sdrone_recon = 1.3, cost_sdrone_fpv = 1.4, cost_loiter = 1.4, cost_uav_strike = 1.4, cost_uav_kami = 1.4,
			cost_uav_heavy = 1.4, cost_fighter = 1.15, cost_striker = 1.1},
		ability = {id = "baraj", name = "Topçu Barajı", cost = 700, cd = 120.0, tier = 1, target = true,
			desc = "Görülen bir alana 7 saniye boyunca 14 ağır top mermisi yağdırır. Siperleri ve toplu piyadeyi dağıtır."},
	},
	"fuze": {
		name = "Balistik Füze", desc = "Füzeler %40 ucuz, çabuk hazır; Füze Üssü Kademe 2'de açılır. Kamikaze İHA'lar ucuz. Zırhlı ve uçaklar %35-40 pahalı.",
		mods = {missile_cost = 0.6, missile_cd = 0.6, cost_uav_kami = 0.7, cost_sdrone_fpv = 0.8, cost_loiter = 0.85,
			hp_tank = 0.9, hp_ifv = 0.9, cost_tank = 1.35, cost_ifv = 1.2, cost_fighter = 1.4, cost_striker = 1.4, cost_stealth = 1.4},
		ability = {id = "salvo", name = "Doyurma Salvosu", cost = 1600, cd = 180.0, tier = 2, target = true,
			desc = "Görülen bir noktaya aynı anda 4 balistik füze atar. Her hava savunma bataryası en çok birini önleyebilir."},
	},
	"denge": {
		name = "Dengeli / İnsan Gücü", desc = "Piyade %35, tanksavar %25 ucuz, birlik sınırı yüksek. Pahalı doktrin cezası yok.",
		mods = {cost_inf = 0.65, cost_at = 0.75, cost_ifv = 0.9, pop_cap = 12.0},
		ability = {id = "seferberlik", name = "Seferberlik", cost = 400, cd = 150.0, tier = 1, target = false,
			desc = "Karargâhın yanında anında 4 piyade mangası toplar (birlik sınırı izin verdiği kadar)."},
	},
}

# ---------------------------------------------------------------- araştırmalar (Teknoloji Merkezi)
const RESEARCH := [
	{id = "fiber", name = "Fiber Optik FPV", cost = 600, time = 30.0, desc = "FPV dronları elektronik harpten etkilenmez", mods = {}},
	{id = "kafes", name = "Drone Kafesi", cost = 600, time = 30.0, desc = "Araçlar İHA hasarını %40 az alır", mods = {drone_resist = 0.6}},
	{id = "eh", name = "Elektronik Harp", cost = 700, time = 35.0, desc = "Hava savunma araçları %40 daha çok hasar verir", mods = {dmg_spaag = 1.4, dmg_laser = 1.4}},
	{id = "gudum", name = "Güdümlü Mermi", cost = 700, time = 35.0, desc = "Topçu hasarı +%25", mods = {dmg_arty = 1.25, dmg_mlrs = 1.25}},
	{id = "yz", name = "YZ Hedef Tanıma", cost = 700, time = 35.0, desc = "İHA hasarı +%25", mods = {dmg_uav_strike = 1.25, dmg_uav_heavy = 1.25, dmg_sdrone_fpv = 1.25, dmg_loiter = 1.25, dmg_uav_kami = 1.25}},
	{id = "aps", name = "Aktif Koruma", cost = 800, time = 40.0, desc = "Tank canı +%20", mods = {hp_tank = 1.2}},
	{id = "aesa", name = "AESA Radar", cost = 800, time = 40.0, desc = "Uçak ve hava savunma menzili +%20", mods = {range_sam = 1.2, range_fighter = 1.2, range_stealth = 1.2}},
]

# ---------------------------------------------------------------- ülkeler
# units: [kısa kimlik, ad, sınıf, model, değişen değerler]
const COUNTRIES := {
	"ua": {
		name = "Ukrayna", doctrine = "iha", body = Color(0.33, 0.4, 0.25), air = Color(0.55, 0.6, 0.66),
		sam = ["Patriot", "sam_box"],
		missiles = [{name = "Hrim-2", cost = 1300, cd = 70.0, dmg = 900.0, splash = 7.0, tier = 3}],
		units = [
			["inf", "Piyade Mangası", "inf", "inf", {}],
			["at", "Javelin Timi", "at", "at", {}],
			["ew", "Bukovel-AD", "ew", "ew_truck", {}],
			["mavic", "DJI Mavic 3", "sdrone_recon", "quad", {}],
			["fpv", "FPV Kamikaze", "sdrone_fpv", "quad", {}],
			["baba", "Baba Yaga", "sdrone_bomb", "hexa", {}],
			["sb600", "Switchblade 600", "loiter", "xwing", {}],
			["bradley", "M2 Bradley", "ifv", "ifv_tall", {}],
			["gepard", "Gepard", "spaag", "gepard", {}],
			["bohdana", "2S22 Bohdana", "arty", "truck_gun", {}],
			["himars", "M142 HIMARS", "mlrs", "himars", {}],
			["tb2", "Bayraktar TB2", "uav_strike", "tb2", {}],
			["liutyi", "AN-196 Liutyi", "uav_kami", "liutyi", {}],
			["f16", "F-16", "fighter", "f16", {}],
			["mirage", "Mirage 2000-5", "fighter", "mirage", {}],
			["tryzub", "Tryzub Lazer", "laser", "laser_truck", {}],
			["peklo", "Peklo Füze-Drone", "uav_kami", "liutyi", {tier = 3, dmg = 420.0, speed = 10.0, hp = 110, cost = 700}],
		],
	},
	"ru": {
		name = "Rusya", doctrine = "zirh", body = Color(0.25, 0.32, 0.22), air = Color(0.42, 0.5, 0.6),
		sam = ["S-400", "sam_tube"],
		missiles = [{name = "İskender-M", cost = 1300, cd = 70.0, dmg = 950.0, splash = 7.0, tier = 3}],
		units = [
			["inf", "Motorize Piyade", "inf", "inf", {}],
			["at", "Kornet Timi", "at", "at", {}],
			["ew", "Silok", "ew", "ew_truck", {}],
			["orlan", "Orlan-10", "sdrone_recon", "small_plane", {}],
			["fpv", "FPV Kamikaze", "sdrone_fpv", "quad", {}],
			["lancet", "Lancet-3", "loiter", "xwing", {}],
			["bmp3", "BMP-3", "ifv", "ifv_low", {}],
			["t72", "T-72B3", "tank", "tank_ru", {}],
			["t90", "T-90M", "tank", "tank_ru2", {cost = 850, hp = 1300, tier = 2}],
			["pantsir", "Pantsir-S1", "spaag", "pantsir", {}],
			["msta", "2S19 Msta-S", "arty", "sph", {}],
			["tos", "TOS-1A", "mlrs", "tos", {range = 22.0, min_range = 6.0, dmg = 150.0, splash = 8.5, cost = 1000}],
			["tornado", "Tornado-S", "mlrs", "mlrs_truck", {}],
			["orion", "Orion", "uav_strike", "vtail", {}],
			["geran", "Geran-2", "uav_kami", "shahed", {}],
			["su35", "Su-35", "fighter", "su35", {}],
			["su34", "Su-34", "striker", "su34", {}],
			["su57", "Su-57", "stealth", "su57", {}],
			["s70", "S-70 Okhotnik-B", "uav_heavy", "flyingwing", {tier = 3, stealth = true, cost = 1900, hp = 420}],
			["t14", "T-14 Armata", "tank", "tank_ru2", {tier = 3, hp = 1450, cost = 1100}],
		],
	},
	"il": {
		name = "İsrail", doctrine = "hava", body = Color(0.5, 0.47, 0.36), air = Color(0.6, 0.62, 0.64),
		sam = ["David's Sling", "sam_box"],
		missiles = [{name = "LORA", cost = 1300, cd = 70.0, dmg = 900.0, splash = 6.5, tier = 3}],
		units = [
			["inf", "Piyade Mangası", "inf", "inf", {}],
			["at", "Spike Timi", "at", "at", {}],
			["ew", "Drone Dome", "ew", "ew_truck", {}],
			["orbiter", "Orbiter", "sdrone_recon", "small_plane", {}],
			["hero", "Hero-30", "loiter", "xwing", {}],
			["namer", "Namer", "ifv", "namer", {hp = 760, cost = 440}],
			["merkava", "Merkava Mk 4", "tank", "tank_merkava", {hp = 1250, cost = 780}],
			["irondome", "Iron Dome", "spaag", "irondome", {speed = 3.2, dmg = 65.0, cd = 1.0, proj = "missile", range = 17.0}],
			["atmos", "ATMOS 2000", "arty", "truck_gun", {}],
			["eitan", "Heron TP", "uav_recon", "twinboom", {}],
			["hermes", "Hermes 900", "uav_strike", "vtail", {}],
			["harop", "Harop", "uav_kami", "harop", {}],
			["f16i", "F-16I Sufa", "fighter", "f16", {}],
			["f15i", "F-15I Ra'am", "striker", "f15", {}],
			["f35i", "F-35I Adir", "stealth", "f35", {}],
			["ironbeam", "Iron Beam", "laser", "laser_truck", {}],
			["barak", "Merkava Barak", "tank", "tank_merkava", {tier = 3, hp = 1450, cost = 1100}],
		],
	},
	"ir": {
		name = "İran", doctrine = "fuze", body = Color(0.6, 0.52, 0.38), air = Color(0.62, 0.6, 0.55),
		sam = ["Bavar-373", "sam_tube"],
		missiles = [
			{name = "Fateh-110", cost = 800, cd = 45.0, dmg = 600.0, splash = 6.0, tier = 2},
			{name = "Sejjil", cost = 1500, cd = 80.0, dmg = 1100.0, splash = 8.0, tier = 3},
			{name = "Fattah-2", cost = 2400, cd = 110.0, dmg = 1200.0, splash = 7.0, tier = 3, hypersonic = true},
		],
		units = [
			["inf", "Piyade Mangası", "inf", "inf", {}],
			["at", "Dehlaviyeh Timi", "at", "at", {}],
			["ew", "Kobra V8", "ew", "ew_truck", {}],
			["ababil2", "Ababil-2", "sdrone_recon", "small_plane", {}],
			["meraj", "Meraj-521", "loiter", "xwing", {}],
			["shahed131", "Shahed-131", "sdrone_fpv", "shahed_s", {count = 2, dmg = 170.0, cost = 220}],
			["boragh", "Boragh", "ifv", "m113", {}],
			["karrar", "Karrar", "tank", "tank_ru2", {}],
			["tor", "Tor-M1", "spaag", "tor", {proj = "missile", dmg = 60.0, cd = 1.0}],
			["raad", "Raad-2", "arty", "sph", {}],
			["fajr", "Fajr-5", "mlrs", "mlrs_truck", {}],
			["mohajer6", "Mohajer-6", "uav_strike", "mohajer6", {}],
			["shahed129", "Shahed-129", "uav_heavy", "vtail", {}],
			["shahed136", "Shahed-136", "uav_kami", "shahed", {}],
			["f14", "F-14A Tomcat", "fighter", "f14", {}],
			["mig29", "MiG-29", "fighter", "mig29", {}],
			["shahed238", "Shahed-238 (jet)", "uav_kami", "shahed", {tier = 3, dmg = 440.0, speed = 11.0, hp = 110, cost = 700}],
		],
	},
	"pk": {
		name = "Pakistan", doctrine = "fuze", body = Color(0.5, 0.5, 0.36), air = Color(0.55, 0.58, 0.6),
		sam = ["HQ-9/P", "sam_tube"],
		missiles = [
			{name = "Nasr", cost = 700, cd = 40.0, dmg = 500.0, splash = 6.0, tier = 2},
			{name = "Shaheen-II", cost = 1500, cd = 80.0, dmg = 1100.0, splash = 8.0, tier = 3},
			{name = "Fatah-IV", cost = 2200, cd = 100.0, dmg = 1000.0, splash = 6.0, tier = 3, hypersonic = true},
		],
		units = [
			["inf", "Piyade Mangası", "inf", "inf", {}],
			["at", "Baktar-Shikan Timi", "at", "at", {}],
			["ew", "EH Karıştırıcı", "ew", "ew_truck", {}],
			["uqab", "Uqab", "sdrone_recon", "small_plane", {}],
			["talha", "Talha", "ifv", "m113", {}],
			["alkhalid", "Al-Khalid", "tank", "tank_ru2", {}],
			["vt4", "VT-4 Haider", "tank", "tank_leo", {cost = 850, hp = 1300, tier = 2}],
			["fm90", "FM-90", "spaag", "tor", {proj = "missile", dmg = 60.0, cd = 1.0}],
			["sh15", "SH-15", "arty", "truck_gun", {}],
			["a100", "A-100", "mlrs", "mlrs_truck", {}],
			["shahpar", "Shahpar-II", "uav_recon", "vtail", {}],
			["burraq", "Burraq", "uav_strike", "vtail", {}],
			["akinci", "Akıncı", "uav_heavy", "akinci", {}],
			["f7", "Chengdu F-7", "fighter", "mig21", {cost = 950, hp = 300, dmg = 95.0, time = 26.0}],
			["jf17", "JF-17 Thunder", "fighter", "jf17", {}],
			["j10c", "J-10C", "fighter", "j10", {cost = 1650, dmg = 145.0}],
			["f16", "F-16", "fighter", "f16", {}],
			["j35", "J-35", "stealth", "f35", {}],
		],
	},
	"in": {
		name = "Hindistan", doctrine = "denge", body = Color(0.3, 0.4, 0.28), air = Color(0.52, 0.58, 0.66),
		sam = ["S-400", "sam_tube"],
		missiles = [
			{name = "Pralay", cost = 1300, cd = 70.0, dmg = 900.0, splash = 7.0, tier = 3},
			{name = "BrahMos", cost = 2000, cd = 95.0, dmg = 1000.0, splash = 5.5, tier = 3, hypersonic = true},
		],
		units = [
			["inf", "Piyade Mangası", "inf", "inf", {}],
			["at", "Nag Timi", "at", "at", {}],
			["ew", "D4 Drone Sistemi", "ew", "ew_truck", {}],
			["switch", "Switch UAV", "sdrone_recon", "quad", {}],
			["nagastra", "Nagastra-1", "loiter", "xwing", {}],
			["bmp2", "BMP-2 Sarath", "ifv", "ifv_low", {}],
			["t90s", "T-90S Bhishma", "tank", "tank_ru2", {}],
			["arjun", "Arjun Mk1A", "tank", "tank_leo", {cost = 880, hp = 1350, tier = 2}],
			["shilka", "ZSU-23-4 Shilka", "spaag", "shilka", {}],
			["k9", "K9 Vajra", "arty", "sph", {}],
			["pinaka", "Pinaka", "mlrs", "mlrs_truck", {}],
			["heron", "Heron", "uav_recon", "twinboom", {}],
			["harop", "Harop", "uav_kami", "harop", {}],
			["mq9b", "MQ-9B", "uav_heavy", "vtail", {}],
			["tejas", "Tejas", "fighter", "tejas", {cost = 1100, hp = 330, dmg = 105.0, time = 28.0}],
			["mirage", "Mirage 2000", "fighter", "mirage", {}],
			["su30", "Su-30MKI", "fighter", "su30", {cost = 1650, hp = 480}],
			["rafale", "Rafale", "fighter", "rafale", {cost = 1750, dmg = 150.0}],
			["ghatak", "Ghatak", "uav_heavy", "flyingwing", {tier = 3, stealth = true, cost = 1900, hp = 420}],
			["durga", "DURGA-II Lazer", "laser", "laser_truck", {}],
		],
	},
}

# ---------------------------------------------------------------- haritalar
# Her harita 720 x 440 birimdir (x: -360..360 batı-doğu, z: -220..220 kuzey-güney).
# Şekiller: dikdörtgen [x0, z0, x1, z1], elips {e = [cx, cz, rx, rz]}, kalın çizgi {p = [[x, z], ...], w = genişlik},
# çokgen {poly = [[x, z], ...]}. rivers/water: su; rock: dağ (geçilmez); hills: tepe (görüş, menzil, hasar);
# forest: orman (gizlenme); trees: ağaç hattı; ruins: yıkıntı; roads: yol (nehri kestiği yerde köprü kurulur).
# towns: [x, z, ev sayısı, yarıçap, ad, apartman oranı]. big: terk edilmiş büyük yapılar [x, z, "factory"].
# windbreaks: tarla aralarına kendiliğinden ağaç hatları. bases_a/bases_b: iki tarafın üs yerleri (ilk üs ana üs).
# points: [x, z, gelir $/sn, ele geçirme süresi, tür (supply / town / oil), ad]
const MAPS := {
	"harkiv": {
		name = "Harkiv – Severski Donets", size = Vector2(720, 440),
		ground = Color(0.44, 0.47, 0.27), patch = Color(0.52, 0.5, 0.28), tree_col = Color(0.2, 0.36, 0.17),
		fields = [Color(0.6, 0.55, 0.3), Color(0.38, 0.46, 0.23), Color(0.44, 0.37, 0.26), Color(0.5, 0.5, 0.27)],
		windbreaks = {sp = 56.0},
		bases_a = [Vector3(-300, 0, -40), Vector3(-290, 0, 130)],
		bases_b = [Vector3(300, 0, 30), Vector3(295, 0, -150)],
		rivers = [
			{p = [[38, -225], [50, -185], [35, -150], [48, -110], [22, -60], [40, -10], [12, 40], [30, 95], [8, 150], [25, 225]], w = 12.0},
			{p = [[195, -225], [205, -160], [185, -100], [200, -40], [180, 30], [198, 100], [178, 160], [190, 225]], w = 8.0},
			{p = [[-170, -225], [-155, -160], [-175, -100], [-140, -40], [-90, 10], [-40, 30], [12, 40]], w = 6.0},
		],
		water = [{e = [42, -150, 16, 40]}],
		rock = [],
		hills = [
			{e = [-40, -50, 18, 13]}, {e = [150, 40, 18, 14]}, {e = [-190, 30, 16, 12]}, {e = [200, -165, 16, 12]},
			{e = [0, 200, 16, 11]}, {e = [-70, -150, 15, 11]}, {e = [150, -120, 14, 10]}, {e = [-60, 60, 13, 10]},
			{e = [230, 200, 14, 10]}, {e = [-230, -200, 14, 10]},
		],
		forest = [
			{e = [-220, -120, 45, 30]}, {e = [-150, 95, 55, 32]}, {e = [85, -40, 28, 45]}, {e = [-30, 105, 30, 38]},
			{e = [110, 120, 40, 28]}, {e = [240, -60, 35, 30]}, {e = [245, 110, 30, 40]}, {e = [-40, -180, 40, 25]},
			{e = [150, -190, 30, 20]}, {e = [-250, 190, 40, 20]}, {e = [60, 60, 22, 20]},
		],
		trees = [], ruins = [],
		roads = [
			{p = [[-360, 0], [-260, -8], [-160, -5], [-60, 8], [90, -5], [150, -12], [260, -25], [360, -15]], w = 6.0, asphalt = true},
			{p = [[-360, -140], [-250, -130], [-120, -110], [-20, -85], [110, -80], [250, -110], [360, -120]], w = 4.0},
			{p = [[-360, 150], [-240, 140], [-120, 165], [-20, 150], [80, 160], [240, 175], [360, 160]], w = 4.0},
			{p = [[-280, -225], [-270, -100], [-285, 40], [-275, 225]], w = 4.0},
			{p = [[-100, -225], [-110, -110], [-115, -60], [-80, 40], [-110, 165], [-90, 225]], w = 4.0},
			{p = [[110, -225], [120, -80], [100, 0], [120, 160], [110, 225]], w = 4.0},
			{p = [[270, -225], [265, -100], [280, 30], [265, 225]], w = 4.0},
		],
		towns = [
			[-20, 25, 12, 24, "Çuhuiv", 0.35], [80, -115, 7, 16, "Staryi Saltiv", 0.2], [150, -175, 9, 18, "Vovçansk", 0.2],
			[225, 70, 10, 20, "Kupiansk", 0.3], [-130, 170, 8, 16, "Balakliia", 0.25], [60, 195, 9, 18, "İzyum", 0.3],
			[-215, -50, 6, 14, "Ruska Lozova", 0.1], [-250, 40, 8, 18, "Harkiv Doğu", 0.5],
		],
		big = [[-60, -20, "factory"], [140, -45, "factory"], [95, 75, "factory"]],
		points = [
			[-20, 25, 5.0, 25.0, "town", "Çuhuiv"],
			[-230, -170, 2.0, 12.0, "supply", ""], [-200, 0, 2.0, 12.0, "supply", ""], [-220, 110, 2.0, 12.0, "supply", ""],
			[-120, -75, 2.0, 12.0, "supply", ""], [-70, -110, 2.0, 12.0, "supply", ""], [-60, 180, 2.0, 12.0, "supply", ""],
			[-130, 170, 3.0, 15.0, "town", "Balakliia"], [-75, 140, 4.0, 18.0, "oil", "Şebelinka gaz sahası"],
			[80, -115, 3.0, 15.0, "town", "Staryi Saltiv"], [60, 195, 3.0, 15.0, "town", "İzyum"],
			[150, -175, 3.0, 15.0, "town", "Vovçansk"], [225, 70, 3.0, 15.0, "town", "Kupiansk"],
			[130, 10, 2.0, 12.0, "supply", ""], [95, -160, 2.0, 12.0, "supply", ""], [240, 15, 2.0, 12.0, "supply", ""],
			[215, 150, 2.0, 12.0, "supply", ""],
		],
	},
	"korfez": {
		name = "Huzistan – Zagros Eteği", size = Vector2(720, 440),
		ground = Color(0.66, 0.58, 0.4), patch = Color(0.6, 0.5, 0.34), tree_col = Color(0.28, 0.38, 0.18),
		fields = [Color(0.68, 0.6, 0.42), Color(0.62, 0.54, 0.38), Color(0.7, 0.62, 0.45)],
		bases_a = [Vector3(-300, 0, -20), Vector3(-290, 0, 110)],
		bases_b = [Vector3(300, 0, -30), Vector3(295, 0, 100)],
		water = [{poly = [[-360, 170], [-250, 160], [-150, 175], [-60, 190], [40, 170], [140, 160], [250, 150], [360, 140], [360, 225], [-360, 225]]}],
		rivers = [
			{p = [[60, -225], [40, -160], [0, -100], [-20, -40], [-5, 20], [-35, 80], [-20, 130], [-50, 200]], w = 12.0},
			{p = [[-150, -225], [-170, -150], [-190, -60], [-215, 30], [-200, 100], [-230, 175]], w = 8.0},
		],
		rock = [
			{p = [[-120, -225], [-60, -170], [0, -140]], w = 26.0},
			{p = [[80, -225], [140, -150], [210, -110], [280, -100]], w = 30.0},
			{p = [[120, -60], [160, -37]], w = 22.0}, {p = [[198, -8], [230, 40]], w = 22.0},
			{p = [[300, -225], [360, -170]], w = 40.0}, {p = [[-300, -225], [-250, -190]], w = 30.0},
			{e = [-110, -30, 22, 16]}, {e = [110, 60, 18, 12]},
		],
		hills = [
			{e = [-60, 40, 16, 12]}, {e = [70, -40, 18, 12]}, {e = [160, 90, 20, 13]}, {e = [-260, -80, 15, 10]},
			{e = [260, 40, 16, 11]}, {e = [-150, 90, 14, 10]}, {e = [40, 120, 14, 10]},
		],
		forest = [
			{e = [-40, 100, 22, 35]}, {e = [-180, -20, 20, 30]}, {e = [10, -40, 18, 25]}, {e = [-200, 140, 25, 18]},
			{e = [90, 140, 30, 14]}, {e = [-100, 150, 25, 15]},
		],
		trees = [], ruins = [],
		roads = [
			{p = [[-360, 100], [-250, 125], [-150, 120], [-60, 135], [60, 125], [200, 120], [360, 100]], w = 6.0, asphalt = true},
			{p = [[-360, -20], [-250, -15], [-150, 10], [-60, 20], [40, 30], [120, 10], [180, 60], [270, 70], [360, 60]], w = 5.0, asphalt = true},
			{p = [[40, 30], [45, -60], [40, -95], [-60, -105], [-150, -80], [-250, -60], [-360, -70]], w = 4.0},
			{p = [[120, 10], [220, -50], [300, -30], [360, -40]], w = 4.0},
			{p = [[-60, 135], [-90, 165]], w = 4.0},
		],
		towns = [
			[10, 30, 12, 24, "Ahvaz", 0.35], [40, -95, 7, 15, "Dezful", 0.2], [-90, 170, 8, 16, "Abadan", 0.3],
			[-140, 140, 6, 14, "Hürremşehr", 0.2], [-150, -80, 6, 14, "Şuş", 0.1], [150, 25, 7, 15, "Mescid-i Süleyman", 0.15],
			[150, 140, 7, 14, "Bender Mahşehr", 0.25],
		],
		big = [[-50, -75, "factory"], [100, 100, "factory"], [200, 120, "factory"]],
		points = [
			[15, 40, 6.0, 25.0, "oil", "Ahvaz petrol terminali"],
			[-230, -120, 2.0, 12.0, "supply", ""], [-260, 40, 2.0, 12.0, "supply", ""], [-150, 55, 2.0, 12.0, "supply", ""],
			[-90, -140, 2.0, 12.0, "supply", ""], [-85, 160, 5.0, 18.0, "oil", "Abadan rafinerisi"],
			[80, -75, 2.0, 12.0, "supply", ""], [-75, -35, 2.0, 12.0, "supply", ""], [60, 90, 2.0, 12.0, "supply", ""],
			[150, 25, 3.0, 15.0, "town", "Mescid-i Süleyman"], [150, 140, 3.0, 15.0, "town", "Bender Mahşehr"],
			[40, -90, 3.0, 15.0, "town", "Dezful"], [235, -65, 2.0, 12.0, "supply", ""], [230, 110, 2.0, 12.0, "supply", ""],
			[255, 10, 2.0, 12.0, "supply", ""], [-220, -180, 2.0, 12.0, "supply", ""], [20, -200, 4.0, 18.0, "oil", "Mescid-i Süleyman petrol sahası"],
		],
	},
	"kesmir": {
		name = "Keşmir – Kontrol Hattı", size = Vector2(720, 440),
		ground = Color(0.38, 0.44, 0.28), patch = Color(0.43, 0.46, 0.3), tree_col = Color(0.14, 0.3, 0.17),
		fields = [Color(0.36, 0.48, 0.24), Color(0.5, 0.5, 0.28), Color(0.42, 0.44, 0.26), Color(0.33, 0.43, 0.22)],
		windbreaks = {sp = 66.0},
		bases_a = [Vector3(-300, 0, 60), Vector3(-300, 0, -80)],
		bases_b = [Vector3(300, 0, 40), Vector3(300, 0, -60)],
		rivers = [
			{p = [[10, -225], [-5, -160], [20, -110], [0, -50], [25, 10], [0, 80], [20, 150], [0, 225]], w = 14.0},
			{p = [[-240, -225], [-220, -160], [-250, -100], [-230, -40], [-260, 20], [-240, 90], [-270, 160], [-250, 225]], w = 10.0},
			{p = [[150, -225], [140, -120], [120, -60], [150, 0], [130, 80], [160, 150], [150, 225]], w = 7.0},
			{p = [[-360, 175], [-150, 180], [0, 170], [200, 185], [360, 175]], w = 5.0},
		],
		water = [],
		rock = [
			{poly = [[-360, -225], [360, -225], [360, -170], [250, -150], [200, -175], [150, -140], [90, -160], [40, -175], [-10, -150],
				[-60, -165], [-110, -140], [-160, -170], [-230, -150], [-300, -165], [-360, -150]]},
			{p = [[-110, -140], [-90, -90], [-70, -60]], w = 22.0}, {p = [[150, -140], [130, -90], [150, -50]], w = 22.0},
			{p = [[250, -150], [270, -110]], w = 26.0}, {e = [-20, -40, 16, 12]},
		],
		hills = [
			{e = [-130, -30, 16, 12]}, {e = [90, -30, 18, 12]}, {e = [-50, 40, 14, 10]}, {e = [70, 40, 14, 10]},
			{e = [200, -20, 16, 11]}, {e = [-200, 20, 14, 10]}, {e = [-180, 130, 14, 10]}, {e = [250, 130, 14, 10]},
		],
		forest = [
			{e = [-180, -110, 45, 25]}, {e = [60, -115, 40, 25]}, {e = [220, -95, 35, 25]}, {e = [-40, -100, 25, 18]},
			{e = [-120, 60, 28, 18]}, {e = [90, 100, 30, 18]}, {e = [-60, 140, 25, 15]}, {e = [210, 60, 22, 18]},
		],
		trees = [], ruins = [],
		roads = [
			{p = [[-360, 40], [-220, 60], [-170, 90], [-60, 100], [40, 110], [130, 105], [200, 110], [300, 90], [360, 80]], w = 6.0, asphalt = true},
			{p = [[-360, -70], [-250, -60], [-150, -60], [-60, -20], [30, -10], [110, -10], [200, -30], [300, -60], [360, -60]], w = 4.0},
			{p = [[-150, -140], [-150, -60], [-170, 90], [-160, 225]], w = 4.0},
			{p = [[200, -140], [200, -30], [200, 110], [210, 225]], w = 4.0},
			{p = [[45, 70], [40, 110]], w = 4.0},
		],
		towns = [
			[-170, 90, 10, 20, "Siyalkot", 0.35], [200, 110, 10, 20, "Cammu", 0.35], [45, 70, 7, 14, "Akhnur", 0.2],
			[-150, -60, 6, 12, "Kotli", 0.1], [100, -70, 6, 12, "Racuri", 0.1], [-90, 150, 6, 12, "Şakargarh", 0.15],
			[260, 165, 6, 12, "Kathua", 0.15],
		],
		big = [[-20, 100, "factory"], [120, 140, "factory"], [-110, 20, "factory"]],
		points = [
			[45, 70, 5.0, 25.0, "town", "Akhnur"],
			[-200, -140, 2.0, 12.0, "supply", ""], [-190, -10, 2.0, 12.0, "supply", ""], [-210, 150, 2.0, 12.0, "supply", ""],
			[-60, -120, 2.0, 12.0, "supply", ""], [-110, 120, 2.0, 12.0, "supply", ""], [-40, 200, 2.0, 12.0, "supply", ""],
			[-170, 90, 3.0, 15.0, "town", "Siyalkot"], [-150, -60, 3.0, 15.0, "town", "Kotli"], [100, -70, 3.0, 15.0, "town", "Racuri"],
			[200, 110, 3.0, 15.0, "town", "Cammu"], [260, 165, 3.0, 15.0, "town", "Kathua"], [-90, 150, 3.0, 15.0, "town", "Şakargarh"],
			[110, -125, 2.0, 12.0, "supply", ""], [250, 0, 2.0, 12.0, "supply", ""], [100, 30, 2.0, 12.0, "supply", ""],
			[-60, 10, 2.0, 12.0, "supply", ""],
		],
	},
}

# ---------------------------------------------------------------- birim kartı ipuçları
const TIPS := {
	inf = "Noktaları ele geçirir. Siper kazarak ya da bir eve girerek dayanıklılığını artır; tanklardan uzak tut.",
	at = "Tanklara ve zırhlılara karşı çok etkili, piyadeye karşı zayıf. Ormanda ya da siperde pusu kur.",
	ifv = "Piyadeyi hızla biçer, tanka karşı zayıf. Yolda hızlıdır: noktalara baskın için kullan.",
	tank = "Zırhlıları ve binaları yok eder. Tanksavar timlerine ve İHA'lara karşı yanına hava savunma ve EH al.",
	arty = "Uzak menzilli ama hedefi başka bir birimin görmesi gerekir. Önüne keşif dronu ya da piyade sür.",
	mlrs = "Geniş alana hasar verir; siperleri ve toplu piyadeyi dağıtır. Yakın savunması yok, geride tut.",
	spaag = "Dronları ve İHA'ları düşürür. Ordunun içinde ilerlet; tek başına tanklara yem olur.",
	laser = "Mühimmatsız drone katili. Sürü saldırılarına karşı en iyi savunma; uçaklara karşı zayıf.",
	ew = "Silahı yok. Çevresindeki küçük dronları karıştırıp düşürür, büyük İHA'ların kilidini bozar. Fiber optik FPV etkilenmez.",
	sdrone_recon = "Ucuz gözcü. Topçunun ve füzelerin görebilmesi için hedefin üstüne gönder.",
	sdrone_fpv = "Paket hâlinde gelir, hedefe dalıp patlar. Uçuş süresi kısa: yakındaki zırhlılara gönder. EH'ye dikkat.",
	sdrone_bomb = "Piyade ve siperlerin üstüne bomba bırakır, kışlaya dönüp yeniden yüklenir.",
	loiter = "Bölgede dolaşır, zırhlı hedef görünce dalar. Hava savunması zayıf alanlara gönder.",
	uav_recon = "Geniş alanı açar. Topçu ve füze hedefleri için keşif yap; hava savunmasından uzak tut.",
	uav_strike = "Güdümlü füzeyle tek hedefleri vurur, mühimmatı bitince hava alanına döner.",
	uav_heavy = "Daha çok mühimmat, daha uzun menzil. Önce düşman hava savunmasını sustur.",
	uav_kami = "Uzun menzilli kamikaze; binaları vurur. Toplu göndererek hava savunmasını doyur.",
	fighter = "Hava ve kara hedeflerine saldırır. Önce düşman uçak ve İHA'larını temizle.",
	striker = "Ağır bomba yükü: binaları ve toplu birlikleri vurur. Hava savunması bastırılmadan gönderme.",
	stealth = "Hava savunması onu ancak yakından görür. Füze üssü, santral gibi stratejik hedefleri vur.",
}


# ---------------------------------------------------------------- senaryolar
const LIST := [
	{
		name = "Rusya – Ukrayna", map = "harkiv", a = "ua", b = "ru",
		geo = {c = Vector2(36.5, 49.8), zoom = 9.0, a = Vector2(34.6, 49.8), b = Vector2(38.6, 50.4), col = Color(1.0, 0.72, 0.25), label = "Harkiv – Severski Donets"},
		desc = "Harkiv'in doğusu: Severski Donets ve Oskil nehirleri, köprüler, Peçenihi barajı, geniş ormanlar ve ağaç hatlarıyla bölünmüş tarlalar. Ukrayna'nın tankı yok; drone'larla Rus zırhını avlar. Rusya ağır zırh ve topçuya güvenir.",
		obj = {
			a = {type = "hold", point = 0, secs = 600.0, text = "Çuhuiv köprübaşını toplam 10 dakika elinde tut"},
			b = {type = "hold", point = 0, secs = 600.0, text = "Çuhuiv köprübaşını toplam 10 dakika elinde tut"},
		},
	},
	{
		name = "İran – İsrail", map = "korfez", a = "il", b = "ir",
		geo = {c = Vector2(42.0, 31.8), zoom = 6.0, a = Vector2(35.0, 31.6), b = Vector2(49.5, 31.5), col = Color(0.3, 0.85, 0.75), label = "Huzistan – Zagros"},
		desc = "Huzistan ovası ve Zagros sıradağları: Karun ve Kerhe nehirleri, petrol sahaları, hurma bahçeleri ve dar dağ geçitleri. İsrail görünmez uçaklarla stratejik hedefleri vurur, İran balistik füzelerle karşılık verir.",
		obj = {
			a = {type = "destroy", kinds = ["fuze", "sam", "santral", "teknoloji"], count = 4, text = "4 stratejik hedefi yok et (füze üssü, hava savunma, santral, teknoloji merkezi)"},
			b = {type = "hold", point = 0, secs = 600.0, text = "Ahvaz petrol terminalini toplam 10 dakika elinde tut"},
		},
	},
	{
		name = "Pakistan – Hindistan", map = "kesmir", a = "pk", b = "in",
		geo = {c = Vector2(74.5, 33.0), zoom = 10.0, a = Vector2(72.8, 33.4), b = Vector2(76.3, 32.6), col = Color(0.55, 0.9, 0.4), label = "Keşmir – Kontrol Hattı"},
		desc = "Kontrol Hattı: kuzeyde Himalaya eteklerinin çam ormanları ve hâkim tepeler, güneyde kanallarla bölünmüş Pencap ovası; Chenab, Jhelum ve Tawi nehirleri. Pakistan balistik füzelere, Hindistan insan gücüne güvenir.",
		obj = {
			a = {type = "destroy", kinds = ["havaalani", "fabrika", "kisla", "fuze"], count = 3, text = "3 askerî üretim tesisini yok et (hava alanı, fabrika, kışla, füze üssü)"},
			b = {type = "hold", point = 0, secs = 600.0, text = "Akhnur köprübaşını toplam 10 dakika elinde tut"},
		},
	},
	{name = "Çin – ABD: Tayvan Çıkarması", locked = true, geo = {c = Vector2(120.5, 24.0), zoom = 6.0, col = Color(0.9, 0.35, 0.3)}, desc = "Çin Tayvan'a çıkmak ister, ABD denizde geçişi durdurmaya çalışır. Deniz moduyla açılacak."},
	{name = "Çin – ABD: Okyanus", locked = true, geo = {c = Vector2(150.0, 18.0), zoom = 2.5, col = Color(0.35, 0.6, 1.0)}, desc = "İki donanma okyanusta karşılaşır; amaç karadaki üsleri yok etmek. Deniz moduyla açılacak."},
	{name = "Türkiye – Yunanistan: Adalar", locked = true, geo = {c = Vector2(26.0, 38.5), zoom = 9.0, col = Color(0.85, 0.85, 0.95)}, desc = "Türkiye'nin silahları üstün, Yunanistan'ın silahlandırılmış adaları ve kaynakları fazla. Deniz moduyla açılacak."},
]


## Seçilen senaryoya ve maç düzenine göre Defs tablolarını doldurur. Oyuncunun ülkesi her zaman takım 0,
## ana düşman takım 1'dir; düzene göre bir düşman üssü ve bir müttefik daha eklenebilir.
static func setup() -> void:
	var scn: Dictionary = LIST[chosen]
	var md: Dictionary = Defs.MODES[clampi(mode, 0, Defs.MODES.size() - 1)]
	if tutorial:
		md = Defs.MODES[0]
	var codes: Array = [scn.a, scn.b] if side == 0 else [scn.b, scn.a]
	var map: Dictionary = MAPS[scn.map].duplicate(true)
	if side == 1:
		var tmp = map.bases_a
		map.bases_a = map.bases_b
		map.bases_b = tmp
	Defs.MAP_W = map.size.x
	Defs.MAP_H = map.size.y
	Defs.SIDE = md.sides.duplicate()
	Defs.N = Defs.SIDE.size()
	Defs.COUNTRY = []
	Defs.TEAM_COLORS = []
	Defs.TEAM_NAMES = []
	map.team_bases = []
	var used := [0, 0]
	for t in Defs.N:
		var s: int = Defs.SIDE[t]
		var cc: String = codes[s]
		Defs.COUNTRY.append(cc)
		map.team_bases.append((map.bases_a if s == 0 else map.bases_b)[used[s]])
		var nm: String = COUNTRIES[cc].name
		if t == Defs.PLAYER:
			Defs.TEAM_COLORS.append(Defs.COL_PLAYER)
		elif s == 0:
			Defs.TEAM_COLORS.append(Defs.COL_ALLY)
			nm += " (müttefik)"
		else:
			Defs.TEAM_COLORS.append(Defs.COL_FOES[used[1] % Defs.COL_FOES.size()])
			if Defs.N > 2:
				nm += [" (1. ordu)", " (2. ordu)"][used[1] % 2]
		Defs.TEAM_NAMES.append(nm)
		used[s] += 1
	Defs.SCN = scn
	Defs.MAP = map
	Defs.UNITS = {}
	Defs.BUILDINGS = {}
	for cc in codes:
		var c: Dictionary = COUNTRIES[cc]
		var produces := {}
		for u in c.units:
			var d: Dictionary = CLASSES[u[2]].duplicate(true)
			d.merge(u[4], true)
			d.name = u[1]
			d.cls = u[2]
			d.model = u[3]
			d.cc = cc
			if int(d.get("tier", 1)) >= 3:
				# Deneysel silah: pahalı ama çok etkili.
				d.exp = true
				d.cost = int(round(float(d.cost) * 1.5))
				d.hp = float(d.hp) * 1.3
				d.time = float(d.time) * 1.2
				if d.has("dmg"):
					d.dmg = float(d.dmg) * 1.5
			var id := "%s_%s" % [cc, u[0]]
			Defs.UNITS[id] = d
			if not produces.has(d.from):
				produces[d.from] = []
			produces[d.from].append(id)
		for kind in BUILDING_KINDS:
			var b: Dictionary = BUILDING_KINDS[kind].duplicate(true)
			b.kind = kind
			b.model = kind
			b.cc = cc
			b.armor = "bld"
			if produces.has(kind):
				b.produces = produces[kind]
				b.slots = country_slots(cc, kind)
			if kind == "sam":
				b.name = c.sam[0]
				b.model = c.sam[1]
			if kind == "fuze" and c.doctrine == "fuze":
				b.tier = 2
			if kind == "engel":
				b.model = "obstacle"
			Defs.BUILDINGS["%s_%s" % [cc, kind]] = b


# Üretim panelindeki sabit yuva düzeni: her binada sınıflar bu sırayla dizilir. Bir sınıfın yuva sayısı, o sınıftan
# en çok birimi olan ülkeye göre belirlenir; ülkede olmayan birimin yuvası boş kalır, diğerleri kaymaz.
const SLOT_ORDER := {
	kisla = ["inf", "at", "sdrone_recon", "sdrone_fpv", "sdrone_bomb", "loiter"],
	fabrika = ["ifv", "tank", "arty", "mlrs", "spaag", "ew", "laser"],
	havaalani = ["uav_recon", "uav_strike", "uav_heavy", "uav_kami", "fighter", "striker", "stealth"],
}


## Bir binanın yuvaları: [birim kimliği ya da ""] (boş yuva).
static func country_slots(cc: String, kind: String) -> Array:
	var out: Array = []
	if not SLOT_ORDER.has(kind):
		return out
	for cls in SLOT_ORDER[kind]:
		var most := 0
		for c in COUNTRIES:
			var n := 0
			for u in COUNTRIES[c].units:
				if u[2] == cls:
					n += 1
			most = maxi(most, n)
		var mine: Array = []
		for u in COUNTRIES[cc].units:
			if u[2] == cls:
				mine.append("%s_%s" % [cc, u[0]])
		mine.sort_custom(func(a, b): return int(Defs.UNITS[a].get("tier", 1)) < int(Defs.UNITS[b].get("tier", 1)))
		for i in most:
			out.append(mine[i] if i < mine.size() else "")
	return out


static func country(team: int) -> Dictionary:
	return COUNTRIES[Defs.COUNTRY[team]]


static func doctrine(team: int) -> Dictionary:
	return DOCTRINES[country(team).doctrine]


## Takımın görev hedefi (senaryoda yoksa boş sözlük).
static func objective(team: int) -> Dictionary:
	var scn: Dictionary = Defs.SCN
	if not scn.has("obj") or (tutorial and Game.I != null and Game.I.tutorial_on):
		return {}
	return scn.obj.a if Defs.COUNTRY[team] == scn.a else scn.obj.b
