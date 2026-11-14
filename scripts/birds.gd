class_name Birds
extends Node3D
## Atmosfer: haritanın üstünden geçen kuş sürüleri ve tepelerin üstünde süzülen yırtıcılar.
## Tek MultiMesh; kanat çırpma shader'dadır. Oynanışa etkisi yoktur.

const FLOCKS := 3
const SOARERS := 2

var mm := MultiMesh.new()
var flocks: Array = []     # {pos, yaw, speed, alt, turn, t, n, first}
var soarers: Array = []    # {ctr, r, a, w, alt, i}


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var total := 0
	for f in FLOCKS:
		var n := rng.randi_range(5, 9)
		flocks.append({
			pos = Vector3(rng.randf_range(-90.0, 90.0), 0, rng.randf_range(-60.0, 60.0)), yaw = rng.randf() * TAU,
			speed = rng.randf_range(5.0, 7.5), alt = rng.randf_range(7.0, 10.0), turn = 0.0, t = rng.randf() * 20.0,
			n = n, first = total})
		total += n
	# yırtıcılar tepe ve dağların üstünde döner
	var spots: Array = Defs.MAP.get("hills", []) + Defs.MAP.rock
	for s in mini(SOARERS, spots.size()):
		var r: Array = spots[rng.randi() % spots.size()]
		soarers.append({
			ctr = Vector3((r[0] + r[2]) * 0.5, 0, (r[1] + r[3]) * 0.5), r = rng.randf_range(7.0, 12.0),
			a = rng.randf() * TAU, w = rng.randf_range(0.22, 0.32) * (1.0 if s % 2 == 0 else -1.0),
			alt = rng.randf_range(10.0, 12.0), i = total})
		total += 1
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = Scenery.mesh("bird")
	mm.instance_count = total
	for f in flocks:
		for i in f.n:
			mm.set_instance_custom_data(f.first + i, Color(rng.randf() * TAU, 0.0, rng.randf_range(9.0, 12.0), 0))
	for s in soarers:
		mm.set_instance_custom_data(s.i, Color(rng.randf() * TAU, 1.0, 2.0, 0))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = Scenery.shader_mat(Scenery.BIRD_SHADER)
	mi.custom_aabb = AABB(Vector3(-200, 0, -200), Vector3(400, 40, 400))
	add_child(mi)
	_process(0.0)


func _process(dt: float) -> void:
	var lim_x := Defs.MAP_W * 0.5 + 25.0
	var lim_z := Defs.MAP_H * 0.5 + 25.0
	for f in flocks:
		f.t += dt
		# gelişigüzel süzülür; haritadan uzaklaşınca merkeze döner
		var want: float = sin(f.t * 0.13) * 0.18 + sin(f.t * 0.31) * 0.1
		var p: Vector3 = f.pos
		if absf(p.x) > lim_x or absf(p.z) > lim_z:
			var home := atan2(-p.x, -p.z)
			want = clampf(angle_difference(f.yaw, home), -0.5, 0.5)
		f.turn = lerpf(f.turn, want, minf(1.0, dt * 1.5))
		f.yaw += f.turn * dt
		var fwd := Vector3(sin(f.yaw), 0.0, cos(f.yaw))
		f.pos = p + fwd * f.speed * dt
		var yaw: float = f.yaw
		var bank: float = f.turn
		var basis := Basis(Vector3.UP, yaw + PI) * Basis(Vector3.BACK, -bank * 1.2)
		for i in int(f.n):
			# V düzeni: sırayla sağ ve sol kanatta, öndekinin biraz gerisinde
			var row: int = (i + 1) / 2
			var side := 1.0 if i % 2 == 0 else -1.0
			var off := Vector3(side * row * 1.5, sin(f.t * 0.9 + i * 1.7) * 0.35, row * 1.3 + sin(f.t * 0.5 + i) * 0.3)
			var s := 0.95
			mm.set_instance_transform(f.first + i, Transform3D(basis * Basis.from_scale(Vector3(s, s, s)),
				p + Vector3(0, f.alt, 0) + Basis(Vector3.UP, yaw + PI) * off))
	for s in soarers:
		s.a += s.w * dt
		var c: Vector3 = s.ctr
		var a: float = s.a
		var rad: float = s.r
		var alt: float = s.alt
		var p := c + Vector3(cos(a) * rad, alt + sin(a * 0.7) * 1.2, sin(a) * rad)
		var dir: float = signf(s.w)
		var yaw := atan2(-sin(a) * dir, cos(a) * dir)
		var b := Basis(Vector3.UP, yaw + PI) * Basis(Vector3.BACK, -0.35 * dir)
		mm.set_instance_transform(s.i, Transform3D(b * Basis.from_scale(Vector3(1.5, 1.5, 1.5)), p))
