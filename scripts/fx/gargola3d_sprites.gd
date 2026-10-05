# ============================================================
#  gargola3d_sprites.gd  (class_name Gargola3DSprites)
#  LA GARGOLA DE BASALTO EN 3D (05/10/2026): agazapada, alas de murcielago plegadas a la espalda. Se modela en
#  tools/sprites_sdf/gargola_sdf.py.
#  Aqui solo se cargan sus hojas (Sprites3D, con el tinte de cada piso). Los tiempos de cada gesto son los
#  del viejo, asi que sus efectos caen igual. El viejo (GargolaSprites, por codigo) queda de referencia y le presta
#  la caja y los pasos de color.
# ============================================================

extends RefCounted
class_name Gargola3DSprites

const CARPETA := "res://assets/sprites/enemigos/gargola_sdf/"
# El lienzo del generador viejo (y el del script de python): el juego lo coloca igual.
const LIENZO := Vector2i(116, 116)
# El color de la variante en que estan pintadas las hojas (la del horneado con el que se comparo).
const BASE := Color("6a7380")

const ANIMS := {
	"idle": {"hoja": "idle", "dirs": 8, "marcos": 8, "fps": 4.0, "loop": true},
	"walk": {"hoja": "walk", "dirs": 8, "marcos": 8, "fps": 8.0, "loop": true},
	"despegar": {"hoja": "despegar", "dirs": 8, "marcos": 6, "fps": 10.0, "loop": false},
	"embestida": {"hoja": "embestida", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": false},
	"mirada": {"hoja": "mirada", "dirs": 8, "marcos": 8, "fps": 8.0, "loop": false},
	"picar": {"hoja": "picar", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": false},
	"vuelo": {"hoja": "vuelo", "dirs": 8, "marcos": 6, "fps": 7.0, "loop": true},
	"encaje": {"hoja": "encaje", "dirs": 8, "marcos": 4, "fps": 18.0, "loop": false},
	"muerte": {"hoja": "muerte", "dirs": 8, "marcos": 8, "fps": 11.0, "loop": false},
	"cadaver": {"hoja": "muerte", "dirs": 8, "marcos": 1, "desde": 7, "fps": 1.0, "loop": false},
}


# --- Contrato de SpritesEnemigo ---
static func generar_de(ed: EnemyData, t: float) -> SpriteFrames:
	return generar(ed.color_visual(t))


# 'gargola3d_' y no 'gargola_': con la clave vieja, SpritesEnemigo cargaria el horneado VIEJO de disco.
static func clave_de(ed: EnemyData, t: float) -> String:
	return "gargola3d_%s" % SpriteLienzo.cuantizar_hsv(ed.color_visual(t), GargolaSprites.COLOR_PASOS).to_html(false)


static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(_escala: float = 1.0) -> int:
	return LIENZO.x


static func dimensiona_por_escala() -> bool:
	return true


static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	return GargolaSprites.tam_cuerpo(escala)


static func generar(color: Color = BASE) -> SpriteFrames:
	return Sprites3D.montar(CARPETA, ANIMS, LIENZO, BASE, SpriteLienzo.cuantizar_hsv(color, GargolaSprites.COLOR_PASOS))
