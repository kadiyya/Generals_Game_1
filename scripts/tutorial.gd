extends Node
## Eğitim: Rusya – Ukrayna haritasında, Ukrayna tarafında adım adım temel oynanış.
## Her adımın bir açıklaması ve bir tamamlanma koşulu var. Eğitim sürerken yapay zekâ saldırmaz
## ve görevler işlemez; son adımdan sonra normal maç başlar.

var steps: Array = []
var i := 0
var panel: PanelContainer
var lbl: Label
var skip: Button
var start_focus := Vector3.ZERO
var t := 0.0


func _ready() -> void:
	var g := Game.I
	g.teams[Defs.PLAYER].money = 4000.0
	start_focus = g.cam.focus
	steps = [
		["Kamerayı kaydırmak için ekranı parmağınla sürükle. İki parmakla yakınlaştırabilirsin.",
			func(): return g.cam.focus.distance_to(start_focus) > 6.0],
		["Sol paneldeki İnşa düğmesine bas, Kışla'yı seç, sarı alanın içinde bir yere dokun.",
			func(): return g.count_kind(0, "kisla", false) > 0],
		["Kışla bitince ona dokun ve bir Piyade Mangası üret. Kartın köşesindeki sarı simgeye basarak birimin özelliklerine bakabilirsin.",
			func(): return _count("inf") >= 3],
		["Piyadeyi seç (dokun ya da basılı tutup sürükle) ve bir ikmal noktasına dokun. Nokta senin rengine dönünce gelirin artar.",
			func(): return _points() >= 1],
		["Piyade seçiliyken Siper Kaz'a bas. Siperdeki birlik yarı hasar alır. İstersen bir köy evine dokunup içine de sokabilirsin.",
			func(): return _dug()],
		["İnşa menüsünden bir Santral ve bir Fabrika kur. Vinç sayısı aynı anda kaç inşaat yürüyeceğini belirler.",
			func(): return g.count_kind(0, "santral", false) > 0 and g.count_kind(0, "fabrika", false) > 0],
		["Fabrikadan bir M2 Bradley üret. Ukrayna'nın tankı yok (İHA doktrini): yeşil fiyatlı dronlar ucuz, kırmızı fiyatlılar pahalı. Fabrikayı seçip Toplanma Noktası'na basarak yeni birliklerin nereye gideceğini de seçebilirsin.",
			func(): return _count("ifv") >= 1],
		["Birliklerini seçip Grup 1 düğmesine basılı tut: grup kaydedilir. Sonra Grup 1'e dokunarak hepsini bir anda seçebilirsin.",
			func(): return not g.groups[0].is_empty()],
		["Sol paneldeki doktrin yeteneğini (Sürü Saldırısı) görebildiğin bir düşman bölgesine kullan.",
			func(): return g.teams[0].ab_cd > 0.0],
		["Eğitim bitti! Haritada beliren kaynak yataklarına Maden Ocağı kur, ileri üslerle ikmal hattını uzat. Görevin ekranın üstünde: Çuhuiv köprübaşını 10 dakika tut ya da düşman karargâhını yık.",
			func(): return t > 10.0],
	]
	panel = PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -330.0
	panel.offset_right = 330.0
	panel.offset_top = 112.0
	var hb := HBoxContainer.new()
	panel.add_child(hb)
	lbl = Label.new()
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(540, 0)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))
	hb.add_child(lbl)
	skip = Button.new()
	skip.text = "Atla"
	skip.custom_minimum_size = Vector2(90, 48)
	skip.focus_mode = Control.FOCUS_NONE
	skip.pressed.connect(_next)
	hb.add_child(skip)
	g.hud.root.add_child(panel)
	g.hud.blockers.append(panel)
	_show()


func _count(cls: String) -> int:
	var n := 0
	for e in Game.I.entities:
		if e.team == Defs.PLAYER and e.cls == cls:
			n += 1
	return n


func _points() -> int:
	var n := 0
	for p in Game.I.points:
		if p.owner_team == Defs.PLAYER:
			n += 1
	return n


func _dug() -> bool:
	for e in Game.I.entities:
		if e is Unit and e.team == Defs.PLAYER and (e.entrenched or e.garrison != null):
			return true
	return false


func _show() -> void:
	lbl.text = "Eğitim %d/%d — %s" % [i + 1, steps.size(), steps[i][0]]


func _next() -> void:
	i += 1
	t = 0.0
	if i >= steps.size():
		Game.I.tutorial_on = false
		panel.queue_free()
		queue_free()
		return
	if i == steps.size() - 1:
		Game.I.tutorial_on = false
		skip.text = "Kapat"
	_show()


func _process(dt: float) -> void:
	t += dt
	if t > 0.5 and steps[i][1].call():
		_next()
