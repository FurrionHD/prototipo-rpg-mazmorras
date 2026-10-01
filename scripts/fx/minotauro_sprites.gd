# ============================================================
#  minotauro_sprites.gd  (class_name MinotauroSprites)
#  Sprite del MINOTAURO dibujado por codigo, con el motor comun (SpriteLienzo) y la camara de 45 grados de todos los
#  bichos. Es el JEFE DEL PISO 12 (scenes/actors/enemy/guardian_rango.tres).
#
#  REHECHO DE CERO (01/10) desde la referencia que eligio el usuario ("esto es peak"), guardada en
#  Escritorio\ataques_mapa\enemigos\minotauro\referencia\ (cuerpo.png, con_hacha.png, embestida.png). El de antes (en
#  git) salio "horrible en general": cabezon, cuernos de lira, bolas por hombros y achaparrado. Lo que manda ahora:
#    * PIERNAS LARGAS: mas de la mitad del cuerpo. La camara a 45 grados encoge las alturas, asi que se ESTIRA la Z.
#    * CABEZA PEQUEÑA Y HUNDIDA entre los hombros por el TRAPECIO, cara larga y morro abajo, ojos ambar, anilla de oro.
#    * CUERNOS EN U: cortos, gordos, salen a lo ancho y suben.
#    * BRAZOS LARGUISIMOS (el puño a medio muslo), antebrazo gordo, BRAZALETES anchos y PUÑOS enormes.
#    * TAPARRABOS largo hasta la rodilla, CAÑAS oscuras, PEZUÑAS gris azulado y COLA con borla.
#    * EL HACHA (labrys) en su PROPIA CAPA, como las armas de los personajes: cogida con el puño derecho.
#
#  COMO SE DIBUJA: por PARTES (cada pierna, cada brazo, el torso, la cabeza, cada cuerno, la cola, el hacha). Cada parte
#  tiene un ANCLA y se pinta en orden de PROFUNDIDAD (lo mas lejos de la camara primero), asi que el orden sale solo en
#  las 8 direcciones. Y entre partes van LAS LINEAS DE DENTRO (SpriteLienzo.contornear_grupos): donde una parte suelta
#  pasa por delante de otra hay raya; donde una nace de otra (muslo-cadera, cuello-pecho, cuerno-craneo, la raiz del
#  brazo) no, que si no sale "descuartizado".
#
#  ESTADO: solo esta la pose QUIETA (para el visto bueno del usuario). Las demas animaciones usan esa pose de momento.
# ============================================================

extends RefCounted
class_name MinotauroSprites

const FRAMES := 8

# --- MUNDO: origen = donde pisa, +X a su IZQUIERDA (a la derecha de la pantalla mirando al sur), +Y hacia donde mira,
# +Z arriba. Mide ALTO_MUNDO de las pezuñas a la coronilla (los cuernos, unas 3 mas).
const ALTO_MUNDO := 40.0
# LA ALTURA SE ESTIRA EN PANTALLA: la camara a 45 grados encoge las alturas un 30% y deja los anchos. En un bicho bajo
# da igual; en un humanoide de pie lo deja achaparrado y con las piernas comidas, que es lo que le pasaba al de antes.
const ESTIRA_Z := 1.25

# --- LAS PIERNAS: muslo grueso hasta la rodilla en su color, y de ahi abajo la CAÑA oscura y peluda, con el corvejon
# un poco hacia atras (pata de toro), y la PEZUÑA gris azulado.
const PIERNA_X := 5.0
const MUSLO := Vector3(0.0, 0.5, 17.6)
const MUSLO_R := Vector3(3.6, 4.0, 5.4)
const RODILLA := Vector3(0.0, -0.6, 11.4)
const RODILLA_R := Vector3(2.8, 3.0, 2.8)
const CANA := Vector3(0.0, 0.2, 6.0)
const CANA_R := Vector3(2.2, 2.4, 4.2)
const PEZUNA := Vector3(0.2, 1.3, 1.2)
const PEZUNA_R := Vector3(2.3, 2.9, 1.3)

# --- EL TORSO EN V: pelvis, vientre, PECHO ancho y el TRAPECIO que hunde la cabeza.
const PELVIS := Vector3(0.0, -0.8, 22.4)
const PELVIS_R := Vector3(6.2, 4.8, 3.2)
const VIENTRE := Vector3(0.0, 1.0, 25.4)
const VIENTRE_R := Vector3(5.6, 4.6, 3.4)
const PECHO := Vector3(0.0, 1.4, 29.8)
const PECHO_R := Vector3(8.8, 6.0, 4.6)
const TRAPECIO := Vector3(0.0, -0.8, 34.2)
const TRAPECIO_R := Vector3(6.6, 3.6, 2.8)

# --- LOS BRAZOS: del HOMBRO (el deltoide) cuelgan siete tramos con el CODO en el tercero. Se estrechan hacia el codo
# y el ANTEBRAZO ENGORDA, como en la referencia; los tramos 4 y 5 llevan el BRAZALETE, ancho y un pelin mas gordo
# que el brazo para que asome en la silueta.
const HOMBRO := Vector3(10.0, 0.4, 32.2)
const DELTOIDE_R := Vector3(3.1, 3.2, 3.4)
const BRAZO_PASO := 2.3
const BRAZO_RADIOS := [2.7, 2.5, 2.3, 2.55, 2.9, 2.85, 2.55]
const BRAZO_CODO_SEG := 3
const BRAZALETE_SEGS := [5, 6]
const BRAZO_ABRE := 0.10            # cuelga un pelin hacia fuera: los puños quedan por fuera de los muslos
const BRAZO_ADELANTA := 0.85
const BRAZO_RAIZ := 2               # deltoide + estos tramos, sin linea contra el torso (SpriteLienzo.RAIZ)
# EL PUÑO: tan gordo como el antebrazo, con la fila de NUDILLOS hacia delante y el pulgar por dentro.
const PUNO_R := Vector3(2.8, 2.7, 2.9)
const NUDILLO_R := 1.05

# --- LA CABEZA: cara larga hacia abajo, morro claro, ojos ambar con el ceño, orejas, anilla de oro.
const CUELLO := Vector3(0.0, -0.4, 36.6)
const CUELLO_R := Vector3(3.6, 3.2, 3.0)
const CRANEO := Vector3(0.0, 0.2, 41.6)
const CRANEO_R := Vector3(3.9, 3.9, 3.6)
const CARA := Vector3(0.0, 1.4, 39.2)
const CARA_R := Vector3(3.0, 3.0, 3.2)
const HOCICO := Vector3(0.0, 2.8, 37.0)
const HOCICO_R := Vector3(2.1, 1.9, 1.5)
const OJO := Vector3(2.1, 2.4, 40.8)
const OJO_R := Vector3(0.75, 0.75, 0.75)
const OREJA := Vector3(4.3, -0.2, 41.8)
const OREJA_R := Vector3(1.9, 1.0, 1.0)
const ANILLA := Vector3(0.0, 4.2, 35.8)
const ANILLA_R := 1.3
const ANILLA_GROSOR := 0.5
const ANILLA_SEGMENTOS := 7

# --- LOS CUERNOS EN U: salen casi horizontales hacia fuera y giran hacia ARRIBA, cerrandose un poco al final.
const CUERNO_BASE := Vector3(3.0, 0.0, 43.2)
const CUERNO_SEGMENTOS := 7
const CUERNO_PASO := 1.6
const CUERNO_R0 := 1.4
const CUERNO_R1 := 0.75
const CUERNO_ANG0 := 0.55           # el primer tramo: hacia fuera, apenas subiendo
const CUERNO_GIRO := 0.26           # cuanto sube por tramo (radianes)
# LA RABIA (01/10): el cuerno IZQUIERDO partido, con el muñon.
const CUERNO_ROTO_LADO := 1.0
const CUERNO_ROTO_QUEDA := 3

# --- EL TAPARRABOS: el cinto ancho y el FALDON delante y detras, hasta la rodilla.
const CINTO := Vector3(0.0, -0.2, 21.6)
const CINTO_R := Vector3(6.4, 4.5, 1.2)
const FALDON_Y := 4.1
const FALDON_ARRIBA := 20.4
const FALDON_ABAJO := 13.0
const FALDON_ANCHO := 2.8

# --- LA COLA: sale de detras de la cadera, cae y se abre hacia un lado, con la BORLA oscura.
const COLA_BASE := Vector3(0.0, -4.4, 21.4)
const COLA_SEGMENTOS := 10
const COLA_PASO := 1.1
const COLA_R := 0.75
const BORLA_R := Vector3(1.4, 1.4, 2.2)

# --- EL HACHA, LA LABRYS, en su capa: va en la mano DERECHA (X negativa: la de la izquierda de la pantalla mirando al
# sur, como en la referencia). QUIETA la lleva colgando junto a la pierna, cogida cerca de la cabeza del hacha.
const HACHA_LADO := -1.0
const MANGO_LARGO := 9.0            # del puño hacia ARRIBA, por detras del antebrazo
const MANGO_R := 0.65
const MANGO_PASO := 0.6
const HOJA_ANCHO := 5.4             # cuanto sale cada hoja del mango
const HOJA_ALTO := 4.4              # media altura de la hoja junto al filo
const HOJA_PASO := 0.65
const HOJA_BOLA := 0.72

# --- EL LIENZO, en multiplos de la altura: rectangular, con el origen abajo.
const LIENZO_ANCHO := 1.55
const LIENZO_ARRIBA := 1.62
const LIENZO_ABAJO := 0.35

enum Tono { VACIO, SOMBRA_SUELO, BORDE, BASE, CLARO, SOMBRA, PIERNA_OSC, PEZUNA_T, CUERO_T, CUERNO_T, HOCICO_T,
	OJO_T, ANILLA_T, MADERA_T, HIERRO_T, FILO_T }

# Las 8 direcciones (pantalla: +Y abajo), mismo orden que el resto: 0=S 1=SE 2=E 3=NE 4=N 5=NW 6=W 7=SW.
const DIR_VECS := [
	Vector2(0, 1), Vector2(0.7, 0.7), Vector2(1, 0), Vector2(0.7, -0.7),
	Vector2(0, -1), Vector2(-0.7, -0.7), Vector2(-1, 0), Vector2(-0.7, 0.7),
]

const COLOR_PASOS := 6.0
static var _cache: Dictionary = {}
static var _cache_plantillas: Dictionary = {}
# Lo que lee _piezas mientras se genera (un generador a la vez: no hay hilos).
static var _roto: bool = false
# Las parejas de partes UNIDAS del ultimo _piezas (sin linea entre ellas): las escribe _piezas y las lee _plantilla.
static var _unidas: Dictionary = {}


# --- Contrato de SpritesEnemigo ---
static func generar_de(ed: EnemyData, t: float) -> SpriteFrames:
	return generar(ed.color_visual(t), ed.escala_visual)


static func clave_de(ed: EnemyData, t: float) -> String:
	return _clave(SpriteLienzo.cuantizar_hsv(ed.color_visual(t), COLOR_PASOS), snappedf(ed.escala_visual, 0.05))


static func generar_roto_de(ed: EnemyData, t: float) -> SpriteFrames:
	return generar(ed.color_visual(t), ed.escala_visual, true)


static func clave_roto_de(ed: EnemyData, t: float) -> String:
	return _clave(SpriteLienzo.cuantizar_hsv(ed.color_visual(t), COLOR_PASOS), snappedf(ed.escala_visual, 0.05), true)


static func _clave(col: Color, esc: float, roto: bool = false) -> String:
	return "minotauro_%s_%.2f%s" % [col.to_html(false), esc, "_roto" if roto else ""]


static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(escala: float = 1.0) -> int:
	return _lienzo(escala).x


static func dimensiona_por_escala() -> bool:
	return true


# El CUERPO en planta para la colision: lo marcan las PEZUÑAS. Brazos, cuernos y hacha se quedan fuera (un jefe que no
# cupiera por su sala porque abre los brazos seria absurdo).
static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	var ancho: float = (PIERNA_X + PEZUNA_R.x) * 2.0
	var largo: float = (PEZUNA.y + PEZUNA_R.y) - (RODILLA.y - RODILLA_R.y)
	return Vector2(ancho, largo) * escala


static func _lienzo(escala: float) -> Vector2i:
	var alto_celdas: float = ALTO_MUNDO * escala / SpriteLienzo.UNIDADES_POR_CELDA
	var w: int = int(ceil(alto_celdas * LIENZO_ANCHO))
	var h: int = int(ceil(alto_celdas * (LIENZO_ARRIBA + LIENZO_ABAJO)))
	return Vector2i(w + (w % 2), h + (h % 2))


static func _origen(escala: float) -> Vector2:
	var lz: Vector2i = _lienzo(escala)
	var alto_celdas: float = ALTO_MUNDO * escala / SpriteLienzo.UNIDADES_POR_CELDA
	return Vector2(float(lz.x) * 0.5, alto_celdas * LIENZO_ARRIBA)


static func generar(color: Color = Color(0.55, 0.34, 0.2), escala: float = 1.0, roto: bool = false) -> SpriteFrames:
	var col: Color = SpriteLienzo.cuantizar_hsv(color, COLOR_PASOS)
	var esc: float = snappedf(escala, 0.05)
	var clave: String = _clave(col, esc, roto)
	if _cache.has(clave):
		return _cache[clave]
	_roto = roto
	var anims: Array = []
	var quieto := func(t: float) -> Dictionary:
		return _pose_idle(t)
	_montar_animacion(anims, esc, "idle", true, 3.0, quieto, false)
	# PROVISIONAL (01/10): hasta que el usuario de el visto bueno al cuerpo nuevo, el resto de animaciones repiten la
	# pose quieta. Los nombres son los que pide el combate.
	# Reutilizan los fotogramas ya hechos del quieto (sin recalcular nada).
	var idle: Array = anims.duplicate()
	for nombre in ["walk", "embestida", "barrido", "cornada", "pisoton", "bramido"]:
		for dir in 8:
			anims.append({"nombre": "%s_%d" % [nombre, dir], "loop": nombre == "walk", "fps": 8.0,
				"plantillas": idle[dir]["plantillas"]})
	anims.append({"nombre": "encaje_0", "loop": false, "fps": 18.0, "plantillas": idle[0]["plantillas"].slice(0, 4)})
	anims.append({"nombre": "muerte_0", "loop": false, "fps": 9.0, "plantillas": idle[0]["plantillas"]})
	for dir in 8:
		anims.append({"nombre": "cadaver_%d" % dir, "loop": false, "fps": 1.0, "plantillas": [idle[dir]["plantillas"][0]]})
	var lz: Vector2i = _lienzo(esc)
	var sf: SpriteFrames = SpriteLienzo.montar_frames(anims, SpriteLienzo.paleta(_colores(col)), lz.x, lz.y)
	_roto = false
	_cache[clave] = sf
	return sf


# La pose de reposo, con TODAS las claves: cada animacion escribe solo lo suyo.
static func _reposo() -> Dictionary:
	return {
		"avance": 0.0,       # cuanto se desplaza hacia donde mira
		"resopla": 0.0,      # respiracion: hincha el cuerpo
		"patas": 0.0,        # fase de la zancada (-1..1)
		"agacha": 0.0,       # se hunde sobre las piernas (0..1)
		"inclina": 0.0,      # el torso hacia delante sobre la cadera (radianes)
		"cabeza": 0.0,       # la cabeza arriba (+) o abajo (-), en unidades
		# Los brazos: angulo desde la vertical en el plano de delante (0 a plomo, PI/2 al frente) y codo (radianes).
		"brazo_d": 0.10, "codo_d": 0.15, "brazo_i": 0.10, "codo_i": 0.15,
		"hacha": 0,          # 0 = colgando en la mano (quieto)
	}


# QUIETO: respira hondo, los hombros suben y bajan y la cabeza apenas se mueve.
static func _pose_idle(t: float) -> Dictionary:
	var p: Dictionary = _reposo()
	p["resopla"] = sin(TAU * t)
	p["cabeza"] = 0.25 * sin(TAU * t)
	p["codo_d"] = 0.15 + 0.04 * sin(TAU * t)
	p["codo_i"] = 0.15 + 0.04 * sin(TAU * t)
	return p


static func _montar_animacion(anims: Array, esc: float, nombre: String, loop: bool, fps: float,
		pose_fn: Callable, ultimo_incluido: bool, dirs: int = 8, marcos: int = FRAMES) -> void:
	var divisor: float = float(marcos - 1) if ultimo_incluido else float(marcos)
	for dir in dirs:
		var plantillas: Array = []
		for i in marcos:
			var t: float = float(i) / divisor if divisor > 0.0 else 0.0
			var clave: String = "%s_%d_%d_%.2f%s" % [nombre, i, dir, esc, "_roto" if _roto else ""]
			var plant: PackedByteArray = _cache_plantillas.get(clave, PackedByteArray())
			if plant.is_empty():
				plant = _plantilla(dir, pose_fn.call(t), esc)
				_cache_plantillas[clave] = plant
			plantillas.append(plant)
		anims.append({"nombre": "%s_%d" % [nombre, dir], "loop": loop, "fps": fps, "plantillas": plantillas})


# LOS COLORES, sacados de la referencia: rojo anaranjado de base, el pecho y los hombros mas claros, las cañas pardo
# oscuro, las pezuñas gris azulado y el cuero casi negro. La BASE se tuerce hacia ese rojo pero guarda el BRILLO del
# color de la ficha, para que las variantes de la franja (color_visual) sigan distinguiendose.
static func _colores(color: Color) -> Array:
	var base := Color.from_hsv(0.035, 0.74, clampf(color.v * 1.22, 0.45, 0.85))
	return [
		Color(0, 0, 0, 0),                          # VACIO
		Color(0, 0, 0, 0.22),                       # SOMBRA_SUELO
		Color(0.13, 0.06, 0.05),                    # BORDE
		base,                                       # BASE
		base.lerp(Color(0.95, 0.58, 0.30), 0.42),   # CLARO (pecho, hombros, lomo)
		base.darkened(0.30),                        # SOMBRA (bajo el pecho, lo que va al fondo)
		Color(0.34, 0.19, 0.14),                    # PIERNA_OSC (las cañas)
		Color(0.22, 0.24, 0.32),                    # PEZUNA_T (gris azulado)
		Color(0.25, 0.16, 0.13),                    # CUERO_T (taparrabos, brazaletes, el puño del hacha)
		Color(0.92, 0.82, 0.66),                    # CUERNO_T
		Color(0.86, 0.56, 0.50),                    # HOCICO_T
		Color(1.00, 0.80, 0.12),                    # OJO_T
		Color(0.96, 0.76, 0.16),                    # ANILLA_T (oro)
		Color(0.42, 0.24, 0.14),                    # MADERA_T
		Color(0.30, 0.31, 0.35),                    # HIERRO_T
		Color(0.80, 0.80, 0.82),                    # FILO_T
	]


# ------------------------------------------------------------
#  GEOMETRIA
# ------------------------------------------------------------

static func _piezas(dir: int, pose: Dictionary, esc: float) -> Array:
	var ang: float = DIR_VECS[dir].angle() - DIR_VECS[0].angle()
	var u: float = esc / SpriteLienzo.UNIDADES_POR_CELDA
	var org: Vector2 = _origen(esc)
	var agacha: float = float(pose["agacha"])
	var inclina: float = float(pose["inclina"])
	var alto: float = 1.0 - 0.30 * agacha
	var hincha: float = 1.0 + 0.022 * float(pose["resopla"])
	var desp := Vector2(0.0, float(pose["avance"])).rotated(ang)
	var s_a: float = sin(ang)
	var c_a: float = cos(ang)

	# LAS PARTES: cada una con su ancla (para ordenarlas por profundidad) y sus piezas. 'cur' es la que se esta llenando
	# (un Dictionary porque las lambdas capturan por valor).
	var partes: Array = []
	var cur: Dictionary = {"p": null, "sup": false, "raiz": false}
	var profundidad := func(local: Vector3) -> float:
		return Vector2(local.x, local.y).rotated(ang).y
	var parte := func(nombre: String, ancla: Vector3, sesgo: float = 0.0, sup: bool = true) -> void:
		var pt := {"nombre": nombre, "prof": profundidad.call(ancla) + sesgo, "orden": partes.size(), "piezas": []}
		partes.append(pt)
		cur["p"] = pt
		cur["sup"] = sup

	# local -> pieza de pantalla. LO DE CINTURA PARA ARRIBA ('sup') gira con 'inclina' alrededor de la cadera.
	var poner := func(local0: Vector3, r: Vector3, tono: int, solo_sobre: Array = [], en_suelo: bool = false) -> void:
		var local: Vector3 = local0
		if bool(cur["sup"]) and not is_zero_approx(inclina):
			var dy: float = local.y - PELVIS.y
			var dz: float = local.z - PELVIS.z
			local = Vector3(local.x, PELVIS.y + dy * cos(inclina) + dz * sin(inclina),
				PELVIS.z + dz * cos(inclina) - dy * sin(inclina))
		var rot: Vector2 = Vector2(local.x, local.y).rotated(ang) + desp
		var z: float = 0.0 if en_suelo else local.z * alto * hincha * ESTIRA_Z
		var sx: float = org.x + rot.x * u
		var sy: float = org.y + (rot.y * SpriteLienzo.COS_CAM - z * SpriteLienzo.SIN_CAM) * u
		# La perspectiva se mide sobre el radio YA GIRADO (la leccion de las patas del acechador).
		var ry_rot: float = sqrt(r.x * r.x * s_a * s_a + r.y * r.y * c_a * c_a)
		var decal: bool = en_suelo or not solo_sobre.is_empty()
		# LO PINTADO ENCIMA SOLO SE VE POR SU CARA: un adorno que esta en la cara de atras del cuerpo (la sombra del
		# pecho mirando de espaldas) no se pinta. Sin esto se transparentaba por la espalda.
		if not solo_sobre.is_empty():
			var fuera := Vector2(local0.x, local0.y)
			if fuera.length() > 1.0 and fuera.rotated(ang).y < -0.25 * fuera.length():
				return
		cur["p"]["piezas"].append({"pos": Vector2(sx, sy), "radio": Vector2(r.x * u, r.y * u), "tono": tono,
			"ang": ang, "persp": SpriteLienzo.persp_de(ry_rot, r.z * alto * ESTIRA_Z), "solo_sobre": solo_sobre,
			"decal": decal, "raiz": bool(cur["raiz"])})

	# --- LA SOMBRA DE CONTACTO, lo primero de todo.
	parte.call("suelo", Vector3.ZERO, -1000.0, false)
	poner.call(Vector3.ZERO, Vector3(PIERNA_X + PEZUNA_R.x + 1.0, PEZUNA_R.y * 1.8, 0.0), Tono.SOMBRA_SUELO, [], true)

	# --- LAS PIERNAS. Un pelin por detras del torso en profundidad (la pelvis tapa el arranque de los muslos).
	var fase: float = float(pose["patas"])
	for lado in [-1.0, 1.0]:
		parte.call("pierna", Vector3(lado * PIERNA_X, 0.0, 0.0), -0.6, false)
		var swing: float = fase * lado
		var y_off: float = swing * 2.6
		var z_off: float = maxf(0.0, swing) * 1.8
		var reparto := [[MUSLO, MUSLO_R, 0.45, 0.1, Tono.BASE], [RODILLA, RODILLA_R, 0.75, 0.5, Tono.PIERNA_OSC],
			[CANA, CANA_R, 1.0, 0.85, Tono.PIERNA_OSC], [PEZUNA, PEZUNA_R, 1.0, 1.0, Tono.PEZUNA_T]]
		for pz in reparto:
			var c: Vector3 = pz[0]
			poner.call(Vector3(lado * (PIERNA_X + c.x), c.y + y_off * float(pz[2]), c.z + z_off * float(pz[3])),
				pz[1], int(pz[4]))
		# La pezuña HENDIDA: una raya oscura por delante.
		poner.call(Vector3(lado * (PIERNA_X + PEZUNA.x), PEZUNA.y + y_off + 1.6, PEZUNA.z + z_off), Vector3(0.35, 1.4, 1.0),
			Tono.BORDE, [Tono.PEZUNA_T])

	# --- EL TORSO (con el taparrabos y sus luces y sombras pintadas encima).
	parte.call("torso", Vector3.ZERO)
	poner.call(PELVIS, PELVIS_R, Tono.BASE)
	poner.call(VIENTRE, VIENTRE_R, Tono.BASE)
	poner.call(PECHO, PECHO_R, Tono.BASE)
	poner.call(TRAPECIO, TRAPECIO_R, Tono.BASE)
	# LUZ ARRIBA Y SOMBRA ABAJO, como la referencia: el pecho y lo alto de la espalda claros...
	poner.call(Vector3(0.0, 2.4, 29.4), Vector3(7.8, 4.6, 2.4), Tono.CLARO, [Tono.BASE])
	poner.call(Vector3(0.0, -2.6, 30.6), Vector3(7.4, 2.8, 3.0), Tono.CLARO, [Tono.BASE])
	# ...la raya bajo los PECTORALES, y la linea de los ABDOMINALES.
	for lado in [-1.0, 1.0]:
		poner.call(Vector3(lado * 4.3, 3.6, 25.8), Vector3(3.6, 2.0, 1.0), Tono.SOMBRA, [Tono.BASE, Tono.CLARO])
	poner.call(Vector3(0.0, 4.2, 23.4), Vector3(0.5, 1.2, 2.6), Tono.SOMBRA, [Tono.BASE])
	for k in 2:
		poner.call(Vector3(0.0, 4.0, 22.6 + 1.9 * k), Vector3(2.8, 1.2, 0.4), Tono.SOMBRA, [Tono.BASE])
	# El cinto y el faldon (delante y detras), de cuero.
	# EL CINTO NO ES UNA PIEZA: un disco ancho y bajo, visto desde arriba a 45 grados, enseña su CARA DE ARRIBA y se
	# come la barriga entera. Es una banda pintada sobre la piel, por delante, por detras y por los costados.
	for c in [Vector3(0.0, CINTO_R.y - 0.6, CINTO.z), Vector3(0.0, -CINTO_R.y + 0.6, CINTO.z)]:
		poner.call(c, Vector3(CINTO_R.x, 1.2, CINTO_R.z), Tono.CUERO_T, [Tono.BASE, Tono.SOMBRA])
	for sg in [1.0, -1.0]:
		poner.call(Vector3(sg * (CINTO_R.x - 0.7), 0.0, CINTO.z), Vector3(1.2, CINTO_R.y, CINTO_R.z), Tono.CUERO_T,
			[Tono.BASE, Tono.SOMBRA])
	# EL FALDON, delante y detras, cada uno SU PARTE (si fuera del torso, el de atras se pintaba encima de la barriga).
	for sg in [1.0, -1.0]:
		parte.call("faldon", Vector3(0.0, sg * FALDON_Y, 0.0), 0.1)
		var n: int = 5
		for k in n:
			var f: float = float(k) / float(n - 1)
			poner.call(Vector3(0.0, sg * (FALDON_Y + 0.3 * f), lerpf(FALDON_ARRIBA, FALDON_ABAJO + 1.0, f)),
				Vector3(lerpf(FALDON_ANCHO, FALDON_ANCHO * 0.8, f), 0.6, 2.0), Tono.CUERO_T)

	# --- LA COLA: detras de la cadera, cae y se abre hacia el lado izquierdo, con la borla.
	parte.call("cola", COLA_BASE, 0.0, false)
	var cp: Vector3 = COLA_BASE
	for k in COLA_SEGMENTOS:
		var f: float = float(k) / float(COLA_SEGMENTOS - 1)
		poner.call(cp, Vector3.ONE * COLA_R, Tono.BASE)
		var d := Vector3(0.55 * f, -0.65 + 0.35 * f, -0.75).normalized()
		cp += d * COLA_PASO
	poner.call(cp + Vector3(0.0, 0.0, -0.8), BORLA_R, Tono.PIERNA_OSC)

	# --- LOS BRAZOS: cadena por pasos con el codo de golpe en una junta; el deltoide y los primeros tramos son RAIZ.
	var manos: Dictionary = {}
	for lado in [-1.0, 1.0]:
		var hombro := Vector3(lado * HOMBRO.x, HOMBRO.y, HOMBRO.z)
		parte.call("brazo", hombro, 0.3)
		var a: float = float(pose["brazo_d"] if lado == HACHA_LADO else pose["brazo_i"])
		var flex: float = float(pose["codo_d"] if lado == HACHA_LADO else pose["codo_i"])
		cur["raiz"] = true
		poner.call(hombro, DELTOIDE_R, Tono.BASE)
		poner.call(hombro + Vector3(lado * 0.3, 0.6, 1.2), Vector3(2.6, 2.6, 1.6), Tono.CLARO, [Tono.BASE])
		var p3: Vector3 = hombro + Vector3(0.0, 0.0, -1.6)
		var d3 := Vector3(0.0, 0.0, -1.0)
		for k in BRAZO_RADIOS.size():
			cur["raiz"] = k < BRAZO_RAIZ
			var rk: float = float(BRAZO_RADIOS[k])
			poner.call(p3, Vector3.ONE * rk, Tono.BASE)
			if k in BRAZALETE_SEGS:
				poner.call(p3, Vector3.ONE * (rk + 0.3), Tono.CUERO_T)
			if k == BRAZO_CODO_SEG - 1:
				a += flex
			d3 = Vector3(lado * BRAZO_ABRE, sin(a) * BRAZO_ADELANTA, -cos(a)).normalized()
			p3 += d3 * BRAZO_PASO
		cur["raiz"] = false
		# EL PUÑO, con los nudillos hacia delante (perpendiculares al antebrazo) y el pulgar por dentro.
		var puno: Vector3 = p3 + d3 * 0.6
		poner.call(puno, PUNO_R, Tono.BASE)
		var frente := Vector3(0.0, 1.0, 0.0)
		frente = (frente - d3 * frente.dot(d3)).normalized()
		var ancho: Vector3 = d3.cross(frente).normalized()
		for i in 4:
			var o: float = (float(i) - 1.5) * 1.35
			poner.call(puno + frente * 1.9 + ancho * o + d3 * 0.6, Vector3.ONE * NUDILLO_R, Tono.BASE)
		poner.call(puno + Vector3(-lado * 2.2, 1.0, 0.4), Vector3.ONE * 1.0, Tono.BASE)
		manos[lado] = {"p": puno, "d": d3}

	# --- LA CABEZA: cuello, craneo, cara larga, morro, orejas, ojos y anilla. Por delante del torso (sesgo).
	var cab_y: float = float(pose["cabeza"])
	var frente_dir: float = DIR_VECS[dir].y
	var se_ve_cara: bool = frente_dir > -0.5
	parte.call("cabeza", CRANEO, 0.5)
	var cz := Vector3(0.0, 0.0, cab_y)
	poner.call(CUELLO + cz * 0.4, CUELLO_R, Tono.BASE)
	poner.call(CRANEO + cz, CRANEO_R, Tono.BASE)
	poner.call(CARA + cz, CARA_R, Tono.BASE)
	poner.call(CRANEO + cz + Vector3(0.0, 0.6, 1.6), Vector3(2.8, 2.6, 1.6), Tono.CLARO, [Tono.BASE])
	poner.call(HOCICO + cz, HOCICO_R, Tono.HOCICO_T if se_ve_cara else Tono.SOMBRA)
	for lado in [-1.0, 1.0]:
		poner.call(Vector3(lado * OREJA.x, OREJA.y, OREJA.z) + cz, OREJA_R, Tono.SOMBRA)
	if se_ve_cara:
		for lado in [-1.0, 1.0]:
			# El CEÑO encima del ojo, y el ojo.
			poner.call(Vector3(lado * OJO.x, OJO.y, OJO.z + 0.9) + cz, Vector3(1.5, 0.9, 0.6), Tono.SOMBRA, [Tono.BASE, Tono.CLARO])
			poner.call(Vector3(lado * OJO.x, OJO.y, OJO.z) + cz, OJO_R, Tono.OJO_T)
		# Las NARINAS, dos puntos oscuros en el morro.
		for lado in [-1.0, 1.0]:
			poner.call(HOCICO + cz + Vector3(lado * 1.0, 2.0, 0.2), Vector3.ONE * 0.5, Tono.BORDE, [Tono.HOCICO_T])
		for k in ANILLA_SEGMENTOS:
			var fa: float = float(k) / float(ANILLA_SEGMENTOS - 1)
			var aa: float = PI * (0.1 + 0.8 * fa)
			poner.call(Vector3(ANILLA.x + cos(aa) * ANILLA_R, ANILLA.y, ANILLA.z - sin(aa) * ANILLA_R) + cz,
				Vector3.ONE * ANILLA_GROSOR, Tono.ANILLA_T)

	# --- LOS CUERNOS EN U, cada uno su parte (el del fondo queda detras del craneo solo).
	for lado in [-1.0, 1.0]:
		var base := Vector3(lado * CUERNO_BASE.x, CUERNO_BASE.y, CUERNO_BASE.z) + cz
		parte.call("cuerno", base, 0.6)
		var n_seg: int = CUERNO_SEGMENTOS
		if _roto and is_equal_approx(lado, CUERNO_ROTO_LADO):
			n_seg = CUERNO_ROTO_QUEDA
		var hp: Vector3 = base
		var th: float = CUERNO_ANG0
		for k in n_seg:
			var f: float = float(k) / float(CUERNO_SEGMENTOS - 1)
			poner.call(hp, Vector3.ONE * lerpf(CUERNO_R0, CUERNO_R1, f), Tono.CUERNO_T)
			if n_seg < CUERNO_SEGMENTOS and k == n_seg - 1:
				poner.call(hp + Vector3(lado * 0.5, 0.0, 0.5), Vector3.ONE * CUERNO_R0 * 0.65, Tono.SOMBRA, [Tono.CUERNO_T])
			# Y SE VAN HACIA DELANTE al subir: de perfil asi se lee la curva (sin esto, dos pinchos en vertical).
			hp += Vector3(lado * cos(th), 0.15 + 0.55 * f, sin(th)).normalized() * CUERNO_PASO
			th += CUERNO_GIRO

	# --- EL HACHA, en su capa: cogida con el puño derecho. QUIETA cuelga junto a la pierna: el puño la agarra cerca
	# de la cabeza, que queda justo debajo, y el mango sigue hacia abajo y algo atras.
	var mano: Dictionary = manos[HACHA_LADO]
	var grip: Vector3 = mano["p"]
	# El MANGO sube desde el puño por detras del antebrazo (va justo por detras del brazo en profundidad, que lo tapa)
	# y la CABEZA cuelga justo debajo del puño, como en la referencia.
	var eje: Vector3 = -Vector3(mano["d"])
	parte.call("hacha", Vector3(HACHA_LADO * HOMBRO.x, HOMBRO.y, 0.0), -0.2)
	var cabeza_h: Vector3 = grip - eje * 4.6
	# Las hojas, HACIA FUERA (a lo ancho del cuerpo) y un poco al frente: de frente se ven de cara, como en la referencia.
	var b: Vector3 = Vector3(HACHA_LADO * 0.9, 0.45, 0.0).normalized()
	b = (b - eje * b.dot(eje)).normalized()
	_labrys(poner, grip, eje, cabeza_h, b)

	# --- ORDEN POR PROFUNDIDAD y lineas de dentro.
	partes.sort_custom(func(p1, p2): return p1["prof"] < p2["prof"] or (p1["prof"] == p2["prof"] and p1["orden"] < p2["orden"]))
	var piezas: Array = []
	for i in partes.size():
		var pt: Dictionary = partes[i]
		var id: int = i + 1
		pt["id"] = id
		for pz in pt["piezas"]:
			pz["grupo"] = 0 if (bool(pz["decal"]) or pt["nombre"] == "suelo") else id
			piezas.append(pz)
	# LAS UNIONES: lo que nace de otra cosa no lleva raya contra ella.
	_unidas.clear()
	var torso_id: int = 0
	var cabeza_id: int = 0
	for pt in partes:
		if pt["nombre"] == "torso":
			torso_id = int(pt["id"])
		elif pt["nombre"] == "cabeza":
			cabeza_id = int(pt["id"])
	for pt in partes:
		match String(pt["nombre"]):
			"pierna", "cola", "cabeza", "faldon":
				_unidas[SpriteLienzo.clave_unidas(int(pt["id"]), torso_id)] = true
			"cuerno":
				_unidas[SpriteLienzo.clave_unidas(int(pt["id"]), cabeza_id)] = true
	return piezas


# LA LABRYS: el mango (madera, con el puño forrado de cuero junto a la mano y en la punta), el collar de hierro y las
# DOS HOJAS en media luna, rellenas de bolas en una rejilla del plano (eje del mango, 'b'); la ultima fila, el FILO.
static func _labrys(poner: Callable, grip: Vector3, eje: Vector3, cabeza_h: Vector3, b: Vector3) -> void:
	var k: float = -4.6
	while k <= MANGO_LARGO:
		var cerca: bool = absf(k) < 1.4 or k > MANGO_LARGO - 1.2
		poner.call(grip + eje * k, Vector3.ONE * MANGO_R, Tono.CUERO_T if cerca else Tono.MADERA_T)
		k += MANGO_PASO
	for sg in [1.0, -1.0]:
		var d: float = 0.9
		while d <= HOJA_ANCHO:
			var f: float = d / HOJA_ANCHO
			# Junto al mango la hoja es estrecha; hacia el filo se abre en media luna.
			var media: float = HOJA_ALTO * (0.35 + 0.65 * f)
			var t: float = -media
			while t <= media + 0.01:
				var borde: float = HOJA_ANCHO * (1.0 - 0.18 * (t / HOJA_ALTO) * (t / HOJA_ALTO))
				if d <= borde:
					var filo: bool = d + HOJA_PASO > borde
					poner.call(cabeza_h + b * (sg * d) + eje * t, Vector3.ONE * HOJA_BOLA,
						Tono.FILO_T if filo else Tono.HIERRO_T)
				t += HOJA_PASO
			d += HOJA_PASO
	poner.call(cabeza_h, Vector3(1.1, 1.1, 1.4), Tono.HIERRO_T)


# La plantilla de un fotograma: que tono le toca a cada celda, con el contorno de fuera y las lineas de dentro.
static func _plantilla(dir: int, pose: Dictionary, esc: float) -> PackedByteArray:
	var lz: Vector2i = _lienzo(esc)
	var plant := PackedByteArray()
	plant.resize(lz.x * lz.y)
	plant.fill(0)
	var grupos := PackedByteArray()
	grupos.resize(lz.x * lz.y)
	grupos.fill(0)
	var piezas: Array = _piezas(dir, pose, esc)
	for p in piezas:
		var pos: Vector2 = p["pos"]
		var r: Vector2 = p["radio"]
		SpriteLienzo.elipse(plant, lz.x, lz.y, pos.x, pos.y, r.x, r.y, int(p["tono"]), float(p["ang"]), p["solo_sobre"],
			float(p["persp"]))
		var g: int = int(p["grupo"])
		if g > 0:
			if bool(p["raiz"]):
				g += SpriteLienzo.RAIZ
			SpriteLienzo.elipse(grupos, lz.x, lz.y, pos.x, pos.y, r.x, r.y, g, float(p["ang"]), [], float(p["persp"]))
	var cj: Rect2i = SpriteLienzo.caja_de_piezas(piezas, lz.x, lz.y)
	SpriteLienzo.contornear(plant, cj, lz.x, lz.y, Tono.BORDE, Tono.VACIO, Tono.SOMBRA_SUELO)
	SpriteLienzo.contornear_grupos(plant, grupos, cj, lz.x, lz.y, Tono.BORDE, Tono.VACIO, Tono.SOMBRA_SUELO, _unidas)
	return plant
