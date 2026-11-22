class_name Shot
extends MeshInstance3D
## Mermi / füze. Hedefe varınca hasar verir; splash varsa alan hasarı.

var target = null
var src = null
var src_team := 0
var start := Vector3.ZERO
var end := Vector3.ZERO
var speed := 30.0
var arc := 0.0
var homing := false
var base := 0.0
var mult: Dictionary = {}
var splash := 0.0
var tag := ""
var intercept_at := -1.0   # 0..1 arası ise füze o noktada önlenir
var boom := 1.2
var t := 0.0
var dur := 0.1
var trail := false
var trail_t := 0.0
# Balistik füze: canı vardır. Uçuşun ikinci yarısında menzildeki düşman hava savunması önleyici atar ve canını
# düşürür; sıfırlanırsa havada patlar. Hasarlı füze daha az hasar verir.
var bhp := 0.0
var bhp_max := 0.0
var hypersonic := false
var _ad_t := 0.0


func launch() -> void:
	global_position = start
	dur = maxf(0.05, start.distance_to(end) / speed)


func _process(dt: float) -> void:
	if homing and target != null and is_instance_valid(target) and target.alive:
		end = target.aim_pos()
	t += dt / dur
	var f := minf(t, 1.0)
	var before := global_position
	global_position = start.lerp(end, f) + Vector3(0, arc * 4.0 * f * (1.0 - f), 0)
	if trail:
		if global_position.distance_to(before) > 0.01:
			look_at(global_position * 2.0 - before, Vector3.UP if absf((global_position - before).normalized().y) < 0.98 else Vector3.RIGHT)
		trail_t -= dt
		if trail_t <= 0.0:
			trail_t = 0.05
			Game.I.fx_puff(global_position, Color(0.85, 0.85, 0.85), 0.35 * maxf(1.0, boom * 0.3), 0.6, 0.2)
	if bhp_max > 0.0:
		_ad_t -= dt
		var w0 := 0.72 if hypersonic else 0.4
		if _ad_t <= 0.0 and t >= w0 and t < 0.97:
			_ad_t = 0.2
			_air_defense()
			if bhp <= 0.0:
				Game.I.fx_explosion(global_position, 3.5)
				Game.I.on_missile_intercepted(src_team)
				queue_free()
				return
	if intercept_at >= 0.0 and t >= intercept_at:
		Game.I.fx_explosion(global_position, 3.0)
		Game.I.on_missile_intercepted(src_team)
		queue_free()
		return
	if t >= 1.0:
		_hit()


## Menzildeki düşman hava savunmaları (bina ve araç) silahları hazırsa önleyici atar.
func _air_defense() -> void:
	var g := Game.I
	var p := global_position
	for e in g.nearby(Vector3(p.x, 0, p.z), 40.0):
		if not e.alive or not Defs.foe(src_team, e.team) or e.team == Defs.IND or not e.has_weapon():
			continue
		var ad: bool = e.cls in ["sam", "ads", "spaag", "laser"]
		if not ad or e.cd_timer > 0.0 or (e.is_building and (not e.built or not e.powered())):
			continue
		if Entity.flat(e.global_position, p) > e.wrange():
			continue
		e.cd_timer = float(e.d.cd)
		g.fx_tracer(e.muzzle_pos(), p, Color(1.0, 1.0, 0.85) if e.cls != "laser" else Color(0.3, 0.95, 1.0), 0.12, 0.25)
		if randf() < (0.75 if not hypersonic else 0.45):
			var hit: float = float(e.d.dmg) * float(e.d.mult.get("missile", e.d.mult.get("air", 0.0))) * g.mod(e.team, "dmg_" + e.cls)
			bhp -= hit
			g.fx_puff(p, Color(0.95, 0.85, 0.6), 1.2, 0.5, 0.2)
		if bhp <= 0.0:
			return


func _hit() -> void:
	var g := Game.I
	if bhp_max > 0.0:
		# hasarlı füze: savaş başlığının bir kısmı devre dışı
		base *= 0.4 + 0.6 * clampf(bhp / bhp_max, 0.0, 1.0)
	var attacker = src if (src != null and is_instance_valid(src)) else null
	if splash > 0.0:
		g.fx_explosion(end, maxf(boom, splash * 0.8))
		g.splash_damage(end, splash, base, mult, src_team, tag, attacker)
	else:
		g.fx_explosion(end, boom)
		if target != null and is_instance_valid(target) and target.alive:
			target.take_damage(base * float(mult.get(target.armor, 0.0)), attacker, tag)
	queue_free()
