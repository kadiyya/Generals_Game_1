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
var t := 0.0
var dur := 0.1


func launch() -> void:
	global_position = start
	dur = maxf(0.05, start.distance_to(end) / speed)


func _process(dt: float) -> void:
	if homing and target != null and is_instance_valid(target) and target.alive:
		end = target.aim_pos()
	t += dt / dur
	var f := minf(t, 1.0)
	global_position = start.lerp(end, f) + Vector3(0, arc * 4.0 * f * (1.0 - f), 0)
	if t >= 1.0:
		_hit()


func _hit() -> void:
	var g := Game.I
	var attacker = src if (src != null and is_instance_valid(src)) else null
	if splash > 0.0:
		g.fx_explosion(end, splash * 0.8)
		for e in g.entities.duplicate():
			if e.alive and e.team != src_team and not e.is_air:
				var dist: float = Entity.flat(e.global_position, end) - e.radius
				if dist <= splash:
					e.take_damage(base * float(mult.get(e.armor, 0.0)), attacker)
	else:
		g.fx_explosion(end, 1.2)
		if target != null and is_instance_valid(target) and target.alive:
			target.take_damage(base * float(mult.get(target.armor, 0.0)), attacker)
	queue_free()
