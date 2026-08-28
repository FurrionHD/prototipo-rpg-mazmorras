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
const GEO := {
	"daga":            {"mango": 3.5,  "hoja": 8.0,  "r_mango": 1.5, "r_hoja": 2.1, "guarda": 2.8, "punta": true},
	"espada_corta":    {"mango": 4.0,  "hoja": 14.0, "r_mango": 1.6, "r_hoja": 2.5, "guarda": 4.0, "punta": true},
	"espada_larga":    {"mango": 5.0,  "hoja": 19.0, "r_mango": 1.7, "r_hoja": 2.7, "guarda": 4.6, "punta": true, "pomo": true},
	"estoque":         {"mango": 4.6,  "hoja": 18.0, "r_mango": 1.3, "r_hoja": 1.5, "guarda": 3.0, "punta": true, "copa": true},
	"mandoble":        {"mango": 8.0,  "hoja": 17.0, "r_mango": 2.0, "r_hoja": 3.4, "guarda": 5.4, "punta": true},
	"maza_peq":        {"mango": 9.0,  "hoja": 0.0,  "r_mango": 1.8, "cabeza": 3.8, "cabeza_forma": "bola"},
	"hacha_grande":    {"mango": 17.0, "hoja": 0.0,  "r_mango": 2.1, "cabeza": 6.2, "cabeza_forma": "hacha"},
	"martillo_grande": {"mango": 17.0, "hoja": 0.0,  "r_mango": 2.2, "cabeza": 5.4, "cabeza_forma": "caja"},
	"baston":          {"mango": 22.0, "hoja": 0.0,  "r_mango": 1.7, "cabeza": 2.8, "cabeza_forma": "orbe"},
	"varita":          {"mango": 8.0,  "hoja": 0.0,  "r_mango": 1.2, "cabeza": 2.0, "cabeza_forma": "orbe"},
}

# En qué animaciones dibuja cada capa (nombre BASE, sin dirección).
const _ANIM_ENVAINADA := ["idle", "walk", "correr", "sigilo", "encaje", "muerte", "cadaver", "desenvainar"]
const _ANIM_MANO_1H := ["guardia", "guardia_and", "guardia_cor", "golpe", "golpe_izq"]
const _ANIM_MANO_2H := ["guardia", "guardia_and", "guardia_cor", "golpe_2m"]


# --- Contrato de capa (ver CapaJugador y el registro de JugadorSprites) ---
static func frames(clave: String, esc: float = 1.0) -> SpriteFrames:
	return CapaJugador.frames(clave, pintar.bind(clave), colores(), esc)


static func generar(clave: String, esc: float = 1.0) -> SpriteFrames:
	return CapaJugador.generar(clave, pintar.bind(clave), colores(), esc)


static func colores() -> Array:
	return [
		Color(0, 0, 0, 0),               # VACIO
		Color(0, 0, 0, 0.20),            # SOMBRA_SUELO
		Color(0.09, 0.09, 0.11),        # BORDE
		Color(0.26, 0.18, 0.11),        # MANGO_S   cuero/madera oscura
		Color(0.42, 0.29, 0.17),        # MANGO
		Color(0.40, 0.44, 0.50),        # METAL_S
		Color(0.66, 0.70, 0.77),        # METAL
		Color(0.88, 0.92, 0.98),        # METAL_L
	]


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
	return out


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
	if estado != "mano":
		return _ANIM_ENVAINADA.has(anim)
	return (_ANIM_MANO_2H if tipo in DOS_MANOS else _ANIM_MANO_1H).has(anim)


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

	var mano: int = int(info["mano"])
	if estado == "mano" and tipo in DOS_MANOS:
		mano = 2

	var ag: Dictionary = PoseJugador.agarre_arma(esq, mano, estado)
	var grip: Vector3 = ag["empunadura"]
	var eje: Vector3 = ag["eje"]

	# DESENVAINAR: la capa envainada viaja de la vaina a la mano. 'sacando' (0..1) lo publica
	# _pose_desenvainar. La de mano no se pinta durante 'desenvainar' (lo hace esta), así no hay
	# doble dibujo.
	var sac: float = float((esq.get("pose", {}) as Dictionary).get("sacando", -1.0))
	if sac >= 0.0 and estado != "mano":
		var m2: int = 2 if tipo in DOS_MANOS else 0
		var agm: Dictionary = PoseJugador.agarre_arma(esq, m2, "mano")
		grip = grip.lerp(agm["empunadura"], sac)
		eje = eje.lerp(agm["eje"], sac)
		if eje.length() > 0.01:
			eje = eje.normalized()

	_dibujar(piezas, esq, grip, eje, g)


static func _dibujar(piezas: Array, esq: Dictionary, grip: Vector3, eje: Vector3,
		g: Dictionary) -> void:
	var r_mango: float = float(g.get("r_mango", 1.2))
	var mango_fin: Vector3 = grip + eje * float(g.get("mango", 4.0))
	# El mango / astil.
	PoseJugador.cadena(piezas, esq, grip, mango_fin, r_mango, r_mango, Tono.MANGO)

	# La guarda: una barra corta cruzada, centrada en el final del mango (pasa por él -> queda
	# pegada al astil, no suelta).
	var guarda: float = float(g.get("guarda", 0.0))
	if guarda > 0.0:
		var perp: Vector3 = eje.cross(Vector3(0.0, 0.0, 1.0))
		if perp.length() < 0.01:
			perp = Vector3(1.0, 0.0, 0.0)
		perp = perp.normalized() * guarda * 0.5
		PoseJugador.cadena(piezas, esq, mango_fin - perp, mango_fin + perp,
			r_mango * 0.9, r_mango * 0.9, Tono.METAL)

	# La hoja.
	var hoja: float = float(g.get("hoja", 0.0))
	if hoja > 0.0:
		var r_hoja: float = float(g.get("r_hoja", 1.8))
		var r_punta: float = r_hoja * (0.25 if g.get("punta", false) else 1.0)
		var hoja_fin: Vector3 = mango_fin + eje * hoja
		PoseJugador.cadena(piezas, esq, mango_fin, hoja_fin, r_hoja, r_punta, Tono.METAL)
		# El filo: un realce fino por el centro, solo sobre el acero (no se sale de la hoja).
		PoseJugador.cadena(piezas, esq, mango_fin, hoja_fin,
			r_hoja * 0.45, r_punta * 0.45, Tono.METAL_L, {"solo_sobre": [Tono.METAL]})
		if g.get("pomo", false):
			PoseJugador.poner(piezas, esq, grip - eje * (r_mango * 0.8),
				Vector3(r_mango * 1.3, r_mango * 1.3, r_mango * 1.3), Tono.METAL)

	# La cabeza (romas).
	var cabeza: float = float(g.get("cabeza", 0.0))
	if cabeza > 0.0:
		var forma: String = String(g.get("cabeza_forma", "bola"))
		var centro: Vector3 = mango_fin + eje * (cabeza * 0.25)
		match forma:
			"hacha":
				# Media luna: un bulto ancho desplazado a un lado del astil.
				var lado: Vector3 = eje.cross(Vector3(0.0, 0.0, 1.0))
				if lado.length() < 0.01:
					lado = Vector3(1.0, 0.0, 0.0)
				lado = lado.normalized() * cabeza * 0.55
				PoseJugador.poner(piezas, esq, centro + lado,
					Vector3(cabeza * 0.75, cabeza * 0.5, cabeza * 0.95), Tono.METAL)
			"caja":
				PoseJugador.poner(piezas, esq, centro,
					Vector3(cabeza, cabeza * 0.8, cabeza * 0.8), Tono.METAL)
			"orbe":
				PoseJugador.poner(piezas, esq, mango_fin,
					Vector3(cabeza, cabeza, cabeza), Tono.METAL_L)
			_:
				PoseJugador.poner(piezas, esq, centro,
					Vector3(cabeza, cabeza, cabeza), Tono.METAL)
