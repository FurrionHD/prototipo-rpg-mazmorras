# ============================================================
#  arma_sprites.gd  (class_name ArmaSprites)
#  LA CAPA DEL ARMA: dibuja la espada / hacha / bastón que lleva el personaje, colgada del punto
#  que le da el esqueleto (la mano cuando está empuñada, la cadera o la espalda cuando envainada).
#
#  Es hermana de RopaSprites / PeloSprites y comparte todo el andamiaje (CapaJugador): lo único
#  propio es QUE forma tiene cada arma y DÓNDE se agarra. El "dónde" no se calcula aquí -- lo dice
#  PoseJugador.agarre_arma, que es el único sitio con geometría de colocación de arma, igual que
#  una hombrera se cuelga de PoseJugador.P_HOMBRO y no de una cuenta suya.
#
#  UNA CAPA POR (arma, sitio, mano): "arma_daga_mano_der", "arma_hacha_grande_espalda"... El string
#  lleva dentro tipo + estado + mano y se parsea en 'pintar', así CapaJugador y el horno la tratan
#  como cualquier otra capa (igual que "pelo_largo_atras").
#
#  QUÉ DIBUJA CADA CAPA SEGÚN LA ANIMACIÓN: la envainada (cadera/espalda) sale en idle/walk/correr/
#  sigilo/encaje/muerte/cadaver y en 'desenvainar' (donde viaja de la vaina a la mano); la de mano
#  sale en guardia*/golpe*. En las demás no dibuja nada -- un fotograma vacío no cuesta casi nada.
#
#  NO SE TIÑE: un arma no es del color de tu camisa. La paleta lleva colores de verdad (acero y
#  cuero) y va con "tinte": false en el registro.
# ============================================================

extends RefCounted
class_name ArmaSprites

# Los tonos, a partir del primer índice libre (los tres de abajo son fijos, ver CapaJugador).
enum Tono {
	VACIO = 0, SOMBRA_SUELO = 1, BORDE = 2,
	MANGO_S,   # el mango/astil en penumbra
	MANGO,     # el mango/astil (cuero, madera)
	METAL_S,   # el acero en penumbra
	METAL,     # el acero
	METAL_L,   # el filo / el brillo
}

# Nombre de cada WeaponData.Tipo (para las claves de capa). El índice es el valor del enum.
const TIPO_NOMBRE := [
	"punos", "daga", "espada_corta", "espada_larga", "mandoble",
	"estoque", "hacha_grande", "maza_peq", "martillo_grande", "baston",
]
# La varita (WandData) no es un WeaponData.Tipo, pero se dibuja igual: va aparte.
const EXTRA := ["varita"]

# Las de dos manos: se empuñan con las dos a la vez y se envainan a la ESPALDA.
const DOS_MANOS := ["mandoble", "hacha_grande", "martillo_grande", "baston"]

# GEOMETRÍA por tipo, en unidades de mundo (PoseJugador.ALTO_MUNDO = 60). 'mango' es el trozo que
# va del puño a la guarda, 'hoja' de la guarda a la punta. Las romas (maza/martillo/hacha) no
# tienen hoja: llevan 'cabeza'. Ver PoseJugador.agarre_arma para el eje.
#
# LA HOJA NO ES UN CONO. Iba de 'r_hoja' en la guarda a la punta en una sola rampa, asi que toda
# espada era un triangulo largo -- en el retrato de la vitrina se leia como una hoja de arbol. Ahora
# 'cuerpo' es la fraccion de la hoja que mantiene el ancho (casi) entero, y solo el resto se afila:
# la silueta de una espada de verdad.
#
# 'pomo' y 'copa' SI SE DIBUJAN: la copa del estoque estaba en esta tabla desde el principio y el
# pintor no la leia nunca.
const GEO := {
	"daga":            {"mango": 3.5,  "hoja": 8.0,  "r_mango": 1.5, "r_hoja": 2.1, "guarda": 3.4, "punta": true, "cuerpo": 0.55, "pomo": true},
	"espada_corta":    {"mango": 4.0,  "hoja": 14.0, "r_mango": 1.6, "r_hoja": 2.4, "guarda": 5.0, "punta": true, "cuerpo": 0.70, "pomo": true},
	"espada_larga":    {"mango": 5.0,  "hoja": 19.0, "r_mango": 1.7, "r_hoja": 2.6, "guarda": 6.0, "punta": true, "cuerpo": 0.76, "pomo": true},
	"estoque":         {"mango": 4.6,  "hoja": 18.0, "r_mango": 1.3, "r_hoja": 1.4, "guarda": 3.0, "punta": true, "cuerpo": 0.80, "pomo": true, "copa": true},
	"mandoble":        {"mango": 8.0,  "hoja": 17.0, "r_mango": 2.0, "r_hoja": 3.3, "guarda": 7.0, "punta": true, "cuerpo": 0.74, "pomo": true},
	"maza_peq":        {"mango": 9.0,  "hoja": 0.0,  "r_mango": 1.8, "cabeza": 3.8, "cabeza_forma": "bola"},
	"hacha_grande":    {"mango": 17.0, "hoja": 0.0,  "r_mango": 2.1, "cabeza": 6.2, "cabeza_forma": "hacha"},
	"martillo_grande": {"mango": 17.0, "hoja": 0.0,  "r_mango": 2.2, "cabeza": 5.4, "cabeza_forma": "caja"},
	"baston":          {"mango": 22.0, "hoja": 0.0,  "r_mango": 1.7, "cabeza": 2.8, "cabeza_forma": "orbe"},
	"varita":          {"mango": 8.0,  "hoja": 0.0,  "r_mango": 1.2, "cabeza": 2.0, "cabeza_forma": "orbe"},
	# LAS HERRAMIENTAS DE RECOLECTAR (ver HERRAMIENTA_ANIM). El pico: astil largo y la cabeza CRUZADA
	# en el plano del golpe, con las dos puntas curvadas hacia el mango.
	"pico":            {"mango": 15.0, "hoja": 0.0,  "r_mango": 1.5, "cabeza": 6.5, "cabeza_forma": "pico"},
	# El hacha de LEÑADOR: la misma forma de hacha que la de guerra, con el astil algo mas corto y la
	# cabeza mas estrecha -- la de guerra es un arma y esta una herramienta.
	"hacha_talar":     {"mango": 14.0, "hoja": 0.0,  "r_mango": 1.5, "cabeza": 5.0, "cabeza_forma": "hacha"},
	# La hoz: mango corto y la hoja en MEDIA LUNA que sale de su punta (ver la forma "hoz").
	"hoz":             {"mango": 5.5,  "hoja": 0.0,  "r_mango": 1.3, "cabeza": 5.2, "cabeza_forma": "hoz"},
	# El cuchillo de desollar: una hoja corta y ancha con guarda pequeña, mas gruesa que la de la daga
	# para que a ras del cadaver no se pierda.
	"cuchillo":        {"mango": 3.5,  "hoja": 7.0,  "r_mango": 1.4, "r_hoja": 1.9, "guarda": 2.4, "punta": true, "cuerpo": 0.5, "pomo": true},
}

# LAS HERRAMIENTAS en la mano: cada una sale SOLO en la animacion de su faena (ver PoseJugador.FAENAS),
# y no se monta en el muñeco mas que mientras dura (ver JugadorSprites.capa_herramienta). Las de dos
# manos se agarran con las dos, como un hacha grande.
const HERRAMIENTA_ANIM := {"pico": "picar", "hacha_talar": "talar", "hoz": "segar",
	"cuchillo": "extraer"}
const HERRAMIENTAS_2M := ["pico", "hacha_talar"]

# En qué animaciones dibuja cada capa (nombre BASE, sin dirección). Las FAENAS van aparte (ver
# _dibuja_en): mientras picas, la espada sigue colgada de la cadera.
const _ANIM_ENVAINADA := ["idle", "walk", "correr", "sigilo", "encaje", "muerte", "cadaver", "desenvainar"]
const _ANIM_MANO_1H := ["guardia", "guardia_and", "guardia_cor", "golpe", "golpe_izq"]
const _ANIM_MANO_2H := ["guardia", "guardia_and", "guardia_cor", "golpe_2m"]


# --- Contrato de capa (ver CapaJugador y el registro de JugadorSprites) ---
static func frames(clave: String, esc: float = 1.0) -> SpriteFrames:
	return CapaJugador.frames(clave, pintar.bind(clave), colores(), esc)


static func generar(clave: String, esc: float = 1.0) -> SpriteFrames:
	return CapaJugador.generar(clave, pintar.bind(clave), colores(), esc)


static func colores() -> Array:
	return CapaJugador.rampa_indices(ROLES.size())


# QUE PAPEL HACE CADA TONO. El arma se hornea con la rampa de indices y el color lo pone PaletaEquipo
# en el juego, segun el tier y la mejora del arma que lleves.
#
# LA HOJA Y EL MANGO VAN POR SEPARADO, y es la gracia de hacerlo por papeles: la hoja sigue al METAL
# de su tier (cobre, hierro, acero) y el mango al CUERO, que tiene su propia escala. Una espada de
# tier 2 muy mejorada sale de hierro negro con el mango de cuero placado -- que es como se forja de
# verdad, con dos materiales distintos.
#
# El indice de este array ES el numero de tono, asi que su orden sigue al del enum Tono.
const ROLES := [
	PaletaEquipo.Rol.BORDE,        # 0 VACIO
	PaletaEquipo.Rol.SOMBRA,       # 1 SOMBRA_SUELO
	PaletaEquipo.Rol.BORDE,        # 2 BORDE
	PaletaEquipo.Rol.CUERO_S,      # 3 MANGO_S
	PaletaEquipo.Rol.CUERO,        # 4 MANGO
	PaletaEquipo.Rol.MATERIAL_S,   # 5 METAL_S
	PaletaEquipo.Rol.MATERIAL,     # 6 METAL
	PaletaEquipo.Rol.MATERIAL_L,   # 7 METAL_L
]

const CLAVE_ROLES := "arma"


# LA FAMILIA DEL MATERIAL de un arma. Un baston y una varita son de MADERA -- su "hoja" es el asta --,
# el resto son de metal. Sin esto, un baston de tier 3 saldria de acero blanco.
static func familia_de(tn: String) -> String:
	return PaletaEquipo.LEÑO if tn in ["baston", "varita"] else PaletaEquipo.METAL


# ============================================================
#  QUÉ CLAVES EXISTEN
# ============================================================
# Las capas que hay que hornear para un tipo de arma. Encapsula las reglas: una de una mano puede
# ir de principal o de secundaria y en cualquier mano (4 claves); la espada larga nunca va en dual
# (off_hand_solo_escudo -> solo mano/cadera derecha); las de dos manos van a la espalda; la varita
# solo cuelga de la cadera izquierda (no se desenvaina en el mapa).
static func claves_de(tn: String) -> Array:
	if tn == "punos":
		return []
	if tn == "varita":
		return ["arma_varita_cadera_izq"]
	if tn in DOS_MANOS:
		return ["arma_%s_mano_der" % tn, "arma_%s_espalda" % tn]
	if tn == "espada_larga":
		return ["arma_espada_larga_mano_der", "arma_espada_larga_cadera_der"]
	return ["arma_%s_mano_der" % tn, "arma_%s_mano_izq" % tn,
		"arma_%s_cadera_der" % tn, "arma_%s_cadera_izq" % tn]


# Todas las capas de arma que existen, para el horno y el registro.
static func todas_las_claves() -> Array:
	var out: Array = []
	for tn in TIPO_NOMBRE:
		out.append_array(claves_de(tn))
	for tn in EXTRA:
		out.append_array(claves_de(tn))
	out.append_array(claves_herramientas())
	return out


# Las capas de las herramientas: UNA por herramienta, siempre en la mano derecha (las de dos manos
# se agarran por el punto medio igualmente, ver pintar).
static func claves_herramientas() -> Array:
	var out: Array = []
	for tn in HERRAMIENTA_ANIM:
		out.append(clave_herramienta(tn))
	return out


static func clave_herramienta(tn: String) -> String:
	return "arma_%s_mano_der" % tn


# ============================================================
#  EL PARSEO DE LA CLAVE
# ============================================================
static func _parse(clave: String) -> Dictionary:
	var s: String = clave.trim_prefix("arma_")
	var estado := "mano"
	var mano := 0
	if s.ends_with("_espalda"):
		estado = "espalda"
		s = s.trim_suffix("_espalda")
	elif s.ends_with("_mano_der"):
		estado = "mano"; mano = 0; s = s.trim_suffix("_mano_der")
	elif s.ends_with("_mano_izq"):
		estado = "mano"; mano = 1; s = s.trim_suffix("_mano_izq")
	elif s.ends_with("_cadera_der"):
		estado = "cadera"; mano = 0; s = s.trim_suffix("_cadera_der")
	elif s.ends_with("_cadera_izq"):
		estado = "cadera"; mano = 1; s = s.trim_suffix("_cadera_izq")
	return {"tipo": s, "estado": estado, "mano": mano}


static func _dibuja_en(anim: String, tipo: String, estado: String) -> bool:
	if HERRAMIENTA_ANIM.has(tipo):
		return anim == String(HERRAMIENTA_ANIM[tipo])
	if estado != "mano":
		return _ANIM_ENVAINADA.has(anim) or PoseJugador.FAENAS.has(anim)
	return (_ANIM_MANO_2H if tipo in DOS_MANOS else _ANIM_MANO_1H).has(anim)


# Direcciones en las que se ve el arma ENVAINADA, por sitio. En el resto el cuerpo la tapa entera.
# dir: 0=S 1=SE 2=E 3=NE 4=N 5=NW 6=W 7=SW (SpriteLienzo.dir8).
const _DIRS_ESPALDA := [3, 4, 5]        # de espaldas
const _DIRS_CADERA_DER := [0, 1, 2]     # el costado derecho (-X) mira a la cámara
const _DIRS_CADERA_IZQ := [0, 6, 7]     # el costado izquierdo (+X) mira a la cámara

static func _visible_envainada(estado: String, mano: int, dir: int) -> bool:
	if estado == "espalda":
		return _DIRS_ESPALDA.has(dir)
	return (_DIRS_CADERA_IZQ if mano == 1 else _DIRS_CADERA_DER).has(dir)


# ============================================================
#  EL PINTOR
# ============================================================
static func pintar(esq: Dictionary, piezas: Array, clave: String) -> void:
	var info: Dictionary = _parse(clave)
	var tipo: String = info["tipo"]
	var estado: String = info["estado"]
	var g: Dictionary = GEO.get(tipo, {})
	if g.is_empty():
		return
	var anim: String = String(esq.get("anim", ""))
	if not _dibuja_en(anim, tipo, estado):
		return

	# 'sacando' (0..1): durante el gesto de desenvainar la capa envainada viaja de la vaina a la
	# mano. -1 = no se está desenvainando.
	var sac: float = float((esq.get("pose", {}) as Dictionary).get("sacando", -1.0))

	# ENVAINADA: solo se dibuja en las direcciones donde ESE lado del cuerpo mira a la cámara. En el
	# resto no vale con mandarla "detrás" -- una hoja larga asoma por los lados de la silueta --, así
	# que ni se dibuja. Mismo criterio que MunecoJugador.CARA_DIRS con la cara. Durante 'desenvainar'
	# se dibuja siempre: el arma está viajando a la mano.
	if estado != "mano" and sac < 0.0 \
			and not _visible_envainada(estado, int(info["mano"]), int(esq.get("dir", 0))):
		return

	var mano: int = int(info["mano"])
	if estado == "mano" and (tipo in DOS_MANOS or tipo in HERRAMIENTAS_2M):
		mano = 2

	var ag: Dictionary = PoseJugador.agarre_arma(esq, mano, estado)
	var grip: Vector3 = ag["empunadura"]
	var eje: Vector3 = ag["eje"]

	if sac >= 0.0 and estado != "mano":
		var m2: int = 2 if tipo in DOS_MANOS else 0
		var agm: Dictionary = PoseJugador.agarre_arma(esq, m2, "mano")
		grip = grip.lerp(agm["empunadura"], sac)
		eje = eje.lerp(agm["eje"], sac)
		if eje.length() > 0.01:
			eje = eje.normalized()

	# En la mano gira ENTERA con la torsion del tronco, a la altura de las manos (ver
	# PoseJugador.proyectar, 'z_torsion').
	_dibujar(piezas, esq, grip, eje, g, Vector3.ZERO,
		{"z_torsion": grip.z} if estado == "mano" else {})


# ============================================================
#  EL RETRATO: el arma SUELTA, recta y en diagonal
# ============================================================
# Para la vitrina y las celdas del menu (ver scripts/ui/retrato_pieza.gd). No sale de ninguna pose
# del muñeco: en todas las de guardia el arma cuelga hacia delante, o sea hacia abajo y escorzada en
# pantalla, y retratada asi una espada era un palito corto. Aqui se dibuja entera, con la empuñadura
# abajo a la izquierda y la punta arriba a la derecha, como se enseña un arma suelta.
#
# Con 'gira': false (el giro de la direccion no pinta nada: el arma no la lleva nadie) y el EJE
# COMPENSADO: la camara aplasta la altura (SIN_CAM), asi que para que en pantalla salga a 45 grados
# y con su largo de verdad, la componente z se estira lo que la camara va a encoger.
const RETRATO_DIR := Vector2(0.7071, 0.7071)   # en pantalla: x a la derecha, y hacia ARRIBA
const RETRATO_ALTURA := 30.0                  # a que altura del lienzo se centra (media figura)

static func pintar_retrato(esq: Dictionary, piezas: Array, tipo: String) -> void:
	var g: Dictionary = GEO.get(tipo, {})
	if g.is_empty():
		return
	var eje := Vector3(RETRATO_DIR.x, 0.0, RETRATO_DIR.y / SpriteLienzo.SIN_CAM)
	var perp := Vector2(-RETRATO_DIR.y, RETRATO_DIR.x)
	var lado := Vector3(perp.x, 0.0, perp.y / SpriteLienzo.SIN_CAM)
	# CENTRADA: se mide lo largo que es entera (del pomo a la punta o a la cabeza) y se coloca la
	# empuñadura media arma por debajo del centro. Asi un baston y una daga caen en el mismo sitio.
	var largo: float = float(g.get("mango", 4.0)) + float(g.get("hoja", 0.0)) \
		+ float(g.get("cabeza", 0.0))
	var grip: Vector3 = Vector3(0.0, 0.0, RETRATO_ALTURA) - eje * (largo * 0.5)
	_dibujar(piezas, esq, grip, eje, g, lado, {"gira": false})


# 'lado' es hacia donde se cruzan la guarda y la cabeza del hacha o del martillo. Vacio = el de
# siempre (perpendicular al eje en horizontal), que es lo que quiere el muñeco; el retrato pasa el
# suyo, perpendicular EN PANTALLA. 'op' va a todas las piezas (el retrato manda 'gira': false).
static func _dibujar(piezas: Array, esq: Dictionary, grip: Vector3, eje: Vector3,
		g: Dictionary, lado: Vector3 = Vector3.ZERO, op: Dictionary = {}) -> void:
	if lado == Vector3.ZERO:
		lado = eje.cross(Vector3(0.0, 0.0, 1.0))
		if lado.length() < 0.01:
			lado = Vector3(1.0, 0.0, 0.0)
		lado = lado.normalized()
	var r_mango: float = float(g.get("r_mango", 1.2))
	var mango_fin: Vector3 = grip + eje * float(g.get("mango", 4.0))
	# El mango / astil, con su lado en sombra: un solo tono se leia como un palo pintado.
	PoseJugador.cadena(piezas, esq, grip, mango_fin, r_mango, r_mango, Tono.MANGO, op)
	PoseJugador.cadena(piezas, esq, grip - lado * (r_mango * 0.45), mango_fin - lado * (r_mango * 0.45),
		r_mango * 0.55, r_mango * 0.55, Tono.MANGO_S, op.merged({"solo_sobre": [Tono.MANGO]}))

	# EL POMO: el remate del puño. Es lo que cierra la empuñadura; sin el, el mango acababa en seco.
	if g.get("pomo", false):
		PoseJugador.poner(piezas, esq, grip - eje * (r_mango * 0.7),
			Vector3.ONE * (r_mango * 1.25), Tono.METAL, op)

	# La guarda: una barra cruzada, centrada en el final del mango (pasa por el -> queda pegada al
	# astil, no suelta), con los extremos engordados para que se lea como guarda y no como una raya.
	var guarda: float = float(g.get("guarda", 0.0))
	if guarda > 0.0:
		var pg: Vector3 = lado * guarda * 0.5
		PoseJugador.cadena(piezas, esq, mango_fin - pg, mango_fin + pg,
			r_mango * 0.85, r_mango * 0.85, Tono.METAL, op)
		for s in [-1.0, 1.0]:
			PoseJugador.poner(piezas, esq, mango_fin + pg * s, Vector3.ONE * (r_mango * 1.05),
				Tono.METAL, op)
	# LA COPA del estoque: la cazoleta que le tapa la mano. Es lo que lo distingue de una espada fina.
	if g.get("copa", false):
		PoseJugador.poner(piezas, esq, mango_fin - eje * (r_mango * 0.6),
			Vector3.ONE * (r_mango * 2.0), Tono.METAL, op)

	# LA HOJA: el CUERPO mantiene el ancho y solo la punta se afila (ver GEO).
	var hoja: float = float(g.get("hoja", 0.0))
	if hoja > 0.0:
		var r_hoja: float = float(g.get("r_hoja", 1.8))
		var r_punta: float = r_hoja * (0.2 if g.get("punta", false) else 1.0)
		var cuerpo: float = clampf(float(g.get("cuerpo", 0.0)), 0.0, 0.95)
		var hoja_fin: Vector3 = mango_fin + eje * hoja
		var quiebre: Vector3 = mango_fin + eje * (hoja * cuerpo)
		var r_quiebre: float = r_hoja * 0.9
		if cuerpo > 0.0:
			PoseJugador.cadena(piezas, esq, mango_fin, quiebre, r_hoja, r_quiebre, Tono.METAL, op)
			PoseJugador.cadena(piezas, esq, quiebre, hoja_fin, r_quiebre, r_punta, Tono.METAL, op)
		else:
			PoseJugador.cadena(piezas, esq, mango_fin, hoja_fin, r_hoja, r_punta, Tono.METAL, op)
		# EL LADO EN SOMBRA y EL FILO en luz, los dos solo sobre el acero (no se salen de la hoja). Con
		# un tono liso la hoja era plana; con la sombra a un lado y el brillo al otro, tiene arista.
		var sombra: Dictionary = op.merged({"solo_sobre": [Tono.METAL]})
		PoseJugador.cadena(piezas, esq, mango_fin - lado * (r_hoja * 0.5),
			hoja_fin - lado * (r_punta * 0.5), r_hoja * 0.5, r_punta * 0.5, Tono.METAL_S, sombra)
		PoseJugador.cadena(piezas, esq, mango_fin + lado * (r_hoja * 0.15),
			hoja_fin, r_hoja * 0.32, r_punta * 0.4, Tono.METAL_L, sombra)

	# La cabeza (romas).
	var cabeza: float = float(g.get("cabeza", 0.0))
	if cabeza > 0.0:
		var forma: String = String(g.get("cabeza_forma", "bola"))
		var centro: Vector3 = mango_fin + eje * (cabeza * 0.25)
		match forma:
			"hacha":
				# EL FILO en media luna a un lado del astil, con su borde en brillo, y un PICO corto al
				# otro: una sola elipse de lado se leia como una bola pegada al palo.
				# La hoja va ALARGADA A LO LARGO DEL ASTIL (una cadena paralela al mango, apartada a un
				# lado), no redonda: una bola grande de lado era un sonajero, por mucho pico que llevara.
				var hc: Vector3 = centro + lado * (cabeza * 0.7)
				var alto: Vector3 = eje * (cabeza * 0.8)
				PoseJugador.cadena(piezas, esq, hc - alto, hc + alto, cabeza * 0.42, cabeza * 0.42,
					Tono.METAL, op)
				PoseJugador.cadena(piezas, esq, centro, hc, cabeza * 0.34, cabeza * 0.4, Tono.METAL, op)
				# El FILO en brillo por el borde de fuera.
				PoseJugador.cadena(piezas, esq, hc - alto + lado * (cabeza * 0.3),
					hc + alto + lado * (cabeza * 0.3), cabeza * 0.2, cabeza * 0.2, Tono.METAL_L,
					op.merged({"solo_sobre": [Tono.METAL]}))
				# El PICO de atras.
				PoseJugador.cadena(piezas, esq, centro, centro - lado * (cabeza * 0.75),
					cabeza * 0.3, cabeza * 0.1, Tono.METAL, op)
			"caja":
				# LA CABEZA CRUZADA AL MANGO, como un martillo: una barra gruesa a lo ancho. Centrada en
				# el mango se leia como un bulto al final de un palo (una maza).
				var pc: Vector3 = lado * (cabeza * 0.75)
				PoseJugador.cadena(piezas, esq, centro - pc, centro + pc,
					cabeza * 0.62, cabeza * 0.62, Tono.METAL, op)
				PoseJugador.cadena(piezas, esq, centro - pc + eje * (cabeza * 0.2),
					centro + pc + eje * (cabeza * 0.2), cabeza * 0.25, cabeza * 0.25, Tono.METAL_L,
					op.merged({"solo_sobre": [Tono.METAL]}))
			"orbe":
				PoseJugador.poner(piezas, esq, mango_fin,
					Vector3(cabeza, cabeza, cabeza), Tono.METAL_L, op)
			"hoz":
				# LA MEDIA LUNA: arranca en la punta del mango y da la vuelta en el plano del tajo
				# (lado/eje), abriendose hacia un costado y volviendo hacia delante como un gancho. Se
				# afila hacia la punta y lleva el filo en luz por dentro, que es por donde corta.
				var rr: float = cabeza
				var c0: Vector3 = mango_fin + lado * rr
				# GRUESA EN LA RAIZ (0,34 del radio): con la mitad, a tamaño de juego era una raya de un
				# pixel y la hoz no se veia.
				var n: int = 9
				var prev: Vector3 = mango_fin
				for k in range(1, n + 1):
					var a: float = PI * 1.15 * float(k) / float(n)
					var pt: Vector3 = c0 - lado * (rr * cos(a)) + eje * (rr * 0.9 * sin(a))
					var f0: float = float(k - 1) / float(n)
					var f: float = float(k) / float(n)
					PoseJugador.cadena(piezas, esq, prev, pt, lerpf(0.34, 0.08, f0) * rr,
						lerpf(0.34, 0.08, f) * rr, Tono.METAL, op)
					if k < n:
						PoseJugador.cadena(piezas, esq, prev, pt, rr * 0.09, rr * 0.07, Tono.METAL_L,
							op.merged({"solo_sobre": [Tono.METAL]}))
					prev = pt
			"pico":
				# LA CABEZA DEL PICO VA EN EL PLANO DEL GOLPE, no cruzada a lo ancho como el martillo:
				# es lo que la hace un pico. 'plano' es el eje girado un cuarto de vuelta sobre la linea de
				# los hombros (X), o sea perpendicular al mango y dentro del arco que describe. Con 'lado'
				# (el de las demas) la cabeza quedaba de canto a la camara mirando al este y se veia un
				# martillo visto de frente.
				var plano := Vector3(0.0, -eje.z, eje.y)
				plano = plano.normalized() if plano.length() > 0.01 else lado
				var cen: Vector3 = mango_fin - eje * (cabeza * 0.12)
				# El ojo donde entra el astil: un bulto que las une, o las dos puntas salen sueltas.
				PoseJugador.poner(piezas, esq, cen, Vector3.ONE * (cabeza * 0.34), Tono.METAL, op)
				for s in [-1.0, 1.0]:
					# Cada punta sale recta y se CURVA hacia el mango al final: con dos tramos rectos
					# en linea era una T, y un pico sin curva se lee como una cruz.
					var medio: Vector3 = cen + plano * (s * cabeza * 0.55) - eje * (cabeza * 0.10)
					var punta: Vector3 = cen + plano * (s * cabeza) - eje * (cabeza * 0.38)
					PoseJugador.cadena(piezas, esq, cen, medio, cabeza * 0.28, cabeza * 0.22, Tono.METAL, op)
					PoseJugador.cadena(piezas, esq, medio, punta, cabeza * 0.22, cabeza * 0.07, Tono.METAL, op)
					# El brillo por el lomo (el lado de fuera de la curva).
					PoseJugador.cadena(piezas, esq, cen + eje * (cabeza * 0.08),
						medio + eje * (cabeza * 0.06), cabeza * 0.10, cabeza * 0.08, Tono.METAL_L,
						op.merged({"solo_sobre": [Tono.METAL]}))
			_:
				# LA MAZA, con pinchos: la bola sola era un sonajero.
				for k in 4:
					var a: float = TAU * float(k) / 4.0 + PI * 0.25
					var d: Vector3 = lado * cos(a) + eje * sin(a)
					PoseJugador.cadena(piezas, esq, centro, centro + d * (cabeza * 1.35),
						cabeza * 0.4, cabeza * 0.12, Tono.METAL, op)
				PoseJugador.poner(piezas, esq, centro, Vector3(cabeza, cabeza, cabeza), Tono.METAL, op)
				PoseJugador.poner(piezas, esq, centro + (lado + eje) * (cabeza * 0.25),
					Vector3.ONE * (cabeza * 0.4), Tono.METAL_L, op.merged({"solo_sobre": [Tono.METAL]}))
