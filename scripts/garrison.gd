class_name Garrison
extends Node3D
## Piyadenin girebildiği yapı. Kimseye ait değildir; içinde kim varsa onundur. Türler:
##   house:   köy evi, 2 birlik, %60 az hasar, +3 menzil, +6 görüş
##   block:   yıkık apartman, 3 birlik, %65 az hasar, +4 menzil, +10 görüş (üst katlardan gözetler)
##   factory: terk edilmiş fabrika, 4 birlik, %55 az hasar, +3 menzil, +6 görüş
## Yapılar yıkılmaz (prototip).

const TYPES := {
	house = {cap = 2, protect = 0.4, range = 3.0, vision = 6.0, radius = 2.4, model = "house"},
	block = {cap = 3, protect = 0.35, range = 4.0, vision = 10.0, radius = 3.0, model = "block"},
	factory = {cap = 4, protect = 0.45, range = 3.0, vision = 6.0, radius = 4.6, model = "ruin_factory"},
}

var tp := "house"
var cap := 2
var protect := 0.4
var range_bonus := 3.0
var vision_bonus := 6.0
var radius := 2.4
var units: Array = []
var flag: MeshInstance3D


func setup(p: Vector3, kind := "house") -> void:
	position = p
	tp = kind if TYPES.has(kind) else "house"
	var t: Dictionary = TYPES[tp]
	cap = t.cap
	protect = t.protect
	range_bonus = t.range
	vision_bonus = t.vision
	radius = t.radius
	rotation.y = (int(absf(p.x * 3.0 + p.z)) % 4) * PI * 0.5
	add_child(Models.build({"model": t.model}, Defs.PLAYER))
	var top := 3.9 if tp == "house" else (6.6 if tp == "block" else 5.2)
	flag = Models.box(self, Vector3(1.0, 0.6, 0.05), Vector3(radius * 0.65, top, radius * 0.55), Color(0.85, 0.85, 0.85))
	Models.cyl(self, 0.05, 0.05, 2.2, Vector3(radius * 0.65 - 0.5, top - 0.9, radius * 0.55), Models.DARK)
	Game.I.terrain.block_circle(p, radius, true)


func owner_team() -> int:
	_prune()
	return units[0].team if not units.is_empty() else Defs.NEUTRAL


func has_room(team: int) -> bool:
	var o := owner_team()
	return units.size() < cap and (o == Defs.NEUTRAL or o == team)


func add(u) -> void:
	units.append(u)
	u.position = position + Vector3(-0.8 + units.size() * 0.6, 0, 0.3)
	_update_flag()


func remove(u) -> void:
	units.erase(u)
	_update_flag()


func _prune() -> void:
	for u in units.duplicate():
		if not is_instance_valid(u) or not u.alive:
			units.erase(u)


func _update_flag() -> void:
	var o := owner_team()
	flag.material_override = Models.mat(Defs.TEAM_COLORS[o] if o != Defs.NEUTRAL else Color(0.85, 0.85, 0.85))


func _process(_dt: float) -> void:
	var n := units.size()
	_prune()
	if units.size() != n:
		_update_flag()
