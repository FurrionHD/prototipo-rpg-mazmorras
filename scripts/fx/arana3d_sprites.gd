# ============================================================
#  arana3d_sprites.gd  (class_name Arana3DSprites)
#  LA ARAÑA DE LAS SIMAS EN 3D (05/10/2026): ocho patas en el mundo (anda a tetrapodo, se alza, se enrosca al morir).
#  Se modela en tools/sprites_sdf/arana_sdf.py y aqui solo se cargan sus hojas (Sprites3D, con el tinte de cada piso).
#  Los tiempos de cada gesto son los del viejo, asi que sus efectos caen igual. El viejo (AranaSprites, por codigo) queda
#  de referencia.
# ============================================================

extends RefCounted
class_name Arana3DSprites

const CARPETA := "res://assets/sprites/enemigos/arana_sdf/"
# El lienzo del generador viejo a su escala (y el del script de python): el juego lo coloca igual.
const LIENZO := Vector2i(90, 90)
# El color en que estan pintadas las hojas (el de su ficha).
const BASE := Color("635580")

const ANIMS := {
	"idle": {"hoja": "idle", "dirs": 8, "marcos": 8, "fps": 3.0, "loop": true},
	"walk": {"hoja": "walk", "dirs": 8, "marcos": 8, "fps": 11.0, "loop": true},
	# SE ALZA y se deja caer encima: el avance llega en el 0,72.
	"embestida": {"hoja": "embestida", "dirs": 8, "marcos": 8, "fps": 11.0, "loop": false},
	"muerte": {"hoja": "muerte", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	# LA TELARAÑA: baja la cabeza, sube el abdomen y dispara en el 0,45.
	"telarana": {"hoja": "telarana", "dirs": 8, "marcos": 10, "fps": 12.0, "loop": false},
	# EL PONZOÑOSO: clava en el 0,44 y se queda apretando.
	"mordisco": {"hoja": "mordisco", "dirs": 8, "marcos": 10, "fps": 14.0, "loop": false},
	# PICA (cierra los queliceros) en el 0,45.
	"basico": {"hoja": "basico", "dirs": 8, "marcos": 8, "fps": 16.0, "loop": false},
	"encaje": {"hoja": "encaje", "dirs": 8, "marcos": 4, "fps": 18.0, "loop": false},
	"cadaver": {"hoja": "muerte", "dirs": 8, "marcos": 1, "desde": 7, "fps": 1.0, "loop": false},
}


# --- Contrato de SpritesEnemigo ---
static func generar_de(ed: EnemyData, t: float) -> SpriteFrames:
	return generar(ed.color_visual(t))


# 'arana3d_' y no 'arana_': con la clave vieja, SpritesEnemigo cargaria el horneado VIEJO de disco.
static func clave_de(ed: EnemyData, t: float) -> String:
	return "arana3d_%s" % SpriteLienzo.cuantizar_hsv(ed.color_visual(t), AranaSprites.COLOR_PASOS).to_html(false)


static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(_escala: float = 1.0) -> int:
	return LIENZO.x


static func dimensiona_por_escala() -> bool:
	return true


static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	return AranaSprites.tam_cuerpo(escala)


static func generar(color: Color = BASE) -> SpriteFrames:
	return Sprites3D.montar(CARPETA, ANIMS, LIENZO, BASE, SpriteLienzo.cuantizar_hsv(color, AranaSprites.COLOR_PASOS))
