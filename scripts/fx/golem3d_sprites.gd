# ============================================================
#  golem3d_sprites.gd  (class_name Golem3DSprites)
#  EL GOLEM DE ARCILLA EN 3D (03/10/2026; "nivel dios"). Se modela en tools/sprites_sdf/golem_sdf.py y aqui solo se
#  cargan sus hojas (Sprites3D, con el tinte de cada piso). El viejo (GolemSprites, por codigo) queda de referencia.
# ============================================================

extends RefCounted
class_name Golem3DSprites

const CARPETA := "res://assets/sprites/enemigos/golem_sdf/"
# El lienzo del generador viejo a escala 2,8 (y el del script de python): el juego lo coloca igual.
const LIENZO := Vector2i(162, 176)
# El barro en que estan pintadas las hojas (el color de golem_arcilla.tres).
const BASE := Color(0.6, 0.45, 0.3)

# Las animaciones que pide el juego -> la hoja de donde salen. 8 direcciones todas (en el tactico se ven todas).
const ANIMS := {
	"idle": {"hoja": "idle", "dirs": 8, "marcos": 8, "fps": 3.0, "loop": true},
	"walk": {"hoja": "walk", "dirs": 8, "marcos": 8, "fps": 5.0, "loop": true},
	# EL PUÑETAZO (su basico, anim_basico 'golem_golpe'): un puño arriba y cae; toca en el 6o de 8 a 10 fps.
	"basico": {"hoja": "basico", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	# LA MACHACA (fx_anim 'golem_machaca'): los dos puños arriba y caen como un yunque; tambien toca en el 6o.
	"golem_machaca": {"hoja": "golem_machaca", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	# Y como 'embestida', por si algo la pide por el nombre de siempre.
	"embestida": {"hoja": "golem_machaca", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	"endurecerse": {"hoja": "endurecerse", "dirs": 8, "marcos": 8, "fps": 9.0, "loop": false},
	"encaje": {"hoja": "encaje", "dirs": 8, "marcos": 4, "fps": 18.0, "loop": false},
	# MORIR: cae de rodillas y se desmorona en trozos de arcilla. El CADAVER es el monton (su ultimo fotograma).
	"muerte": {"hoja": "muerte", "dirs": 8, "marcos": 8, "fps": 9.0, "loop": false},
	"cadaver": {"hoja": "muerte", "dirs": 8, "marcos": 1, "desde": 7, "fps": 1.0, "loop": false},
}


# --- Contrato de SpritesEnemigo ---
static func generar_de(ed: EnemyData, t: float) -> SpriteFrames:
	return generar(ed.color_visual(t))


# 'golem3d_' y no 'golem_': con la clave vieja, SpritesEnemigo cargaria el horneado VIEJO de disco.
static func clave_de(ed: EnemyData, t: float) -> String:
	return "golem3d_%s" % SpriteLienzo.cuantizar_hsv(ed.color_visual(t), GolemSprites.COLOR_PASOS).to_html(false)


static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(_escala: float = 1.0) -> int:
	return LIENZO.x


static func dimensiona_por_escala() -> bool:
	return true


# La colision, la del viejo: el bulto es el mismo.
static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	return GolemSprites.tam_cuerpo(escala)


static func generar(color: Color = BASE) -> SpriteFrames:
	return Sprites3D.montar(CARPETA, ANIMS, LIENZO, BASE, SpriteLienzo.cuantizar_hsv(color, GolemSprites.COLOR_PASOS))
