# ============================================================
#  trent3d_sprites.gd  (class_name Trent3DSprites)
#  EL TRENT EN 3D: el GUARDIAN (05/10/2026). Se modela en tools/sprites_sdf/trent_sdf.py y aqui solo se cargan sus hojas
#  (Sprites3D, con el tinte de cada piso). Los tiempos de cada gesto son los del viejo, asi que sus efectos caen igual.
#  El viejo (TrentSprites, por codigo) queda de referencia.
# ============================================================

extends RefCounted
class_name Trent3DSprites

const CARPETA := "res://assets/sprites/enemigos/trent_sdf/"
# El lienzo del generador viejo a escala 2,5 (y el del script de python): el juego lo coloca igual.
const LIENZO := Vector2i(306, 216)
# El color de la variante en que estan pintadas las hojas (la del piso 4, 598040).
const BASE := Color("598040")

const ANIMS := {
	"idle": {"hoja": "idle", "dirs": 8, "marcos": 8, "fps": 3.0, "loop": true},
	"walk": {"hoja": "walk", "dirs": 8, "marcos": 8, "fps": 5.0, "loop": true},
	# EL RAMAZO: descarga las ramas en el 0,55.
	"embestida": {"hoja": "embestida", "dirs": 8, "marcos": 8, "fps": 8.0, "loop": false},
	# LA SAVIA: se vuelca al soltar en el 3o-4o.
	"escupir": {"hoja": "escupir", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	"basico": {"hoja": "basico", "dirs": 8, "marcos": 8, "fps": 9.0, "loop": false},
	"barrido_raiz": {"hoja": "barrido_raiz", "dirs": 8, "marcos": 6, "fps": 10.0, "loop": false},
	"barrido_vuelta": {"hoja": "barrido_vuelta", "dirs": 8, "marcos": 6, "fps": 10.0, "loop": false},
	# LAS RAICES: clava las manos en el suelo en el 0,52 y se queda agarrado.
	"raices": {"hoja": "raices", "dirs": 8, "marcos": 8, "fps": 7.0, "loop": false},
	"encaje": {"hoja": "encaje", "dirs": 8, "marcos": 4, "fps": 18.0, "loop": false},
	"muerte": {"hoja": "muerte", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	"cadaver": {"hoja": "muerte", "dirs": 8, "marcos": 1, "desde": 7, "fps": 1.0, "loop": false},
	# COMER UN CRISTAL y LA EVOLUCION (02/11, los mutantes del trent): la del trent normal y la de sus mutantes.
	"comer": {"hoja": "comer", "dirs": 8, "marcos": 10, "fps": 10.0, "loop": false, "opcional": true},
	"evolucion": {"hoja": "evolucion", "dirs": 8, "marcos": 18, "fps": 10.0, "loop": false, "opcional": true},
	# EL GEISER del Espantajo: cargando (en bucle, la grieta de la espalda se abre) y soltando (se arquea en el 0,35).
	"geiser_carga": {"hoja": "geiser_carga", "dirs": 8, "marcos": 8, "fps": 8.0, "loop": true, "opcional": true},
	"geiser": {"hoja": "geiser", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false, "opcional": true},
}

# LOS MUTANTES DEL TRENT (02/11, trent-mutante): UNA LINEA unida por la savia. El TOCON AMBARINO (1a: un tocon araña de
# corteza viva rebosando ambar) y el ESPANTAJO (2a: altisimo y flaco, savia negra). Cada uno CON SU CUERPO, de
# tools/sprites_sdf/trent_mutantes_sdf.py: [carpeta, lienzo, sus animaciones, sus VARIANTES de la pelea]. Ya vienen a su
# tamaño y con SU color (sin el tinte del piso). La variante: el Tocon SIN COSTRA (se le rompe el ambar y se le ve el
# domo roto hasta que le vuelve a brotar). La evolucion del Espantajo dura mas (24: se pudre poco a poco).
const _COMUNES_MUT := ["idle", "walk", "embestida", "escupir", "basico", "barrido_raiz", "barrido_vuelta", "raices",
	"encaje", "muerte", "cadaver"]
const MUTANTES := {
	&"ambarino": ["trent_sdf_ambarino", Vector2i(240, 216), _COMUNES_MUT + ["comer", "evolucion"], [&"sin_costra"]],
	&"espantajo": ["trent_sdf_espantajo", Vector2i(340, 400),
		_COMUNES_MUT + ["comer", "evolucion", "geiser_carga", "geiser"], []],
}


# --- Contrato de SpritesEnemigo ---
static func generar_de(ed: EnemyData, t: float) -> SpriteFrames:
	return generar(ed.color_visual(t))


# 'trent3d_' y no 'trent_': con la clave vieja, SpritesEnemigo cargaria el horneado VIEJO de disco.
static func clave_de(ed: EnemyData, t: float) -> String:
	return "trent3d_%s" % SpriteLienzo.cuantizar_hsv(ed.color_visual(t), TrentSprites.COLOR_PASOS).to_html(false)


static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(_escala: float = 1.0) -> int:
	return LIENZO.x


static func dimensiona_por_escala() -> bool:
	return true


static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	return TrentSprites.tam_cuerpo(escala)


static func generar(color: Color = BASE) -> SpriteFrames:
	return Sprites3D.montar(CARPETA, ANIMS, LIENZO, BASE, SpriteLienzo.cuantizar_hsv(color, TrentSprites.COLOR_PASOS))


static func _anims_de(lista: Array, carpeta: String) -> Dictionary:
	var anims := {}
	for k in lista:
		anims[k] = ANIMS[k].duplicate()
	# (los marcos de la evolucion, los de SU hoja: la del Espantajo tiene 24)
	if anims.has("evolucion"):
		var meta = JSON.parse_string(FileAccess.get_file_as_string(carpeta + "hojas.json"))
		if meta is Dictionary and (meta.get("anims", {}) as Dictionary).has("evolucion"):
			anims["evolucion"]["marcos"] = int(meta["anims"]["evolucion"]["fotogramas"])
	return anims


# --- EL SPRITE DE MUTANTE (contrato de SpritesEnemigo, como Jabali3DSprites) ---
static func _variante_mutante(ed: EnemyData, mutacion: StringName) -> Array:
	var m: MutacionData = ed.mutacion_de(mutacion) if ed != null else null
	if m == null or not MUTANTES.has(m.sprite):
		return []
	return MUTANTES[m.sprite]


static func tiene_mutante(ed: EnemyData, mutacion: StringName = &"") -> bool:
	return not _variante_mutante(ed, mutacion).is_empty()


# Sin tinte: la clave no lleva color (es siempre el mismo).
static func clave_mutante_de(ed: EnemyData, _t: float, mutacion: StringName = &"") -> String:
	var v: Array = _variante_mutante(ed, mutacion)
	return "" if v.is_empty() else "trent3d_%s" % String(v[0])


static func generar_mutante_de(ed: EnemyData, _t: float, mutacion: StringName = &"") -> SpriteFrames:
	var v: Array = _variante_mutante(ed, mutacion)
	if v.is_empty():
		return null
	var carpeta: String = "res://assets/sprites/enemigos/%s/" % String(v[0])
	return Sprites3D.montar(carpeta, _anims_de(v[2], carpeta), v[1], BASE, BASE)


# --- SUS VARIANTES DE LA PELEA (contrato de SpritesEnemigo.frames_variante y del horno) ---
static func variantes_de_mutante(ed: EnemyData, mutacion: StringName) -> Array:
	var v: Array = _variante_mutante(ed, mutacion)
	return [] if v.is_empty() else v[3]


static func clave_variante_de(ed: EnemyData, mutacion: StringName, variante: StringName) -> String:
	var v: Array = _variante_mutante(ed, mutacion)
	return "" if v.is_empty() else "trent3d_%s_%s" % [String(v[0]), String(variante)]


static func generar_variante_de(ed: EnemyData, mutacion: StringName, variante: StringName) -> SpriteFrames:
	var v: Array = _variante_mutante(ed, mutacion)
	if v.is_empty() or not (v[3] as Array).has(variante):
		return null
	var carpeta: String = "res://assets/sprites/enemigos/%s_%s/" % [String(v[0]), String(variante)]
	return Sprites3D.montar(carpeta, _anims_de(_COMUNES_MUT, carpeta), v[1], BASE, BASE)
