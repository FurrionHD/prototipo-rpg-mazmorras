# ============================================================
#  segadora3d_sprites.gd  (class_name Segadora3DSprites)
#  LA SEGADORA EN 3D (05/10/2026). Se modela en tools/sprites_sdf/segadora_sdf.py.
#  Aqui solo se cargan sus hojas (Sprites3D, con el tinte de cada piso). Los tiempos de cada gesto son los
#  del viejo, asi que sus efectos caen igual. El viejo (SegadoraSprites, por codigo) queda de referencia y le presta
#  la caja y los pasos de color.
# ============================================================

extends RefCounted
class_name Segadora3DSprites

const CARPETA := "res://assets/sprites/enemigos/segadora_sdf/"
# El lienzo del generador viejo (y el del script de python): el juego lo coloca igual.
const LIENZO := Vector2i(166, 166)
# El color de la variante en que estan pintadas las hojas (la del horneado con el que se comparo).
const BASE := Color("806e40")

const ANIMS := {
	"idle": {"hoja": "idle", "dirs": 8, "marcos": 8, "fps": 3.0, "loop": true},
	"walk": {"hoja": "walk", "dirs": 8, "marcos": 8, "fps": 9.0, "loop": true},
	"acecho": {"hoja": "acecho", "dirs": 8, "marcos": 8, "fps": 5.0, "loop": true},
	"basico": {"hoja": "basico", "dirs": 8, "marcos": 6, "fps": 16.0, "loop": false},
	"basico_der": {"hoja": "basico_der", "dirs": 8, "marcos": 6, "fps": 16.0, "loop": false},
	"embestida": {"hoja": "embestida", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": false},
	"ensarte": {"hoja": "ensarte", "dirs": 8, "marcos": 8, "fps": 13.0, "loop": false},
	"guadanas": {"hoja": "guadanas", "dirs": 8, "marcos": 8, "fps": 13.0, "loop": false},
	"encaje": {"hoja": "encaje", "dirs": 8, "marcos": 4, "fps": 18.0, "loop": false},
	"muerte": {"hoja": "muerte", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	"cadaver": {"hoja": "muerte", "dirs": 8, "marcos": 1, "desde": 7, "fps": 1.0, "loop": false},
}

# LOS MUTANTES DE LA SEGADORA (05/11, segadora-mutante): su carpeta y sus animaciones (tools/sprites_sdf/segadora_mut_sdf.py).
# Ya vienen a su tamaño y con SU color (sin el tinte del piso).
const LIENZO_MUT := Vector2i(220, 220)
const _MUT := {
	"idle": {"hoja": "idle", "dirs": 8, "marcos": 8, "fps": 3.0, "loop": true},
	"walk": {"hoja": "walk", "dirs": 8, "marcos": 8, "fps": 9.0, "loop": true},
	"acecho": {"hoja": "acecho", "dirs": 8, "marcos": 8, "fps": 5.0, "loop": true},
	"basico": {"hoja": "basico", "dirs": 8, "marcos": 6, "fps": 16.0, "loop": false},
	"basico_der": {"hoja": "basico_der", "dirs": 8, "marcos": 6, "fps": 16.0, "loop": false},
	"embestida": {"hoja": "embestida", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": false},
	"ensarte": {"hoja": "ensarte", "dirs": 8, "marcos": 8, "fps": 13.0, "loop": false},
	"guadanas": {"hoja": "guadanas", "dirs": 8, "marcos": 8, "fps": 13.0, "loop": false},
	"siega_carga": {"hoja": "siega_carga", "dirs": 8, "marcos": 8, "fps": 8.0, "loop": true},
	"siega": {"hoja": "siega", "dirs": 8, "marcos": 7, "fps": 13.0, "loop": false},
	"encaje": {"hoja": "encaje", "dirs": 8, "marcos": 4, "fps": 18.0, "loop": false},
	"muerte": {"hoja": "muerte", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	"cadaver": {"hoja": "muerte", "dirs": 8, "marcos": 1, "desde": 7, "fps": 1.0, "loop": false},
	"comer": {"hoja": "comer", "dirs": 8, "marcos": 10, "fps": 10.0, "loop": false},
	"evolucion": {"hoja": "evolucion", "dirs": 8, "marcos": 18, "fps": 10.0, "loop": false},
}
const _MUT_VENDAVAL := {
	"vendaval_carga": {"hoja": "vendaval_carga", "dirs": 8, "marcos": 8, "fps": 8.0, "loop": true},
	"vendaval": {"hoja": "vendaval", "dirs": 8, "marcos": 7, "fps": 13.0, "loop": false},
	"salto_atras": {"hoja": "salto_atras", "dirs": 8, "marcos": 6, "fps": 14.0, "loop": false},
}
const SPRITES_MUT := [&"sierra", &"vendaval"]


static func _sprite_mutante(ed: EnemyData, mutacion: StringName) -> StringName:
	var m: MutacionData = ed.mutacion_de(mutacion) if ed != null else null
	return m.sprite if m != null and SPRITES_MUT.has(m.sprite) else &""


# --- EL SPRITE DE MUTANTE (contrato de SpritesEnemigo, como Ciempies3DSprites) ---
static func tiene_mutante(ed: EnemyData, mutacion: StringName = &"") -> bool:
	return _sprite_mutante(ed, mutacion) != &""


static func clave_mutante_de(ed: EnemyData, _t: float, mutacion: StringName = &"") -> String:
	var s: StringName = _sprite_mutante(ed, mutacion)
	return "" if s == &"" else "segadora3d_segadora_sdf_%s" % String(s)


static func generar_mutante_de(ed: EnemyData, _t: float, mutacion: StringName = &"") -> SpriteFrames:
	var s: StringName = _sprite_mutante(ed, mutacion)
	if s == &"":
		return null
	var a: Dictionary = _MUT.duplicate()
	if s == &"vendaval":
		a.merge(_MUT_VENDAVAL)
	return Sprites3D.montar("res://assets/sprites/enemigos/segadora_sdf_%s/" % String(s), a, LIENZO_MUT, BASE, BASE)


# --- Contrato de SpritesEnemigo ---
static func generar_de(ed: EnemyData, t: float) -> SpriteFrames:
	return generar(ed.color_visual(t))


# 'segadora3d_' y no 'segadora_': con la clave vieja, SpritesEnemigo cargaria el horneado VIEJO de disco.
static func clave_de(ed: EnemyData, t: float) -> String:
	return "segadora3d_%s" % SpriteLienzo.cuantizar_hsv(ed.color_visual(t), SegadoraSprites.COLOR_PASOS).to_html(false)


static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(_escala: float = 1.0) -> int:
	return LIENZO.x


static func dimensiona_por_escala() -> bool:
	return true


static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	return SegadoraSprites.tam_cuerpo(escala)


static func generar(color: Color = BASE) -> SpriteFrames:
	return Sprites3D.montar(CARPETA, ANIMS, LIENZO, BASE, SpriteLienzo.cuantizar_hsv(color, SegadoraSprites.COLOR_PASOS))
