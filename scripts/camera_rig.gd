class_name CameraRig
extends Node3D
## Eğik kuşbakışı kamera. focus yerdeki bakış noktası, dist uzaklık.

const PITCH := 1.0   # radyan, aşağı bakış açısı
const MIN_DIST := 22.0
const MAX_DIST := 210.0

var camera: Camera3D
var focus := Vector3.ZERO
var dist := 60.0


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 40.0
	camera.far = 900.0
	add_child(camera)
	camera.current = true
	apply()


func _process(_dt: float) -> void:
	apply()


func apply() -> void:
	focus.x = clampf(focus.x, -Defs.MAP_W * 0.5, Defs.MAP_W * 0.5)
	focus.z = clampf(focus.z, -Defs.MAP_H * 0.5, Defs.MAP_H * 0.5)
	focus.y = 0.0
	dist = clampf(dist, MIN_DIST, MAX_DIST)
	camera.position = focus + Vector3(0, sin(PITCH), cos(PITCH)) * dist
	camera.rotation = Vector3(-PITCH, 0, 0)


func ground_at(sp: Vector2) -> Vector3:
	var o := camera.project_ray_origin(sp)
	var n := camera.project_ray_normal(sp)
	if absf(n.y) < 0.001:
		return focus
	return o + n * (-o.y / n.y)


func pan_screen(from: Vector2, to: Vector2) -> void:
	focus += ground_at(from) - ground_at(to)
	apply()


func zoom(factor: float) -> void:
	dist *= factor
	apply()
