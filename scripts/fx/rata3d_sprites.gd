# ============================================================
#  rata3d_sprites.gd  (class_name Rata3DSprites)
#  LA RATA Y EL REY RATA EN 3D (05/10/2026). Se modelan en tools/sprites_sdf/rata_sdf.py (RATA_VAR=rey para el rey: su
#  cicatriz, la oreja rasgada, la cola anudada y la CORONA DE ORO que pidio el jefe) y aqui solo se cargan sus hojas
#  (Sprites3D, con el tinte de cada piso). Los tiempos de cada gesto son los del viejo, asi que sus efectos caen igual.
#  El viejo (RataSprites, por codigo) queda de referencia.
# ============================================================

extends RefCounted
class_name Rata3DSprites

const CARPETA := "res://assets/sprites/enemigos/rata_sdf/"
const CARPETA_REY := "res://assets/sprites/enemigos/rata_rey_sdf/"
# Los lienzos del generador viejo a su escala (rata 1,20; rey 1,70): el juego los coloca igual.
const LIENZO := Vector2i(48, 48)
const LIENZO_REY := Vector2i(66, 66)
# El color en que estan pintadas las hojas (el de la prueba de cada una).
const BASE := Color("806a55")
const BASE_REY := Color("aa8a55")

const ANIMS := {
	"idle": {"hoja": "idle", "dirs": 8, "marcos": 8, "fps": 5.0, "loop": true},
	"walk": {"hoja": "walk", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": true},
	"embestida": {"hoja": "embestida", "dirs": 8, "marcos": 8, "fps": 11.0, "loop": false},
	"chillido": {"hoja": "chillido", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	"basico": {"hoja": "basico", "dirs": 8, "marcos": 8, "fps": 16.0, "loop": false},
	"desgarro": {"hoja": "desgarro", "dirs": 8, "marcos": 11, "fps": 16.0, "loop": false},
	"agazapado": {"hoja": "agazapado", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": true},
	"salto_rata": {"hoja": "salto_rata", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": false},
	"frenesi": {"hoja": "frenesi", "dirs": 8, "marcos": 6, "fps": 20.0, "loop": false},
	"dentellada": {"hoja": "dentellada", "dirs": 8, "marcos": 8, "fps": 13.0, "loop": false},
	"yugular": {"hoja": "yugular", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": false},
	"zarandeo": {"hoja": "zarandeo", "dirs": 8, "marcos": 12, "fps": 16.0, "loop": false},
	"encaje": {"hoja": "encaje", "dirs": 8, "marcos": 4, "fps": 18.0, "loop": false},
	"muerte": {"hoja": "muerte", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	"cadaver": {"hoja": "muerte", "dirs": 8, "marcos": 1, "desde": 7, "fps": 1.0, "loop": false},
}


# --- Contrato de SpritesEnemigo ---
static func generar_de(ed: EnemyData, t: float) -> SpriteFrames:
	return generar(ed.color_visual(t), ed.sprite_variante == &"rey")


# 'rata3d_' y no 'rata_': con la clave vieja, SpritesEnemigo cargaria el horneado VIEJO de disco.
static func clave_de(ed: EnemyData, t: float) -> String:
	return "rata3d_%s%s" % [SpriteLienzo.cuantizar_hsv(ed.color_visual(t), RataSprites.COLOR_PASOS).to_html(false),
		"_rey" if ed.sprite_variante == &"rey" else ""]


static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


# El lienzo de la que toque: el rey (1,7) es el grande.
static func ancho_px(escala: float = 1.0) -> int:
	return LIENZO_REY.x if escala > 1.45 else LIENZO.x


static func dimensiona_por_escala() -> bool:
	return true


static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	return RataSprites.tam_cuerpo(escala)


static func generar(color: Color = BASE, rey: bool = false) -> SpriteFrames:
	var col: Color = SpriteLienzo.cuantizar_hsv(color, RataSprites.COLOR_PASOS)
	if rey:
		return Sprites3D.montar(CARPETA_REY, ANIMS, LIENZO_REY, BASE_REY, col)
	return Sprites3D.montar(CARPETA, ANIMS, LIENZO, BASE, col)
