class_name Scenarios
extends RefCounted
## Oyunun verisi: birim sınıfları, ülkeler ve envanterleri, doktrinler, araştırmalar, haritalar, senaryolar.
## Denge buradan ayarlanır.

static var chosen := 0     # seçilen senaryo
static var side := 0       # oyuncunun tarafı: 0 = a ülkesi, 1 = b ülkesi

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
		mult = {inf = 1.2, light = 0.8, heavy = 0.2, bld = 0.4, drone = 0.3},
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
		range = 34.0, min_range = 9.0, dmg = 110.0, cd = 5.0, proj = "arc", splash = 4.5, no_chase = true,
		mult = {inf = 1.0, light = 1.0, heavy = 0.6, bld = 1.6},
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
	"maden": {name = "Maden Ocağı", cost = 600, time = 25.0, tier = 1, hp = 900, vision = 10.0, radius = 3.2, income = 4.0},
	"kisla": {name = "Kışla", cost = 300, time = 15.0, tier = 1, hp = 1200, vision = 12.0, radius = 3.2},
	"fabrika": {name = "Fabrika", cost = 600, time = 22.0, tier = 1, hp = 1500, vision = 12.0, radius = 3.6, power = -1},
	"havaalani": {name = "Hava Alanı", cost = 900, time = 30.0, tier = 2, hp = 1600, vision = 14.0, radius = 6.0, power = -2},
	"sam": {
		name = "Hava Savunma", cost = 700, time = 20.0, tier = 2, hp = 800, vision = 14.0, radius = 2.2, power = -1,
		cls = "sam", range = 26.0, dmg = 140.0, cd = 3.0, proj = "missile", mult = {air = 1.0},
	},
	"teknoloji": {name = "Teknoloji Merkezi", cost = 800, time = 30.0, tier = 2, hp = 1000, vision = 12.0, radius = 3.4, power = -1},
	"fuze": {name = "Füze Üssü", cost = 1200, time = 35.0, tier = 3, hp = 900, vision = 12.0, radius = 3.2, power = -2},
}

# ---------------------------------------------------------------- doktrinler
# mods anahtarları: cost_<sınıf>, hp_<sınıf>, dmg_<sınıf>, range_<sınıf>, rearm, missile_cost, missile_cd, pop_cap, drone_resist
const DOCTRINES := {
	"hava": {
		name = "Hava Üstünlüğü", desc = "Uçaklar ucuz ve hızlı silahlanır. Kara ordusu pahalı.",
		mods = {cost_fighter = 0.85, cost_striker = 0.85, cost_stealth = 0.85, rearm = 0.7, cost_tank = 1.15},
	},
	"iha": {
		name = "İHA Doktrini", desc = "Küçük ve büyük İHA'lar ucuz. Uçaklar pahalı.",
		mods = {cost_sdrone_recon = 0.7, cost_sdrone_fpv = 0.7, cost_sdrone_bomb = 0.7, cost_loiter = 0.7,
			cost_uav_strike = 0.8, cost_uav_kami = 0.8, cost_uav_heavy = 0.8, cost_fighter = 1.2},
	},
	"zirh": {
		name = "Zırhlı / Topçu", desc = "Tank ve topçu daha dayanıklı ve ucuz. İHA'lar pahalı.",
		mods = {hp_tank = 1.2, hp_arty = 1.2, hp_mlrs = 1.2, cost_tank = 0.9, cost_arty = 0.9, cost_uav_strike = 1.2},
	},
	"fuze": {
		name = "Balistik Füze", desc = "Füzeler ucuz, çabuk hazır; Füze Üssü Kademe 2'de açılır. Zırhlılar zayıf.",
		mods = {missile_cost = 0.65, missile_cd = 0.6, hp_tank = 0.9, hp_ifv = 0.9},
	},
	"denge": {
		name = "Dengeli / İnsan Gücü", desc = "Piyade ucuz, birlik sınırı yüksek.",
		mods = {cost_inf = 0.7, cost_at = 0.8, pop_cap = 12.0},
	},
}

# ---------------------------------------------------------------- araştırmalar (Teknoloji Merkezi)
const RESEARCH := [
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
			["mavic", "DJI Mavic 3", "sdrone_recon", "quad", {}],
			["fpv", "FPV Kamikaze", "sdrone_fpv", "quad", {}],
			["baba", "Baba Yaga", "sdrone_bomb", "hexa", {}],
			["bradley", "M2 Bradley", "ifv", "ifv_tall", {}],
			["t64", "T-64BV", "tank", "tank_ru", {}],
			["leo2", "Leopard 2A6", "tank", "tank_leo", {cost = 850, hp = 1300, tier = 2}],
			["gepard", "Gepard", "spaag", "gepard", {}],
			["bohdana", "2S22 Bohdana", "arty", "truck_gun", {}],
			["himars", "M142 HIMARS", "mlrs", "himars", {}],
			["tb2", "Bayraktar TB2", "uav_strike", "tb2", {}],
			["liutyi", "AN-196 Liutyi", "uav_kami", "liutyi", {}],
			["f16", "F-16", "fighter", "f16", {}],
			["mirage", "Mirage 2000-5", "fighter", "mirage", {}],
			["tryzub", "Tryzub Lazer", "laser", "laser_truck", {}],
		],
	},
	"ru": {
		name = "Rusya", doctrine = "zirh", body = Color(0.25, 0.32, 0.22), air = Color(0.42, 0.5, 0.6),
		sam = ["S-400", "sam_tube"],
		missiles = [{name = "İskender-M", cost = 1300, cd = 70.0, dmg = 950.0, splash = 7.0, tier = 3}],
		units = [
			["inf", "Motorize Piyade", "inf", "inf", {}],
			["at", "Kornet Timi", "at", "at", {}],
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
		],
	},
	"il": {
		name = "İsrail", doctrine = "hava", body = Color(0.5, 0.47, 0.36), air = Color(0.6, 0.62, 0.64),
		sam = ["David's Sling", "sam_box"],
		missiles = [{name = "LORA", cost = 1300, cd = 70.0, dmg = 900.0, splash = 6.5, tier = 3}],
		units = [
			["inf", "Piyade Mangası", "inf", "inf", {}],
			["at", "Spike Timi", "at", "at", {}],
			["orbiter", "Orbiter", "sdrone_recon", "small_plane", {}],
			["hero", "Hero-30", "loiter", "xwing", {}],
			["namer", "Namer", "ifv", "namer", {hp = 760, cost = 440}],
			["merkava", "Merkava Mk 4", "tank", "tank_merkava", {hp = 1250, cost = 780}],
			["irondome", "Iron Dome", "spaag", "irondome", {speed = 3.2, dmg = 65.0, cd = 1.0, proj = "missile", range = 17.0}],
			["atmos", "ATMOS 2000", "arty", "truck_gun", {}],
			["puls", "PULS", "mlrs", "mlrs_truck", {}],
			["eitan", "Heron TP", "uav_recon", "twinboom", {}],
			["hermes", "Hermes 900", "uav_strike", "vtail", {}],
			["harop", "Harop", "uav_kami", "harop", {}],
			["f16i", "F-16I Sufa", "fighter", "f16", {}],
			["f15i", "F-15I Ra'am", "striker", "f15", {}],
			["f35i", "F-35I Adir", "stealth", "f35", {}],
			["ironbeam", "Iron Beam", "laser", "laser_truck", {}],
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
			["f4", "F-4E Phantom II", "striker", "f4", {cost = 1500, hp = 440}],
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
		],
	},
}

# ---------------------------------------------------------------- haritalar
# Dikdörtgenler [x0, z0, x1, z1]. rock/trees/ruins/water geçilmez; bridges suyu geçilir yapar.
# flora: ağaç ve çalı türleri (mixed: çam ve yapraklı, pine: çoğunlukla çam, desert: kuru çalı ve taş).
# points: [x, z, gelir $/sn, ele geçirme süresi, petrol mü]
const MAPS := {
	"harkiv": {
		name = "Harkiv Açıkları", ground = Color(0.47, 0.5, 0.28), patch = Color(0.56, 0.52, 0.27), flora = "mixed",
		bases = [Vector3(-90, 0, 0), Vector3(90, 0, 0)],
		rock = [],
		trees = [
			[-52.0, -66.0, -48.0, -22.0], [-52.0, -8.0, -48.0, 30.0], [-52.0, 44.0, -48.0, 66.0],
			[48.0, -66.0, 52.0, -30.0], [48.0, -16.0, 52.0, 22.0], [48.0, 36.0, 52.0, 66.0],
			[-30.0, 20.0, 8.0, 24.0], [-8.0, -24.0, 30.0, -20.0],
		],
		ruins = [
			[-10.0, -6.0, -4.0, 0.0], [4.0, 2.0, 10.0, 8.0], [-6.0, 8.0, 0.0, 12.0], [2.0, -12.0, 8.0, -6.0],
			[-36.0, -44.0, -30.0, -38.0], [30.0, 40.0, 36.0, 46.0],
		],
		water = [[-110.0, -70.0, 110.0, -64.0]],
		bridges = [],
		points = [
			[-70.0, -40.0, 5.0, 12.0, false], [-70.0, 40.0, 5.0, 12.0, false],
			[-26.0, -44.0, 5.0, 12.0, false], [-26.0, 44.0, 5.0, 12.0, false],
			[26.0, -44.0, 5.0, 12.0, false], [26.0, 44.0, 5.0, 12.0, false],
			[70.0, -40.0, 5.0, 12.0, false], [70.0, 40.0, 5.0, 12.0, false],
			[0.0, 0.0, 12.0, 25.0, false],
		],
	},
	"korfez": {
		name = "Körfez", ground = Color(0.66, 0.58, 0.4), patch = Color(0.6, 0.5, 0.34), flora = "desert",
		bases = [Vector3(-92, 0, -20), Vector3(92, 0, -20)],
		rock = [
			[-60.0, -70.0, -50.0, -30.0], [-60.0, -16.0, -50.0, 22.0],
			[-20.0, -52.0, -10.0, -4.0], [10.0, -70.0, 20.0, -24.0], [10.0, -10.0, 20.0, 22.0],
			[50.0, -52.0, 60.0, 4.0], [-30.0, 14.0, -22.0, 28.0], [24.0, 4.0, 34.0, 12.0],
		],
		trees = [], ruins = [],
		water = [[-110.0, 34.0, 110.0, 70.0], [-40.0, 22.0, 40.0, 34.0]],
		bridges = [],
		points = [
			[-76.0, 16.0, 5.0, 12.0, false], [-74.0, -52.0, 5.0, 12.0, false],
			[-36.0, -30.0, 5.0, 12.0, false], [36.0, -30.0, 5.0, 12.0, false],
			[76.0, 16.0, 5.0, 12.0, false], [74.0, -52.0, 5.0, 12.0, false],
			[0.0, -60.0, 8.0, 18.0, false], [0.0, 8.0, 14.0, 25.0, true],
		],
	},
	"kesmir": {
		name = "Sınır Hattı", ground = Color(0.38, 0.44, 0.28), patch = Color(0.43, 0.46, 0.3), flora = "pine",
		bases = [Vector3(-90, 0, 10), Vector3(90, 0, 10)],
		rock = [
			[-49.0, -70.0, -41.0, -40.0], [-49.0, -26.0, -41.0, -6.0],
			[41.0, -70.0, 49.0, -40.0], [41.0, -26.0, 49.0, -6.0],
			[-26.0, -56.0, -16.0, -46.0], [16.0, -56.0, 26.0, -46.0],
			[-30.0, -20.0, -22.0, -10.0], [22.0, -20.0, 30.0, -10.0],
			[-80.0, -70.0, -60.0, -56.0], [60.0, -70.0, 80.0, -56.0],
		],
		trees = [[-70.0, 44.0, -40.0, 48.0], [40.0, 44.0, 70.0, 48.0]],
		ruins = [],
		water = [[-4.0, -70.0, 4.0, 70.0]],
		bridges = [[-5.0, -64.0, 5.0, -56.0], [-5.0, -34.0, 5.0, -26.0], [-10.0, 0.0, 10.0, 20.0], [-5.0, 50.0, 5.0, 58.0]],
		points = [
			[-68.0, -36.0, 5.0, 12.0, false], [-68.0, 52.0, 5.0, 12.0, false],
			[-24.0, -34.0, 5.0, 12.0, false], [-24.0, 44.0, 5.0, 12.0, false],
			[24.0, -34.0, 5.0, 12.0, false], [24.0, 44.0, 5.0, 12.0, false],
			[68.0, -36.0, 5.0, 12.0, false], [68.0, 52.0, 5.0, 12.0, false],
			[0.0, 10.0, 12.0, 25.0, true],
		],
	},
}

# ---------------------------------------------------------------- senaryolar
const LIST := [
	{
		name = "Rusya – Ukrayna", map = "harkiv", a = "ua", b = "ru",
		desc = "Harkiv açıkları. İki taraf da yoğun drone saldırıları yüzünden ilerleyemiyor. Ukrayna drone'lara, Rusya ağır zırh ve topçuya güvenir.",
	},
	{
		name = "İran – İsrail", map = "korfez", a = "il", b = "ir",
		desc = "İsrail görünmez uçaklarla stratejik hedefleri vurur, İran balistik füzelerle karşılık verir. Dağlar yüzünden kara harekâtı uzun ve zordur.",
	},
	{
		name = "Pakistan – Hindistan", map = "kesmir", a = "pk", b = "in",
		desc = "Dağlık kuzey, nehirli ova. Pakistan balistik füzelere, Hindistan dengeli ordusuna ve insan gücüne güvenir.",
	},
	{name = "Çin – ABD: Tayvan Çıkarması", locked = true, desc = "Çin Tayvan'a çıkmak ister, ABD denizde geçişi durdurmaya çalışır. Deniz moduyla açılacak."},
	{name = "Çin – ABD: Okyanus", locked = true, desc = "İki donanma okyanusta karşılaşır; amaç karadaki üsleri yok etmek. Deniz moduyla açılacak."},
	{name = "Türkiye – Yunanistan: Adalar", locked = true, desc = "Türkiye'nin silahları üstün, Yunanistan'ın silahlandırılmış adaları ve kaynakları fazla. Deniz moduyla açılacak."},
]


## Seçilen senaryoya göre Defs tablolarını doldurur. Oyuncunun ülkesi her zaman takım 0 olur.
static func setup() -> void:
	var scn: Dictionary = LIST[chosen]
	var codes: Array = [scn.a, scn.b] if side == 0 else [scn.b, scn.a]
	var map: Dictionary = MAPS[scn.map].duplicate(true)
	if side == 1:
		map.bases = [map.bases[1], map.bases[0]]
	Defs.SCN = scn
	Defs.COUNTRY = codes
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
			if kind == "sam":
				b.name = c.sam[0]
				b.model = c.sam[1]
			if kind == "fuze" and c.doctrine == "fuze":
				b.tier = 2
			Defs.BUILDINGS["%s_%s" % [cc, kind]] = b


static func country(team: int) -> Dictionary:
	return COUNTRIES[Defs.COUNTRY[team]]


static func doctrine(team: int) -> Dictionary:
	return DOCTRINES[country(team).doctrine]
