# ============================================================
#  capullo3d_sprites.gd  (class_name Capullo3DSprites)
#  EL CAPULLO DE CENIZA (03/11/2026, arana-mutante: lo teje la Tejedora de brasas alrededor de un personaje): un huso de
#  seda de ceniza con vetas de ascuas. Se modela en tools/sprites_sdf/capullo_sdf.py y aqui solo se cargan sus hojas.
# ============================================================

extends RefCounted
class_name Capullo3DSprites

const CARPETA := "res://assets/sprites/enemigos/capullo_sdf/"
const LIENZO := Vector2i(110, 120)
# El color en que estan pintadas las hojas (no se tiñen).
const BASE := Color("6e6969")
const TAM := Vector2(26.0, 24.0)

const ANIMS := {
	"idle": {"hoja": "idle", "dirs": 8, "marcos": 8, "fps": 5.0, "loop": true},
	"walk": {"hoja": "walk", "dirs": 8, "marcos": 8, "fps": 5.0, "loop": true},
	"embestida": {"hoja": "embestida", "dirs": 8, "marcos": 8, "fps": 8.0, "loop": false},
	"encaje": {"hoja": "encaje", "dirs": 8, "marcos": 4, "fps": 18.0, "loop": false},
	"muerte": {"hoja": "muerte", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": false},
	"cadaver": {"hoja": "muerte", "dirs": 8, "marcos": 1, "desde": 7, "fps": 1.0, "loop": false},
}


# --- Contrato de SpritesEnemigo ---
static func generar_de(_ed: EnemyData, _t: float) -> SpriteFrames:
	return generar()


static func clave_de(_ed: EnemyData, _t: float) -> String:
	return "capullo3d"


static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(_escala: float = 1.0) -> int:
	return LIENZO.x


static func dimensiona_por_escala() -> bool:
	return true


static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	return TAM * escala


static func generar() -> SpriteFrames:
	return Sprites3D.montar(CARPETA, ANIMS, LIENZO, BASE, BASE)
