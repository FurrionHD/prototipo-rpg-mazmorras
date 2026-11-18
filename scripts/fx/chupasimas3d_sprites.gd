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


# ------------------------------------------------------------
#  LOS MUTANTES (17-18/11, chupasimas-mutante), de tools/sprites_sdf/chupasimas_mut_sdf.py: [carpeta, lienzo, sus
#  animaciones, sus VARIANTES de la pelea]. Ya vienen a su tamaño y con SU color (sin el tinte del piso).
#    COAGULO   la sanguijuela llena y oscura; variante 'costra': las postillas puestas (CombatTactico._tick_costra la pone
#              mientras tiene costra y la quita al romperse; al reves que el Tocon, que nace con la suya)
#    VIDRIADA  la cadena de prismas de cristal con el mana dentro: no se pega (sin adherirse/adherido), SORBO y RAYO
#    MADRE     el octogono granate de cristal; variante 'costra'; RAYO y DOS evoluciones (desde la Vidriada 'evolucion',
#              desde el Coagulo 'evolucion_coagulo': Enemy.gesto_transformacion busca evolucion_<de donde viene>)
# ------------------------------------------------------------
const _MUT_ANIMS := {
	"idle": {"hoja": "idle", "dirs": 8, "marcos": 8, "fps": 4.0, "loop": true},
	"walk": {"hoja": "walk", "dirs": 8, "marcos": 8, "fps": 7.0, "loop": true},
	"embestida": {"hoja": "embestida", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	"adherirse": {"hoja": "adherirse", "dirs": 8, "marcos": 8, "fps": 11.0, "loop": false},
	"adherido": {"hoja": "adherido", "dirs": 8, "marcos": 6, "fps": 5.0, "loop": true},
	"drenaje": {"hoja": "drenaje", "dirs": 8, "marcos": 8, "fps": 11.0, "loop": false},
	"encaje": {"hoja": "encaje", "dirs": 8, "marcos": 4, "fps": 18.0, "loop": false},
	"muerte": {"hoja": "muerte", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	"cadaver": {"hoja": "muerte", "dirs": 8, "marcos": 1, "desde": 7, "fps": 1.0, "loop": false},
	# SALTA, MUERDE, BEBE Y VUELVE (la Vidriada no se queda pegada).
	"sorbo": {"hoja": "sorbo", "dirs": 8, "marcos": 10, "fps": 12.0, "loop": false},
	# CARGA Y SUELTA: el mana de dentro engorda y sale por la boca (el rayo en si es un efecto aparte).
	"rayo": {"hoja": "rayo", "dirs": 8, "marcos": 10, "fps": 11.0, "loop": false},
	"comer": {"hoja": "comer", "dirs": 8, "marcos": 10, "fps": 10.0, "loop": false},
	"evolucion": {"hoja": "evolucion", "dirs": 8, "marcos": 18, "fps": 10.0, "loop": false},
	"evolucion_coagulo": {"hoja": "evolucion_coagulo", "dirs": 8, "marcos": 18, "fps": 10.0, "loop": false},
}
const _PEGADA := ["idle", "walk", "embestida", "adherirse", "adherido", "drenaje", "encaje", "muerte", "cadaver"]
const _CRISTAL := ["idle", "walk", "embestida", "drenaje", "encaje", "muerte", "cadaver", "sorbo", "rayo"]
const LIENZO_MUT := Vector2i(104, 104)
const MUTANTES := {
	&"coagulo": ["chupasimas_sdf_coagulo", _PEGADA + ["comer", "evolucion"], {&"costra": _PEGADA}],
	&"vidriada": ["chupasimas_sdf_vidriada", _CRISTAL + ["comer", "evolucion"], {}],
	&"madre": ["chupasimas_sdf_madre", _PEGADA + ["rayo", "comer", "evolucion", "evolucion_coagulo"],
		{&"costra": _PEGADA + ["rayo"]}],
}


static func _anims_de(lista: Array) -> Dictionary:
	var anims := {}
	for k in lista:
		anims[k] = _MUT_ANIMS[k].duplicate()
	return anims


# --- EL SPRITE DE MUTANTE (contrato de SpritesEnemigo, como Trent3DSprites) ---
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
	return "" if v.is_empty() else "chupasimas3d_%s" % String(v[0])


static func generar_mutante_de(ed: EnemyData, _t: float, mutacion: StringName = &"") -> SpriteFrames:
	var v: Array = _variante_mutante(ed, mutacion)
	if v.is_empty():
		return null
	return Sprites3D.montar("res://assets/sprites/enemigos/%s/" % String(v[0]), _anims_de(v[1]), LIENZO_MUT, BASE, BASE)


# --- SUS VARIANTES DE LA PELEA (contrato de SpritesEnemigo.frames_variante y del horno) ---
static func variantes_de_mutante(ed: EnemyData, mutacion: StringName) -> Array:
	var v: Array = _variante_mutante(ed, mutacion)
	return [] if v.is_empty() else (v[2] as Dictionary).keys()


static func clave_variante_de(ed: EnemyData, mutacion: StringName, variante: StringName) -> String:
	var v: Array = _variante_mutante(ed, mutacion)
	return "" if v.is_empty() else "chupasimas3d_%s_%s" % [String(v[0]), String(variante)]


static func generar_variante_de(ed: EnemyData, mutacion: StringName, variante: StringName) -> SpriteFrames:
	var v: Array = _variante_mutante(ed, mutacion)
	if v.is_empty() or not (v[2] as Dictionary).has(variante):
		return null
	var carpeta: String = "res://assets/sprites/enemigos/%s_%s/" % [String(v[0]), String(variante)]
	return Sprites3D.montar(carpeta, _anims_de(v[2][variante]), LIENZO_MUT, BASE, BASE)
