# ============================================================
#  ciempies3d_sprites.gd  (class_name Ciempies3DSprites)
#  EL CIEMPIES CARMESI EN 3D (05/10/2026): cada anillo un hueso; espiral al morir y la HELICE del enroscado en dos mitades.
#  Se modela en tools/sprites_sdf/ciempies_sdf.py y aqui solo se cargan sus hojas (Sprites3D, con el tinte de cada piso).
#  Los tiempos de cada gesto son los del viejo, asi que sus efectos caen igual. El viejo (CiempiesSprites, por codigo) queda
#  de referencia.
# ============================================================

extends RefCounted
class_name Ciempies3DSprites

const CARPETA := "res://assets/sprites/enemigos/ciempies_sdf/"
# El lienzo del generador viejo a su escala (y el del script de python): el juego lo coloca igual.
const LIENZO := Vector2i(104, 104)
# El color en que estan pintadas las hojas (el de su ficha).
const BASE := Color("aa251c")

const ANIMS := {
	"idle": {"hoja": "idle", "dirs": 8, "marcos": 8, "fps": 4.0, "loop": true},
	"walk": {"hoja": "walk", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": true},
	"embestida": {"hoja": "embestida", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": false},
	# UNA direccion (combate, de frente).
	"enrosque": {"hoja": "enrosque", "dirs": 1, "marcos": 8, "fps": 11.0, "loop": false},
	# PICA en la mitad.
	"basico": {"hoja": "basico", "dirs": 8, "marcos": 6, "fps": 16.0, "loop": false},
	# Una sacudida por picotazo, en la mitad.
	"oleada": {"hoja": "oleada", "dirs": 8, "marcos": 6, "fps": 18.0, "loop": false},
	"encaje": {"hoja": "encaje", "dirs": 8, "marcos": 4, "fps": 18.0, "loop": false},
	"muerte": {"hoja": "muerte", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	"enroscarse_detras": {"hoja": "enroscarse_detras", "dirs": 1, "marcos": 6, "fps": 12.0, "loop": false},
	"enroscado_detras": {"hoja": "enroscado_detras", "dirs": 1, "marcos": 8, "fps": 8.0, "loop": true},
	"apreton_detras": {"hoja": "apreton_detras", "dirs": 1, "marcos": 5, "fps": 14.0, "loop": false},
	"desenroscarse_detras": {"hoja": "desenroscarse_detras", "dirs": 1, "marcos": 6, "fps": 12.0, "loop": false},
	"enroscarse_delante": {"hoja": "enroscarse_delante", "dirs": 1, "marcos": 6, "fps": 12.0, "loop": false},
	"enroscado_delante": {"hoja": "enroscado_delante", "dirs": 1, "marcos": 8, "fps": 8.0, "loop": true},
	"apreton_delante": {"hoja": "apreton_delante", "dirs": 1, "marcos": 5, "fps": 14.0, "loop": false},
	"desenroscarse_delante": {"hoja": "desenroscarse_delante", "dirs": 1, "marcos": 6, "fps": 12.0, "loop": false},
	"cadaver": {"hoja": "muerte", "dirs": 8, "marcos": 1, "desde": 7, "fps": 1.0, "loop": false},
}


# --- Contrato de SpritesEnemigo ---
static func generar_de(ed: EnemyData, t: float) -> SpriteFrames:
	return generar(ed.color_visual(t))


# 'ciempies3d_' y no 'ciempies_': con la clave vieja, SpritesEnemigo cargaria el horneado VIEJO de disco.
static func clave_de(ed: EnemyData, t: float) -> String:
	return "ciempies3d_%s" % SpriteLienzo.cuantizar_hsv(ed.color_visual(t), CiempiesSprites.COLOR_PASOS).to_html(false)


static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(_escala: float = 1.0) -> int:
	return LIENZO.x


static func dimensiona_por_escala() -> bool:
	return true


static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	return CiempiesSprites.tam_cuerpo(escala)


static func generar(color: Color = BASE) -> SpriteFrames:
	return Sprites3D.montar(CARPETA, ANIMS, LIENZO, BASE, SpriteLienzo.cuantizar_hsv(color, CiempiesSprites.COLOR_PASOS))
