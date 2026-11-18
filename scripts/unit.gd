class_name Unit
extends Entity
## Kara birimi. Emirler: idle, move (emredilen yere git; yolda menzildekine durmadan ateş eder), amove (saldırarak ilerle), attack,
## dig (siper kaz), mine (mayın döşe), obstacle (engel kur), enter (eve gir).
## Engellerin çevresinden Terrain üzerinden yol bulur; tepede yükselir, yolda hızlanır, ormanda yavaşlar.
## Emir önceliklidir: yürüyen birim düşmana sapmaz. Boştaki birim yakına gelen düşmana saldırır ama bulunduğu
## yerden LEASH'ten fazla uzaklaşmaz, sonra yerine döner.

const LEASH := 24.0
const TURRET_SPEED := 1.9    # kule dönüş hızı (rad/sn)

var order := "idle"
var dest := Vector3.ZERO
var speed := 4.0
var near_t := 0.0
var nav := PackedVector3Array()
var nav_i := 0
var nav_goal := Vector3.INF
var nav_wp := Vector3.ZERO
var nav_t := 0.0
var nav_ok := true
var turret: Node3D = null    # varsa gövdeden bağımsız döner
var turret_base := Vector3.ZERO   # kulenin dönme merkezi (geri tepme buradan ölçülür)
var recoil := 0.0
var anim_t := 0.0
var moving := false
var dust_t := 0.0
var _last_pos := Vector3.ZERO
var task_t := 0.0
var entrenched := false
var trench: Node3D = null
var garrison = null            # içinde bulunduğu ev (Garrison)
var enter_target = null
var retreating := false
var ew_ring: MeshInstance3D = null
var los_t := 0.0
var patrol_a := Vector3.ZERO
var stuck_t := 0.0
var stuck_n := 0
var stuck_pos := Vector3.INF
var patrol_b := Vector3.ZERO
var los_ok := true
var supplied := true       # ikmal hattında mı (Game her saniye günceller)
var hold_pos := Vector3.INF   # boştaki birimin nöbet yeri (kovalarken buradan LEASH'ten fazla uzaklaşmaz)
var figs: Array = []          # piyade: [{n, body, legs: [sol, sağ], phase, kick, down}]


func setup(id: String, t: int, def: Dictionary) -> void:
	super.setup(id, t, def)
	speed = float(d.speed)
	rotation.y = PI * 0.5 if position.x < 0.0 else -PI * 0.5
	turret = model.get_node_or_null("turret")
	if turret != null:
		turret_base = turret.position
	for i in model.get_child_count():
		var f: Node3D = model.get_child(i)
		var body: Node3D = f.get_node_or_null("body")
		if body != null:
			figs.append({n = f, body = body, legs = [f.get_node("leg_l"), f.get_node("leg_r")],
				knees = [f.get_node("leg_l/knee"), f.get_node("leg_r/knee")], phase = randf() * TAU,
				kick = 0.0, kick_t = -1.0, down = false})
	_last_pos = position
	if d.has("ew"):
		ew_ring = Models.ring(float(d.ew), Color(0.35, 0.85, 1.0))
		ew_ring.scale.y = 0.08
		add_child(ew_ring)


func muzzle_pos() -> Vector3:
	var yaw := rotation.y + (turret.rotation.y if turret != null else 0.0)
	var reach: float = 0.6 if armor == "inf" else radius + 1.0
	var pivot := global_transform.basis * turret_base
	return global_position + pivot + Vector3(sin(yaw), 0, cos(yaw)) * reach + Vector3(0, 1.25 if armor != "inf" else 0.75, 0)


func _on_fired() -> void:
	recoil = 1.0
	# mangadaki askerler sırayla tetik çeker
	for f in figs:
		if not f.down:
			f.kick_t = randf_range(0.0, 0.3)


func damage_base() -> float:
	return super.damage_base() * (1.0 if supplied else Defs.OOS_DMG)


func wrange() -> float:
	return super.wrange() + (garrison.range_bonus if garrison != null else 0.0)


## Orman ve ağaç hattında gizlenir: piyade yürürken de, araç yalnızca dururken. Ateş edince bir süre görünür.
func concealed() -> bool:
	if reveal_t > 0.0 or garrison != null or not Game.I.terrain.cover_at(global_position):
		return false
	return armor == "inf" or not moving


func damage_taken_mult() -> float:
	var m := super.damage_taken_mult()
	if garrison != null:
		m *= garrison.protect
	elif entrenched:
		m *= 0.5
	if retreating:
		m *= 0.7
	return m


## Görev emri: siper, mayın, engel. Birim durur ve görev süresi dolunca iş biter.
func do_task(kind: String) -> void:
	_leave()
	order = kind
	target = null
	task_t = 0.0


## Devriye: bulunduğu yerle p arasında saldırarak gidip gelir.
func patrol_to(p: Vector3) -> void:
	patrol_a = position
	go(p, true)
	patrol_b = dest
	order = "patrol"


func enter(house) -> void:
	_leave()
	enter_target = house
	go(house.position, false)
	enter_target = house
	order = "enter"


func _leave() -> void:
	if garrison != null:
		garrison.remove(self)
		garrison = null
		model.visible = true
		position = Game.I.terrain.nearest_free(position + Vector3(0, 0, 3.2))
	if entrenched:
		entrenched = false
		if trench != null:
			trench.queue_free()
			trench = null


func go(p: Vector3, attack_move: bool) -> void:
	_leave()
	retreating = false
	enter_target = null
	dest = Game.I.terrain.nearest_free(Vector3(p.x, 0, p.z))
	order = "amove" if attack_move else "move"
	target = null
	hold_pos = Vector3.INF
	near_t = 0.0
	nav_goal = Vector3.INF


func attack(e) -> void:
	target = e
	order = "attack"


func stop() -> void:
	order = "idle"
	target = null
	retreating = false
	hold_pos = Vector3.INF


func weapon_range() -> float:
	return wrange()


func _process(dt: float) -> void:
	if not alive:
		return
	cd_timer -= dt
	scan_timer -= dt
	reveal_t -= dt
	valid_target()
	match order:
		"move":
			_fire_on_move(dt)
			if _step(dest, dt):
				order = "idle"
				retreating = false
		"enter":
			var h = enter_target
			if h == null or not h.has_room(team):
				order = "idle"
			elif flat(position, h.position) < 4.5 or _step(dest, dt):
				if flat(position, h.position) < 6.0 and h.has_room(team):
					h.add(self)
					garrison = h
					model.visible = false
				order = "idle"
		"patrol":
			_scan()
			if target != null:
				_engage(dt, true)
			elif _step(dest, dt):
				dest = patrol_a if dest.distance_to(patrol_b) < 1.0 else patrol_b
				nav_goal = Vector3.INF
		"dig", "mine", "obstacle":
			task_t += dt
			var need := Defs.DIG_TIME if order == "dig" else (3.0 if order == "mine" else 5.0)
			if task_t >= need:
				_finish_task()
		"attack":
			if target == null:
				order = "idle"
			else:
				_engage(dt, true)
		"amove":
			_scan()
			if target != null:
				_engage(dt, true)
			elif _step(dest, dt):
				order = "idle"
		_:
			if hold_pos == Vector3.INF:
				hold_pos = position
			_scan()
			if target != null:
				_engage(dt, not d.get("no_chase", false) and not guard)
			if target != null and flat(position, hold_pos) > LEASH and garrison == null and not entrenched:
				# Fazla uzaklaştı: hedefi bırakıp nöbet yerine dön (dönerken menzildekine ateş eder).
				var home := hold_pos
				go(home, false)
	_animate(dt)


## Yürürken menzile giren düşmana durmadan ateş: kule hedefi izler, piyade yürüyerek ateş eder.
## Topçu yürürken ateş edemez. Hedef menzilden çıkınca bırakılır; birim yoluna devam eder.
func _fire_on_move(dt: float) -> void:
	if not has_weapon() or d.get("no_chase", false):
		return
	if target == null:
		if scan_timer > 0.0:
			return
		scan_timer = 0.3
		target = find_target(weapon_range(), float(d.get("min_range", 0.0)))
		los_t = 0.0
		if target == null:
			return
	var dist: float = flat(position, target.position) - target.radius
	if dist > weapon_range() + 0.5:
		target = null
		return
	los_t -= dt
	if los_t <= 0.0:
		los_t = 0.5
		los_ok = target.is_air or not needs_los() or Game.I.terrain.los_clear(global_position, target.global_position)
	if not los_ok:
		target = null
		return
	var aimed := true
	if turret != null:
		aimed = _aim_turret(target.position, dt)
	elif armor != "inf":
		var to: Vector3 = target.position - position
		aimed = absf(angle_difference(rotation.y, atan2(to.x, to.z))) < 0.35
	if aimed and cd_timer <= 0.0:
		fire(target)


## Kuleyi dünyadaki p noktasına döndürür; nişan alındıysa true.
func _aim_turret(p: Vector3, dt: float) -> bool:
	var to := p - position
	var want := atan2(to.x, to.z) - rotation.y
	turret.rotation.y = rotate_toward(turret.rotation.y, want, dt * TURRET_SPEED)
	return absf(angle_difference(turret.rotation.y, want)) < 0.1


func _scan() -> void:
	if target != null or scan_timer > 0.0 or not has_weapon():
		return
	scan_timer = 0.3
	# Görüş alanındaki her düşmana kendiliğinden saldırır (topçu menzilindekine, gördüğü kadarıyla).
	var r := maxf(weapon_range(), vision)
	target = find_target(r, float(d.get("min_range", 0.0)))


func _engage(dt: float, chase: bool) -> void:
	# Siperdeki ve evdeki birlik mevziini bırakıp kovalamaz.
	chase = chase and garrison == null and not entrenched
	var dist: float = flat(position, target.position) - target.radius
	los_t -= dt
	if los_t <= 0.0:
		los_t = 0.5
		los_ok = target.is_air or not needs_los() or Game.I.terrain.los_clear(global_position, target.global_position)
	if turret != null and target != null:
		# Kule hedefi hep izler: yaklaşırken de namlu hedefe döner.
		_aim_turret(target.position, dt)
	if not los_ok:
		# Arada engel var: görüş hattı açılana kadar yaklaş.
		if chase:
			_step(target.position, dt)
		else:
			target = null
	elif dist > weapon_range():
		if chase:
			_step(target.position, dt)
		else:
			target = null
	elif dist < float(d.get("min_range", 0.0)):
		target = null
	else:
		var to: Vector3 = target.position - position
		var dir := Vector3(to.x, 0, to.z).normalized()
		var aimed := true
		if turret != null:
			# Gövde yerinde kalır, kule hedefe döner; nişan alınmadan ateş edilmez.
			aimed = absf(angle_difference(turret.rotation.y, atan2(dir.x, dir.z) - rotation.y)) < 0.1
		else:
			_face(dir, dt)
		if aimed and cd_timer <= 0.0:
			fire(target)


func _finish_task() -> void:
	var g := Game.I
	var fwd := Vector3(sin(rotation.y), 0, cos(rotation.y))
	match order:
		"dig":
			entrenched = true
			trench = Models.build({"model": "trench"}, team)
			add_child(trench)
		"mine":
			g.place_mine(team, position + fwd * 2.5)
		"obstacle":
			g.place_obstacle(team, position + fwd * 4.0)
	order = "idle"


func _waypoint(p: Vector3, dt: float) -> Vector3:
	nav_t -= dt
	if nav_t > 0.0 and nav_goal.distance_to(p) < 3.0 and flat(position, nav_wp) > 1.0:
		return nav_wp
	nav_t = 0.25
	var ter := Game.I.terrain
	if flat(position, p) < 26.0 and ter.line_clear(position, p):
		nav = PackedVector3Array()
		nav_goal = p
		nav_wp = p
		nav_ok = true
		return p
	if nav.is_empty() or nav_goal.distance_to(p) > 3.0:
		nav = ter.find_path(position, p)
		nav_i = 0
		nav_goal = p
		nav_ok = not nav.is_empty()
		if not nav_ok:
			nav_wp = position
			return position
	while nav_i < nav.size() - 1 and (flat(position, nav[nav_i]) < 1.6 or (flat(position, nav[nav_i + 1]) < 10.0 and ter.line_clear(position, nav[nav_i + 1]))):
		nav_i += 1
	nav_wp = nav[nav_i]
	return nav_wp


func _step(p: Vector3, dt: float) -> bool:
	var dist := flat(position, p)
	if dist < 0.7:
		return true
	if dist < 4.0:
		# Kalabalıkta hedef noktaya tam ulaşılamıyorsa bir süre sonra varmış say.
		near_t += dt
		if near_t > 1.5:
			near_t = 0.0
			return true
	else:
		near_t = 0.0
	# Sıkışma: 1,5 saniyede neredeyse hiç ilerlemediyse yolu yeniden hesapla ve yana kay;
	# üst üste üç kez sıkışırsa vardığını kabul et (kalabalık geçitte sonsuza dek itişmesin).
	stuck_t += dt
	if stuck_t >= 1.5:
		stuck_t = 0.0
		if stuck_pos != Vector3.INF and flat(position, stuck_pos) < 0.6:
			stuck_n += 1
			nav_goal = Vector3.INF
			nav_t = 0.0
			var side := Vector3(-(p.z - position.z), 0, p.x - position.x).normalized() * (1.0 if stuck_n % 2 == 0 else -1.0)
			if not Game.I.terrain.solid(position + side * 1.2):
				position += side * 0.9
			if stuck_n >= 3:
				stuck_n = 0
				stuck_pos = Vector3.INF
				return true
		else:
			stuck_n = 0
		stuck_pos = position
	var wp := _waypoint(p, dt)
	if not nav_ok:
		return true
	var to := Vector3(wp.x - position.x, 0, wp.z - position.z)
	var l := to.length()
	if l < 0.05:
		nav_t = 0.0
		return false
	var dir := to / l
	var ter := Game.I.terrain
	var sp := speed * ter.speed_mult(position, armor) * (1.25 if retreating else 1.0) * (1.0 if supplied else Defs.OOS_SPEED)
	position += dir * minf(sp * dt, l)
	position.y = lerpf(position.y, ter.height(position), minf(1.0, dt * 6.0))
	position.x = clampf(position.x, -Defs.MAP_W * 0.5 + 1.0, Defs.MAP_W * 0.5 - 1.0)
	position.z = clampf(position.z, -Defs.MAP_H * 0.5 + 1.0, Defs.MAP_H * 0.5 - 1.0)
	_face(dir, dt)
	return false


func _face(dir: Vector3, dt: float) -> void:
	if dir.length_squared() < 0.0001:
		return
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(1.0, dt * 8.0))


func _animate(dt: float) -> void:
	if dt <= 0.0:
		return
	var v := flat(position, _last_pos) / dt
	_last_pos = position
	moving = v > 0.3
	recoil = maxf(0.0, recoil - dt * 4.0)
	if ew_ring != null:
		ew_ring.visible = seen
		var pulse := 1.0 + 0.04 * sin(Game.I.time * 3.0)
		ew_ring.scale = Vector3(pulse, 0.08, pulse)
	if garrison != null:
		return
	if armor == "inf":
		_animate_figures(dt, v)
		return
	# Araç: giderken hafif sallanır, ateş edince geri teper, arkasında toz kaldırır.
	anim_t += dt * v * 1.6
	model.position.y = sin(anim_t) * 0.035 if moving else 0.0
	var heavy: bool = d.get("proj", "") in ["shell", "arc"]
	var kick := recoil * (0.4 if heavy else 0.08)
	if turret != null:
		if target == null:
			# Boşta kule ağır ağır çevreyi gözler; yürürken öne döner.
			var look := 0.0
			if order == "idle" and not moving:
				look = sin(Game.I.time * 0.22 + get_instance_id() % 97) * 0.7
			turret.rotation.y = rotate_toward(turret.rotation.y, look, dt * 0.7)
		turret.position = turret_base + Vector3(-sin(turret.rotation.y), 0, -cos(turret.rotation.y)) * kick
		model.rotation.x = lerpf(model.rotation.x, -kick * 0.12 * cos(turret.rotation.y), minf(1.0, dt * 14.0))
		model.rotation.z = lerpf(model.rotation.z, kick * 0.12 * sin(turret.rotation.y), minf(1.0, dt * 14.0))
	else:
		model.position.z = -kick
		model.rotation.x = lerpf(model.rotation.x, -kick * 0.15, minf(1.0, dt * 14.0))
	if moving and seen:
		dust_t -= dt
		if dust_t <= 0.0:
			dust_t = 0.3
			var back := Vector3(-sin(rotation.y), 0, -cos(rotation.y)) * radius
			Game.I.fx_puff(global_position + back + Vector3(randf_range(-0.5, 0.5), 0.3, 0), Game.I.dust_color, 1.0, 0.8, 0.5)


## Piyade askerleri: adım uzunluğuna göre bacak salınımı ve gövde inip kalkması (ayak kaymaz), çatışmada diz çökme,
## atışta sırayla geri tepme, boşta etrafa bakınma. Gövde biraz öne eğik yürür, geri çekilirken koşar.
func _animate_figures(dt: float, v: float) -> void:
	var stance := 0.0     # 0 ayakta, 1 diz çökmüş
	if not moving and (target != null or entrenched or order == "dig"):
		stance = 1.0
	var run := 1.0 if retreating else 0.0
	var k := minf(1.0, dt * 10.0)
	var t: float = Game.I.time
	for f in figs:
		if f.down:
			continue
		var n: Node3D = f.n
		var body: Node3D = f.body
		var legs: Array = f.legs
		if f.kick_t >= 0.0:
			f.kick_t -= dt
			if f.kick_t < 0.0:
				f.kick = 1.0
		f.kick = maxf(0.0, f.kick - dt * 6.0)
		var knees: Array = f.knees
		var swing := 0.0
		var bob := 0.0
		var bend := [0.0, 0.0]
		if moving:
			f.phase += v * dt * (5.2 - run * 1.2)
			swing = sin(f.phase) * lerpf(0.5, 0.75, run)
			bob = absf(cos(f.phase)) * 0.04
			# öne salınan bacağın dizi bükülür
			bend = [maxf(0.0, cos(f.phase)) * (0.9 + run * 0.4), maxf(0.0, -cos(f.phase)) * (0.9 + run * 0.4)]
		var lean := (0.12 + run * 0.18) if moving else 0.0
		var look := 0.0 if moving or stance > 0.0 else sin(t * 0.4 + f.phase) * 0.35
		# diz çökme: sol uyluk öne, baldır dik; sağ diz yerde, baldır geriye yatık
		legs[0].rotation.x = lerpf(legs[0].rotation.x, lerpf(swing, -1.35, stance), k)
		legs[1].rotation.x = lerpf(legs[1].rotation.x, lerpf(-swing, 0.05, stance), k)
		knees[0].rotation.x = lerpf(knees[0].rotation.x, lerpf(bend[0], 1.45, stance), k)
		knees[1].rotation.x = lerpf(knees[1].rotation.x, lerpf(bend[1], 1.5, stance), k)
		n.position.y = lerpf(n.position.y, bob - stance * 0.29, k)
		body.rotation.x = lerpf(body.rotation.x, lean - f.kick * 0.22, k * 1.5)
		body.position.z = lerpf(body.position.z, -f.kick * 0.06, k * 1.5)
		n.rotation.y = lerp_angle(n.rotation.y, look, minf(1.0, dt * 2.0))


func _on_damaged(attacker) -> void:
	update_figures()
	if order == "idle" and target == null and attacker != null and is_instance_valid(attacker) and attacker.alive and can_hit(attacker):
		target = attacker


func update_figures() -> void:
	# Mangada can azaldıkça asker sayısı düşer: vurulan asker yere yığılır, bir süre sonra kaybolur.
	# Onarılınca geri gelir.
	if armor != "inf" or figs.is_empty():
		return
	var n := figs.size()
	var keep := maxi(int(ceil(clampf(hp / max_hp, 0.0, 1.0) * n)), 1) if alive else 0
	for i in n:
		var f: Dictionary = figs[i]
		var fn: Node3D = f.n
		if i < keep and f.down:
			f.down = false
			if f.has("tw") and f.tw.is_valid():
				f.tw.kill()
			fn.visible = true
			fn.rotation = Vector3.ZERO
			fn.position.y = 0.0
		elif i >= keep and not f.down:
			f.down = true
			f.tw = _fall(fn)


## Askerin yere yığılması: devrilir, bir süre yatar, sonra toprağa karışıp kaybolur.
static func _fall(fn: Node3D) -> Tween:
	var side := 1.0 if randf() < 0.5 else -1.0
	var tw := fn.create_tween()
	tw.tween_property(fn, "rotation", Vector3(-1.45, fn.rotation.y + randf_range(-0.6, 0.6), 0.25 * side), 0.45) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(fn, "position:y", 0.08, 0.45)
	tw.tween_interval(3.5)
	tw.tween_property(fn, "position:y", -0.5, 1.2)
	tw.tween_callback(func(): fn.visible = false)
	return tw


## Ölen manganın askerleri yerde kalır ve yığılır (patlama yerine).
func die() -> void:
	if armor == "inf" and garrison == null and model.visible and not figs.is_empty():
		var m := model
		var xf := m.global_transform
		remove_child(m)
		Game.I.add_child(m)
		m.global_transform = xf
		m.visible = seen
		for f in figs:
			if not f.down:
				f.down = true
				_fall(f.n)
		get_tree().create_timer(6.0, false).timeout.connect(func(): if is_instance_valid(m): m.queue_free())
	super.die()
