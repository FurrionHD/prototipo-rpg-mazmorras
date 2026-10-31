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
	# COMER UN CRISTAL y LA EVOLUCION (31/10, los mutantes del jabali): la del jabali normal y la de sus mutantes.
	"comer": {"hoja": "comer", "dirs": 8, "marcos": 10, "fps": 10.0, "loop": false, "opcional": true},
	"evolucion": {"hoja": "evolucion", "dirs": 8, "marcos": 18, "fps": 10.0, "loop": false, "opcional": true},
}

# LOS MUTANTES DEL JABALI (31/10, jabali-mutante): la variante que dice su MutacionData.sprite -> [carpeta, lienzo, sus
# animaciones, sus VARIANTES de la pelea]. Ya vienen dibujados a su tamaño y con SU color (sin el tinte del piso). Las
# variantes (cada una su carpeta 'jabali_sdf_<mutante>_<variante>', sin comer ni evolucion): los colmillos ROTOS tras la
# Cornada de cristal y, el ancestral, PELADO cuando le queman el musgo (y pelado con los colmillos rotos).
const _COMUNES_MUT := ["idle", "walk", "embestida", "cornada", "pisoton", "basico", "arrollar", "encaje", "muerte",
	"cadaver"]
const MUTANTES := {
	&"colmillo": ["jabali_sdf_colmillo", Vector2i(122, 122), _COMUNES_MUT + ["comer", "evolucion"], [&"rotos"]],
	&"ancestral": ["jabali_sdf_ancestral", Vector2i(132, 132), _COMUNES_MUT + ["comer", "evolucion"],
		[&"rotos", &"pelado", &"pelado_rotos"]],
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


static func _anims_de(lista: Array) -> Dictionary:
	var anims := {}
	for k in lista:
		anims[k] = ANIMS[k]
	return anims


# --- EL SPRITE DE MUTANTE (contrato de SpritesEnemigo, como Rata3DSprites) ---
static func _variante_mutante(ed: EnemyData, mutacion: StringName) -> Array:
	var m: MutacionData = ed.mutacion_de(mutacion) if ed != null else null
	if m == null or not MUTANTES.has(m.sprite):
		return []
	return MUTANTES[m.sprite]


static func tiene_mutante(ed: EnemyData, mutacion: StringName = &"") -> bool:
	return not _variante_mutante(ed, mutacion).is_empty()


# Sin tinte: la clave no lleva color (es siempre el mismo).
static func clave_mutante_de(ed: EnemyData, _t: float, mutacion: StringName = &"") -> String:
	var v: Array = _variante_mutante(ed, mutacion)
	return "" if v.is_empty() else "jabali3d_%s" % String(v[0])


static func generar_mutante_de(ed: EnemyData, _t: float, mutacion: StringName = &"") -> SpriteFrames:
	var v: Array = _variante_mutante(ed, mutacion)
	if v.is_empty():
		return null
	return Sprites3D.montar("res://assets/sprites/enemigos/%s/" % String(v[0]), _anims_de(v[2]), v[1], BASE, BASE)


# --- SUS VARIANTES DE LA PELEA (contrato de SpritesEnemigo.frames_variante y del horno) ---
static func variantes_de_mutante(ed: EnemyData, mutacion: StringName) -> Array:
	var v: Array = _variante_mutante(ed, mutacion)
	return [] if v.is_empty() else v[3]


static func clave_variante_de(ed: EnemyData, mutacion: StringName, variante: StringName) -> String:
	var v: Array = _variante_mutante(ed, mutacion)
	return "" if v.is_empty() else "jabali3d_%s_%s" % [String(v[0]), String(variante)]


static func generar_variante_de(ed: EnemyData, mutacion: StringName, variante: StringName) -> SpriteFrames:
	var v: Array = _variante_mutante(ed, mutacion)
	if v.is_empty() or not (v[3] as Array).has(variante):
		return null
	return Sprites3D.montar("res://assets/sprites/enemigos/%s_%s/" % [String(v[0]), String(variante)],
		_anims_de(_COMUNES_MUT), v[1], BASE, BASE)
