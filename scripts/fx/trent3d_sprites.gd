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
