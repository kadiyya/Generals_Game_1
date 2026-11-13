class_name Settings
extends RefCounted
## Oyuncu ayarları (user://ayarlar.cfg): ses, müzik, gölge, efekt ve texture.
## Eski telefonlarda gölge, efekt ve texture kapatılarak oyun hızlandırılabilir.

const PATH := "user://ayarlar.cfg"
const KEYS := {
	sound = ["Ses efektleri", true],
	music = ["Müzik", true],
	shadows = ["Gölgeler", true],
	effects = ["Duman ve toz efektleri", true],
	textures = ["Texture'lar", true],
}

static var values := {}
static var _loaded := false


static func get_v(key: String) -> bool:
	if not _loaded:
		load_all()
	return bool(values.get(key, KEYS[key][1]))


static func set_v(key: String, v: bool) -> void:
	values[key] = v
	var cf := ConfigFile.new()
	for k in values:
		cf.set_value("ayar", k, values[k])
	cf.save(PATH)


static func load_all() -> void:
	_loaded = true
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		for k in KEYS:
			values[k] = cf.get_value("ayar", k, KEYS[k][1])
