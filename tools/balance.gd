extends SceneTree
## Geliştirme aracı: bütün ülkelerin birimlerinin oyundaki gerçek değerlerini (sınıf + ülke farkı + doktrin fiyatı,
## hız ve zırh ayarları dahil) Markdown tablosu olarak yazar. Denge konuşmak için.
## Kullanım: godot --headless --path . -s tools/balance.gd -- docs/DENGE.md

const ARM := ["inf", "light", "heavy", "bld", "air", "drone"]
const ARM_TR := {inf = "piyade", light = "hafif zırh", heavy = "tank", bld = "bina", air = "uçak/İHA", drone = "küçük dron"}
const CAT_TR := {kara = "Kara", hs = "Hava savunma", hava = "Hava"}


func _init() -> void:
	var out := PackedStringArray()
	out.append("# Birim değerleri (koddan üretildi)\n")
	out.append("Bu dosya `tools/balance.gd` ile üretilir; elle değiştirme. Değerler `scripts/scenarios.gd` içindeki sınıf,")
	out.append("ülke ve doktrin tablolarından gelir. **Saniyede hasar (SnH)**: hasar ÷ atış aralığı × zırh çarpanı")
	out.append("(paket birimlerde adetle çarpılır). Kamikazelerde tek vuruş hasarı yazılır. Fiyat doktrin indirimi/cezasıyla.\n")
	out.append("Zırh sınıfları: piyade, hafif zırh (zırhlı araç, topçu, hava savunma araçları), tank, bina, uçak/İHA (büyük),")
	out.append("küçük dron. Hız birim/sn (piyade %10 artırılmış, kara araçları %5 düşürülmüş hâliyle).\n")
	# sınıf özeti
	out.append("## Sınıflar\n")
	out.append("| Sınıf | Tür | Fiyat | Can | Hız | Görüş | Menzil | Hasar / aralık | SnH: piyade | hafif | tank | bina | uçak | dron | Not |")
	out.append("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
	for cls in Scenarios.CLASSES:
		var d: Dictionary = Scenarios.CLASSES[cls].duplicate(true)
		if not d.get("air", false):
			d.speed = float(d.speed) * (1.1 if d.armor == "inf" else 0.95)
		out.append(_row(cls, d, int(d.cost)))
	# binalar
	out.append("\n## Silahlı bina\n")
	var sam: Dictionary = Scenarios.BUILDING_KINDS.sam
	out.append("Hava Savunma binası: can %d, menzil %.0f, %d hasar / %.1f sn. SnH: %s. Balistik füze önleme çarpanı %.2f." % [
		int(sam.hp), float(sam.range), int(sam.dmg), float(sam.cd), _dps_text(sam), float(sam.mult.get("missile", sam.mult.air))])
	# ülkeler
	for cc in Scenarios.COUNTRIES:
		var c: Dictionary = Scenarios.COUNTRIES[cc]
		var doc: Dictionary = Scenarios.DOCTRINES[c.doctrine]
		out.append("\n## %s — %s\n" % [c.name, doc.name])
		var dtext := String(doc.desc)
		if c.has("drone_armor"):
			dtext += " Ülke farkı: dronlar zırhlılara %%%d fazla vurur." % int(round((float(c.drone_armor) - 1.0) * 100.0))
		out.append(dtext)
		out.append("\n\nYetenek: **%s** ($%d, %d sn bekleme) — %s\n" % [doc.ability.name, int(doc.ability.cost), int(doc.ability.cd), doc.ability.desc])
		out.append("| Birim | Sınıf | Fiyat | Can | Hız | Görüş | Menzil | Hasar / aralık | SnH: piyade | hafif | tank | bina | uçak | dron | Not |")
		out.append("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
		for u in c.units:
			var d: Dictionary = Scenarios.CLASSES[u[2]].duplicate(true)
			d.merge(u[4], true)
			d.mult = d.get("mult", {}).duplicate()
			if not d.get("air", false):
				d.speed = float(d.speed) * (1.1 if d.armor == "inf" else 0.95)
			if d.get("tag", "") == "drone" and c.has("drone_armor"):
				for ak in ["light", "heavy"]:
					if d.mult.has(ak):
						d.mult[ak] = float(d.mult[ak]) * float(c.drone_armor)
			var cost := float(d.cost)
			var tier := int(d.get("tier", 1))
			if tier >= 3:
				cost *= 1.5
				d.hp = float(d.hp) * 1.3
				if d.has("dmg"):
					d.dmg = float(d.dmg) * 1.5
			cost *= float(doc.mods.get("cost_" + String(u[2]), 1.0))
			d.hp = float(d.hp) * float(doc.mods.get("hp_" + String(u[2]), 1.0))
			out.append(_row("%s%s" % [u[1], " (deneysel)" if tier >= 3 else ""], d, int(round(cost)), u[2]))
		var ms: Array = c.get("missiles", [])
		if not ms.is_empty():
			var mt := PackedStringArray()
			for m in ms:
				var mc := float(m.cost) * float(doc.mods.get("missile_cost", 1.0)) * (1.3 if int(m.tier) >= 3 else 1.0)
				var cd := float(m.cd) * float(doc.mods.get("missile_cd", 1.0))
				mt.append("%s ($%d, %d hasar, alan %.1f, %d sn%s)" % [m.name, int(mc), int(float(m.dmg) * (1.3 if int(m.tier) >= 3 else 1.0)), float(m.splash), int(cd), ", hipersonik" if m.get("hypersonic", false) else ""])
			out.append("\nFüzeler: " + ", ".join(mt))
	var path: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "res://docs/DENGE.md"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(out) + "\n")
	f.close()
	print("DENGE yazildi: ", path)
	quit()


func _dps(d: Dictionary, a: String) -> float:
	var m := float(d.get("mult", {}).get(a, 0.0))
	if not d.has("dmg") or m <= 0.0:
		return 0.0
	if d.get("kamikaze", false):
		return float(d.dmg) * m * float(d.get("count", 1))
	return float(d.dmg) / maxf(0.05, float(d.cd)) * m * float(d.get("count", 1))


func _dps_text(d: Dictionary) -> String:
	var t := PackedStringArray()
	for a in ARM:
		var v := _dps(d, a)
		if v > 0.0:
			t.append("%s %.0f" % [ARM_TR[a], v])
	return ", ".join(t)


func _row(name: String, d: Dictionary, cost: int, cls := "") -> String:
	var notes := PackedStringArray()
	if d.get("kamikaze", false):
		notes.append("kamikaze (SnH = tek vuruş)")
	if d.get("count", 1) > 1:
		notes.append("%d'li paket" % int(d.count))
	if d.has("life"):
		notes.append("uçuş %d sn" % int(d.life))
	if d.has("splash"):
		notes.append("alan %.1f" % float(d.splash))
	if d.has("min_range"):
		notes.append("en az %.0f" % float(d.min_range))
	if d.has("ammo"):
		notes.append("%d mühimmat" % int(d.ammo))
	if d.has("ew"):
		notes.append("EH %.0f: küçük dronları düşürür, büyükleri karıştırır" % float(d.ew))
	if d.get("stealth", false):
		notes.append("görünmez")
	if d.get("capture", false):
		notes.append("nokta alır")
	if d.get("no_chase", false):
		notes.append("kovalamaz")
	var cells := PackedStringArray()
	for a in ARM:
		var v := _dps(d, a)
		cells.append("%.0f" % v if v > 0.0 else "–")
	var hit := "–"
	if d.has("dmg"):
		hit = ("%d" % int(d.dmg)) if d.get("kamikaze", false) else ("%d / %.2f sn" % [int(d.dmg), float(d.cd)])
	return "| %s | %s | %d | %d | %.1f | %.0f | %s | %s | %s | %s |" % [
		name, cls if cls != "" else CAT_TR.get(d.get("cat", ""), ""), cost, int(d.hp), float(d.speed), float(d.get("vision", 0.0)),
		("%.0f" % float(d.range)) if d.has("range") else "–", hit, " | ".join(cells), "; ".join(notes)]
