# ============================================================
#  slime3d_sprites.gd  (class_name Slime3DSprites)
#  LOS SLIMES EN 3D (05/10/2026, su referencia: una gominola de GEL TRANSLUCIDO, los ojos solidos en el frente). Se
#  modelan en tools/sprites_sdf/slime_sdf.py, UNA HOJA POR TAMAÑO (el lienzo del viejo cambia con la escala) y por
#  forma: el de siempre (s100, s115, s150, s170), el de LAVA (lava160) y el REY (rey280, con su corona de gel). Aqui
#  solo se cargan (Sprites3D, con el tinte de cada piso). Los tiempos de cada gesto son los del viejo.
#  El viejo (SlimeSprites, por codigo) queda de referencia y presta su lienzo y su caja.
# ============================================================

extends RefCounted
class_name Slime3DSprites

const CARPETA := "res://assets/sprites/enemigos/slime_sdf_%s/"
# Las variantes horneadas: escala -> (carpeta, color en que estan pintadas).
const NORMALES := [[1.00, "s100", "ff2b2b"], [1.15, "s115", "47d552"], [1.50, "s150", "556a80"], [1.70, "s170", "556faa"]]
# LAS MUTACIONES DEL SLIME NORMAL (06/10, su arbol: ver MutacionData y slime.tres), una hoja por mutacion: la variante
# que dice su MutacionData.sprite -> [color en que esta pintada, escala, sus animaciones]. SOLO las que usa cada una
# ("no te inventes cosas": nada de ignicion ni brote). Las mutaciones sin sprite (el Rey, el de lava, los demas slimes)
# se quedan con el normal estirado, como antes.
const _COMUNES_MUT := ["idle", "walk", "embestida", "inflar", "hinchado", "aplaston", "deshincharse", "encaje",
	"muerte", "cadaver", "comer", "evolucion"]
const _COMUNES_TOX := ["idle", "walk", "embestida", "escupir", "encaje", "muerte", "cadaver", "comer", "evolucion"]
const MUTANTES := {
	# El BROTADO: yemas con ojitos, tercer cuerno, nucleo y cristales dentro. 'evolucion' = del normal al brotado.
	&"mut120": ["ff2b2b", 1.20, _COMUNES_MUT],
	# El PUNZANTE: puas de cristal por fuera. Lanza puas (espinas) y Expandir puas (erizar = su carga).
	&"pun120": ["ff2b2b", 1.20, _COMUNES_MUT + ["lanzar_puas", "erizar", "expandir"]],
	# El BROTADO PUNZANTE (x1,1 del brotado). 'evolucion' = desde el brotado; 'evolucion_punzante' = desde el punzante.
	&"evo2": ["ff2b2b", 1.32, _COMUNES_MUT + ["lanzar_puas", "erizar", "expandir", "evolucion_punzante"]],
	# LOS DEL SLIME VENENOSO (06/10): el MIASMA (poros) y el PESTILENTE (poros + burbujas), con las anims del VENENOSO
	# (escupir, sin inflar ni aplaston) + Exhalar miasma (aspirar = su carga) y las burbujas del pestilente.
	&"mia138": ["47d552", 1.38, _COMUNES_TOX + ["aspirar", "exhalar"]],
	&"pes152": ["47d552", 1.518, _COMUNES_TOX + ["aspirar", "exhalar", "soltar_burbujas"]],
}
const LAVA := ["lava160", "ff862b", 1.60]
const REY := ["rey280", "55b8ff", 2.80]

const ANIMS := {
	"idle": {"hoja": "idle", "dirs": 8, "marcos": 8, "fps": 4.0, "loop": true},
	"walk": {"hoja": "walk", "dirs": 8, "marcos": 8, "fps": 8.0, "loop": true},
	"embestida": {"hoja": "embestida", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	"inflar": {"hoja": "inflar", "dirs": 8, "marcos": 8, "fps": 9.0, "loop": false},
	"hinchado": {"hoja": "hinchado", "dirs": 8, "marcos": 8, "fps": 8.0, "loop": true},
	"deshincharse": {"hoja": "deshincharse", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	"encogido": {"hoja": "encogido", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": true},
	"aplaston": {"hoja": "aplaston", "dirs": 8, "marcos": 8, "fps": 14.0, "loop": false},
	"ignicion": {"hoja": "ignicion", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": false},
	"brote": {"hoja": "brote", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	"escupir": {"hoja": "escupir", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": false},
	"nacer": {"hoja": "nacer", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	"encaje": {"hoja": "encaje", "dirs": 8, "marcos": 4, "fps": 18.0, "loop": false},
	"muerte": {"hoja": "muerte", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	"cadaver": {"hoja": "muerte", "dirs": 8, "marcos": 1, "desde": 7, "fps": 1.0, "loop": false},
	# COMER UN CRISTAL (05/10): de momento solo el normal y sus mutaciones (opcional: las demas variantes no la tienen).
	"comer": {"hoja": "comer", "dirs": 8, "marcos": 12, "fps": 10.0, "loop": false, "opcional": true},
	# LAS DE LAS MUTACIONES (06/10): la transformacion HASTA esa hoja, las espinas y Expandir puas.
	"evolucion": {"hoja": "evolucion", "dirs": 8, "marcos": 18, "fps": 10.0, "loop": false, "opcional": true},
	"evolucion_punzante": {"hoja": "evolucion_punzante", "dirs": 8, "marcos": 18, "fps": 10.0, "loop": false,
		"opcional": true},
	"lanzar_puas": {"hoja": "lanzar_puas", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": false, "opcional": true},
	"erizar": {"hoja": "erizar", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": true, "opcional": true},
	"expandir": {"hoja": "expandir", "dirs": 8, "marcos": 10, "fps": 12.0, "loop": false, "opcional": true},
	# LAS DEL MIASMA Y EL PESTILENTE (06/10).
	"aspirar": {"hoja": "aspirar", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": true, "opcional": true},
	"exhalar": {"hoja": "exhalar", "dirs": 8, "marcos": 10, "fps": 12.0, "loop": false, "opcional": true},
	"soltar_burbujas": {"hoja": "soltar_burbujas", "dirs": 8, "marcos": 10, "fps": 12.0, "loop": false, "opcional": true},
}


# La variante horneada que le toca: [carpeta, color base, escala].
static func _variante(escala: float, corona: bool, lava: bool) -> Array:
	if corona:
		return REY
	if lava:
		return LAVA
	var mejor: Array = NORMALES[0]
	for v in NORMALES:
		if absf(float(v[0]) - escala) < absf(float(mejor[0]) - escala):
			mejor = v
	return [mejor[1], mejor[2], mejor[0]]


# La hoja de SU mutacion: [carpeta, color base, escala, animaciones], o [] si esa mutacion no tiene sprite propio.
static func _variante_mutante(ed: EnemyData, mutacion: StringName) -> Array:
	var m: MutacionData = ed.mutacion_de(mutacion) if ed != null else null
	if m == null or not MUTANTES.has(m.sprite):
		return []
	var v: Array = MUTANTES[m.sprite]
	return [String(m.sprite), v[0], v[1], v[2]]


static func _anims_de(lista: Array) -> Dictionary:
	var anims := {}
	for k in lista:
		anims[k] = ANIMS[k]
	return anims


# --- Contrato de SpritesEnemigo ---
static func generar_de(ed: EnemyData, t: float) -> SpriteFrames:
	return generar(ed.color_visual(t), ed.corona_slime, ed.escala_visual, ed.lava_slime)


# 'slime3d_' y no 'slime_': con la clave vieja, SpritesEnemigo cargaria el horneado VIEJO de disco.
static func clave_de(ed: EnemyData, t: float) -> String:
	var v: Array = _variante(ed.escala_visual, ed.corona_slime, ed.lava_slime)
	return "slime3d_%s_%s" % [String(v[0]),
		SpriteLienzo.cuantizar_hsv(ed.color_visual(t), SlimeSprites.COLOR_PASOS).to_html(false)]


# EL SPRITE DE MUTANTE (05/10, ver SpritesEnemigo.frames_de). Ya viene dibujado al tamaño del mutante, asi que quien lo
# pinte no tiene que estirarlo.
static func tiene_mutante(ed: EnemyData, mutacion: StringName = &"") -> bool:
	return not _variante_mutante(ed, mutacion).is_empty()


static func clave_mutante_de(ed: EnemyData, t: float, mutacion: StringName = &"") -> String:
	var v: Array = _variante_mutante(ed, mutacion)
	if v.is_empty():
		return ""
	return "slime3d_%s_%s" % [String(v[0]),
		SpriteLienzo.cuantizar_hsv(ed.color_visual(t), SlimeSprites.COLOR_PASOS).to_html(false)]


static func generar_mutante_de(ed: EnemyData, t: float, mutacion: StringName = &"") -> SpriteFrames:
	var v: Array = _variante_mutante(ed, mutacion)
	if v.is_empty():
		return null
	var lienzo: Vector2i = SlimeSprites._lienzo(float(v[2]))
	return Sprites3D.montar(CARPETA % String(v[0]), _anims_de(v[3]), lienzo, Color(String(v[1])),
		SpriteLienzo.cuantizar_hsv(ed.color_visual(t), SlimeSprites.COLOR_PASOS))


# LOS PARPADOS (05/10): la hoja de los ojos cerrados de su variante (la del mutante si lo es), con el mismo tinte. La
# pone encima Parpadeo a ratos. null si esa variante no la tiene.
static func parpados_de(ed: EnemyData, t: float, mutante: bool = false, mutacion: StringName = &"") -> SpriteFrames:
	var color: Color = SpriteLienzo.cuantizar_hsv(ed.color_visual(t), SlimeSprites.COLOR_PASOS)
	var v: Array = _variante_mutante(ed, mutacion) if mutante else []
	if not v.is_empty():
		return Sprites3D.montar(CARPETA % String(v[0]), _anims_de(v[3]), SlimeSprites._lienzo(float(v[2])),
			Color(String(v[1])), color, "_parpado")
	v = _variante(ed.escala_visual, ed.corona_slime, ed.lava_slime)
	return Sprites3D.montar(CARPETA % String(v[0]), ANIMS, SlimeSprites._lienzo(float(v[2])), Color(String(v[1])),
		color, "_parpado")


static func escala_base() -> float:
	return SlimeSprites.escala_base()


static func ancho_px(escala: float = 1.0) -> int:
	return SlimeSprites.ancho_px(escala)


static func dimensiona_por_escala() -> bool:
	return SlimeSprites.dimensiona_por_escala()


static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	return SlimeSprites.tam_cuerpo(escala)


static func generar(color: Color = Color(1.0, 0.2, 0.2), corona: bool = false, escala: float = 1.0,
		lava: bool = false) -> SpriteFrames:
	var v: Array = _variante(escala, corona, lava)
	var lienzo: Vector2i = SlimeSprites._lienzo(float(v[2]))
	return Sprites3D.montar(CARPETA % String(v[0]), ANIMS, lienzo, Color(String(v[1])),
		SpriteLienzo.cuantizar_hsv(color, SlimeSprites.COLOR_PASOS))
