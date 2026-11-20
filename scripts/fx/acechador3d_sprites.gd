# ============================================================
#  acechador3d_sprites.gd  (class_name Acechador3DSprites)
#  EL ACECHADOR EN 3D (05/10/2026). Se modela en tools/sprites_sdf/acechador_sdf.py.
#  Aqui solo se cargan sus hojas (Sprites3D, con el tinte de cada piso). Los tiempos de cada gesto son los
#  del viejo, asi que sus efectos caen igual. El viejo (AcechadorSprites, por codigo) queda de referencia y le presta
#  la caja y los pasos de color.
# ============================================================

extends RefCounted
class_name Acechador3DSprites

const CARPETA := "res://assets/sprites/enemigos/acechador_sdf/"
# El lienzo del generador viejo (y el del script de python): el juego lo coloca igual.
const LIENZO := Vector2i(130, 130)
# El color de la variante en que estan pintadas las hojas (la del horneado con el que se comparo).
const BASE := Color("554e47")

const ANIMS := {
	"idle": {"hoja": "idle", "dirs": 8, "marcos": 8, "fps": 6.0, "loop": true},
	"walk": {"hoja": "walk", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": true},
	"basico": {"hoja": "basico", "dirs": 8, "marcos": 8, "fps": 16.0, "loop": false},
	"desgarrar": {"hoja": "desgarrar", "dirs": 8, "marcos": 12, "fps": 18.0, "loop": false},
	"embestida": {"hoja": "embestida", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": false},
	"yugular": {"hoja": "yugular", "dirs": 8, "marcos": 14, "fps": 16.0, "loop": false},
	"zarpazo": {"hoja": "zarpazo", "dirs": 8, "marcos": 12, "fps": 20.0, "loop": false},
	"encaje": {"hoja": "encaje", "dirs": 8, "marcos": 4, "fps": 18.0, "loop": false},
	"muerte": {"hoja": "muerte", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	"cadaver": {"hoja": "muerte", "dirs": 8, "marcos": 1, "desde": 7, "fps": 1.0, "loop": false},
}


# --- Contrato de SpritesEnemigo ---
static func generar_de(ed: EnemyData, t: float) -> SpriteFrames:
	return generar(ed.color_visual(t))


# 'acechador3d_' y no 'acechador_': con la clave vieja, SpritesEnemigo cargaria el horneado VIEJO de disco.
static func clave_de(ed: EnemyData, t: float) -> String:
	return "acechador3d_%s" % SpriteLienzo.cuantizar_hsv(ed.color_visual(t), AcechadorSprites.COLOR_PASOS).to_html(false)


static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(_escala: float = 1.0) -> int:
	return LIENZO.x


static func dimensiona_por_escala() -> bool:
	return true


static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	return AcechadorSprites.tam_cuerpo(escala)


static func generar(color: Color = BASE) -> SpriteFrames:
	return Sprites3D.montar(CARPETA, ANIMS, LIENZO, BASE, SpriteLienzo.cuantizar_hsv(color, AcechadorSprites.COLOR_PASOS))


# ------------------------------------------------------------
#  LOS MUTANTES (20/11, acechador-mutante), de tools/sprites_sdf/acechador_mut_sdf.py: [carpeta, lienzo, sus animaciones].
#  Ya vienen a su tamaño y con SU color (sin el tinte del piso). Los tiempos son los del normal (sus efectos caen igual).
#    SOMBRA SIN ROSTRO  negra y recia, humo en bocanadas; los ojos solo se encienden al atacar. FUNDIRSE (al acabar su
#                       turno se deshace en humo), EMERGER (sale con los ojos encendidos: el golpe desde las sombras),
#                       comer y la evolucion desde el normal
#    CAZADOR LUNAR      el lobo de luna; MEDIA LUNA (zarpazo en arco), AULLIDO (Caida de la luna, carga), MARCA (Marca de
#                       la luna), fundirse/emerger en niebla azul, comer y la evolucion desde la Sombra
# ------------------------------------------------------------
const _MUT_ANIMS := {
	"idle": {"hoja": "idle", "dirs": 8, "marcos": 8, "fps": 6.0, "loop": true},
	"walk": {"hoja": "walk", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": true},
	"basico": {"hoja": "basico", "dirs": 8, "marcos": 8, "fps": 16.0, "loop": false},
	"desgarrar": {"hoja": "desgarrar", "dirs": 8, "marcos": 12, "fps": 18.0, "loop": false},
	"embestida": {"hoja": "embestida", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": false},
	"yugular": {"hoja": "yugular", "dirs": 8, "marcos": 14, "fps": 16.0, "loop": false},
	"zarpazo": {"hoja": "zarpazo", "dirs": 8, "marcos": 12, "fps": 20.0, "loop": false},
	"encaje": {"hoja": "encaje", "dirs": 8, "marcos": 4, "fps": 18.0, "loop": false},
	"muerte": {"hoja": "muerte", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	"cadaver": {"hoja": "muerte", "dirs": 8, "marcos": 1, "desde": 7, "fps": 1.0, "loop": false},
	"media_luna": {"hoja": "media_luna", "dirs": 8, "marcos": 12, "fps": 18.0, "loop": false},
	"aullido": {"hoja": "aullido", "dirs": 8, "marcos": 14, "fps": 10.0, "loop": false},
	"marca": {"hoja": "marca", "dirs": 8, "marcos": 10, "fps": 12.0, "loop": false},
	"fundirse": {"hoja": "fundirse", "dirs": 8, "marcos": 10, "fps": 12.0, "loop": false},
	"emerger": {"hoja": "emerger", "dirs": 8, "marcos": 10, "fps": 14.0, "loop": false},
	"comer": {"hoja": "comer", "dirs": 8, "marcos": 10, "fps": 10.0, "loop": false},
	"evolucion": {"hoja": "evolucion", "dirs": 8, "marcos": 18, "fps": 10.0, "loop": false},
}
const _COMUNES := ["idle", "walk", "embestida", "basico", "yugular", "encaje", "muerte", "cadaver", "fundirse", "emerger",
	"comer", "evolucion"]
const MUTANTES := {
	&"sombra": ["acechador_sdf_sombra", Vector2i(150, 150), _MUT_ANIMS, _COMUNES + ["zarpazo", "desgarrar"]],
	&"cazador": ["acechador_sdf_cazador", Vector2i(180, 180), _MUT_ANIMS, _COMUNES + ["media_luna", "aullido", "marca"]],
}


static func _anims_de(tabla: Dictionary, lista: Array) -> Dictionary:
	var anims := {}
	for k in lista:
		anims[k] = (tabla[k] as Dictionary).duplicate()
	return anims


static func _montar(v: Array) -> SpriteFrames:
	return Sprites3D.montar("res://assets/sprites/enemigos/%s/" % String(v[0]), _anims_de(v[2], v[3]), v[1], BASE, BASE)


# --- EL SPRITE DE MUTANTE (contrato de SpritesEnemigo, como Chillon3DSprites) ---
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
	return "" if v.is_empty() else "acechador3d_%s" % String(v[0])


static func generar_mutante_de(ed: EnemyData, _t: float, mutacion: StringName = &"") -> SpriteFrames:
	var v: Array = _variante_mutante(ed, mutacion)
	return null if v.is_empty() else _montar(v)
