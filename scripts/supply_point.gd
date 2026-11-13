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
var beam: Node3D    # petrol pompası: kiriş iner kalkar, krank döner
var crank: Node3D
var pump_t := 0.0


func setup(p: Vector3, inc: float, ct: float, oil: bool) -> void:
	position = p
	income = inc
	cap_time = ct
	is_oil = oil
	var model := Models.supply_point(oil)
	add_child(model)
	var parts := model.get_node_or_null("parts")
	if parts != null:
		beam = parts.get_node_or_null("pump_beam") as Node3D
		crank = parts.get_node_or_null("pump_crank") as Node3D
	flag = Models.box(self, Vector3(1.5, 0.9, 0.06), Vector3(-1.1, 3.5, 1.6), Color(0.9, 0.9, 0.9))


func _process(dt: float) -> void:
	if crank != null and visible:
		# sahipli kuyu hızlı, sahipsiz kuyu ağır çalışır
		pump_t += dt * (1.6 if owner_team != Defs.NEUTRAL else 0.7)
		crank.basis = Basis(crank.get_meta("axis"), -pump_t)
		beam.basis = Basis(beam.get_meta("axis"), sin(pump_t) * 0.28)
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
