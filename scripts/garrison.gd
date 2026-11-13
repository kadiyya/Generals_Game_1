class_name Garrison
extends Node3D
## Köy evi: en çok iki piyade birliği girebilir. İçerideki birlik %60 az hasar alır, menzili artar.
## Ev bir takıma ait değildir; içinde kim varsa onundur. Ev yıkılmaz (prototip).

const CAP := 2
const RADIUS := 2.4

var units: Array = []
var flag: MeshInstance3D


func setup(p: Vector3) -> void:
	position = p
	rotation.y = (int(absf(p.x + p.z)) % 4) * PI * 0.5
	add_child(Models.build({"model": "house"}, Defs.PLAYER))
	flag = Models.box(self, Vector3(1.0, 0.6, 0.05), Vector3(1.6, 3.9, 1.4), Color(0.85, 0.85, 0.85))
	Models.cyl(self, 0.05, 0.05, 2.2, Vector3(1.1, 3.0, 1.4), Models.DARK)
	Game.I.terrain.block_circle(p, RADIUS, true)


func owner_team() -> int:
	_prune()
	return units[0].team if not units.is_empty() else Defs.NEUTRAL


func has_room(team: int) -> bool:
	var o := owner_team()
	return units.size() < CAP and (o == Defs.NEUTRAL or o == team)


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
