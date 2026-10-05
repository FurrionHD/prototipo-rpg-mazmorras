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
	return generar(ed.color_visual(t))


# 'chillon3d_' y no 'chillon_': con la clave vieja, SpritesEnemigo cargaria el horneado VIEJO de disco.
static func clave_de(ed: EnemyData, t: float) -> String:
	return "chillon3d_%s" % SpriteLienzo.cuantizar_hsv(ed.color_visual(t), ChillonSprites.COLOR_PASOS).to_html(false)


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
