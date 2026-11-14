class_name ZoneOverlay
extends MeshInstance3D
## İnşa alanı: karargâhın ve binaların çevresindeki dairelerin birleşimi tek bir sarı alan olarak çizilir.
## Daireler üst üste binince koyulaşmaz; yalnızca birleşimin dış sınırı çizgi olur. Gölge düşürmez.

const MAX := 48
const SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec3 circles[48];
uniform int count = 0;
uniform float pulse = 0.0;
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float d = 1e6;
	for (int i = 0; i < 48; i++) {
		if (i >= count) { break; }
		d = min(d, length(wp.xz - circles[i].xy) - circles[i].z);
	}
	float edge = 1.0 - smoothstep(0.12, 0.5, abs(d));
	float fill = d < 0.0 ? 0.09 + 0.03 * pulse : 0.0;
	ALBEDO = vec3(1.0, 0.86, 0.22);
	ALPHA = max(fill, edge * 0.95);
}
"""

var mat: ShaderMaterial


func _ready() -> void:
	var sh := Shader.new()
	sh.code = SHADER
	mat = ShaderMaterial.new()
	mat.shader = sh
	var pm := PlaneMesh.new()
	pm.size = Vector2(Defs.MAP_W, Defs.MAP_H)
	mesh = pm
	material_override = mat
	position.y = 0.26
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


## circles: [[konum, yarıçap], ...]
func show_circles(circles: Array) -> void:
	var arr := PackedVector3Array()
	for c in circles:
		if arr.size() >= MAX:
			break
		var p: Vector3 = c[0]
		arr.append(Vector3(p.x, p.z, float(c[1])))
	while arr.size() < MAX:
		arr.append(Vector3(1e5, 1e5, 0.0))
	mat.set_shader_parameter("circles", arr)
	mat.set_shader_parameter("count", mini(circles.size(), MAX))
	visible = true


func _process(_dt: float) -> void:
	if visible and Game.I != null:
		mat.set_shader_parameter("pulse", 0.5 + 0.5 * sin(Game.I.time * 3.0))
