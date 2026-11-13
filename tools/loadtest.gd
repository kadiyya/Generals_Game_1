extends Node
## Geliştirme aracı: --mechtest'in kaydettiği oyunu yükleyip durumun geri geldiğini doğrular.
## Kullanım: önce --mechtest, sonra: godot --headless --path . -- --load --loadtest

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var g := Game.I
	var f := FileAccess.open("user://mechtest_sayi.txt", FileAccess.READ)
	var want: PackedStringArray = f.get_as_text().split(" ")
	var alive := 0
	for e in g.entities:
		if e.alive:
			alive += 1
	var fails := 0
	var checks := [
		["birlik ve bina sayisi geri gelir", alive == int(want[0])],
		["para geri gelir", absi(int(g.teams[0].money) - int(want[1])) <= 2],
		["oyun saati geri gelir", absi(int(g.time) - int(want[2])) <= 1],
		["karargahlar yerinde", g.teams[0].hq != null and g.teams[1].hq != null],
	]
	var houses_ok := false
	var dug_ok := false
	var rank_ok := false
	for e in g.entities:
		if e is Unit and e.garrison != null:
			houses_ok = true
		if e is Unit and e.entrenched:
			dug_ok = true
		if e.rank > 0:
			rank_ok = true
	checks += [["evdeki birlik evde", houses_ok], ["siper korunur", dug_ok], ["rutbe korunur", rank_ok]]
	for c in checks:
		print(("GECTI  " if c[1] else "KALDI  ") + c[0])
		if not c[1]:
			fails += 1
	print("LOADTEST BITTI  hata=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
