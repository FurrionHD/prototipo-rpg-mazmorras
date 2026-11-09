# ============================================================
#  miconido3d_sprites.gd  (class_name Miconido3DSprites)
#  EL MICONIDO EN 3D (05/10/2026): la seta con cuerpo; porrazo de sombrero, bocanada de esporas, latigo con el brazo de camara.
#  Se modela en tools/sprites_sdf/miconido_sdf.py y aqui solo se cargan sus hojas (Sprites3D, con el tinte de cada piso).
#  Los tiempos de cada gesto son los del viejo, asi que sus efectos caen igual. El viejo (MiconidoSprites, por codigo) queda
#  de referencia.
# ============================================================

extends RefCounted
class_name Miconido3DSprites

const CARPETA := "res://assets/sprites/enemigos/miconido_sdf/"
# El lienzo del generador viejo a su escala (y el del script de python): el juego lo coloca igual.
# x2,1 (09/10, el jefe: "el miconido tiene que ser mas grande"): renderizado a ese tamaño en miconido_sdf.py (GRANDE).
const LIENZO := Vector2i(189, 223)
# El color en que estan pintadas las hojas (el de su ficha).
const BASE := Color("806e40")

const ANIMS := {
	"idle": {"hoja": "idle", "dirs": 8, "marcos": 8, "fps": 3.0, "loop": true},
	"walk": {"hoja": "walk", "dirs": 8, "marcos": 8, "fps": 5.0, "loop": true},
	"embestida": {"hoja": "embestida", "dirs": 8, "marcos": 8, "fps": 8.0, "loop": false},
	# Revienta en el 0,571 (sale la nube).
	"esporas": {"hoja": "esporas", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": false},
	# LANZA el brazo de camara en el 0,286 (de su mano sale el latigo de SimaAire).
	"micelio": {"hoja": "micelio", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": false},
	"encaje": {"hoja": "encaje", "dirs": 8, "marcos": 4, "fps": 18.0, "loop": false},
	"muerte": {"hoja": "muerte", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	"cadaver": {"hoja": "muerte", "dirs": 8, "marcos": 1, "desde": 7, "fps": 1.0, "loop": false},
	# COMER UN CRISTAL (09/11, sus mutantes).
	"comer": {"hoja": "comer", "dirs": 8, "marcos": 10, "fps": 10.0, "loop": false, "opcional": true},
}

# LOS MUTANTES DEL MICONIDO (09/11, miconido-mutante): su carpeta y sus animaciones (tools/sprites_sdf/miconido_mut_sdf.py).
# Ya vienen a su tamaño y con SU color (sin el tinte del piso). Su 'embestida' es su basico (el latigazo de filamentos de la
# Campana palida, el tajo oxidado del Aventurero florecido).
const LIENZOS_MUT := {&"campana": Vector2i(280, 340), &"florecido": Vector2i(280, 340)}
const _MUT_COMUN := {
	"idle": {"hoja": "idle", "dirs": 8, "marcos": 8, "fps": 3.0, "loop": true},
	"walk": {"hoja": "walk", "dirs": 8, "marcos": 8, "fps": 5.0, "loop": true},
	"embestida": {"hoja": "embestida", "dirs": 8, "marcos": 8, "fps": 8.0, "loop": false},
	# Revienta en el 0,571 (sale la nube), como el normal.
	"esporas": {"hoja": "esporas", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": false},
	"micelio": {"hoja": "micelio", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": false},
	"destello_carga": {"hoja": "destello_carga", "dirs": 8, "marcos": 8, "fps": 8.0, "loop": true},
	# La campana se abre de golpe en el 0,4.
	"destello": {"hoja": "destello", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": false},
	"encaje": {"hoja": "encaje", "dirs": 8, "marcos": 4, "fps": 18.0, "loop": false},
	"muerte": {"hoja": "muerte", "dirs": 8, "marcos": 10, "fps": 10.0, "loop": false},
	"cadaver": {"hoja": "muerte", "dirs": 8, "marcos": 1, "desde": 9, "fps": 1.0, "loop": false},
	"comer": {"hoja": "comer", "dirs": 8, "marcos": 10, "fps": 10.0, "loop": false},
	"evolucion": {"hoja": "evolucion", "dirs": 8, "marcos": 20, "fps": 10.0, "loop": false},
}
# El florecido: la Estocada del muerto (se lanza en el 0,5).
const _MUT_FLORECIDO := {
	"estocada": {"hoja": "estocada", "dirs": 8, "marcos": 8, "fps": 13.0, "loop": false},
}


static func _anims_mutante(sprite: StringName) -> Dictionary:
	var a: Dictionary = _MUT_COMUN.duplicate()
	if sprite == &"florecido":
		a.merge(_MUT_FLORECIDO)
	return a


static func _sprite_mutante(ed: EnemyData, mutacion: StringName) -> StringName:
	var m: MutacionData = ed.mutacion_de(mutacion) if ed != null else null
	return m.sprite if m != null and LIENZOS_MUT.has(m.sprite) else &""


# --- EL SPRITE DE MUTANTE (contrato de SpritesEnemigo, como Ciempies3DSprites) ---
static func tiene_mutante(ed: EnemyData, mutacion: StringName = &"") -> bool:
	return _sprite_mutante(ed, mutacion) != &""


static func clave_mutante_de(ed: EnemyData, _t: float, mutacion: StringName = &"") -> String:
	var s: StringName = _sprite_mutante(ed, mutacion)
	return "" if s == &"" else "miconido3d_miconido_sdf_%s" % String(s)


static func generar_mutante_de(ed: EnemyData, _t: float, mutacion: StringName = &"") -> SpriteFrames:
	var s: StringName = _sprite_mutante(ed, mutacion)
	if s == &"":
		return null
	return Sprites3D.montar("res://assets/sprites/enemigos/miconido_sdf_%s/" % String(s), _anims_mutante(s), LIENZOS_MUT[s], BASE, BASE)


# --- Contrato de SpritesEnemigo ---
static func generar_de(ed: EnemyData, t: float) -> SpriteFrames:
	return generar(ed.color_visual(t))


# 'miconido3d_' y no 'miconido_': con la clave vieja, SpritesEnemigo cargaria el horneado VIEJO de disco.
static func clave_de(ed: EnemyData, t: float) -> String:
	return "miconido3d_%s" % SpriteLienzo.cuantizar_hsv(ed.color_visual(t), MiconidoSprites.COLOR_PASOS).to_html(false)


static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(_escala: float = 1.0) -> int:
	return LIENZO.x


static func dimensiona_por_escala() -> bool:
	return true


static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	return MiconidoSprites.tam_cuerpo(escala)


static func generar(color: Color = BASE) -> SpriteFrames:
	return Sprites3D.montar(CARPETA, ANIMS, LIENZO, BASE, SpriteLienzo.cuantizar_hsv(color, MiconidoSprites.COLOR_PASOS))
