# ============================================================
#  garrapata3d_sprites.gd  (class_name Garrapata3DSprites)
#  LA GARRAPATA DEL AMBAR (02/11/2026, trent-mutante: la suelta la costra del Tocon ambarino): lenteja ambar oscuro con pinzas y ocho patitas; se engancha,
#  chupa y se va hinchando (tres hojas mas, garrapata_h1..h3_sdf, una por hinchazon: las VARIANTES de la pelea), y muerta
#  hinchada revienta.
#  Se modela en tools/sprites_sdf/bichos_ambar_sdf.py (BICHO=garrapata) y aqui solo se cargan sus hojas (Sprites3D).
# ============================================================

extends RefCounted
class_name Garrapata3DSprites

const CARPETA := "res://assets/sprites/enemigos/garrapata_sdf/"
const LIENZO := Vector2i(96, 96)
# El color en que estan pintadas las hojas (no se tiñen: es el mismo de salida).
const BASE := Color("6b4a2a")
# La escala_visual de su ficha (resources/enemigos_invocados/bicho_garrapata.tres) y su cuerpo en planta a esa escala.
const ESCALA := 1.2
const TAM := Vector2(27.6, 23.0)

const ANIMS := {
	"idle": {"hoja": "idle", "dirs": 8, "marcos": 8, "fps": 4.0, "loop": true},
	"walk": {"hoja": "walk", "dirs": 8, "marcos": 8, "fps": 8.0, "loop": true},
	"embestida": {"hoja": "embestida", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	"encaje": {"hoja": "encaje", "dirs": 8, "marcos": 4, "fps": 18.0, "loop": false},
	"muerte": {"hoja": "muerte", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	"adherirse": {"hoja": "adherirse", "dirs": 8, "marcos": 8, "fps": 11.0, "loop": false},
	"adherido": {"hoja": "adherido", "dirs": 8, "marcos": 6, "fps": 5.0, "loop": true},
	"drenaje": {"hoja": "drenaje", "dirs": 8, "marcos": 8, "fps": 11.0, "loop": false},
	"cadaver": {"hoja": "muerte", "dirs": 8, "marcos": 1, "desde": 7, "fps": 1.0, "loop": false},
}

# --- Contrato de SpritesEnemigo ---
# Sin tinte: salen siempre del color del ambar (los suelta la costra, no los cria el piso).
static func generar_de(_ed: EnemyData, _t: float) -> SpriteFrames:
	return generar()


static func clave_de(_ed: EnemyData, _t: float) -> String:
	return "garrapata3d"


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


# --- LAS HINCHAZONES (contrato de SpritesEnemigo.frames_variante y del horno) ---
# Cuanto ha chupado: h1, h2 y h3 (el tope), cada una su carpeta garrapata_h<n>_sdf con las mismas animaciones. No son de
# un mutante (la garrapata no muta): valen con cualquier 'mutacion', tambien la vacia.
const HINCHAZONES: Array[StringName] = [&"h1", &"h2", &"h3"]


static func variantes_de_mutante(_ed: EnemyData, _mutacion: StringName) -> Array:
	return HINCHAZONES


static func clave_variante_de(_ed: EnemyData, _mutacion: StringName, variante: StringName) -> String:
	return "garrapata3d_%s" % String(variante)


static func generar_variante_de(_ed: EnemyData, _mutacion: StringName, variante: StringName) -> SpriteFrames:
	if not HINCHAZONES.has(variante):
		return null
	return Sprites3D.montar("res://assets/sprites/enemigos/garrapata_%s_sdf/" % String(variante), ANIMS, LIENZO, BASE, BASE)
