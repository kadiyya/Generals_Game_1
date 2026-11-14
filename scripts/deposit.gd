class_name Deposit
extends Node3D
## Kaynak yatağı: maç boyunca haritanın rastgele yerlerinde belirir ve herkese duyurulur.
## Üstüne Maden Ocağı kuran takımın olur (kurulum pahalıdır, yanında askerî birlik gerekir).
## Rezervi bitince tükenir. Maden yıkılırsa yatak yeniden boşa çıkar.

const SNAP := 7.0

var rich := 7.0          # maden kurulunca $/sn
var reserve := 6000.0    # kalan $
var start_reserve := 6000.0
var mine = null          # üstündeki Maden Ocağı (Building)
var model: Node3D
var marker: MeshInstance3D
var born := 0.0
var ruined_until := -1.0   # üstündeki maden yıkılınca yatak bir süre kullanılamaz


func setup(p: Vector3, r: float, res: float) -> void:
	position = p
	rich = r
	reserve = res
	start_reserve = res
	model = Models.build({"model": "deposit"}, Defs.PLAYER)
	add_child(model)
	marker = Models.ring(SNAP, Color(1.0, 0.8, 0.25))
	marker.position.y = 0.15
	add_child(marker)
	born = Game.I.time


func free_for(_team: int) -> bool:
	return (mine == null or not is_instance_valid(mine) or not mine.alive) and not ruined()


func ruined() -> bool:
	return Game.I.time < ruined_until


func depleted() -> bool:
	return reserve <= 0.0


func _process(_dt: float) -> void:
	if mine != null and (not is_instance_valid(mine) or not mine.alive):
		mine = null
		ruined_until = Game.I.time + Defs.RUIN_TIME
	if ruined() and randf() < 0.05:
		Game.I.fx_puff(global_position + Vector3(randf_range(-2, 2), 1.0, randf_range(-2, 2)), Color(0.12, 0.11, 0.1), 1.8, 2.4, 3.5)
	# Boş yatak, yeni belirdiyse yanıp söner.
	marker.visible = mine == null and not ruined()
	if marker.visible:
		var pulse := 1.0 + 0.06 * sin(Game.I.time * 4.0)
		marker.scale = Vector3(pulse, 0.2, pulse)
