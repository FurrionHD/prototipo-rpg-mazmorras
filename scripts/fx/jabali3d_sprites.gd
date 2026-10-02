# ============================================================
#  jabali3d_sprites.gd  (class_name Jabali3DSprites)
#  EL JABALI EN 3D (03/10/2026). Se modela en tools/sprites_sdf/jabali_sdf.py y aqui solo se cargan sus hojas
#  (Sprites3D, con el tinte de cada piso). Los tiempos de cada gesto son los del viejo, asi que sus efectos caen igual.
#  El viejo (JabaliSprites, por codigo) queda de referencia.
# ============================================================

extends RefCounted
class_name Jabali3DSprites

const CARPETA := "res://assets/sprites/enemigos/jabali_sdf/"
# El lienzo del generador viejo a escala 1,7 (y el del script de python): el juego lo coloca igual.
const LIENZO := Vector2i(88, 88)
# El color de la variante en que estan pintadas las hojas (la de la prueba, 806255).
const BASE := Color("806255")

const ANIMS := {
	"idle": {"hoja": "idle", "dirs": 8, "marcos": 8, "fps": 5.0, "loop": true},
	"walk": {"hoja": "walk", "dirs": 8, "marcos": 8, "fps": 8.0, "loop": true},
	"embestida": {"hoja": "embestida", "dirs": 8, "marcos": 8, "fps": 11.0, "loop": false},
	# LA CORNADA: sube la cabeza de golpe en el 5o (IMPACTO_ANIM_MAPA 'cornada').
	"cornada": {"hoja": "cornada", "dirs": 8, "marcos": 8, "fps": 11.0, "loop": false},
	# EL PISOTON: se empina sobre las traseras y estampa en el 5o (IMPACTO 'pisoton').
	"pisoton": {"hoja": "pisoton", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": false},
	"basico": {"hoja": "basico", "dirs": 8, "marcos": 8, "fps": 14.0, "loop": false},
	# LA EMBESTIDA EN EL MAPA: galope con la testuz baja y el testarazo al llegar.
	"arrollar": {"hoja": "arrollar", "dirs": 8, "marcos": 8, "fps": 14.0, "loop": false},
	"encaje": {"hoja": "encaje", "dirs": 8, "marcos": 4, "fps": 18.0, "loop": false},
	"muerte": {"hoja": "muerte", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	"cadaver": {"hoja": "muerte", "dirs": 8, "marcos": 1, "desde": 7, "fps": 1.0, "loop": false},
}


# --- Contrato de SpritesEnemigo ---
static func generar_de(ed: EnemyData, t: float) -> SpriteFrames:
	return generar(ed.color_visual(t))


# 'jabali3d_' y no 'jabali_': con la clave vieja, SpritesEnemigo cargaria el horneado VIEJO de disco.
static func clave_de(ed: EnemyData, t: float) -> String:
	return "jabali3d_%s" % SpriteLienzo.cuantizar_hsv(ed.color_visual(t), JabaliSprites.COLOR_PASOS).to_html(false)


static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(_escala: float = 1.0) -> int:
	return LIENZO.x


static func dimensiona_por_escala() -> bool:
	return true


static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	return JabaliSprites.tam_cuerpo(escala)


static func generar(color: Color = BASE) -> SpriteFrames:
	return Sprites3D.montar(CARPETA, ANIMS, LIENZO, BASE, SpriteLienzo.cuantizar_hsv(color, JabaliSprites.COLOR_PASOS))
