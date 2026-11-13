# ============================================================
#  polilla3d_sprites.gd  (class_name Polilla3DSprites)
#  LA POLILLA EN 3D (05/10/2026): la version A (pavon). La D (calavera) es la POLILLA DE LUTO (12/11), su propia ficha
#  con sprite_variante = &"luto": la misma tabla de animaciones y el mismo tinte, otra carpeta. Se modelan en
#  tools/sprites_sdf/polilla_variante_sdf.py (POLILLA_VAR=a|d); sus mutantes, en polilla_mut_sdf.py.
#  Aqui solo se cargan sus hojas (Sprites3D, con el tinte de cada piso). Los tiempos de cada gesto son los
#  del viejo, asi que sus efectos caen igual. El viejo (PolillaSprites, por codigo) queda de referencia y le presta
#  la caja y los pasos de color.
# ============================================================

extends RefCounted
class_name Polilla3DSprites

const CARPETA := "res://assets/sprites/enemigos/polilla_sdf_a/"
# La Polilla de luto (el dibujo D, la calavera).
const CARPETA_LUTO := "res://assets/sprites/enemigos/polilla_sdf_d/"
# El lienzo del generador viejo (y el del script de python): el juego lo coloca igual.
const LIENZO := Vector2i(90, 90)
# El color de la variante en que estan pintadas las hojas (la del horneado con el que se comparo).
const BASE := Color("a48eaa")

const ANIMS := {
	"idle": {"hoja": "idle", "dirs": 8, "marcos": 8, "fps": 6.0, "loop": true},
	"walk": {"hoja": "walk", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": true},
	"aletear": {"hoja": "aletear", "dirs": 8, "marcos": 8, "fps": 14.0, "loop": false},
	"embestida": {"hoja": "embestida", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": false},
	"nube": {"hoja": "nube", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	"encaje": {"hoja": "encaje", "dirs": 8, "marcos": 4, "fps": 18.0, "loop": false},
	"muerte": {"hoja": "muerte", "dirs": 8, "marcos": 8, "fps": 11.0, "loop": false},
	"cadaver": {"hoja": "muerte", "dirs": 8, "marcos": 1, "desde": 7, "fps": 1.0, "loop": false},
}


# LOS MUTANTES DE LA POLILLA (12/11, polilla-mutante): su carpeta y sus animaciones (tools/sprites_sdf/polilla_mut_sdf.py).
# Ya vienen a su tamaño y con SU color (sin el tinte del piso). Los tiempos de cada gesto son los de la base, asi que sus
# efectos caen igual: 'aletear' son los conos, 'nube' los circulos (y la Lluvia de escamas y el Amortajarse).
const LIENZOS_MUT := {&"vigilia": Vector2i(136, 136), &"mortaja": Vector2i(138, 138), &"insomne": Vector2i(190, 190)}
const _MUT_COMUN := {
	"idle": {"hoja": "idle", "dirs": 8, "marcos": 8, "fps": 6.0, "loop": true},
	"walk": {"hoja": "walk", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": true},
	"aletear": {"hoja": "aletear", "dirs": 8, "marcos": 8, "fps": 14.0, "loop": false},
	"embestida": {"hoja": "embestida", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": false},
	"nube": {"hoja": "nube", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	"encaje": {"hoja": "encaje", "dirs": 8, "marcos": 4, "fps": 18.0, "loop": false},
	"muerte": {"hoja": "muerte", "dirs": 8, "marcos": 8, "fps": 11.0, "loop": false},
	"cadaver": {"hoja": "muerte", "dirs": 8, "marcos": 1, "desde": 7, "fps": 1.0, "loop": false},
}
# Las de rango 1: la transformacion desde su base (el pavon a la Vigilia, la de luto a la Mortaja).
const _MUT_RANGO1 := {
	"evolucion": {"hoja": "evolucion", "dirs": 8, "marcos": 20, "fps": 10.0, "loop": false},
}
# LA INSOMNE: el Ojo que se abre (carga en bucle y el estallido) y DOS transformaciones, una por cada polilla de la que
# puede venir (Enemy.gesto_transformacion busca 'evolucion_<de donde viene>'): de la Vigilia se le ennegrece el oro, de la
# Mortaja se le abren los ojos en la ceniza.
const _MUT_INSOMNE := {
	"ojo_carga": {"hoja": "ojo_carga", "dirs": 8, "marcos": 8, "fps": 8.0, "loop": true},
	"ojo": {"hoja": "ojo", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": false},
	"evolucion_vigilia": {"hoja": "evolucion_luz", "dirs": 8, "marcos": 20, "fps": 10.0, "loop": false},
	"evolucion_mortaja": {"hoja": "evolucion_sombra", "dirs": 8, "marcos": 20, "fps": 10.0, "loop": false},
}


# LA MORTAJA: Amortajarse tiene su propio nombre de gesto (con la hoja de la nube) para que su humo no salga en la Nube de
# ceniza (TacticoPixel.al_gesto).
const _MUT_MORTAJA := {
	"amortajarse": {"hoja": "nube", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
}


static func _anims_mutante(sprite: StringName) -> Dictionary:
	var a: Dictionary = _MUT_COMUN.duplicate()
	a.merge(_MUT_INSOMNE if sprite == &"insomne" else _MUT_RANGO1)
	if sprite == &"mortaja":
		a.merge(_MUT_MORTAJA)
	return a


static func _sprite_mutante(ed: EnemyData, mutacion: StringName) -> StringName:
	var m: MutacionData = ed.mutacion_de(mutacion) if ed != null else null
	return m.sprite if m != null and LIENZOS_MUT.has(m.sprite) else &""


# --- EL SPRITE DE MUTANTE (contrato de SpritesEnemigo, como Miconido3DSprites) ---
static func tiene_mutante(ed: EnemyData, mutacion: StringName = &"") -> bool:
	return _sprite_mutante(ed, mutacion) != &""


static func clave_mutante_de(ed: EnemyData, _t: float, mutacion: StringName = &"") -> String:
	var s: StringName = _sprite_mutante(ed, mutacion)
	return "" if s == &"" else "polilla3d_polilla_sdf_%s" % String(s)


static func generar_mutante_de(ed: EnemyData, _t: float, mutacion: StringName = &"") -> SpriteFrames:
	var s: StringName = _sprite_mutante(ed, mutacion)
	if s == &"":
		return null
	return Sprites3D.montar("res://assets/sprites/enemigos/polilla_sdf_%s/" % String(s), _anims_mutante(s), LIENZOS_MUT[s], BASE,
		BASE)


# LOS OJOS DE LA INSOMNE PARPADEAN POR SEPARADO (12/11, su pedido: como el slime de mil ojos). Una hoja de parpados por
# ojo de ala (6 grupos, solo en idle y walk: tools/sprites_sdf/polilla_mut_sdf.py, PARPADOS) y van POR TURNOS: uno al azar
# cada PARPADO_CADA s, sin repetir hasta que hayan parpadeado otros PARPADO_SIN_REPETIR (Parpadeo.turnos).
const GRUPOS_PARPADO := {&"insomne": 6}
const PARPADO_CADA := 3.0
const PARPADO_SIN_REPETIR := 2


static func _parpados_mut(ed: EnemyData, mutacion: StringName, sufijo: String) -> SpriteFrames:
	var s: StringName = _sprite_mutante(ed, mutacion)
	if not GRUPOS_PARPADO.has(s):
		return null
	return Sprites3D.montar("res://assets/sprites/enemigos/polilla_sdf_%s/" % String(s), _anims_mutante(s), LIENZOS_MUT[s],
		BASE, BASE, sufijo)


static func parpados_de(ed: EnemyData, _t: float, mutante: bool = false, mutacion: StringName = &"") -> SpriteFrames:
	return _parpados_mut(ed, mutacion, "_parpado") if mutante else null


static func parpados_extra_de(ed: EnemyData, _t: float, mutante: bool = false, mutacion: StringName = &"") -> Array:
	var out: Array = []
	if not mutante:
		return out
	for g in range(2, int(GRUPOS_PARPADO.get(_sprite_mutante(ed, mutacion), 1)) + 1):
		var sf: SpriteFrames = _parpados_mut(ed, mutacion, "_parpado%d" % g)
		if sf != null:
			out.append(sf)
	return out


static func turnos_parpados(ed: EnemyData, mutacion: StringName) -> Array:
	return [PARPADO_CADA, PARPADO_SIN_REPETIR] if GRUPOS_PARPADO.has(_sprite_mutante(ed, mutacion)) else []


static func _es_luto(ed: EnemyData) -> bool:
	return ed != null and ed.sprite_variante == &"luto"


# --- Contrato de SpritesEnemigo ---
static func generar_de(ed: EnemyData, t: float) -> SpriteFrames:
	return generar(ed.color_visual(t), _es_luto(ed))


# 'polilla3d_' y no 'polilla_': con la clave vieja, SpritesEnemigo cargaria el horneado VIEJO de disco. La de luto, con
# '_luto' detras del nombre (el mismo tinte daria la misma clave que el pavon).
static func clave_de(ed: EnemyData, t: float) -> String:
	return "polilla3d_%s%s" % ["luto_" if _es_luto(ed) else "",
		SpriteLienzo.cuantizar_hsv(ed.color_visual(t), PolillaSprites.COLOR_PASOS).to_html(false)]


static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(_escala: float = 1.0) -> int:
	return LIENZO.x


static func dimensiona_por_escala() -> bool:
	return true


static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	return PolillaSprites.tam_cuerpo(escala)


static func generar(color: Color = BASE, luto: bool = false) -> SpriteFrames:
	return Sprites3D.montar(CARPETA_LUTO if luto else CARPETA, ANIMS, LIENZO, BASE,
		SpriteLienzo.cuantizar_hsv(color, PolillaSprites.COLOR_PASOS))
