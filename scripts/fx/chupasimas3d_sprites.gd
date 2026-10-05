# ============================================================
#  chupasimas3d_sprites.gd  (class_name Chupasimas3DSprites)
#  LA CHUPASIMAS EN 3D (05/10/2026): la sanguijuela mojada; bucle de oruga, se adhiere y queda pegada, drena a tirones.
#  Se modela en tools/sprites_sdf/chupasimas_sdf.py y aqui solo se cargan sus hojas (Sprites3D, con el tinte de cada piso).
#  Los tiempos de cada gesto son los del viejo, asi que sus efectos caen igual. El viejo (ChupasimasSprites, por codigo) queda
#  de referencia.
# ============================================================

extends RefCounted
class_name Chupasimas3DSprites

const CARPETA := "res://assets/sprites/enemigos/chupasimas_sdf/"
# El lienzo del generador viejo a su escala (y el del script de python): el juego lo coloca igual.
const LIENZO := Vector2i(104, 104)
# El color en que estan pintadas las hojas (el de su ficha).
const BASE := Color("804055")

const ANIMS := {
	"idle": {"hoja": "idle", "dirs": 8, "marcos": 8, "fps": 4.0, "loop": true},
	"walk": {"hoja": "walk", "dirs": 8, "marcos": 8, "fps": 7.0, "loop": true},
	"embestida": {"hoja": "embestida", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	"adherirse": {"hoja": "adherirse", "dirs": 8, "marcos": 8, "fps": 11.0, "loop": false},
	# PEGADA encima de su presa, en bucle.
	"adherido": {"hoja": "adherido", "dirs": 8, "marcos": 6, "fps": 5.0, "loop": true},
	# Se llena A TIRONES (escalones).
	"drenaje": {"hoja": "drenaje", "dirs": 8, "marcos": 8, "fps": 11.0, "loop": false},
	"encaje": {"hoja": "encaje", "dirs": 8, "marcos": 4, "fps": 18.0, "loop": false},
	"muerte": {"hoja": "muerte", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	"cadaver": {"hoja": "muerte", "dirs": 8, "marcos": 1, "desde": 7, "fps": 1.0, "loop": false},
}


# --- Contrato de SpritesEnemigo ---
static func generar_de(ed: EnemyData, t: float) -> SpriteFrames:
	return generar(ed.color_visual(t))


# 'chupasimas3d_' y no 'chupasimas_': con la clave vieja, SpritesEnemigo cargaria el horneado VIEJO de disco.
static func clave_de(ed: EnemyData, t: float) -> String:
	return "chupasimas3d_%s" % SpriteLienzo.cuantizar_hsv(ed.color_visual(t), ChupasimasSprites.COLOR_PASOS).to_html(false)


static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(_escala: float = 1.0) -> int:
	return LIENZO.x


static func dimensiona_por_escala() -> bool:
	return true


static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	return ChupasimasSprites.tam_cuerpo(escala)


static func generar(color: Color = BASE) -> SpriteFrames:
	return Sprites3D.montar(CARPETA, ANIMS, LIENZO, BASE, SpriteLienzo.cuantizar_hsv(color, ChupasimasSprites.COLOR_PASOS))
