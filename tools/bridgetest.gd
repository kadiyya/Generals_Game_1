extends Node
## Geliştirme aracı: köprü geçişini ölçer. Her köprüde iki araç kolu karşılıklı, bir kol da aynı yönde geçer;
## süre sonunda hedefine varan, köprüde takılıp kalan birlikleri sayar.
## Kullanım: godot --headless --path . --fixed-fps 30 -- --bridgetest --scn=0

var PER_SIDE := 10
const LIMIT := 120.0

var fails := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--n="):
			PER_SIDE = int(a.trim_prefix("--n="))
	_run.call_deferred()


func _wait(secs: float) -> void:
	await get_tree().create_timer(secs, false).timeout


func _run() -> void:
	var g := Game.I
	var ter := g.terrain
	if OS.get_cmdline_user_args().has("--watch"):
		await _watch()
		return
	# Yapay zekâ ordularının araya girmemesi için durdurulur.
	for c in g.get_children():
		if c is EnemyAI:
			c.process_mode = Node.PROCESS_MODE_DISABLED
	var kinds: Array = []
	for cls in ["ifv", "ads", "tank", "spaag", "inf"]:
		var id: String = g.unit_of(0, cls)
		if id != "":
			kinds.append(id)
	var total := 0
	var arrived := 0
	var on_deck := 0
	var tested := 0
	for br in g.bridges:
		var ax: Vector3 = (br.b - br.a)
		ax.y = 0.0
		var dir := ax.normalized()
		var side := Vector3(-dir.z, 0, dir.x)
		var s0: Vector3 = ter.nearest_free(br.a - dir * 30.0 + side * float(OS.get_cmdline_user_args().has("--oblique")) * 18.0)
		var s1: Vector3 = ter.nearest_free(br.b + dir * 30.0 - side * float(OS.get_cmdline_user_args().has("--oblique")) * 18.0)
		if ter.find_path(s0, s1).is_empty():
			continue
		tested += 1
		var groups: Array = []
		var extra: Array = []
		var args := OS.get_cmdline_user_args()
		if args.has("--blocker"):
			# Köprünün ortasında duran iki dost birlik (ateş eden ya da emir bekleyen birlik gibi).
			for j in 2:
				extra.append(g.spawn_unit(kinds[1 % kinds.size()], Defs.PLAYER, (br.a + br.b) * 0.5 + side * (j * 2.0 - 1.0)))
		for k in 2:
			var start: Vector3 = s0 if k == 0 else s1
			var back := -dir if k == 0 else dir
			var goal: Vector3 = ter.nearest_free(s1 + dir * 20.0 if k == 0 else s0 - dir * 20.0)
				goal.x = clampf(goal.x, -Defs.MAP_W * 0.5 + 14.0, Defs.MAP_W * 0.5 - 14.0)
				goal.z = clampf(goal.z, -Defs.MAP_H * 0.5 + 14.0, Defs.MAP_H * 0.5 - 14.0)
			var us: Array = []
			for i in PER_SIDE:
				var p := ter.nearest_free(start + back * (i / 2) * 4.5 + side * ((i % 2) * 4.0 - 2.0))
				var u: Unit = g.spawn_unit(kinds[i % kinds.size()], Defs.PLAYER, p)
				us.append(u)
			g.order_move(us, goal, args.has("--amove"))
			groups.append([us, goal])
		var t := 0.0
		while t < LIMIT:
			await _wait(1.0)
			t += 1.0
			var all_done := true
			for gr in groups:
				for u in gr[0]:
					if u.alive and Entity.flat(u.position, gr[1]) > 10.0:
						all_done = false
			if all_done:
				break
		var a_n := 0
		var d_n := 0
		var stuck_idle := 0
		for gr in groups:
			for u in gr[0]:
				total += 1
				if u.alive and u.order == "idle" and Entity.flat(u.position, gr[1]) > 13.0:
					stuck_idle += 1
				if u.alive and Entity.flat(u.position, gr[1]) > 13.0:
					print("  kalan %s  emir=%s  hedefe=%.1f  kopruye=%.1f  kara=%s  pos=%s  dest=%s" % [u.d.name, u.order, Entity.flat(u.position, gr[1]), br.dist_to(u.position), not ter.solid(u.position), u.position, u.dest])
				if u.alive and Entity.flat(u.position, gr[1]) <= 13.0:
					a_n += 1
				elif u.alive and ter.on_bridge(u.position):
					d_n += 1
		arrived += a_n
		on_deck += d_n
		print("KOPRU %d  uzunluk=%.0f  genislik=%.0f  varan=%d/%d  koprude kalan=%d  sure=%.0f sn  takildi=%d" % [
			g.bridges.find(br), br.a.distance_to(br.b), br.w, a_n, PER_SIDE * 2, d_n, t, stuck_idle])
		for gr in groups:
			for u in gr[0]:
				if u.alive:
					u.die()
		for u in extra:
			if u.alive:
				u.die()
		await _wait(1.5)
	var ok := tested > 0 and arrived >= int(total * 0.9) and on_deck == 0
	print(("GECTI  " if ok else "KALDI  ") + "kopru gecisi: varan %d/%d, koprude kalan %d" % [arrived, total, on_deck])
	if not ok:
		fails += 1
	print("BRIDGETEST BITTI  hata=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


## Gerçek maç: yapay zekâ orduları oynar (oyuncu boş durur). Köprünün yakınında yürümek isteyip 20 saniyedir
## yerinden kıpırdamayan birlikleri sayar.
func _watch() -> void:
	var g := Game.I
	var ter := g.terrain
	var mins := 18.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mins="):
			mins = float(a.trim_prefix("--mins="))
	var last := {}     # birim -> [konum, kıpırdamadan geçen süre]
	var reported := {}
	var stuck := 0
	var crossings := 0
	var side_of := {}   # birim -> son bilinen köprü tarafı (geçiş sayımı)
	var t := 0.0
	while t < mins * 60.0:
		await _wait(2.0)
		t += 2.0
		for e in g.entities:
			if not (e is Unit) or not e.alive:
				continue
			var u: Unit = e
			var near_br = null
			for br in g.bridges:
				if br.alive and br.dist_to(u.position) < 12.0:
					near_br = br
			if near_br != null:
				var ax: Vector3 = near_br.b - near_br.a
				var sd := signf(ax.dot(u.position - near_br.position))
				if side_of.has(u) and side_of[u] != sd and absf(ax.normalized().dot(u.position - near_br.position)) > 4.0:
					crossings += 1
				if absf(ax.normalized().dot(u.position - near_br.position)) > 4.0:
					side_of[u] = sd
			# İlerleme ölçütü: hedefe olan uzaklık 20 saniyede 2 birimden az azaldıysa (itişip bocalıyorsa) takılmıştır.
			# Takılma: yürümek isteyip (hedefsiz) 16 saniyede net 4 birimden az yer değiştiren birlik (yerinde itişip bocalıyor).
			var wants: bool = u.order in ["move", "amove", "patrol"] and u.target == null
			var gd := Entity.flat(u.position, u.dest)
			if not last.has(u) or not wants or gd < 6.0 or Entity.flat(u.position, last[u][0]) > 4.0:
				last[u] = [u.position, 0.0, u.position, 0.0]
				continue
			last[u][1] += 2.0
			last[u][3] += Entity.flat(u.position, last[u][2])
			last[u][2] = u.position
			if last[u][1] >= 16.0 and near_br != null and not reported.has(u):
				reported[u] = true
				stuck += 1
				var gx := g.get_children().filter(func(c): return c is EnemyAI and c.T == u.team)
				var role := "-"
				if not gx.is_empty():
					role = str(gx[0].roles.get(u, "ordu"))
				print("  TAKILDI %.0fs  %s (takım %d)  emir=%s rol=%s  kopruye=%.1f  hedefe=%.1f  yuruyus=%.1f  nav=%s/%d ok=%s wp=%s  pos=%s dest=%s solid=%s" % [t, u.d.name, u.team, u.order, role, near_br.dist_to(u.position), Entity.flat(u.position, u.dest), last[u][3], u.nav_i, u.nav.size(), u.nav_ok, u.nav_wp, u.position, u.dest, ter.solid(u.position)])
	print("IZLEME  sure=%.0f dk  kopru gecisi=%d  takilan=%d" % [mins, crossings, stuck])
	get_tree().quit(0)
