# ============================================================
#  arco_sprites.gd  (class_name ArcoSprites)
#  EL DIBUJO DEL ARCO Y LA BALLESTA (03/10/2026). Lo llama ArmaSprites.pintar: es su misma capa, con los
#  mismos tonos, pero su forma no es "un palo con algo en la punta" como las demas -- llevan CUERDA, que va
#  de punta a punta y se tensa hasta la mano que tira, y la flecha o el virote puestos.
#
#  QUE LES DICE LA POSE (claves de PoseDistancia; si faltan, valores de reposo):
#    arco_f    hacia donde apunta la flecha (sistema del cuerpo: x = su izquierda, y = al frente, z = arriba)
#    arco_e    el eje de las palas (de la de abajo a la de arriba), perpendicular a arco_f
#    tensa     0..1, cuanto se tira de la cuerda (0 = armada en reposo; 1 = hasta la cara)
#    flecha    1 = hay una flecha puesta en la cuerda
#    ball_f    hacia donde apunta la ballesta (la culata va detras de la mano derecha)
#    ball_cuerda  0..1: 1 = la cuerda enganchada en la nuez (armada), 0 = suelta contra el arco (disparada)
#    virote    1 = hay un virote puesto
#  El arco se agarra con la IZQUIERDA (la empuñadura en el centro de las palas) y la cuerda la tira la
#  DERECHA; la ballesta, con la DERECHA en el gatillo y la izquierda debajo, sujetando.
#
#  A LA ESPALDA: el arco cruzado de la cadera derecha al hombro izquierdo, y el CARCAJ al reves, con la boca
#  sobre el hombro derecho y las plumas ROJAS asomando (las de sus disparos, DistanciaAire.PLUMA). El carcaj
#  se ve SIEMPRE que se vea la espalda, tambien con el arco en la mano. La ballesta va a la espalda sola.
# ============================================================
extends RefCounted
class_name ArcoSprites

const T := ArmaSprites.Tono

# EL ARCO: media altura de las palas (de la empuñadura a cada punta) y cuanto se curvan. El personaje mide
# 60 (PoseJugador.ALTO_MUNDO): un arco de 36 son dos tercios largos de el, un arco corto de los de cazar.
const ARCO_MEDIO := 18.0
const ARCO_CURVA := 4.6        # lo que retroceden las puntas hacia el arquero, armado y sin tensar
const ARCO_CURVA_TENSO := 7.5  # y tensado del todo
const ARCO_RECURVA := 1.4      # el remate de las puntas, que vuelve hacia delante
const ARCO_R := 1.9            # grosor de la pala junto a la empuñadura (se afina hacia la punta). Con 1,15 era todo borde: un palo negro
const CUERDA_R := 0.5
const FLECHA_LARGO := 25.0
const ARCO_TENSO := 13.0       # hasta donde va la cuerda tensada del todo, desde la empuñadura

# LA BALLESTA
const CULATA_ATRAS := 7.5      # de la mano del gatillo hacia la culata
const CULATA_DELANTE := 12.5   # y hacia la punta
const PALAS_BALL := 8.5        # media envergadura del arco de la ballesta
const NUEZ := 2.0              # donde se engancha la cuerda armada, delante de la mano
const VIROTE_LARGO := 13.0


static func es_suyo(tipo: String) -> bool:
	return tipo == "arco" or tipo == "ballesta"


# ============================================================
#  EN LA MANO
# ============================================================
static func pintar_mano(piezas: Array, esq: Dictionary, tipo: String) -> void:
	var p: Dictionary = esq["puntos"]
	var po: Dictionary = esq.get("pose", {})
	if tipo == "arco":
		var g: Vector3 = p[PoseJugador.P_EMPUNADURA_IZQ]
		var f: Vector3 = _vec(po, "arco_f", Vector3(0.0, 1.0, 0.0))
		var e: Vector3 = _vec(po, "arco_e", Vector3(0.0, 0.0, 1.0))
		var tensa: float = clampf(float(po.get("tensa", 0.0)), 0.0, 1.0)
		# La mano que tira se pinta con SU torsion y el arco con la de la otra mano: se pasa al giro del arco para
		# que la cuerda acabe en la mano de verdad.
		var tirador: Vector3 = p[PoseJugador.P_EMPUNADURA_DER]
		var da: float = PoseJugador.ang_en(esq, tirador.z) - PoseJugador.ang_en(esq, g.z)
		var tv: Vector2 = Vector2(tirador.x, tirador.y).rotated(da)
		tirador = Vector3(tv.x, tv.y, tirador.z)
		_arco(piezas, esq, g, f, e, tensa, tirador, float(po.get("flecha", 0.0)) > 0.5, {"z_torsion": g.z})
	else:
		var g2: Vector3 = p[PoseJugador.P_EMPUNADURA_DER]
		var f2: Vector3 = _vec(po, "ball_f", Vector3(0.0, 1.0, 0.0))
		_ballesta(piezas, esq, g2, f2, clampf(float(po.get("ball_cuerda", 1.0)), 0.0, 1.0),
			float(po.get("virote", 1.0)) > 0.5, {"z_torsion": g2.z})


static func _vec(po: Dictionary, k: String, defecto: Vector3) -> Vector3:
	var v: Vector3 = po.get(k, defecto)
	return v.normalized() if v.length() > 0.01 else defecto


# ============================================================
#  A LA ESPALDA
# ============================================================
# 'con_arma': false = solo el carcaj (el arco esta en la mano).
static func pintar_espalda(piezas: Array, esq: Dictionary, tipo: String, con_arma: bool) -> void:
	var p: Dictionary = esq["puntos"]
	# Los puntos de la espalda salen de P_ESPALDA, que ya hereda la inclinacion, el agachado y el cadaver:
	# se reparte desde ahi para que el carcaj se tumbe con el cuerpo.
	var ref: Vector3 = p[PoseJugador.P_ESPALDA]
	var eje_ref: Vector3 = (p[PoseJugador.P_ESPALDA_PUNTA] - ref).normalized()   # del hombro der. a la cadera izq.
	# El "atras" del cuerpo (sale de la espalda hacia fuera) y su "arriba", sacados de los mismos puntos.
	var atras := Vector3(0.0, -1.0, 0.0)
	var arriba: Vector3 = -eje_ref
	var medio: Vector3 = ref + eje_ref * 11.0 + atras * 2.0          # el centro de la espalda
	if tipo == "arco":
		# EL CARCAJ: la boca sobre el hombro derecho (donde va la empuñadura del mandoble) y el culo a la cadera
		# izquierda.
		var boca: Vector3 = ref + atras * 2.6 + Vector3(-1.5, 0.0, 1.5)
		var culo: Vector3 = boca + eje_ref * 17.0
		PoseJugador.cadena(piezas, esq, culo, boca, 2.3, 2.6, T.MANGO, {})
		PoseJugador.cadena(piezas, esq, culo - Vector3(1.0, 0.0, 0.0), boca - Vector3(1.0, 0.0, 0.0), 1.2, 1.4,
			T.MANGO_S, {"solo_sobre": [T.MANGO]})
		# El brocal: un aro de madera en la boca.
		PoseJugador.cadena(piezas, esq, boca - eje_ref * 0.6, boca + eje_ref * 0.4, 2.9, 2.9, T.MADERA, {})
		# Las PLUMAS asomando, en abanico.
		for k in 3:
			var ab: Vector3 = Vector3(-1.6 + 1.6 * float(k), 0.0, 0.0)
			var pie: Vector3 = boca - eje_ref * 0.5 + ab * 0.6
			var punta: Vector3 = pie - eje_ref * 4.6 + ab * 0.5
			PoseJugador.cadena(piezas, esq, pie, punta, 0.9, 1.1, T.PLUMA if k != 1 else T.PLUMA_S, {})
		if con_arma:
			# EL ARCO cruzado al reves que el carcaj: la pala de arriba al hombro izquierdo, y PLANO CONTRA LA ESPALDA
			# (la curva de lado, no hacia fuera): de canto, visto por detras, solo se veia la cuerda.
			var e: Vector3 = (arriba + Vector3(1.0, 0.0, 0.0) * 0.9).normalized()
			e = Vector3(e.x, 0.0, e.z).normalized()
			var f_esp: Vector3 = e.cross(atras).normalized()
			_arco(piezas, esq, medio + atras * 3.2, f_esp, e, 0.0, Vector3.ZERO, false, {})
	elif con_arma:
		# LA BALLESTA: la culata a la cadera izquierda y la punta (con el arco) sobre el hombro derecho.
		var punta_b: Vector3 = ref + atras * 2.8 + Vector3(0.0, 0.0, -1.0)
		var f: Vector3 = (punta_b - (punta_b + eje_ref * 20.0)).normalized()
		var mano: Vector3 = punta_b - f * CULATA_DELANTE
		_ballesta(piezas, esq, mano, f, 0.0, false, {}, atras)


# ============================================================
#  LAS PIEZAS
# ============================================================
# 'g' la empuñadura, 'f' hacia donde dispara, 'e' el eje de las palas, 'tirador' donde esta la mano que tira
# (solo cuenta con tensa > 0).
static func _arco(piezas: Array, esq: Dictionary, g: Vector3, f: Vector3, e: Vector3, tensa: float,
		tirador: Vector3, flecha: bool, op: Dictionary) -> void:
	# Las palas, punto a punto: retroceden hacia el arquero con el cuadrado de la distancia y las puntas
	# vuelven un poco hacia delante (el recurvo), que es lo que hace que se lea como un arco y no como un palo
	# doblado.
	var curva: float = lerpf(ARCO_CURVA, ARCO_CURVA_TENSO, tensa)
	var n: int = 7
	var puntas: Array = []
	for lado in [1.0, -1.0]:
		var prev: Vector3 = g
		for k in range(1, n + 1):
			var s: float = float(k) / float(n)
			var rec: float = ARCO_RECURVA * smoothstep(0.78, 1.0, s)
			var pt: Vector3 = g + e * (lado * s * ARCO_MEDIO) - f * (curva * s * s) + f * rec
			var r0: float = lerpf(ARCO_R, ARCO_R * 0.6, float(k - 1) / float(n))
			var r1: float = lerpf(ARCO_R, ARCO_R * 0.6, s)
			PoseJugador.cadena(piezas, esq, prev, pt, r0, r1, T.METAL, op)
			# La luz por la panza (el lado que mira al blanco).
			PoseJugador.cadena(piezas, esq, prev + f * (r0 * 0.4), pt + f * (r1 * 0.4), r0 * 0.45, r1 * 0.45,
				T.METAL_L, op.merged({"solo_sobre": [T.METAL]}))
			prev = pt
		puntas.append(prev)
	# La empuñadura, de cuero, tapando el centro.
	PoseJugador.cadena(piezas, esq, g - e * 2.2, g + e * 2.2, ARCO_R * 1.3, ARCO_R * 1.3, T.MANGO, op)
	# LA CUERDA: recta de punta a punta, o en V hasta la mano que tira.
	var nock: Vector3 = g - f * (curva * 0.35 + 2.4)
	if tensa > 0.01:
		nock = nock.lerp(tirador, clampf(tensa * 1.6, 0.0, 1.0))
		PoseJugador.cadena(piezas, esq, puntas[0], nock, CUERDA_R, CUERDA_R, T.CUERDA, op)
		PoseJugador.cadena(piezas, esq, nock, puntas[1], CUERDA_R, CUERDA_R, T.CUERDA, op)
	else:
		PoseJugador.cadena(piezas, esq, puntas[0], puntas[1], CUERDA_R, CUERDA_R, T.CUERDA, op)
	if flecha:
		_flecha(piezas, esq, nock, (g - nock).normalized() if (g - nock).length() > 0.5 else f, FLECHA_LARGO, op)


# Una flecha (o un virote, mas corto) desde la cola 'cola' hacia 'dir'. Astil de madera, punta del metal y
# plumas rojas.
static func _flecha(piezas: Array, esq: Dictionary, cola: Vector3, dir: Vector3, largo: float,
		op: Dictionary) -> void:
	var fin: Vector3 = cola + dir * largo
	PoseJugador.cadena(piezas, esq, cola, fin, 0.5, 0.5, T.MADERA, op)
	PoseJugador.cadena(piezas, esq, fin, fin + dir * 2.2, 0.95, 0.25, T.METAL_L, op)
	PoseJugador.cadena(piezas, esq, cola + dir * 0.6, cola + dir * (largo * 0.2), 1.05, 0.7, T.PLUMA, op)


# 'g' la mano del gatillo, 'f' hacia donde apunta. 'arriba_ref' fija hacia donde cae el canto del arco (en la
# espalda, hacia fuera); vacio = el arco tumbado en horizontal, como se dispara.
static func _ballesta(piezas: Array, esq: Dictionary, g: Vector3, f: Vector3, cuerda: float, virote: bool,
		op: Dictionary, arriba_ref: Vector3 = Vector3.ZERO) -> void:
	var lado: Vector3
	if arriba_ref == Vector3.ZERO:
		lado = f.cross(Vector3(0.0, 0.0, 1.0))
		if lado.length() < 0.05:
			lado = Vector3(1.0, 0.0, 0.0)
	else:
		lado = f.cross(arriba_ref)
	lado = lado.normalized()
	var culo: Vector3 = g - f * CULATA_ATRAS
	var punta: Vector3 = g + f * CULATA_DELANTE
	var arriba: Vector3 = lado.cross(f).normalized()
	# LA CULATA: mas gruesa detras (donde se apoya en el hombro) y con la cola caida, que es lo que la distingue
	# de un palo.
	PoseJugador.cadena(piezas, esq, culo - arriba * 1.5, g, 2.5, 1.9, T.MADERA, op)
	PoseJugador.cadena(piezas, esq, g, punta, 1.9, 1.6, T.MADERA, op)
	PoseJugador.cadena(piezas, esq, culo - arriba * 1.3 - lado * 0.6, punta - lado * 0.5, 0.8, 0.6, T.MADERA_S,
		op.merged({"solo_sobre": [T.MADERA]}))
	PoseJugador.cadena(piezas, esq, g + arriba * 0.9, punta + arriba * 0.8, 0.5, 0.45, T.MADERA_L,
		op.merged({"solo_sobre": [T.MADERA]}))
	# EL ARCO, de metal, cruzado en la punta y doblado hacia delante.
	var tips: Array = []
	for s in [1.0, -1.0]:
		var prev: Vector3 = punta
		for k in range(1, 5):
			var u: float = float(k) / 4.0
			var pt: Vector3 = punta + lado * (s * u * PALAS_BALL) - f * (2.2 * u * u)
			PoseJugador.cadena(piezas, esq, prev, pt, lerpf(1.8, 1.0, float(k - 1) / 4.0), lerpf(1.8, 1.0, u),
				T.METAL, op)
			PoseJugador.cadena(piezas, esq, prev + f * 0.35, pt + f * 0.5, 0.7, 0.45, T.METAL_L,
				op.merged({"solo_sobre": [T.METAL]}))
			prev = pt
		tips.append(prev)
	# El estribo: un aro de metal delante del arco, donde se mete el pie para recargar.
	PoseJugador.cadena(piezas, esq, punta + f * 0.5, punta + f * 2.6, 0.9, 0.9, T.METAL_S, op)
	# LA CUERDA: armada, enganchada en la nuez; suelta, casi contra el arco.
	var nuez: Vector3 = g + f * NUEZ + arriba * 0.6
	var suelta: Vector3 = punta - f * 2.4 + arriba * 0.6
	var c: Vector3 = suelta.lerp(nuez, cuerda)
	PoseJugador.cadena(piezas, esq, tips[0], c, CUERDA_R, CUERDA_R, T.CUERDA, op)
	PoseJugador.cadena(piezas, esq, c, tips[1], CUERDA_R, CUERDA_R, T.CUERDA, op)
	if virote:
		_flecha(piezas, esq, c + arriba * 0.5, f, VIROTE_LARGO, op)


# ============================================================
#  EL RETRATO (la vitrina y las celdas)
# ============================================================
# El arco de pie con la panza a la derecha, y la ballesta tumbada apuntando a la derecha y vista un poco desde
# arriba. Mismo truco que ArmaSprites.pintar_retrato: la altura se estira lo que la camara la aplasta.
static func pintar_retrato(esq: Dictionary, piezas: Array, tipo: String) -> void:
	var op := {"gira": false}
	var k: float = 1.0 / SpriteLienzo.SIN_CAM
	var centro := Vector3(0.0, 0.0, ArmaSprites.RETRATO_ALTURA)
	if tipo == "arco":
		var e := Vector3(-0.25, 0.0, 1.0 * k).normalized()
		var f := Vector3(1.0, 0.0, 0.25 * k).normalized()
		_arco(piezas, esq, centro + Vector3(-1.5, 0.0, 0.0), f, e, 0.0, Vector3.ZERO, false, op)
	else:
		var f2 := Vector3(0.82, 0.0, 0.57 * k).normalized()
		_ballesta(piezas, esq, centro - f2 * 2.5, f2, 1.0, true, op, Vector3(0.0, -1.0, 0.0))
