# ============================================================
#  pelotero3d_sprites.gd  (class_name Pelotero3DSprites)
#  EL PELOTERO DEL AMBAR (02/11/2026, trent-mutante: lo suelta la costra del Tocon ambarino): el escarabajo negro-verdoso con su bola de caca al lado; la
#  patea (hoja 'bola') y le crece otra.
#  Se modela en tools/sprites_sdf/bichos_ambar_sdf.py (BICHO=pelotero) y aqui solo se cargan sus hojas (Sprites3D).
# ============================================================

extends RefCounted
class_name Pelotero3DSprites

const CARPETA := "res://assets/sprites/enemigos/pelotero_sdf/"
const LIENZO := Vector2i(96, 96)
# El color en que estan pintadas las hojas (no se tiñen: es el mismo de salida).
const BASE := Color("283d2e")
# La escala_visual de su ficha (resources/enemigos_invocados/bicho_pelotero.tres) y su cuerpo en planta a esa escala.
const ESCALA := 1.3
const TAM := Vector2(27.6, 34.5)

const ANIMS := {
	"idle": {"hoja": "idle", "dirs": 8, "marcos": 8, "fps": 4.0, "loop": true},
	"walk": {"hoja": "walk", "dirs": 8, "marcos": 8, "fps": 8.0, "loop": true},
	"embestida": {"hoja": "embestida", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	"encaje": {"hoja": "encaje", "dirs": 8, "marcos": 4, "fps": 18.0, "loop": false},
	"muerte": {"hoja": "muerte", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	"bola": {"hoja": "bola", "dirs": 8, "marcos": 12, "fps": 10.0, "loop": false},
	"cadaver": {"hoja": "muerte", "dirs": 8, "marcos": 1, "desde": 7, "fps": 1.0, "loop": false},
}

# --- Contrato de SpritesEnemigo ---
# Sin tinte: salen siempre del color del ambar (los suelta la costra, no los cria el piso).
static func generar_de(_ed: EnemyData, _t: float) -> SpriteFrames:
	return generar()


static func clave_de(_ed: EnemyData, _t: float) -> String:
	return "pelotero3d"


static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(_escala: float = 1.0) -> int:
	return LIENZO.x


static func dimensiona_por_escala() -> bool:
	return true


# El cuerpo en planta (ancho, largo) sin las patas, medido en sus hojas de quieto a la escala de su ficha (ESCALA).
static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	return TAM * escala / ESCALA


static func generar() -> SpriteFrames:
	return Sprites3D.montar(CARPETA, ANIMS, LIENZO, BASE, BASE)
