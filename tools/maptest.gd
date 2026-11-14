extends Node
## Geliştirme aracı: haritanın oynanabilirliğini doğrular. Üsler düz arazide mi, her üsten her noktaya ve
## karşı üslere kara yolu var mı, köprüler kuruldu mu; uzun bir yol bulmanın süresini ölçer.
## Kullanım: godot --headless --path . -- --maptest --scn=N

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var g := Game.I
	var ter := g.terrain
	var fails := 0
	var bases: Array = Defs.MAP.bases_a + Defs.MAP.bases_b
	for b in bases:
		if not ter.is_land(b):
			print("KALDI  üs düz arazide değil: %s" % b)
			fails += 1
	var t0 := Time.get_ticks_usec()
	var paths := 0
	for b in bases:
		for p in g.points:
			var path := ter.find_path(b, p.position)
			paths += 1
			if path.is_empty() or Entity.flat(path[path.size() - 1], p.position) > 12.0:
				print("KALDI  %s -> nokta %s (%s) yol yok" % [b, p.position, p.pname])
				fails += 1
		for b2 in bases:
			if b2 != b and ter.find_path(b, b2).is_empty():
				print("KALDI  üsten üsse yol yok: %s -> %s" % [b, b2])
				fails += 1
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	print("HARITA %s  köprü=%d  ev=%d  nokta=%d  yol=%d  ort. yol bulma=%.2f ms" % [Defs.MAP.name, g.bridges.size(), g.houses.size(), g.points.size(), paths, ms / paths])
	var counts := {}
	for k in ter.kind:
		counts[k] = counts.get(k, 0) + 1
	print("HÜCRE  %s" % counts)
	print("MAPTEST BITTI  hata=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
