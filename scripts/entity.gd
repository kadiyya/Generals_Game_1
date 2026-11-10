class_name Entity
extends Node3D
## Birim ve binaların ortak tabanı: can, takım, hedef bulma ve ateş etme.

var team := 0
var def_id := ""
var d: Dictionary = {}
var hp := 1.0
var max_hp := 1.0
var alive := true
var is_building := false
var is_air := false
var armor := "light"
var radius := 1.0
var vision := 12.0
var seen := true          # oyuncu şu an görüyor mu
var discovered := false   # düşman binası bir kez görüldü mü
var cd_timer := 0.0
var scan_timer := 0.0
var target = null
var model: Node3D
var ring: MeshInstance3D


func setup(id: String, t: int, def: Dictionary) -> void:
	def_id = id
	team = t
	d = def
	max_hp = float(d.hp)
	hp = max_hp
	armor = d.get("armor", "light")
	radius = float(d.get("radius", 1.0))
	vision = float(d.get("vision", 12.0))
	is_air = d.get("air", false)
	model = Models.build(id, t)
	add_child(model)
	ring = Models.ring(radius + 0.4)
	ring.visible = false
	add_child(ring)
	seen = (t == Defs.PLAYER)
	visible = seen
	scan_timer = randf() * 0.3


static func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func aim_pos() -> Vector3:
	return global_position + Vector3(0, 0.8, 0)


func muzzle_pos() -> Vector3:
	return global_position + Vector3(0, 1.3, 0)


func set_selected(v: bool) -> void:
	ring.visible = v


func has_weapon() -> bool:
	return d.has("dmg")


func valid_target() -> bool:
	if target == null:
		return false
	if not is_instance_valid(target) or not target.alive or not can_hit(target):
		target = null
		return false
	return true


func can_hit(e) -> bool:
	if not e.alive or e.team == team or not d.has("dmg"):
		return false
	var air_weapon: bool = d.get("targets", "ground") == "air"
	if e.is_air != air_weapon:
		return false
	if float(d.mult.get(e.armor, 0.0)) <= 0.0:
		return false
	# Hava savunma radarla görür; yer hedefleri için takımın görüşü şart.
	if not air_weapon and not Game.I.fog.sees(team, e.global_position):
		return false
	return true


func find_target(max_d: float, min_d := 0.0, from := Vector3.INF):
	var origin: Vector3 = global_position if from == Vector3.INF else from
	var best = null
	var best_s := 1e9
	for e in Game.I.entities:
		if not can_hit(e):
			continue
		var dist: float = flat(origin, e.global_position) - e.radius
		if dist > max_d or dist < min_d:
			continue
		var s: float = dist / (0.3 + float(d.mult.get(e.armor, 0.0)))
		if s < best_s:
			best_s = s
			best = e
	return best


func fire(e) -> void:
	cd_timer = float(d.cd)
	var g := Game.I
	var base: float = float(d.dmg)
	match d.get("proj", "tracer"):
		"tracer":
			g.fx_tracer(muzzle_pos(), e.aim_pos())
			e.take_damage(base * float(d.mult.get(e.armor, 0.0)), self)
		"arc":
			g.fx_shot(self, e, base, 26.0, 9.0, false)
		"missile":
			g.fx_shot(self, e, base, 30.0, 0.0, true)
		_:
			g.fx_shot(self, e, base, 45.0, 0.0, false)


func take_damage(amount: float, attacker = null) -> void:
	if not alive:
		return
	hp -= amount
	_on_damaged(attacker)
	if hp <= 0.0:
		die()


func _on_damaged(_attacker) -> void:
	pass


func die() -> void:
	alive = false
	Game.I.fx_explosion(aim_pos(), radius * 1.6)
	Game.I.on_entity_died(self)
	visible = false
	set_process(false)
	get_tree().create_timer(1.0).timeout.connect(queue_free)
