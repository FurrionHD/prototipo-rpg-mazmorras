# ============================================================
#  bestia_acorazada3d_sprites.gd  (class_name BestiaAcorazada3DSprites)
#  LA BESTIA ACORAZADA EN 3D (05/10/2026): la version E (placas rojas y collares de hierro). Se modela en
#  tools/sprites_sdf/bestia_acorazada_sdf.py.
#  Aqui solo se cargan sus hojas (Sprites3D, con el tinte de cada piso). Los tiempos de cada gesto son los
#  del viejo, asi que sus efectos caen igual. El viejo (BestiaAcorazadaSprites, por codigo) queda de referencia y le presta
#  la caja y los pasos de color.
# ============================================================

extends RefCounted
class_name BestiaAcorazada3DSprites

const CARPETA := "res://assets/sprites/enemigos/bestia_acorazada_sdf/"
# El lienzo del generador viejo (y el del script de python): el juego lo coloca igual.
const LIENZO := Vector2i(130, 130)
# El color de la variante en que estan pintadas las hojas (la del horneado con el que se comparo).
const BASE := Color("804d40")

const ANIMS := {
	"idle": {"hoja": "idle", "dirs": 8, "marcos": 8, "fps": 3.0, "loop": true},
	"walk": {"hoja": "walk", "dirs": 8, "marcos": 8, "fps": 5.0, "loop": true},
	"agazapar": {"hoja": "agazapar", "dirs": 8, "marcos": 5, "fps": 10.0, "loop": false},
	"arremeter": {"hoja": "arremeter", "dirs": 8, "marcos": 10, "fps": 12.0, "loop": false},
	"embestida": {"hoja": "embestida", "dirs": 8, "marcos": 8, "fps": 9.0, "loop": false},
	"enderezarse": {"hoja": "enderezarse", "dirs": 8, "marcos": 6, "fps": 12.0, "loop": false},
	"escarbar": {"hoja": "escarbar", "dirs": 8, "marcos": 8, "fps": 8.0, "loop": true},
	"volcada": {"hoja": "volcada", "dirs": 8, "marcos": 8, "fps": 8.0, "loop": true},
	"volcar": {"hoja": "volcar", "dirs": 8, "marcos": 6, "fps": 12.0, "loop": false},
	"zarpazo": {"hoja": "zarpazo", "dirs": 8, "marcos": 12, "fps": 20.0, "loop": false},
	"encaje": {"hoja": "encaje", "dirs": 8, "marcos": 4, "fps": 18.0, "loop": false},
	"muerte": {"hoja": "muerte", "dirs": 8, "marcos": 8, "fps": 9.0, "loop": false},
	"cadaver": {"hoja": "muerte", "dirs": 8, "marcos": 1, "desde": 7, "fps": 1.0, "loop": false},
}


# --- Contrato de SpritesEnemigo ---
static func generar_de(ed: EnemyData, t: float) -> SpriteFrames:
	return generar(ed.color_visual(t))


# 'bestia_acorazada3d_' y no 'bestia_acorazada_': con la clave vieja, SpritesEnemigo cargaria el horneado VIEJO de disco.
static func clave_de(ed: EnemyData, t: float) -> String:
	return "bestia_acorazada3d_%s" % SpriteLienzo.cuantizar_hsv(ed.color_visual(t), BestiaAcorazadaSprites.COLOR_PASOS).to_html(false)


static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(_escala: float = 1.0) -> int:
	return LIENZO.x


static func dimensiona_por_escala() -> bool:
	return true


static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	return BestiaAcorazadaSprites.tam_cuerpo(escala)


static func generar(color: Color = BASE) -> SpriteFrames:
	return Sprites3D.montar(CARPETA, ANIMS, LIENZO, BASE, SpriteLienzo.cuantizar_hsv(color, BestiaAcorazadaSprites.COLOR_PASOS))
