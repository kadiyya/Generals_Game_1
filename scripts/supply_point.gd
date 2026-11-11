class_name SupplyPoint
extends Node3D
## Ele geçirilebilir ikmal noktası. Yalnızca piyade mangası ele geçirir.

const RADIUS := 6.0
const VISION := 10.0

var owner_team := Defs.NEUTRAL
var income := 5.0
var cap_time := 10.0
var is_oil := false
var cap_team := Defs.NEUTRAL
var cap_t := 0.0
var flag: MeshInstance3D


func setup(p: Vector3, inc: float, ct: float, oil: bool) -> void:
	position = p
	income = inc
	cap_time = ct
	is_oil = oil
	add_child(Models.supply_point(oil))
	flag = Models.box(self, Vector3(1.5, 0.9, 0.06), Vector3(-1.1, 3.5, 1.6), Color(0.9, 0.9, 0.9))


func _process(dt: float) -> void:
	var n := [0, 0]
	for e in Game.I.entities:
		if e.alive and not e.is_building and e.d.get("capture", false) and Entity.flat(e.position, position) <= RADIUS:
			n[e.team] += 1
	var who := Defs.NEUTRAL
	if n[0] > 0 and n[1] == 0:
		who = 0
	elif n[1] > 0 and n[0] == 0:
		who = 1
	if who != Defs.NEUTRAL and who != owner_team:
		if cap_team != who:
			cap_team = who
			cap_t = 0.0
		cap_t += dt
		if cap_t >= cap_time:
			owner_team = who
			cap_t = 0.0
			cap_team = Defs.NEUTRAL
			flag.material_override = Models.mat(Defs.TEAM_COLORS[who])
			Game.I.on_point_captured(self)
	elif n[0] == 0 and n[1] == 0:
		cap_t = maxf(0.0, cap_t - dt)
