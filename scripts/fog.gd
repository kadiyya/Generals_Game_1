class_name Fog
extends Node3D
## Savaş sisi. Her takım için bir görüş ızgarası tutar; oyuncununki haritaya çizilir.

const CELL := 2.0
const SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D vis : filter_linear, repeat_disable;
void fragment() {
	float v = texture(vis, UV).r;
	ALBEDO = vec3(0.02, 0.03, 0.05);
	ALPHA = (1.0 - v) * 0.6;
}
"""

var gw := 0
var gh := 0
var grids: Array = []
var tex: ImageTexture
var timer := 0.0


func _ready() -> void:
	gw = int(ceil(Defs.MAP_W / CELL))
	gh = int(ceil(Defs.MAP_H / CELL))
	for i in 2:
		var a := PackedByteArray()
		a.resize(gw * gh)
		grids.append(a)
	tex = ImageTexture.create_from_image(Image.create_from_data(gw, gh, false, Image.FORMAT_L8, grids[0]))
	var sh := Shader.new()
	sh.code = SHADER
	var sm := ShaderMaterial.new()
	sm.shader = sh
	sm.set_shader_parameter("vis", tex)
	var pm := PlaneMesh.new()
	pm.size = Vector2(Defs.MAP_W, Defs.MAP_H)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = sm
	mi.position.y = 0.2
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _process(dt: float) -> void:
	timer -= dt
	if timer <= 0.0:
		timer = 0.2
		recompute()


func recompute() -> void:
	var g := Game.I
	for i in 2:
		grids[i].fill(0)
	for e in g.entities:
		if e.alive:
			var v: float = e.vision
			if e.is_building and not e.built:
				v = 6.0
			_stamp(e.team, e.global_position, v)
	for p in g.points:
		if p.owner_team != Defs.NEUTRAL:
			_stamp(p.owner_team, p.position, SupplyPoint.VISION)
	tex.update(Image.create_from_data(gw, gh, false, Image.FORMAT_L8, grids[Defs.PLAYER]))
	for e in g.entities:
		if e.team == Defs.PLAYER:
			continue
		var s := sees(Defs.PLAYER, e.global_position)
		if e.is_building:
			if s:
				e.discovered = true
			s = e.discovered
		e.seen = s
		e.visible = s


func _stamp(team: int, pos: Vector3, r: float) -> void:
	var grid: PackedByteArray = grids[team]
	var cx := (pos.x + Defs.MAP_W * 0.5) / CELL
	var cy := (pos.z + Defs.MAP_H * 0.5) / CELL
	var cr := r / CELL
	var x0 := maxi(0, int(cx - cr))
	var x1 := mini(gw - 1, int(cx + cr))
	var y0 := maxi(0, int(cy - cr))
	var y1 := mini(gh - 1, int(cy + cr))
	var r2 := cr * cr
	for y in range(y0, y1 + 1):
		var dy := y + 0.5 - cy
		for x in range(x0, x1 + 1):
			var dx := x + 0.5 - cx
			if dx * dx + dy * dy <= r2:
				grid[y * gw + x] = 255
	grids[team] = grid


func sees(team: int, pos: Vector3) -> bool:
	var x := int((pos.x + Defs.MAP_W * 0.5) / CELL)
	var y := int((pos.z + Defs.MAP_H * 0.5) / CELL)
	if x < 0 or y < 0 or x >= gw or y >= gh:
		return false
	return grids[team][y * gw + x] > 0
