# ============================================================
#  chillon3d_sprites.gd  (class_name Chillon3DSprites)
#  EL CHILLON EN 3D (05/10/2026). Se modela en tools/sprites_sdf/chillon_sdf.py.
#  Aqui solo se cargan sus hojas (Sprites3D, con el tinte de cada piso). Los tiempos de cada gesto son los
#  del viejo, asi que sus efectos caen igual. El viejo (ChillonSprites, por codigo) queda de referencia y le presta
#  la caja y los pasos de color.
# ============================================================

extends RefCounted
class_name Chillon3DSprites

const CARPETA := "res://assets/sprites/enemigos/chillon_sdf/"
# El lienzo del generador viejo (y el del script de python): el juego lo coloca igual.
const LIENZO := Vector2i(80, 80)
# El color de la variante en que estan pintadas las hojas (la del horneado con el que se comparo).
const BASE := Color("6a7480")

const ANIMS := {
	"idle": {"hoja": "idle", "dirs": 8, "marcos": 8, "fps": 9.0, "loop": true},
	"walk": {"hoja": "walk", "dirs": 8, "marcos": 8, "fps": 14.0, "loop": true},
	"chillido": {"hoja": "chillido", "dirs": 8, "marcos": 8, "fps": 8.0, "loop": false},
	"embestida": {"hoja": "embestida", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": false},
	"encaje": {"hoja": "encaje", "dirs": 8, "marcos": 4, "fps": 18.0, "loop": false},
	"muerte": {"hoja": "muerte", "dirs": 8, "marcos": 8, "fps": 11.0, "loop": false},
	"cadaver": {"hoja": "muerte", "dirs": 8, "marcos": 1, "desde": 7, "fps": 1.0, "loop": false},
}


# --- Contrato de SpritesEnemigo ---
static func generar_de(ed: EnemyData, t: float) -> SpriteFrames:
	if _es_cria(ed):
		return _montar(CRIA)
	return generar(ed.color_visual(t))


# 'chillon3d_' y no 'chillon_': con la clave vieja, SpritesEnemigo cargaria el horneado VIEJO de disco. La cria (18/11) sin
# tinte: es siempre la misma.
static func clave_de(ed: EnemyData, t: float) -> String:
	if _es_cria(ed):
		return "chillon3d_%s" % String(CRIA[0])
	return "chillon3d_%s" % SpriteLienzo.cuantizar_hsv(ed.color_visual(t), ChillonSprites.COLOR_PASOS).to_html(false)


static func _es_cria(ed: EnemyData) -> bool:
	return ed != null and ed.sprite_variante == &"cria"


static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(_escala: float = 1.0) -> int:
	return LIENZO.x


static func dimensiona_por_escala() -> bool:
	return true


static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	return ChillonSprites.tam_cuerpo(escala)


static func generar(color: Color = BASE) -> SpriteFrames:
	return Sprites3D.montar(CARPETA, ANIMS, LIENZO, BASE, SpriteLienzo.cuantizar_hsv(color, ChillonSprites.COLOR_PASOS))


# ------------------------------------------------------------
#  LOS MUTANTES (18/11, chillon-mutante), de tools/sprites_sdf/chillon_mut_sdf.py: [carpeta, lienzo, sus animaciones].
#  Ya vienen a su tamaño y con SU color (sin el tinte del piso).
#    APAGALUCES  el mismo murcielago, negro mate, con los ojos ciegos; CHILLIDO DE OSCURIDAD (en circulo: las orejas se
#                abren a los lados), comer y la evolucion desde el normal
#    PIÑA        el racimo: unos 25 colgando y seis batiendo a destiempo; SOLTAR (el de abajo cae y es la cria) y la
#                evolucion (le llegan volando desde fuera); sin Picado
#  LA CRIA no es un mutante: es su propia ficha (resources/enemigos_invocados), con sprite_variante 'cria'.
# ------------------------------------------------------------
const _MUT_ANIMS := {
	"idle": {"hoja": "idle", "dirs": 8, "marcos": 8, "fps": 9.0, "loop": true},
	"walk": {"hoja": "walk", "dirs": 8, "marcos": 8, "fps": 14.0, "loop": true},
	"embestida": {"hoja": "embestida", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": false},
	"chillido_oscuro": {"hoja": "chillido_oscuro", "dirs": 8, "marcos": 8, "fps": 8.0, "loop": false},
	"encaje": {"hoja": "encaje", "dirs": 8, "marcos": 4, "fps": 18.0, "loop": false},
	"muerte": {"hoja": "muerte", "dirs": 8, "marcos": 8, "fps": 11.0, "loop": false},
	"cadaver": {"hoja": "muerte", "dirs": 8, "marcos": 1, "desde": 7, "fps": 1.0, "loop": false},
	"comer": {"hoja": "comer", "dirs": 8, "marcos": 10, "fps": 10.0, "loop": false},
	"evolucion": {"hoja": "evolucion", "dirs": 8, "marcos": 18, "fps": 10.0, "loop": false},
}
# La Piña: sus propios tiempos (es pesada) y sus gestos.
const _PINA_ANIMS := {
	"idle": {"hoja": "idle", "dirs": 8, "marcos": 8, "fps": 8.0, "loop": true},
	"walk": {"hoja": "walk", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": true},
	"chillido_oscuro": {"hoja": "chillido_oscuro", "dirs": 8, "marcos": 8, "fps": 8.0, "loop": false},
	"soltar": {"hoja": "soltar", "dirs": 8, "marcos": 10, "fps": 10.0, "loop": false},
	"encaje": {"hoja": "encaje", "dirs": 8, "marcos": 4, "fps": 14.0, "loop": false},
	"muerte": {"hoja": "muerte", "dirs": 8, "marcos": 10, "fps": 10.0, "loop": false},
	"cadaver": {"hoja": "muerte", "dirs": 8, "marcos": 1, "desde": 9, "fps": 1.0, "loop": false},
	"evolucion": {"hoja": "evolucion", "dirs": 8, "marcos": 24, "fps": 10.0, "loop": false},
}
const _APAGALUCES := ["idle", "walk", "embestida", "chillido_oscuro", "encaje", "muerte", "cadaver"]
const MUTANTES := {
	&"apagaluces": ["chillon_sdf_apagaluces", Vector2i(100, 100), _MUT_ANIMS, _APAGALUCES + ["comer", "evolucion"]],
	&"pina": ["chillon_sdf_pina", Vector2i(136, 136), _PINA_ANIMS, ["idle", "walk", "chillido_oscuro", "soltar", "encaje", "muerte",
		"cadaver", "evolucion"]],
}
# La cria (sprite_variante 'cria' de su ficha): el apagaluces en pequeño, con su mismo juego.
const CRIA := ["chillon_sdf_cria", Vector2i(60, 60), _MUT_ANIMS, _APAGALUCES]


static func _anims_de(tabla: Dictionary, lista: Array) -> Dictionary:
	var anims := {}
	for k in lista:
		anims[k] = (tabla[k] as Dictionary).duplicate()
	return anims


static func _montar(v: Array) -> SpriteFrames:
	return Sprites3D.montar("res://assets/sprites/enemigos/%s/" % String(v[0]), _anims_de(v[2], v[3]), v[1], BASE, BASE)


# --- EL SPRITE DE MUTANTE (contrato de SpritesEnemigo, como Chupasimas3DSprites) ---
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
	return "" if v.is_empty() else "chillon3d_%s" % String(v[0])


static func generar_mutante_de(ed: EnemyData, _t: float, mutacion: StringName = &"") -> SpriteFrames:
	var v: Array = _variante_mutante(ed, mutacion)
	return null if v.is_empty() else _montar(v)
