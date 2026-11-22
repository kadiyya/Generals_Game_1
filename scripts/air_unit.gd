class_name AirUnit
extends Entity
## Hava aracı: küçük İHA, büyük İHA ve uçak. Bir bölgeye atanır, orada döner.
## Silahlıysa gördüğü hedefi kendisi vurur; mühimmatı bitince üssüne dönüp silahlanır.
## Kamikaze olanlar hedefe dalıp patlar. Bazı küçük İHA'ların uçuş süresi sınırlıdır.

var patrol := Vector3.ZERO
var speed := 8.0
var turn := 2.6
var alt := 9.0
var orbit := 6.0
var leash := 24.0
var yaw := 0.0
var ammo := 0
var state := "patrol"   # patrol / rearm
var rearm_t := 0.0
var life := -1.0
var bob_t := randf() * 6.0
var rotors: Node3D = null   # varsa pervaneler döner
var tank_t := 0.0
var phase_t := 0.0
var rw_start := Vector3.ZERO    # pist başı (iniş / kalkış)
var rw_dir := Vector3.FORWARD
var raid_at := Vector3.ZERO     # hava akını: hedef
var raid_exit := Vector3.ZERO   # hava akını: dönüş (harita dışı)
var bombs := 0
var bomb_t := 0.0
var _dove := false


func setup(id: String, t: int, def: Dictionary) -> void:
	super.setup(id, t, def)
	speed = float(d.speed)
	turn = float(d.get("turn", 2.6))
	alt = float(d.get("alt", 9.0))
	orbit = maxf(5.0, speed * 0.85) if not d.get("small", false) else 3.5
	leash = float(d.get("leash", 24.0))
	ammo = int(d.get("ammo", 0))
	life = float(d.get("life", -1.0))
	yaw = PI * 0.5 if position.x < 0.0 else -PI * 0.5
	position.y = alt
	patrol = position
	rotors = model.get_node_or_null("rotors")
	ring.position.y = 0.0


func aim_pos() -> Vector3:
	return global_position


func muzzle_pos() -> Vector3:
	return global_position + Vector3(0, -0.3, 0)


func set_patrol(p: Vector3) -> void:
	patrol = Vector3(
		clampf(p.x, -Defs.MAP_W * 0.5, Defs.MAP_W * 0.5), 0,
		clampf(p.z, -Defs.MAP_H * 0.5, Defs.MAP_H * 0.5))
	target = null


## Hava akınına çıkar: hedefe uçar, bombalarını bırakır, harita dışına döner ve kaybolur.
func start_raid(p: Vector3, exit_p: Vector3) -> void:
	state = "raid"
	raid_at = p
	raid_exit = exit_p
	bombs = 6
	position.y = alt
	yaw = atan2(p.x - position.x, p.z - position.z)
	if cls in Defs.PLANE_CLASSES:
		Game.I.sfx.play("jet", global_position)


func _raid(dt: float) -> void:
	var g := Game.I
	if bombs > 0:
		_fly(raid_at, dt, alt * 0.75, speed * 1.15)
		var dd := flat(global_position, raid_at)
		if dd < 14.0:
			bomb_t -= dt
			if bomb_t <= 0.0:
				bomb_t = 0.16
				bombs -= 1
				var hit := raid_at + Vector3(randf_range(-7, 7), 0, randf_range(-7, 7))
				var tm := team
				var base := 170.0
				get_tree().create_timer(0.55, false).timeout.connect(func():
					if Game.I == null or Game.I.over:
						return
					Game.I.fx_explosion(hit + Vector3(0, 0.5, 0), 3.0)
					Game.I.fx_scorch(hit, 2.0)
					Game.I.splash_damage(hit, 4.0, base, {inf = 1.0, light = 1.0, heavy = 0.6, bld = 1.2}, tm, "bomb")
					Game.I.sfx.play("boom_s", hit))
				if bombs == 0 and seen:
					g.sfx.play("jet", global_position)
		return
	_fly(raid_exit, dt, -1.0, speed * 1.2)
	if flat(global_position, raid_exit) < 8.0:
		# harita dışına çıktı: sessizce kaybolur
		alive = false
		g.on_entity_died(self)
		queue_free()


func is_kamikaze() -> bool:
	return d.get("kamikaze", false)


func _process(dt: float) -> void:
	if not alive:
		return
	cd_timer -= dt
	scan_timer -= dt
	jammed_t -= dt
	if tanker() and d.has("ammo"):
		# Havada yakıt ikmali: mühimmat havada yenilenir, üsse dönmez.
		tank_t += dt
		if tank_t >= 5.0:
			tank_t = 0.0
			ammo = mini(int(d.ammo), ammo + 1)
			if state in ["rearm", "landing"]:
				state = "patrol"
	if rotors != null and visible:
		for r in rotors.get_children():
			r.rotate_object_local(Vector3.UP, dt * 38.0)
	if life > 0.0:
		life -= dt
		if life <= 0.0:
			die()
			return
	if state == "takeoff":
		_takeoff(dt)
		return
	if state == "raid":
		_raid(dt)
		return
	valid_target()
	if is_kamikaze():
		_kamikaze(dt)
		return
	if has_weapon() and d.has("ammo") and state == "patrol" and ammo <= 0:
		state = "rearm"
		rearm_t = 0.0
		target = null
	if state in ["rearm", "landing", "rollout", "parked"]:
		_rearm(dt)
		return
	if has_weapon():
		_acquire()
		if target != null:
			var dist: float = flat(global_position, target.global_position) - target.radius
			_fly(target.global_position, dt)
			if dist <= wrange() and cd_timer <= 0.0:
				fire(target)
				ammo -= 1
				target = null
			return
	_orbit(patrol, dt)


func tanker() -> bool:
	return cls in Defs.PLANE_CLASSES and Game.I.teams[team].tanker_until > Game.I.time


func _acquire() -> void:
	if jammed_t > 0.0:
		target = null
		return
	if target != null or scan_timer > 0.0:
		return
	scan_timer = 0.4
	var t = find_target(vision)
	if t != null and flat(t.global_position, patrol) <= leash:
		target = t


## Kamikaze: görev bölgesine (patrol çevresi, leash yarıçapı) yakın, tarafının gördüğü herhangi bir düşmanı
## hemen seçer ve doğrudan dalar; bölgede yoksa kendi gördüğünü alır. Hedefe kilitlenince bölgeden çıksa da kovalar.
func _acquire_zone() -> void:
	if jammed_t > 0.0:
		target = null
		return
	if target != null or scan_timer > 0.0:
		return
	scan_timer = 0.2
	var g := Game.I
	var r := leash + 8.0
	var best = null
	var bs := 1e9
	for e in g.nearby(patrol, r + 7.0):
		if not can_hit(e) or e.is_building:
			continue
		if flat(e.global_position, patrol) > r:
			continue
		var s: float = flat(global_position, e.global_position) / (0.3 + float(d.mult.get(e.armor, 0.0)))
		if s < bs:
			bs = s
			best = e
	target = best if best != null else find_target(vision)


func _kamikaze(dt: float) -> void:
	_acquire_zone()
	if target == null:
		_orbit(patrol, dt)
		return
	if not _dove:
		_dove = true
		if seen:
			Game.I.sfx.play("drone", global_position)
	_fly(target.global_position, dt, -1.0, speed * 1.3)
	if flat(global_position, target.global_position) <= target.radius + 1.2:
		var g := Game.I
		var base := damage_base()
		var sp: float = float(d.get("splash", 0.0))
		if sp > 0.0:
			g.splash_damage(target.global_position, sp, base, d.mult, team, "drone")
		else:
			target.take_damage(base * float(d.mult.get(target.armor, 0.0)), null, "drone")
		die()


## Hava alanının pistinden kalkış: pistte hızlanır, sonra tırmanır.
func start_takeoff(start: Vector3, dir: Vector3) -> void:
	state = "takeoff"
	phase_t = 0.0
	rw_start = start
	rw_dir = dir
	position = Vector3(start.x, 0.35, start.z)
	yaw = atan2(dir.x, dir.z)
	rotation.y = yaw
	if cls in Defs.PLANE_CLASSES:
		Game.I.sfx.play("jet", global_position)


func _takeoff(dt: float) -> void:
	phase_t += dt
	var v := speed * clampf(phase_t / 2.5, 0.2, 1.0)
	position += Vector3(sin(yaw), 0, cos(yaw)) * v * dt
	var climb := smoothstep(1.6, 4.2, phase_t)
	position.y = lerpf(0.35, alt, climb)
	model.rotation.x = -0.22 * climb * (1.0 - climb) * 4.0
	if phase_t >= 4.2:
		state = "patrol"
		model.rotation.x = 0.0


## Pist: hava alanı modelinde x = 2.6'da, z boyunca uzanır.
static func runway(home) -> Array:
	var a: Vector3 = home.global_transform * Vector3(2.6, 0, -5.0)
	var b: Vector3 = home.global_transform * Vector3(2.6, 0, 5.0)
	return [a, (b - a).normalized()]


func _rearm(dt: float) -> void:
	var home = Game.I.nearest_building(team, d.get("home", "havaalani"), global_position)
	if home == null:
		# Üs yok: havada bekler (ya da yakıt ikmaliyle yeniden silahlanır).
		state = "rearm"
		_orbit(patrol, dt)
		return
	if home.kind == "havaalani":
		_land(home, dt)
		return
	_orbit(home.global_position, dt)
	if flat(global_position, home.global_position) < orbit + 4.0:
		rearm_t += dt
		hp = minf(max_hp, hp + max_hp * dt / maxf(4.0, float(d.get("rearm", 8.0))))
		if rearm_t >= float(d.get("rearm", 8.0)) * Game.I.mod(team, "rearm"):
			ammo = int(d.get("ammo", 0))
			state = "patrol"


## Pistte iniş, park ve yeniden kalkış: yaklaşma noktasına uçar, alçalarak piste konar, durur,
## silahlanır ve aynı pistten tekrar kalkar.
func _land(home, dt: float) -> void:
	var rw := runway(home)
	var start: Vector3 = rw[0]
	var dir: Vector3 = rw[1]
	match state:
		"rearm":
			var appr := start - dir * 24.0
			_fly(appr, dt)
			if flat(global_position, appr) < 6.0:
				state = "landing"
		"landing":
			var dist := flat(global_position, start)
			var y := lerpf(0.35, alt, clampf(dist / 24.0, 0.0, 1.0))
			_fly(start, dt, y, speed * clampf(0.45 + dist / 40.0, 0.45, 1.0))
			if dist < 2.0:
				state = "rollout"
				phase_t = 0.0
				yaw = atan2(dir.x, dir.z)
		"rollout":
			phase_t += dt
			var v := speed * 0.45 * maxf(0.0, 1.0 - phase_t / 1.6)
			position += dir * v * dt
			position.y = 0.35
			rotation.y = yaw
			model.rotation.z = 0.0
			if phase_t >= 1.6:
				state = "parked"
				rearm_t = 0.0
		"parked":
			rearm_t += dt
			# Pistte onarılır: silahlanma süresinde canı tamamen dolar; ağır hasarlıysa biraz daha bekler.
			var rt := float(d.get("rearm", 8.0)) * Game.I.mod(team, "rearm")
			hp = minf(max_hp, hp + max_hp * dt / maxf(4.0, rt))
			if rearm_t >= rt and hp >= max_hp:
				ammo = int(d.get("ammo", 0))
				start_takeoff(start, dir)


func _orbit(center: Vector3, dt: float) -> void:
	var off := Vector3(global_position.x - center.x, 0, global_position.z - center.z)
	if off.length() > orbit * 1.6:
		_fly(center, dt)
	else:
		var ang := atan2(off.z, off.x) + 0.7
		_fly(center + Vector3(cos(ang), 0, sin(ang)) * orbit, dt)


func _fly(goal: Vector3, dt: float, y := -1.0, spd := -1.0) -> void:
	var to := Vector3(goal.x - position.x, 0, goal.z - position.z)
	var tr := 0.0
	if to.length() > 0.05:
		var want := atan2(to.x, to.z)
		var before := yaw
		yaw = rotate_toward(yaw, want, turn * dt)
		tr = angle_difference(before, yaw) / maxf(dt, 0.001)
	var sp := (spd if spd > 0.0 else speed) * (1.2 if tanker() else 1.0)
	position += Vector3(sin(yaw), 0, cos(yaw)) * sp * dt
	position.y = y if y >= 0.0 else lerpf(position.y, alt, minf(1.0, dt * 2.0))
	rotation.y = yaw
	model.rotation.z = lerpf(model.rotation.z, -tr * 0.2, minf(1.0, dt * 5.0))
	if d.get("small", false):
		bob_t += dt * 5.0
		model.position.y = sin(bob_t) * 0.18
		model.rotation.x = sin(bob_t * 0.7) * 0.08
